//
//  DYBGesture.m
//  DYBoost
//

#import "DYBGesture.h"
#import "DYBPrefs.h"
#import "DYBKeys.h"
#import "DYBHookKit.h"
#import "DYBActions.h"
#import "DYBHUD.h"
#import "DYBContext.h"
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>

static char kDYBGestureAttached;

@interface DYBGesture () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) MPVolumeView *volumeView;
@property (nonatomic, strong) UISlider *volumeSlider;
@property (nonatomic, assign) CGFloat lastY;
@property (nonatomic, assign) double speedBeforeHold;
@property (nonatomic, weak) UILongPressGestureRecognizer *longPressGR;
@end

@implementation DYBGesture

+ (instancetype)shared { static DYBGesture *g; static dispatch_once_t t; dispatch_once(&t, ^{ g = [DYBGesture new]; }); return g; }

+ (void)install {
    DYBAsyncMain(^{
        [self attachIfNeeded];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(dybPrefsChanged:)
                                                     name:DYBPrefsChangedNotification
                                                   object:nil];
    });
}

+ (void)dybPrefsChanged:(NSNotification *)n {
    DYBGesture *g = DYBGesture.shared;
    g.longPressGR.cancelsTouchesInView = [[DYBPrefs shared] boolFor:DYBKey_replaceLongPress default:NO];
}

+ (void)attachIfNeeded {
    UIWindow *w = DYBKeyWindow();
    if (!w) return;
    if (objc_getAssociatedObject(w, &kDYBGestureAttached)) return;
    objc_setAssociatedObject(w, &kDYBGestureAttached, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    DYBGesture *g = DYBGesture.shared;

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:g action:@selector(longPress:)];
    lp.minimumPressDuration = 0.35;
    lp.delegate = g;
    // 需要「拦截抖音菜单」时才吃掉触摸；否则共存
    lp.cancelsTouchesInView = [[DYBPrefs shared] boolFor:DYBKey_replaceLongPress default:NO];
    lp.delaysTouchesEnded = NO;
    [w addGestureRecognizer:lp];
    g.longPressGR = lp;

    UITapGestureRecognizer *dt = [[UITapGestureRecognizer alloc] initWithTarget:g action:@selector(doubleTap:)];
    dt.numberOfTapsRequired = 2;
    dt.delegate = g;
    dt.cancelsTouchesInView = NO;   // 与抖音点赞共存
    dt.delaysTouchesEnded = NO;
    [w addGestureRecognizer:dt];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:g action:@selector(twoFingerPan:)];
    pan.minimumNumberOfTouches = 2; // 双指，避开上下刷视频
    pan.maximumNumberOfTouches = 2;
    pan.delegate = g;
    pan.cancelsTouchesInView = NO;
    [w addGestureRecognizer:pan];
}

#pragma mark 手势回调

- (void)longPress:(UILongPressGestureRecognizer *)g {
    DYBPrefs *p = DYBPrefs.shared;
    if (![DYBContext isFeedPlayerOnTop]) return;

    if (g.state == UIGestureRecognizerStateBegan) {
        if ([p boolFor:DYBKey_longPressMenu default:YES]) {
            DYBHaptic(UIImpactFeedbackStyleMedium);
            [DYBActions quickMenu];
            return;
        }
        double hold = [p floatFor:DYBKey_longPressSpeed default:2.0];
        if (hold > 1.01) {
            self.speedBeforeHold = [DYBActions currentRate] ?: 1.0;
            [DYBActions applySpeed:hold];
        }
    } else if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) {
        if (self.speedBeforeHold > 0) {
            [DYBActions applySpeed:self.speedBeforeHold];
            self.speedBeforeHold = 0;
        }
    }
}

- (void)doubleTap:(UITapGestureRecognizer *)g {
    if (![DYBContext isFeedPlayerOnTop]) return;
    NSInteger act = [[DYBPrefs shared] intFor:DYBKey_doubleTapAction default:0];
    switch (act) {
        case 1: [DYBActions openPanel]; break;
        case 2: [DYBActions downloadVideo]; break;
        case 3: [DYBActions toggleCleanScreen]; break;
        case 4: [DYBActions copyDirectLink]; break;
        default: break;
    }
}

- (void)twoFingerPan:(UIPanGestureRecognizer *)g {
    NSInteger mode = [[DYBPrefs shared] intFor:DYBKey_swipeMode default:0];
    if (mode == 0) return;
    if (![DYBContext isFeedPlayerOnTop]) return;
    CGPoint t = [g translationInView:g.view];
    if (g.state == UIGestureRecognizerStateBegan) { self.lastY = t.y; return; }
    CGFloat delta = (self.lastY - t.y) / 260.0;   // 向上为正
    self.lastY = t.y;
    if (fabs(delta) < 0.002) return;

    if (mode == 1) {
        CGFloat b = UIScreen.mainScreen.brightness + delta;
        UIScreen.mainScreen.brightness = MIN(MAX(b, 0.0), 1.0);
    } else if (mode == 2) {
        [self ensureVolumeSlider];
        CGFloat v = self.volumeSlider.value + delta;
        self.volumeSlider.value = MIN(MAX(v, 0.0), 1.0);
    } else if (mode == 3) {
        double cur = [DYBActions currentRate];
        if (cur <= 0) cur = 1.0;
        [DYBActions applySpeed:MIN(MAX(cur + delta, 0.5), 3.0)];
    }
}

#pragma mark 音量

- (void)ensureVolumeSlider {
    if (self.volumeSlider) return;
    self.volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-1000, -1000, 10, 10)];
    self.volumeView.hidden = YES;
    for (UIView *v in self.volumeView.subviews) {
        if ([v isKindOfClass:UISlider.class]) { self.volumeSlider = (UISlider *)v; break; }
    }
}

#pragma mark 手势共存

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)a shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)b {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldReceiveTouch:(UITouch *)touch {
    // 点在插件自己的窗口上时不处理
    if ([NSStringFromClass(touch.view.class) hasPrefix:@"DYB"]) return NO;
    return YES;
}

@end
