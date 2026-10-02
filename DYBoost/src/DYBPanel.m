//
//  DYBPanel.m
//  DYBoost
//

#import "DYBPanel.h"
#import "DYBPrefs.h"
#import "DYBKeys.h"
#import "DYBTheme.h"
#import "DYBHUD.h"
#import "DYBMenu.h"
#import "DYBActions.h"
#import "DYBBeauty.h"
#import "DYBFloatBall.h"
#import "DYBMedia.h"
#import "DYBHookKit.h"
#import "DYBAI.h"
#import "DYBDump.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#pragma mark - 模型

@implementation DYBItem

+ (instancetype)sw:(NSString *)key title:(NSString *)title sub:(NSString *)subtitle {
    DYBItem *i = [DYBItem new]; i.key = key; i.title = title; i.subtitle = subtitle; i.type = DYBItemTypeSwitch; return i;
}
+ (instancetype)choose:(NSString *)key title:(NSString *)title sub:(NSString *)subtitle options:(NSArray<NSString *> *)options {
    DYBItem *i = [DYBItem new]; i.key = key; i.title = title; i.subtitle = subtitle; i.type = DYBItemTypeChoose; i.options = options; return i;
}
+ (instancetype)slider:(NSString *)key title:(NSString *)title sub:(NSString *)subtitle min:(double)min max:(double)max {
    DYBItem *i = [DYBItem new]; i.key = key; i.title = title; i.subtitle = subtitle; i.type = DYBItemTypeSlider; i.min = min; i.max = max; return i;
}
+ (instancetype)color:(NSString *)key title:(NSString *)title sub:(NSString *)subtitle {
    DYBItem *i = [DYBItem new]; i.key = key; i.title = title; i.subtitle = subtitle; i.type = DYBItemTypeColor; return i;
}
+ (instancetype)action:(NSString *)title sub:(NSString *)subtitle block:(void (^)(void))block {
    DYBItem *i = [DYBItem new]; i.title = title; i.subtitle = subtitle; i.type = DYBItemTypeAction; i.action = block; return i;
}
+ (instancetype)page:(NSString *)title sub:(NSString *)subtitle children:(NSArray<DYBItem *> *(^)(void))children {
    DYBItem *i = [DYBItem new]; i.title = title; i.subtitle = subtitle; i.type = DYBItemTypePage; i.children = children; return i;
}
+ (instancetype)text:(NSString *)key title:(NSString *)title sub:(NSString *)subtitle {
    DYBItem *i = [DYBItem new]; i.key = key; i.title = title; i.subtitle = subtitle; i.type = DYBItemTypeText; return i;
}
+ (instancetype)longText:(NSString *)key title:(NSString *)title sub:(NSString *)subtitle {
    DYBItem *i = [DYBItem new]; i.key = key; i.title = title; i.subtitle = subtitle; i.type = DYBItemTypeLongText; return i;
}
+ (instancetype)secret:(NSString *)title sub:(NSString *)subtitle
                   get:(NSString *(^)(void))get set:(void (^)(NSString *value))set {
    DYBItem *i = [DYBItem new]; i.title = title; i.subtitle = subtitle; i.type = DYBItemTypeAction;
    i.secretGet = get; i.secretSet = set;
    __weak DYBItem *weakItem = i;
    i.action = ^{
        NSString *cur = weakItem.secretGet ? weakItem.secretGet() : @"";
        [DYBMenu input:title message:subtitle text:cur placeholder:@"sk-..." done:^(NSString *t) {
            if (weakItem.secretSet) weakItem.secretSet(t ?: @"");
        }];
    };
    return i;
}

- (NSString *)currentText {
    DYBPrefs *p = DYBPrefs.shared;
    if (self.secretGet) {
        NSString *v = self.secretGet();
        return v.length ? @"已设置" : @"未设置";
    }
    switch (self.type) {
        case DYBItemTypeSwitch: return [p boolFor:self.key default:NO] ? @"开" : @"关";
        case DYBItemTypeChoose: {
            NSInteger i = [p intFor:self.key default:0];
            return (i >= 0 && i < (NSInteger)self.options.count) ? self.options[i] : @"—";
        }
        case DYBItemTypeSlider: return [NSString stringWithFormat:@"%.2f", [p floatFor:self.key default:0]];
        case DYBItemTypeColor:  return [p stringFor:self.key default:@"#FE2C55"];
        case DYBItemTypeText:   return [p stringFor:self.key default:@""];
        case DYBItemTypeLongText: {
            NSString *s = [p stringFor:self.key default:@""];
            return s.length ? [[s componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet] firstObject] : @"";
        }
        default: return @"";
    }
}

@end

@implementation DYBSection
+ (instancetype)section:(NSString *)title footer:(NSString *)footer items:(NSArray<DYBItem *> *)items {
    DYBSection *s = [DYBSection new]; s.title = title; s.footer = footer; s.items = items; return s;
}
@end

#pragma mark - 多行文本编辑页（提示词）

@interface DYBTextPage : UIViewController
@property (nonatomic, strong) DYBItem *item;
@property (nonatomic, strong) UITextView *tv;
- (instancetype)initWithItem:(DYBItem *)item;
@end

@implementation DYBTextPage

- (instancetype)initWithItem:(DYBItem *)item {
    if (self = [super init]) { self.item = item; }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.item.title;
    self.view.backgroundColor = [DYBTheme bg];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                          target:self action:@selector(save)];
    UIEdgeInsets safe = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) safe = self.view.safeAreaInsets;
    CGRect f = UIEdgeInsetsInsetRect(self.view.bounds, UIEdgeInsetsMake(safe.top + 8, 12, 8, 12));
    self.tv = [[UITextView alloc] initWithFrame:f];
    self.tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tv.font = [UIFont systemFontOfSize:15];
    self.tv.textColor = [DYBTheme textPrimary];
    self.tv.backgroundColor = [DYBTheme card];
    self.tv.text = [[DYBPrefs shared] stringFor:self.item.key default:@""];
    self.tv.autocorrectionType = UITextAutocorrectionTypeNo;
    self.tv.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [self.view addSubview:self.tv];
    [self.tv becomeFirstResponder];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboard:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
}

- (void)keyboard:(NSNotification *)n {
    CGRect end = [n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect r = self.view.bounds;
    CGFloat overlap = MAX(0, r.size.height - end.origin.y);
    UIEdgeInsets insets = self.tv.contentInset;
    insets.bottom = overlap + 12;
    self.tv.contentInset = insets;
    self.tv.scrollIndicatorInsets = insets;
}

- (void)save {
    [[DYBPrefs shared] setString:self.tv.text ?: @"" for:self.item.key];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.item) [[DYBPrefs shared] setString:self.tv.text ?: @"" for:self.item.key];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

#pragma mark - 滑杆页

@interface DYBSliderPage : UIViewController
@property (nonatomic, strong) DYBItem *item;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UILabel *valueLabel;
@end

@implementation DYBSliderPage

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.item.title;
    self.view.backgroundColor = [DYBTheme bg];
    CGFloat w = self.view.bounds.size.width;
    self.slider = [[UISlider alloc] initWithFrame:CGRectMake(24, 160, w - 48, 40)];
    self.slider.minimumValue = self.item.min;
    self.slider.maximumValue = self.item.max;
    self.slider.value = [[DYBPrefs shared] floatFor:self.item.key default:self.item.min];
    self.slider.tintColor = [DYBTheme tint];
    [self.slider addTarget:self action:@selector(changed:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.slider];

    self.valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, 120, w - 48, 30)];
    self.valueLabel.textColor = [DYBTheme textPrimary];
    self.valueLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
    [self.view addSubview:self.valueLabel];
    [self changed:nil];

    UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(24, 210, w - 48, 60)];
    tip.numberOfLines = 0;
    tip.textColor = [DYBTheme textSecondary];
    tip.font = [UIFont systemFontOfSize:13];
    tip.text = self.item.subtitle;
    [self.view addSubview:tip];
}

- (void)changed:(UISlider *)s {
    double v = self.slider.value;
    if (self.item.integerValue) { v = round(v); self.slider.value = v; }
    self.valueLabel.text = self.item.integerValue ? [NSString stringWithFormat:@"%d", (int)v]
                                                  : [NSString stringWithFormat:@"%.2f", v];
    if (s) [[DYBPrefs shared] setFloat:v for:self.item.key];
}

@end

#pragma mark - 面板

static UIWindow *gPanelWindow;

@interface DYBPanel () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate,
                        UIColorPickerViewControllerDelegate, UIDocumentPickerDelegate>
@property (nonatomic, copy) NSArray<DYBSection *> *sections;
@property (nonatomic, copy) NSArray<DYBItem *> *flat;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, strong) DYBItem *pickingColorItem;
@end

@implementation DYBPanel

+ (void)presentRoot {
    DYBAsyncMain(^{
        if (gPanelWindow) { gPanelWindow.hidden = NO; return; }
        UIWindow *w;
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = (UIWindowScene *)DYBKeyWindow().windowScene;
            w = scene ? [[UIWindow alloc] initWithWindowScene:scene] : [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        } else {
            w = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        }
        w.frame = UIScreen.mainScreen.bounds;
        w.windowLevel = UIWindowLevelAlert + 50;
        w.backgroundColor = UIColor.clearColor;

        DYBPanel *root = [[DYBPanel alloc] initWithTitle:@"DYBoost" sections:[self rootSections]];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
        w.rootViewController = nav;
        gPanelWindow = w;
        w.hidden = NO;
        w.alpha = 0.0;
        w.transform = CGAffineTransformMakeScale(0.96, 0.96);
        [UIView animateWithDuration:0.22 animations:^{ w.alpha = 1.0; w.transform = CGAffineTransformIdentity; }];
    });
}

+ (void)dismissPanel {
    DYBAsyncMain(^{
        UIWindow *w = gPanelWindow;
        if (!w) return;
        [UIView animateWithDuration:0.18 animations:^{ w.alpha = 0.0; w.transform = CGAffineTransformMakeScale(0.96, 0.96); }
                         completion:^(BOOL f) {
            w.hidden = YES; w.rootViewController = nil; gPanelWindow = nil;
        }];
    });
}

- (instancetype)initWithTitle:(NSString *)title sections:(NSArray<DYBSection *> *)sections {
    if (self = [super init]) {
        self.title = title;
        self.sections = sections;
        NSMutableArray *f = [NSMutableArray array];
        for (DYBSection *s in sections) [f addObjectsFromArray:s.items];
        self.flat = f;
    }
    return self;
}

#pragma mark 构建页面

+ (NSArray<DYBSection *> *)rootSections {
    DYBPrefs *p = DYBPrefs.shared;

    NSArray *enhance = @[
        [DYBItem sw:DYBKey_noWatermark title:@"无水印下载" sub:@"下载视频时把 playwm 换成 play 并去掉水印参数"],
        [DYBItem sw:DYBKey_copyLink title:@"复制无水印直链" sub:@"快捷菜单里可复制当前作品直链"],
        [DYBItem sw:DYBKey_saveAlbum title:@"图集一键保存" sub:@"图集作品一次写多张到相册"],
        [DYBItem slider:DYBKey_defaultSpeed title:@"默认倍速" sub:@"进入视频时尝试套用（找不到播放器则无效）" min:0.5 max:3.0],
        [DYBItem slider:DYBKey_longPressSpeed title:@"长按倍速" sub:@"长按屏幕时临时加速的值" min:1.0 max:3.0],
        [DYBItem sw:DYBKey_tapSeek title:@"点击进度条跳转" sub:@"打开系统播放器进度定位能力"],
        [DYBItem choose:DYBKey_swipeMode title:@"双指上下滑" sub:@"双指上下滑动调节，避免和刷视频冲突"
                 options:@[@"关闭", @"亮度", @"音量", @"倍速"]],
        [DYBItem choose:DYBKey_doubleTapAction title:@"双击屏幕动作" sub:@"双击会与抖音点赞共存，谨慎开启"
                 options:@[@"关闭", @"打开面板", @"下载当前视频", @"清屏", @"复制直链"]],
        [DYBItem sw:DYBKey_longPressMenu title:@"长按出插件菜单" sub:@"长按视频弹出下载/直链/倍速等"],
        [DYBItem sw:DYBKey_replaceLongPress title:@"拦截抖音原生长按菜单" sub:@"开启后抖音自己的长按菜单会被吃掉"],
        [DYBItem sw:DYBKey_haptic title:@"触感反馈" sub:@""],
        [DYBItem sw:DYBKey_showFPS title:@"帧率胶囊" sub:@"左上角显示实时 FPS"],
        [DYBItem sw:DYBKey_showStats title:@"作品数据" sub:@"右侧显示点赞/评论/收藏等真实数据"],
        [DYBItem sw:DYBKey_showLiveDuration title:@"直播时长" sub:@"进直播间后显示观看时长"],
    ];

    NSArray *beauty = @[
        [DYBItem sw:DYBKey_beautyMaster title:@"美化总开关" sub:@""],
        [DYBItem sw:DYBKey_glassTabBar title:@"底栏玻璃" sub:@"底栏换成毛玻璃 / iOS26 原生液态玻璃"],
        [DYBItem slider:DYBKey_tabBarCorner title:@"底栏圆角" sub:@"0 直角，1 最大" min:0 max:1],
        [DYBItem sw:DYBKey_hideTabLabels title:@"隐藏底栏文字" sub:@"只留图标"],
        [DYBItem sw:DYBKey_glassNavBar title:@"顶栏玻璃" sub:@"导航条毛玻璃化"],
        [DYBItem sw:DYBKey_nativeGlass title:@"iOS26 原生玻璃" sub:@"系统存在 UIGlassEffect 时用原生，否则回落磨砂"],
        [DYBItem sw:DYBKey_tintEnabled title:@"自定义主题色" sub:@"开启后按钮/强调色用下面这个颜色"],
        [DYBItem color:DYBKey_tintHex title:@"主题色" sub:@"点开取色"],
        [DYBItem choose:DYBKey_progressStyle title:@"进度条样式" sub:@""
                 options:@[@"原生", @"细线", @"胶囊", @"亮色脉冲"]],
        [DYBItem slider:DYBKey_progressHeight title:@"进度条高度" sub:@"0 = 跟随原生" min:0 max:12],
        [DYBItem color:DYBKey_progressHex title:@"进度条颜色" sub:@""],
        [DYBItem page:@"面板与悬浮球" sub:@"面板主题、圆角、悬浮球、图标包" children:^NSArray<DYBItem *> * {
            return @[
                [DYBItem choose:DYBKey_panelTheme title:@"面板明暗" sub:@"" options:@[@"跟随系统", @"固定浅色", @"固定深色"]],
                [DYBItem slider:DYBKey_panelCorner title:@"面板圆角" sub:@"" min:0 max:32],
                [DYBItem sw:DYBKey_floatBall title:@"悬浮球" sub:@"点一下出快捷菜单，长按开面板"],
                [DYBItem slider:DYBKey_floatBallSize title:@"悬浮球大小" sub:@"" min:34 max:80],
                [DYBItem slider:DYBKey_floatBallAlpha title:@"悬浮球不透明度" sub:@"" min:0.2 max:1.0],
                [DYBItem sw:DYBKey_floatBallAutoHide title:@"闲置自动淡出" sub:@""],
                [DYBItem choose:DYBKey_iconPack title:@"图标包" sub:@"换悬浮球图标风格"
                         options:@[@"默认", @"极简", @"霓虹", @"自定义图片"]],
                [DYBItem action:@"选择自定义图标" sub:@"从文件里选一张 PNG，自动裁切填充" block:^{ [self pickIcon]; }],
                [DYBItem action:@"清除自定义图标" sub:@"" block:^{
                    [[DYBPrefs shared] setString:@"" for:DYBKey_customIconB64];
                    [DYBFloatBall applyPrefs];
                    [DYBHUD show:@"已清除"];
                }],
            ];
        }],
    ];

    NSMutableArray *hide = [NSMutableArray array];
    NSArray *rules = @[
        @[DYBKey_hideAd, @"广告 / 推广"],
        @[DYBKey_hideLive, @"直播入口 / 标记"],
        @[DYBKey_hideShop, @"商城 / 电商锚点"],
        @[DYBKey_hideSearchBtn, @"顶部搜索入口"],
        @[DYBKey_hideAntiAddict, @"防沉迷提示条"],
        @[DYBKey_hideDanmaku, @"弹幕"],
        @[DYBKey_hideAIBall, @"搜索 / 键盘 AI 浮钮"],
        @[DYBKey_hideStoryRing, @"头像故事圈"],
        @[DYBKey_hideCommentInput, @"评论输入框背景"],
        @[DYBKey_hideTyping, @"「正在输入」状态"],
        @[DYBKey_hideReadReceipt, @"已读回执"],
    ];
    for (NSArray *r in rules) {
        DYBItem *it = [DYBItem sw:r[0] title:r[1] sub:@""];
        it.experimental = [@[DYBKey_hideTyping, DYBKey_hideReadReceipt] containsObject:r[0]];
        [hide addObject:it];
    }
    [hide addObject:[DYBItem sw:DYBKey_cleanScreen title:@"清屏模式" sub:@"只保留播放器相关视图"]];

    NSMutableArray *data = [@[
        [DYBItem action:@"导出配置到剪贴板" sub:@"JSON，可直接发给别人" block:^{
            NSDictionary *snap = [p exportSnapshot];
            NSData *d = [NSJSONSerialization dataWithJSONObject:snap options:NSJSONWritingPrettyPrinted error:nil];
            UIPasteboard.generalPasteboard.string = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
            [DYBHUD show:@"配置已复制到剪贴板"];
        }],
        [DYBItem action:@"从剪贴板导入配置" sub:@"" block:^{
            NSString *s = UIPasteboard.generalPasteboard.string;
            NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *j = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
            if ([p importSnapshot:j]) [DYBHUD show:@"已导入"]; else [DYBHUD show:@"剪贴板里没有有效配置"];
        }],
        [DYBItem action:@"从文件导入配置" sub:@"选择 .json" block:^{ [self pickConfigFile]; }],
        [DYBItem action:@"重置全部设置" sub:@"" block:^{
            [DYBMenu sheet:@"确认重置？" message:@"所有开关恢复默认" actions:@[
                @{@"title": @"重置", @"style": @2, @"action": ^{ [[DYBPrefs shared] resetAll]; [DYBHUD show:@"已重置"]; }}]];
        }],
        [DYBItem page:@"诊断" sub:@"看抖音内部类有没有被解析到" children:^NSArray<DYBItem *> * {
            NSDictionary *d = [DYBBeauty diagnose];
            NSMutableArray *arr = [NSMutableArray array];
            NSArray *keys = [d.allKeys sortedArrayUsingSelector:@selector(compare:)];
            for (NSString *k in keys) {
                [arr addObject:[DYBItem action:k sub:d[k] block:^{ }]];
            }
            return arr;
        }],
        [DYBItem action:@"关于" sub:@"DYBoost 1.0 · 仅供个人学习与自用" block:^{
            [DYBHUD show:@"DYBoost 1.0.0 · seagull" duration:2.2];
        }],
    ] mutableCopy];

    // ---- AI ----
    NSMutableArray *aiTop = [NSMutableArray array];
    [aiTop addObject:[DYBItem sw:DYBKey_aiEnabled title:@"启用 AI" sub:@"关掉后悬浮球/长按菜单里不再出现 AI 入口"]];
    [aiTop addObject:[DYBItem sw:DYBKey_aiAutoCopy title:@"结果自动复制到剪贴板" sub:@""]];
    [aiTop addObject:[DYBItem page:@"接口设置" sub:@"OpenAI 兼容 /chat/completions" children:^NSArray<DYBItem *> * {
        DYBItem *tok = [DYBItem slider:DYBKey_aiMaxTokens title:@"最大 token" sub:@"" min:64 max:4096];
        tok.integerValue = YES;
        return @[
            [DYBItem text:DYBKey_aiBase title:@"接口地址" sub:@"例：https://api.openai.com/v1 、https://api.deepseek.com/v1"],
            [DYBItem text:DYBKey_aiPath title:@"路径" sub:@"默认 /chat/completions；地址里已带则忽略"],
            [DYBItem text:DYBKey_aiModel title:@"模型名" sub:@"gpt-4o-mini / deepseek-chat / qwen-plus ..."],
            [DYBItem secret:@"API Key" sub:@"存本机钥匙串，不会进配置备份" get:^NSString * { return [DYBAI apiKey]; }
                        set:^(NSString *v) { [DYBAI setApiKey:v]; }],
            [DYBItem slider:DYBKey_aiTemperature title:@"温度" sub:@"越高越发散" min:0 max:2],
            tok,
            [DYBItem action:@"测试连接" sub:@"发一条极短请求验证配置" block:^{ [DYBAI testConnection]; }],
        ];
    }]];
    [aiTop addObject:[DYBItem page:@"提示词" sub:@"占位符：{desc} {author} {comments} {comment} {text} {command} {context}"
                          children:^NSArray<DYBItem *> * {
        return @[
            [DYBItem longText:DYBKey_aiSystem title:@"System 提示词" sub:@"全局人设 / 输出风格"],
            [DYBItem longText:DYBKey_aiTplSummary title:@"视频总结模板" sub:@"{desc} {author} {comments}"],
            [DYBItem longText:DYBKey_aiTplComments title:@"评论总结模板" sub:@"{desc} {comments}"],
            [DYBItem longText:DYBKey_aiTplReply title:@"评论回复模板" sub:@"{comment} {desc}"],
            [DYBItem longText:DYBKey_aiTplTranslate title:@"翻译模板" sub:@"{text}"],
            [DYBItem longText:DYBKey_aiTplCustom title:@"自定义指令模板" sub:@"{command} {context}"],
            [DYBItem action:@"恢复默认提示词" sub:@"只重置提示词，不动接口配置" block:^{
                for (NSString *k in @[DYBKey_aiSystem, DYBKey_aiTplSummary, DYBKey_aiTplComments,
                                      DYBKey_aiTplReply, DYBKey_aiTplTranslate, DYBKey_aiTplCustom]) {
                    [[DYBPrefs shared] reset:k];
                }
                [DYBHUD show:@"已恢复默认提示词"];
            }],
        ];
    }]];
    [aiTop addObject:[DYBItem action:@"总结当前视频" sub:@"用当前作品文案生成要点" block:^{ [DYBAI run:DYBAIActionSummary]; }]];
    [aiTop addObject:[DYBItem action:@"总结评论区" sub:@"抓屏幕上可见的评论（最多 30 条）" block:^{ [DYBAI run:DYBAIActionComments]; }]];
    [aiTop addObject:[DYBItem action:@"写一条评论回复" sub:@"先让你挑一条评论，再生成回复" block:^{ [DYBAI run:DYBAIActionReply]; }]];
    [aiTop addObject:[DYBItem action:@"翻译当前文案" sub:@"中 → 英（模板里可改目标语言）" block:^{ [DYBAI run:DYBAIActionTranslate]; }]];
    [aiTop addObject:[DYBItem action:@"自定义指令" sub:@"自己写 prompt，附上下文" block:^{ [DYBAI runCustom:nil]; }]];

    // ---- 真机校准 ----
    [data addObjectsFromArray:@[
        [DYBItem action:@"导出校准报告（分享）" sub:@"抖音版本 + 顶层 VC 链 + 候选类名 + 规则命中" block:^{ [DYBDump shareReport]; }],
        [DYBItem action:@"导出全部类名（分享）" sub:@"文件较大，只在需要深度校准时导出" block:^{ [DYBDump shareFullClassList]; }],
        [DYBItem action:@"复制校准报告" sub:@"内容太长时改用分享" block:^{ [DYBDump copyReport]; }],
    ]];

    return @[
        [DYBSection section:@"功能增强" footer:@"所有功能都在本机执行，不会上传任何数据" items:enhance],
        [DYBSection section:@"界面美化" footer:@"美化只改渲染层，不写回抖音自己的设置" items:beauty],
        [DYBSection section:@"隐藏元素" footer:@"依赖类名解析，版本变动可能失效，看「诊断」" items:hide],
        [DYBSection section:@"AI 助手" footer:@"只会把当前作品文案 / 可见评论发到你自己在上面填的接口，除此之外不联网" items:aiTop],
        [DYBSection section:@"数据与诊断" footer:@"" items:data],
    ];
}

#pragma mark 文件选择

+ (void)pickIcon {
    [self pickJSON:NO];
}

+ (void)pickConfigFile {
    [self pickJSON:YES];
}

+ (void)pickJSON:(BOOL)isJSON {
    DYBAsyncMain(^{
        UINavigationController *nav = (UINavigationController *)gPanelWindow.rootViewController;
        if (!nav) return;
        DYBPanel *panelHost = nil;
        for (UIViewController *v in nav.viewControllers) {
            if ([v isKindOfClass:DYBPanel.class]) { panelHost = (DYBPanel *)v; break; }
        }
        UIViewController *host = panelHost ?: nav.visibleViewController;
        if (!host) return;
        NSArray *types = isJSON ? @[UTTypeJSON] : @[UTTypeImage, UTTypePNG, UTTypeJPEG];
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
        picker.delegate = (id<UIDocumentPickerDelegate>)panelHost;
        if (!panelHost) return;
        picker.allowsMultipleSelection = NO;
        [host presentViewController:picker animated:YES completion:nil];
    });
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *u = urls.firstObject;
    if (!u) return;
    BOOL isJSON = [u.pathExtension.lowercaseString isEqualToString:@"json"];
    if (isJSON) {
        NSData *d = [NSData dataWithContentsOfURL:u];
        NSDictionary *j = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        [[DYBPrefs shared] importSnapshot:j] ? [DYBHUD show:@"已导入"] : [DYBHUD show:@"文件格式不对"];
    } else {
        NSData *d = [NSData dataWithContentsOfURL:u];
        UIImage *img = [UIImage imageWithData:d];
        if (!img) { [DYBHUD show:@"图片读取失败"]; return; }
        CGFloat s = 128.0;
        UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(s, s)];
        UIImage *sq = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            UIBezierPath *bp = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, s, s)];
            [bp addClip];
            [img drawInRect:CGRectMake(0, 0, s, s)];
        }];
        NSData *png = UIImagePNGRepresentation(sq);
        [[DYBPrefs shared] setString:[png base64EncodedStringWithOptions:0] for:DYBKey_customIconB64];
        [[DYBPrefs shared] setInt:3 for:DYBKey_iconPack];
        [DYBFloatBall applyPrefs];
        [DYBHUD show:@"图标已更新"];
    }
}

#pragma mark UI

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [DYBTheme bg];
    self.navigationController.navigationBar.barStyle = [DYBTheme isDark] ? UIBarStyleBlack : UIBarStyleDefault;
    self.navigationController.navigationBar.tintColor = [DYBTheme tint];
    self.navigationController.navigationBar.prefersLargeTitles = NO;

    // 双击标题栏切换明暗
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
    t.text = self.title;
    t.textAlignment = NSTextAlignmentCenter;
    t.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    t.textColor = [DYBTheme textPrimary];
    t.userInteractionEnabled = YES;
    UITapGestureRecognizer *tg = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(titleDoubleTapped:)];
    tg.numberOfTapsRequired = 2;
    [t addGestureRecognizer:tg];
    self.navigationItem.titleView = t;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(close)];

    self.search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.search.placeholder = @"搜索功能";
    self.search.delegate = self;
    self.search.keyboardAppearance = [DYBTheme keyboard];
    self.search.barStyle = [DYBTheme isDark] ? UIBarStyleBlack : UIBarStyleDefault;

    self.table = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.tableHeaderView = self.search;
    self.table.backgroundColor = [DYBTheme bg];
    self.table.separatorColor = [DYBTheme separator];
    self.table.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:self.table];

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressed:)];
    [self.table addGestureRecognizer:lp];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:DYBPrefsChangedNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.view.backgroundColor = [DYBTheme bg];
    self.table.backgroundColor = [DYBTheme bg];
    [self.table reloadData];
}

- (void)close { [DYBPanel dismissPanel]; }

- (void)titleDoubleTapped:(UITapGestureRecognizer *)g {
    NSInteger cur = [[DYBPrefs shared] intFor:DYBKey_panelTheme default:0];
    NSInteger next = (cur == 1) ? 2 : 1;
    [[DYBPrefs shared] setInt:next for:DYBKey_panelTheme];
    [DYBHUD show:next == 2 ? @"固定深色" : @"固定浅色"];
}

- (void)reload { [self.table reloadData]; }

#pragma mark 搜索

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        NSMutableArray *f = [NSMutableArray array];
        for (DYBSection *s in self.sections) [f addObjectsFromArray:s.items];
        self.flat = f;
    } else {
        NSMutableArray *f = [NSMutableArray array];
        for (DYBSection *s in self.sections) {
            for (DYBItem *i in s.items) {
                if ([i.title rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [i.subtitle rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    [f addObject:i];
                }
            }
        }
        self.flat = f;
    }
    [self.table reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar { [searchBar resignFirstResponder]; }

#pragma mark 表格

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.flat.count ? 1 : self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.flat.count ? self.flat.count : self.sections[section].items.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.flat.count ? @"搜索结果" : self.sections[section].title;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.flat.count ? nil : self.sections[section].footer;
}

- (NSArray<DYBItem *> *)itemsInSection:(NSInteger)section {
    return self.flat.count ? self.flat : self.sections[section].items;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *ID = @"DYBCell";
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:ID];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ID];
    DYBItem *it = [self itemsInSection:indexPath.section][indexPath.row];
    c.textLabel.text = it.experimental ? [NSString stringWithFormat:@"%@（实验）", it.title] : it.title;
    c.textLabel.textColor = [DYBTheme textPrimary];
    c.detailTextLabel.text = it.subtitle.length ? it.subtitle : nil;
    c.detailTextLabel.textColor = [DYBTheme textSecondary];
    c.detailTextLabel.numberOfLines = 0;
    c.backgroundColor = [DYBTheme card];
    c.tintColor = [DYBTheme tint];
    c.selectionStyle = UITableViewCellSelectionStyleDefault;
    c.accessoryView = nil;
    c.accessoryType = UITableViewCellAccessoryNone;

    if (it.type == DYBItemTypeSwitch) {
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = [[DYBPrefs shared] boolFor:it.key default:NO];
        sw.onTintColor = [DYBTheme tint];
        sw.tag = indexPath.row;
        [sw addTarget:self action:@selector(switched:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw;
        c.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (it.type == DYBItemTypeChoose || it.type == DYBItemTypeColor || it.type == DYBItemTypeSlider
               || it.type == DYBItemTypeText || it.type == DYBItemTypeLongText || it.secretGet) {
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        UILabel *v = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 120, 24)];
        v.text = [it currentText];
        v.textAlignment = NSTextAlignmentRight;
        v.textColor = [DYBTheme textSecondary];
        v.font = [UIFont systemFontOfSize:13];
        c.accessoryView = v;
    } else if (it.type == DYBItemTypePage) {
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        c.accessoryType = UITableViewCellAccessoryNone;
    }
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    DYBItem *it = [self itemsInSection:indexPath.section][indexPath.row];
    DYBPrefs *p = DYBPrefs.shared;
    switch (it.type) {
        case DYBItemTypeSwitch: break;
        case DYBItemTypeChoose: {
            NSInteger cur = [p intFor:it.key default:0];
            [DYBMenu choose:it.title message:it.subtitle options:it.options current:cur done:^(NSInteger i) {
                [p setInt:i for:it.key];
                [self.table reloadData];
            }];
            break;
        }
        case DYBItemTypeSlider: {
            DYBSliderPage *sp = [DYBSliderPage new];
            sp.item = it;
            [self.navigationController pushViewController:sp animated:YES];
            break;
        }
        case DYBItemTypeColor: {
            if (@available(iOS 14.0, *)) {
                UIColorPickerViewController *cp = [[UIColorPickerViewController alloc] init];
                cp.delegate = self;
                cp.selectedColor = [UIColor dyb_colorWithHex:[p stringFor:it.key default:@"#FE2C55"]] ?: UIColor.redColor;
                cp.supportsAlpha = NO;
                self.pickingColorItem = it;
                [self presentViewController:cp animated:YES completion:nil];
            } else {
                [DYBMenu choose:it.title message:it.subtitle options:@[@"抖音红", @"白", @"黑", @"青", @"紫", @"橙"] current:0 done:^(NSInteger i) {
                    NSArray *hex = @[@"#FE2C55", @"#FFFFFF", @"#111111", @"#25F4EE", @"#8E44FF", @"#FF9500"];
                    [p setString:hex[i] for:it.key];
                    [self.table reloadData];
                }];
            }
            break;
        }
        case DYBItemTypeText: {
            [DYBMenu input:it.title message:it.subtitle text:[p stringFor:it.key default:@""] placeholder:@"" done:^(NSString *t) {
                [p setString:t for:it.key];
                [self.table reloadData];
            }];
            break;
        }
        case DYBItemTypeLongText: {
            DYBTextPage *tp = [[DYBTextPage alloc] initWithItem:it];
            [self.navigationController pushViewController:tp animated:YES];
            break;
        }
        case DYBItemTypePage: {
            NSArray<DYBItem *> *children = it.children ? it.children() : @[];
            DYBPanel *sub = [[DYBPanel alloc] initWithTitle:it.title
                                                   sections:@[[DYBSection section:@"" footer:it.subtitle items:children]]];
            [self.navigationController pushViewController:sub animated:YES];
            break;
        }
        case DYBItemTypeAction: {
            if (it.action) it.action();
            break;
        }
    }
}

- (void)switched:(UISwitch *)sw {
    NSIndexPath *ip = [self.table indexPathForCell:(UITableViewCell *)sw.superview];
    if (!ip) return;
    DYBItem *it = [self itemsInSection:ip.section][ip.row];
    [[DYBPrefs shared] setBool:sw.on for:it.key];
    DYBHaptic(UIImpactFeedbackStyleLight);
    if ([it.key isEqualToString:DYBKey_floatBall] || [it.key isEqualToString:DYBKey_floatBallSize]
        || [it.key isEqualToString:DYBKey_floatBallAlpha] || [it.key isEqualToString:DYBKey_iconPack]) {
        [DYBFloatBall applyPrefs];
    }
    if ([it.key isEqualToString:DYBKey_cleanScreen]) [DYBBeauty setCleanScreen:sw.on];
    if ([it.key hasPrefix:@"DYB.hide"]) [DYBBeauty refresh];
}

#pragma mark 长按重置

- (void)longPressed:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    CGPoint pt = [g locationInView:self.table];
    NSIndexPath *ip = [self.table indexPathForRowAtPoint:pt];
    if (!ip) return;
    DYBItem *it = [self itemsInSection:ip.section][ip.row];
    if (!it.key) return;
    [[DYBPrefs shared] reset:it.key];
    [DYBHUD show:[NSString stringWithFormat:@"%@ 已恢复默认", it.title]];
    [self.table reloadData];
}

#pragma mark 取色

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)vc {
    if (!self.pickingColorItem) return;
    NSString *hex = [vc.selectedColor dyb_hexString];
    [[DYBPrefs shared] setString:hex for:self.pickingColorItem.key];
    [self.table reloadData];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)vc {
    self.pickingColorItem = nil;
    [self.table reloadData];
}

@end
