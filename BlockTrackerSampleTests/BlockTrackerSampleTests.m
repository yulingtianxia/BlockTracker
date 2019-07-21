//
//  BlockTrackerSampleTests.m
//  BlockTrackerSampleTests
//
//  Created by 杨萧玉 on 2019/6/27.
//  Copyright © 2019 杨萧玉. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <BlockTracker/BlockTracker.h>

@interface BlockTrackerSampleTests : XCTestCase

@end

@implementation BlockTrackerSampleTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testTrackMethod {
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Wait for block invoke."];
    __unused BTTracker *tracker = [self bt_trackBlockArgOfSelector:@selector(performBlock:) callback:^(BHInvocation * _Nonnull invocation, int a) {
        switch (invocation.mode) {
            case BlockHookModeBefore:{
                NSAssert(a == 1, @"参数传递错误");
                NSDate *startDate = objc_getAssociatedObject(invocation.token, BTTrackDateAssociatedObjectKey);
                NSTimeInterval duration = -[startDate timeIntervalSinceNow];
                NSLog(@"Before block:%@, mangleName:%@, index:%@, duration:%f", invocation.token.block, invocation.token.mangleName, invocation.token.userInfo[BTArgumentIndexKey], duration);
                break;
            }
            case BlockHookModeAfter:{
                NSLog(@"After block:%@, mangleName:%@, index:%@", invocation.token.block, invocation.token.mangleName, invocation.token.userInfo[BTArgumentIndexKey]);
                objc_setAssociatedObject(invocation.token, @"invoked", @YES, OBJC_ASSOCIATION_RETAIN);
                break;
            }
            case BlockHookModeDead:{
                NSLog(@"Block Dead! mangleName:%@, index:%@", invocation.token.mangleName, invocation.token.userInfo[BTArgumentIndexKey]);
                BOOL invoked = [objc_getAssociatedObject(invocation.token, @"invoked") boolValue];
                if (!invoked) {
                    NSLog(@"Block Not Invoked Before Dead! %@", invocation.token.mangleName);
                }
                break;
            }
            default:
                break;
        }
    }];
    
    // invoke blocks
    NSString *word = @"I'm a block";
    [self performBlock:^(int a){
        NSLog(@"%@", word);
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:30];
}

- (void)testTrackAllMallocBlock {
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
}

- (void)performBlock:(void(^)(int))block {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        block(1);
    });
}

@end
