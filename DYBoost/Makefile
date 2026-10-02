# DYBoost - 抖音功能增强 & 界面美化插件 (iOS dylib, Theos)
#
# 编译前置：macOS + Theos(https://theos.dev) + Xcode(iOS SDK)
# 没有 Mac？用 GitHub Actions：`.github/workflows/build-deb.yml`，push 上去自动出 deb。
#
# 三种产物布局（都用同一个 dylib，只是 deb 里的路径不同）：
#   make package SCHEME=rootless     -> /var/jb/...      无根越狱(Dopamine/Serotonin/...)
#   make package SCHEME=roothide     -> .jbroot/...      roothide 越狱
#   make package SCHEME=trollstore   -> 只放 dylib      巨魔注入器(TrollFools) 用这个
#
# 巨魔注入器其实只需要一个 .dylib，deb 只是个容器；SCHEME=trollstore 出的 deb 最干净。

ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

SCHEME ?= rootless
THEOS_PACKAGE_SCHEME ?= $(SCHEME)

INSTALL_TARGET_PROCESSES = Aweme

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DYBoost

DYBoost_FILES = Tweak.xm $(wildcard src/*.m)
DYBoost_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-property-ivar -Wno-incomplete-implementation
DYBoost_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore AVFoundation AVKit Photos MediaPlayer SafariServices UniformTypeIdentifiers WebKit Security
# 关键：不链 -lsubstrate。全部 hook 走 libobjc runtime，TrollStore 无 Substrate 也能跑。
DYBoost_LDFLAGS =
DYBoost_LOGOSFLAGS = -c warnings=none

include $(THEOS_MAKE_PATH)/tweak.mk

# 自建 deb（不依赖 dpkg-deb，Windows / CI 都能跑）
pack:
	@python3 tools/pack_deb.py --scheme $(SCHEME)
