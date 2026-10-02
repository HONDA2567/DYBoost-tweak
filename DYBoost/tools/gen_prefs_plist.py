#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_prefs_plist.py - 生成 PreferenceLoader 的 entry.plist（设置 App 里那一份）

不用手写 60 个 specifier，改这张表后重跑即可：
    python3 tools/gen_prefs_plist.py

输出：layout/Library/PreferenceLoader/Preferences/DYBoost.plist
（Theos 的 layout/ 会被自动 stage；rootless 下自动落到 /var/jb/...）

注意：偏好 Bundle 只在**越狱**设备生效（要在设置 App 里注入）。
巨魔注入器是往 App 里塞 dylib，设置 App 不会有入口，DYBoost 的内置面板照常用。
"""

import os
from xml.sax.saxutils import escape

SUITE = "com.seagull.dyboost"
NOTIFY = "com.seagull.dyboost.prefs"
P = "DYB."     # key 前缀，和 DYBKeys.h 里的宏一致

SW = "PSSwitchCell"
GROUP = "PSGroupCell"
EDIT = "PSEditTextCell"
SECURE = "PSSecureEditTextCell"
SLIDER = "PSSliderCell"
LIST = "PSLinkListCell"

# (section, label, cell, key, default, extra)
TABLE = [
    ("总开关", None, None, None, None, None),
    (None, "美化总开关", SW, "beautyMaster", True, None),
    (None, "功能增强总开关", SW, "enhanceMaster", True, None),

    ("功能增强", None, None, None, None, None),
    (None, "无水印下载", SW, "noWatermark", True, None),
    (None, "复制无水印直链", SW, "copyLink", True, None),
    (None, "图集一键保存", SW, "saveAlbum", True, None),
    (None, "保存音频", SW, "saveAudio", True, None),
    (None, "保存封面", SW, "saveCover", True, None),
    (None, "点击进度条跳转", SW, "tapSeek", True, None),
    (None, "长按出插件菜单", SW, "longPressMenu", True, None),
    (None, "拦截抖音原生长按菜单", SW, "replaceLongPress", False, None),
    (None, "触感反馈", SW, "haptic", True, None),
    (None, "帧率胶囊", SW, "showFPS", False, None),
    (None, "作品数据", SW, "showStats", False, None),
    (None, "直播时长", SW, "showLiveDuration", False, None),
    (None, "清屏模式", SW, "cleanScreen", False, None),
    (None, "默认倍速", SLIDER, "defaultSpeed", 1.0, {"min": 0.5, "max": 3.0}),
    (None, "长按倍速", SLIDER, "longPressSpeed", 2.0, {"min": 1.0, "max": 3.0}),
    (None, "双指上下滑", LIST, "swipeMode", 0,
     {"validValues": [0, 1, 2, 3], "validTitles": ["关闭", "亮度", "音量", "倍速"]}),
    (None, "双击屏幕动作", LIST, "doubleTapAction", 0,
     {"validValues": [0, 1, 2, 3, 4], "validTitles": ["关闭", "打开面板", "下载视频", "清屏", "复制直链"]}),

    ("界面美化", None, None, None, None, None),
    (None, "底栏玻璃", SW, "glassTabBar", True, None),
    (None, "隐藏底栏文字", SW, "hideTabLabels", False, None),
    (None, "顶栏玻璃", SW, "glassNavBar", False, None),
    (None, "iOS26 原生玻璃", SW, "nativeGlass", True, None),
    (None, "自定义主题色", SW, "tintEnabled", False, None),
    (None, "主题色（#RRGGBB）", EDIT, "tintHex", "#FE2C55", None),
    (None, "底栏圆角", SLIDER, "tabBarCorner", 0.35, {"min": 0.0, "max": 1.0}),
    (None, "进度条样式", LIST, "progressStyle", 0,
     {"validValues": [0, 1, 2, 3], "validTitles": ["原生", "细线", "胶囊", "亮色脉冲"]}),
    (None, "进度条高度（0=跟随）", SLIDER, "progressHeight", 0.0, {"min": 0.0, "max": 12.0}),
    (None, "进度条颜色", EDIT, "progressHex", "#FFFFFF", None),
    (None, "面板明暗", LIST, "panelTheme", 0,
     {"validValues": [0, 1, 2], "validTitles": ["跟随系统", "固定浅色", "固定深色"]}),
    (None, "面板圆角", SLIDER, "panelCorner", 16.0, {"min": 0.0, "max": 32.0}),
    (None, "悬浮球", SW, "floatBall", True, None),
    (None, "悬浮球大小", SLIDER, "floatBallSize", 54.0, {"min": 34.0, "max": 80.0}),
    (None, "悬浮球不透明度", SLIDER, "floatBallAlpha", 0.85, {"min": 0.2, "max": 1.0}),
    (None, "闲置自动淡出", SW, "floatBallAutoHide", True, None),
    (None, "图标包", LIST, "iconPack", 0,
     {"validValues": [0, 1, 2, 3], "validTitles": ["默认", "极简", "霓虹", "自定义图片"]}),

    ("隐藏元素", "依赖类名解析，抖音大版本更新后可能失效", None, None, None, None),
    (None, "广告 / 推广", SW, "hideAd", False, None),
    (None, "直播入口 / 标记", SW, "hideLive", False, None),
    (None, "商城 / 电商锚点", SW, "hideShop", False, None),
    (None, "顶部搜索入口", SW, "hideSearchBtn", False, None),
    (None, "防沉迷提示条", SW, "hideAntiAddict", True, None),
    (None, "弹幕", SW, "hideDanmaku", False, None),
    (None, "搜索 / 键盘 AI 浮钮", SW, "hideAIBall", False, None),
    (None, "头像故事圈", SW, "hideStoryRing", False, None),
    (None, "评论输入框背景", SW, "hideCommentInput", False, None),
    (None, "「正在输入」状态", SW, "hideTyping", False, None),
    (None, "已读回执", SW, "hideReadReceipt", False, None),

    ("AI 助手", "只发到你自己在下面填的接口。API Key 若写不进钥匙串会退化存到配置里", None, None, None, None),
    (None, "启用 AI", SW, "aiEnabled", False, None),
    (None, "接口地址", EDIT, "aiBase", "https://api.openai.com/v1", None),
    (None, "路径", EDIT, "aiPath", "/chat/completions", None),
    (None, "模型名", EDIT, "aiModel", "gpt-4o-mini", None),
    (None, "API Key", SECURE, "ai.key.fallback", "", None),
    (None, "温度", SLIDER, "aiTemperature", 0.7, {"min": 0.0, "max": 2.0}),
    (None, "最大 token", EDIT, "aiMaxTokens", "800", {"keyboard": "numbers"}),
    (None, "结果自动复制", SW, "aiAutoCopy", False, None),

    ("关于", "DYBoost 1.0.0 · 仅供个人学习与自用。滑杆/取色/提示词这类复杂项用 App 内面板（悬浮球长按）。",
     None, None, None, None),
]


def val(v):
    if isinstance(v, bool):
        return "  <true/>\n" if v else "  <false/>\n"
    if isinstance(v, (int, float)):
        return f"  <real>{v}</real>\n" if isinstance(v, float) else f"  <integer>{v}</integer>\n"
    return f"  <string>{escape(str(v))}</string>\n"


def spec(d):
    out = " <dict>\n"
    for k, v in d.items():
        out += f"  <key>{escape(k)}</key>\n" + val(v)
    out += " </dict>\n"
    return out


def main():
    items = []
    for section, label, cell, key, default, extra in TABLE:
        is_section = (cell is None and key is None and default is None)
        if is_section:
            d = {"cell": GROUP, "label": section}
            if label:      # section 行的第 2 个元素当 footerText
                d["footerText"] = label
            items.append(d)
            continue
        d = {"cell": cell, "label": label, "defaults": SUITE, "key": (P + key) if key else ""}
        if cell == SW:
            d["default"] = bool(default)
        elif cell == SLIDER:
            d.update({"min": extra["min"], "max": extra["max"], "showValue": True,
                      "default": default, "isContinuous": True})
        elif cell == LIST:
            d.update({"validValues": extra["validValues"], "validTitles": extra["validTitles"],
                      "default": default, "detail": LIST})
        elif cell in (EDIT, SECURE):
            d["default"] = str(default)
            d["placeholder"] = str(default)
            if extra and extra.get("keyboard"):
                d["keyboard"] = extra["keyboard"]
        d["PostNotification"] = NOTIFY
        items.append(d)

    xml = '<?xml version="1.0" encoding="UTF-8"?>\n'
    xml += '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
    xml += '<plist version="1.0">\n<dict>\n'
    xml += ' <key>title</key>\n  <string>DYBoost</string>\n'
    xml += ' <key>entry</key>\n' + spec({"cell": "PSLinkCell", "label": "DYBoost", "icon": "DYBoost.png"})
    xml += ' <key>items</key>\n <array>\n'
    for i in items:
        xml += spec(i)
    xml += ' </array>\n'
    xml += '</dict>\n</plist>\n'

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir,
                       "layout", "Library", "PreferenceLoader", "Preferences", "DYBoost.plist")
    out = os.path.normpath(out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        f.write(xml)
    print("[+] 写出", out)
    print("[+] specifier 数", len(items))


if __name__ == "__main__":
    main()
