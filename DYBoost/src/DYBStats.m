//
//  DYBStats.m
//  DYBoost
//

#import "DYBStats.h"
#import "DYBPrefs.h"
#import "DYBKeys.h"
#import "DYBTheme.h"
#import "DYBHookKit.h"
#import "DYBAweme.h"
#import "DYBContext.h"
#import "DYBHUD.h"

static UIWindow *gFPSWindow;
static UILabel *gFPSLabel;
static CADisplayLink *gLink;
static NSInteger gFrames;
static CFTimeInterval gLastTime;

static UIWindow *gStatsWindow;
static UILabel *gStatsLabel;

static UIWindow *gLiveWindow;
static UILabel *gLiveLabel;
static NSTimer *gLiveTimer;
static NSDate *gLiveStart;

@implementation DYBStats

+ (void)install {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        DYBAsyncMain(^{
            [self buildFPS];
            [self buildStats];
            [self buildLive];
            [self update];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(dybPrefsChanged:)
                                                         name:DYBPrefsChangedNotification
                                                       object:nil];
        });
    });
}

+ (void)dybPrefsChanged:(NSNotification *)n { [self update]; }

#pragma mark 通用小窗口

+ (UIWindow *)smallWindowWithFrame:(CGRect)frame {
    UIWindow *w;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = (UIWindowScene *)DYBKeyWindow().windowScene;
        w = scene ? [[UIWindow alloc] initWithWindowScene:scene] : [[UIWindow alloc] initWithFrame:frame];
    } else {
        w = [[UIWindow alloc] initWithFrame:frame];
    }
    w.frame = frame;
    w.windowLevel = UIWindowLevelStatusBar + 8;
    w.backgroundColor = UIColor.clearColor;
    w.userInteractionEnabled = NO;
    w.hidden = YES;
    return w;
}

+ (UILabel *)pillLabelIn:(UIWindow *)w {
    UILabel *lb = [[UILabel alloc] initWithFrame:w.bounds];
    lb.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    lb.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
    lb.textColor = UIColor.whiteColor;
    lb.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
    lb.textAlignment = NSTextAlignmentCenter;
    lb.numberOfLines = 0;
    lb.layer.cornerRadius = 8;
    lb.layer.masksToBounds = YES;
    [w addSubview:lb];
    return lb;
}

#pragma mark FPS

+ (void)buildFPS {
    CGRect f = CGRectMake(12, 44, 68, 22);
    gFPSWindow = [self smallWindowWithFrame:f];
    gFPSLabel = [self pillLabelIn:gFPSWindow];

    gLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    if (@available(iOS 15.0, *)) {
        gLink.preferredFrameRateRange = CAFrameRateRangeMake(60, 120, 120);
    }
    [gLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    gLastTime = CACurrentMediaTime();
}

+ (void)tick:(CADisplayLink *)l {
    gFrames++;
    CFTimeInterval now = CACurrentMediaTime();
    CFTimeInterval dt = now - gLastTime;
    if (dt >= 0.5) {
        double fps = gFrames / dt;
        gFrames = 0;
        gLastTime = now;
        BOOL on = [[DYBPrefs shared] boolFor:DYBKey_showFPS default:NO];
        gFPSWindow.hidden = !on;
        if (on) gFPSLabel.text = [NSString stringWithFormat:@"%.0f FPS", fps];
    }
}

#pragma mark 作品数据

+ (void)buildStats {
    CGRect f = CGRectMake(UIScreen.mainScreen.bounds.size.width - 96, 160, 92, 96);
    gStatsWindow = [self smallWindowWithFrame:f];
    gStatsLabel = [self pillLabelIn:gStatsWindow];
    gStatsLabel.textAlignment = NSTextAlignmentLeft;
}

static NSString *DYBShortNum(long long n) {
    if (n <= 0) return @"0";
    if (n >= 100000000) return [NSString stringWithFormat:@"%.1f亿", n / 100000000.0];
    if (n >= 10000) return [NSString stringWithFormat:@"%.1f万", n / 10000.0];
    return [NSString stringWithFormat:@"%lld", n];
}

+ (void)refreshStats {
    BOOL on = [[DYBPrefs shared] boolFor:DYBKey_showStats default:NO];
    gStatsWindow.hidden = !on;
    if (!on) return;
    DYBAweme *a = [DYBAweme current];
    if (!a) { gStatsLabel.text = @"暂无数据"; return; }
    NSMutableString *s = [NSMutableString string];
    if (a.diggCount)    [s appendFormat:@"赞 %@\n", DYBShortNum(a.diggCount.longLongValue)];
    if (a.commentCount) [s appendFormat:@"评 %@\n", DYBShortNum(a.commentCount.longLongValue)];
    if (a.collectCount) [s appendFormat:@"藏 %@\n", DYBShortNum(a.collectCount.longLongValue)];
    if (a.shareCount)   [s appendFormat:@"转 %@\n", DYBShortNum(a.shareCount.longLongValue)];
    if (a.playCount)    [s appendFormat:@"播 %@", DYBShortNum(a.playCount.longLongValue)];
    gStatsLabel.text = s.length ? s : @"暂无数据";
}

#pragma mark 直播时长

+ (void)buildLive {
    CGRect f = CGRectMake((UIScreen.mainScreen.bounds.size.width - 120) / 2.0, 48, 120, 22);
    gLiveWindow = [self smallWindowWithFrame:f];
    gLiveLabel = [self pillLabelIn:gLiveWindow];
}

+ (void)refreshLive {
    BOOL want = [[DYBPrefs shared] boolFor:DYBKey_showLiveDuration default:NO];
    BOOL live = [DYBContext isLiveOnTop];
    BOOL on = want && live;
    gLiveWindow.hidden = !on;
    if (on && !gLiveTimer) {
        gLiveStart = [NSDate date];
        gLiveTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
            NSTimeInterval d = -[gLiveStart timeIntervalSinceNow];
            gLiveLabel.text = [NSString stringWithFormat:@"已看 %02d:%02d", (int)(d / 60), (int)((long)d % 60)];
        }];
    } else if (!on && gLiveTimer) {
        [gLiveTimer invalidate];
        gLiveTimer = nil;
    }
}

#pragma mark 对外

+ (void)update {
    DYBAsyncMain(^{
        [self refreshStats];
        [self refreshLive];
    });
}

@end
