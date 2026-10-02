//
//  DYBAI.h
//  DYBoost
//
//  AI 模块：接你自己部署 / 自己的 OpenAI 兼容接口（chat/completions）。
//  密钥存本机钥匙串（不可用时退化到 NSUserDefaults），提示词全部可在面板里改。
//  除了你填的那个接口，本插件不会把任何数据发到别处。
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, DYBAIAction) {
    DYBAIActionSummary = 0,     // 总结当前视频
    DYBAIActionComments,        // 总结评论区
    DYBAIActionReply,           // 写一条评论回复
    DYBAIActionTranslate,       // 翻译当前文案
    DYBAIActionCustom,          // 自定义指令
};

@interface DYBAI : NSObject

/// 总开关打开且接口信息齐全
+ (BOOL)ready;
/// 只判断开关（用于在菜单里决定要不要提示去配置）
+ (BOOL)enabled;

/// 弹一个 AI 动作选择菜单（悬浮球 / 长按菜单用）
+ (void)menu;

/// 执行某个动作
+ (void)run:(DYBAIAction)action;
/// 自定义指令（instruction 为空会先弹输入框）
+ (void)runCustom:(NSString *)instruction;

/// 连通性自检：发一条极短请求
+ (void)testConnection;

/// API Key（钥匙串优先）
+ (NSString *)apiKey;
+ (void)setApiKey:(NSString *)key;

/// 当前屏幕上能看到的评论文本（抓 cell 里的文本，拿不到就返回空数组）
+ (NSArray<NSString *> *)visibleComments:(NSInteger)limit;
/// 把文本填进评论输入框（找不到返回 NO，调用方应兜底走剪贴板）
+ (BOOL)fillCommentBox:(NSString *)text;

/// 底层：发一轮对话
+ (void)chat:(NSArray<NSDictionary<NSString *, NSString *> *> *)messages
  completion:(void (^)(NSString *text, NSError *error))completion;

@end
