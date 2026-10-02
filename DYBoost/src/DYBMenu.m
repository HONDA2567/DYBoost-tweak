//
//  DYBMenu.m
//  DYBoost
//

#import "DYBMenu.h"
#import "DYBHookKit.h"
#import "DYBTheme.h"

static NSMutableArray<UIWindow *> *gHosts;

@implementation DYBMenu

+ (void)load { gHosts = [NSMutableArray array]; }

+ (UIViewController *)hostFor:(UIWindow **)outWin {
    UIWindow *w;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = (UIWindowScene *)DYBKeyWindow().windowScene;
        w = scene ? [[UIWindow alloc] initWithWindowScene:scene] : [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        if (!scene) w.frame = UIScreen.mainScreen.bounds;
    } else {
        w = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }
    w.frame = UIScreen.mainScreen.bounds;
    w.windowLevel = UIWindowLevelAlert + 20;
    w.backgroundColor = UIColor.clearColor;
    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = UIColor.clearColor;
    w.rootViewController = root;
    w.hidden = NO;
    [gHosts addObject:w];
    if (outWin) *outWin = w;
    return root;
}

+ (void)releaseLater:(UIWindow *)w {
    DYBAsyncMainAfter(0.6, ^{
        w.hidden = YES;
        w.rootViewController = nil;
        [gHosts removeObject:w];
    });
}

+ (void)present:(UIAlertController *)alert {
    DYBAsyncMain(^{
        UIWindow *w = nil;
        UIViewController *root = [self hostFor:&w];
        alert.popoverPresentationController.sourceView = root.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(root.view.bounds.size.width / 2, root.view.bounds.size.height / 2, 1, 1);
        [root presentViewController:alert animated:YES completion:nil];
        [self releaseLater:w];
    });
}

+ (void)sheet:(NSString *)title message:(NSString *)message actions:(NSArray<NSDictionary *> *)actions {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title
                                                               message:message
                                                        preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *a in actions) {
        NSInteger st = [a[@"style"] integerValue];
        UIAlertAction *act = [UIAlertAction actionWithTitle:a[@"title"]
                                                     style:(UIAlertActionStyle)st
                                                   handler:^(UIAlertAction *x) {
            void (^blk)(void) = a[@"action"];
            if (blk) blk();
        }];
        [ac addAction:act];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

+ (void)choose:(NSString *)title message:(NSString *)message options:(NSArray<NSString *> *)options current:(NSInteger)current done:(void (^)(NSInteger))done {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title
                                                               message:message
                                                        preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSInteger i = 0; i < options.count; i++) {
        NSString *t = options[i];
        if (i == current) t = [NSString stringWithFormat:@"✓ %@", t];
        [ac addAction:[UIAlertAction actionWithTitle:t style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            if (done) done(i);
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

+ (void)input:(NSString *)title message:(NSString *)message text:(NSString *)text placeholder:(NSString *)placeholder done:(void (^)(NSString *))done {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title
                                                               message:message
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = text ?: @"";
        tf.placeholder = placeholder ?: @"";
        tf.keyboardAppearance = [DYBTheme keyboard];
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        NSString *v = ac.textFields.firstObject.text;
        if (done) done(v);
    }]];
    [self present:ac];
}

@end
