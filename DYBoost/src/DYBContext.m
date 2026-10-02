//
//  DYBContext.m
//  DYBoost
//

#import "DYBContext.h"
#import "DYBHookKit.h"
#import "DYBAweme.h"
#import "DYBFloatBall.h"
#import "DYBGesture.h"
#import "DYBStats.h"
#import "DYBBeauty.h"

static __weak UIViewController *gVC;
static NSString *gClassName;
static BOOL gInstalled;

@implementation DYBContext

+ (void)noteViewControllerDidAppear:(UIViewController *)vc {
    if (!vc) return;
    NSString *cn = NSStringFromClass(vc.class);
    BOOL dy = [cn hasPrefix:@"AWE"] || [cn hasPrefix:@"AWEM"] || [cn hasPrefix:@"FDS"]
              || [cn containsString:@"Aweme"] || [cn containsString:@"Douyin"];
    if (!dy) return;

    gVC = vc;
    gClassName = cn;

    // 上报当前 model（用于下载/复制直链）
    id model = DYBFindObject(vc, @[@"AWEAwemeModel", @"AwemeModel"], 6);
    if (model) [DYBAweme noteModel:model];

    [self installOnce];
    [DYBBeauty refresh];
    [DYBStats update];
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
    DYBAsyncMainAfter(0.6, ^{
        [DYBBeauty install];
        [DYBFloatBall install];
        [DYBGesture install];
        [DYBStats install];
    });
}

@end
