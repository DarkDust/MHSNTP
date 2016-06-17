//
//  MHSNTPManager-Internal.h
//  MHSNTP
//
//  Created by Marc Haisenko on 13.06.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

#import <MHSNTP/MHSNTPManager.h>


NS_ASSUME_NONNULL_BEGIN

/** Helper accounting object for MHSNTPManager.
 
 Gathers some data related to a client.
 */
@interface MHSNTPManagerEntry : NSObject

/// The managed client instance.
@property (strong) MHSNTPClient * client;

/// Last system clock offset received from the client.
@property (assign) NSTimeInterval lastClockOffset;

/** The earliest date at which we may send the next request in local system
 time.
 */
@property (strong) NSDate * nextRequestWindow;

/** Date at which the last request was sent in local system time.
 */
@property (strong) NSDate * _Nullable lastRequestDate;

/// The last error received from the client.
@property (strong) NSError * _Nullable error;

/// Whether a request is currently in flight.
@property (assign) BOOL inFlight;

/// Debugging/testing: the number of requests sent so far.
@property (assign) NSUInteger numberOfRequests;

@end

/** Internal properties and method for the manager that need to be accessed
 for unit testing.
 */
@interface MHSNTPManager (Internal)

/// Managed clients.
@property (strong) NSMutableDictionary<NSString *, MHSNTPManagerEntry *> *
    clientEntries;

@end

NS_ASSUME_NONNULL_END
