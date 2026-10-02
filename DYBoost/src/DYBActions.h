//
//  DYBActions.h
//  DYBoost
//
//  所有「动作」的统一入口：悬浮球 / 手势 / 面板都调这里
//

#import <UIKit/UIKit.h>

@interface DYBActions : NSObject

/// 快捷菜单（下载/直链/封面/音频/倍速/清屏/面板）
+ (void)quickMenu;

+ (void)downloadVideo;
+ (void)copyDirectLink;
+ (void)saveCover;
+ (void)saveAudio;
+ (void)saveImages;
+ (void)chooseSpeed;
+ (void)applySpeed:(double)rate;
+ (void)applySpeed:(double)rate silent:(BOOL)silent;
+ (void)toggleCleanScreen;
+ (void)openPanel;

/// 当前播放倍速（找不到播放器时返回 0）
+ (double)currentRate;

@end
