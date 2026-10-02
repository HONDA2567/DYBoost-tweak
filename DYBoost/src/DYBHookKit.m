//
//  DYBHookKit.m
//  DYBoost
//

#import "DYBHookKit.h"
#import "DYBPrefs.h"
#import "DYBKeys.h"
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - 类解析

Class DYBFirstClass(NSArray<NSString *> *candidates) {
    for (NSString *name in candidates) {
        Class c = NSClassFromString(name);
        if (c) return c;
    }
    return Nil;
}

NSDictionary<NSString *, NSNumber *> *DYBProbeClasses(NSDictionary<NSString *, NSArray<NSString *> *> *groups) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    [groups enumerateKeysAndObjectsUsingBlock:^(NSString *gid, NSArray<NSString *> *names, BOOL *stop) {
        NSMutableArray *hit = [NSMutableArray array];
        for (NSString *n in names) { if (NSClassFromString(n)) { [hit addObject:n]; break; } }
        out[gid] = @(hit.count > 0);
    }];
    return out;
}

#pragma mark - Hook

static BOOL DYBHookWithIMP(Class cls, SEL sel, IMP newImp, void **origOut) {
    if (!cls || !sel || !newImp) return NO;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return NO;
    IMP prev = method_getImplementation(m);
    const char *types = method_getTypeEncoding(m);
    // 类自身没有实现（继承自父类）：先加一份，避免改到父类
    if (class_addMethod(cls, sel, newImp, types)) {
        if (origOut) *origOut = (void *)prev;
        return YES;
    }
    IMP replaced = method_setImplementation(m, newImp);
    if (origOut) *origOut = (void *)replaced;
    return YES;
}

BOOL DYBHookMessage(Class cls, SEL sel, void *replacement, void **origOut) {
    return DYBHookWithIMP(cls, sel, (IMP)replacement, origOut);
}

BOOL DYBHookBlock(Class cls, SEL sel, id block, void **origOut) {
    IMP imp = imp_implementationWithBlock(block);
    return DYBHookWithIMP(cls, sel, imp, origOut);
}

BOOL DYBHookClassMethod(Class cls, SEL sel, void *replacement, void **origOut) {
    if (!cls) return NO;
    Class meta = object_getClass((id)cls);
    Method m = class_getInstanceMethod(meta, sel);
    if (!m) return NO;
    IMP prev = method_getImplementation(m);
    const char *types = method_getTypeEncoding(m);
    if (class_addMethod(meta, sel, (IMP)replacement, types)) {
        if (origOut) *origOut = (void *)prev;
        return YES;
    }
    IMP replaced = method_setImplementation(m, (IMP)replacement);
    if (origOut) *origOut = (void *)replaced;
    return YES;
}

BOOL DYBHookFirst(NSArray<NSString *> *classes, NSArray<NSString *> *sels, id block, void **origOut) {
    Class cls = DYBFirstClass(classes);
    if (!cls) return NO;
    for (NSString *s in sels) {
        SEL sel = NSSelectorFromString(s);
        if (![cls instancesRespondToSelector:sel]) continue;
        if (DYBHookBlock(cls, sel, block, origOut)) return YES;
    }
    return NO;
}

#pragma mark - 安全取值

id DYBSafeGet(id obj, NSString *key) {
    if (!obj || key.length == 0) return nil;
    if (![obj respondsToSelector:NSSelectorFromString(key)]) {
        // Swift/ObjC 有些 key 带下划线前缀，做一次兜底
        NSString *alt = [@"_" stringByAppendingString:key];
        if (![obj respondsToSelector:NSSelectorFromString(alt)]) return nil;
        key = alt;
    }
    @try { return [obj valueForKey:key]; }
    @catch (NSException *e) { return nil; }
}

BOOL DYBSafeSet(id obj, NSString *key, id value) {
    if (!obj || key.length == 0) return NO;
    @try {
        [obj setValue:value forKey:key];
        return YES;
    } @catch (NSException *e) {
        NSString *alt = [@"_" stringByAppendingString:key];
        @try { [obj setValue:value forKey:alt]; return YES; } @catch (NSException *e2) { return NO; }
    }
}

id DYBPick(id obj, NSArray<NSString *> *keys) {
    for (NSString *k in keys) {
        id v = DYBSafeGet(obj, k);
        if (v) return v;
    }
    return nil;
}

id DYBCall(id obj, NSArray<NSString *> *sels) {
    if (!obj) return nil;
    for (NSString *s in sels) {
        SEL sel = NSSelectorFromString(s);
        if (![obj respondsToSelector:sel]) continue;
        @try {
            IMP imp = [obj methodForSelector:sel];
            id (*fn)(id, SEL) = (void *)imp;
            return fn(obj, sel);
        } @catch (NSException *e) { }
    }
    return nil;
}

#pragma mark - 对象图扫描

typedef BOOL (^DYBVisit)(id obj);

// 预算：抖音首页 VC 的对象图能到 10^6 级别（feed 数据源 × 每个 model 上百 ivar），
// 不设上限就是主线程冻结 —— 之前「打开就卡死」就是这么来的。
static const int   kWalkMaxNodes  = 1200;
static const int   kWalkMaxDepth  = 5;
static const CFTimeInterval kWalkMaxSeconds = 0.020;

typedef struct {
    int nodes;
    CFTimeInterval deadline;
    NSMutableSet<NSValue *> *seen;
    BOOL exhausted;
} DYBWalkBudget;

/// 这些类的 ivar 一律不再深入：UIKit 对象图会把整个 window 树 / layer 树带进来，
/// 图片、数据块本身也只有字节，没有信息量。
static BOOL DYBNoDeepDive(id obj) {
    if ([obj isKindOfClass:UIView.class])        return YES;
    if ([obj isKindOfClass:UIViewController.class]) return YES;
    if ([obj isKindOfClass:UIResponder.class])   return YES;
    if ([obj isKindOfClass:CALayer.class])       return YES;
    if ([obj isKindOfClass:UIImage.class])       return YES;
    if ([obj isKindOfClass:NSData.class])        return YES;
    if ([obj isKindOfClass:NSDate.class])        return YES;
    if ([obj isKindOfClass:NSError.class])       return YES;
    if ([obj isKindOfClass:NSValue.class])       return YES;   // NSNumber / NSValue
    return NO;
}

static void DYBWalkObjectBudget(id obj, int depth, DYBWalkBudget *b, DYBVisit visit) {
    if (!obj || depth <= 0 || b->exhausted) return;
    if (b->nodes++ > kWalkMaxNodes) { b->exhausted = YES; return; }
    if ((b->nodes & 0x3F) == 0 && CACurrentMediaTime() > b->deadline) { b->exhausted = YES; return; }

    NSValue *ident = [NSValue valueWithPointer:(__bridge const void *)(obj)];
    if ([b->seen containsObject:ident]) return;
    [b->seen addObject:ident];

    if (visit(obj)) return;
    if (depth <= 1) return;

    if ([obj isKindOfClass:NSArray.class]) {
        NSArray *a = (NSArray *)obj;
        NSUInteger n = MIN(a.count, 64);
        for (NSUInteger i = 0; i < n; i++) DYBWalkObjectBudget(a[i], depth - 1, b, visit);
        return;
    }
    if ([obj isKindOfClass:NSSet.class]) {
        NSUInteger i = 0;
        for (id e in (NSSet *)obj) { if (i++ >= 64) break; DYBWalkObjectBudget(e, depth - 1, b, visit); }
        return;
    }
    if ([obj isKindOfClass:NSDictionary.class]) {
        NSUInteger i = 0;
        for (id e in [(NSDictionary *)obj allValues]) { if (i++ >= 64) break; DYBWalkObjectBudget(e, depth - 1, b, visit); }
        return;
    }
    if (DYBNoDeepDive(obj)) return;

    // 只遍历对象类型 ivar，避免对非对象内存调用 object_getIvar
    for (Class c = object_getClass(obj); c && c != [NSObject class]; c = class_getSuperclass(c)) {
        unsigned n = 0;
        Ivar *ivars = class_copyIvarList(c, &n);
        if (!ivars) continue;
        @try {
            for (unsigned i = 0; i < n && !b->exhausted; i++) {
                const char *t = ivar_getTypeEncoding(ivars[i]);
                if (!t || t[0] != '@') continue;
                id v = nil;
                @try { v = object_getIvar(obj, ivars[i]); } @catch (NSException *e) { v = nil; }
                if (v) DYBWalkObjectBudget(v, depth - 1, b, visit);
            }
        } @finally { free(ivars); }
    }
}

static void DYBWalkObject(id obj, int depth, NSMutableSet<NSValue *> *seen, DYBVisit visit) {
    DYBWalkBudget b = { 0, CACurrentMediaTime() + kWalkMaxSeconds, seen, NO };
    DYBWalkObjectBudget(obj, MIN(depth, kWalkMaxDepth), &b, visit);
}

id DYBFindObject(id root, NSArray<NSString *> *classNames, int maxDepth) {
    if (!root) return nil;
    __block id found = nil;
    NSMutableSet *seen = [NSMutableSet set];
    DYBWalkObject(root, maxDepth ?: 5, seen, ^BOOL(id obj) {
        NSString *cn = NSStringFromClass([obj class]);
        for (NSString *n in classNames) {
            if ([cn isEqualToString:n] || [cn containsString:n]) { found = obj; return YES; }
        }
        return NO;
    });
    return found;
}

NSArray<NSString *> *DYBCollectStrings(id root, int maxDepth) {
    if (!root) return @[];
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSMutableSet<NSString *> *uniq = [NSMutableSet set];
    DYBWalkObject(root, maxDepth ?: 6, seen, ^BOOL(id obj) {
        if ([obj isKindOfClass:NSString.class]) {
            NSString *s = (NSString *)obj;
            if (s.length > 8 && s.length < 2048 && ![uniq containsObject:s]) {
                [uniq addObject:s];
                [out addObject:s];
            }
        }
        return NO;
    });
    return out;
}

#pragma mark - UI 工具

UIWindow *DYBKeyWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive) continue;
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) return w;
            }
        }
    }
    return UIApplication.sharedApplication.keyWindow;
}

UIViewController *DYBMostTopViewController(void) {
    UIViewController *vc = DYBKeyWindow().rootViewController;
    while (vc) {
        if ([vc isKindOfClass:UINavigationController.class]) {
            vc = ((UINavigationController *)vc).visibleViewController;
        } else if ([vc isKindOfClass:UITabBarController.class]) {
            vc = ((UITabBarController *)vc).selectedViewController;
        } else if (vc.presentedViewController && !vc.presentedViewController.isBeingDismissed) {
            vc = vc.presentedViewController;
        } else {
            break;
        }
    }
    return vc;
}

void DYBWalkViews(UIView *root, void (^visit)(UIView *view, BOOL *stop)) {
    if (!root) return;
    static int depth = 0;
    if (depth > 40) return;                 // 防御：异常深的视图树直接放弃
    depth++;
    @try {
        BOOL stop = NO;
        visit(root, &stop);
        if (!stop) {
            for (UIView *sub in root.subviews) {
                DYBWalkViews(sub, visit);
                if (stop) break;
            }
        }
    } @finally { depth--; }
}

UIView *DYBFindView(UIView *root, BOOL (^predicate)(UIView *view)) {
    __block UIView *hit = nil;
    DYBWalkViews(root, ^(UIView *v, BOOL *stop) {
        if (predicate(v)) { hit = v; *stop = YES; }
    });
    return hit;
}

void DYBAsyncMain(dispatch_block_t block) {
    if (!block) return;
    if ([NSThread isMainThread]) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

void DYBAsyncMainAfter(NSTimeInterval delay, dispatch_block_t block) {
    if (!block) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

void DYBHaptic(UIImpactFeedbackStyle style) {
    if (![[DYBPrefs shared] boolFor:DYBKey_haptic default:YES]) return;
    DYBAsyncMain(^{
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *g = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
            [g prepare];
            [g impactOccurred];
        }
    });
}
