//
//  DYBActions.m
//  DYBoost
//

#import "DYBActions.h"
#import "DYBAweme.h"
#import "DYBMedia.h"
#import "DYBHUD.h"
#import "DYBMenu.h"
#import "DYBBeauty.h"
#import "DYBPrefs.h"
#import "DYBKeys.h"
#import "DYBHookKit.h"
#import "DYBContext.h"
#import "DYBPanel.h"
#import "DYBAI.h"
#import <AVFoundation/AVFoundation.h>

@implementation DYBActions

#pragma mark 播放器

+ (AVPlayer *)player {
    id vc = [DYBContext currentVC];
    if (!vc) return nil;
    id p = DYBFindObject(vc, @[@"AVPlayer"], 6);
    return [p isKindOfClass:AVPlayer.class] ? (AVPlayer *)p : nil;
}

+ (double)currentRate {
    AVPlayer *p = [self player];
    return p ? p.rate : 0.0;
}

+ (void)applySpeed:(double)rate { [self applySpeed:rate silent:NO]; }

+ (void)applySpeed:(double)rate silent:(BOOL)silent {
    AVPlayer *p = [self player];
    if (!p) { if (!silent) [DYBHUD show:@"没找到播放器，倍速未生效"]; return; }
    p.rate = rate;
    if (!silent) {
        [[DYBPrefs shared] setFloat:rate for:DYBKey_defaultSpeed];
        DYBHaptic(UIImpactFeedbackStyleLight);
        [DYBHUD show:[NSString stringWithFormat:@"倍速 %.2gx", rate]];
    }
}

#pragma mark 菜单

+ (void)quickMenu {
    DYBAweme *a = [DYBAweme current];
    NSMutableArray<NSDictionary *> *acts = [NSMutableArray array];

    [acts addObject:@{@"title": @"下载无水印视频", @"style": @0, @"action": ^{ [self downloadVideo]; }}];
    [acts addObject:@{@"title": @"复制无水印直链", @"style": @0, @"action": ^{ [self copyDirectLink]; }}];
    if (a.imageURLs.count) {
        [acts addObject:@{@"title": [NSString stringWithFormat:@"保存图集（%lu 张）", (unsigned long)a.imageURLs.count], @"style": @0, @"action": ^{ [self saveImages]; }}];
    }
    if (a.coverURL.length) {
        [acts addObject:@{@"title": @"保存封面", @"style": @0, @"action": ^{ [self saveCover]; }}];
    }
    if (a.audioURLs.count) {
        [acts addObject:@{@"title": @"下载背景音乐", @"style": @0, @"action": ^{ [self saveAudio]; }}];
    }
    [acts addObject:@{@"title": @"播放倍速", @"style": @0, @"action": ^{ [self chooseSpeed]; }}];
    [acts addObject:@{@"title": ([DYBBeauty isCleanScreen] ? @"退出清屏" : @"清屏模式"), @"style": @0, @"action": ^{ [self toggleCleanScreen]; }}];
    if ([DYBAI ready]) {
        [acts addObject:@{@"title": @"AI 助手", @"style": @0, @"action": ^{ [DYBAI menu]; }}];
    }
    [acts addObject:@{@"title": @"打开插件面板", @"style": @0, @"action": ^{ [self openPanel]; }}];

    NSString *msg = nil;
    if (a.desc.length) {
        NSString *head = [a.desc substringToIndex:MIN((NSUInteger)60, a.desc.length)];
        msg = [NSString stringWithFormat:@"%@\n@%@", head, a.authorName ?: @""];
    }
    [DYBMenu sheet:@"DYBoost" message:msg actions:acts];
}

#pragma mark 下载

+ (void)downloadVideo {
    DYBAweme *a = [DYBAweme current];
    if (a.videoURLs.count == 0) {
        if (a.awemeID.length == 0) { [DYBHUD show:@"没识别到当前作品"]; return; }
        [DYBHUD showLoading:@"解析中..."];
        [DYBMedia resolveItem:a.awemeID completion:^(NSDictionary *info, NSError *error) {
            NSArray *urls = info[@"videoURLs"];
            if (urls.count == 0) { [DYBHUD hideLoading]; [DYBHUD show:@"解析失败，可试试复制直链"]; return; }
            [self doDownload:urls.firstObject];
        }];
        return;
    }
    [self doDownload:a.videoURLs.firstObject];
}

+ (void)doDownload:(NSString *)url {
    NSString *final = [[DYBPrefs shared] boolFor:DYBKey_noWatermark default:YES] ? [DYBMedia noWatermark:url] : url;
    [DYBHUD showLoading:@"下载中... 0%"];
    [DYBMedia download:final progress:^(double p) {
        [DYBHUD updateLoading:[NSString stringWithFormat:@"下载中... %d%%", (int)(p * 100)]];
    } completion:^(NSURL *file, NSError *error) {
        if (error || !file) { [DYBHUD hideLoading]; [DYBHUD show:error.localizedDescription ?: @"下载失败"]; return; }
        if (![DYBMedia canWriteAlbum]) {
            [DYBHUD hideLoading];
            [DYBMedia exportFile:file fromVC:nil];
            [DYBHUD show:@"宿主无相册权限，已改用文件导出"];
            return;
        }
        [DYBHUD updateLoading:@"写入相册..."];
        [DYBMedia saveVideo:file completion:^(BOOL ok, NSError *err) {
            [DYBHUD hideLoading];
            [DYBHUD show:ok ? @"已保存到相册" : (err.localizedDescription ?: @"保存失败")];
            [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
        }];
    }];
}

+ (void)copyDirectLink {
    DYBAweme *a = [DYBAweme current];
    NSString *link = a.videoURLs.firstObject ?: a.imageURLs.firstObject;
    if (!link) { [DYBHUD show:@"没解析到直链"]; return; }
    link = [DYBMedia noWatermark:link];
    UIPasteboard.generalPasteboard.string = link;
    DYBHaptic(UIImpactFeedbackStyleLight);
    [DYBHUD show:@"无水印直链已复制"];
}

+ (void)saveCover {
    DYBAweme *a = [DYBAweme current];
    if (!a.coverURL) { [DYBHUD show:@"没解析到封面"]; return; }
    [DYBHUD showLoading:@"保存封面..."];
    [DYBMedia download:a.coverURL progress:nil completion:^(NSURL *file, NSError *error) {
        if (!file) { [DYBHUD hideLoading]; [DYBHUD show:@"封面下载失败"]; return; }
        NSData *d = [NSData dataWithContentsOfURL:file];
        [DYBMedia saveImageData:d completion:^(BOOL ok, NSError *err) {
            [DYBHUD hideLoading];
            [DYBHUD show:ok ? @"封面已保存" : @"保存失败"];
        }];
    }];
}

+ (void)saveAudio {
    DYBAweme *a = [DYBAweme current];
    NSString *u = a.audioURLs.firstObject;
    if (!u) { [DYBHUD show:@"没解析到音频"]; return; }
    [DYBHUD showLoading:@"下载音频..."];
    [DYBMedia download:u progress:nil completion:^(NSURL *file, NSError *error) {
        [DYBHUD hideLoading];
        if (!file) { [DYBHUD show:@"音频下载失败"]; return; }
        [DYBMedia exportFile:file fromVC:nil];
    }];
}

+ (void)saveImages {
    DYBAweme *a = [DYBAweme current];
    if (a.imageURLs.count == 0) { [DYBHUD show:@"当前不是图集"]; return; }
    [DYBHUD showLoading:@"保存图集..."];
    [DYBMedia saveImages:a.imageURLs completion:^(NSInteger ok, NSInteger fail) {
        [DYBHUD hideLoading];
        [DYBHUD show:[NSString stringWithFormat:@"图片：成功 %ld 失败 %ld", (long)ok, (long)fail]];
    }];
}

+ (void)chooseSpeed {
    NSArray *opts = @[@"0.75x", @"1.0x 正常", @"1.25x", @"1.5x", @"2.0x", @"3.0x"];
    NSArray *vals = @[@0.75, @1.0, @1.25, @1.5, @2.0, @3.0];
    double cur = [[DYBPrefs shared] floatFor:DYBKey_defaultSpeed default:1.0];
    NSInteger idx = 1;
    for (NSInteger i = 0; i < vals.count; i++) if (fabs([vals[i] doubleValue] - cur) < 0.01) { idx = i; break; }
    [DYBMenu choose:@"播放倍速" message:@"对当前视频生效（找不到播放器时无效）" options:opts current:idx done:^(NSInteger i) {
        [self applySpeed:[vals[i] doubleValue]];
    }];
}

+ (void)toggleCleanScreen {
    BOOL on = ![DYBBeauty isCleanScreen];
    [DYBBeauty setCleanScreen:on];
    [DYBHUD show:on ? @"清屏：开" : @"清屏：关"];
}

+ (void)openPanel {
    [DYBPanel presentRoot];
}

@end
