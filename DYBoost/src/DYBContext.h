//
//  DYBContext.h
//  DYBoost
//

#import <UIKit/UIKit.h>

@interface DYBContext : NSObject

/// 在 UIViewController viewDidAppear 里调用
+ (void)noteViewControllerDidAppear:(UIViewController *)vc;
+ (UIViewController *)currentVC;
+ (NSString *)currentClassName;

/// 顶层是不是视频播放/信息流页（决定手势、悬浮球是否介入）
+ (BOOL)isFeedPlayerOnTop;
/// 顶层是不是直播间
+ (BOOL)isLiveOnTop;

/// 首次进入抖音界面时挂载：悬浮球 / 手势 / 胶囊
+ (void)installOnce;

@end
