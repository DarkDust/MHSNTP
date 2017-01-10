# MHSNTP – SNTP pod

![CocoaPods version](https://img.shields.io/cocoapods/v/MHSNTP.svg?maxAge=2592000)
![CocoaPods license](https://img.shields.io/cocoapods/l/MHSNTP.svg?maxAge=2592000)


This is a pod for easy SNTP client support in macOS, iOS and tvOS. It's main
goals are:

* [RFC 4330](https://tools.ietf.org/html/rfc4330) compliance.
* As much covered by unit tests as possible.
* Modern Objective-C syntax for good support of both Objective-C and Swift.

This pod does not alter the system's clock. It merely provides easy access to
networked time for your apps.

## Current limitations

* Only unicast operation is supported at the moment.

## Dependencies

This pod requires [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket)
to handle the UDP communication.

## Integration in your project

This project is available as a CocoaPod, so you simply need to add the following
line to your `Podfile`:

```
pod 'MHSNTP'
```

There are two ways to integrate this pod: as module or not. To integrate using
modules, add `use_frameworks!` to your `Podfile`. After this, you reference the
pod like this:

```
// Objective-C
@import MHSNTP;

// Swift
import MHSNTP
```

If you are not using modules, you need to import the umbrella header in
Objective-C:

```Objective-C
#import <MHSNTP/MHSNTP.h>
```

When using the pod in Swift without modules, you need add `#import <MHSNTP/MHSNTP.h>`
to your bridging header. No `import MHSNTP` is needed in this case.

## Usage

The most simple way to use this pod is to instantiate a `MHSNTPManager`
instance and add Apple's NTP servers (there's a convenience method for that).

Objective-C example:
```Objective-C
// Store the instance in a property or global variable to keep it alive.
MHSNTPManager * sntp = [[MHSNTPManager alloc] init];
[sntp addAppleSNTPServers];

// After adding the servers, the manager automatically starts querying them.
// You can then fetch the corrected current time via:
NSDate * now = [sntp now];

// Or you can query the offset of the local clock for other time calculations:
NSTimeInterval offset = [sntp systemClockOffset];
```

Swift example:
```Swift
let sntp = MHSNTPManager()
sntp.addAppleSNTPServers()

let now = sntp.now()
let offset = sntp.systemClockOffset()
```

Please note that querying the servers for the first time is not instantaneous.
So you may want to instantiate the manager as early as possible/necessary in
your app's lifecycle so you hopefully have received responses by the time you
actually need to use the network time.
