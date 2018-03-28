//
//  ViewController.m
//  BlockTrackerSample
//
//  Created by 杨萧玉 on 2018/3/28.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//

#import "ViewController.h"
#import "BlockTracker.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [mt_metaClass(UIView.self) bt_trackBlockArgOfSelector:@selector(animateWithDuration:animations:) callback:^(id  _Nonnull block, BlockTrackerCallBackType type, void * _Nonnull result, NSArray<NSString *> * _Nonnull callStackSymbols) {

    }];
    
    [UIView animateWithDuration:0.1 animations:^{
        NSLog(@"hehe");
    }];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
