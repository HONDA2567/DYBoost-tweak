//
//  DYBAweme.h
//  DYBoost
//
//  从抖音内部 model 里「盲取」字段：不 import 任何私有头文件，
//  靠候选属性名 + ivar 扫描 + URL 分类，版本变化不会导致崩溃，只会降级。
//

#import <Foundation/Foundation.h>

@interface DYBAweme : NSObject

@property (nonatomic, copy)   NSString *awemeID;
@property (nonatomic, copy)   NSString *desc;
@property (nonatomic, copy)   NSString *authorName;
@property (nonatomic, copy)   NSString *authorUID;
@property (nonatomic, copy)   NSArray<NSString *> *videoURLs;   // 已无水印化
@property (nonatomic, copy)   NSArray<NSString *> *imageURLs;
@property (nonatomic, copy)   NSArray<NSString *> *audioURLs;
@property (nonatomic, copy)   NSString *coverURL;
@property (nonatomic, strong) NSNumber *duration;               // 毫秒
@property (nonatomic, strong) NSNumber *diggCount;
@property (nonatomic, strong) NSNumber *commentCount;
@property (nonatomic, strong) NSNumber *collectCount;
@property (nonatomic, strong) NSNumber *shareCount;
@property (nonatomic, strong) NSNumber *playCount;
@property (nonatomic, assign) BOOL isAd;
@property (nonatomic, assign) BOOL isImagePost;

/// 解析一个抖音 model（AWEAwemeModel 之类）
+ (instancetype)parse:(id)model;

/// hook 侧把当前 model 报上来
+ (void)noteModel:(id)model;
/// 当前作品信息（必要时自动从顶层 VC 里找 model，带节流与预算）
+ (DYBAweme *)current;
/// 只返回已缓存的解析结果，绝不扫描（高频调用用这个）
+ (DYBAweme *)currentNoScan;
/// 强制重新扫描顶层 VC
+ (void)rescan;

@end
