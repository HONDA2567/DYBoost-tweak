//
//  DYBSafe.h
//  DYBoost
//
//  防卡死安全层：
//   1. kill switch   —— 一键彻底不装载
//   2. 分级启动     —— stage 1 轻量 / stage 2 完整；某级卡住就永久降到上一级
//   3. 主线程看门狗 —— 检测到主线程长时间无响应，写盘降级，下次启动生效
//   4. 空闲调度     —— 重活只在主线程 RunLoop 空闲时做
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 是否整体关闭插件（YES = 一个 hook 都不装）
BOOL DYBKillSwitch(void);

/// 当前允许装载到的等级：1 = 只装悬浮球/手势，2 = 完整（美化 hook + 模型扫描）
int DYBSafeStage(void);

/// 手动设置等级上限（面板里给用户的开关），1 或 2
void DYBSetSafeStage(int stage);

/// 打开/关闭 kill switch
void DYBSetKillSwitch(BOOL on);

/// 启动后调用：登记当前等级并开看门狗。
/// 主线程在 timeout 秒内没回应，就把等级降到 stage-1 并写盘。
void DYBSafeBeginStage(int stage, NSTimeInterval timeout);

/// 看门狗喂狗：主线程每次跑一轮就调用一次
void DYBSafePing(void);

/// 只做一次的重活：主线程空闲时执行；app 未激活则顺延
void DYBRunWhenIdle(dispatch_block_t block);

/// 节流：同一个 key 在 interval 内只执行一次（尾部执行）
BOOL DYBThrottle(NSString *key, NSTimeInterval interval);

/// 已降级过几次（面板显示用）
int DYBSafeDegradeCount(void);

/// 装崩溃黑匣子：ObjC 未捕获异常 + SIGSEGV/ABRT/BUS/ILL。
/// 记录写进 NSUserDefaults(DYB.lastCrash) 与 Documents/dyboost-crash.log，
/// 下次打开面板就能看到上一次崩在哪（signal 只写文件）。
void DYBSafeInstallCrashTrap(void);
NSString *DYBLastCrash(void);
NSString *DYBCrashLogPath(void);

/// 逐阶段落盘追踪（写进同一个日志文件）。崩溃后看最后一行就知道死在哪一步。
void DYBTrace(NSString *line);

NS_ASSUME_NONNULL_END
