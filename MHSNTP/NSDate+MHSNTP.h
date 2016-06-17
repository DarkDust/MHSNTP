//
//  NSDate+MHSNTP.h
//  MHSNTP
//
//  Created by Marc Haisenko on 07.05.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDate (MHSNTP)

/** Creates and returns an NSDate object set to the given number of seconds
 from 00:00:00 UTC on 1 January 1900.
 
 @param interval The time interval since 1900-01-01T00:00Z.
 */
+ (NSDate *)dateWithTimeIntervalSince1900MH:(NSTimeInterval)interval;

/** Returns the number of seconds since 00:00:00 UTC on 1 January 1900.
 */
- (NSTimeInterval)timeIntervalSince1900MH;

@end

NS_ASSUME_NONNULL_END