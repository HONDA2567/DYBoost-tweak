//
//  DYBTheme.h
//  DYBoost
//
//  统一的外观来源：亮/暗、主题色、玻璃与磨砂材质、圆角
//

#import <UIKit/UIKit.h>

@interface UIColor (DYB)
+ (UIColor *)dyb_colorWithHex:(NSString *)hex;
- (NSString *)dyb_hexString;
@end

@interface DYBTheme : NSObject

+ (BOOL)isDark;
+ (UIColor *)tint;                 // 用户主题色（未开启时用抖音红）
+ (UIColor *)accent;               // 主强调色
+ (UIColor *)bg;                   // 面板背景
+ (UIColor *)card;                 // 卡片背景
+ (UIColor *)textPrimary;
+ (UIColor *)textSecondary;
+ (UIColor *)separator;

+ (CGFloat)corner;                 // 面板圆角
+ (UIKeyboardAppearance)keyboard;

/// iOS 26+ 尝试原生 UIGlassEffect，失败/旧系统回落 UIBlurEffect
+ (UIVisualEffect *)glassEffect;
+ (UIBlurEffect *)blurEffect;
/// 造一个玻璃容器视图（内部已带圆角/描边）
+ (UIView *)glassContainerWithCorner:(CGFloat)corner;

+ (void)applyPanelLook:(UIView *)view;
@end
