//
//  DYBStats.h
//  DYBoost
//
//  信息胶囊：FPS / 作品数据 / 直播观看时长
//

#import <UIKit/UIKit.h>

@interface DYBStats : NSObject

+ (void)install;
/// 页面切换后刷新
+ (void)update;

@end
