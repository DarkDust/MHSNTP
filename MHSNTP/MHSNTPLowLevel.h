//
//  MHSNTPLowLevel.h
//  MHSNTP
//
//  Created by Marc Haisenko on 06.05.16.
//  Copyright © 2016 Marc Haisenko. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** Represents a decoded NTP packet.
 
 All fields are in host byte order.
 */
typedef struct MHNTPRawPacket {
    /** Warning of an impending leap second to be inserted or deleted in the
     last minute of the current month.
     */
    unsigned int leapIndicator : 2;
    
    /** NTP version number.
     */
    unsigned int version : 3;
    
    /** Mode.
     */
    unsigned int mode : 3;
    
    /** Stratum.
     */
    uint8_t stratum;
    
    /** Maximum interval between successive messages, in log2 seconds.
     */
    uint8_t poll;
    
    /** Precision of the system clock, in log2 seconds.
     */
    int8_t precision;
    
    /** Total round-trip delay to the reference clock, in NTP short format.
     */
    uint32_t rootDelay;
    
    /** Total dispersion to the reference clock, in NTP short format.
     */
    uint32_t rootDispersion;
    
    /** Code identifying the particular server or reference clock.
     */
    uint32_t referenceID;
    
    /** Time when the system clock was last set or corrected, in NTP timestamp
     format.
     */
    uint64_t referenceTimestamp;
    
    /** Time at the client when the request departed for the server, in NTP
     timestamp format.
     */
    uint64_t originTimestamp;

    /** Time at the server when the request arrived from the client, in NTP
     timestamp format.
     */
    uint64_t receiveTimestamp;

    /** Time at the server when the response left for the client, in NTP
     timestamp format.
     */
    uint64_t transmitTimestamp;
    
} MHNTPRawPacket;

/** Converts a NTP short format value to a time interval.
 
 @param timestamp The 32-bit short format value in host byte order to convert.
 @return Converted timestamp.
 */
NSTimeInterval MHNTPShortFormatToTimeInterval(uint32_t timestamp);

/** Converts a time interval to a NTP short format value.
 
 The time interval to convert must be positive.
 
 @param interval The time interval to convert.
 @return Converted NTP short format value in host byte order or 
    <code>UINT32_MAX</code> if the time interval was negative.
 */
uint32_t MHTimeIntervalToNTPShortFormat(NSTimeInterval interval);

/** Converts a NTP timestamp value to a time interval.
 
 @param timestamp The 64-bit timestamp value in host byte order to convert.
 @return Converted timestamp.
 */
NSTimeInterval MHNTPTimestampToTimeInterval(uint64_t timestamp);

/** Converts a time interval to a NTP timestamp.
 
 The time interval to convert must be positive.

 @param interval The time interval to convert.
 @return Converted NTP timestamp value in host order or <code>UINT64_MAX</code>
    if the time interval was negative.
 */
uint64_t MHTimeIntervalToNTPTimestamp(NSTimeInterval interval);

/** Decodes a raw NTP data packet.
 
 @param data The data to decode.
 @return Decoded packet. On error (data too short), all fields are zero.
 */
MHNTPRawPacket MHDecodeNTPData(NSData * data);

/** Encodes a NTP packet.
 
 @param The packet to encode.
 @return Raw data that can be sent.
 */
NSData * MHEncodeNTPPacket(MHNTPRawPacket packet);

NS_ASSUME_NONNULL_END