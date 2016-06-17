# MHSNTP – SNTP pod

This is an Objective-C pod for easy SNTP client support. It's main goals are:

* [RFC 4330](https://tools.ietf.org/html/rfc4330) compliance.
* As much covered by unit tests as possible.
* Modern Objective-C syntax for good support of both Objective-C and Swift.

## Current limitations

* Only unicast operation is supported at the moment.

## Dependencies

This pod requires [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket) to handle the UDP communication.

## Usage

The most simple way to use this pod is to instantiate a `MHSNTPManager`
instance and add Apple's NTP servers (there's a convenience method for that).

```Objective-C
@import MHSNTP
// or
#import <MHSNTP/MHSNTP.h>

// Store the instance in a property or global variable to keep it alive.
MHSNTPManager * sntp = [[MHSNTPManager alloc] init];
[sntp addAppleSNTPServers];

// After adding the servers, the manager automatically starts querying them.
// You can then fetch the corrected current time via:
NSDate * now = [sntp now];

// Or you can query the offset of the local clock for other time calculations:
NSTimeInterval offset = [sntp systemClockOffset];
```

```Swift
import MHSNTP

let sntp = MHSNTPManager()
sntp.addAppleSNTPServers()

let now = sntp.now()
let offset = sntp.systemClockOffset()
```

Please note that querying the servers for the first time is not instantaneous.
So you may want to instantiate the manager as early as possible/necessary in
your app's lifecycle so you hopefully have received responses by the time you
actually need to use the network time.
