# Installation #

## Pre-Requisites ##
- Install xCode 11 and ensure the command line tools as well. 
- Install CocoaPods
```
$ sudo gem install cocoapods
```
- Create your app project via xCode

## Installation via CocoaPods ##

Navigate to the folder your xCode project and create a text file named "Podfile",
then paste the following text, replacing 'MyApp' with the name that you gave to your xCode project

```
platform :ios, '13.0'
use_frameworks!

target 'MyApp' do
  pod 'c8yAPIClient'
end
```

Now you can install the library into your project with the following command, after first closing your xCode
project if not already done so.

```
$ pod install
```

Make sure to always open the Xcode workspace instead of the project file when building your project:

```
$ open App.xcworkspace
```

Now you can import your dependencies e.g.:
```
#import <Cumulocity_Client_Library/Cumulocity_Client_Library.h>