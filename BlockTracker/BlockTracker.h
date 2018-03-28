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

typedef void(^BlockTrackerCallbackBlock)(id block, BlockTrackerCallBackType type, void *result, NSArray<NSString *> *callStackSymbols);

/**
 获取元类
 
 @param cls 类对象
 @return 类对象的元类
 */
Class mt_metaClass(Class cls);

/**
 消息节流的规则。durationThreshold = 0.1，则代表 0.1 秒内最多发送一次消息，多余的消息会被忽略掉。
 */
@interface MTRule : NSObject

/**
 target, 可以为实例，类，元类(可以使用 mt_metaClass 函数获取元类）
 */
@property (nonatomic, weak, readonly) id target;

/**
 节流消息的 SEL
 */
@property (nonatomic, readonly) SEL selector;



- (instancetype)initWithTarget:(id)target selector:(SEL)selector NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/**
 应用规则，会覆盖已有的规则
 
 @return 更新成功返回 YES；如果规则不合法或继承链上已有相同 selector 的规则，则返回 NO
 */
- (BOOL)apply;

/**
 废除规则
 
 @return 废除成功返回 YES；如果规则不存在或不合法，则返回 NO
 */
- (BOOL)discard;

@end

@interface MTEngine : NSObject

@property (nonatomic, class, readonly) MTEngine *defaultEngine;
@property (nonatomic, readonly) NSArray<MTRule *> *allRules;

/**
 应用规则，会覆盖已有的规则
 
 @param rule MTRule 对象
 @return 更新成功返回 YES；如果规则不合法或继承链上已有相同 selector 的规则，则返回 NO
 */
- (BOOL)applyRule:(MTRule *)rule;

/**
 废除规则
 
 @param rule MTRule 对象
 @return 废除成功返回 YES；如果规则不存在或不合法，则返回 NO
 */
- (BOOL)discardRule:(MTRule *)rule;

@end

@interface NSObject (BlockTracker)

@property (nonatomic, readonly) NSArray<MTRule *> *mt_allRules;


/**
 对方法调用限频
 
 @param selector 限频的方法
 @return 如果限频成功则返回规则对象，否则返回 nil
 */
- (nullable MTRule *)bt_trackBlockArgOfSelector:(SEL)selector callback:(BlockTrackerCallbackBlock)callback;

@end

NS_ASSUME_NONNULL_END
