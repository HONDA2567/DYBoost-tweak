//
//  DYBMedia.m
//  DYBoost
//

#import "DYBMedia.h"
#import "DYBHUD.h"
#import "DYBHookKit.h"
#import <Photos/Photos.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#pragma mark - 下载器

@interface DYBMedia (Private)
+ (NSString *)guessExt:(NSString *)u kind:(DYBMediaKind)kind;
@end

@interface DYBDownloader : NSObject <NSURLSessionDownloadDelegate>
@property (nonatomic, copy) void (^progress)(double p);
@property (nonatomic, copy) void (^done)(NSURL *file, NSError *error);
@property (nonatomic, strong) NSURLSession *session;
+ (instancetype)start:(NSURL *)url progress:(void (^)(double p))p done:(void (^)(NSURL *file, NSError *e))d;
@end

@implementation DYBDownloader

+ (instancetype)start:(NSURL *)url progress:(void (^)(double))p done:(void (^)(NSURL *, NSError *))d {
    DYBDownloader *o = [DYBDownloader new];
    o.progress = p;
    o.done = d;
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    cfg.timeoutIntervalForRequest = 30;
    cfg.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148" forHTTPHeaderField:@"User-Agent"];
    [req setValue:url.absoluteString forHTTPHeaderField:@"Referer"];
    o.session = [NSURLSession sessionWithConfiguration:cfg delegate:o delegateQueue:nil];
    [[o.session downloadTaskWithRequest:req] resume];
    return o;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)t
      didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)total totalBytesExpectedToWrite:(int64_t)expected {
    if (expected <= 0) return;
    DYBAsyncMain(^{ if (self.progress) self.progress((double)total / (double)expected); });
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)t
didFinishDownloadingToURL:(NSURL *)location {
    NSString *ext = [DYBMedia guessExt:t.originalRequest.URL.absoluteString kind:DYBMediaKindVideo];
    NSString *name = [NSString stringWithFormat:@"DYB_%lld%@", (long long)([[NSDate date] timeIntervalSince1970] * 1000), ext];
    NSURL *dst = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
    [[NSFileManager defaultManager] removeItemAtURL:dst error:nil];
    NSError *err = nil;
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:dst error:&err];
    DYBAsyncMain(^{ if (self.done) self.done(err ? nil : dst, err); });
    [session invalidateAndCancel];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)t didCompleteWithError:(NSError *)error {
    if (error && error.code != NSURLErrorCancelled) {
        DYBAsyncMain(^{ if (self.done) self.done(nil, error); });
    }
    [session invalidateAndCancel];
}

@end

#pragma mark - 主实现

@implementation DYBMedia

static NSMutableArray<DYBDownloader *> *gKeep;

+ (void)load { gKeep = [NSMutableArray array]; }

#pragma mark 判定

+ (BOOL)isVideoURL:(NSString *)u {
    if (![u isKindOfClass:NSString.class] || u.length < 10) return NO;
    NSString *l = u.lowercaseString;
    if (![l hasPrefix:@"http"]) return NO;
    return ([l containsString:@"playwm"] || [l containsString:@"/play/"] || [l containsString:@"video_id="]
            || [l hasSuffix:@".mp4"] || [l hasSuffix:@".mov"] || [l containsString:@".m3u8"]
            || ([l containsString:@"douyinvod"] && ![l containsString:@"image"]));
}

+ (BOOL)isImageURL:(NSString *)u {
    if (![u isKindOfClass:NSString.class] || u.length < 10) return NO;
    NSString *l = u.lowercaseString;
    if (![l hasPrefix:@"http"]) return NO;
    if ([l containsString:@"avatar"] || [l containsString:@"user_profile"]) return NO;
    return ([l containsString:@"douyinpic"] || [l containsString:@"toutiaostatic"] || [l containsString:@"ixigua"]
            || [l hasSuffix:@".jpeg"] || [l hasSuffix:@".jpg"] || [l hasSuffix:@".png"]
            || [l hasSuffix:@".webp"] || [l hasSuffix:@".heic"] || [l containsString:@"tplv-"]);
}

+ (BOOL)isAudioURL:(NSString *)u {
    if (![u isKindOfClass:NSString.class] || u.length < 10) return NO;
    NSString *l = u.lowercaseString;
    if (![l hasPrefix:@"http"]) return NO;
    return ([l hasSuffix:@".mp3"] || [l hasSuffix:@".m4a"] || [l hasSuffix:@".aac"]
            || [l containsString:@"/music/"] || [l containsString:@"douyinmusic"]);
}

+ (NSString *)noWatermark:(NSString *)u {
    if (![u isKindOfClass:NSString.class] || u.length == 0) return u;
    NSMutableString *m = u.mutableCopy;
    [m replaceOccurrencesOfString:@"playwm" withString:@"play" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"&watermark=1" withString:@"" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"?watermark=1&" withString:@"?" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"&watermark=2" withString:@"" options:0 range:NSMakeRange(0, m.length)];
    return m.copy;
}

+ (NSString *)guessExt:(NSString *)u kind:(DYBMediaKind)kind {
    NSString *l = (u ?: @"" ).lowercaseString;
    if ([l containsString:@".mp4"]) return @".mp4";
    if ([l containsString:@".mov"]) return @".mov";
    if ([l containsString:@".m3u8"]) return @".m3u8";
    if ([l containsString:@".mp3"]) return @".mp3";
    if ([l containsString:@".m4a"]) return @".m4a";
    if ([l containsString:@".jpeg"] || [l containsString:@".jpg"]) return @".jpg";
    if ([l containsString:@".png"]) return @".png";
    if ([l containsString:@".webp"]) return @".webp";
    if ([l containsString:@".heic"]) return @".heic";
    switch (kind) {
        case DYBMediaKindImage: return @".jpg";
        case DYBMediaKindAudio: return @".m4a";
        default: return @".mp4";
    }
}

+ (NSString *)awemeIDFromText:(NSString *)text {
    if (![text isKindOfClass:NSString.class] || text.length == 0) return nil;
    // /video/1234567890/ 或 /slide/xxx/ 或 note/xxx
    NSArray *pats = @[@"/video/(\\d+)", @"/note/(\\d+)", @"/slide/(\\d+)", @"item_ids=(\\d+)", @"\\bmod_id=(\\d+)", @"^\\s*(\\d{6,25})\\s*$"];
    for (NSString *pat in pats) {
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pat options:0 error:nil];
        NSTextCheckingResult *r = [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
        if (r && r.numberOfRanges > 1) return [text substringWithRange:[r rangeAtIndex:1]];
    }
    return nil;
}

#pragma mark 解析

+ (void)resolveItem:(NSString *)awemeID completion:(void (^)(NSDictionary *, NSError *))c {
    if (awemeID.length == 0) { if (c) c(@{}, [NSError errorWithDomain:@"DYB" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"没有作品 ID"}]); return; }
    NSString *api = [NSString stringWithFormat:@"https://www.iesdouyin.com/web/api/v2/aweme/iteminfo/?item_ids=%@", awemeID];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:api]];
    [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148" forHTTPHeaderField:@"User-Agent"];
    req.timeoutInterval = 20;
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err || data.length == 0) { if (c) c(@{}, err ?: [NSError errorWithDomain:@"DYB" code:-2 userInfo:@{NSLocalizedDescriptionKey:@"接口无返回"}]); return; }
        NSError *je = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&je];
        NSArray *list = json[@"item_list"];
        if (je || ![list isKindOfClass:NSArray.class] || list.count == 0) {
            if (c) c(@{}, [NSError errorWithDomain:@"DYB" code:-3 userInfo:@{NSLocalizedDescriptionKey:@"解析失败"}]);
            return;
        }
        NSDictionary *item = list.firstObject;
        NSMutableArray *videos = [NSMutableArray array];
        NSArray *vl = item[@"video"][@"play_addr"][@"url_list"];
        if ([vl isKindOfClass:NSArray.class]) for (id s in vl) if ([s isKindOfClass:NSString.class]) [videos addObject:[self noWatermark:s]];
        NSArray *dwl = item[@"video"][@"download_addr"][@"url_list"];
        if ([dwl isKindOfClass:NSArray.class]) for (id s in dwl) if ([s isKindOfClass:NSString.class]) [videos addObject:[self noWatermark:s]];
        NSMutableArray *imgs = [NSMutableArray array];
        NSArray *il = item[@"images"];
        if ([il isKindOfClass:NSArray.class]) {
            for (NSDictionary *im in il) {
                NSArray *ul = im[@"url_list"];
                if ([ul isKindOfClass:NSArray.class] && ul.count) {
                    id first = ul.firstObject;
                    if ([first isKindOfClass:NSString.class]) [imgs addObject:first];
                }
            }
        }
        NSString *audio = nil;
        NSArray *al = item[@"music"][@"play_url"][@"url_list"];
        if ([al isKindOfClass:NSArray.class] && al.count && [al.firstObject isKindOfClass:NSString.class]) audio = al.firstObject;
        NSString *cover = nil;
        NSArray *cl = item[@"video"][@"cover"][@"url_list"] ?: item[@"video"][@"origin_cover"][@"url_list"];
        if ([cl isKindOfClass:NSArray.class] && cl.count && [cl.firstObject isKindOfClass:NSString.class]) cover = cl.firstObject;
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        out[@"awemeID"] = awemeID;
        out[@"videoURLs"] = videos;
        out[@"imageURLs"] = imgs;
        if (audio) out[@"audioURL"] = audio;
        if (cover) out[@"coverURL"] = cover;
        out[@"desc"] = item[@"desc"] ?: @"";
        out[@"author"] = item[@"author"][@"nickname"] ?: @"";
        if (c) c(out, nil);
    }] resume];
}

#pragma mark 下载

+ (void)download:(NSString *)urlString progress:(void (^)(double))progress completion:(void (^)(NSURL *, NSError *))c {
    NSURL *u = [NSURL URLWithString:urlString];
    if (!u) { if (c) c(nil, [NSError errorWithDomain:@"DYB" code:-4 userInfo:@{NSLocalizedDescriptionKey:@"链接无效"}]); return; }
    DYBDownloader *d = [DYBDownloader start:u progress:progress done:^(NSURL *file, NSError *e) {
        [gKeep removeObject:d];
        if (c) c(file, e);
    }];
    if (d) [gKeep addObject:d];
}

#pragma mark 保存

+ (BOOL)canWriteAlbum {
    NSString *desc = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSPhotoLibraryAddUsageDescription"];
    NSString *desc2 = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSPhotoLibraryUsageDescription"];
    return (desc.length > 0 || desc2.length > 0);
}

+ (void)saveVideo:(NSURL *)file completion:(void (^)(BOOL, NSError *))c {
    if (![self canWriteAlbum]) {
        if (c) c(NO, [NSError errorWithDomain:@"DYB" code:-5 userInfo:@{NSLocalizedDescriptionKey:@"宿主未声明相册权限，已改用文件导出"}]);
        return;
    }
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus st) {
        if (st != PHAuthorizationStatusAuthorized && st != PHAuthorizationStatusLimited) {
            if (c) c(NO, [NSError errorWithDomain:@"DYB" code:-6 userInfo:@{NSLocalizedDescriptionKey:@"没有相册权限"}]);
            return;
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCreationRequest *r = [PHAssetCreationRequest creationRequestForAsset];
            [r addResourceWithType:PHAssetResourceTypeVideo fileURL:file options:nil];
        } completionHandler:^(BOOL success, NSError *error) {
            DYBAsyncMain(^{ if (c) c(success, error); });
        }];
    }];
}

+ (void)saveImageData:(NSData *)data completion:(void (^)(BOOL, NSError *))c {
    if (![self canWriteAlbum]) {
        if (c) c(NO, [NSError errorWithDomain:@"DYB" code:-5 userInfo:@{NSLocalizedDescriptionKey:@"宿主未声明相册权限"}]);
        return;
    }
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus st) {
        if (st != PHAuthorizationStatusAuthorized && st != PHAuthorizationStatusLimited) {
            if (c) c(NO, [NSError errorWithDomain:@"DYB" code:-6 userInfo:@{NSLocalizedDescriptionKey:@"没有相册权限"}]);
            return;
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCreationRequest *r = [PHAssetCreationRequest creationRequestForAsset];
            [r addResourceWithType:PHAssetResourceTypePhoto data:data options:nil];
        } completionHandler:^(BOOL success, NSError *error) {
            DYBAsyncMain(^{ if (c) c(success, error); });
        }];
    }];
}

+ (void)saveImages:(NSArray<NSString *> *)urls completion:(void (^)(NSInteger, NSInteger))c {
    if (urls.count == 0) { if (c) c(0, 0); return; }
    if (![self canWriteAlbum]) { if (c) c(0, urls.count); return; }
    __block NSInteger ok = 0, fail = 0;
    dispatch_group_t g = dispatch_group_create();
    for (NSString *u in urls) {
        dispatch_group_enter(g);
        NSURL *url = [NSURL URLWithString:u];
        [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
            if (d.length) {
                [self saveImageData:d completion:^(BOOL s, NSError *err) {
                    if (s) ok++; else fail++;
                    dispatch_group_leave(g);
                }];
            } else { fail++; dispatch_group_leave(g); }
        }] resume];
    }
    dispatch_group_notify(g, dispatch_get_main_queue(), ^{ if (c) c(ok, fail); });
}

+ (void)exportFile:(NSURL *)file fromVC:(UIViewController *)vc {
    DYBAsyncMain(^{
        UIViewController *host = vc ?: DYBMostTopViewController();
        if (!host || !file) return;
        UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];
        av.popoverPresentationController.sourceView = host.view;
        av.popoverPresentationController.sourceRect = CGRectMake(host.view.bounds.size.width / 2, host.view.bounds.size.height / 2, 1, 1);
        [host presentViewController:av animated:YES completion:nil];
    });
}

@end
