//
//  DYBGesture.h
//  DYBoost
//
//  全局手势：长按菜单 / 长按加速 / 双指上下滑调节 / 双击动作
//

#import <UIKit/UIKit.h>

@interface DYBGesture : NSObject

+ (void)install;
/// 窗口换了（比如抖音重建 Window）时重新挂一次
+ (void)attachIfNeeded;

@end
