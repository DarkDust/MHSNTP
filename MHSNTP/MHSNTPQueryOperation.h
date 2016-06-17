//
//  MHSNTPQueryOperation.h
//  MHSNTP
//
//  Created by Marc Haisenko on 06.05.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MHSNTPErrorCode) {
    
    /** Kiss code: DENY.
     
     Access denied by remote server.
     
     The server asks the client to stop sending requests.
     
     @see RFC 5905 section 7.4
     */
    MHSNTPErrorCodeKissDeny,
    
    /** Kiss code: RSTR.
     
     Access denied due to local policy.
     
     The server asks the client to stop sending requests.
     
     @see RFC 5905 section 7.4
     */
    MHSNTPErrorCodeKissRstr,
    
    /** Kiss code: RATE.
     
     Rate exceeded. The server has temporarily denied access because the client
     exceeded the rate threshold.
     
     The server asks the client to reduce its rate.
     
     @see RFC 5905 section 7.4
     */
    MHSNTPErrorCodeKissRate,
    
    /** Kiss code: deny.

     An unknown kiss code was received.
     
     @see RFC 5905 section 7.4
     */
    MHSNTPErrorCodeKissUnknown,
};

/** Queries a (S)NTP server.
 */
@interface MHSNTPQueryOperation : NSOperation

// Mark default initializer as being unavailable since it doesn't make
// sense to use it.
- (instancetype)init
    __attribute__((unavailable("Use the designated initializer instead.")));

/** Designated initializer.
 
 @param hostName The server to query.
 */
- (instancetype)initWithServerName:(NSString *)hostName;

/** The error if the operation failed.
 */
@property (strong) NSError * _Nullable error;

/** Offset of the host time to the calculated network time.
 */
@property NSTimeInterval offset;

@end


NS_ASSUME_NONNULL_END