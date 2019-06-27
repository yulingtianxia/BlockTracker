<p align="center">
<a href="https://github.com/yulingtianxia/BlockTracker">
<img src="Assets/logo.png" alt="BlockTracker" />
</a>
</p>

[![CI Status](http://img.shields.io/travis/yulingtianxia/BlockTracker.svg?style=flat)](https://travis-ci.org/yulingtianxia/BlockTracker)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![GitHub release](https://img.shields.io/github/release/yulingtianxia/blocktracker.svg)](https://github.com/yulingtianxia/BlockTracker/releases)
[![Twitter Follow](https://img.shields.io/twitter/follow/yulingtianxia.svg?style=social&label=Follow)](https://twitter.com/yulingtianxia)

# BlockTracker

BlockTracker can track block arguments of a method. It's based on [BlockHook](https://github.com/yulingtianxia/BlockHook).

## 📚 Article

[追踪 Objective-C 方法中的 Block 参数对象](http://yulingtianxia.com/blog/2018/03/31/Track-Block-Arguments-of-Objective-C-Method/)

## 🌟 Features

- [x] Easy to use.
- [x] Keep your code clear.
- [x] Let you modify return value and arguments.
- [x] Trace all block args of method.
- [x] Trace all `NSMallocBlock`.
- [x] Self-managed trackers.
- [x] Support CocoaPods & Carthage.

## 🔮 Example

The sample project "BlockTrackerSample" just only support iOS platform.

## 🐒 How to use

### Track blocks in method
You can track blocks in arguments. This method returns a `BTTracker` instance for more control. You can `stop` a `BTTracker` when you don't want to track it anymore.

```
__unused BTTracker *tracker = [self bt_trackBlockArgOfSelector:@selector(performBlock:) callback:^(BHInvocation * _Nonnull invocation) {
        switch (invocation.mode) {
            case BlockHookModeBefore:
                NSLog(@"Before block:%@, mangleName:%@", invocation.token.block, invocation.token.mangleName);
                break;
            case BlockHookModeAfter:
                NSLog(@"After block:%@, mangleName:%@", invocation.token.block, invocation.token.mangleName);
                objc_setAssociatedObject(invocation.token, @"invoked", @YES, OBJC_ASSOCIATION_RETAIN);
                break;
            case BlockHookModeDead:
                NSLog(@"Block Dead! mangleName:%@", invocation.token.mangleName);
                BOOL invoked = [objc_getAssociatedObject(invocation.token, @"invoked") boolValue];
                if (!invoked) {
                    NSLog(@"Block Not Invoked Before Dead! %@", invocation.token.mangleName);
                }
                break;
            default:
                break;
        }
    }];
    
    // invoke blocks
    NSString *word = @"I'm a block";
    [self performBlock:^{
        NSLog(@"%@", word);
    }];
    // stop tracker in future
//    [tracker stop];
    // blocks will die
}

- (void)performBlock:(void(^)(void))block {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

@end
```

Here is the log:

```
Hook Block Arg mangleName:__42-[BlockTrackerSampleTests testTrackMethod]_block_invoke_2, in selector:performBlock:
Before block:<__NSMallocBlock__: 0x600000c71aa0>, mangleName:__42-[BlockTrackerSampleTests testTrackMethod]_block_invoke_2
I'm a block
After block:<__NSMallocBlock__: 0x600000c71aa0>, mangleName:__42-[BlockTrackerSampleTests testTrackMethod]_block_invoke_2
Block Dead! mangleName:__42-[BlockTrackerSampleTests testTrackMethod]_block_invoke_2
```

### Track a batch of blocks.

```
setMallocBlockCallback(^(BHInvocation * _Nonnull invocation) {
        switch (invocation.mode) {
            case BlockHookModeBefore: {
                NSLog(@"Before block:%@, mangleName:%@", invocation.token.block, invocation.token.mangleName);
                break;
            }
            case BlockHookModeAfter: {
                NSLog(@"After block:%@, mangleName:%@", invocation.token.block, invocation.token.mangleName);
                objc_setAssociatedObject(invocation.token, @"invoked", @YES, OBJC_ASSOCIATION_RETAIN);
                break;
            }
            case BlockHookModeDead: {
                NSLog(@"Block Dead! mangleName:%@", invocation.token.mangleName);
                BOOL invoked = [objc_getAssociatedObject(invocation.token, @"invoked") boolValue];
                if (!invoked) {
                    NSLog(@"Block Not Invoked Before Dead! %@", invocation.token.mangleName);
                }
                break;
            }
            default:
                break;
        }
    });
```

## 📲 Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

To integrate BlockTracker into your Xcode project using CocoaPods, specify it in your `Podfile`:


```
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!
target 'MyApp' do
	pod 'BlockTracker'
end
```

You need replace "MyApp" with your project's name.

Then, run the following command:

```bash
$ pod install
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate BlockTracker into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "yulingtianxia/BlockTracker"
```

Run `carthage update` to build the framework and drag the built `BlockTrackerKit.framework` into your Xcode project.

### Manual

Just drag source files in `BlockTracker` folder to your project.

## ❤️ Contributed

- If you **need help** or you'd like to **ask a general question**, open an issue.
- If you **found a bug**, open an issue.
- If you **have a feature request**, open an issue.
- If you **want to contribute**, submit a pull request.

## 👨🏻‍💻 Author

yulingtianxia, yulingtianxia@gmail.com

## 👮🏻 License

BlockTracker is available under the MIT license. See the LICENSE file for more info.

