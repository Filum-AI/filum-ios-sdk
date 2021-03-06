#import <Foundation/Foundation.h>
#import "FilumBDPNetwork.h"

@implementation FilumBDPNetwork: NSObject

+ (instancetype)initWithToken:(NSString *) token serverUrl:(NSURL *)serverURL
{
    FilumBDPNetwork* instance = [FilumBDPNetwork alloc];
    instance.serverUrl = serverURL;
    instance.token = token;
    
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfig.timeoutIntervalForRequest = 30.0;
    instance.urlSession = [NSURLSession sessionWithConfiguration:sessionConfig];
    
    return instance;
}

- (void)emitEvents:(NSArray *)events completionHandler:(void (^)(NSDictionary*, NSError*))completionHandler
{
    NSURLRequest* request = [self buildRequestForEndpoint:@"/events" byHTTPMethod:@"POST" withQueryItems:nil andBody: events];
    
    [[_urlSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self parseResponseData:data error:error completionHandler:completionHandler];
    }] resume];
}

- (NSURLRequest *)buildRequestForEndpoint:(NSString *)endpoint
                             byHTTPMethod:(NSString *)method
                           withQueryItems:(NSArray <NSURLQueryItem *> *)queryItems
                                  andBody:(NSDictionary *)body
{
    // Build URL from path and query items
    NSURL *urlWithEndpoint = [self.serverUrl URLByAppendingPathComponent:endpoint];
    NSURLComponents *components = [NSURLComponents componentsWithURL:urlWithEndpoint
                                             resolvingAgainstBaseURL:YES];
    if (queryItems) {
        components.queryItems = queryItems;
    }
    
    // NSURLComponents/NSURLQueryItem doesn't encode + as %2B, and then the + is interpreted as a space on servers
    components.percentEncodedQuery = [components.percentEncodedQuery stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
    
    // Build request from URL
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:components.URL];
    
    if (![method isEqualToString:@"GET"] && ![method isEqualToString:@"DELETE"]) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }
    
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self.token] forHTTPHeaderField:@"Authorization"];
    [request setHTTPMethod:method];
    
    if (body) {
        NSError *error;
        id json = [self convertFoundationTypesToJSON:body];
        NSData *bodyData = [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
        [request setHTTPBody:bodyData];
    }
    
    return request;
}

- (void)parseResponseData:(NSData *)data error:(NSError *)error completionHandler:(void (^)(NSDictionary*, NSError*))completionHandler
{
    if (error) {
        completionHandler(nil, error);
        return;
    }
    
    NSError *jsonError;
    NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    
    if (jsonError) {
        completionHandler(nil, jsonError);
        return;
    }
    
    completionHandler(jsonResponse, nil);
}

- (id)convertFoundationTypesToJSON:(id)obj {
    // valid json types
    if ([obj isKindOfClass:NSString.class] || [obj isKindOfClass:NSNumber.class] || [obj isKindOfClass:NSNull.class]) {
        return obj;
    }
    if ([obj isKindOfClass:NSDate.class]) {
        return [[self dateFormatter] stringFromDate:obj];
    } else if ([obj isKindOfClass:NSURL.class]) {
        return [obj absoluteString];
    }
    // recurse on containers
    if ([obj isKindOfClass:NSArray.class]) {
        NSMutableArray *a = [NSMutableArray array];
        for (id i in obj) {
            [a addObject:[self convertFoundationTypesToJSON:i]];
        }
        return [NSArray arrayWithArray:a];
    }
    if ([obj isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (id key in obj) {
            NSString *stringKey = key;
            if (![key isKindOfClass:[NSString class]]) {
                stringKey = [key description];
                NSLog(@"%@ property keys should be strings. got: %@. coercing to: %@", self, [key class], stringKey);
            }
            id v = [self convertFoundationTypesToJSON:obj[key]];
            d[stringKey] = v;
        }
        return [NSDictionary dictionaryWithDictionary:d];
    }
    
    // default to sending the object's description
    NSString *s = [obj description];
    NSLog(@"%@ property values should be valid json types. got: %@. coercing to: %@", self, [obj class], s);
    return s;
}

- (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    });
    return formatter;
}

@end
