//
//  Tweak.xm
//  DYBoost
//
//  入口：全部走 libobjc runtime hook，不依赖 CydiaSubstrate / libellekit。
//  这样巨魔注入器(TrollFools)把 dylib 塞进 IPA 后，即使没有 Substrate 也能正常工作。
//
//  职责：
//   1. 安全层：kill switch / 分级启动 / 主线程看门狗（DYBSafe）
//   2. 认页面（viewDidAppear）——> 交给 DYBContext
//   3. 窗口变 key ——> 补挂手势 / 悬浮球
//   4. 空闲时才装载重模块，绝不阻塞启动
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
#import "DYBSafe.h"
#import "DYBHUD.h"

// 原实现指针
static void (*DYBOrigViewDidAppear)(UIViewController *, SEL, BOOL);
static void (*DYBOrigBecomeKeyWindow)(UIWindow *, SEL);

static BOOL gDYBBooted = NO;

#pragma mark - Hook 实现

static void DYBViewDidAppear(UIViewController *self_, SEL _cmd, BOOL animated) {
    if (DYBOrigViewDidAppear) DYBOrigViewDidAppear(self_, _cmd, animated);
    // 我们的任何异常都不允许冒泡到抖音：穿过去就是闪退
    @autoreleasepool {
        @try {
            DYBSafePing();
            [DYBContext noteViewControllerDidAppear:self_];
            [DYBGesture attachIfNeeded];
            double sp = [[DYBPrefs shared] floatFor:DYBKey_defaultSpeed default:1.0];
            if (sp > 1.01 && [DYBContext isFeedPlayerOnTop]) {
                DYBAsyncMainAfter(0.9, ^{ [DYBActions applySpeed:sp silent:YES]; });
            }
        } @catch (NSException *e) {
            NSLog(@"[DYBoost] viewDidAppear 异常: %@", e.reason);
        }
    }
}

static void DYBWindowBecomeKey(UIWindow *self_, SEL _cmd) {
    if (DYBOrigBecomeKeyWindow) DYBOrigBecomeKeyWindow(self_, _cmd);
    DYBAsyncMainAfter(0.3, ^{
        @try {
            [DYBGesture attachIfNeeded];
            [DYBFloatBall applyPrefs];
            DYBSafePing();
        } @catch (NSException *e) {
            NSLog(@"[DYBoost] becomeKey 异常: %@", e.reason);
        }
    });
}

#pragma mark - 装载

static void DYBBoot(void) {
    if (gDYBBooted) return;
    gDYBBooted = YES;

    NSLog(@"[DYBoost] boot 1.0.3 stage=%d", DYBSafeStage());
    DYBTrace([NSString stringWithFormat:@"T7 boot stage=%d", DYBSafeStage()]);

    // 顺序有意义：Context 内部会按等级把各模块装好
    @try {
        [DYBContext installOnce];
        DYBTrace(@"T8 context installed");
    } @catch (NSException *e) {
        DYBTrace([NSString stringWithFormat:@"T8 异常 %@", e.reason]);
    }

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:NSOperationQueue.mainQueue
                                                  usingBlock:^(NSNotification *n) {
        DYBAsyncMainAfter(0.5, ^{
            [DYBGesture attachIfNeeded];
            [DYBFloatBall applyPrefs];
            DYBSafePing();
        });
    }];
}

#pragma mark - 构造入口（不经过 Logos，避免链接 substrate）

static dispatch_once_t DYBoostEntryOnceToken;

static void DYBoostEntryReal(void) {
    @autoreleasepool {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        if (![bid hasPrefix:@"com.ss.iphone.ugc.Aweme"]) return;

        DYBSafeInstallCrashTrap();   // 越早越好，崩了要能留痕
        DYBTrace(@"T1 entry");

#ifdef DYB_PROBE_ONLY
        DYBTrace(@"T-probe 只加载不装载，到此为止");
        NSLog(@"[DYBoost] probe 模式：dylib 已加载，不挂任何 hook");
        return;
#endif

        if (DYBKillSwitch()) {
            DYBTrace(@"T-kill kill switch on");
            NSLog(@"[DYBoost] kill switch on，不装载");
            return;
        }

        (void)[DYBPrefs shared];   // 预热配置（默认值注册）
        DYBTrace(@"T2 prefs ok");

        int stage = DYBSafeStage();
        DYBSafeBeginStage(stage, 8.0);
        DYBTrace([NSString stringWithFormat:@"T3 watchdog stage=%d", stage]);

        // UIViewController / UIWindow 是系统类，直接 method_setImplementation 即可
        BOOL h1 = DYBHookMessage(UIViewController.class, @selector(viewDidAppear:),
                                 (void *)DYBViewDidAppear, (void **)&DYBOrigViewDidAppear);
        BOOL h2 = DYBHookMessage(UIWindow.class, @selector(becomeKeyWindow),
                                 (void *)DYBWindowBecomeKey, (void **)&DYBOrigBecomeKeyWindow);
        DYBTrace([NSString stringWithFormat:@"T4 hook vc=%d win=%d", h1, h2]);

        // 启动路径上不做任何重活：等首屏出来、RunLoop 空闲了再装
        DYBAsyncMainAfter(1.5, ^{
            DYBTrace(@"T5 boot scheduled");
            DYBSafePing();
            DYBRunWhenIdle(^{ DYBTrace(@"T6 boot run"); DYBBoot(); });
        });
    }
}

static void DYBoostEntry(void) {
    dispatch_once(&DYBoostEntryOnceToken, ^{ DYBoostEntryReal(); });
}

// 通路 1：+load —— 落进 __objc_nlclslist，由 objc runtime 在镜像加载时调用。
// 这是所有 iOS 版本都支持的老机制，比 __attribute__((constructor)) 更稳：
// 新 ld 会把构造器编码成 __TEXT,__init_offsets，只有 dyld4(iOS15+) 认。
@interface DYBoostLoader : NSObject @end
@implementation DYBoostLoader
+ (void)load { DYBoostEntry(); }
@end

// 通路 2：构造器 —— 有就跑，没有也不影响（dispatch_once 保证只执行一次）
__attribute__((constructor))
static void DYBoostConstructor(void) {
    DYBoostEntry();
}
