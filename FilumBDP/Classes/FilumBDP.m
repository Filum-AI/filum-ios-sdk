

#include "FilumBDP.h"
#include "FilumBDP+Private.h"
#include "Constants.h"

@implementation FilumBDP

void myExceptionHandler(NSException *exception)
{
    [[FilumBDP sharedInstance] handleException:exception];
}

static FilumBDP *instance;

+ (nullable instancetype) initWithToken:(NSString *)token serverUrl:(NSURL *)serverUrl
{
    return [[FilumBDP alloc] initWithToken:token serverUrl:serverUrl];
}

+ (nullable instancetype) sharedInstance{
    return instance;
}

+ (void)destroy
{
    instance = nil;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (nullable instancetype) initWithToken:(NSString *)token serverUrl:(NSURL *)serverUrl
{
    if (instance != nil) {
        NSException *e = [NSException
                          exceptionWithName:@"DuplcatedInitialization"
                          reason:@"FilumBDP can be initialized only once"
                          userInfo:nil];
        @throw e;
    }
    
    NSSetUncaughtExceptionHandler(&myExceptionHandler);
    
    // Utilities
    self.network = [FilumBDPNetwork initWithToken:token serverUrl:serverUrl];
    self.device = [FilumBDPDevice initWithToken:token];
    self.storage = [FilumBDPStorage initWithToken:token];
    
    // Identity
    self.distinctId = [self.storage getDistinctId];
    self.deviceId = [self getDeviceId];
    self.flushOnBackground = FLUSH_ON_BACKGROUND;
    
    
    // Task queue
    NSArray *archivedTaskQueue = [self.storage getTaskQueue];
    if (archivedTaskQueue) {
        self.taskQueue = [archivedTaskQueue mutableCopy];
    } else {
        self.taskQueue = [NSMutableArray array];
    }
    self.flushing = NO;
    self.disabled = NO;
    
    // Serial queue
    NSString *label = [NSString stringWithFormat:@"ai.filum.BDP.%@.%p", token, (void *)self];
    self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
    
    // Flush timer
    [self startFlushTimer];
    
    // Application lifecycle events
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillTerminate:)
                               name:UIApplicationWillTerminateNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
    
    instance = self;
    return instance;
}

- (void)identify:(NSString *)userId properties:(NSDictionary *)properties
{
    if (!userId || [userId isEqualToString:@""]) {
        NSException *e = [NSException
                          exceptionWithName:@"InvalidArgument"
                          reason:@"userId can not be nil or empty"
                          userInfo:nil];
        @throw e;
    }
    
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    [data addEntriesFromDictionary:@{
        @"event_type": @"identify",
        @"event_name": @"Identify",
        @"event_id": [[NSUUID UUID] UUIDString],
        @"user_id": userId,
    }];

    if (properties) {
        [data addEntriesFromDictionary:@{
            @"event_params": [self convertEventParams:properties]
        }];
    }
    
    [self addToQueue:@{
        @"type": @"identify",
        @"data": data
    }];
}

- (void)identify:(NSString *)userId
{
    [self identify:userId properties:nil];
}

- (void)track:(NSString *)eventName properties:(NSDictionary *)properties
{
    if (!eventName) {
        NSException *e = [NSException
                          exceptionWithName:@"InvalidArgument"
                          reason:@"eventName can not be nil"
                          userInfo:nil];
        @throw e;
    }

    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    [data addEntriesFromDictionary:@{
        @"event_type": @"track",
        @"event_name": eventName,
        @"event_id": [[NSUUID UUID] UUIDString],
    }];
    
    if (properties) {
        [data addEntriesFromDictionary:@{
            @"event_params": [self convertEventParams:properties]
        }];
    }
    
    [self addToQueue:@{
        @"type": @"event",
        @"data": data
    }];
}

- (void)track:(NSString *)eventName
{
    [self track:eventName properties:nil];
}

- (void)reset
{
    [self addToQueue:@{
        @"type": @"reset",
        @"data": @{
            @"distinct_id": self.distinctId,
            @"device_id": self.deviceId
        }
    }];
    [self flushQueue];
}

- (void)handleException:(NSException *)exception
{
    [self.storage saveTaskQueue:self.taskQueue];
}

- (void)addToQueue:(NSDictionary *)data
{
    if (self.disabled) {
        return;
    }

    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
    [dateFormatter setDateFormat: @"yyyy-MM-dd'T'HH:mm:ss.SSSSSSSZZZZZ"];
    
    NSMutableDictionary *taskdata = [data mutableCopy];

    [taskdata setValue:[dateFormatter stringFromDate:[NSDate date]] forKey:@"time"];
    [taskdata setValue:VERSION forKey:@"version"];
    [self.taskQueue addObject:taskdata];
    
    if ([self.taskQueue count] > QUEUE_SIZE_LIMIT) {
        [self.taskQueue removeObjectAtIndex:0];
    }
}

- (void)startFlushTimer
{
    [self stopFlushTimer];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (FLUSH_INTERVAL > 0) {
            self.timer = [NSTimer scheduledTimerWithTimeInterval:FLUSH_INTERVAL
                                                          target:self
                                                        selector:@selector(flushQueue)
                                                        userInfo:nil
                                                         repeats:YES];
        }
    });
}

- (void)stopFlushTimer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.timer) {
            [self.timer invalidate];
            self.timer = nil;
        }
    });
}

- (void)keepFlushing
{
    self.flushing = NO;
    
    if ([self.taskQueue count] > 0) {
        [self flushQueue];
    }
}

- (BOOL)shouldShiftEventFromQueue:(NSArray *)queue
{
    if ([queue count] > 0) {
        NSArray *eventTaskTypes = @[@"event", @"identify"];
        return [eventTaskTypes containsObject:[[queue objectAtIndex:0] valueForKey:@"type"]];
    }
    
    return false;
}

- (void)handleTaskResult:(NSDictionary *)response error:(NSError *)error
{
    [self handleTaskResult:response error:error numberOfTasksToRemove:1];
}

- (void)handleTaskResult:(NSDictionary *)response error:(NSError *)error numberOfTasksToRemove:(unsigned long)numberOfTasksToRemove
{
    if (error) {
        self.flushing = NO;
    } else {
        NSNumber *errorCode = [response valueForKey:@"error_code"];
        if ([errorCode isEqualToNumber:[NSNumber numberWithLong:40101]]) {
            self.disabled = YES;
            [self stopFlushTimer];
            [self.storage saveTaskQueue:nil];
        } else {
            [self.taskQueue removeObjectsInRange:NSMakeRange(0, numberOfTasksToRemove)];
            [self keepFlushing];
        }
    }
}

- (void)flushQueue
{
    dispatch_async(self.serialQueue, ^{
        if (self.flushing) {
            return;
        }
        
        self.flushing = YES;
        
        while([self.taskQueue count] > 0 && ![[[self.taskQueue objectAtIndex:0] valueForKey:@"version"] isEqualToString:VERSION]) {
            [self.taskQueue removeObjectAtIndex:0];
        }
        
        NSMutableArray *currentEventBatch = [NSMutableArray array];
        NSMutableArray *queueCopyForFlushing = [self.taskQueue mutableCopy];
        
        NSMutableDictionary *context = [self.device getDeviceProperties];
        // Set Device ID and advertising ID
        [context setValue:self.deviceId forKeyPath:@"device.id"];
        if ([self.device getIDFA]) [context setValue:[self.device getIDFA] forKeyPath:@"device.advertising_id"];
        
        while ([self shouldShiftEventFromQueue:queueCopyForFlushing]) {
            NSDictionary *task = [queueCopyForFlushing objectAtIndex:0];
            [queueCopyForFlushing removeObjectAtIndex:0];
            NSMutableDictionary *taskData = [[task valueForKey:@"data"] mutableCopy];
            
            // Add event attributes based on event schema
            NSNumber *time = [task valueForKey:@"time"];
            [taskData setValue:time forKey:@"timestamp"];
            [taskData setValue:time forKey:@"original_timestamp"];
            [taskData setValue:time forKey:@"sent_at"];
            [taskData setValue:self.distinctId forKey:@"anonymous_id"];
            [taskData setValue:context forKey:@"context"];

            // Add event to the batch
            [currentEventBatch addObject:taskData];
        }
        
        if ([currentEventBatch count] > 0) {
            [self.network emitEvents:currentEventBatch completionHandler:^(NSDictionary *response, NSError *error) {
                if (self.delegate) {
                    [self.delegate filumBDP:self didEmitEvents:currentEventBatch withResponse:response andError:error];
                }
                
                [self handleTaskResult:response error:error numberOfTasksToRemove:[currentEventBatch count]];
            }];
        } else if ([queueCopyForFlushing count] > 0) {
            NSDictionary *task = [queueCopyForFlushing objectAtIndex:0];
            [queueCopyForFlushing removeObjectAtIndex:0];
            NSString *taskType = [task valueForKey:@"type"];

            if ([taskType isEqualToString:@"reset"]) {
                // Reset
                self.distinctId = [self.storage resetDistinctId];
                
                if (self.delegate) {
                    [self.delegate filumBDP:self didResetWithDistinctId:self.distinctId];
                }
                
                [self.taskQueue removeObjectAtIndex:0];
                [self keepFlushing];
            } else {
                self.flushing = NO;
            }
        } else {
            self.flushing = NO;
        }
    });
}

- (NSString *)getDeviceId
{
    NSString *deviceId;
    
    // Try with IDFA
    deviceId = [self.device getIDFA];
    
    // If IDFA is not available, try with identifierForVendor
    if (!deviceId && NSClassFromString(@"UIDevice")) {
        deviceId = [self.device getIdentifierForVendor];
    }
    
    // If identifierForVendor is not available, use UUID
    if (!deviceId) {
        deviceId = [self.storage getUUIDDeviceId];
    }
    
    return deviceId;
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    [self stopFlushTimer];
    
    if (self.flushOnBackground) {
        [self flushQueue];
    } else {
        dispatch_async(self.serialQueue, ^{
            [self.storage saveTaskQueue:self.taskQueue];
        });
        [self.storage saveTaskQueue:self.taskQueue];
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    dispatch_async(self.serialQueue, ^{
        [self.storage saveTaskQueue:self.taskQueue];
    });
}

- (void)applicationDidBecomeActive:(NSNotificationCenter *)notification
{
    [self startFlushTimer];
}

- (NSMutableArray *) convertEventParams:(NSDictionary *)params
{
    NSMutableArray *listParams = [NSMutableArray array];
    for (NSString* key in params) {
        NSDictionary *param = @{
            @"key": key,
            @"value": @{
                @"string_value": params[key]
            }
        };
        [listParams addObject:param];
    }
    return listParams;
}

@end
