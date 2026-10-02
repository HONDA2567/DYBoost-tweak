//
//  DYBMenu.h
//  DYBoost
//
//  任意位置弹原生菜单（自建透明 window 作为 presenting VC）
//

#import <UIKit/UIKit.h>

@interface DYBMenu : NSObject

/// 选择一项（current 为当前选中索引，done 传回索引；取消不回调）
+ (void)choose:(NSString *)title
       message:(NSString *)message
       options:(NSArray<NSString *> *)options
       current:(NSInteger)current
          done:(void (^)(NSInteger index))done;

/// 一组动作按钮：@[@{@"title":..., @"style":@(0|1|2), @"action":block}]
+ (void)sheet:(NSString *)title
      message:(NSString *)message
      actions:(NSArray<NSDictionary *> *)actions;

/// 文本输入
+ (void)input:(NSString *)title
      message:(NSString *)message
         text:(NSString *)text
  placeholder:(NSString *)placeholder
         done:(void (^)(NSString *text))done;

@end
