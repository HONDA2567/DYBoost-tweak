//
//  DYBPrefs.m
//  DYBoost
//

#import "DYBPrefs.h"
#import "DYBKeys.h"
#import <CoreFoundation/CoreFoundation.h>

#define DYB_K_DEF(name) NSString * const DYBKey_##name = @"DYB." #name;

DYB_K_DEF(beautyMaster)
DYB_K_DEF(enhanceMaster)
DYB_K_DEF(glassTabBar)
DYB_K_DEF(tabBarCorner)
DYB_K_DEF(hideTabLabels)
DYB_K_DEF(glassNavBar)
DYB_K_DEF(tintEnabled)
DYB_K_DEF(tintHex)
DYB_K_DEF(nativeGlass)
DYB_K_DEF(progressStyle)
DYB_K_DEF(progressHeight)
DYB_K_DEF(progressHex)
DYB_K_DEF(panelTheme)
DYB_K_DEF(panelCorner)
DYB_K_DEF(floatBall)
DYB_K_DEF(floatBallSize)
DYB_K_DEF(floatBallAlpha)
DYB_K_DEF(floatBallAutoHide)
DYB_K_DEF(floatBallPosX)
DYB_K_DEF(floatBallPosY)
DYB_K_DEF(iconPack)
DYB_K_DEF(customIconB64)
DYB_K_DEF(wallpaperB64)
DYB_K_DEF(hideAd)
DYB_K_DEF(hideLive)
DYB_K_DEF(hideShop)
DYB_K_DEF(hideSearchBtn)
DYB_K_DEF(hideAntiAddict)
DYB_K_DEF(hideDanmaku)
DYB_K_DEF(hideAIBall)
DYB_K_DEF(hideStoryRing)
DYB_K_DEF(hideCommentInput)
DYB_K_DEF(hideTyping)
DYB_K_DEF(hideReadReceipt)
DYB_K_DEF(cleanScreen)
DYB_K_DEF(noWatermark)
DYB_K_DEF(copyLink)
DYB_K_DEF(saveAudio)
DYB_K_DEF(saveCover)
DYB_K_DEF(saveAlbum)
DYB_K_DEF(defaultSpeed)
DYB_K_DEF(longPressSpeed)
DYB_K_DEF(tapSeek)
DYB_K_DEF(swipeMode)
DYB_K_DEF(doubleTapAction)
DYB_K_DEF(longPressMenu)
DYB_K_DEF(replaceLongPress)
DYB_K_DEF(haptic)
DYB_K_DEF(showFPS)
DYB_K_DEF(fpsPosX)
DYB_K_DEF(fpsPosY)
DYB_K_DEF(showStats)
DYB_K_DEF(showLiveDuration)
DYB_K_DEF(hiddenFriends)
DYB_K_DEF(licenseNote)

DYB_K_DEF(aiEnabled)
DYB_K_DEF(aiBase)
DYB_K_DEF(aiPath)
DYB_K_DEF(aiModel)
DYB_K_DEF(aiTemperature)
DYB_K_DEF(aiMaxTokens)
DYB_K_DEF(aiSystem)
DYB_K_DEF(aiTplSummary)
DYB_K_DEF(aiTplComments)
DYB_K_DEF(aiTplReply)
DYB_K_DEF(aiTplTranslate)
DYB_K_DEF(aiTplCustom)
DYB_K_DEF(aiAutoCopy)

NSString * const DYBPrefsChangedNotification = @"com.seagull.dyboost.prefs.changed";

static NSString * const DYBSuite = @"com.seagull.dyboost";

static NSDictionary<NSString *, id> * DYBDefaultTable(void) {
    static NSDictionary *t;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        t = @{
            DYBKey_beautyMaster     : @YES,
            DYBKey_enhanceMaster    : @YES,

            DYBKey_glassTabBar      : @YES,
            DYBKey_tabBarCorner     : @0.35,
            DYBKey_hideTabLabels    : @NO,
            DYBKey_glassNavBar      : @NO,
            DYBKey_tintEnabled      : @NO,
            DYBKey_tintHex          : @"#FE2C55",
            DYBKey_nativeGlass      : @YES,
            DYBKey_progressStyle    : @0,
            DYBKey_progressHeight   : @0.0,   // 0 = 跟随原生
            DYBKey_progressHex      : @"#FFFFFF",

            DYBKey_panelTheme       : @0,
            DYBKey_panelCorner      : @16.0,
            DYBKey_floatBall        : @YES,
            DYBKey_floatBallSize    : @54.0,
            DYBKey_floatBallAlpha   : @0.85,
            DYBKey_floatBallAutoHide: @YES,
            DYBKey_floatBallPosX    : @0.92,
            DYBKey_floatBallPosY    : @0.62,

            DYBKey_iconPack         : @0,
            DYBKey_customIconB64    : @"",
            DYBKey_wallpaperB64     : @"",

            DYBKey_hideAd           : @NO,
            DYBKey_hideLive         : @NO,
            DYBKey_hideShop         : @NO,
            DYBKey_hideSearchBtn    : @NO,
            DYBKey_hideAntiAddict   : @YES,
            DYBKey_hideDanmaku      : @NO,
            DYBKey_hideAIBall       : @NO,
            DYBKey_hideStoryRing    : @NO,
            DYBKey_hideCommentInput : @NO,
            DYBKey_hideTyping       : @NO,
            DYBKey_hideReadReceipt  : @NO,
            DYBKey_cleanScreen      : @NO,

            DYBKey_noWatermark      : @YES,
            DYBKey_copyLink         : @YES,
            DYBKey_saveAudio        : @YES,
            DYBKey_saveCover        : @YES,
            DYBKey_saveAlbum        : @YES,

            DYBKey_defaultSpeed     : @1.0,
            DYBKey_longPressSpeed   : @2.0,
            DYBKey_tapSeek          : @YES,
            DYBKey_swipeMode        : @0,
            DYBKey_doubleTapAction  : @0,
            DYBKey_longPressMenu    : @YES,
            DYBKey_replaceLongPress : @NO,
            DYBKey_haptic           : @YES,

            DYBKey_showFPS          : @NO,
            DYBKey_fpsPosX          : @0.06,
            DYBKey_fpsPosY          : @0.02,
            DYBKey_showStats        : @NO,
            DYBKey_showLiveDuration : @NO,

            DYBKey_hiddenFriends    : @[],
            DYBKey_licenseNote      : @"仅供个人学习与自用",

            DYBKey_aiEnabled        : @NO,
            DYBKey_aiBase           : @"https://api.openai.com/v1",
            DYBKey_aiPath           : @"/chat/completions",
            DYBKey_aiModel          : @"gpt-4o-mini",
            DYBKey_aiTemperature    : @0.7,
            DYBKey_aiMaxTokens      : @800,
            DYBKey_aiSystem         : @"你是抖音内容助手。回答用中文，简洁口语化，不要客套，不要使用 Markdown 标题。",
            DYBKey_aiTplSummary     : @"用 3 条要点总结这条视频讲了什么，每条不超过 20 字。\n\n作者：{author}\n文案：{desc}",
            DYBKey_aiTplComments    : @"总结下面这些评论的主要观点和整体情绪，100 字以内，直接给结论。\n\n视频文案：{desc}\n评论：\n{comments}",
            DYBKey_aiTplReply       : @"针对这条评论，写一条自然、简短、像真人说的回复，不要引号不要解释。\n\n视频文案：{desc}\n评论：{comment}",
            DYBKey_aiTplTranslate   : @"把下面的内容翻译成英文，只输出译文，不要解释。\n\n{text}",
            DYBKey_aiTplCustom      : @"{command}\n\n下面是上下文（可能为空）：\n{context}",
            DYBKey_aiAutoCopy       : @NO,
        };
    });
    return t;
}

@implementation DYBPrefs {
    NSUserDefaults *_store;
}

+ (instancetype)shared {
    static DYBPrefs *p;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ p = [[DYBPrefs alloc] init]; });
    return p;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *suite = [[NSUserDefaults alloc] initWithSuiteName:DYBSuite];
        _store = suite ?: [NSUserDefaults standardUserDefaults];
        [_store registerDefaults:DYBDefaultTable()];
        [self observeExternalChanges];
    }
    return self;
}

/// 设置 App（PreferenceBundle）在别的进程改了配置：收 Darwin 通知，重新读一遍再刷 UI
static void DYBDarwinPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name,
                                  const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[DYBPrefs shared] reload];
        [[NSNotificationCenter defaultCenter] postNotificationName:DYBPrefsChangedNotification object:@"*"];
    });
}

- (void)observeExternalChanges {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    (__bridge const void *)(self),
                                    DYBDarwinPrefsChanged,
                                    CFSTR("com.seagull.dyboost.prefs"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}

- (void)reload {
    NSUserDefaults *suite = [[NSUserDefaults alloc] initWithSuiteName:DYBSuite];
    if (suite) {
        [suite registerDefaults:DYBDefaultTable()];
        _store = suite;
    }
}

static void DYBPost(NSString *key) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DYBPrefsChangedNotification object:key];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFSTR("com.seagull.dyboost.prefs"), NULL, NULL, YES);
    });
}

- (id)_valueFor:(NSString *)key {
    id v = [_store objectForKey:key];
    if (v == nil) v = DYBDefaultTable()[key];
    return v;
}

- (BOOL)boolFor:(NSString *)key default:(BOOL)def {
    id v = [self _valueFor:key];
    return [v respondsToSelector:@selector(boolValue)] ? [v boolValue] : def;
}

- (void)setBool:(BOOL)v for:(NSString *)key {
    [_store setBool:v forKey:key];
    [_store synchronize];
    DYBPost(key);
}

- (double)floatFor:(NSString *)key default:(double)def {
    id v = [self _valueFor:key];
    return [v respondsToSelector:@selector(doubleValue)] ? [v doubleValue] : def;
}

- (void)setFloat:(double)v for:(NSString *)key {
    [_store setDouble:v forKey:key];
    [_store synchronize];
    DYBPost(key);
}

- (NSInteger)intFor:(NSString *)key default:(NSInteger)def {
    id v = [self _valueFor:key];
    return [v respondsToSelector:@selector(integerValue)] ? [v integerValue] : def;
}

- (void)setInt:(NSInteger)v for:(NSString *)key {
    [_store setInteger:v forKey:key];
    [_store synchronize];
    DYBPost(key);
}

- (NSString *)stringFor:(NSString *)key default:(NSString *)def {
    id v = [self _valueFor:key];
    return [v isKindOfClass:NSString.class] ? v : def;
}

- (void)setString:(NSString *)v for:(NSString *)key {
    [_store setObject:v ?: @"" forKey:key];
    [_store synchronize];
    DYBPost(key);
}

- (NSArray *)arrayFor:(NSString *)key {
    id v = [self _valueFor:key];
    return [v isKindOfClass:NSArray.class] ? v : @[];
}

- (void)setArray:(NSArray *)v for:(NSString *)key {
    [_store setObject:v ?: @[] forKey:key];
    [_store synchronize];
    DYBPost(key);
}

- (void)reset:(NSString *)key {
    id def = DYBDefaultTable()[key];
    if (def) { [_store setObject:def forKey:key]; } else { [_store removeObjectForKey:key]; }
    [_store synchronize];
    DYBPost(key);
}

- (void)resetAll {
    for (NSString *k in DYBDefaultTable()) { [_store removeObjectForKey:k]; }
    [_store synchronize];
    DYBPost(@"*");
}

- (NSDictionary *)exportSnapshot {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (NSString *k in DYBDefaultTable()) {
        id v = [_store objectForKey:k];
        if (v && [NSJSONSerialization isValidJSONObject:@[v]]) out[k] = v;
    }
    return @{ @"format": @"DYBoost.prefs.v1",
              @"date": @((long long)[[NSDate date] timeIntervalSince1970]),
              @"values": out };
}

- (BOOL)importSnapshot:(NSDictionary *)snap {
    if (![snap isKindOfClass:NSDictionary.class]) return NO;
    NSDictionary *values = snap[@"values"];
    if ([values isKindOfClass:NSDictionary.class]) {
        [values enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
            if (![key isKindOfClass:NSString.class]) return;
            if (![key hasPrefix:@"DYB."]) return;
            [self->_store setObject:obj forKey:key];
        }];
    } else if ([[snap allKeys] count] && [snap allKeys][0] && [[snap allKeys][0] hasPrefix:@"DYB."]) {
        [snap enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
            [self->_store setObject:obj forKey:key];
        }];
    } else {
        return NO;
    }
    [_store synchronize];
    DYBPost(@"*");
    return YES;
}

- (BOOL)isDark {
    NSInteger mode = [self intFor:DYBKey_panelTheme default:0];
    if (mode == 1) return NO;
    if (mode == 2) return YES;
    if (@available(iOS 13.0, *)) {
        UITraitCollection *tc = [UITraitCollection currentTraitCollection];
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

@end
