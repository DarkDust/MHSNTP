//
//  MHSNTPManager.h
//  MHSNTP
//
//  Created by Marc Haisenko on 10.06.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MHSNTPClient;


NS_ASSUME_NONNULL_BEGIN

/** Manages SNTP client object to provide convenient time synchronization.
 
 This class is thread-safe.
 
 @note When you want to dispose an instance of this class, it's recommended to
    assign an empty array to the <code>clients</code> property to clean up
    internal structures and break a possible (temporary) retain cycle caused
    by a timer.
 */
@interface MHSNTPManager : NSObject

/** List of SNTP client instances to.
 
 Assigning new client instances immediately 
 */
@property (nonatomic, copy) NSArray<MHSNTPClient *> * clients;


#pragma mark Time methods

/** Returns the current system clock offset.
 
 The offset is determined in the following way:
 
 <ul>
 <li>With no valid offset entry, 0 is returned.</li>
 <li>If there is just one valid offset entry, that value is returned.</li>
 <li>If there are two valid offset entries, the value closer to 0 is returned.
 </li>
 <li>Otherwise the median offset is returned.</li>
 </ul>
 */
- (NSTimeInterval)systemClockOffset;

/** Returns the current time, taking the current system clock offset into 
 account.
 */
- (NSDate *)now;


#pragma mark Utility methods

/** Add SNTP clients for Apples NTP servers to the receiver's list of
 SNTP client instances.
 */
- (void)addAppleSNTPServers;

@end

NS_ASSUME_NONNULL_END
