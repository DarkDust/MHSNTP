//
//  MHSNTPClient.h
//  MHSNTP
//
//  Created by Marc Haisenko on 08.05.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** The default (S)NTP server port number.
 */
extern const uint16_t kMHSNTPDefaultNTPPort;


/** Domain for errors reported by the SNTP client class.
 */
extern NSString * const MHSNTPClientErrorDomain;

/** Error codes in the SNTP client error domain.
 */
typedef NS_ENUM(NSInteger, MHSNTPClientErrorCode) {
    /** A networking error occurred.
     
     See the underlying error for details.
     */
    MHSNTPClientErrorCodeNetwork,
    
    /** The server didn't answer in a timely manner.
     */
    MHSNTPClientErrorCodeTimeout,
    
    /** The server sent an invalid response.
     */
    MHSNTPClientErrorCodeInvalidResponse,
    
    /** The server has asked us to stop sending requests.
     */
    MHSNTPClientErrorCodeAccessDenied,

    /** The server wants us to send with bigger delays.
     */
    MHSNTPClientErrorCodeRateLimitExceeded,

    /** The client object is getting deallocated.
     */
    MHSNTPClientErrorCodeDealloc,
};

/** Callback block for <code>-[MHSNTPClient queryTime:]</code>.
 
 @param systemClockOffset On success, the offset that needs to be added to the
    system clock to get the server's time.
 @param nextRequestWindow On both success and error, the earliest time
    (uncorrected system time) at which the client may send another request.
    On fatal errors or in case the server said to stop sending requests,
    <code>+[NSDate distantFuture]</code> is passed.
 @param error On failure, an error object in the MHSNTPClientErrorDomain.
 */
typedef void (^MHSNTPClientQueryBlock) (NSTimeInterval systemClockOffset,
    NSDate * nextRequestWindow, NSError * _Nullable error
);

@interface MHSNTPClient : NSObject

/** Designated initializer.
 
 @param serverName The NTP server to query.
 @param portNumber Server port.
 */
- (instancetype)initWithServerName:(NSString *)serverName
    port:(uint16_t)portNumber;

// Mark the default initializer as being unavailable.
- (instancetype)init
    __attribute__((unavailable("Use the designated initializer instead.")));

/** The NTP server to query.
 */
@property(readonly, copy) NSString * serverName;

/** The server's port.
 */
@property(readonly, assign) uint16_t serverPort;

/** Maximum time to wait for a response from the server.
 
 Defaults to 10 seconds.
 */
@property(assign) NSTimeInterval timeout;

/** Queries the server or returns cached data.
 */
- (void)queryTime:(MHSNTPClientQueryBlock)block;

@end


NS_ASSUME_NONNULL_END