#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
pack_deb.py - 把编译好的 dylib 打成 deb（纯标准库，Windows / macOS / Linux / CI 都能跑）

用法:
    python3 tools/pack_deb.py                          # 自动找 .theos/obj 下的 dylib
    python3 tools/pack_deb.py --scheme trollstore      # 巨魔注入器用
    python3 tools/pack_deb.py --dylib /path/DYBoost.dylib --out dist/
    python3 tools/pack_deb.py --format zip             # 顺便出一个 zip（TrollFools 也吃）

产物路径布局:
    rootless   : /var/jb/Library/MobileSubstrate/DynamicLibraries/
    roothide   : .jbroot/Library/MobileSubstrate/DynamicLibraries/   (相对沙盒根)
    trollstore : /Library/MobileSubstrate/DynamicLibraries/          (标准 deb 布局)
"""

import argparse
import gzip
import io
import os
import shutil
import stat
import sys
import tarfile
import time
import zipfile
from pathlib import Path

PKG_ID = "com.seagull.dyboost"
PKG_NAME = "DYBoost"
VERSION = "1.0-1"
ARCH = "iphoneos-arm64"
MAINTAINER = "seagull"
SECTION = "Tweaks"
DESCRIPTION = "DYBoost - 抖音功能增强 & 界面美化插件（无水印下载/倍速/悬浮球/玻璃美化/AI 助手）"

PREFIX = {
    "rootless":   "/var/jb",
    "roothide":   ".jbroot",
    "trollstore": "",
    "rootful":    "",
}


# ---------------------------------------------------------------- ar

def _ar_header(name: str, size: int, mtime: int) -> bytes:
    return (
        f"{name:<16}"
        f"{mtime:<12}"
        f"{0:<6}"
        f"{0:<6}"
        f"{0o644:<8}"
        f"{size:<10}"
        "`\n"
    ).encode("ascii")


def build_ar(members: "list[tuple[str, bytes]]", mtime: int) -> bytes:
    """members: [(name, data)] -> ar 归档字节（GNU ar 格式）"""
    out = bytearray(b"!<arch>\n")
    for name, data in members:
        out += _ar_header(name, len(data), mtime)
        out += data
        if len(data) % 2:
            out += b"\n"   # ar 要求偶数对齐
    return bytes(out)


# ---------------------------------------------------------------- tar

def _tarinfo(name: str, size: int, mtime: int, mode: int = 0o644) -> tarfile.TarInfo:
    ti = tarfile.TarInfo(name)
    ti.size = size
    ti.mtime = mtime
    ti.mode = mode
    ti.uid = ti.gid = 0
    ti.uname = ti.gname = "root"
    ti.type = tarfile.REGTYPE
    return ti


def build_tar_gz(files: "dict[str, bytes]", mtime: int, dirs: "list[str]" = None) -> bytes:
    """files: {归档内路径(带前导 / 或不带): 字节}"""
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w", format=tarfile.GNU_FORMAT) as tf:
        for d in (dirs or []):
            ti = tarfile.TarInfo(d)
            ti.type = tarfile.DIRTYPE
            ti.mode = 0o755
            ti.mtime = mtime
            ti.uid = ti.gid = 0
            ti.uname = ti.gname = "root"
            tf.addfile(ti)
        for arc_name, data in files.items():
            tf.addfile(_tarinfo(arc_name, len(data), mtime, 0o755 if arc_name.endswith(".dylib") else 0o644),
                       io.BytesIO(data))
    return gzip.compress(buf.getvalue(), mtime=0)


# ---------------------------------------------------------------- control

CONTROL_TMPL = """\
Package: {pkg}
Name: {name}
Version: {version}
Architecture: {arch}
Description: {desc}
Maintainer: {maintainer}
Author: {maintainer}
Section: {section}
Depends: firmware (>= 14.0)
Suggests: preferenceloader
Priority: optional
Icon: file:///Library/MobileSubstrate/DynamicLibraries/{name}.png
"""


def control_text() -> str:
    return CONTROL_TMPL.format(pkg=PKG_ID, name=PKG_NAME, version=VERSION, arch=ARCH,
                               desc=DESCRIPTION, maintainer=MAINTAINER, section=SECTION)


# ---------------------------------------------------------------- 查找 dylib

def find_dylib(explicit: str | None, root: Path) -> Path | None:
    if explicit:
        p = Path(explicit)
        return p if p.exists() else None
    patterns = [
        ".theos/obj/**/*.dylib",
        ".theos/obj/**/DYBoost.dylib",
        "obj/**/*.dylib",
        "theos/obj/**/*.dylib",
        ".theos/_/**/*.dylib",
        "**/*.dylib",
    ]
    best = None
    for pat in patterns:
        hits = [p for p in root.glob(pat) if p.is_file() and p.stat().st_size > 20000]
        # 排除 framework 内嵌
        hits = [p for p in hits if "framework" not in str(p).lower()]
        if hits:
            # 优先取层级最浅的那个（Theos 把 lipo 合并后的最终产物放在 obj 根），同级取最新
            hits.sort(key=lambda p: (len(p.parts), -p.stat().st_mtime))
            best = hits[0]
            break
    return best


# ---------------------------------------------------------------- 打包

def pack(dylib: Path, plist: Path | None, scheme: str, out_dir: Path,
         fmt: str = "deb", want_zip: bool = False) -> "list[Path]":
    prefix = PREFIX[scheme]
    rel = "Library/MobileSubstrate/DynamicLibraries"
    arc_dylib = f"{prefix}/{rel}/{PKG_NAME}.dylib".lstrip("/")
    arc_plist = f"{prefix}/{rel}/{PKG_NAME}.plist".lstrip("/")

    data = dylib.read_bytes()
    files = {arc_dylib: data}
    if plist and plist.exists():
        files[arc_plist] = plist.read_bytes()

    # layout/ 里的东西（比如 PreferenceLoader 的 entry.plist）一起打进去
    layout = Path(__file__).resolve().parent.parent / "layout"
    if layout.is_dir():
        for p in sorted(layout.rglob("*")):
            if p.is_file() and p.stat().st_size > 0:
                rel = p.relative_to(layout).as_posix()
                files[f"{prefix}/{rel}".lstrip("/")] = p.read_bytes()

    dirs = [d.rstrip("/") for d in {os.path.dirname(p) for p in files}]

    mtime = int(time.time())
    control = build_tar_gz({"./control": control_text().encode("utf-8")}, mtime)
    payload = build_tar_gz(files, mtime, dirs)

    out_dir.mkdir(parents=True, exist_ok=True)
    produced: "list[Path]" = []

    if fmt in ("deb", "all"):
        blob = build_ar([("debian-binary", b"2.0\n"),
                         ("control.tar.gz", control),
                         ("data.tar.gz", payload)], mtime)
        deb = out_dir / f"{PKG_ID}_{VERSION}_{ARCH}.deb"
        deb.write_bytes(blob)
        produced.append(deb)

    if fmt in ("zip", "all") or want_zip:
        zp = out_dir / f"{PKG_NAME}-{VERSION}-{scheme}.zip"
        with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED) as z:
            z.writestr(f"{PKG_NAME}.dylib", data)
            if plist and plist.exists():
                z.writestr(f"{PKG_NAME}.plist", plist.read_bytes())
        produced.append(zp)

    return produced


def inspect_deb(path: Path):
    """自检：解开刚打的包，确认结构正确"""
    raw = path.read_bytes()
    assert raw.startswith(b"!<arch>\n"), "ar 头不对"
    print(f"[check] {path.name}  {len(raw)} bytes")
    off = 8
    while off + 60 <= len(raw):
        hdr = raw[off:off + 60]
        name = hdr[0:16].decode("latin1").strip()
        size = int(hdr[48:58].decode().strip() or 0)
        body = raw[off + 60:off + 60 + size]
        off += 60 + size + (size % 2)
        if name == "debian-binary":
            print(f"  - debian-binary: {body!r}")
        else:
            with tarfile.open(fileobj=io.BytesIO(gzip.decompress(body))) as tf:
                for m in tf.getmembers():
                    print(f"  - {name}: {m.name} ({m.size} bytes)")
        if not name:
            break


def main() -> int:
    ap = argparse.ArgumentParser(description="把 DYBoost.dylib 打成 deb / zip")
    ap.add_argument("--dylib", help="编译产物路径，不给就自动搜")
    ap.add_argument("--plist", default=None, help="过滤器 plist，默认 DYBoost.plist")
    ap.add_argument("--scheme", default="rootless",
                    choices=["rootless", "roothide", "trollstore", "rootful"],
                    help="目标布局，巨魔注入器选 trollstore")
    ap.add_argument("--out", default="packages", help="输出目录")
    ap.add_argument("--format", default="deb", choices=["deb", "zip", "all"])
    ap.add_argument("--version", default=None, help="覆盖版本号")
    args = ap.parse_args()

    global VERSION
    if args.version:
        VERSION = args.version

    root = Path(__file__).resolve().parent.parent
    dylib = find_dylib(args.dylib, root)
    if not dylib:
        print("[!] 没找到编译好的 dylib。先在 macOS/CI 上跑 `make` 编译，或用 --dylib 指定。", file=sys.stderr)
        return 2

    plist = Path(args.plist) if args.plist else root / f"{PKG_NAME}.plist"
    out = root / args.out

    print(f"[+] dylib : {dylib}  ({dylib.stat().st_size} bytes)")
    print(f"[+] scheme: {args.scheme}")
    for p in pack(dylib, plist, args.scheme, out, args.format):
        print(f"[+] 产出  : {p}")
        if p.suffix == ".deb":
            inspect_deb(p)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
