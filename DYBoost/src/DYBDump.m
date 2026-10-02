//
//  DYBDump.m
//  DYBoost
//

#import "DYBDump.h"
#import "DYBPrefs.h"
#import "DYBHUD.h"
#import "DYBHookKit.h"
#import "DYBAweme.h"
#import "DYBBeauty.h"
#import "DYBContext.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <sys/utsname.h>

static NSArray<NSString *> *DYBDumpKeyPrefixes(void) {
    return @[@"AWE", @"AWEM", @"AWEF", @"FDS", @"IES", @"BDX", @"HTS", @"TT", @"TTV", @"AFD", @"ACC", @"DYS"];
}

static NSArray<NSString *> *DYBAllClassNames(void) {
    unsigned n = objc_getClassList(NULL, 0);
    Class *buf = (Class *)malloc(sizeof(Class) * (n ?: 1));
    n = objc_getClassList(buf, n);
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:n];
    for (unsigned i = 0; i < n; i++) {
        const char *cn = class_getName(buf[i]);
        if (cn) [out addObject:[NSString stringWithUTF8String:cn]];
    }
    free(buf);
    return out;
}

static NSString *DYBDeviceString(void) {
    struct utsname s;
    uname(&s);
    return [NSString stringWithUTF8String:s.machine];
}

@implementation DYBDump

+ (NSString *)report {
    NSMutableString *o = [NSMutableString string];
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    [o appendFormat:@"### DYBoost 校准报告\n"];
    [o appendFormat:@"app=%@ (%@)\n", info[@"CFBundleIdentifier"], info[@"CFBundleShortVersionString"] ?: info[@"CFBundleVersion"]];
    [o appendFormat:@"build=%@\n", info[@"CFBundleVersion"]];
    [o appendFormat:@"ios=%@ device=%@\n", UIDevice.currentDevice.systemVersion, DYBDeviceString()];
    [o appendFormat:@"dyboost=1.0.0 date=%.0f\n", [[NSDate date] timeIntervalSince1970]];

    // 顶层 VC 链
    [o appendString:@"\n### 顶层视图控制器\n"];
    @try {
        UIViewController *vc = DYBMostTopViewController();
        NSMutableArray *chain = [NSMutableArray array];
        UIViewController *cur = vc;
        int guard = 0;
        while (cur && guard++ < 12) {
            [chain addObject:NSStringFromClass(cur.class)];
            cur = cur.parentViewController;
        }
        [o appendFormat:@"%@\n", [chain componentsJoinedByString:@" > "]];
        if (vc) {
            NSMutableSet<NSString *> *sub = [NSMutableSet set];
            DYBWalkViews(vc.view, ^(UIView *v, BOOL *stop) {
                if (sub.count > 200) { *stop = YES; return; }
                [sub addObject:NSStringFromClass(v.class)];
            });
            [o appendFormat:@"views(%lu)=%@\n", (unsigned long)sub.count,
             [[sub.allObjects sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","]];
        }
    } @catch (NSException *e) { [o appendString:@"(读取失败)\n"]; }

    // 当前作品
    [o appendString:@"\n### 当前作品解析结果\n"];
    @try {
        DYBAweme *a = [DYBAweme current];
        [o appendFormat:@"id=%@ author=%@ desc=%@\n", a.awemeID, a.authorName,
         a.desc.length > 120 ? [a.desc substringToIndex:120] : a.desc];
        [o appendFormat:@"video=%@ images=%lu audio=%lu cover=%@\n",
         a.videoURLs.firstObject ?: @"(nil)", (unsigned long)a.imageURLs.count,
         (unsigned long)a.audioURLs.count, a.coverURL ?: @"(nil)"];
    } @catch (NSException *e) { [o appendString:@"(读取失败)\n"]; }

    // 隐藏规则命中情况
    [o appendString:@"\n### 隐藏规则诊断\n"];
    @try {
        NSDictionary *d = [DYBBeauty diagnose];
        for (NSString *k in [d.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            [o appendFormat:@"%@ = %@\n", k, d[k]];
        }
    } @catch (NSException *e) { [o appendString:@"(读取失败)\n"]; }

    // 关键字类名
    NSArray *prefixes = DYBDumpKeyPrefixes();
    NSMutableArray *hits = [NSMutableArray array];
    for (NSString *name in DYBAllClassNames()) {
        for (NSString *p in prefixes) {
            if ([name hasPrefix:p]) { [hits addObject:name]; break; }
        }
    }
    [hits sortUsingSelector:@selector(compare:)];
    [o appendFormat:@"\n### 候选类名（%lu 条，前缀 %@）\n", (unsigned long)hits.count,
     [prefixes componentsJoinedByString:@"/"]];
    [o appendFormat:@"%@\n", [hits componentsJoinedByString:@"\n"]];

    return o;
}

+ (NSString *)fullClassList {
    NSArray *all = [DYBAllClassNames() sortedArrayUsingSelector:@selector(compare:)];
    NSMutableString *o = [NSMutableString string];
    [o appendFormat:@"### 全部类名 %lu 条\n", (unsigned long)all.count];
    [o appendFormat:@"%@\n", [all componentsJoinedByString:@"\n"]];
    return o;
}

+ (void)copyReport {
    NSString *r = [self report];
    UIPasteboard.generalPasteboard.string = r;
    [DYBHUD show:[NSString stringWithFormat:@"报告已复制（%.0f KB）", r.length / 1024.0] duration:2.5];
}

+ (void)share:(NSString *)text name:(NSString *)name {
    DYBAsyncMain(^{
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
        [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NSURL *url = [NSURL fileURLWithPath:path];
        UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
        UIViewController *top = DYBMostTopViewController();
        if (!top) { [DYBHUD show:@"找不到宿主 VC"]; return; }
        if (av.popoverPresentationController) av.popoverPresentationController.sourceView = top.view;
        [top presentViewController:av animated:YES completion:nil];
    });
}

+ (void)shareReport    { [self share:[self report] name:@"DYBoost-report.txt"]; }
+ (void)shareFullClassList { [self share:[self fullClassList] name:@"DYBoost-classes.txt"]; }

@end
