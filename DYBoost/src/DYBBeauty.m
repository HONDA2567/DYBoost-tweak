//
//  DYBBeauty.m
//  DYBoost
//

#import "DYBBeauty.h"
#import "DYBPrefs.h"
#import "DYBKeys.h"
#import "DYBTheme.h"
#import "DYBHookKit.h"
#import <objc/runtime.h>

static NSInteger const kDYBVeilTag = 0xD1B0A5;
static char kDYBTabBarBackup;

@class DYBBeauty;
static void DYBSetOrig(NSString *rid, SEL sel, void *orig);
static void *DYBOrigFor(NSString *rid, SEL sel);

#pragma mark - 元素隐藏规则（候选类名，运行时按序解析）

static NSArray<NSDictionary *> *DYBHideRules(void) {
    return @[
        @{ @"id": DYBKey_hideAd,
           @"title": @"广告 / 推广",
           @"classes": @[@"AWEAdTagView", @"AWEAdDescTagView", @"AWEAdFeedTagListView", @"AWEAdFeedLearnMoreView", @"AWEAdButtonAmbienceView", @"AWEAdLinkSponsorshipView", @"AWEFeedDoubleColumnAdCell", @"AWEFeedGamePromotionContainerView"] },

        @{ @"id": DYBKey_hideLive,
           @"title": @"直播入口 / 直播标记",
           @"classes": @[@"AWEFeedLiveMarkView", @"AWEFeedLiveMarkHeadAnimatedView", @"AWEFeedLiveMarkHeadRedView", @"AWEFeedLiveMarkHeadGreyView", @"AWEFeedLiveMarkTitleView", @"AWEAwemeLiveTableViewCell", @"AWEAwemeLiveCollectionViewCell", @"AWEDCFeedLivePreviewCell"] },

        @{ @"id": DYBKey_hideShop,
           @"title": @"商城 / 电商锚点",
           @"classes": @[@"AWEAwemeGoodsTag", @"AWEConcernGoodsCard", @"AWEConcernGoodsCardPriceTagView", @"AWEAwemeDetailEcommerceKolVideoView", @"AWEAwemeDetailEcomKolVideoCollectionViewCell", @"AWEFeedConcernPOISinglePromotionGoodsContentView", @"AWEMerchandiseComponentTabBar"] },

        @{ @"id": DYBKey_hideSearchBtn,
           @"title": @"顶部搜索入口",
           @"classes": @[@"AWEDCFeedSearchBarView", @"AWEDetailFeedSearchContainer", @"AWECommonSearchBar", @"AWECustomSearchBar", @"AWEJXPadSearchEntranceView", @"AWEIMMessageTabNaviBarSearchEntryView", @"AWELeftSideBarAISearchContainerView"] },

        @{ @"id": DYBKey_hideAntiAddict,
           @"title": @"防沉迷 / 时间提示条",
           @"classes": @[@"AWEFeedAntiAddictMaskView", @"AWEFeedAntiAddictClearView", @"AWEAntiAddictedNoticeBarView", @"AWEAntiAddictDailyAlertView", @"AWEAntiAddictDailyAlertBubbleView", @"AWEAntiAddictMaskBlockInteractionView", @"AWEAntiAddictPreviewControlView", @"IESLiveFeedAntiAddictClearView"] },

        @{ @"id": DYBKey_hideDanmaku,
           @"title": @"弹幕",
           @"classes": @[@"AWEAwemeBarrageAwemeView", @"AWEAwemeBarrageBaseView", @"AWEAwemeBarrageCommentView", @"AWEAwemeBarrageCollectView", @"AWEAwemeBarrageDiggView", @"AWEAwemeBarrageIconView", @"AWEAwemeBarrageViewerView", @"AWEBarrageContainerView"] },

        @{ @"id": DYBKey_hideAIBall,
           @"title": @"搜索 / 键盘 AI 浮钮",
           @"classes": @[@"AWEGeneralSearchAIBallButton", @"AWEGeneralSearchAIModeButton", @"AWEKMPAiAssistantTipsView", @"AWEKMPAiAssistantAnimateView", @"AWEKMPAiAssistantPromptLayer", @"AWEKMPAiAssistantComposeLayer", @"AWELeftSideBarAISearchContainerView"] },

        @{ @"id": DYBKey_hideStoryRing,
           @"title": @"头像故事圈",
           @"classes": @[@"AWEUserAvatarRingAvatarView", @"AFDStoryGradientRingView", @"AFDColorRingView", @"AWEIMChatCellStoryCoverView", @"AWEIMFriendTabChatCellStoryCoverComponent", @"AWEStoryProgressContainerView", @"AWEStoryProgressCell"] },

        @{ @"id": DYBKey_hideCommentInput,
           @"title": @"评论输入框背景",
           @"classes": @[@"AWECommentInputBackgroundView", @"AWECommentInputLynxView", @"AWECommentInputLynxBackgroundView", @"AWECommentInputFastEmojiBar", @"AWECommentAudioInputView", @"AWECommentListInputSelectGroupView", @"AFDFastReplyInputViewContainer"] },

        @{ @"id": DYBKey_hideTyping,
           @"title": @"「正在输入」状态",
           @"classes": @[@"_TtC7ChatBuy15TypingIndicator", @"_TtC7FlowIMX12TypingCursor", @"_TtC7FlowIMX13TypingContent"],
           @"experimental": @YES },

        @{ @"id": DYBKey_hideReadReceipt,
           @"title": @"已读回执",
           @"classes": @[@"AWEIMMessageReadIndexComponent", @"IESIMConversationReadReceipt"],
           @"experimental": @YES },
    ];
}

#pragma mark - 进度条候选类

static NSArray<NSString *> *DYBProgressClasses(void) {
    return @[
             @"AWEDPlayerProgressView", 
             @"AWEDPlayerProgressContainer", 
             @"AWEDPlayerProgressContainerView", 
             @"AWEDPlayerPlayProgressContainer", 
             @"AWEDPlayerProgressPreviewView", 
             @"AWEDProgressFeedContainer", 
             @"AWEDProgressPlayBackAdsorbContainer", 
             @"AWEDProgressLongVideoContainer"];
}

#pragma mark - 实现

@implementation DYBBeauty {
    NSHashTable<UIView *> *_cleanHidden;
}

+ (instancetype)shared { static DYBBeauty *b; static dispatch_once_t t; dispatch_once(&t, ^{ b = [DYBBeauty new]; }); return b; }

+ (NSHashTable<UIView *> *)cleanHidden {
    DYBBeauty *s = self.shared;
    if (!s->_cleanHidden) s->_cleanHidden = [NSHashTable weakObjectsHashTable];
    return s->_cleanHidden;
}

#pragma mark 安装

static void (*origTabBarDMW)(UIView *, SEL);
static void (*origTabBarLayout)(UIView *, SEL);
static void (*origNavBarDMW)(UIView *, SEL);

+ (void)install {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 底栏
        DYBHookBlock(UITabBar.class, @selector(didMoveToWindow),
                     ^(UIView *self_, SEL _cmd) {
                         if (origTabBarDMW) origTabBarDMW(self_, _cmd);
                         [DYBBeauty applyTabBar:(UITabBar *)self_];
                     }, (void **)&origTabBarDMW);
        DYBHookBlock(UITabBar.class, @selector(layoutSubviews),
                     ^(UIView *self_, SEL _cmd) {
                         if (origTabBarLayout) origTabBarLayout(self_, _cmd);
                         [DYBBeauty applyTabBar:(UITabBar *)self_];
                     }, (void **)&origTabBarLayout);

        // 顶栏
        DYBHookBlock(UINavigationBar.class, @selector(didMoveToWindow),
                     ^(UIView *self_, SEL _cmd) {
                         if (origNavBarDMW) origNavBarDMW(self_, _cmd);
                         [DYBBeauty applyNavBar:(UINavigationBar *)self_];
                     }, (void **)&origNavBarDMW);

        // 进度条
        for (NSString *cn in DYBProgressClasses()) {
            Class c = NSClassFromString(cn);
            if (!c || ![c instancesRespondToSelector:@selector(layoutSubviews)]) continue;
            void *orig = NULL;
            BOOL ok = DYBHookBlock(c, @selector(layoutSubviews), ^(UIView *self_, SEL _cmd) {
                void (*o)(id, SEL) = (void (*)(id, SEL))DYBOrigFor(cn, _cmd);
                if (o) o(self_, _cmd);
                [DYBBeauty applyProgress:self_];
            }, &orig);
            if (ok) DYBSetOrig(cn, @selector(layoutSubviews), orig);
        }

        // 元素隐藏
        for (NSDictionary *rule in DYBHideRules()) {
            Class c = DYBFirstClass(rule[@"classes"]);
            if (!c) continue;
            if (![c isSubclassOfClass:UIView.class] && ![c isSubclassOfClass:UIViewController.class]) continue;
            NSString *rid = rule[@"id"];
            SEL sels[3] = { @selector(didMoveToWindow), @selector(layoutSubviews), @selector(didMoveToSuperview) };
            for (int i = 0; i < 3; i++) {
                if (![c instancesRespondToSelector:sels[i]]) continue;
                void *orig = NULL;
                DYBHookBlock(c, sels[i], ^(id self_, SEL _cmd) {
                    void (*o)(id, SEL) = (void (*)(id, SEL))DYBOrigFor(rid, _cmd);
                    if (o) o(self_, _cmd);
                    [DYBBeauty applyHideRule:rid toObject:self_];
                }, &orig);
                DYBSetOrig(rid, sels[i], orig);
                break;
            }
        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(dybPrefsChanged:)
                                                     name:DYBPrefsChangedNotification
                                                   object:nil];
    });
}

#pragma mark 隐藏规则里的 orig 保存（每个规则一个）
static NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSValue *> *> *gOrigMap;
static void DYBSetOrig(NSString *rid, SEL sel, void *orig) {
    static dispatch_once_t t; dispatch_once(&t, ^{ gOrigMap = [NSMutableDictionary dictionary]; });
    if (!orig) return;
    gOrigMap[rid] = gOrigMap[rid] ?: [NSMutableDictionary dictionary];
    gOrigMap[rid][NSStringFromSelector(sel)] = [NSValue valueWithPointer:orig];
}
static void *DYBOrigFor(NSString *rid, SEL sel) {
    return [gOrigMap[rid][NSStringFromSelector(sel)] pointerValue];
}

+ (void)dybPrefsChanged:(NSNotification *)n {
    DYBAsyncMainAfter(0.05, ^{ [self refreshNow]; });
}

#pragma mark 应用：底栏

+ (void)applyTabBar:(UITabBar *)tb {
    if (!tb) return;
    DYBPrefs *p = DYBPrefs.shared;
    BOOL on = [p boolFor:DYBKey_beautyMaster default:YES] && [p boolFor:DYBKey_glassTabBar default:YES];
    UIView *veil = [tb viewWithTag:kDYBVeilTag];

    if (!on) {
        if (veil) {
            NSDictionary *bak = objc_getAssociatedObject(tb, &kDYBTabBarBackup);
            tb.backgroundImage = bak[@"bg"];
            tb.shadowImage = bak[@"shadow"];
            tb.backgroundColor = bak[@"color"];
            tb.tintColor = bak[@"tint"];
            [veil removeFromSuperview];
        }
        [self setTabBarLabelsHidden:NO in:tb];
        return;
    }

    if (!veil) {
        NSMutableDictionary *bak = [NSMutableDictionary dictionary];
        if (tb.backgroundImage) bak[@"bg"] = tb.backgroundImage;
        if (tb.shadowImage) bak[@"shadow"] = tb.shadowImage;
        if (tb.backgroundColor) bak[@"color"] = tb.backgroundColor;
        if (tb.tintColor) bak[@"tint"] = tb.tintColor;
        objc_setAssociatedObject(tb, &kDYBTabBarBackup, bak, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        [veil removeFromSuperview];
    }

    UIVisualEffectView *v = [[UIVisualEffectView alloc] initWithEffect:[DYBTheme glassEffect]];
    v.tag = kDYBVeilTag;
    v.frame = tb.bounds;
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    v.userInteractionEnabled = NO;
    [tb insertSubview:v atIndex:0];
    [tb sendSubviewToBack:v];

    tb.backgroundImage = [UIImage new];
    tb.shadowImage = [UIImage new];
    tb.backgroundColor = UIColor.clearColor;
    tb.translucent = YES;
    if ([p boolFor:DYBKey_tintEnabled default:NO]) tb.tintColor = [DYBTheme tint];

    CGFloat corner = MAX(0, [p floatFor:DYBKey_tabBarCorner default:0.35]);
    if (corner > 0) {
        CGFloat r = MIN(tb.bounds.size.height, 44.0) * corner;
        v.layer.cornerRadius = r;
        v.layer.cornerCurve = kCACornerCurveContinuous;
        v.clipsToBounds = YES;
        v.layer.borderWidth = 0.5;
        v.layer.borderColor = [DYBTheme separator].CGColor;
    }
    [self setTabBarLabelsHidden:[p boolFor:DYBKey_hideTabLabels default:NO] in:tb];
}

+ (void)setTabBarLabelsHidden:(BOOL)hidden in:(UITabBar *)tb {
    for (UIView *sub in tb.subviews) {
        if (![NSStringFromClass(sub.class) containsString:@"UITabBarButton"]) continue;
        for (UIView *v in sub.subviews) {
            if ([v isKindOfClass:UILabel.class]) v.hidden = hidden;
        }
    }
}

#pragma mark 应用：顶栏

+ (void)applyNavBar:(UINavigationBar *)bar {
    if (!bar) return;
    DYBPrefs *p = DYBPrefs.shared;
    BOOL on = [p boolFor:DYBKey_beautyMaster default:YES] && [p boolFor:DYBKey_glassNavBar default:NO];
    if (!on) return;
    bar.translucent = YES;
    bar.shadowImage = [UIImage new];
    bar.backgroundColor = UIColor.clearColor;
    bar.barTintColor = nil;
    if ([p boolFor:DYBKey_tintEnabled default:NO]) bar.tintColor = [DYBTheme tint];
    if (![bar viewWithTag:kDYBVeilTag]) {
        UIVisualEffectView *v = [[UIVisualEffectView alloc] initWithEffect:[DYBTheme glassEffect]];
        v.tag = kDYBVeilTag;
        v.frame = bar.bounds;
        v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        v.userInteractionEnabled = NO;
        [bar insertSubview:v atIndex:0];
    }
}

#pragma mark 应用：进度条

+ (void)applyProgress:(UIView *)v {
    if (!v) return;
    DYBPrefs *p = DYBPrefs.shared;
    if (![p boolFor:DYBKey_beautyMaster default:YES]) return;
    NSInteger style = [p intFor:DYBKey_progressStyle default:0];
    CGFloat h = [p floatFor:DYBKey_progressHeight default:0.0];
    UIColor *color = [UIColor dyb_colorWithHex:[p stringFor:DYBKey_progressHex default:@"#FFFFFF"]] ?: UIColor.whiteColor;

    if ([v respondsToSelector:@selector(setMinimumTrackTintColor:)]) {
        UISlider *s = (UISlider *)v;
        switch (style) {
            case 1: s.minimumTrackTintColor = color; s.maximumTrackTintColor = [color colorWithAlphaComponent:0.25]; break;
            case 2: s.minimumTrackTintColor = [DYBTheme tint]; s.maximumTrackTintColor = [color colorWithAlphaComponent:0.20]; break;
            case 3: s.minimumTrackTintColor = [DYBTheme tint]; s.maximumTrackTintColor = [color colorWithAlphaComponent:0.15]; break;
            default: break;
        }
        if (h > 0) {
            CGRect f = s.frame;
            if (fabs(f.size.height - h) > 0.5 && f.size.height > 0) {
                f.origin.y += (f.size.height - h) / 2.0;
                f.size.height = h;
                s.frame = f;
            }
        }
    }
    if (style != 0 || h > 0) {
        v.layer.cornerRadius = (h > 0 ? h : v.bounds.size.height) / 2.0;
        v.clipsToBounds = YES;
    }
}

#pragma mark 应用：隐藏规则

+ (void)applyHideRule:(NSString *)ruleID toObject:(id)obj {
    if (!obj || ruleID.length == 0) return;
    DYBPrefs *p = DYBPrefs.shared;
    if (![p boolFor:ruleID default:NO]) return;
    if ([obj isKindOfClass:UIView.class]) {
        ((UIView *)obj).hidden = YES;
    } else if ([obj isKindOfClass:UIViewController.class]) {
        ((UIViewController *)obj).view.hidden = YES;
    }
}

#pragma mark 清屏

+ (BOOL)isCleanScreen { return [[DYBPrefs shared] boolFor:DYBKey_cleanScreen default:NO]; }

+ (void)setCleanScreen:(BOOL)on {
    [[DYBPrefs shared] setBool:on for:DYBKey_cleanScreen];
    [self refresh];
}

+ (void)applyCleanScreenIn:(UIView *)root {
    BOOL on = [self isCleanScreen];
    NSHashTable *table = [self cleanHidden];
    if (!on) {
        for (UIView *v in table) v.hidden = NO;
        [table removeAllObjects];
        return;
    }
    NSArray *keep = @[@"player", @"video", @"av", @"layer", @"scroll", @"progress", @"gradient", @"container", @"dyb"];
    DYBWalkViews(root, ^(UIView *v, BOOL *stop) {
        NSString *cn = NSStringFromClass(v.class).lowercaseString;
        BOOL keepIt = NO;
        for (NSString *k in keep) if ([cn containsString:k]) { keepIt = YES; break; }
        if (!keepIt && v.bounds.size.width < root.bounds.size.width * 0.98) {
            v.hidden = YES;
            [table addObject:v];
        }
    });
}

#pragma mark refresh / diagnose

static CFTimeInterval gLastRefresh;

/// 页面切换会频繁调用，做个节流
+ (void)refresh {
    CFTimeInterval now = CACurrentMediaTime();
    if (now - gLastRefresh < 0.8) return;
    [self refreshNow];
}

+ (void)refreshNow {
    gLastRefresh = CACurrentMediaTime();
    UIWindow *w = DYBKeyWindow();
    if (!w) return;
    DYBWalkViews(w, ^(UIView *v, BOOL *stop) {
        if ([v isKindOfClass:UITabBar.class]) [self applyTabBar:(UITabBar *)v];
        if ([v isKindOfClass:UINavigationBar.class]) [self applyNavBar:(UINavigationBar *)v];
    });
    for (NSDictionary *rule in DYBHideRules()) {
        Class c = DYBFirstClass(rule[@"classes"]);
        if (!c) continue;
        if ([c isSubclassOfClass:UIViewController.class]) continue;
        DYBWalkViews(w, ^(UIView *v, BOOL *stop) {
            if ([v isKindOfClass:c]) [self applyHideRule:rule[@"id"] toObject:v];
        });
    }
    [self applyCleanScreenIn:w];
}

+ (NSDictionary<NSString *, NSString *> *)diagnose {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (NSDictionary *rule in DYBHideRules()) {
        NSString *hit = @"未命中";
        for (NSString *cn in rule[@"classes"]) {
            if (NSClassFromString(cn)) { hit = cn; break; }
        }
        out[rule[@"title"]] = hit;
    }
    NSString *prog = @"未命中";
    for (NSString *cn in DYBProgressClasses()) if (NSClassFromString(cn)) { prog = cn; break; }
    out[@"进度条"] = prog;
    return out;
}

@end
