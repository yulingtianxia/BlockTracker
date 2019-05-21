//
//  ViewController.m
//  BlockTrackerSample macOS
//
//  Created by 杨萧玉 on 2019/5/12.
//  Copyright © 2019 杨萧玉. All rights reserved.
//

#import "ViewController.h"

void bt_before_Block_invoke(void) {
    NSLog(@"Before");
}
void bt_after_Block_invoke(void) {
    NSLog(@"After");
}
void bt_when_Block_dead(void) {
    NSLog(@"Dead");
}

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    trackAllBlocks(bt_before_Block_invoke, bt_after_Block_invoke, bt_when_Block_dead);
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
