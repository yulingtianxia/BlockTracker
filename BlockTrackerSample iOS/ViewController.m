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
//    __unused BTTracker *tracker = [self bt_trackBlockArgOfSelector:@selector(performBlock:) callback:^(BHInvocation * _Nonnull invocation) {
//        switch (invocation.token.mode) {
//            case BlockHookModeBefore:
//                NSLog(@"Before block:%@, mangleName:%@", invocation.token.block, invocation.token.mangleName);
//                break;
//            case BlockHookModeAfter:
//                NSLog(@"After block:%@, mangleName:%@", invocation.token.block, invocation.token.mangleName);
//                break;
//            case BlockHookModeDead:
//                NSLog(@"Block Dead! mangleName:%@", invocation.token.mangleName);
//                break;
//            default:
//                break;
//        }
//    }];

    setMallocBlockCallback(^(BHInvocation * _Nonnull invocation) {
        //        NSLog(@"type: %lu, mangleName: %@", (unsigned long)type, mangleName);
        switch (invocation.token.mode) {
            case BlockHookModeBefore:
                NSLog(@"Before block:%@, mangleName:%@", invocation.token.block, invocation.token.mangleName);
                break;
            case BlockHookModeAfter: {
                NSLog(@"After block:%@, mangleName:%@", invocation.token.block, invocation.token.mangleName);
                invocation.token.userInfo[@"invokeCount"] = @([invocation.token.userInfo[@"invokeCount"] integerValue] + 1);
                break;
            }
            case BlockHookModeDead: {
                NSInteger invokeCount = [invocation.token.userInfo[@"invokeCount"] integerValue];
                if (invokeCount == 0) {
                    NSLog(@"Block Dead without invoked! mangleName:%@", invocation.token.mangleName);
                }
                else {
                    NSLog(@"Block Dead with invoke count: %ld! mangleName:%@", (long)invokeCount, invocation.token.mangleName);
                }
                break;
            }
            default:
                break;
        }
    });
    
    // invoke blocks
    NSString *word = @"I'm a block";
    [self performBlock:^{
        NSLog(@"%@", word);
    }];
    
    //    void(^globalBlock)(void) = ^() {
    //        NSLog(@"Global block!");
    //    };
    
    //    [self performBlock:globalBlock];
    
    // stop tracker in future
//    [tracker stop];
    // blocks will die
}

- (void)performBlock:(void(^)(void))block {
    id b = block;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), b);
}

@end
