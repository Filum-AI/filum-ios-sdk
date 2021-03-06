#import <SystemConfiguration/SystemConfiguration.h>
#include <sys/sysctl.h>

#import <Foundation/Foundation.h>
#import "FilumBDPDevice.h"
#import "Constants.h"

@implementation FilumBDPDevice: NSObject

+ (instancetype)initWithToken:(NSString *)token
{
    return [[FilumBDPDevice alloc] initWithToken:token];
}

- (instancetype)initWithToken:(NSString *)token
{
    NSString *label = [NSString stringWithFormat:@"ai.filum.BDP.%@.%p", token, (void *)self];
    self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
    
    self.consistentProperties = [self getConsistentProperties];
    
    self.telephonyInfo = [[CTTelephonyNetworkInfo alloc] init];
    
    // cellular info
    [self setCurrentRadio];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(setCurrentRadio)
                                                 name:CTRadioAccessTechnologyDidChangeNotification
                                               object:nil];
    
    // wifi
    if ((self.reachability = SCNetworkReachabilityCreateWithName(NULL, "events.filum.ai")) != NULL) {
        SCNetworkReachabilityContext context = {0, (__bridge void*)self, NULL, NULL, NULL};
        if (SCNetworkReachabilitySetCallback(self.reachability, FilumBDPReachabilityCallback, &context)) {
            if (!SCNetworkReachabilitySetDispatchQueue(self.reachability, self.serialQueue)) {
                // cleanup callback if setting dispatch queue failed
                SCNetworkReachabilitySetCallback(self.reachability, NULL, NULL);
            }
        }
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (!SCNetworkReachabilitySetCallback(self.reachability, NULL, NULL)) {
        NSLog(@"%@ error unsetting reachability callback", self);
    }
    if (!SCNetworkReachabilitySetDispatchQueue(self.reachability, NULL)) {
        NSLog(@"%@ error unsetting reachability dispatch queue", self);
    }
    
    CFRelease(_reachability);
    self.reachability = NULL;
}

- (NSDictionary *) getDeviceProperties
{
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    [p addEntriesFromDictionary: self.consistentProperties];
    
    NSDictionary *network = [NSMutableDictionary dictionary];
    [network setValue:@(self.radio ? 1 : 0) forKey:@"cellular"];
    [network setValue:@(self.wifi ? 1 : 0) forKey:@"wifi"];
    if (self.carrier) [network setValue:self.carrier forKey:@"carrier"];
    [p setValue:network forKey:@"network"];
    
    return p;
}

- (NSString *)getIDFA
{
    NSString *ifa = nil;

    Class ASIdentifierManagerClass = NSClassFromString(@"ASIdentifierManager");
    if (ASIdentifierManagerClass) {
        SEL sharedManagerSelector = NSSelectorFromString(@"sharedManager");
        id sharedManager = ((id (*)(id, SEL))[ASIdentifierManagerClass methodForSelector:sharedManagerSelector])(ASIdentifierManagerClass, sharedManagerSelector);
        SEL advertisingTrackingEnabledSelector = NSSelectorFromString(@"isAdvertisingTrackingEnabled");
        BOOL isTrackingEnabled = ((BOOL (*)(id, SEL))[sharedManager methodForSelector:advertisingTrackingEnabledSelector])(sharedManager, advertisingTrackingEnabledSelector);
        if (isTrackingEnabled) {
            SEL advertisingIdentifierSelector = NSSelectorFromString(@"advertisingIdentifier");
            NSUUID *uuid = ((NSUUID* (*)(id, SEL))[sharedManager methodForSelector:advertisingIdentifierSelector])(sharedManager, advertisingIdentifierSelector);
            ifa = [uuid UUIDString];
        }
    }

    return ifa;
}

- (NSString *)getIdentifierForVendor
{
    return [[UIDevice currentDevice].identifierForVendor UUIDString];
}

- (NSDictionary *) getConsistentProperties
{
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    
    // Use setValue semantics to avoid adding keys where value can be nil.
    NSMutableDictionary *app = [NSMutableDictionary dictionary];
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    NSString *appBuild = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
    NSString *appVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    if (appBuild) [app setValue:appBuild forKey:@"build"];
    if (appVersion) [app setValue:appVersion forKey:@"version"];
    if (appName) [app setValue:appName forKey:@"name"];
    
    [p setValue:app forKey:@"app"];
    
    UIDevice *device = [UIDevice currentDevice];
    id deviceModel = [self getDeviceModel] ? : [NSNull null];
    NSString *deviceName = [device name];
    NSString *deviceType = [device model];
    NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionary];
    [deviceInfo setValue:MANUFACTURER forKey:@"name"];
    [deviceInfo setValue:deviceModel forKey:@"model"];
    if (deviceName) [deviceInfo setValue:deviceName forKey:@"name"];
    if (deviceType) [deviceInfo setValue:deviceType forKey:@"type"];
    [p setValue:deviceInfo forKey:@"device"];
    
    NSDictionary *library = @{
        @"name": SOURCE,
        @"version": VERSION,
    };
    [p setValue:library forKey:@"library"];
    
    NSDictionary *os = @{
        @"name":  [device systemName],
        @"version": [device systemVersion],
    };
    [p setValue:os forKey:@"os"];
    
    CGSize size = [UIScreen mainScreen].bounds.size;
    NSDictionary *screen = @{
        @"height": @((NSInteger)size.height),
        @"width": @((NSInteger)size.width)
    };
    [p setValue:screen forKey:@"screen"];
    
    return p;
}

- (NSString *)getDeviceModel
{
    NSString *results = nil;
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char answer[size];
    sysctlbyname("hw.machine", answer, &size, NULL, 0);
    if (size) {
        results = @(answer);
    } else {
        NSLog(@"%@Failed fetch hw.machine from sysctl.", self);
    }
    return results;
}

- (void)setCurrentRadio
{
    dispatch_async(self.serialQueue, ^{
        NSString *radio = self.telephonyInfo.currentRadioAccessTechnology;
        
        if (!radio) {
            radio = nil;
        } else if ([radio hasPrefix:@"CTRadioAccessTechnology"]) {
            radio = [radio substringFromIndex:23];
        }
        
        CTCarrier *carrier = [self.telephonyInfo subscriberCellularProvider];
        
        self.carrier = carrier.carrierName;
        self.radio = radio;
    });
}

static void FilumBDPReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
    FilumBDPDevice *device = (__bridge FilumBDPDevice *)info;
    if (device && [device isKindOfClass:[FilumBDPDevice class]]) {
        [device reachabilityChanged:flags];
    }
}

- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags
{
    // this should be run in the serial queue. the reason we don't dispatch_async here
    // is because it's only ever called by the reachability callback, which is already
    // set to run on the serial queue. see SCNetworkReachabilitySetDispatchQueue in init
    self.wifi = (flags & kSCNetworkReachabilityFlagsReachable) && !(flags & kSCNetworkReachabilityFlagsIsWWAN);
}

@end
