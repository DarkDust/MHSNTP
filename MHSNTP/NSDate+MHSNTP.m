//
//  NSDate+MHSNTP.m
//  MHSNTP
//
//  Created by Marc Haisenko on 07.05.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

#import "NSDate+MHSNTP.h"

#import "MHSNTPLowLevel.h"

/** Time interval between 1900-01-01T00:00Z and 1970-01-01T00:00Z.
 */
static const NSTimeInterval kIntervalBetween1900And1970 = 2208988800.0;

@implementation NSDate (MHSNTP)

+ (NSDate *)dateWithTimeIntervalSince1900MH:(NSTimeInterval)interval;
{
    NSTimeInterval intervalSince1970 = interval
        - kIntervalBetween1900And1970;
    return [NSDate dateWithTimeIntervalSince1970:intervalSince1970];
}

- (NSTimeInterval)timeIntervalSince1900MH
{
    return self.timeIntervalSince1970 + kIntervalBetween1900And1970;
}

@end
