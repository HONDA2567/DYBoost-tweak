//
//  DYBHookKit.h
//  DYBoost
//
//  纯 runtime 的 hook / 探测工具。
//  不依赖抖音内部头文件：所有内部类都用「候选类名列表」在运行时解析，
//  解析不到的功能自动降级，插件不会因类名变动而崩。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 类解析

/// 从候选类名里挑第一个运行时存在的类
Class _Nullable DYBFirstClass(NSArray<NSString *> *candidates);
/// 批量解析，返回 候选名 -> 是否命中 的诊断信息（面板“诊断”页用）
NSDictionary<NSString *, NSNumber *> *DYBProbeClasses(NSDictionary<NSString *, NSArray<NSString *> *> *groups);

#pragma mark - Hook

/// 用函数指针 hook 实例方法。origOut 可为 NULL（不调用原实现）
BOOL DYBHookMessage(Class cls, SEL sel, void *replacement, void *_Nullable *_Nullable origOut);
/// 用 block hook 实例方法（block 签名为 ^(id self, SEL _cmd, ...)）
BOOL DYBHookBlock(Class cls, SEL sel, id block, void *_Nullable *_Nullable origOut);
/// 类方法版本
BOOL DYBHookClassMethod(Class cls, SEL sel, void *replacement, void *_Nullable *_Nullable origOut);
/// 一次性安装：候选类名里第一个命中的类 + 第一个存在的方法
BOOL DYBHookFirst(NSArray<NSString *> *classes, NSArray<NSString *> *sels, id block, void *_Nullable *_Nullable origOut);

#pragma mark - 安全取值

id _Nullable DYBSafeGet(id obj, NSString *key);
BOOL DYBSafeSet(id obj, NSString *key, id _Nullable value);
/// 按候选 key 依次尝试
id _Nullable DYBPick(id obj, NSArray<NSString *> *keys);
/// 找对象响应第一个存在的方法并返回调用结果（无参）
id _Nullable DYBCall(id obj, NSArray<NSString *> *sels);

#pragma mark - 对象图扫描

/// 通过 ivar / 数组 / 字典递归查找指定类名的实例
id _Nullable DYBFindObject(id root, NSArray<NSString *> *classNames, int maxDepth);
/// 递归收集所有 NSString（可用来抓 URL）
NSArray<NSString *> *DYBCollectStrings(id root, int maxDepth);

#pragma mark - UI 工具

UIWindow *_Nullable DYBKeyWindow(void);
UIViewController *_Nullable DYBMostTopViewController(void);
UIView *_Nullable DYBFindView(UIView *root, BOOL (^predicate)(UIView *view));
void DYBWalkViews(UIView *root, void (^visit)(UIView *view, BOOL *stop));

void DYBAsyncMain(dispatch_block_t block);
void DYBAsyncMainAfter(NSTimeInterval delay, dispatch_block_t block);
void DYBHaptic(UIImpactFeedbackStyle style);

NS_ASSUME_NONNULL_END
