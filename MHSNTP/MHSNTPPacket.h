//
//  MHSNTPPacket.h
//  MHSNTP
//
//  Created by Marc Haisenko on 07.05.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** Values of the leap indicator field.
 */
typedef NS_ENUM(NSInteger, MHSNTPLeapIndicator) {
    
    /** No warning.
     */
    MHSNTPLeapIndicatorNone = 0,
    
    /** The last minute has 61 seconds.
     */
    MHSNTPLeapIndicator61Seconds,
    
    /** The last minute has 59 seconds.
     */
    MHSNTPLeapIndicator59Seconds,
    
    /** Unknown or clock not synchronized.
     */
    MHSNTPLeapIndicatorUnknownUnsynchronized
};

/** Values of the mode field.
 */
typedef NS_ENUM(NSInteger, MHSNTPMode) {
    
    /** Reserved value.
     */
    MHSNTPModeReserved = 0,
    
    /** Symmetric active mode.
     
     Not used by SNTP.
     */
    MHSNTPModeSymmetricActive,
    
    /** Symmetric passive mode.
     
     Not used by SNTP.
     */
    MHSNTPModeSymmetricPassive,
    
    /** Client mode.
     
     Set for requests from a client to a server.
     */
    MHSNTPModeClient,
    
    /** Server mode.
     
     Set for responses from a server to a client.
     */
    MHSNTPModeServer,
    
    /** Broadcast mode.
     
     Set for broadcast messages from a server.
     */
    MHSNTPModeBroadcast,
    
    /** Reserved value.
     */
    MHSNTPModeReservedNTPControlMessage,
    
    /** Reserved value.
     */
    MHSNTPModeReservedPrivateUse
};

// Note: this is only a small number of possible values for the reference
// identifiers. An exhaustive list is beyond the scope of this pod.

/** Reference identifer: local uncalibrated clock.
 */
extern FourCharCode MHSNTPReferenceLOCL;

/** Reference identifier: calibrated Cesium clock.
 */
extern FourCharCode MHSNTPReferenceCESM;

/** Reference identifier: calibrated Rubidium clock.
 */
extern FourCharCode MHSNTPReferenceRBDM;

/** Reference identifier: calibrated quartz clock or other pulse-per-second
 source.
 */
extern FourCharCode MHSNTPReferencePPS;

/** Reference identifier: German longwave time signal and standard-frequency
 radio station (DCF77).
 */
extern FourCharCode MHSNTPReferenceDCF;

/** Reference identifier: Global Positioning Service.
 */
extern FourCharCode MHSNTPReferenceGPS;

/** Reference identifier: Global Positioning Service with shared access.
 */
extern FourCharCode MHSNTPReferenceGPSs;

/** Reference identifier: GLONASS with shared access.
 */
extern FourCharCode MHSNTPReferenceGLNs;

/** Kiss-o'-death code: Access denied by remote server.
 
 The client must stop sending requests to the server.
 */
extern FourCharCode MHSNTPKissODeathDENY;

/** Kiss-o'-death code: Access denied due to local policy.
 
 The client must stop sending requests to the server.
 */
extern FourCharCode MHSNTPKissODeathRSTR;

/** Kiss-o'-death code: Rate exceeded.
 
 The server has temporarily denied access because the client exceeded the
 rate threshold.
 
 The client must throttle its request rate.
 */
extern FourCharCode MHSNTPKissODeathRATE;


/** A NTP packet.
 */
@interface MHSNTPPacket : NSObject <NSMutableCopying>

/** Initialize with raw NTP packet data.
 
 @param data NTP data to initialize with.
 @return A new instance or <code>nil</code> on error.
 */
- (instancetype _Nullable)initWithData:(NSData *)data;

/** Returns the packet as data that may be sent.
 */
- (NSData *)data;

/** Leap second indicator.
 
 Warning of an impending leap second to be inserted/deleted in the last minute
 of the current day.  This field is significant only in server messages.
 */
@property(readonly) MHSNTPLeapIndicator leapIndicator;

/** NTP/SNTP version number.
 
 Only version 4 is supported.
 */
@property(readonly) NSUInteger version;

/** Protocol mode.
 */
@property(readonly) MHSNTPMode mode;

/** Stratum.
 
 This field is significant only in SNTP server messages, where the values are
 defined as follows:
 
 <ul>
 <li>0: Kiss-o'-death message.</li>
 <li>1: Primary reference (e.g., synchronized by radio clock).</li>
 <li>2–15: Secondary reference (synchronized by NTP or SNTP).</li>
 <li>16–255: Reserved.</li>
 </ul>
 */
@property(readonly) NSUInteger stratum;

/** Poll interval as as an exponent of two.
 
 The resulting value is the maximum interval between successive messages in
 seconds. This field is significant only in SNTP server messages, where the
 values range from 4 (16 seconds) to 17 (131,072 seconds – about 36 hours).
 */
@property(readonly) NSUInteger rawPollInterval;

/** Poll interval.
 
 The maximum interval between successive messages in seconds. This field is
 significant only in SNTP server messages, where the values range from 16 
 seconds to 131,072 seconds – about 36 hours.
 
 This value is derived from <code>rawPollInterval<code>.
 */
@property(readonly) NSTimeInterval pollInterval;

/** System clock precision as an exponent of two.
 
 The resulting value is the precision of the system clock in seconds. This
 field is significant only in server messages, where the values range from
 -6 for mains-frequency clocks to -20 for microsecond clocks.
 */
@property(readonly) NSInteger rawPrecision;

/** System clock precision.
 
 The precision of the system clock in seconds. This field is significant only
 in server messages.
 
 This value is derived from <code>rawPrecision</code>.
 */
@property(readonly) NSTimeInterval precision;

/** The total roundtrip delay to the primary reference source.
 
 Note that this variable can take on both positive and negative values,
 depending on the relative time and frequency offsets. This field is
 significant only in server messages, where the values range from negative
 values of a few milliseconds to positive values of several hundred
 milliseconds.
 */
@property(readonly) NSTimeInterval rootDelay;

/** The maximum error due to the clock frequency tolerance.
 
 This field is significant only in server messages, where the values range
 from zero to several hundred milliseconds.
 */
@property(readonly) NSTimeInterval rootDispersion;

/** Reference source.
 
 This field is significant only in server messages, where for stratum 0
 (kiss-o'-death message) and 1 (primary server), the value is a
 four-character ASCII string.
 
 For IPv4 secondary servers, the value is the 32-bit IPv4 address of the
 synchronization source. For IPv6 and OSI secondary servers, the value is the
 first 32 bits of the MD5 hash of the IPv6 or NSAP address of the
 synchronization source.
 
 @see <code>MHSNTPReference*</code> constants for values relevant to stratum 1.
 */
@property(readonly) FourCharCode referenceIdentifier;

/** The time the system clock was last set or corrected.
 
 This is a time interval relative to 1900-01-01T00:00 UTC.
 */
@property(readonly) NSTimeInterval referenceTimestamp;

/** The time at which the request departed the client for the server.
 
 This is a time interval relative to 1900-01-01T00:00 UTC.
 */
@property(readonly) NSTimeInterval originateTimestamp;

/** The time at which the request arrived at the server or the reply arrived at
 the client.
 
 This is a time interval relative to 1900-01-01T00:00 UTC.
 */
@property(readonly) NSTimeInterval receiveTimestamp;

/** The time at which the request departed the client or the reply departed the
 server.
 
 This is a time interval relative to 1900-01-01T00:00 UTC.
 */
@property(readonly) NSTimeInterval transmitTimestamp;

@end

/** Mutable NTP packet.
 */
@interface MHSNTPMutablePacket : MHSNTPPacket

@property(readwrite) MHSNTPLeapIndicator leapIndicator;
@property(readwrite) NSUInteger version;
@property(readwrite) MHSNTPMode mode;
@property(readwrite) NSUInteger stratum;
@property(readwrite) NSUInteger rawPollInterval;
@property(readwrite) NSInteger rawPrecision;
@property(readwrite) NSTimeInterval rootDelay;
@property(readwrite) NSTimeInterval rootDispersion;
@property(readwrite) FourCharCode referenceIdentifier;
@property(readwrite) NSTimeInterval referenceTimestamp;
@property(readwrite) NSTimeInterval originateTimestamp;
@property(readwrite) NSTimeInterval receiveTimestamp;
@property(readwrite) NSTimeInterval transmitTimestamp;

@end

NS_ASSUME_NONNULL_END