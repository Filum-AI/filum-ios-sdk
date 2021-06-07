#import <Foundation/Foundation.h>
#import "FilumBDPStorage.h"
#import "FilumBDPStorage+Private.h"
#import "Constants.h"

@implementation FilumBDPStorage: NSObject

+ (instancetype)initWithToken:(NSString *)token
{
    FilumBDPStorage *instance = [[FilumBDPStorage alloc] init];
    instance.token = token;
    instance.userDefaults = [NSUserDefaults standardUserDefaults];
    
    return instance;
}

- (NSString *)getDistinctId
{
    return [self getUUIDForKey:@"distinctId"];
}

- (void)setDistinctId:(NSString *)distinctId
{
    [self.userDefaults setObject:distinctId forKey:[self getPrefixedKeyForKey:@"distinctId"]];
}

- (NSString *)resetDistinctId
{
    return [self resetUUIDForKey:@"distinctId"];
}

- (NSString *)getUUIDDeviceId
{
    return [self getUUIDForKey:@"uuidDeviceId"];
}

- (NSString *)resetUUIDDeviceId
{
    return [self resetUUIDForKey:@"uuidDeviceId"];
}

- (void)saveTaskQueue:(NSArray *)taskQueue
{
    NSString *storageKey = [self getPrefixedKeyForKey:@"taskQueue"];
    [self.userDefaults setObject:taskQueue forKey:storageKey];
}

- (NSArray *)getTaskQueue
{
    NSString *storageKey = [self getPrefixedKeyForKey:@"taskQueue"];
    return [self.userDefaults objectForKey:storageKey];
}

- (NSString *)getUUIDForKey:(NSString *)key
{
    NSString *storageKey = [self getPrefixedKeyForKey:key];
    NSString *item;
    
    item = [self.userDefaults stringForKey:storageKey];
    
    if (!item) {
        item = [[NSUUID UUID] UUIDString];
        [self.userDefaults setObject:item forKey:storageKey];
    }
    
    return item;
}

- (NSString *)resetUUIDForKey:(NSString *)key
{
    NSString *storageKey = [self getPrefixedKeyForKey:key];
    NSString *item = [[NSUUID UUID] UUIDString];
    [self.userDefaults setObject:item forKey:storageKey];
    return item;
}

- (NSString *)getPrefixedKeyForKey:(NSString *)key
{
    return [NSString stringWithFormat:@"%@_%@", self.token, key];
}

@end
