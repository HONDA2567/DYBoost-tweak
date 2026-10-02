//
//  DYBFloatBall.m
//  DYBoost
//

#import "DYBFloatBall.h"
#import "DYBPrefs.h"
#import "DYBKeys.h"
#import "DYBTheme.h"
#import "DYBHookKit.h"
#import "DYBActions.h"
#import "DYBHUD.h"

static UIWindow *gBallWindow;
static UIView *gBallView;
static UIImageView *gIconView;
static NSTimer *gIdleTimer;
static CGFloat gBaseAlpha = 0.85;
static CGPoint gDragStart;
static CGPoint gOriginStart;

@implementation DYBFloatBall

+ (void)install {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        DYBAsyncMain(^{
            [self build];
            [self applyPrefs];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(dybPrefsChanged:)
                                                         name:DYBPrefsChangedNotification
                                                       object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(orientationChanged:)
                                                         name:UIApplicationDidChangeStatusBarOrientationNotification
                                                       object:nil];
        });
    });
}

+ (void)build {
    if (gBallWindow) return;
    CGFloat s = [[DYBPrefs shared] floatFor:DYBKey_floatBallSize default:54.0];
    UIWindow *w;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = (UIWindowScene *)DYBKeyWindow().windowScene;
        w = scene ? [[UIWindow alloc] initWithWindowScene:scene] : [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    } else {
        w = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }
    w.frame = CGRectMake(0, 0, s, s);
    w.windowLevel = UIWindowLevelAlert - 1.0;
    w.backgroundColor = UIColor.clearColor;
    w.hidden = YES;

    UIVisualEffectView *bg = [[UIVisualEffectView alloc] initWithEffect:[DYBTheme glassEffect]];
    bg.frame = w.bounds;
    bg.layer.cornerRadius = s / 2.0;
    bg.clipsToBounds = YES;
    bg.layer.borderWidth = 0.5;
    bg.layer.borderColor = [[DYBTheme separator] CGColor];
    [w addSubview:bg];

    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectInset(w.bounds, s * 0.24, s * 0.24)];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.tintColor = [DYBTheme tint];
    [w addSubview:icon];
    gIconView = icon;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    [w addGestureRecognizer:pan];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [w addGestureRecognizer:tap];
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    lp.minimumPressDuration = 0.45;
    [w addGestureRecognizer:lp];

    gBallView = bg;
    gBallWindow = w;
    [self layoutByPrefs];
}

+ (void)layoutByPrefs {
    CGFloat s = [[DYBPrefs shared] floatFor:DYBKey_floatBallSize default:54.0];
    CGRect screen = UIScreen.mainScreen.bounds;
    CGFloat x = [[DYBPrefs shared] floatFor:DYBKey_floatBallPosX default:0.92];
    CGFloat y = [[DYBPrefs shared] floatFor:DYBKey_floatBallPosY default:0.62];
    CGFloat cx = MIN(MAX(x, 0.03), 0.97) * screen.size.width;
    CGFloat cy = MIN(MAX(y, 0.05), 0.95) * screen.size.height;
    gBallWindow.frame = CGRectMake(cx - s / 2.0, cy - s / 2.0, s, s);
    gBallView.frame = gBallWindow.bounds;
    gBallView.layer.cornerRadius = s / 2.0;
    gIconView.frame = CGRectInset(gBallWindow.bounds, s * 0.24, s * 0.24);
}

+ (void)dybPrefsChanged:(NSNotification *)n { [self applyPrefs]; }

+ (void)applyPrefs {
    DYBAsyncMain(^{
        if (!gBallWindow) [self build];
        if (!gBallWindow) return;
        BOOL on = [[DYBPrefs shared] boolFor:DYBKey_floatBall default:YES];
        gBallWindow.hidden = !on;
        if (!on) return;
        [self layoutByPrefs];
        gBaseAlpha = [[DYBPrefs shared] floatFor:DYBKey_floatBallAlpha default:0.85];
        gBallWindow.alpha = gBaseAlpha;
        [self updateIcon];
        [self scheduleIdle];
    });
}

+ (void)updateIcon {
    NSInteger pack = [[DYBPrefs shared] intFor:DYBKey_iconPack default:0];
    NSString *b64 = [[DYBPrefs shared] stringFor:DYBKey_customIconB64 default:@""];
    if (pack == 3 && b64.length > 0) {
        NSData *d = [[NSData alloc] initWithBase64EncodedString:b64 options:0];
        UIImage *img = [UIImage imageWithData:d];
        if (img) { gIconView.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]; return; }
    }
    gIconView.tintColor = [DYBTheme tint];
    NSString *name = @"bolt.fill";
    if (pack == 1) name = @"circle";
    if (pack == 2) name = @"sparkles";
    UIImage *img = nil;
    if (@available(iOS 13.0, *)) img = [UIImage systemImageNamed:name];
    gIconView.image = img;
    if (pack == 2) {
        gIconView.layer.shadowColor = [DYBTheme tint].CGColor;
        gIconView.layer.shadowRadius = 8;
        gIconView.layer.shadowOpacity = 0.9;
    } else {
        gIconView.layer.shadowOpacity = 0;
    }
}

+ (void)setVisible:(BOOL)visible {
    DYBAsyncMain(^{ if (gBallWindow) gBallWindow.hidden = !visible; });
}

#pragma mark 交互

+ (void)touch {
    gBallWindow.alpha = gBaseAlpha;
    [self scheduleIdle];
}

+ (void)scheduleIdle {
    [gIdleTimer invalidate];
    if (![[DYBPrefs shared] boolFor:DYBKey_floatBallAutoHide default:YES]) return;
    gIdleTimer = [NSTimer scheduledTimerWithTimeInterval:4.0 repeats:NO block:^(NSTimer *t) {
        [UIView animateWithDuration:0.4 animations:^{
            gBallWindow.alpha = MAX(0.15, gBaseAlpha * 0.35);
        }];
    }];
}

+ (void)tap:(UITapGestureRecognizer *)g {
    [self touch];
    DYBHaptic(UIImpactFeedbackStyleLight);
    [DYBActions quickMenu];
}

+ (void)longPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    [self touch];
    DYBHaptic(UIImpactFeedbackStyleMedium);
    [DYBActions openPanel];
}

+ (void)pan:(UIPanGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) {
        gDragStart = [g translationInView:gBallWindow];
        gOriginStart = gBallWindow.frame.origin;
        gBallWindow.alpha = gBaseAlpha;
    } else if (g.state == UIGestureRecognizerStateChanged) {
        CGPoint t = [g translationInView:gBallWindow];
        CGFloat nx = gOriginStart.x + (t.x - gDragStart.x);
        CGFloat ny = gOriginStart.y + (t.y - gDragStart.y);
        CGRect f = gBallWindow.frame;
        f.origin = CGPointMake(nx, ny);
        gBallWindow.frame = f;
    } else if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) {
        CGRect screen = UIScreen.mainScreen.bounds;
        CGRect f = gBallWindow.frame;
        // 边缘吸附
        CGFloat left = f.origin.x, right = screen.size.width - CGRectGetMaxX(f);
        f.origin.x = (left < right) ? 8 : screen.size.width - f.size.width - 8;
        f.origin.y = MIN(MAX(f.origin.y, 80), screen.size.height - f.size.height - 80);
        [UIView animateWithDuration:0.25 animations:^{ gBallWindow.frame = f; }];
        [[DYBPrefs shared] setFloat:(f.origin.x + f.size.width / 2.0) / screen.size.width for:DYBKey_floatBallPosX];
        [[DYBPrefs shared] setFloat:(f.origin.y + f.size.height / 2.0) / screen.size.height for:DYBKey_floatBallPosY];
        [self scheduleIdle];
    }
}

+ (void)orientationChanged:(NSNotification *)n {
    DYBAsyncMainAfter(0.3, ^{ [self layoutByPrefs]; });
}

@end
