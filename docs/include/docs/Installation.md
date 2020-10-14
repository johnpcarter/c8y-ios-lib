# Installation #

## Pre-Requisites ##
- Install xCode 11+ and ensure the command line tools as well. 
- Create your app project via xCode

## Installation via Swift Package Manager ##

Using Xcode 11 go to File > Swift Packages > Add Package Dependency
Paste the project URL: https://github.com/johnpcarter/c8y-ios-lib
Click on next and select the project target

Now you can import your dependencies e.g.:
```
import Combine
import Cumulocity_Client_Library
```