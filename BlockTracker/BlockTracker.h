//
//  BlockTracker.h
//  BlockTrackerSample
//
//  Created by 杨萧玉 on 2018/3/28.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, BlockTrackerCallbackType) {
    BlockTrackerCallbackTypeBefore,
    BlockTrackerCallbackTypeAfter,
    BlockTrackerCallbackTypeDead,
};

NS_ASSUME_NONNULL_BEGIN

/**
 追踪回调

 @param block 被追踪的 block
 @param type  追踪到的类型：Invoke 或 Dead
 @param args InvokeType 下为这次执行传入 block 的参数；DeadType 下为空
 @param result InvokeType 下为这次执行 block 的返回值；DeadType 下为空
 */
typedef void(^BlockTrackerCallback)(id _Nullable block, BlockTrackerCallbackType type, void *_Nullable *_Null_unspecified args, void *_Nullable result, NSString *mangleName);

/**
 获取元类
 
 @param cls 类对象
 @return 类对象的元类
 */
Class bt_metaClass(Class cls);

/**
 消息参数中 block 的追踪者。
 */
@interface BTTracker : NSObject

/**
 target, 可以为实例，类，元类(可以使用 bt_metaClass 函数获取元类）
 */
@property (nonatomic, weak, readonly) id target;

/**
 追踪消息的 SEL
 */
@property (nonatomic, readonly) SEL selector;
/**
 追踪是否在生效。
 */
@property (nonatomic, readonly, getter=isActive) BOOL active;

/**
 停止继续追踪新的方法调用传入的 block 参数，已追踪的 block 依然生效
 
 @return 停止成功返回 YES；如果追踪者不存在或不合法，则返回 NO
 */
- (BOOL)stop;

@end

@interface NSObject (BlockTracker)

@property (nonatomic, readonly) NSArray<BTTracker *> *bt_allTrackers;


/**
 追踪方法调用中的 block 参数
 
 @param selector 追踪 block 参数所属的方法
 @return 如果追踪成功则返回追踪者对象，否则返回 nil
 */
- (nullable BTTracker *)bt_trackBlockArgOfSelector:(SEL)selector callback:(BlockTrackerCallback)callback;

@end

typedef void (*BlockTrackerCallbackFP)(id, BlockTrackerCallbackType, void *_Nullable *_Null_unspecified, void *_Nullable, NSString *);

void trackAllBlocks(BlockTrackerCallbackFP before, BlockTrackerCallbackFP after, BlockTrackerCallbackFP dead);

NS_ASSUME_NONNULL_END


