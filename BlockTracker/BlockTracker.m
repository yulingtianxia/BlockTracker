//
//  BlockTracker.m
//  BlockTrackerSample
//
//  Created by 杨萧玉 on 2018/3/28.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//

#import "BlockTracker.h"
#import <BlockHook/BlockHook.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <pthread.h>
#import <mach-o/getsect.h>
#import "fishhook.h"
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

static const char *BTSizeAndAlignment(const char *str, NSUInteger *sizep, NSUInteger *alignp, long *len)
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

- (void)lock;
- (void)unlock;

@end

@interface BTEngine : NSObject

@property (nonatomic, class, readonly) BTEngine *defaultEngine;
@property (nonatomic) NSMapTable<id, NSMutableSet<NSString *> *> *targetSELs;
@property (nonatomic) NSMutableSet<Class> *classHooked;

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

- (instancetype)init
{
    self = [super init];
    if (self) {
        pthread_mutexattr_t attr;
        pthread_mutexattr_init(&attr);
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_invokeLock, &attr);
    }
    return self;
}

- (void)dealloc
{
    SEL selector = NSSelectorFromString(@"stopTracker:whenTargetDealloc:");
    ((void (*)(id, SEL, BTTracker *, BTDealloc *))[BTEngine.defaultEngine methodForSelector:selector])(BTEngine.defaultEngine, selector, self.tracker, self);
}

- (void)lock
{
    pthread_mutex_lock(&_invokeLock);
}

- (void)unlock
{
    pthread_mutex_unlock(&_invokeLock);
}

@end

@interface BTTracker ()

@property (nonatomic) BlockTrackerCallback callback;
@property (nonatomic) NSArray<NSNumber *> *blockArgIndex;
@property (nonatomic) SEL aliasSelector;
@property (nonatomic, readwrite, getter=isActive) BOOL active;
@property (nonatomic) NSHashTable *blockHookTokens;
- (instancetype)initWithTarget:(id)target selector:(SEL)selector;

/**
 应用追踪者
 
 @return 更新成功返回 YES；如果追踪者不合法或继承链上已有相同 selector 的追踪者，则返回 NO
 */
- (BOOL)apply;

@end

@implementation BTTracker

- (instancetype)initWithTarget:(id)target selector:(SEL)selector
{
    self = [super init];
    if (self) {
        _target = target;
        _selector = selector;
        _blockHookTokens = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

#pragma mark Getter & Setter

- (SEL)aliasSelector
{
    if (!_aliasSelector) {
        NSString *selectorName = NSStringFromSelector(self.selector);
        _aliasSelector = NSSelectorFromString([NSString stringWithFormat:@"__bt_%@", selectorName]);
    }
    return _aliasSelector;
}

#pragma mark Public Method

- (BOOL)apply
{
    return [BTEngine.defaultEngine applyTracker:self];
}

- (BOOL)stop
{
    return [BTEngine.defaultEngine stopTracker:self];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"target:%@, selector:%@, active:%d, blockArgIndex:%@", [self.target description], NSStringFromSelector(self.selector), self.isActive, self.blockArgIndex.description];
}

#pragma mark Private Method

- (BTDealloc *)bt_deallocObject
{
    BTDealloc *btDealloc = objc_getAssociatedObject(self.target, self.selector);
    if (!btDealloc) {
        btDealloc = [BTDealloc new];
        btDealloc.tracker = self;
        btDealloc.cls = object_getClass(self.target);
        objc_setAssociatedObject(self.target, self.selector, btDealloc, OBJC_ASSOCIATION_RETAIN);
    }
    return btDealloc;
}

@end

@implementation BTEngine

static pthread_mutex_t mutex;

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
        _classHooked = [NSMutableSet set];
        pthread_mutex_init(&mutex, NULL);
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
            if (btDealloc.tracker) {
                [trackers addObject:btDealloc.tracker];
            }
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
    BTDealloc *btDealloc = [tracker bt_deallocObject];
    [btDealloc lock];
    BOOL shouldApply = YES;
    if (bt_checkTrackerValid(tracker)) {
        for (id target in [[self.targetSELs keyEnumerator] allObjects]) {
            NSMutableSet *selectors = [self.targetSELs objectForKey:target];
            NSString *selectorName = NSStringFromSelector(tracker.selector);
            if ([selectors containsObject:selectorName]) {
                if (target == tracker.target) {
                    shouldApply = NO;
                    continue;
                }
                if (bt_object_isClass(tracker.target) && bt_object_isClass(target)) {
                    Class clsA = tracker.target;
                    Class clsB = target;
                    shouldApply = !([clsA isSubclassOfClass:clsB] || [clsB isSubclassOfClass:clsA]);
                    // inheritance relationship
                    if (!shouldApply) {
                        NSLog(@"Sorry: %@ already apply tracker in %@. A message can only have one tracker per class hierarchy.", selectorName, NSStringFromClass(clsB));
                        break;
                    }
                }
                else if (bt_object_isClass(target) && target == object_getClass(tracker.target)) {
                    shouldApply = NO;
                    NSLog(@"Sorry: %@ already apply tracker in target's Class(%@).", selectorName, target);
                    break;
                }
            }
        }
        shouldApply = shouldApply && bt_overrideMethod(tracker);
        if (shouldApply) {
            [self addSelector:tracker.selector onTarget:tracker.target];
            tracker.active = YES;
        }
    }
    else {
        shouldApply = NO;
        NSLog(@"Sorry: invalid tracker.");
    }
    [btDealloc unlock];
    if (!shouldApply) {
        objc_setAssociatedObject(tracker.target, tracker.selector, nil, OBJC_ASSOCIATION_RETAIN);
    }
    pthread_mutex_unlock(&mutex);
    return shouldApply;
}

- (BOOL)stopTracker:(BTTracker *)tracker
{
    pthread_mutex_lock(&mutex);
    BTDealloc *btDealloc = [tracker bt_deallocObject];
    [btDealloc lock];
    BOOL shouldDiscard = NO;
    if (bt_checkTrackerValid(tracker)) {
        [self removeSelector:tracker.selector onTarget:tracker.target];
        shouldDiscard = bt_recoverMethod(tracker.target, tracker.selector, tracker.aliasSelector);
        tracker.active = NO;
    }
    [btDealloc unlock];
    pthread_mutex_unlock(&mutex);
    return shouldDiscard;
}

- (void)stopTracker:(BTTracker *)tracker whenTargetDealloc:(BTDealloc *)btDealloc
{
    if (bt_object_isClass(tracker.target)) {
        return;
    }
    pthread_mutex_lock(&mutex);
    [btDealloc lock];
    if (![self containsSelector:tracker.selector onTarget:btDealloc.cls] &&
        ![self containsSelector:tracker.selector onTargetsOfClass:btDealloc.cls]) {
        bt_revertHook(btDealloc.cls, tracker.selector, tracker.aliasSelector);
    }
    tracker.active = NO;
    [btDealloc unlock];
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

/**
 处理执行 NSInvocation
 
 @param invocation NSInvocation 对象
 @param tracker BTTracker 对象
 */
static void bt_handleInvocation(NSInvocation *invocation, BTTracker *tracker)
{
    NSCParameterAssert(invocation);
    NSCParameterAssert(tracker);
    
    if (!tracker.isActive) {
        [invocation invoke];
        return;
    }
    
    [invocation retainArguments];
    for (NSNumber *index in tracker.blockArgIndex) {
        if (index.integerValue < invocation.methodSignature.numberOfArguments) {
            __unsafe_unretained id block;
            [invocation getArgument:&block atIndex:index.integerValue];
            if ([tracker.blockHookTokens containsObject:block]) {
                continue;
            }
            // It's a weak reference.
            [tracker.blockHookTokens addObject:block];
            
            [block block_hookWithMode:BlockHookModeBefore usingBlock:^(BHInvocation *invocation) {
                if (tracker.callback) {
                    tracker.callback(invocation.token.block,
                                     BlockTrackerCallbackTypeBefore,
                                     invocation.args,
                                     nil,
                                     invocation.token.mangleName);
                }
            }];
            
            [block block_hookWithMode:BlockHookModeAfter usingBlock:^(BHInvocation *invocation) {
                if (tracker.callback) {
                    tracker.callback(invocation.token.block,
                                     BlockTrackerCallbackTypeAfter,
                                     invocation.args,
                                     invocation.retValue,
                                     invocation.token.mangleName);
                }
            }];

            [block block_hookWithMode:BlockHookModeDead usingBlock:^(BHToken *token) {
                if (tracker.callback) {
                    tracker.callback(nil,
                                     BlockTrackerCallbackTypeDead,
                                     nil,
                                     nil,
                                     token.mangleName);
                }
            }];
            
            NSLog(@"Hook Block Arg mangleName:%@, in selector:%@", [block block_currentHookToken].mangleName, NSStringFromSelector(tracker.selector));
        }
    }
    invocation.selector = tracker.aliasSelector;
    [invocation invoke];
}

static void bt_forwardInvocation(__unsafe_unretained id assignSlf, SEL selector, NSInvocation *invocation)
{
    BTDealloc *btDealloc = nil;
    if (!bt_object_isClass(invocation.target)) {
        btDealloc = objc_getAssociatedObject(invocation.target, invocation.selector);
    }
    else {
        btDealloc = objc_getAssociatedObject(object_getClass(invocation.target), invocation.selector);
    }
    
    BOOL respondsToAlias = YES;
    Class cls = object_getClass(invocation.target);
    
    do {
        if (!btDealloc.tracker) {
            btDealloc = objc_getAssociatedObject(cls, invocation.selector);
        }
        if ((respondsToAlias = [cls instancesRespondToSelector:btDealloc.tracker.aliasSelector])) {
            break;
        }
        btDealloc = nil;
    }
    while (!respondsToAlias && (cls = class_getSuperclass(cls)));
    
    [btDealloc lock];
    
    if (!respondsToAlias) {
        bt_executeOrigForwardInvocation(assignSlf, selector, invocation);
    }
    else {
        bt_handleInvocation(invocation, btDealloc.tracker);
    }
    
    [btDealloc unlock];
}

static NSString *const BTForwardInvocationSelectorName = @"__bt_forwardInvocation:";
static NSString *const BTSubclassPrefix = @"_BlockTracker_";

/**
 获取实例对象的类。如果 instance 是类对象，则返回元类。
 兼容 KVO 用子类替换 isa 并覆写 class 方法的场景。
 */
static Class bt_classOfTarget(id target)
{
    Class cls;
    if (bt_object_isClass(target)) {
        cls = object_getClass(target);
    }
    else {
        cls = [target class];
    }
    return cls;
}

static void bt_hookedGetClass(Class class, Class statedClass)
{
    NSCParameterAssert(class);
    NSCParameterAssert(statedClass);
    Method method = class_getInstanceMethod(class, @selector(class));
    IMP newIMP = imp_implementationWithBlock(^(id self) {
        return statedClass;
    });
    class_replaceMethod(class, @selector(class), newIMP, method_getTypeEncoding(method));
}

static BOOL bt_isMsgForwardIMP(IMP impl)
{
    return impl == _objc_msgForward
#if !defined(__arm64__)
    || impl == (IMP)_objc_msgForward_stret
#endif
    ;
}

static IMP bt_getMsgForwardIMP(Class cls, SEL selector)
{
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    Method originMethod = class_getInstanceMethod(cls, selector);
    const char *originType = (char *)method_getTypeEncoding(originMethod);
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
    return msgForwardIMP;
}

static BOOL bt_overrideMethod(BTTracker *tracker)
{
    id target = tracker.target;
    SEL selector = tracker.selector;
    SEL aliasSelector = tracker.aliasSelector;
    Class cls;
    Class statedClass = [target class];
    Class baseClass = object_getClass(target);
    NSString *className = NSStringFromClass(baseClass);
    
    if ([className hasPrefix:BTSubclassPrefix]) {
        cls = baseClass;
    }
    else if (bt_object_isClass(target)) {
        cls = target;
    }
    else if (statedClass != baseClass) {
        cls = baseClass;
    }
    else {
        const char *subclassName = [BTSubclassPrefix stringByAppendingString:className].UTF8String;
        Class subclass = objc_getClass(subclassName);
        
        if (subclass == nil) {
            subclass = objc_allocateClassPair(baseClass, subclassName, 0);
            if (subclass == nil) {
                NSLog(@"objc_allocateClassPair failed to allocate class %s.", subclassName);
                return NO;
            }
            bt_hookedGetClass(subclass, statedClass);
            bt_hookedGetClass(object_getClass(subclass), statedClass);
            objc_registerClassPair(subclass);
        }
        object_setClass(target, subclass);
        cls = subclass;
    }
    
    // check if subclass has hooked!
    for (Class clsHooked in BTEngine.defaultEngine.classHooked) {
        if (clsHooked != cls && [clsHooked isSubclassOfClass:cls]) {
            NSLog(@"Sorry: %@ used to be applied, can't apply it's super class %@!", NSStringFromClass(cls), NSStringFromClass(cls));
            return NO;
        }
    }
    
    [tracker bt_deallocObject].cls = cls;
    
    if (class_getMethodImplementation(cls, @selector(forwardInvocation:)) != (IMP)bt_forwardInvocation) {
        IMP originalImplementation = class_replaceMethod(cls, @selector(forwardInvocation:), (IMP)bt_forwardInvocation, "v@:@");
        if (originalImplementation) {
            class_addMethod(cls, NSSelectorFromString(BTForwardInvocationSelectorName), originalImplementation, "v@:@");
        }
    }
    
    Class superCls = class_getSuperclass(cls);
    Method targetMethod = class_getInstanceMethod(cls, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    if (!bt_isMsgForwardIMP(targetMethodIMP)) {
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        Method targetAliasMethod = class_getInstanceMethod(cls, aliasSelector);
        Method targetAliasMethodSuper = class_getInstanceMethod(superCls, aliasSelector);
        if (![cls instancesRespondToSelector:aliasSelector] || targetAliasMethod == targetAliasMethodSuper) {
            __unused BOOL addedAlias = class_addMethod(cls, aliasSelector, method_getImplementation(targetMethod), typeEncoding);
            NSCAssert(addedAlias, @"Original implementation for %@ is already copied to %@ on %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), cls);
        }
        class_replaceMethod(cls, selector, bt_getMsgForwardIMP(statedClass, selector), typeEncoding);
        [BTEngine.defaultEngine.classHooked addObject:cls];
    }
    
    return YES;
}

static void bt_revertHook(Class cls, SEL selector, SEL aliasSelector)
{
    Method targetMethod = class_getInstanceMethod(cls, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    if (bt_isMsgForwardIMP(targetMethodIMP)) {
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        Method originalMethod = class_getInstanceMethod(cls, aliasSelector);
        IMP originalIMP = method_getImplementation(originalMethod);
        NSCAssert(originalMethod, @"Original implementation for %@ not found %@ on %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), cls);
        class_replaceMethod(cls, selector, originalIMP, typeEncoding);
    }
    
    if (class_getMethodImplementation(cls, @selector(forwardInvocation:)) == (IMP)bt_forwardInvocation) {
        Method originalMethod = class_getInstanceMethod(cls, NSSelectorFromString(BTForwardInvocationSelectorName));
        Method objectMethod = class_getInstanceMethod(NSObject.class, @selector(forwardInvocation:));
        IMP originalImplementation = method_getImplementation(originalMethod ?: objectMethod);
        class_replaceMethod(cls, @selector(forwardInvocation:), originalImplementation, "v@:@");
    }
}

static BOOL bt_recoverMethod(id target, SEL selector, SEL aliasSelector)
{
    Class cls;
    if (bt_object_isClass(target)) {
        cls = target;
        if ([BTEngine.defaultEngine containsSelector:selector onTargetsOfClass:cls]) {
            return NO;
        }
    }
    else {
        BTDealloc *btDealloc = objc_getAssociatedObject(target, selector);
        // get class when apply tracker on target.
        cls = btDealloc.cls;
        // target current real class name
        NSString *className = NSStringFromClass(object_getClass(target));
        if ([className hasPrefix:BTSubclassPrefix]) {
            Class originalClass = NSClassFromString([className stringByReplacingOccurrencesOfString:BTSubclassPrefix withString:@""]);
            NSCAssert(originalClass != nil, @"Original class must exist");
            if (originalClass) {
                object_setClass(target, originalClass);
            }
        }
        if ([BTEngine.defaultEngine containsSelector:selector onTarget:cls] ||
            [BTEngine.defaultEngine containsSelector:selector onTargetsOfClass:cls]) {
            return NO;
        }
    }
    bt_revertHook(cls, selector, aliasSelector);
    return YES;
}

static void bt_executeOrigForwardInvocation(id slf, SEL selector, NSInvocation *invocation)
{
    SEL origForwardSelector = NSSelectorFromString(BTForwardInvocationSelectorName);
    if ([object_getClass(slf) instancesRespondToSelector:origForwardSelector]) {
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

@end

@implementation NSObject (BlockTracker)

- (NSArray<BTTracker *> *)bt_allTrackers
{
    NSMutableArray<BTTracker *> *result = [NSMutableArray array];
    for (BTTracker *tracker in BTEngine.defaultEngine.allTrackers) {
        if (tracker.target == self || tracker.target == bt_classOfTarget(self)) {
            [result addObject:tracker];
        }
    }
    return [result copy];
}

- (nullable BTTracker *)bt_trackBlockArgOfSelector:(SEL)selector callback:(BlockTrackerCallback)callback
{
    Method originMethod = class_getInstanceMethod([self class], selector);
    if (!originMethod) {
        return nil;
    }
    const char *originType = (char *)method_getTypeEncoding(originMethod);
    NSString *originTypeString = [NSString stringWithUTF8String:originType];
    if ([originTypeString rangeOfString:@"@?"].location == NSNotFound) {
        return nil;
    }
    NSMutableArray *blockArgIndex = [NSMutableArray array];
    int argIndex = 0; // return type is the first one
    while(originType && *originType)
    {
        originType = BTSizeAndAlignment(originType, NULL, NULL, NULL);
        if ([[NSString stringWithUTF8String:originType] hasPrefix:@"@?"]) {
            [blockArgIndex addObject:@(argIndex)];
        }
        argIndex++;
    }

    BTDealloc *btDealloc = objc_getAssociatedObject(self, selector);
    BTTracker *tracker = btDealloc.tracker;
    BOOL isNewTracker = NO;
    if (!tracker) {
        tracker = [[BTTracker alloc] initWithTarget:self selector:selector];
        isNewTracker = YES;
    }
    tracker.callback = callback;
    tracker.blockArgIndex = [blockArgIndex copy];
    if (isNewTracker) {
        return [tracker apply] ? tracker : nil;
    }
    return tracker;
}

@end

static void *(*bt_orig_Block_copy)(const void *aBlock);
static BlockTrackerCallback bt_blockTrackerCallback;

void(^hookBefore)(BHInvocation *) = ^(BHInvocation *invocation) {
    bt_blockTrackerCallback(invocation.token.block,
                            BlockTrackerCallbackTypeBefore,
                            invocation.args,
                            nil,
                            invocation.token.mangleName);
};

void(^hookAfter)(BHInvocation *) = ^(BHInvocation *invocation) {
    bt_blockTrackerCallback(invocation.token.block,
                            BlockTrackerCallbackTypeAfter,
                            invocation.args,
                            invocation.retValue,
                            invocation.token.mangleName);
};

void(^hookDead)(BHToken *) = ^(BHToken *token) {
    bt_blockTrackerCallback(nil,
                            BlockTrackerCallbackTypeDead,
                            nil,
                            nil,
                            token.mangleName);
};

void *bt_replaced_Block_copy(const void *aBlock)
{
    void *result = bt_orig_Block_copy(aBlock);
    if (aBlock == result) {
        return result;
    }
    
    [((__bridge id)result) block_hookWithMode:BlockHookModeBefore usingBlock:hookBefore];
    [((__bridge id)result) block_hookWithMode:BlockHookModeAfter usingBlock:hookAfter];
    [((__bridge id)result) block_hookWithMode:BlockHookModeDead usingBlock:hookDead];
    
    NSLog(@"Hook Block mangleName:%@", [(__bridge id)(result) block_currentHookToken].mangleName);
    return result;
}

void setMallocBlockCallback(BlockTrackerCallback callback) {
    bt_blockTrackerCallback = callback;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rebind_symbols((struct rebinding[1]){"_Block_copy", bt_replaced_Block_copy, (void *)&bt_orig_Block_copy}, 1);
    });
}
