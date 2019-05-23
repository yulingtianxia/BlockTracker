//
//  ViewController.m
//  BlockTrackerSample
//
//  Created by 杨萧玉 on 2018/3/28.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//

#import "ViewController.h"
#import "BlockTracker.h"
#import <objc/runtime.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Begin Track
//    __unused BTTracker *tracker = [self bt_trackBlockArgOfSelector:@selector(performBlock:) callback:^(id  _Nullable block, BlockTrackerCallbackType type, void * _Nullable * _Null_unspecified args, void * _Nullable result, NSString * _Nullable mangleName) {
//
//    }];
//    // invoke blocks
//    __block NSString *word = @"I'm a block";
//    [self performBlock:^{
//        NSLog(@"add '!!!' to word");
//        word = [word stringByAppendingString:@"!!!"];
//    }];
//    [self performBlock:^{
//        NSLog(@"%@", word);
//    }];
    trackAllBlocks(^(id  _Nullable block, BlockTrackerCallbackType type, void * _Nullable * _Null_unspecified args, void * _Nullable result, NSString * _Nullable mangleName) {
        NSLog(@"type: %lu, mangleName: %@", (unsigned long)type, mangleName);
    });
    // stop tracker in future
//    [tracker stop];
    // blocks will die
}

- (void)performBlock:(void(^)(void))block {
    block();
}

@end
