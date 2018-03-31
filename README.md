[![CI Status](http://img.shields.io/travis/yulingtianxia/BlockTracker.svg?style=flat)](https://travis-ci.org/yulingtianxia/BlockTracker)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![GitHub release](https://img.shields.io/github/release/yulingtianxia/blocktracker.svg)](https://github.com/yulingtianxia/BlockTracker/releases)
[![Twitter Follow](https://img.shields.io/twitter/follow/yulingtianxia.svg?style=social&label=Follow)](https://twitter.com/yulingtianxia)

# BlockTracker

BlockTracker can track block arguments of a method. It's based on [BlockHook](https://github.com/yulingtianxia/BlockHook).

## 📚 Article



## 🌟 Features

- [x] Easy to use.
- [x] Keep your code clear.
- [x] Reserve the whole arguments.
- [x] Self-managed trackers.
- [x] Support Carthage.

## 🔮 Example

The sample project "BlockTrackerSample" just only support iOS platform.

## 🐒 How to use

You can track blocks in arguments. This method returns a `BTTracker` instance for more control. You can `stop` a `BTTracker` when you don't want to track it anymore.

```
- (void)viewDidLoad {
    [super viewDidLoad];
    BTTracker *tracker = [self bt_trackBlockArgOfSelector:@selector(performBlock:) callback:^(id _Nullable block, BlockTrackerCallBackType type, void * _Nullable * _Null_unspecified args, void * _Nullable result, NSArray<NSString *> * _Nonnull callStackSymbols) {
        NSLog(@"%@", BlockTrackerCallBackTypeInvoke == type ? @"BlockTrackerCallBackTypeInvoke" : @"BlockTrackerCallBackTypeDead");
    }];
    // invoke blocks
    __block NSString *word = @"I'm a block";
    [self performBlock:^{
        NSLog(@"add '!!!' to word");
        word = [word stringByAppendingString:@"!!!"];
    }];
    [self performBlock:^{
        NSLog(@"%@", word);
    }];
    // stop tracker in future
//    [tracker stop];
    // blocks will die
}

- (void)performBlock:(void(^)(void))block {
    block();
}

@end
```

Here is the log:

```
add '!!!' to word
BlockTrackerCallBackTypeInvoke
I'm a block!!!
BlockTrackerCallBackTypeInvoke
BlockTrackerCallBackTypeDead
BlockTrackerCallBackTypeDead
```

## 📲 Installation

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

After importing libffi, just add the two files `BlockTracker.h/m` to your project.

## ❤️ Contributed

- If you **need help** or you'd like to **ask a general question**, open an issue.
- If you **found a bug**, open an issue.
- If you **have a feature request**, open an issue.
- If you **want to contribute**, submit a pull request.

## 👨🏻‍💻 Author

yulingtianxia, yulingtianxia@gmail.com

## 👮🏻 License

BlockTracker is available under the MIT license. See the LICENSE file for more info.

