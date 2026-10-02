//
//  DYBSafe.m
//  DYBoost
//
//  见 DYBSafe.h。这里的读写全部走 NSUserDefaults(suite)，
//  不经过 DYBPrefs —— 因为看门狗在后台线程写盘，不能碰任何 UI 相关东西。
//

#import "DYBSafe.h"
#import <UIKit/UIKit.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>

// 编译期可改：lite 版直接定成 1，默认只挂悬浮球 + 手势
#ifndef DYB_DEFAULT_STAGE
#define DYB_DEFAULT_STAGE 2
#endif

static NSString * const kSuite   = @"com.seagull.dyboost";
static NSString * const kKill    = @"DYB.killSwitch";
static NSString * const kStage   = @"DYB.safeStage";
static NSString * const kDegrade = @"DYB.degradeCount";

static int      gStage      = 2;
static BOOL     gKill       = NO;
static BOOL     gLoaded     = NO;
static BOOL     gDogRunning = NO;
static volatile int64_t gLastPing = 0;

#pragma mark - 存储

static NSUserDefaults *DYBSafeStore(void) {
    static NSUserDefaults *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        s = [[NSUserDefaults alloc] initWithSuiteName:kSuite] ?: [NSUserDefaults standardUserDefaults];
        [s registerDefaults:@{ kKill: @NO, kStage: @(DYB_DEFAULT_STAGE), kDegrade: @0 }];
    });
    return s;
}

static int64_t DYBMillis(void) {
    return (int64_t)(CACurrentMediaTime() * 1000.0);
}

static void DYBLoadState(void) {
    if (gLoaded) return;
    gLoaded = YES;
    NSUserDefaults *s = DYBSafeStore();
    gKill  = [s boolForKey:kKill];
    gStage = (int)[s integerForKey:kStage];
    if (gStage < 1) gStage = 1;
    if (gStage > 2) gStage = 2;
}

BOOL DYBKillSwitch(void) { DYBLoadState(); return gKill; }

int DYBSafeStage(void) { DYBLoadState(); return gKill ? 0 : gStage; }

int DYBSafeDegradeCount(void) {
    DYBLoadState();
    return (int)[DYBSafeStore() integerForKey:kDegrade];
}

void DYBSetKillSwitch(BOOL on) {
    DYBLoadState();
    gKill = on;
    NSUserDefaults *s = DYBSafeStore();
    [s setBool:on forKey:kKill];
    [s synchronize];
}

void DYBSetSafeStage(int stage) {
    DYBLoadState();
    if (stage < 1) stage = 1;
    if (stage > 2) stage = 2;
    gStage = stage;
    NSUserDefaults *s = DYBSafeStore();
    [s setInteger:stage forKey:kStage];
    [s synchronize];
}

#pragma mark - 看门狗

/// 后台线程发现主线程超时后调用：降级 + 写盘（下次启动生效）
static void DYBDogDegrade(int fromStage) {
    int next = fromStage - 1;
    NSUserDefaults *s = DYBSafeStore();
    if (next < 1) {
        // 连最轻的一级都卡住：直接整体关闭，至少保证抖音能开
        [s setBool:YES forKey:kKill];
        [s setInteger:1 forKey:kStage];
    } else {
        [s setInteger:next forKey:kStage];
    }
    [s setInteger:[s integerForKey:kDegrade] + 1 forKey:kDegrade];
    [s synchronize];
    NSLog(@"[DYBoost][safe] 主线程无响应，已降级 stage %d -> %d（重启抖音生效）", fromStage, next);
}

void DYBSafePing(void) { gLastPing = DYBMillis(); }

void DYBSafeBeginStage(int stage, NSTimeInterval timeout) {
    if (gDogRunning) return;
    if (timeout <= 0) timeout = 8.0;

    gLastPing = DYBMillis();
    // 主线程正常时每 0.5s 喂一次狗
    __block BOOL alive = YES;
    dispatch_async(dispatch_get_main_queue(), ^{ DYBSafePing(); });

    gDogRunning = YES;
    dispatch_queue_t q = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    dispatch_async(q, ^{
        int64_t limit = (int64_t)(timeout * 1000.0);
        CFTimeInterval start = CACurrentMediaTime();
        while (alive) {
            usleep(250 * 1000);
            dispatch_async(dispatch_get_main_queue(), ^{ DYBSafePing(); });
            int64_t gap = DYBMillis() - gLastPing;
            if (gap > limit) { DYBDogDegrade(stage); break; }
            // 最多盯 60 秒，别一直占着一条队列
            if (CACurrentMediaTime() - start > 60.0) break;
        }
        gDogRunning = NO;
    });

    // 主线程一旦正常跑起来，30 秒后自动撤掉看门狗（之后卡顿可能是抖音自己的锅）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ alive = NO; });
}

#pragma mark - 空闲调度 / 节流

static NSMutableDictionary<NSString *, NSNumber *> *gThrottle;

BOOL DYBThrottle(NSString *key, NSTimeInterval interval) {
    if (key.length == 0) return YES;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ gThrottle = [NSMutableDictionary dictionary]; });
    CFTimeInterval now = CACurrentMediaTime();
    NSNumber *last = gThrottle[key];
    if (last && now - last.doubleValue < interval) return NO;
    gThrottle[key] = @(now);
    return YES;
}

/// 把 observer 摘掉并延后释放：在 observer 自己的回调里 CFRelease 会 use-after-free
/// （runloop 回调返回后还要访问 observer），闪退有一半是这个原因。
static void DYBDropObserver(CFRunLoopObserverRef r) {
    if (!r) return;
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), r, kCFRunLoopCommonModes);
    dispatch_async(dispatch_get_main_queue(), ^{ CFRelease(r); });
}

void DYBRunWhenIdle(dispatch_block_t block) {
    if (!block) return;
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        // 后台时不做重活，等回到前台
        __block __weak id weakObs = nil;
        id obs = [[NSNotificationCenter defaultCenter]
                  addObserverForName:UIApplicationDidBecomeActiveNotification
                              object:nil
                               queue:NSOperationQueue.mainQueue
                          usingBlock:^(NSNotification *n) {
            id o = weakObs;
            if (o) [[NSNotificationCenter defaultCenter] removeObserver:o];
            DYBRunWhenIdle(block);
        }];
        weakObs = obs;
        return;
    }

    __block CFRunLoopObserverRef ref = NULL;
    __block BOOL done = NO;

    CFRunLoopObserverRef created =
        CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault,
                                           kCFRunLoopBeforeWaiting | kCFRunLoopExit,
                                           YES, 0,
                                           ^(CFRunLoopObserverRef o, CFRunLoopActivity a) {
        if (done) return;
        done = YES;
        CFRunLoopObserverRef r = ref; ref = NULL;
        DYBDropObserver(r);
        @autoreleasepool { block(); }
        DYBSafePing();
    });
    ref = created;
    CFRunLoopAddObserver(CFRunLoopGetMain(), created, kCFRunLoopCommonModes);

    // 兜底：RunLoop 一直忙，2 秒后也强制跑一次
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (done) return;
        done = YES;
        CFRunLoopObserverRef r = ref; ref = NULL;
        DYBDropObserver(r);
        @autoreleasepool { block(); }
        DYBSafePing();
    });
}

#pragma mark - 崩溃黑匣子

static NSString * const kCrash = @"DYB.lastCrash";
static NSUncaughtExceptionHandler *gPrevExceptionHandler;
static char *gTraceFile = NULL;
static char *gCrashFile = NULL;

/// 逐阶段落盘追踪：每一步都立即 write() 到文件，崩了也能看到最后走到哪一步。
/// 只用 async-signal-safe 的 open/write/close，且必须在 crash trap 之后调用。
void DYBTrace(NSString *line) {
    if (!gTraceFile || line.length == 0) return;
    NSString *s = [NSString stringWithFormat:@"%@\n", line];
    const char *u = s.UTF8String;
    int fd = open(gTraceFile, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd >= 0) { write(fd, u, strlen(u)); close(fd); }
}

static void DYBRecordCrash(NSString *text) {
    if (text.length == 0) return;
    NSString *stamp = [NSString stringWithFormat:@"[%@]\n%@", [NSDate date], text];
    NSUserDefaults *s = DYBSafeStore();
    [s setObject:stamp forKey:kCrash];
    [s synchronize];
    if (gCrashFile) {
        int fd = open(gCrashFile, O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (fd >= 0) {
            const char *u = [stamp UTF8String];
            write(fd, u, strlen(u));
            write(fd, "\n\n", 2);
            close(fd);
        }
    }
}

static void DYBExceptionTrap(NSException *e) {
    NSArray *syms = e.callStackSymbols ?: @[];
    NSArray *head = [syms subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)20, syms.count))];
    DYBRecordCrash([NSString stringWithFormat:@"ObjC 异常 %@\n原因: %@\n%@",
                    e.name, e.reason, [head componentsJoinedByString:@"\n"]]);
    if (gPrevExceptionHandler) gPrevExceptionHandler(e);
}

static void DYBSignalTrap(int sig) {
    // 信号上下文里只能用 async-signal-safe 的东西，别碰 Foundation
    if (gCrashFile) {
        int fd = open(gCrashFile, O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (fd >= 0) {
            char buf[96];
            int n = snprintf(buf, sizeof(buf), "signal %d (%s)\n", sig,
                             sig == SIGSEGV ? "SIGSEGV" : sig == SIGABRT ? "SIGABRT" :
                             sig == SIGBUS  ? "SIGBUS"  : sig == SIGILL  ? "SIGILL" : "?");
            if (n > 0) write(fd, buf, (size_t)n);
            close(fd);
        }
    }
    signal(sig, SIG_DFL);
    raise(sig);
}

void DYBSafeInstallCrashTrap(void) {
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        NSString *dir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                            NSUserDomainMask, YES).firstObject
                     ?: NSTemporaryDirectory();
        NSString *path = [dir stringByAppendingPathComponent:@"dyboost-crash.log"];
        gCrashFile = strdup(path.fileSystemRepresentation);
        gTraceFile = gCrashFile;
        gPrevExceptionHandler = NSGetUncaughtExceptionHandler();
        NSSetUncaughtExceptionHandler(&DYBExceptionTrap);
        signal(SIGABRT, &DYBSignalTrap);
        signal(SIGBUS,  &DYBSignalTrap);
        signal(SIGILL,  &DYBSignalTrap);
        signal(SIGSEGV, &DYBSignalTrap);
    });
}

NSString *DYBLastCrash(void) {
    NSString *s = [DYBSafeStore() stringForKey:kCrash];
    return s ?: @"";
}

NSString *DYBCrashLogPath(void) {
    return gCrashFile ? [NSString stringWithUTF8String:gCrashFile] : @"";
}
