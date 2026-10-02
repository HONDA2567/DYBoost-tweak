//
//  DYBAweme.m
//  DYBoost
//

#import "DYBAweme.h"
#import "DYBMedia.h"
#import "DYBHookKit.h"

static __weak id gRawModel;
static DYBAweme *gParsed;
static NSValue *gParsedKey;

@implementation DYBAweme

+ (instancetype)parse:(id)model {
    if (!model) return nil;
    DYBAweme *a = [DYBAweme new];

    // --- 基础字段 ---
    id v = DYBPick(model, @[@"awemeID", @"awemeId", @"aweme_id", @"itemID", @"itemId", @"groupID", @"gid", @"awemeIdStr"]);
    a.awemeID = [v isKindOfClass:NSString.class] ? v : ([v respondsToSelector:@selector(stringValue)] ? [v stringValue] : nil);

    id d = DYBPick(model, @[@"desc", @"text", @"title", @"content", @"caption"]);
    a.desc = [d isKindOfClass:NSString.class] ? d : nil;

    id author = DYBPick(model, @[@"author", @"user", @"authorUser", @"userInfo"]);
    id nick = DYBPick(author, @[@"nickname", @"nickName", @"name", @"displayName"]);
    a.authorName = [nick isKindOfClass:NSString.class] ? nick : nil;
    id uid = DYBPick(author, @[@"uid", @"userID", @"userId", @"secUid", @"shortId"]);
    a.authorUID = [uid isKindOfClass:NSString.class] ? uid : ([uid respondsToSelector:@selector(stringValue)] ? [uid stringValue] : nil);

    // --- 广告 / 图集 ---
    id ad = DYBPick(model, @[@"isAd", @"isAdvertise", @"isAds", @"ad"]);
    a.isAd = [ad respondsToSelector:@selector(boolValue)] && [ad boolValue];

    id images = DYBPick(model, @[@"images", @"imageList", @"imageInfos", @"albumImages"]);
    NSMutableArray<NSString *> *imgs = [NSMutableArray array];
    if ([images isKindOfClass:NSArray.class]) {
        for (id im in (NSArray *)images) {
            NSArray<NSString *> *found = [self urlsIn:im];
            for (NSString *s in found) if ([DYBMedia isImageURL:s] && ![imgs containsObject:s]) [imgs addObject:s];
        }
    }
    if (imgs.count == 0) {
        for (NSString *s in DYBCollectStrings(model, 5)) {
            if ([DYBMedia isImageURL:s] && ![imgs containsObject:s]) [imgs addObject:s];
        }
    }
    a.imageURLs = imgs;
    a.isImagePost = imgs.count > 0;

    // --- 视频直链 ---
    id video = DYBPick(model, @[@"video", @"videoModel", @"awemeVideo"]);
    NSMutableArray<NSString *> *videos = [NSMutableArray array];
    for (NSString *key in @[@"playAddr", @"play_addr", @"downloadAddr", @"download_addr", @"h264PlayAddr",
                            @"playApi", @"playURL", @"urlList", @"url_list", @"playAddrRaw"]) {
        id o = DYBSafeGet(video, key);
        if (!o) continue;
        NSArray<NSString *> *found = [self urlsIn:o];
        for (NSString *s in found) {
            NSString *nw = [DYBMedia noWatermark:s];
            if ([DYBMedia isVideoURL:nw] && ![videos containsObject:nw]) [videos addObject:nw];
        }
    }
    if (videos.count == 0) {
        for (NSString *s in DYBCollectStrings(video ?: model, 6)) {
            NSString *nw = [DYBMedia noWatermark:s];
            if ([DYBMedia isVideoURL:nw] && ![videos containsObject:nw]) [videos addObject:nw];
        }
    }
    // 评分排序：download 直链优先，其次 play（非 wm）
    [videos sortUsingComparator:^NSComparisonResult(NSString *a1, NSString *b1) {
        NSInteger sa = [a1 containsString:@"download"] ? 2 : ([a1 containsString:@"playwm"] ? 0 : 1);
        NSInteger sb = [b1 containsString:@"download"] ? 2 : ([b1 containsString:@"playwm"] ? 0 : 1);
        return sa < sb ? NSOrderedDescending : (sa == sb ? NSOrderedSame : NSOrderedAscending);
    }];
    a.videoURLs = videos;

    NSNumber *dur = DYBPick(video, @[@"duration", @"videoDuration", @"durationMs"]);
    a.duration = [dur respondsToSelector:@selector(doubleValue)] ? dur : nil;

    // --- 封面 ---
    id cover = DYBPick(model, @[@"cover", @"coverURL", @"originCover", @"staticCover", @"poster"]);
    NSArray<NSString *> *cv = [self urlsIn:cover];
    for (NSString *s in cv) { if ([DYBMedia isImageURL:s]) { a.coverURL = s; break; } }

    // --- 音频 ---
    id music = DYBPick(model, @[@"music", @"musicModel"]);
    NSMutableArray<NSString *> *aud = [NSMutableArray array];
    for (NSString *key in @[@"playUrl", @"play_url", @"downloadUrl", @"urlList", @"url_list"]) {
        NSArray<NSString *> *found = [self urlsIn:DYBSafeGet(music, key)];
        for (NSString *s in found) if ([DYBMedia isAudioURL:s] && ![aud containsObject:s]) [aud addObject:s];
    }
    if (aud.count == 0) {
        for (NSString *s in DYBCollectStrings(music, 4)) if ([DYBMedia isAudioURL:s]) [aud addObject:s];
    }
    a.audioURLs = aud;

    // --- 统计数据 ---
    id stat = DYBPick(model, @[@"statistics", @"stats", @"awemeStatistics", @"interaction", @"statsInfo"]);
    a.diggCount    = [self numIn:stat keys:@[@"diggCount", @"digg_count", @"likeCount", @"praiseCount"]] ?: [self numIn:model keys:@[@"diggCount", @"likeCount"]];
    a.commentCount = [self numIn:stat keys:@[@"commentCount", @"comment_count"]] ?: [self numIn:model keys:@[@"commentCount"]];
    a.collectCount = [self numIn:stat keys:@[@"collectCount", @"collect_count", @"favoriteCount"]] ?: [self numIn:model keys:@[@"collectCount"]];
    a.shareCount   = [self numIn:stat keys:@[@"shareCount", @"share_count"]] ?: [self numIn:model keys:@[@"shareCount"]];
    a.playCount    = [self numIn:stat keys:@[@"playCount", @"play_count", @"vvCount"]] ?: [self numIn:model keys:@[@"playCount"]];

    return a;
}

#pragma mark 辅助

/// 从任意对象/数组/字典里抓 URL 字符串
+ (NSArray<NSString *> *)urlsIn:(id)obj {
    if (!obj) return @[];
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    if ([obj isKindOfClass:NSString.class]) {
        if ([(NSString *)obj hasPrefix:@"http"]) [out addObject:obj];
        return out;
    }
    if ([obj isKindOfClass:NSArray.class]) {
        for (id e in (NSArray *)obj) {
            if ([e isKindOfClass:NSString.class] && [e hasPrefix:@"http"]) [out addObject:e];
            else {
                for (NSString *s in [self urlsIn:e]) if (![out containsObject:s]) [out addObject:s];
            }
        }
        return out;
    }
    if ([obj isKindOfClass:NSDictionary.class]) {
        for (id e in [(NSDictionary *)obj allValues]) {
            for (NSString *s in [self urlsIn:e]) if (![out containsObject:s]) [out addObject:s];
        }
        return out;
    }
    for (NSString *s in DYBCollectStrings(obj, 3)) {
        if ([s hasPrefix:@"http"]) [out addObject:s];
    }
    return out;
}

+ (NSNumber *)numIn:(id)obj keys:(NSArray<NSString *> *)keys {
    if (!obj) return nil;
    for (NSString *k in keys) {
        id v = DYBSafeGet(obj, k);
        if ([v respondsToSelector:@selector(longLongValue)]) return @([v longLongValue]);
    }
    return nil;
}

#pragma mark 当前作品

+ (void)noteModel:(id)model {
    if (!model) return;
    gRawModel = model;
    gParsed = nil;
    gParsedKey = nil;
}

+ (void)rescan {
    // 40.6.0 实测：AWEAwemeModel 与 AWECodeGenAwemeModel 都存在
    id found = DYBFindObject(DYBMostTopViewController(),
                             @[@"AWEAwemeModel", @"AWECodeGenAwemeModel", @"AwemeModel", @"AWEModel"], 6);
    if (found) [self noteModel:found];
}

+ (DYBAweme *)current {
    id m = gRawModel;
    if (!m) {
        [self rescan];
        m = gRawModel;
    }
    if (!m) return nil;
    NSValue *k = [NSValue valueWithPointer:(__bridge const void *)m];
    if (gParsed && gParsedKey && [gParsedKey isEqualToValue:k]) return gParsed;
    DYBAweme *a = [self parse:m];
    gParsed = a;
    gParsedKey = k;
    return a;
}

@end
