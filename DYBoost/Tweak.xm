//
//  Tweak.xm
//  DYBoost
//
//  入口：全部走 libobjc runtime hook，不依赖 CydiaSubstrate / libellekit。
//  这样巨魔注入器(TrollFools)把 dylib 塞进 IPA 后，即使没有 Substrate 也能正常工作。
//
//  职责：
//   1. 认页面（viewDidAppear）——> 交给 DYBContext
//   2. 窗口变 key ——> 补挂手势 / 悬浮球 / 美化
//   3. 启动后延迟装载各模块
//

#import <UIKit/UIKit.h>
#import "DYBContext.h"
#import "DYBActions.h"
#import "DYBGesture.h"
#import "DYBFloatBall.h"
#import "DYBStats.h"
#import "DYBBeauty.h"
#import "DYBMenu.h"
#import "DYBPrefs.h"
#import "DYBKeys.h"
#import "DYBHookKit.h"
#import "DYBHUD.h"

// 原实现指针
static void (*DYBOrigViewDidAppear)(UIViewController *, SEL, BOOL);
static void (*DYBOrigBecomeKeyWindow)(UIWindow *, SEL);

static BOOL gDYBBooted = NO;

#pragma mark - Hook 实现

static void DYBViewDidAppear(UIViewController *self_, SEL _cmd, BOOL animated) {
    if (DYBOrigViewDidAppear) DYBOrigViewDidAppear(self_, _cmd, animated);
    @autoreleasepool {
        [DYBContext noteViewControllerDidAppear:self_];
        [DYBGesture attachIfNeeded];
        double sp = [[DYBPrefs shared] floatFor:DYBKey_defaultSpeed default:1.0];
        if (sp > 1.01 && [DYBContext isFeedPlayerOnTop]) {
            DYBAsyncMainAfter(0.9, ^{ [DYBActions applySpeed:sp silent:YES]; });
        }
    }
}

static void DYBWindowBecomeKey(UIWindow *self_, SEL _cmd) {
    if (DYBOrigBecomeKeyWindow) DYBOrigBecomeKeyWindow(self_, _cmd);
    DYBAsyncMainAfter(0.2, ^{
        [DYBGesture attachIfNeeded];
        [DYBFloatBall applyPrefs];
    });
}

#pragma mark - 装载

static void DYBBoot(void) {
    if (gDYBBooted) return;
    gDYBBooted = YES;

    NSLog(@"[DYBoost] boot 1.0.0");

    // 顺序有意义：Context 内部会把 Beauty / FloatBall / Gesture / Stats 一起装好
    [DYBContext installOnce];
    [DYBGesture install];
    [DYBFloatBall install];
    [DYBGesture attachIfNeeded];
    [DYBFloatBall applyPrefs];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:NSOperationQueue.mainQueue
                                                  usingBlock:^(NSNotification *n) {
        DYBAsyncMainAfter(0.5, ^{
            [DYBGesture attachIfNeeded];
            [DYBFloatBall applyPrefs];
            [DYBBeauty refresh];
        });
    }];
}

#pragma mark - 构造入口（不经过 Logos，避免链接 substrate）

__attribute__((constructor))
static void DYBoostEntry(void) {
    @autoreleasepool {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        if (![bid hasPrefix:@"com.ss.iphone.ugc.Aweme"]) return;

        (void)[DYBPrefs shared];   // 预热配置（默认值注册）

        // UIViewController / UIWindow 是系统类，直接 method_setImplementation 即可
        DYBHookMessage(UIViewController.class, @selector(viewDidAppear:),
                       (void *)DYBViewDidAppear, (void **)&DYBOrigViewDidAppear);
        DYBHookMessage(UIWindow.class, @selector(becomeKeyWindow),
                       (void *)DYBWindowBecomeKey, (void **)&DYBOrigBecomeKeyWindow);

        DYBAsyncMainAfter(1.0, ^{ DYBBoot(); });
    }
}
