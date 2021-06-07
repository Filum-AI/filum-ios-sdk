#ifndef FilumBDP_h
#define FilumBDP_h

@protocol FilumBDPDelegate;

#endif /* FilumBDP_h */

@interface FilumBDP : NSObject

@property (atomic, readonly) NSString * _Nonnull token;

@property (atomic, readonly) NSString * _Nonnull distinctId;

@property (atomic, readonly) NSString * _Nonnull deviceId;

@property (atomic) BOOL flushOnBackground;

@property (atomic, weak) id<FilumBDPDelegate> _Nullable delegate;

#pragma mark Methods

+ (nullable instancetype)initWithToken:(NSString * _Nonnull)token serverUrl:(NSURL * _Nonnull)serverUrl;

+ (nullable instancetype)sharedInstance;

+ (void)destroy;

- (void)track:(nonnull NSString *)eventName;
- (void)track:(nonnull NSString *)eventName properties:(nullable NSDictionary*) properties;
- (void)identify:(nonnull NSString *)userId;
- (void)identify:(nonnull NSString *)userId properties:(nullable NSDictionary*) properties;

- (void)reset;
- (void)flushQueue;

@end

@protocol FilumBDPDelegate <NSObject>

@optional

- (void)filumBDP:(nonnull FilumBDP *)filumBDP didEmitEvents:(nonnull NSArray *)events withResponse:(nullable NSDictionary *)response andError:(nullable NSError *)error;
- (void)filumBDP:(nonnull FilumBDP *)filumBDP didResetWithDistinctId:(nonnull NSString *)distinctId;

@end
