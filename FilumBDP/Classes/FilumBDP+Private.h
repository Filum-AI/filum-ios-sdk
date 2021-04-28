//
//  FilumBDP+Private.h
//  FilumBDP
//
//  Created by Tran Viet Thang on 2/7/20.
//

#ifndef FilumBDP_Private_h
#define FilumBDP_Private_h


#endif /* FilumBDP_Private_h */

#import "FilumBDP.h"
#import "FilumBDPNetwork.h"
#import "FilumBDPDevice.h"
#import "FilumBDPStorage.h"

@interface FilumBDP()

#pragma mark Properties

@property (atomic, copy) NSString *token;
@property (atomic, copy) NSString *distinctId;
@property (atomic, copy) NSString *deviceId;
@property (atomic, retain) FilumBDPNetwork *network;
@property (atomic, retain) FilumBDPDevice *device;
@property (atomic, retain) FilumBDPStorage *storage;
@property (atomic, strong) NSMutableArray *taskQueue;
@property (atomic, retain) NSTimer *timer;
@property (nonatomic) dispatch_queue_t serialQueue;
@property (atomic) BOOL flushing;
@property (atomic) BOOL disabled;

@end
