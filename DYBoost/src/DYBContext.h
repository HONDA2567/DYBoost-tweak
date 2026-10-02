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

/// 标记「需要作品数据」。默认关闭——对象图扫描只在用户真的要用
/// 下载 / 直链 / AI / 作品数据浮窗时才开启，避免启动期白跑。
+ (void)setNeedsModel:(BOOL)on;
+ (BOOL)needsModel;
/// 空闲 + 节流地扫一次当前作品 model
+ (void)scheduleModelScan;

@end
