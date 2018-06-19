//
//  BlockTracker.m
//  BlockTrackerSample
//
//  Created by 杨萧玉 on 2018/3/28.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//

#import "BlockTracker.h"
#import <BlockHookKit/BlockHookKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <pthread.h>

#if !__has_feature(objc_arc)
#error
#endif

static inline BOOL bt_object_isClass(id _Nullable obj)
{
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0 || __TV_OS_VERSION_MIN_REQUIRED >= __TVOS_9_0 || __WATCH_OS_VERSION_MIN_REQUIRED >= __WATCHOS_2_0 || __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_10
    return object_isClass(obj);
#else
    if (!obj) return NO;
    return obj == [obj class];
#endif
}

Class bt_metaClass(Class cls)
{
    if (class_isMetaClass(cls)) {
        return cls;
    }
    return object_getClass(cls);
}

static const char *BHSizeAndAlignment(const char *str, NSUInteger *sizep, NSUInteger *alignp, long *len)
{
    const char *out = NSGetSizeAndAlignment(str, sizep, alignp);
    if(len)
        *len = out - str;
    while(isdigit(*out))
        out++;
    return out;
}

@interface BTDealloc : NSObject

@property (nonatomic) BTTracker *tracker;
@property (nonatomic) Class cls;
@property (nonatomic) pthread_mutex_t invokeLock;

@end

@interface BTTracker ()

@property (nonatomic) BlockTrackerCallbackBlock callback;
@property (nonatomic) NSArray<NSNumber *> *blockArgIndex;

- (instancetype)initWithTarget:(id)target selector:(SEL)selector;

/**
 应用追踪者
 
 @return 更新成功返回 YES；如果追踪者不合法或继承链上已有相同 selector 的追踪者，则返回 NO
 */
- (BOOL)apply;

@end

@interface BTEngine : NSObject

@property (nonatomic, class, readonly) BTEngine *defaultEngine;
@property (nonatomic) NSMapTable<id, NSMutableSet<NSString *> *> *targetSELs;
@property (nonatomic) NSMapTable *aliasSelectorCache;

/**
 应用追踪者
 
 @param tracker BTTracker 对象
 @return 更新成功返回 YES；如果追踪者不合法或继承链上已有相同 selector 的追踪者，则返回 NO
 */
- (BOOL)applyTracker:(BTTracker *)tracker;

/**
 停止追踪者
 
 @param tracker BTTracker 对象
 @return 停止成功返回 YES；如果追踪者不存在或不合法，则返回 NO
 */
- (BOOL)stopTracker:(BTTracker *)tracker;

- (void)stopTracker:(BTTracker *)tracker whenTargetDealloc:(BTDealloc *)btDealloc;

- (NSArray<BTTracker *> *)allTrackers;

@end


@implementation BTDealloc

- (void)dealloc
{
    SEL selector = NSSelectorFromString(@"stopTracker:whenTargetDealloc:");
    ((void (*)(id, SEL, BTTracker *, BTDealloc *))[BTEngine.defaultEngine methodForSelector:selector])(BTEngine.defaultEngine, selector, self.tracker, self);
}

@end

@implementation BTTracker

- (instancetype)initWithTarget:(id)target selector:(SEL)selector
{
    self = [super init];
    if (self) {
        _target = target;
        _selector = selector;
    }
    return self;
}

- (BOOL)apply
{
    return [BTEngine.defaultEngine applyTracker:self];
}

- (BOOL)stop
{
    return [BTEngine.defaultEngine stopTracker:self];
}

- (BTDealloc *)bt_deallocObject
{
    BTDealloc *btDealloc = objc_getAssociatedObject(self.target, self.selector);
    return btDealloc;
}

@end

@implementation BTEngine

static pthread_mutex_t mutex;
static pthread_mutex_t alias_selector_mutex;

+ (instancetype)defaultEngine
{
    static dispatch_once_t onceToken;
    static BTEngine *instance;
    dispatch_once(&onceToken, ^{
        instance = [BTEngine new];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _targetSELs = [NSMapTable weakToStrongObjectsMapTable];
        _aliasSelectorCache = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSMapTableObjectPointerPersonality valueOptions:NSPointerFunctionsOpaqueMemory | NSMapTableObjectPointerPersonality];
        pthread_mutex_init(&mutex, NULL);
        pthread_mutex_init(&alias_selector_mutex, NULL);
    }
    return self;
}

- (NSArray<BTTracker *> *)allTrackers
{
    pthread_mutex_lock(&mutex);
    NSMutableArray *trackers = [NSMutableArray array];
    for (id target in [[self.targetSELs keyEnumerator] allObjects]) {
        NSMutableSet *selectors = [self.targetSELs objectForKey:target];
        for (NSString *selectorName in selectors) {
            BTDealloc *btDealloc = objc_getAssociatedObject(target, NSSelectorFromString(selectorName));
            [trackers addObject:btDealloc.tracker];
        }
    }
    pthread_mutex_unlock(&mutex);
    return [trackers copy];
}

/**
 添加 target-selector 记录
 
 @param selector 方法名
 @param target 对象，类，元类
 */
- (void)addSelector:(SEL)selector onTarget:(id)target
{
    if (!target) {
        return;
    }
    NSMutableSet *selectors = [self.targetSELs objectForKey:target];
    if (!selectors) {
        selectors = [NSMutableSet set];
    }
    [selectors addObject:NSStringFromSelector(selector)];
    [self.targetSELs setObject:selectors forKey:target];
}

/**
 移除 target-selector 记录
 
 @param selector 方法名
 @param target 对象，类，元类
 */
- (void)removeSelector:(SEL)selector onTarget:(id)target
{
    if (!target) {
        return;
    }
    NSMutableSet *selectors = [self.targetSELs objectForKey:target];
    if (!selectors) {
        selectors = [NSMutableSet set];
    }
    [selectors removeObject:NSStringFromSelector(selector)];
    [self.targetSELs setObject:selectors forKey:target];
}

/**
 是否存在 target-selector 记录
 
 @param selector 方法名
 @param target 对象，类，元类
 @return 是否存在记录
 */
- (BOOL)containsSelector:(SEL)selector onTarget:(id)target
{
    return [[self.targetSELs objectForKey:target] containsObject:NSStringFromSelector(selector)];
}

/**
 是否存在 target-selector 记录，未指定具体 target，但 target 的类型为 cls 即可
 
 @param selector 方法名
 @param cls 类
 @return 是否存在记录
 */
- (BOOL)containsSelector:(SEL)selector onTargetsOfClass:(Class)cls
{
    for (id target in [[self.targetSELs keyEnumerator] allObjects]) {
        if (!bt_object_isClass(target) &&
            [target isMemberOfClass:cls] &&
            [[self.targetSELs objectForKey:target] containsObject:NSStringFromSelector(selector)]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)applyTracker:(BTTracker *)tracker
{
    pthread_mutex_lock(&mutex);
    __block BOOL shouldApply = YES;
    if (bt_checkTrackerValid(tracker)) {
        for (id target in [[self.targetSELs keyEnumerator] allObjects]) {
            NSMutableSet *selectors = [self.targetSELs objectForKey:target];
            for (NSString *selectorName in selectors) {
                if (sel_isEqual(tracker.selector, NSSelectorFromString(selectorName))
                    && bt_object_isClass(tracker.target)
                    && bt_object_isClass(target)) {
                    Class clsA = tracker.target;
                    Class clsB = target;
                    shouldApply = !([clsA isSubclassOfClass:clsB] || [clsB isSubclassOfClass:clsA]) && shouldApply;
                    NSCAssert(shouldApply, @"Error: %@ already apply tracker in %@. A message can only have one tracker per class hierarchy.", selectorName, NSStringFromClass(clsB));
                }
            }
        }
        if (shouldApply) {
            [self addSelector:tracker.selector onTarget:tracker.target];
            bt_overrideMethod(tracker.target, tracker.selector);
            bt_configureTargetDealloc(tracker);
        }
    }
    else {
        shouldApply = NO;
    }
    pthread_mutex_unlock(&mutex);
    return shouldApply;
}

- (BOOL)stopTracker:(BTTracker *)tracker
{
    pthread_mutex_lock(&mutex);
    BOOL shouldDiscard = NO;
    if (bt_checkTrackerValid(tracker)) {
        [self removeSelector:tracker.selector onTarget:tracker.target];
        shouldDiscard = bt_recoverMethod(tracker.target, tracker.selector);
    }
    pthread_mutex_unlock(&mutex);
    return shouldDiscard;
}

- (void)stopTracker:(BTTracker *)tracker whenTargetDealloc:(BTDealloc *)btDealloc
{
    if (bt_object_isClass(tracker.target)) {
        return;
    }
    pthread_mutex_lock(&mutex);
    if (![self containsSelector:tracker.selector onTarget:btDealloc.cls] &&
        ![self containsSelector:tracker.selector onTargetsOfClass:btDealloc.cls]) {
        bt_revertHook(btDealloc.cls, tracker.selector);
    }
    pthread_mutex_unlock(&mutex);
}

#pragma mark - Private Helper

static BOOL bt_checkTrackerValid(BTTracker *tracker)
{
    if (tracker.target && tracker.selector && tracker.callback) {
        NSString *selectorName = NSStringFromSelector(tracker.selector);
        if ([selectorName isEqualToString:@"forwardInvocation:"]) {
            return NO;
        }
        Class cls = bt_classOfTarget(tracker.target);
        NSString *className = NSStringFromClass(cls);
        if ([className isEqualToString:@"BTTracker"] || [className isEqualToString:@"BTEngine"]) {
            return NO;
        }
        return YES;
    }
    return NO;
}

static SEL bt_aliasForSelector(Class cls, SEL selector)
{
    pthread_mutex_lock(&alias_selector_mutex);
    SEL aliasSelector = (__bridge void *)[BTEngine.defaultEngine.aliasSelectorCache objectForKey:(__bridge id)(void *)selector];
    if (!aliasSelector) {
        NSString *selectorName = NSStringFromSelector(selector);
        aliasSelector = NSSelectorFromString([NSString stringWithFormat:@"__bt_%@", selectorName]);
        [BTEngine.defaultEngine.aliasSelectorCache setObject:(__bridge id)(void *)aliasSelector forKey:(__bridge id)(void *)selector];
    }
    pthread_mutex_unlock(&alias_selector_mutex);
    return aliasSelector;
}

/**
 处理执行 NSInvocation
 
 @param invocation NSInvocation 对象
 @param fixedSelector 修正后的 SEL
 */
static void bt_handleInvocation(NSInvocation *invocation, SEL fixedSelector)
{
    BTDealloc *btDealloc = objc_getAssociatedObject(invocation.target, invocation.selector);
    BTTracker *tracker = btDealloc.tracker;
    if (!tracker) {
        btDealloc = objc_getAssociatedObject(object_getClass(invocation.target), invocation.selector);
        tracker = btDealloc.tracker;
    }
    
    [invocation retainArguments];
    
    for (NSNumber *index in tracker.blockArgIndex) {
        if (index.integerValue < invocation.methodSignature.numberOfArguments) {
            __unsafe_unretained id block;
            [invocation getArgument:&block atIndex:index.integerValue];
            __weak typeof(block) weakBlock = block;
            __weak typeof(tracker) weakTracker = tracker;
            BHToken *tokenAfter = [block block_hookWithMode:BlockHookModeAfter usingBlock:^(BHToken *token) {
                __strong typeof(weakBlock) strongBlock = weakBlock;
                __strong typeof(weakTracker) strongTracker = weakTracker;
                NSNumber *invokeCount = objc_getAssociatedObject(token, NSSelectorFromString(@"invokeCount"));
                if (!invokeCount) {
                    invokeCount = @(1);
                }
                else {
                    invokeCount = [NSNumber numberWithInt:invokeCount.intValue + 1];
                }
                objc_setAssociatedObject(token, NSSelectorFromString(@"invokeCount"), invokeCount, OBJC_ASSOCIATION_RETAIN);
                if (strongTracker.callback) {
                    strongTracker.callback(strongBlock, BlockTrackerCallbackTypeInvoke, invokeCount.intValue, token.args, token.retValue, [NSThread callStackSymbols], token.mangleName);
                }
            }];

            [block block_hookWithMode:BlockHookModeDead usingBlock:^(BHToken *token) {
                __strong typeof(weakTracker) strongTracker = weakTracker;
                NSNumber *invokeCount = objc_getAssociatedObject(tokenAfter, NSSelectorFromString(@"invokeCount"));
                if (strongTracker.callback) {
                    strongTracker.callback(nil, BlockTrackerCallbackTypeDead, invokeCount.intValue, nil, nil, [NSThread callStackSymbols], token.mangleName);
                }
            }];
        }
    }
    invocation.selector = fixedSelector;
    [invocation invoke];
}

static void bt_forwardInvocation(__unsafe_unretained id assignSlf, SEL selector, NSInvocation *invocation)
{
    SEL originalSelector = invocation.selector;
    SEL fixedOriginalSelector = bt_aliasForSelector(object_getClass(assignSlf), originalSelector);
    if (![assignSlf respondsToSelector:fixedOriginalSelector]) {
        bt_executeOrigForwardInvocation(assignSlf, selector, invocation);
        return;
    }
    BTDealloc *btDealloc = objc_getAssociatedObject(invocation.target, originalSelector);
    pthread_mutex_t mutex = btDealloc.invokeLock;
    pthread_mutex_lock(&mutex);
    bt_handleInvocation(invocation, fixedOriginalSelector);
    pthread_mutex_unlock(&mutex);
}

static NSString *const BTForwardInvocationSelectorName = @"__bt_forwardInvocation:";

static Class bt_classOfTarget(id target)
{
    Class cls;
    if (bt_object_isClass(target)) {
        cls = target;
    }
    else {
        cls = object_getClass(target);
    }
    return cls;
}

static void bt_overrideMethod(id target, SEL selector)
{
    Class cls = bt_classOfTarget(target);
    
    Method originMethod = class_getInstanceMethod(cls, selector);
    if (!originMethod) {
        NSCAssert(NO, @"unrecognized selector -%@ for class %@", NSStringFromSelector(selector), NSStringFromClass(cls));
        return;
    }
    const char *originType = (char *)method_getTypeEncoding(originMethod);
    
    IMP originalImp = class_respondsToSelector(cls, selector) ? class_getMethodImplementation(cls, selector) : NULL;
    
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    if (originType[0] == _C_STRUCT_B) {
        //In some cases that returns struct, we should use the '_stret' API:
        //http://sealiesoftware.com/blog/archive/2008/10/30/objc_explain_objc_msgSend_stret.html
        // As an ugly internal runtime implementation detail in the 32bit runtime, we need to determine of the method we hook returns a struct or anything larger than id.
        // https://developer.apple.com/library/mac/documentation/DeveloperTools/Conceptual/LowLevelABI/000-Introduction/introduction.html
        // https://github.com/ReactiveCocoa/ReactiveCocoa/issues/783
        // http://infocenter.arm.com/help/topic/com.arm.doc.ihi0042e/IHI0042E_aapcs.pdf (Section 5.4)
        //NSMethodSignature knows the detail but has no API to return, we can only get the info from debugDescription.
        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:originType];
        if ([methodSignature.debugDescription rangeOfString:@"is special struct return? YES"].location != NSNotFound) {
            msgForwardIMP = (IMP)_objc_msgForward_stret;
        }
    }
#endif
    
    if (originalImp == msgForwardIMP) {
        return;
    }
    
    if (class_getMethodImplementation(cls, @selector(forwardInvocation:)) != (IMP)bt_forwardInvocation) {
        IMP originalForwardImp = class_replaceMethod(cls, @selector(forwardInvocation:), (IMP)bt_forwardInvocation, "v@:@");
        if (originalForwardImp) {
            class_addMethod(cls, NSSelectorFromString(BTForwardInvocationSelectorName), originalForwardImp, "v@:@");
        }
    }
    
    if (class_respondsToSelector(cls, selector)) {
        SEL fixedOriginalSelector = bt_aliasForSelector(cls, selector);
        if(!class_respondsToSelector(cls, fixedOriginalSelector)) {
            class_addMethod(cls, fixedOriginalSelector, originalImp, originType);
        }
    }
    
    // Replace the original selector at last, preventing threading issus when
    // the selector get called during the execution of `overrideMethod`
    class_replaceMethod(cls, selector, msgForwardIMP, originType);
}

static void bt_revertHook(Class cls, SEL selector)
{
    if (class_getMethodImplementation(cls, @selector(forwardInvocation:)) == (IMP)bt_forwardInvocation) {
        IMP originalForwardImp = class_getMethodImplementation(cls, NSSelectorFromString(BTForwardInvocationSelectorName));
        if (originalForwardImp) {
            class_replaceMethod(cls, @selector(forwardInvocation:), originalForwardImp, "v@:@");
        }
    }
    else {
        return;
    }
    
    Method originMethod = class_getInstanceMethod(cls, selector);
    if (!originMethod) {
        NSCAssert(NO, @"unrecognized selector -%@ for class %@", NSStringFromSelector(selector), NSStringFromClass(cls));
        return;
    }
    const char *originType = (char *)method_getTypeEncoding(originMethod);
    
    SEL fixedOriginalSelector = bt_aliasForSelector(cls, selector);
    if (class_respondsToSelector(cls, fixedOriginalSelector)) {
        IMP originalImp = class_getMethodImplementation(cls, fixedOriginalSelector);
        class_replaceMethod(cls, selector, originalImp, originType);
    }
}

static BOOL bt_recoverMethod(id target, SEL selector)
{
    Class cls;
    if (bt_object_isClass(target)) {
        cls = target;
        if ([BTEngine.defaultEngine containsSelector:selector onTargetsOfClass:cls]) {
            return NO;
        }
    }
    else {
        cls = object_getClass(target);
        if ([BTEngine.defaultEngine containsSelector:selector onTarget:cls] ||
            [BTEngine.defaultEngine containsSelector:selector onTargetsOfClass:cls]) {
            return NO;
        }
    }
    bt_revertHook(cls, selector);
    return YES;
}

static void bt_executeOrigForwardInvocation(id slf, SEL selector, NSInvocation *invocation)
{
    SEL origForwardSelector = NSSelectorFromString(BTForwardInvocationSelectorName);
    
    if ([slf respondsToSelector:origForwardSelector]) {
        NSMethodSignature *methodSignature = [slf methodSignatureForSelector:origForwardSelector];
        if (!methodSignature) {
            NSCAssert(NO, @"unrecognized selector -%@ for instance %@", NSStringFromSelector(origForwardSelector), slf);
            return;
        }
        NSInvocation *forwardInv= [NSInvocation invocationWithMethodSignature:methodSignature];
        [forwardInv setTarget:slf];
        [forwardInv setSelector:origForwardSelector];
        [forwardInv setArgument:&invocation atIndex:2];
        [forwardInv invoke];
    } else {
        Class superCls = [[slf class] superclass];
        Method superForwardMethod = class_getInstanceMethod(superCls, @selector(forwardInvocation:));
        void (*superForwardIMP)(id, SEL, NSInvocation *);
        superForwardIMP = (void (*)(id, SEL, NSInvocation *))method_getImplementation(superForwardMethod);
        superForwardIMP(slf, @selector(forwardInvocation:), invocation);
    }
}

static void bt_configureTargetDealloc(BTTracker *tracker)
{
    Class cls = object_getClass(tracker.target);
    BTDealloc *btDealloc = [tracker bt_deallocObject];
    if (!btDealloc) {
        btDealloc = [BTDealloc new];
        btDealloc.tracker = tracker;
        btDealloc.cls = cls;
        pthread_mutexattr_t attr;
        pthread_mutexattr_init(&attr);
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_t mutex;
        pthread_mutex_init(&mutex, &attr);
        btDealloc.invokeLock = mutex;
        objc_setAssociatedObject(tracker.target, tracker.selector, btDealloc, OBJC_ASSOCIATION_RETAIN);
    }
}

@end

@implementation NSObject (BlockTracker)

- (NSArray<BTTracker *> *)bt_allTrackers
{
    NSMutableArray<BTTracker *> *result = [NSMutableArray array];
    for (BTTracker *tracker in BTEngine.defaultEngine.allTrackers) {
        if (tracker.target == self || object_getClass(self) == tracker.target) {
            [result addObject:tracker];
        }
    }
    return [result copy];
}

- (nullable BTTracker *)bt_trackBlockArgOfSelector:(SEL)selector callback:(BlockTrackerCallbackBlock)callback
{
    Class cls = bt_classOfTarget(self);
    
    Method originMethod = class_getInstanceMethod(cls, selector);
    if (!originMethod) {
        return nil;
    }
    const char *originType = (char *)method_getTypeEncoding(originMethod);
    if (![[NSString stringWithUTF8String:originType] containsString:@"@?"]) {
        return nil;
    }
    NSMutableArray *blockArgIndex = [NSMutableArray array];
    int argIndex = 0; // return type is the first one
    while(originType && *originType)
    {
        originType = BHSizeAndAlignment(originType, NULL, NULL, NULL);
        if ([[NSString stringWithUTF8String:originType] hasPrefix:@"@?"]) {
            [blockArgIndex addObject:@(argIndex)];
        }
        argIndex++;
    }

    BTDealloc *btDealloc = objc_getAssociatedObject(self, selector);
    BTTracker *tracker = btDealloc.tracker;
    if (!tracker) {
        tracker = [[BTTracker alloc] initWithTarget:self selector:selector];
    }
    tracker.callback = callback;
    tracker.blockArgIndex = [blockArgIndex copy];
    return [tracker apply] ? tracker : nil;
}

@end
