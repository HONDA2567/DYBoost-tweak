#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build.py - 直接编译 DYBoost.dylib，不依赖 Theos。

两条路都走同一套源码：
  · macOS / CI   : xcrun clang（官方 SDK），出 arm64 + arm64e fat dylib
  · Windows / Linux : zig cc（自带 Mach-O 后端），出 arm64 dylib，需要一份 iPhoneOS*.sdk

本 tweak 的 hook 全部走 libobjc runtime，不链 substrate，所以交叉编译没有额外依赖。

用法：
    python3 tools/build.py                          # 自动选编译器
    python3 tools/build.py --min 15.0               # 抬最低系统版本
    python3 tools/build.py --sdk /path/iPhoneOS17.5.sdk   # zig 模式指定 SDK
    python3 tools/build.py --pack trollstore        # 编完直接打 deb + zip（默认）
    python3 tools/build.py --pack none              # 只出 dylib

产出：packages/DYBoost.dylib  (+ 可选 .deb / .zip)
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import os
import platform
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NAME = "DYBoost"
MIN_IOS = "14.0"

FRAMEWORKS = [
    "UIKit", "Foundation", "CoreGraphics", "QuartzCore", "AVFoundation",
    "AVKit", "Photos", "MediaPlayer", "UniformTypeIdentifiers", "Security",
]

COMMON_CFLAGS = [
    "-fobjc-arc",
    "-Wno-deprecated-declarations",
    "-Wno-nullability-completeness",
    "-Wno-unused-property-ivar",
    "-Wno-incomplete-implementation",
    "-Wno-unguarded-availability-new",
    "-Wno-strict-prototypes",
    "-Wno-objc-root-class",
    "-Wno-unknown-warning-option",
]

IS_DARWIN = platform.system() == "Darwin"


# ------------------------------------------------------------------ 工具链

def xcrun_sdk_path() -> str:
    r = subprocess.run(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("[!] xcrun 找不到 iphoneos SDK，先装 Xcode 命令行工具：xcode-select --install")
    return r.stdout.strip()


def find_sdk(explicit: str | None) -> Path | None:
    if explicit:
        p = Path(explicit)
        if not p.is_dir():
            sys.exit(f"[!] SDK 目录不存在: {p}")
        return p
    for base in (ROOT / "tools" / "sdk", ROOT.parent / "case" / "sdk",
                 Path.home() / ".cache" / "ios-sdk"):
        if not base.is_dir():
            continue
        for d in sorted(base.iterdir()):
            if d.is_dir() and d.name.startswith("iPhoneOS") and d.name.endswith(".sdk") \
               and (d / "System" / "Library" / "Frameworks" / "UIKit.framework").is_dir():
                return d
    return None


def cc_prefix(arch: str, sdk: Path | None, min_ios: str) -> list[str]:
    """返回编译器前缀（不含 -c / -o）"""
    if IS_DARWIN:
        return ["xcrun", "--sdk", "iphoneos", "clang",
                "-arch", arch,
                f"-miphoneos-version-min={min_ios}",
                "-isysroot", xcrun_sdk_path()]
    if not shutil.which("zig"):
        sys.exit("[!] 没装 zig。Windows 上装：winget install zig.zig")
    return ["zig", "cc",
            "-target", f"aarch64-ios.{min_ios}",
            "-isysroot", str(sdk),
            "-F", str(sdk / "System" / "Library" / "Frameworks"),
            "-I", str(sdk / "usr" / "include")]


def link_prefix(arch: str, sdk: Path | None, min_ios: str) -> list[str]:
    p = cc_prefix(arch, sdk, min_ios)
    if not IS_DARWIN:
        p += ["-L", str(sdk / "usr" / "lib")]
    return p


def default_archs() -> list[str]:
    # arm64e 只有 Apple 官方 clang 能编（PAC / ptrauth ABI），zig 不出
    return ["arm64", "arm64e"] if IS_DARWIN else ["arm64"]


# ------------------------------------------------------------------ 编译

def sources() -> list[Path]:
    files = sorted((ROOT / "src").glob("*.m"))
    xm = ROOT / "Tweak.xm"
    if xm.exists():
        files.append(xm)
    if not files:
        sys.exit("[!] src/ 下没有 .m")
    return files


def compile_one(job) -> tuple[bool, str, str]:
    src, obj, prefix, extra = job
    # .xm 后缀 zig 的 driver 不认（会当成 linker input 静默跳过，产出 0 字节 .o），
    # 复制成 .m 再编最稳
    real = src
    if src.suffix == ".xm":
        real = obj.parent / (src.stem + ".m")
        shutil.copy2(src, real)
    cmd = [*prefix, "-I", str(ROOT / "src"), *COMMON_CFLAGS, *extra,
           "-c", str(real), "-o", str(obj)]
    t0 = time.time()
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    dt = time.time() - t0
    # 编译失败时 zig 也会留下 0 字节 .o，下次靠 mtime 判断会被当成最新，链接阶段才炸
    if r.returncode != 0 and obj.exists() and obj.stat().st_size == 0:
        obj.unlink()
    out = (r.stderr or "") + (r.stdout or "")
    keep = [l for l in out.splitlines()
            if "error:" in l or ("warning:" in l and not any(
                k in l for k in ("nullability", "unguarded", "root class", "msgsend")))]
    msg = "\n".join(keep[:30])
    print(f"[{'OK ' if r.returncode == 0 else 'ERR'}] {src.name:22s} {dt:5.1f}s", flush=True)
    if msg:
        print(msg, flush=True)
    return r.returncode == 0, src.name, msg


def build_arch(arch: str, sdk: Path | None, min_ios: str, jobs: int,
               install_name: str = "@rpath/DYBoost.dylib",
               extra: list[str] | None = None,
               variant: str = "") -> Path:
    extra = extra or []
    # 不同 variant 必须分开，否则 -D 变了 .o 缓存却不失效
    objdir = ROOT / f".objs-{arch}{variant}"
    objdir.mkdir(exist_ok=True)
    srcs = sources()
    prefix = cc_prefix(arch, sdk, min_ios)
    todo = []
    for s in srcs:
        o = objdir / (s.stem + ".o")
        if not o.exists() or s.stat().st_mtime > o.stat().st_mtime:
            todo.append((s, o, prefix, extra))
    print(f"[+] {arch}: {len(srcs)} 个源文件，需编译 {len(todo)} 个", flush=True)

    fails = []
    if todo:
        with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
            for ok, name, msg in ex.map(compile_one, todo):
                if not ok:
                    fails.append(name)
    if fails:
        sys.exit(f"[!] {arch} 编译失败: {fails}")

    objs = [objdir / (s.stem + ".o") for s in srcs]
    missing = [o.name for o in objs if not o.exists()]
    if missing:
        sys.exit(f"[!] 缺目标文件: {missing}")

    out = ROOT / f".{NAME}.{arch}{variant}.dylib"
    fw: list[str] = []
    sysroot = Path(xcrun_sdk_path()) if IS_DARWIN else sdk
    for f in FRAMEWORKS:
        if sysroot and not (sysroot / "System" / "Library" / "Frameworks" / f"{f}.framework").is_dir():
            print(f"[~] 跳过缺失的 framework: {f}")
            continue
        fw += ["-framework", f]
    cmd = [*link_prefix(arch, sdk, min_ios),
           "-dynamiclib", "-fobjc-arc", *fw, "-lobjc",
           f"-Wl,-install_name,{install_name}",
           "-Wl,-undefined,dynamic_lookup",
           "-o", str(out), *[str(o) for o in objs]]
    print(f"[+] {arch}: 链接 ...", flush=True)
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    log = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0:
        print(log[-8000:])
        sys.exit(f"[!] {arch} 链接失败")
    warn = [l for l in log.splitlines() if "warning:" in l and "nullability" not in l]
    if warn:
        print("\n".join(warn[:15]))
    print(f"[+] {arch}: {out} ({out.stat().st_size} bytes)")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="编译 DYBoost.dylib（macOS 用 xcrun / 其它用 zig）")
    ap.add_argument("--arch", default=None, help="逗号分隔，默认 darwin=arm64,arm64e 其它=arm64")
    ap.add_argument("--min", default=MIN_IOS, help="最低 iOS 版本")
    ap.add_argument("--sdk", default=None, help="zig 模式下的 iPhoneOS*.sdk 目录")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 4)
    ap.add_argument("--out", default="packages")
    ap.add_argument("--pack", default="trollstore",
                    choices=["trollstore", "rootless", "roothide", "rootful", "none"])
    ap.add_argument("--format", default="all", choices=["deb", "zip", "all"])
    ap.add_argument("--install-name", default="@rpath/DYBoost.dylib",
                    help="LC_ID_DYLIB。宿主 rpath 找不到时用 "
                         "@executable_path/Frameworks/DYBoost.dylib")
    ap.add_argument("--suffix", default="", help="输出文件名后缀，用来同时出多个版本")
    ap.add_argument("--stage-default", type=int, default=2, choices=[1, 2],
                    help="默认启动等级：1 = 只挂悬浮球+手势（lite，最不容易出事），2 = 完整")
    ap.add_argument("--probe", action="store_true",
                    help="探针版：dylib 只写一条日志证明加载成功，不挂任何 hook（用来判断"
                         "闪退是注入/签名问题还是代码问题）")
    args = ap.parse_args()

    sdk = None if IS_DARWIN else (find_sdk(args.sdk) or
                                  sys.exit("[!] 没找到 iPhoneOS SDK，用 --sdk 指定"))
    archs = args.arch.split(",") if args.arch else default_archs()
    print(f"[+] 平台   : {platform.system()}  架构: {','.join(archs)}  最低 iOS {args.min}")

    t0 = time.time()
    variant = args.suffix or ""
    extra = [f"-DDYB_DEFAULT_STAGE={args.stage_default}"]
    if args.probe:
        extra.append("-DDYB_PROBE_ONLY=1")
    slices = [build_arch(a, sdk, args.min, args.jobs, args.install_name, extra, variant)
              for a in archs]

    outdir = ROOT / args.out
    outdir.mkdir(exist_ok=True)
    final = outdir / f"{NAME}{args.suffix}.dylib"
    if len(slices) == 1:
        shutil.copy2(slices[0], final)
    else:
        r = subprocess.run(["lipo", "-create", "-output", str(final), *[str(s) for s in slices]],
                           capture_output=True, text=True)
        if r.returncode != 0:
            print(r.stderr)
            sys.exit("[!] lipo 合并失败")
    print(f"[+] 编译耗时 {time.time()-t0:.1f}s")

    # ad-hoc 签名：塞 LC_CODE_SIGNATURE。TrollFools / TrollStore 重签时会覆盖，
    # 但没有这一段的裸 dylib 在某些宿主上会被 amfi 直接拒载。
    if IS_DARWIN and shutil.which("codesign"):
        subprocess.run(["codesign", "-f", "-s", "-", "--timestamp=none", str(final)],
                       capture_output=True, text=True)
        signed = subprocess.run(["codesign", "-dv", str(final)], capture_output=True, text=True)
        print(f"[+] 签名   : {'ad-hoc OK' if signed.returncode == 0 else '失败（可忽略）'}")

    data = final.read_bytes()
    print(f"[+] 产出   : {final}  ({len(data)} bytes)")
    print(f"[+] magic  : {data[:4].hex()}   (cf fa ed fe = Mach-O 64-bit)")
    if shutil.which("lipo"):
        lip = subprocess.run(["lipo", "-info", str(final)], capture_output=True, text=True)
        if lip.returncode == 0:
            print(f"[+] archs  : {lip.stdout.strip()}")
    else:
        import struct
        magic, cputype, cpusub = struct.unpack_from("<Iii", data, 0)
        print(f"[+] archs  : cputype={cputype:#x} cpusubtype={cpusub:#x} "
              f"(0x100000c/0x0=arm64, 0x100000c/0x2=arm64e)")

    if args.pack != "none":
        rc = subprocess.run([sys.executable, str(ROOT / "tools" / "pack_deb.py"),
                             "--dylib", str(final), "--scheme", args.pack,
                             "--out", str(outdir), "--format", args.format],
                            cwd=str(ROOT)).returncode
        if rc != 0:
            sys.exit("[!] 打包失败")
    print("[+] 完成")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
