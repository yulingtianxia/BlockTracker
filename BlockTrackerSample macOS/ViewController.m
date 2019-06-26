//
//  ViewController.m
//  BlockTrackerSample macOS
//
//  Created by 杨萧玉 on 2019/5/12.
//  Copyright © 2019 杨萧玉. All rights reserved.
//

#import "ViewController.h"
#import "BlockTracker.h"
#import <objc/runtime.h>

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Begin Track
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
