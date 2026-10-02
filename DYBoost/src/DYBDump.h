//
//  DYBDump.h
//  DYBoost
//
//  真机校准用：把这台设备 / 这个抖音版本里真实存在的类名导出来。
//  拿不到砸壳 IPA 时，这是唯一靠谱的校准来源 —— 从面板导出，发给我，
//  我用 tools/calibrate.py 生成新的候选类名表。
//

#import <Foundation/Foundation.h>

@interface DYBDump : NSObject

/// 精简报告：版本 + 顶层 VC 链 + 关键字类名 + 每条隐藏规则的命中情况
+ (NSString *)report;
/// 完整类名清单（可能很大）
+ (NSString *)fullClassList;

+ (void)copyReport;
+ (void)shareReport;
+ (void)shareFullClassList;

@end
