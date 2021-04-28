//
//  FilumBDPStorage.h
//  FilumBDP
//
//  Created by Tran Viet Thang on 2/12/20.
//

#ifndef FilumBDPStorage_h
#define FilumBDPStorage_h


#endif /* FilumBDPStorage_h */

@interface FilumBDPStorage : NSObject

@property (atomic, copy) NSString *token;

+ (instancetype)initWithToken:(NSString *)token;
- (NSString *)getDistinctId;
- (void)setDistinctId:(NSString *)distinctId;
- (NSString *)resetDistinctId;
- (NSString *)getUUIDDeviceId;
- (NSString *)resetUUIDDeviceId;
- (void)saveTaskQueue:(NSArray *)taskQueue;
- (NSArray *)getTaskQueue;
@end
