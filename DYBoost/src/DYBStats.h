//
//  DYBStats.h
//  DYBoost
//
//  信息胶囊：FPS / 作品数据 / 直播观看时长
//

#import <UIKit/UIKit.h>

@interface DYBStats : NSObject

+ (void)install;
/// 轻量刷新：只管 FPS / 直播计时，不碰作品解析（页面切换高频调用用这个）
+ (void)updateLight;
/// 完整刷新：含作品数据解析，只在真正开了「作品数据」浮窗时用
+ (void)update;

@end
