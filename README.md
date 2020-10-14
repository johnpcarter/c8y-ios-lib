# README #

Client library (iOS 13.0+ or MacOS 10.15+) for accessing your Cumulocity IoT tenant from your own iPhone or Mac apps.

Refer to the [Cumulocity Home Page](https://www.softwareag.cloud/site/product/cumulocity-iot.html) to sign up for your own Cumulocity tenant if you do not already have one.

This library uses the [c8y REST API](https://cumulocity.com/guides/reference/rest-implementation/) in order to communicate with your tenant and you will need a login with appropriate permissions to allow access.

You will need a Mac (ideally running 10.15) and up to date version of xCode 11.0 to use this library and integrate with your apps.

Install the library direct from [github]() or as a swift package in a xcode project that you have already created.

Using Xcode 11 go to File > Swift Packages > Add Package Dependency
Paste the project URL: https://github.com/johnpcarter/c8y-ios-lib
Click on next and select the project target

Now you can import your dependencies e.g.:
```
#import Combine
#import <Cumulocity_Client_Library/Cumulocity_Client_Library.h>
```
