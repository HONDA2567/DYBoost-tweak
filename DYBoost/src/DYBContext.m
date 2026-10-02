//
//  DYBContext.m
//  DYBoost
//
//  页面识别。这里曾经在每次 viewDidAppear 里同步跑一次对象图扫描
//  （DYBFindObject 深度 6），抖音首页一出现就把主线程冻住 —— 已改成按需 + 空闲 + 节流。
//

#import "DYBContext.h"
#import "DYBHookKit.h"
#import "DYBAweme.h"
#import "DYBFloatBall.h"
#import "DYBGesture.h"
#import "DYBStats.h"
#import "DYBBeauty.h"
#import "DYBSafe.h"


static __weak UIViewController *gVC;
static NSString *gClassName;
static BOOL gInstalled;
static BOOL gNeedModel;     // 只有真正要用到作品数据时才扫描

@implementation DYBContext

+ (void)noteViewControllerDidAppear:(UIViewController *)vc {
    if (!vc) return;
    NSString *cn = NSStringFromClass(vc.class);
    BOOL dy = [cn hasPrefix:@"AWE"] || [cn hasPrefix:@"AWEM"] || [cn hasPrefix:@"FDS"]
              || [cn containsString:@"Aweme"] || [cn containsString:@"Douyin"];
    if (!dy) return;

    gVC = vc;
    gClassName = cn;
    DYBSafePing();

    [self installOnce];
    [DYBBeauty refresh];
    [self scheduleModelScan];
    [DYBStats updateLight];     // 只刷 UI 开关，不碰作品解析
}

/// 标记「需要作品数据」：用户点过菜单/面板，或开了作品数据浮窗时才置 YES
+ (void)setNeedsModel:(BOOL)on { gNeedModel = on; }
+ (BOOL)needsModel { return gNeedModel; }

+ (void)scheduleModelScan {
    if (!gNeedModel) return;
    if (!DYBThrottle(@"model.scan", 2.5)) return;
    UIViewController *vc = gVC;
    if (!vc) return;
    DYBRunWhenIdle(^{
        if (!vc) return;
        id model = DYBFindObject(vc, @[@"AWEAwemeModel", @"AWECodeGenAwemeModel", @"AwemeModel"], 5);
        if (model) [DYBAweme noteModel:model];
        DYBSafePing();
    });
}

+ (UIViewController *)currentVC { return gVC; }
+ (NSString *)currentClassName { return gClassName; }

+ (BOOL)isFeedPlayerOnTop {
    NSString *cn = gClassName ?: @"";
    if (cn.length == 0) return NO;
    NSArray *kw = @[@"PlayVideo", @"Feed", @"Detail", @"AwemeDetail", @"PlayerFeed", @"AWEAweme"];
    for (NSString *k in kw) if ([cn containsString:k]) return YES;
    return NO;
}

+ (BOOL)isLiveOnTop {
    NSString *cn = gClassName ?: @"";
    return ([cn containsString:@"Live"] && [cn containsString:@"View"]);
}

+ (void)installOnce {
    if (gInstalled) return;
    gInstalled = YES;
    DYBAsyncMainAfter(0.8, ^{
        @try {
            [DYBFloatBall install];
            DYBTrace(@"T9 floatball");
            [DYBGesture install];
            DYBTrace(@"T10 gesture");
            [DYBGesture attachIfNeeded];
            [DYBFloatBall applyPrefs];
            DYBTrace(@"T11 attached");
        } @catch (NSException *e) {
            DYBTrace([NSString stringWithFormat:@"T9-11 异常 %@", e.reason]);
        }
        if (DYBSafeStage() >= 2) {
            DYBAsyncMainAfter(1.2, ^{
                DYBRunWhenIdle(^{
                    @try {
                        [DYBBeauty install];
                        DYBTrace(@"T12 beauty");
                        [DYBStats install];
                        DYBTrace(@"T13 stats");
                        DYBSafePing();
                    } @catch (NSException *e) {
                        DYBTrace([NSString stringWithFormat:@"T12-13 异常 %@", e.reason]);
                    }
                });
            });
        }
    });
}

@end
