//
//  BlockTracker.h
//  BlockTrackerSample
//
//  Created by 杨萧玉 on 2018/3/28.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, BlockTrackerCallBackType) {
    BlockTrackerCallBackTypeInvoke,
    BlockTrackerCallBackTypeDead,
};

NS_ASSUME_NONNULL_BEGIN

/**
 追踪回调

 @param block 被追踪的 block
 @param type  追踪到的类型：Invoke 或 Dead
 @param invokeCount block 参数被执行过的次数
 @param args InvokeType 下为这次执行传入 block 的参数；DeadType 下为空
 @param result InvokeType 下为这次执行 block 的返回值；DeadType 下为空
 @param callStackSymbols 堆栈信息
 */
typedef void(^BlockTrackerCallbackBlock)(id _Nullable block, BlockTrackerCallBackType type, NSInteger invokeCount, void *_Nullable *_Null_unspecified args, void *_Nullable result, NSArray<NSString *> *callStackSymbols);

/**
 获取元类
 
 @param cls 类对象
 @return 类对象的元类
 */
Class bt_metaClass(Class cls);

/**
 消息节流的追踪者。durationThreshold = 0.1，则代表 0.1 秒内最多发送一次消息，多余的消息会被忽略掉。
 */
@interface BTTracker : NSObject

/**
 target, 可以为实例，类，元类(可以使用 bt_metaClass 函数获取元类）
 */
@property (nonatomic, weak, readonly) id target;

/**
 节流消息的 SEL
 */
@property (nonatomic, readonly) SEL selector;

/**
 停止继续追踪新的方法调用传入的 block 参数，已追踪的 block 依然生效
 
 @return 停止成功返回 YES；如果追踪者不存在或不合法，则返回 NO
 */
- (BOOL)stop;

@end

@interface NSObject (BlockTracker)

@property (nonatomic, readonly) NSArray<BTTracker *> *bt_allTrackers;


/**
 对方法调用限频
 
 @param selector 限频的方法
 @return 如果限频成功则返回追踪者对象，否则返回 nil
 */
- (nullable BTTracker *)bt_trackBlockArgOfSelector:(SEL)selector callback:(BlockTrackerCallbackBlock)callback;

@end

NS_ASSUME_NONNULL_END
