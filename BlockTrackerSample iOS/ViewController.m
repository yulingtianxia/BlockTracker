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

void bt_before_Block_invoke(id block) {
    NSLog(@"Before %@", block);
}
void bt_after_Block_invoke(void) {
    NSLog(@"After");
}
void bt_when_Block_dead(void) {
    NSLog(@"Dead");
}

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Begin Track
    __unused BTTracker *tracker = [self bt_trackBlockArgOfSelector:@selector(performBlock:) callback:^(id  _Nullable block, BlockTrackerCallbackType type, NSInteger invokeCount, void * _Nullable * _Null_unspecified args, void * _Nullable result, NSArray<NSString *> * _Nonnull callStackSymbols, NSString * _Nullable mangleName) {
        NSLog(@"%@ invoke count = %ld", BlockTrackerCallbackTypeInvoke == type ? @"BlockTrackerCallBackTypeInvoke" : @"BlockTrackerCallBackTypeDead", (long)invokeCount);
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
//    trackAllBlocks(bt_before_Block_invoke, bt_after_Block_invoke, bt_when_Block_dead);
    // stop tracker in future
//    [tracker stop];
    // blocks will die
}

- (void)performBlock:(void(^)(void))block {
    block();
}

@end
