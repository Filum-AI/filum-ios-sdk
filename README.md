# Filum IOS SDK

## Description

Filum IOS SDK to help your app communicate with Filum Business Data Platform

## Installation

### Step 1: Add filum-ios-sdk as a submodule

Add filum-ios-sdk as a submodule to your local git repo like so:

```shell
git submodule add git@github.com:Filum-AI/filum-ios-sdk.git
```

### Step 2: Instal via CocoaPods
Inside your Podfile:

```shell
pod 'FilumBDP', :path => './filum-ios-sdk'
```
`path` should point to the filum-ios-sdk submodule

Finally, run this command to make FilumBDP available inside your project:

```shell
pod install
```

## Usage

### Integrate

Import the header file

```objectivec
#import <FilumBDP/FilumBDP.h>
```

```swift
import GIAP
```

Initialize the library

```objectivec
[FilumBDP initWithToken:@"INSERT_YOUR_WRITE_KEY_HERE" serverUrl:[NSURL URLWithString:@"INSERT_THE_EVENT_API_URL_HERE"]];
```

```swift
FilumBDP.initWithToken("INSERT_YOUR_WRITE_KEY_HERE", serverUrl: URL(string: "INSERT_THE_EVENT_API_URL_HERE"))
```

### Identify
Use this method right after user has just logged in

```objectivec
[[FilumBDP sharedInstance] identify:@"INSERT THE USER ID" properties:@{
    @"name": name
}];
```

```swift
GIAP.sharedInstance().identify("INSERT THE USER ID", properties: {
    "name": "name"
})
```

### Track

Use a string to represent the event name and a dictionary to represent the event properties. `properties` can be `nil`.

```objectivec
[[FilumBDP sharedInstance] track:@"Purchase" properties:@{
    @"total_amount": totalAmount
}];
```

```swift
GIAP.sharedInstance().track("Purchase", properties: {
    "total_amount": totalAmount
})
```

### Reset
Use this method right after user has just logged out

```objectivec
[[FilumBDP sharedInstance] reset];
```

```swift
GIAP.sharedInstance().reset()
```
