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
    // Do any additional setup after loading the view, typically from a nib.
    [self bt_trackBlockArgOfSelector:@selector(performBlock:) callback:^(id  _Nonnull block, BlockTrackerCallBackType type, void * _Nonnull result, NSArray<NSString *> * _Nonnull callStackSymbols) {
        NSLog(@"xixi");
    }];
    
    NSString *hehe = @"hehe";
    [self performBlock:^{
        NSLog(hehe);
    }];
}

- (void)performBlock:(void(^)(void))block {
    block();
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
