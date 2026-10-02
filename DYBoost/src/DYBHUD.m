//
//  DYBHUD.m
//  DYBoost
//

#import "DYBHUD.h"
#import "DYBTheme.h"
#import "DYBHookKit.h"

static const CGFloat kHUDWindowLevelOffset = 10.0;

@interface DYBHUDWindow : UIWindow
@end

@implementation DYBHUDWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event { return NO; }
@end

@interface DYBHUD ()
@property (nonatomic, strong) UIWindow *win;
@property (nonatomic, strong) UIWindow *loadWin;
@property (nonatomic, strong) UILabel *loadLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSTimer *hideTimer;
@end

@implementation DYBHUD

+ (instancetype)shared { static DYBHUD *h; static dispatch_once_t t; dispatch_once(&t, ^{ h = [DYBHUD new]; }); return h; }

#pragma mark - Toast

+ (void)show:(NSString *)text { [self show:text duration:1.6]; }

+ (void)show:(NSString *)text duration:(NSTimeInterval)d {
    if (text.length == 0) return;
    DYBAsyncMain(^{
        DYBHUD *h = DYBHUD.shared;
        [h.hideTimer invalidate];
        if (!h.win) {
            h.win = [[DYBHUDWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
            h.win.windowLevel = UIWindowLevelAlert + kHUDWindowLevelOffset;
            h.win.backgroundColor = UIColor.clearColor;
            h.win.userInteractionEnabled = NO;
            UILabel *lb = [[UILabel alloc] initWithFrame:CGRectZero];
            lb.tag = 7;
            lb.numberOfLines = 0;
            lb.textAlignment = NSTextAlignmentCenter;
            lb.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
            lb.layer.cornerRadius = 14;
            lb.layer.masksToBounds = YES;
            [h.win addSubview:lb];
            h.win.hidden = NO;
        }
        UILabel *lb = [h.win viewWithTag:7];
        lb.text = text;
        lb.textColor = UIColor.whiteColor;
        UIBlurEffect *eff = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        static NSInteger veilTag = 8;
        UIVisualEffectView *veil = [lb viewWithTag:veilTag];
        if (!veil) {
            veil = [[UIVisualEffectView alloc] initWithEffect:eff];
            veil.tag = veilTag;
            [lb addSubview:veil];
            [lb sendSubviewToBack:veil];
        }
        veil.frame = lb.bounds;
        veil.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        CGSize max = CGSizeMake(UIScreen.mainScreen.bounds.size.width - 80, 300);
        CGRect r = [text boundingRectWithSize:max
                                     options:NSStringDrawingUsesLineFragmentOrigin
                                  attributes:@{NSFontAttributeName: lb.font}
                                     context:nil];
        CGFloat w = ceil(r.size.width) + 32;
        CGFloat ht = ceil(r.size.height) + 22;
        lb.bounds = CGRectMake(0, 0, MAX(80, w), MAX(36, ht));
        lb.center = CGPointMake(UIScreen.mainScreen.bounds.size.width / 2.0,
                                UIScreen.mainScreen.bounds.size.height * 0.82);
        lb.alpha = 0;
        h.win.hidden = NO;
        [UIView animateWithDuration:0.18 animations:^{ lb.alpha = 1.0; }];
        h.hideTimer = [NSTimer scheduledTimerWithTimeInterval:d repeats:NO block:^(NSTimer *timer) {
            [UIView animateWithDuration:0.22 animations:^{ lb.alpha = 0.0; } completion:^(BOOL f) {
                h.win.hidden = YES;
            }];
        }];
    });
}

#pragma mark - Loading

+ (void)showLoading:(NSString *)text {
    DYBAsyncMain(^{
        DYBHUD *h = DYBHUD.shared;
        if (!h.loadWin) {
            h.loadWin = [[DYBHUDWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
            h.loadWin.windowLevel = UIWindowLevelAlert + kHUDWindowLevelOffset;
            h.loadWin.backgroundColor = UIColor.clearColor;
            h.loadWin.userInteractionEnabled = NO;
            UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 84)];
            box.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
            box.layer.cornerRadius = 16;
            CGRect sBounds = UIScreen.mainScreen.bounds;
            box.center = CGPointMake(CGRectGetMidX(sBounds), CGRectGetMidY(sBounds));
            UIActivityIndicatorView *sp = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
            sp.center = CGPointMake(90, 30);
            [sp startAnimating];
            UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(10, 52, 160, 24)];
            lb.font = [UIFont systemFontOfSize:13];
            lb.textColor = UIColor.whiteColor;
            lb.textAlignment = NSTextAlignmentCenter;
            [box addSubview:sp];
            [box addSubview:lb];
            h.loadLabel = lb;
            h.spinner = sp;
            [h.loadWin addSubview:box];
        }
        h.loadLabel.text = text ?: @"处理中...";
        h.loadWin.hidden = NO;
    });
}

+ (void)updateLoading:(NSString *)text {
    DYBAsyncMain(^{ DYBHUD.shared.loadLabel.text = text; });
}

+ (void)hideLoading {
    DYBAsyncMain(^{ DYBHUD.shared.loadWin.hidden = YES; });
}

#pragma mark - Banner

+ (void)banner:(NSString *)text {
    if (text.length == 0) return;
    DYBAsyncMain(^{
        UIWindow *win = [[DYBHUDWindow alloc] initWithFrame:
                         CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, 140)];
        win.windowLevel = UIWindowLevelAlert + kHUDWindowLevelOffset;
        win.backgroundColor = UIColor.clearColor;
        win.userInteractionEnabled = NO;
        win.hidden = NO;

        UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, UIScreen.mainScreen.bounds.size.width - 32, 120)];
        lb.numberOfLines = 0;
        lb.font = [UIFont systemFontOfSize:13];
        lb.textColor = UIColor.whiteColor;
        lb.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.82];
        lb.layer.cornerRadius = 12;
        lb.layer.masksToBounds = YES;
        lb.text = [NSString stringWithFormat:@"\n%@\n", text];
        lb.transform = CGAffineTransformMakeTranslation(0, -160);
        [win addSubview:lb];
        [UIView animateWithDuration:0.25 animations:^{ lb.transform = CGAffineTransformIdentity; }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.25 animations:^{ lb.transform = CGAffineTransformMakeTranslation(0, -160); }
                             completion:^(BOOL f) { win.hidden = YES; }];
        });
    });
}

@end
