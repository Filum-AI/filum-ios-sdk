#ifndef FilumBDPDevice_h
#define FilumBDPDevice_h


#endif /* FilumBDPDevice_h */

#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <SystemConfiguration/SystemConfiguration.h>

@interface FilumBDPDevice : NSObject

@property (nonatomic) dispatch_queue_t serialQueue;
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, strong) CTTelephonyNetworkInfo *telephonyInfo;
@property (atomic, copy) NSString *radio;
@property (atomic, copy) NSString *carrier;
@property (atomic) bool wifi;
@property (atomic, copy) NSDictionary *consistentProperties;

+ (instancetype)initWithToken:(NSString *)token;
- (NSDictionary *) getDeviceProperties;
- (NSString *)getIDFA;
- (NSString *)getIdentifierForVendor;

@end
