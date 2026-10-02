//
//  DYBPrefs.h
//  DYBoost
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern NSString * const DYBPrefsChangedNotification;

@interface DYBPrefs : NSObject

+ (instancetype)shared;

- (BOOL)boolFor:(NSString *)key default:(BOOL)def;
- (void)setBool:(BOOL)v for:(NSString *)key;

- (double)floatFor:(NSString *)key default:(double)def;
- (void)setFloat:(double)v for:(NSString *)key;

- (NSInteger)intFor:(NSString *)key default:(NSInteger)def;
- (void)setInt:(NSInteger)v for:(NSString *)key;

- (NSString *)stringFor:(NSString *)key default:(NSString *)def;
- (void)setString:(NSString *)v for:(NSString *)key;

- (NSArray *)arrayFor:(NSString *)key;
- (void)setArray:(NSArray *)v for:(NSString *)key;

/// 恢复某一项到默认值
- (void)reset:(NSString *)key;
/// 恢复全部
- (void)resetAll;

/// 配置备份/恢复（JSON 字典）
- (NSDictionary *)exportSnapshot;
- (BOOL)importSnapshot:(NSDictionary *)snap;

/// 判断当前是否处于深色外观（受 panelTheme 控制）
- (BOOL)isDark;
@end
