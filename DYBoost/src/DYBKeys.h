//
//  DYBKeys.h
//  DYBoost
//
//  所有设置的 key 集中定义。宏展开后形如：extern NSString * const DYBKey_glassTabBar;
//

#ifndef DYBKeys_h
#define DYBKeys_h

#import <Foundation/Foundation.h>

#define DYB_K_EXTERN(name) extern NSString * const DYBKey_##name;

// ---- 总开关 ----
DYB_K_EXTERN(beautyMaster)
DYB_K_EXTERN(enhanceMaster)

// ---- 美化：底栏 / 顶栏 ----
DYB_K_EXTERN(glassTabBar)
DYB_K_EXTERN(tabBarCorner)
DYB_K_EXTERN(hideTabLabels)
DYB_K_EXTERN(glassNavBar)
DYB_K_EXTERN(tintEnabled)
DYB_K_EXTERN(tintHex)
DYB_K_EXTERN(nativeGlass)          // iOS 26+ 尝试用 UIGlassEffect，失败自动回落磨砂
DYB_K_EXTERN(progressStyle)        // 0 原生 1 细线 2 胶囊 3 亮色脉冲
DYB_K_EXTERN(progressHeight)
DYB_K_EXTERN(progressHex)

// ---- 美化：面板 / 悬浮球 ----
DYB_K_EXTERN(panelTheme)           // 0 跟随系统 1 浅色 2 深色
DYB_K_EXTERN(panelCorner)
DYB_K_EXTERN(floatBall)
DYB_K_EXTERN(floatBallSize)
DYB_K_EXTERN(floatBallAlpha)
DYB_K_EXTERN(floatBallAutoHide)
DYB_K_EXTERN(floatBallPosX)        // 0~1 相对屏宽
DYB_K_EXTERN(floatBallPosY)        // 0~1 相对屏高

// ---- 美化：图标 / 背景 ----
DYB_K_EXTERN(iconPack)             // 0 默认 1 极简 2 霓虹 3 自定义图片
DYB_K_EXTERN(customIconB64)
DYB_K_EXTERN(wallpaperB64)

// ---- 隐藏元素 ----
DYB_K_EXTERN(hideAd)
DYB_K_EXTERN(hideLive)
DYB_K_EXTERN(hideShop)
DYB_K_EXTERN(hideSearchBtn)
DYB_K_EXTERN(hideAntiAddict)
DYB_K_EXTERN(hideDanmaku)
DYB_K_EXTERN(hideAIBall)
DYB_K_EXTERN(hideStoryRing)
DYB_K_EXTERN(hideCommentInput)
DYB_K_EXTERN(hideTyping)
DYB_K_EXTERN(hideReadReceipt)
DYB_K_EXTERN(cleanScreen)

// ---- 增强：下载 / 链接 ----
DYB_K_EXTERN(noWatermark)
DYB_K_EXTERN(copyLink)
DYB_K_EXTERN(saveAudio)
DYB_K_EXTERN(saveCover)
DYB_K_EXTERN(saveAlbum)

// ---- 增强：播放 ----
DYB_K_EXTERN(defaultSpeed)         // 1.0 ~ 3.0
DYB_K_EXTERN(longPressSpeed)       // 长按倍速值
DYB_K_EXTERN(tapSeek)              // 点进度条跳转
DYB_K_EXTERN(swipeMode)            // 0 关 1 亮度 2 音量 3 倍速（双指上下滑）
DYB_K_EXTERN(doubleTapAction)      // 0 关 1 面板 2 下载 3 清屏 4 复制直链
DYB_K_EXTERN(longPressMenu)        // 长按出插件菜单
DYB_K_EXTERN(replaceLongPress)     // 拦截抖音原生长按菜单
DYB_K_EXTERN(haptic)

// ---- 增强：信息显示 ----
DYB_K_EXTERN(showFPS)
DYB_K_EXTERN(fpsPosX)
DYB_K_EXTERN(fpsPosY)
DYB_K_EXTERN(showStats)
DYB_K_EXTERN(showLiveDuration)

// ---- AI（接你自己的 OpenAI 兼容接口，密钥只存本机钥匙串）----
DYB_K_EXTERN(aiEnabled)
DYB_K_EXTERN(aiBase)               // 例：https://api.openai.com/v1
DYB_K_EXTERN(aiPath)               // 默认 /chat/completions
DYB_K_EXTERN(aiModel)              // 例：gpt-4o-mini / deepseek-chat
DYB_K_EXTERN(aiTemperature)        // 0 ~ 2
DYB_K_EXTERN(aiMaxTokens)
DYB_K_EXTERN(aiSystem)             // system prompt
DYB_K_EXTERN(aiTplSummary)         // 视频总结模板，占位符 {desc} {author} {comments}
DYB_K_EXTERN(aiTplComments)        // 评论总结模板
DYB_K_EXTERN(aiTplReply)           // 评论回复模板，占位符 {comment}
DYB_K_EXTERN(aiTplTranslate)       // 翻译模板，占位符 {text}
DYB_K_EXTERN(aiTplCustom)          // 自定义指令模板，占位符 {command} {context}
DYB_K_EXTERN(aiAutoCopy)           // 结果自动复制到剪贴板

// ---- 其它 ----
DYB_K_EXTERN(hiddenFriends)        // 数组，NSString 用户 ID
DYB_K_EXTERN(licenseNote)

#endif /* DYBKeys_h */
