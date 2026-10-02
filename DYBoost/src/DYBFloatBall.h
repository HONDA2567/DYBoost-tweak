//
//  DYBFloatBall.h
//  DYBoost
//

#import <UIKit/UIKit.h>

@interface DYBFloatBall : NSObject

+ (void)install;
/// 设置变化后刷新（大小/透明度/图标/显隐）
+ (void)applyPrefs;
+ (void)setVisible:(BOOL)visible;

@end
