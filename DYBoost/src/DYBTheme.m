//
//  DYBTheme.m
//  DYBoost
//

#import "DYBTheme.h"
#import "DYBPrefs.h"
#import "DYBKeys.h"

@implementation UIColor (DYB)

+ (UIColor *)dyb_colorWithHex:(NSString *)hex {
    if (hex.length == 0) return nil;
    NSString *h = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (h.length == 6) h = [h stringByAppendingString:@"ff"];
    if (h.length != 8) return nil;
    unsigned int v = 0;
    NSScanner *s = [NSScanner scannerWithString:h];
    if (![s scanHexInt:&v]) return nil;
    return [UIColor colorWithRed:((v >> 24) & 0xff) / 255.0
                           green:((v >> 16) & 0xff) / 255.0
                            blue:((v >> 8) & 0xff) / 255.0
                           alpha:(v & 0xff) / 255.0];
}

- (NSString *)dyb_hexString {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) return @"#FFFFFF";
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)(r * 255), (int)(g * 255), (int)(b * 255)];
}

@end

@implementation DYBTheme

+ (BOOL)isDark { return [[DYBPrefs shared] isDark]; }

+ (UIColor *)tint {
    DYBPrefs *p = DYBPrefs.shared;
    if ([p boolFor:DYBKey_tintEnabled default:NO]) {
        UIColor *c = [UIColor dyb_colorWithHex:[p stringFor:DYBKey_tintHex default:@"#FE2C55"]];
        if (c) return c;
    }
    return [UIColor colorWithRed:0xFE / 255.0 green:0x2C / 255.0 blue:0x55 / 255.0 alpha:1.0];
}

+ (UIColor *)accent { return [self tint]; }

+ (UIColor *)bg {
    return [self isDark] ? [UIColor colorWithWhite:0.07 alpha:1.0] : [UIColor colorWithWhite:0.96 alpha:1.0];
}

+ (UIColor *)card {
    return [self isDark] ? [UIColor colorWithWhite:0.14 alpha:1.0] : [UIColor whiteColor];
}

+ (UIColor *)textPrimary {
    return [self isDark] ? [UIColor whiteColor] : [UIColor colorWithWhite:0.10 alpha:1.0];
}

+ (UIColor *)textSecondary {
    return [self isDark] ? [UIColor colorWithWhite:0.70 alpha:1.0] : [UIColor colorWithWhite:0.45 alpha:1.0];
}

+ (UIColor *)separator {
    return [self isDark] ? [UIColor colorWithWhite:1.0 alpha:0.10] : [UIColor colorWithWhite:0.0 alpha:0.08];
}

+ (CGFloat)corner {
    return MAX(0.0, [[DYBPrefs shared] floatFor:DYBKey_panelCorner default:16.0]);
}

+ (UIKeyboardAppearance)keyboard {
    return [self isDark] ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
}

+ (UIBlurEffect *)blurEffect {
    if (@available(iOS 13.0, *)) {
        UIBlurEffectStyle st = [self isDark] ? UIBlurEffectStyleSystemMaterialDark : UIBlurEffectStyleSystemMaterialLight;
        return [UIBlurEffect effectWithStyle:st];
    }
    return [UIBlurEffect effectWithStyle:[self isDark] ? UIBlurEffectStyleDark : UIBlurEffectStyleLight];
}

+ (UIVisualEffect *)glassEffect {
    if (![[DYBPrefs shared] boolFor:DYBKey_nativeGlass default:YES]) return [self blurEffect];
    // iOS 26 起存在 UIGlassEffect；这里用 NSInvocation 试探，失败一律回落磨砂
    Class glassCls = NSClassFromString(@"UIGlassEffect");
    if (glassCls) {
        @try {
            SEL sel = NSSelectorFromString(@"effectWithStyle:");
            if ([glassCls respondsToSelector:sel]) {
                NSMethodSignature *sig = [glassCls methodSignatureForSelector:sel];
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                inv.selector = sel;
                NSInteger style = 0; // regular
                const char *argType = [sig getArgumentTypeAtIndex:2];
                if (argType && argType[0] == 'q') {
                    long long v = style; [inv setArgument:&v atIndex:2];
                } else {
                    NSInteger v = style; [inv setArgument:&v atIndex:2];
                }
                [inv setTarget:glassCls];
                [inv invoke];
                __unsafe_unretained id ret = nil;
                [inv getReturnValue:&ret];
                if (ret && [ret isKindOfClass:UIVisualEffect.class]) return (UIVisualEffect *)ret;
            } else {
                id e = [[glassCls alloc] init];
                if ([e isKindOfClass:UIVisualEffect.class]) return (UIVisualEffect *)e;
            }
        } @catch (NSException *e) { }
    }
    return [self blurEffect];
}

+ (UIView *)glassContainerWithCorner:(CGFloat)corner {
    UIVisualEffectView *v = [[UIVisualEffectView alloc] initWithEffect:[self glassEffect]];
    v.layer.cornerRadius = corner;
    v.layer.cornerCurve = kCACornerCurveContinuous;
    v.clipsToBounds = YES;
    UIView *overlay = [[UIView alloc] initWithFrame:v.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.04];
    [v.contentView addSubview:overlay];
    return v;
}

+ (void)applyPanelLook:(UIView *)view {
    view.backgroundColor = [self bg];
    view.tintColor = [self tint];
}

@end
