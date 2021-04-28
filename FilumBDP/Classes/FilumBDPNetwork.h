//
//  FilumBDPNetwork.h
//  FilumBDP
//
//  Created by Tran Viet Thang on 2/7/20.
//

#ifndef FilumBDPNetwork_h
#define FilumBDPNetwork_h


#endif /* FilumBDPNetwork_h */


@interface FilumBDPNetwork : NSObject

@property (atomic, copy) NSString *token;
@property (atomic, copy) NSURL *serverUrl;
@property (atomic, retain) NSURLSession *urlSession;

+ (instancetype)initWithToken:(NSString *) token serverUrl:(NSURL *)serverURL;
- (void)emitEvents:(NSArray *)events completionHandler:(void (^)(NSDictionary*, NSError*))completionHandler;

@end
