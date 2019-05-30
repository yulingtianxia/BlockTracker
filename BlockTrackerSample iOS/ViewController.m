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
    __unused BTTracker *tracker = [self bt_trackBlockArgOfSelector:@selector(performBlock:) callback:^(BHInvocation * _Nonnull invocation) {
        switch (invocation.token.mode) {
            case BlockHookModeBefore:
                NSLog(@"Before block:%@, mangleName:%@", invocation.token.block, invocation.token.mangleName);
                break;
            case BlockHookModeAfter:
                NSLog(@"After block:%@, mangleName:%@", invocation.token.block, invocation.token.mangleName);
                break;
            case BlockHookModeDead:
                NSLog(@"Block Dead! mangleName:%@", invocation.token.mangleName);
                break;
            default:
                break;
        }
    }];

    // invoke blocks
    __block NSString *word = @"I'm a block";
    [self performBlock:^{
        NSLog(@"%@", word);
    }];
    
//    void(^globalBlock)(void) = ^() {
//        NSLog(@"Global block!");
//    };
    
//    [self performBlock:globalBlock];
    setMallocBlockCallback(^(BHInvocation * _Nonnull invocation) {
        //        NSLog(@"type: %lu, mangleName: %@", (unsigned long)type, mangleName);
        switch (invocation.token.mode) {
            case BlockHookModeBefore:
                NSLog(@"Before block:%@, mangleName:%@", invocation.token.block, invocation.token.mangleName);
                break;
            case BlockHookModeAfter: {
                NSLog(@"After block:%@, mangleName:%@", invocation.token.block, invocation.token.mangleName);
                invocation.token.userInfo[@"invokeCount"] = @([invocation.token.userInfo[@"invokeCount"] integerValue] + 1);
//                __weak typeof(invocation.token.block) weakBlock = invocation.token.block;
//                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
//                    if (weakBlock) {
//                        NSLog(@"Block leak after invoking! mangleName:%@", invocation.token.mangleName);
//                    }
//                });
                break;
            }
            case BlockHookModeDead:
                if ([invocation.token.userInfo[@"invokeCount"] integerValue] == 0) {
                    NSLog(@"Block Dead without invoked! mangleName:%@", invocation.token.mangleName);
                }
                break;
            default:
                break;
        }
    });
    // stop tracker in future
//    [tracker stop];
    // blocks will die
}

- (void)increaseInvokeForBlock:(id)block
{
    double count = [self invokeCountOfBlock:block];
    objc_setAssociatedObject(block, @selector(invokeCountOfBlock:), @(count + 1), OBJC_ASSOCIATION_RETAIN);
}

- (double)invokeCountOfBlock:(id)block
{
    NSNumber *invokeCount = objc_getAssociatedObject(block, _cmd);
    return invokeCount.doubleValue;
}

- (void)performBlock:(void(^)(void))block {
    block();
}

@end
