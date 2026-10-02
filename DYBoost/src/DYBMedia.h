//
//  DYBMedia.h
//  DYBoost
//
//  直链处理 / 下载 / 保存相册 / 导出文件
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, DYBMediaKind) {
    DYBMediaKindVideo = 0,
    DYBMediaKindImage,
    DYBMediaKindAudio,
};

@interface DYBMedia : NSObject

#pragma mark 链接判定
+ (BOOL)isVideoURL:(NSString *)u;
+ (BOOL)isImageURL:(NSString *)u;
+ (BOOL)isAudioURL:(NSString *)u;

/// 无水印化：playwm -> play，并去掉水印参数
+ (NSString *)noWatermark:(NSString *)u;

/// 从任意文本（分享文案 / 链接 / 浏览器 URL）里抽 aweme id
+ (NSString *)awemeIDFromText:(NSString *)text;

#pragma mark 解析
/// 用公开 web 接口补一次直链（当本地 model 里抓不到时用）
+ (void)resolveItem:(NSString *)awemeID completion:(void (^)(NSDictionary *info, NSError *error))c;

#pragma mark 下载 / 保存
+ (void)download:(NSString *)urlString
        progress:(void (^)(double p))progress
      completion:(void (^)(NSURL *file, NSError *error))c;

+ (void)saveVideo:(NSURL *)file completion:(void (^)(BOOL ok, NSError *error))c;
+ (void)saveImageData:(NSData *)data completion:(void (^)(BOOL ok, NSError *error))c;
+ (void)saveImages:(NSArray<NSString *> *)urls completion:(void (^)(NSInteger ok, NSInteger fail))c;

/// 宿主 App 是否声明了相册写入权限描述（没声明就别写相册，改用文件导出）
+ (BOOL)canWriteAlbum;
/// 用系统分享面板导出到文件/其它 App
+ (void)exportFile:(NSURL *)file fromVC:(UIViewController *)vc;

@end
