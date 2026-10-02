//
//  DYBAI.m
//  DYBoost
//
//  实现要点：
//   - 只发到你自己在面板里填的那个接口（OpenAI 兼容 /chat/completions）
//   - API Key 存钥匙串；钥匙串不可用时退化到 NSUserDefaults
//   - 上下文（文案/作者/评论）全部在本机抓：评论走视图层级扫描，不碰抖音私有 API
//

#import "DYBAI.h"
#import "DYBPrefs.h"
#import "DYBKeys.h"
#import "DYBHUD.h"
#import "DYBMenu.h"
#import "DYBAweme.h"
#import "DYBHookKit.h"
#import <UIKit/UIKit.h>
#import <Security/Security.h>

@interface DYBAIResultVC : UIViewController
@property (nonatomic, copy)   NSString *resultText;
@property (nonatomic, strong) UITextView *tv;
@property (nonatomic, copy)   NSArray<NSDictionary<NSString *, NSString *> *> *messages;
+ (void)show:(NSString *)title text:(NSString *)text messages:(NSArray<NSDictionary<NSString *, NSString *> *> *)messages;
@end

@interface DYBAI (Private)
+ (void)run:(DYBAIAction)action extra:(NSString *)extra;
+ (BOOL)plausibleComment:(NSString *)s;
+ (void)ask:(NSArray<NSDictionary<NSString *, NSString *> *> *)messages title:(NSString *)title;
@end

#pragma mark - 钥匙串

static NSString * const kDYBAIService = @"com.seagull.dyboost.ai";
static NSString * const kDYBAIAccount = @"apikey";
static NSString * const kDYBAIFallback = @"DYB.ai.key.fallback";

static NSDictionary *DYBAIBaseQuery(void) {
    return @{
        (__bridge id)kSecClass       : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService : kDYBAIService,
        (__bridge id)kSecAttrAccount : kDYBAIAccount,
    };
}

#pragma mark - 工具

static NSDictionary<NSString *, NSString *> *DYBMsg(NSString *role, NSString *content) {
    return @{ @"role": role ?: @"user", @"content": content ?: @"" };
}

static NSError *DYBAIErr(NSString *msg) {
    return [NSError errorWithDomain:@"DYBAI" code:-1 userInfo:@{ NSLocalizedDescriptionKey: msg ?: @"未知错误" }];
}

static NSString *DYBTemplate(NSString *key, NSString *fallback) {
    NSString *s = [[DYBPrefs shared] stringFor:key default:@""];
    return s.length ? s : fallback;
}

static NSString *DYBFill(NSString *tpl, NSDictionary<NSString *, NSString *> *vars) {
    NSString *out = tpl ?: @"";
    for (NSString *k in vars) {
        NSString *ph = [NSString stringWithFormat:@"{%@}", k];
        out = [out stringByReplacingOccurrencesOfString:ph withString:vars[k] ?: @""];
    }
    return out;
}

@implementation DYBAI

#pragma mark 配置

+ (BOOL)enabled {
    return [[DYBPrefs shared] boolFor:DYBKey_aiEnabled default:NO];
}

+ (NSString *)apiKey {
    CFTypeRef ref = NULL;
    NSDictionary *q = DYBAIBaseQuery();
    NSMutableDictionary *qq = q.mutableCopy;
    qq[(__bridge id)kSecReturnData]   = (__bridge id)kCFBooleanTrue;
    qq[(__bridge id)kSecMatchLimit]   = (__bridge id)kSecMatchLimitOne;
    OSStatus st = SecItemCopyMatching((__bridge CFDictionaryRef)qq, &ref);
    if (st == errSecSuccess && ref) {
        NSData *d = (__bridge_transfer NSData *)ref;
        NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
        if (s.length) return s;
    }
    if (ref) CFRelease(ref);
    return [[DYBPrefs shared] stringFor:kDYBAIFallback default:@""];
}

+ (void)setApiKey:(NSString *)key {
    NSString *k = key ?: @"";
    NSData *d = [k dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *q = DYBAIBaseQuery();
    NSMutableDictionary *qq = q.mutableCopy;
    qq[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    qq[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef ref = NULL;
    BOOL exists = (SecItemCopyMatching((__bridge CFDictionaryRef)qq, &ref) == errSecSuccess);
    if (ref) CFRelease(ref);

    OSStatus st = errSecSuccess;
    if (exists) {
        st = SecItemUpdate((__bridge CFDictionaryRef)q,
                           (__bridge CFDictionaryRef)@{(__bridge id)kSecValueData: d ?: [NSData data]});
    } else {
        NSMutableDictionary *add = q.mutableCopy;
        add[(__bridge id)kSecValueData] = d ?: [NSData data];
        add[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
        st = SecItemAdd((__bridge CFDictionaryRef)add, NULL);
    }
    if (st != errSecSuccess) {
        // 钥匙串写不进去（巨魔/沙盒限制），退化到 NSUserDefaults
        [[DYBPrefs shared] setString:k for:kDYBAIFallback];
    } else {
        [[DYBPrefs shared] setString:@"" for:kDYBAIFallback];
    }
}

+ (NSString *)endpoint {
    NSString *base = [[DYBPrefs shared] stringFor:DYBKey_aiBase default:@"https://api.openai.com/v1"];
    base = [base stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while (base.length > 1 && [base hasSuffix:@"/"]) base = [base substringToIndex:base.length - 1];
    if ([base hasSuffix:@"/chat/completions"]) return base;
    NSString *path = [[DYBPrefs shared] stringFor:DYBKey_aiPath default:@"/chat/completions"];
    if (![path hasPrefix:@"/"]) path = [@"/" stringByAppendingString:path];
    return [base stringByAppendingString:path];
}

+ (BOOL)ready {
    if (![self enabled]) return NO;
    if ([self apiKey].length == 0) return NO;
    NSString *base = [[DYBPrefs shared] stringFor:DYBKey_aiBase default:@""];
    if (base.length == 0) return NO;
    NSString *m = [[DYBPrefs shared] stringFor:DYBKey_aiModel default:@""];
    return m.length > 0;
}

#pragma mark 网络

+ (void)chat:(NSArray<NSDictionary<NSString *, NSString *> *> *)messages
  completion:(void (^)(NSString *text, NSError *error))completion {
    if (!completion) return;

    NSString *key = [self apiKey];
    if (key.length == 0) { completion(nil, DYBAIErr(@"还没填 API Key")); return; }

    NSString *model = [[DYBPrefs shared] stringFor:DYBKey_aiModel default:@"gpt-4o-mini"];
    double temp = [[DYBPrefs shared] floatFor:DYBKey_aiTemperature default:0.7];
    NSInteger maxTok = [[DYBPrefs shared] intFor:DYBKey_aiMaxTokens default:800];
    NSString *sys = [[DYBPrefs shared] stringFor:DYBKey_aiSystem default:@""];

    NSMutableArray *msgs = [NSMutableArray array];
    if (sys.length) [msgs addObject:DYBMsg(@"system", sys)];
    [msgs addObjectsFromArray:messages ?: @[]];

    NSDictionary *body = @{
        @"model": model,
        @"messages": msgs,
        @"temperature": @(temp),
        @"max_tokens": @(maxTok),
        @"stream": @NO,
    };

    NSURL *url = [NSURL URLWithString:[self endpoint]];
    if (!url) { completion(nil, DYBAIErr(@"接口地址不合法")); return; }

    NSData *payload = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    if (!payload) { completion(nil, DYBAIErr(@"请求体构造失败")); return; }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                      cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                  timeoutInterval:60.0];
    req.HTTPMethod = @"POST";
    req.HTTPBody = payload;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[@"Bearer " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
    [req setValue:@"DYBoost/1.0" forHTTPHeaderField:@"User-Agent"];

    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) { completion(nil, err); return; }
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
        id json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;

        if (http.statusCode >= 400) {
            NSString *m = nil;
            if ([json isKindOfClass:NSDictionary.class]) {
                id e = json[@"error"];
                if ([e isKindOfClass:NSDictionary.class]) m = e[@"message"];
                else if ([e isKindOfClass:NSString.class]) m = e;
                if (!m) m = json[@"message"];
            }
            if (!m) m = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (m.length > 200) m = [m substringToIndex:200];
            completion(nil, DYBAIErr([NSString stringWithFormat:@"HTTP %ld %@", (long)http.statusCode, m ?: @""]));
            return;
        }

        NSString *text = nil;
        if ([json isKindOfClass:NSDictionary.class]) {
            id ch = json[@"choices"];
            if ([ch isKindOfClass:NSArray.class] && [ch count]) {
                id c0 = ch[0];
                if ([c0 isKindOfClass:NSDictionary.class]) {
                    id m = c0[@"message"];
                    if ([m isKindOfClass:NSDictionary.class]) text = m[@"content"];
                    if (![text isKindOfClass:NSString.class]) text = c0[@"text"];
                }
            }
            if (!text) text = json[@"content"] ?: json[@"text"] ?: json[@"response"];
        }
        if ([text isKindOfClass:NSString.class] && ((NSString *)text).length) {
            completion((NSString *)text, nil);
        } else {
            completion(nil, DYBAIErr(@"接口返回里没找到文本内容"));
        }
    }] resume];
}

#pragma mark 上下文

+ (BOOL)plausibleComment:(NSString *)s {
    if (s.length < 4 || s.length > 220) return NO;
    static NSSet *chrome;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        chrome = [NSSet setWithArray:@[
            @"关注", @"已关注", @"点赞", @"评论", @"收藏", @"分享", @"转发", @"更多", @"展开", @"收起",
            @"回复", @"复制", @"举报", @"不感兴趣", @"置顶", @"热评", @"最新", @"全部", @"作者",
            @"说点什么", @"善语结善缘", @"抢首评", @"一起聊聊", @"加入粉丝群", @"直播中", @"私信",
            @"主页", @"搜索", @"取消", @"确定", @"发送", @"表情", @"相册", @"拍摄",
        ]];
    });
    NSString *t = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([chrome containsObject:t]) return NO;
    // 纯数字 / 纯时间 / 纯计数
    NSCharacterSet *nonDigit = [NSCharacterSet decimalDigitCharacterSet].invertedSet;
    if ([t rangeOfCharacterFromSet:nonDigit].location == NSNotFound) return NO;
    if ([t hasPrefix:@"http://"] || [t hasPrefix:@"https://"]) return NO;
    if ([t containsString:@"万"] && t.length <= 6) return NO;
    if ([t containsString:@"分钟前"] || [t containsString:@"小时前"] || [t containsString:@"天前"]) return NO;
    return YES;
}

+ (NSArray<NSString *> *)visibleComments:(NSInteger)limit {
    UIWindow *w = DYBKeyWindow();
    if (!w) return @[];

    NSMutableArray<NSString *> *out = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    // 主路径：评论区是列表，逐条取 cell 里最长的那段文本
    NSMutableArray<UIView *> *cells = [NSMutableArray array];
    DYBWalkViews(w, ^(UIView *v, BOOL *stop) {
        if ([v isKindOfClass:UITableViewCell.class]) [cells addObject:v];
        else if ([v isKindOfClass:UICollectionViewCell.class]) [cells addObject:v];
    });

    for (UIView *cell in cells) {
        if (cell.window == nil) continue;
        __block NSString *best = nil;
        DYBWalkViews(cell, ^(UIView *v, BOOL *stop) {
            NSString *t = nil;
            if ([v isKindOfClass:UILabel.class]) t = ((UILabel *)v).text;
            else if ([v isKindOfClass:UITextView.class]) t = ((UITextView *)v).text;
            if (!t) return;
            t = [t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (![self plausibleComment:t]) return;
            if (!best || t.length > best.length) best = t;
        });
        if (best.length && ![seen containsObject:best]) {
            [seen addObject:best];
            [out addObject:best];
        }
    }

    // 兜底：全屏扫标签（有些版本评论区不是标准 cell）
    if (out.count == 0) {
        DYBWalkViews(w, ^(UIView *v, BOOL *stop) {
            if (![v isKindOfClass:UILabel.class]) return;
            NSString *t = ((UILabel *)v).text;
            if (!t || v.window == nil) return;
            t = [t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (![self plausibleComment:t] || [seen containsObject:t]) return;
            [seen addObject:t];
            [out addObject:t];
        });
    }

    if (limit > 0 && (NSInteger)out.count > limit) return [out subarrayWithRange:NSMakeRange(0, (NSUInteger)limit)];
    return out;
}

+ (BOOL)fillCommentBox:(NSString *)text {
    if (!text.length) return NO;
    UIView *target = DYBFindView(DYBKeyWindow(), ^BOOL(UIView *v) {
        NSString *cn = NSStringFromClass(v.class).lowercaseString;
        if (!([cn containsString:@"textview"] || [cn containsString:@"textfield"]
              || [cn containsString:@"input"] || [cn containsString:@"edit"])) return NO;
        return [v respondsToSelector:NSSelectorFromString(@"setText:")] || [v respondsToSelector:NSSelectorFromString(@"setAttributedText:")];
    });
    if (!target) return NO;

    @try {
        if ([target respondsToSelector:NSSelectorFromString(@"setText:")]) {
            [target setValue:text forKey:@"text"];
        } else if ([target respondsToSelector:NSSelectorFromString(@"setAttributedText:")]) {
            [target setValue:[[NSAttributedString alloc] initWithString:text attributes:@{}] forKey:@"attributedText"];
        }
        // 通知 delegate 文本变了，否则发送按钮可能还是灰的
        id del = nil;
        @try { del = [target valueForKey:@"delegate"]; } @catch (NSException *e) { }
        if (del && [del respondsToSelector:NSSelectorFromString(@"textViewDidChange:")]) {
            @try { [del performSelector:NSSelectorFromString(@"textViewDidChange:") withObject:target]; } @catch (NSException *e) { }
        }
        [target becomeFirstResponder];
    } @catch (NSException *e) {
        return NO;
    }
    return YES;
}

#pragma mark 动作

+ (void)menu {
    if (![self ready]) { [DYBHUD show:@"先在插件面板 → AI 助手里配置接口"]; return; }
    [DYBMenu choose:@"AI 助手"
            message:@"只会把当前作品的文案 / 可见评论发给你自己配置的接口"
            options:@[@"总结当前视频", @"总结评论区", @"写一条评论回复", @"翻译当前文案", @"自定义指令..."]
            current:0
               done:^(NSInteger i) {
        if (i == 4) { [self runCustom:nil]; return; }
        [self run:(DYBAIAction)(DYBAIActionSummary + i)];
    }];
}

+ (void)run:(DYBAIAction)action { [self run:action extra:nil]; }

+ (void)run:(DYBAIAction)action extra:(NSString *)extra {
    if (![self ready]) { [DYBHUD show:@"先在插件面板 → AI 助手里配置接口"]; return; }

    DYBAweme *a = [DYBAweme current];
    NSString *desc   = a.desc ?: @"";
    NSString *author = a.authorName ?: @"";

    switch (action) {
        case DYBAIActionSummary: {
            if (desc.length == 0 && author.length == 0) { [DYBHUD show:@"没识别到当前作品"]; return; }
            NSString *p = DYBFill(DYBTemplate(DYBKey_aiTplSummary, @""), @{@"desc": desc, @"author": author, @"comments": @""});
            [self ask:@[DYBMsg(@"user", p)] title:@"AI 总结"];
            break;
        }
        case DYBAIActionComments: {
            NSArray *cs = [self visibleComments:30];
            if (cs.count == 0) { [DYBHUD show:@"没抓到评论，打开评论区再试"]; return; }
            NSString *joined = [cs componentsJoinedByString:@"\n- "];
            NSString *p = DYBFill(DYBTemplate(DYBKey_aiTplComments, @""), @{@"desc": desc, @"comments": [@"- " stringByAppendingString:joined], @"author": author});
            [self ask:@[DYBMsg(@"user", p)] title:@"评论总结"];
            break;
        }
        case DYBAIActionReply: {
            NSArray *cs = [self visibleComments:12];
            NSString *target = extra;
            if (!target.length) {
                if (cs.count == 0) { [DYBHUD show:@"没抓到评论，打开评论区再试"]; return; }
                if (cs.count == 1) {
                    target = cs.firstObject;
                } else {
                    [DYBMenu choose:@"选一条评论" message:@"为它生成回复" options:cs current:0 done:^(NSInteger i) {
                        [self run:DYBAIActionReply extra:cs[i]];
                    }];
                    return;
                }
            }
            NSString *p = DYBFill(DYBTemplate(DYBKey_aiTplReply, @""), @{@"comment": target, @"desc": desc});
            [self ask:@[DYBMsg(@"user", p)] title:@"AI 回复"];
            break;
        }
        case DYBAIActionTranslate: {
            NSString *src = extra.length ? extra : desc;
            if (src.length == 0) { [DYBHUD show:@"没有可翻译的内容"]; return; }
            NSString *p = DYBFill(DYBTemplate(DYBKey_aiTplTranslate, @""), @{@"text": src});
            [self ask:@[DYBMsg(@"user", p)] title:@"翻译"];
            break;
        }
        case DYBAIActionCustom: {
            NSString *cmd = extra;
            if (!cmd.length) {
                [DYBMenu input:@"自定义指令" message:@"会连同当前作品文案 / 可见评论一起发给你自己的接口"
                          text:@"" placeholder:@"例：把这条视频改写成小红书文案"
                          done:^(NSString *t) {
                    if (t.length) [self run:DYBAIActionCustom extra:t];
                }];
                return;
            }
            NSArray *cs = [self visibleComments:20];
            NSMutableString *ctx = [NSMutableString string];
            if (author.length) [ctx appendFormat:@"作者：%@\n", author];
            if (desc.length)   [ctx appendFormat:@"文案：%@\n", desc];
            if (cs.count)      [ctx appendFormat:@"评论：\n- %@\n", [cs componentsJoinedByString:@"\n- "]];
            NSString *p = DYBFill(DYBTemplate(DYBKey_aiTplCustom, @""), @{@"command": cmd, @"context": ctx});
            [self ask:@[DYBMsg(@"user", p)] title:@"AI"];
            break;
        }
    }
}

+ (void)runCustom:(NSString *)instruction { [self run:DYBAIActionCustom extra:instruction]; }

+ (void)testConnection {
    if (![self ready]) { [DYBHUD show:@"先填接口地址 / API Key / 模型名"]; return; }
    [DYBHUD showLoading:@"连接中..."];
    [self chat:@[DYBMsg(@"user", @"只回复两个字：OK")] completion:^(NSString *text, NSError *error) {
        [DYBHUD hideLoading];
        if (error) [DYBHUD show:error.localizedDescription duration:3.0];
        else [DYBHUD show:[NSString stringWithFormat:@"通了：%@", text.length > 40 ? [text substringToIndex:40] : text] duration:3.0];
    }];
}

#pragma mark 结果展示

+ (void)ask:(NSArray<NSDictionary<NSString *, NSString *> *> *)messages title:(NSString *)title {
    [DYBHUD showLoading:@"AI 思考中..."];
    [self chat:messages completion:^(NSString *text, NSError *error) {
        [DYBHUD hideLoading];
        DYBAsyncMain(^{
            if (error || text.length == 0) {
                [DYBHUD show:error.localizedDescription ?: @"没有返回结果" duration:3.0];
                return;
            }
            if ([[DYBPrefs shared] boolFor:DYBKey_aiAutoCopy default:NO]) {
                UIPasteboard.generalPasteboard.string = text;
            }
            [DYBAIResultVC show:title text:text messages:messages];
        });
    }];
}

@end

#pragma mark - 结果页

@implementation DYBAIResultVC

+ (void)show:(NSString *)title text:(NSString *)text messages:(NSArray<NSDictionary<NSString *, NSString *> *> *)messages {
    if (!text.length) return;
    UIViewController *top = DYBMostTopViewController();
    if (!top) return;
    DYBAIResultVC *vc = [DYBAIResultVC new];
    vc.title = title ?: @"AI";
    vc.resultText = text;
    vc.messages = messages;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    if (@available(iOS 15.0, *)) nav.modalPresentationStyle = UIModalPresentationPageSheet;
    else nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [top presentViewController:nav animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(close)];

    self.tv = [[UITextView alloc] initWithFrame:self.view.bounds];
    self.tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tv.font = [UIFont systemFontOfSize:16];
    self.tv.editable = NO;
    self.tv.text = self.resultText;
    self.tv.alwaysBounceVertical = YES;
    self.tv.textContainerInset = UIEdgeInsetsMake(16, 14, 16, 14);
    [self.view addSubview:self.tv];

    UIToolbar *bar = [[UIToolbar alloc] initWithFrame:CGRectZero];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:bar];
    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    ]];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *copy = [[UIBarButtonItem alloc] initWithTitle:@"复制" style:UIBarButtonItemStylePlain target:self action:@selector(doCopy)];
    UIBarButtonItem *fill = [[UIBarButtonItem alloc] initWithTitle:@"填入评论框" style:UIBarButtonItemStylePlain target:self action:@selector(doFill)];
    UIBarButtonItem *redo = [[UIBarButtonItem alloc] initWithTitle:@"重新生成" style:UIBarButtonItemStylePlain target:self action:@selector(doRedo)];
    bar.items = @[copy, flex, fill, flex, redo, flex];

    UIEdgeInsets insets = self.tv.textContainerInset;
    insets.bottom += 44;
    self.tv.textContainerInset = insets;
}

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)doCopy {
    UIPasteboard.generalPasteboard.string = self.resultText;
    [DYBHUD show:@"已复制"];
}

- (void)doFill {
    if ([DYBAI fillCommentBox:self.resultText]) {
        [self dismissViewControllerAnimated:YES completion:nil];
        [DYBHUD show:@"已填入评论框"];
    } else {
        UIPasteboard.generalPasteboard.string = self.resultText;
        [DYBHUD show:@"没找到输入框，已复制到剪贴板"];
    }
}

- (void)doRedo {
    NSArray *msgs = self.messages;
    __weak typeof(self) wself = self;
    [DYBHUD showLoading:@"重新生成..."];
    [DYBAI chat:msgs completion:^(NSString *text, NSError *error) {
        [DYBHUD hideLoading];
        DYBAsyncMain(^{
            if (error || !text.length) { [DYBHUD show:error.localizedDescription ?: @"没有返回结果"]; return; }
            wself.resultText = text;
            wself.tv.text = text;
        });
    }];
}

@end
