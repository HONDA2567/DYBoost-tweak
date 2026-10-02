//
//  DYBBeauty.h
//  DYBoost
//
//  美化层：底栏/顶栏玻璃、进度条样式、元素隐藏、清屏模式
//

#import <UIKit/UIKit.h>

@interface DYBBeauty : NSObject

+ (void)install;
/// 页面切换后刷一遍（带节流）
+ (void)refresh;
/// 设置变化后立刻刷一遍
+ (void)refreshNow;

+ (BOOL)isCleanScreen;
+ (void)setCleanScreen:(BOOL)on;

/// 诊断：每条规则命中的类名，给面板「诊断」页展示
+ (NSDictionary<NSString *, NSString *> *)diagnose;

@end
