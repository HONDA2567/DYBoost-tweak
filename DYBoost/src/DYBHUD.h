//
//  DYBHUD.h
//  DYBoost
//

#import <UIKit/UIKit.h>

@interface DYBHUD : NSObject

+ (void)show:(NSString *)text;
+ (void)show:(NSString *)text duration:(NSTimeInterval)d;
/// 常驻进度提示（下载/转码用），返回后可用 update/hide 刷新
+ (void)showLoading:(NSString *)text;
+ (void)updateLoading:(NSString *)text;
+ (void)hideLoading;
/// 顶部横幅（多行）
+ (void)banner:(NSString *)text;
@end
