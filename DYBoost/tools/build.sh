#!/usr/bin/env bash
# build.sh - macOS / Linux(Theos on Linux 需自备 iOS SDK) 一键编译 + 打包
#
#   ./tools/build.sh                # 无根越狱 deb  (/var/jb/...)
#   ./tools/build.sh trollstore     # 巨魔注入器 deb (/Library/...，TrollFools 直接吃)
#   ./tools/build.sh roothide
#
set -euo pipefail

SCHEME="${1:-rootless}"
cd "$(dirname "$0")/.."

export THEOS="${THEOS:-$HOME/theos}"

if [ ! -d "$THEOS" ]; then
  echo "[+] 没找到 Theos，克隆到 $THEOS"
  git clone --recursive --depth 1 https://github.com/theos/theos.git "$THEOS"
fi

echo "[+] 编译 ($SCHEME)"
make clean || true
make -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"

echo "[+] 打包"
python3 tools/pack_deb.py --scheme "$SCHEME"

echo
echo "[+] 完成："
ls -la packages/
