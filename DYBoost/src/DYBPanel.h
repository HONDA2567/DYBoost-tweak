//
//  DYBPanel.h
//  DYBoost
//
//  内置控制面板：不依赖设置 App / PreferenceLoader，直接在抖音里打开
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, DYBItemType) {
    DYBItemTypeSwitch = 0,
    DYBItemTypeChoose,
    DYBItemTypeSlider,
    DYBItemTypeColor,
    DYBItemTypeAction,
    DYBItemTypePage,
    DYBItemTypeText,
    DYBItemTypeLongText,   // 多行编辑（提示词这类）
};

@interface DYBItem : NSObject
@property (nonatomic, copy)   NSString *key;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *subtitle;
@property (nonatomic, assign) DYBItemType type;
@property (nonatomic, copy)   NSArray<NSString *> *options;
@property (nonatomic, assign) double min;
@property (nonatomic, assign) double max;
@property (nonatomic, assign) BOOL integerValue;
@property (nonatomic, assign) BOOL experimental;
@property (nonatomic, copy)   void (^action)(void);
@property (nonatomic, copy)   NSArray<DYBItem *> *(^children)(void);
/// 密文类条目（API Key）：走弹框输入，值不落在 NSUserDefaults 快照里
@property (nonatomic, copy)   NSString *(^secretGet)(void);
@property (nonatomic, copy)   void (^secretSet)(NSString *value);

+ (instancetype)sw:(NSString *)key title:(NSString *)title sub:(NSString *)subtitle;
+ (instancetype)choose:(NSString *)key title:(NSString *)title sub:(NSString *)subtitle options:(NSArray<NSString *> *)options;
+ (instancetype)slider:(NSString *)key title:(NSString *)title sub:(NSString *)subtitle min:(double)min max:(double)max;
+ (instancetype)color:(NSString *)key title:(NSString *)title sub:(NSString *)subtitle;
+ (instancetype)action:(NSString *)title sub:(NSString *)subtitle block:(void (^)(void))block;
+ (instancetype)page:(NSString *)title sub:(NSString *)subtitle children:(NSArray<DYBItem *> *(^)(void))children;
+ (instancetype)text:(NSString *)key title:(NSString *)title sub:(NSString *)subtitle;
+ (instancetype)longText:(NSString *)key title:(NSString *)title sub:(NSString *)subtitle;
/// 动作条目，但值为文本（用于 API Key 这类需要弹框输入的）
+ (instancetype)secret:(NSString *)title sub:(NSString *)subtitle
                   get:(NSString *(^)(void))get
                   set:(void (^)(NSString *value))set;

/// 当前值的展示文本
- (NSString *)currentText;
@end

@interface DYBSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *footer;
@property (nonatomic, copy) NSArray<DYBItem *> *items;
+ (instancetype)section:(NSString *)title footer:(NSString *)footer items:(NSArray<DYBItem *> *)items;
@end

@interface DYBPanel : UIViewController

/// 从任意位置打开主面板
+ (void)presentRoot;
+ (void)dismissPanel;

- (instancetype)initWithTitle:(NSString *)title sections:(NSArray<DYBSection *> *)sections;
@end
