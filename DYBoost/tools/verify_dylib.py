#!/usr/bin/env python3
"""dylib 产物自检。

只做静态结构检查，不需要 macOS / dyld：
  1. 是不是 Mach-O dylib（MH_DYLIB）
  2. 每个 slice 的架构
  3. DYBoost 自己的类有没有编进去
  4. **入口在不在** —— +load(__objc_nlclslist) 或构造器
     (__mod_init_func / __init_offsets) 至少有一个非空。
     这一条最关键：巨魔注入器不加载 Substrate，全靠镜像自己的入口启动，
     入口丢了就是一个安静的空壳，装上什么都不会发生。
  5. 有没有 LC_CODE_SIGNATURE
  6. 依赖里有没有越狱才有的库（substrate / ellekit / cycript）

用法: python3 tools/verify_dylib.py packages/DYBoost.dylib
"""
from __future__ import annotations

import struct
import sys
from pathlib import Path

MH_DYLIB = 6
LC_SEGMENT_64 = 0x19
LC_ID_DYLIB = 0x0D
LC_LOAD_DYLIB = 0x0C
LC_CODE_SIGNATURE = 0x1D
LC_BUILD_VERSION = 0x32 | 0x80000000
LC_VERSION_MIN_IPHONEOS = 0x25

ARCH = {0x0100000C: {0x0: "arm64", 0x80000002: "arm64e", 0x1: "arm64v8"}}
JAILBREAK_DEPS = ("substrate", "ellekit", "cycript", "libhooker", "cynject", "mobilesubstrate")


def slices(data: bytes):
    magic = struct.unpack(">I", data[:4])[0]
    if magic == 0xCAFEBABE:
        n = struct.unpack(">I", data[4:8])[0]
        off = 8
        for _ in range(n):
            ct, cs, o, sz, _al = struct.unpack_from(">iiIII", data, off)
            off += 20
            yield ARCH.get(ct, {}).get(cs & 0xFFFFFFFF, f"cpu{ct:#x}/{cs:#x}"), data[o:o + sz]
    elif magic == 0xCAFEBABF:
        n = struct.unpack(">I", data[4:8])[0]
        off = 8
        for _ in range(n):
            ct, cs, o, sz, _al, _r = struct.unpack_from(">iiQQII", data, off)
            off += 32
            yield ARCH.get(ct, {}).get(cs & 0xFFFFFFFF, f"cpu{ct:#x}/{cs:#x}"), data[o:o + sz]
    elif data[:4] in (b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe"):
        yield "thin", data
    else:
        return


def parse(blob: bytes) -> dict:
    cpu, sub, ftype, ncmds = struct.unpack_from("<iiII", blob, 4)
    off = 32 if blob[:4] == b"\xcf\xfa\xed\xfe" else 28
    info = {"arch": ARCH.get(cpu, {}).get(sub & 0xFFFFFFFF, f"cpu{cpu:#x}/{sub:#x}"),
            "filetype": ftype, "sections": {}, "deps": [], "id": None,
            "cmds": set(), "minos": None}
    for _ in range(ncmds):
        if off + 8 > len(blob):
            break
        cmd, size = struct.unpack_from("<II", blob, off)
        if size == 0:
            break
        info["cmds"].add(cmd)
        if cmd == LC_SEGMENT_64:
            nsect = struct.unpack_from("<I", blob, off + 64)[0]
            so = off + 72
            for _ in range(nsect):
                if so + 80 > len(blob):
                    break
                name = blob[so:so + 16].rstrip(b"\0").decode("latin1")
                info["sections"][name] = struct.unpack_from("<Q", blob, so + 40)[0]
                so += 80
        elif cmd == LC_LOAD_DYLIB:
            n = struct.unpack_from("<I", blob, off + 8)[0]
            info["deps"].append(blob[off + n:off + size].split(b"\0")[0].decode("latin1"))
        elif cmd == LC_ID_DYLIB:
            n = struct.unpack_from("<I", blob, off + 8)[0]
            info["id"] = blob[off + n:off + size].split(b"\0")[0].decode("latin1")
        elif cmd in (0x32, LC_BUILD_VERSION, LC_VERSION_MIN_IPHONEOS):
            _plat, mo, _sdk, _nt = struct.unpack_from("<IIII", blob, off + 8)
            info["minos"] = f"{mo >> 16}.{(mo >> 8) & 0xFF}.{mo & 0xFF}"
        off += size
    return info


def section_bytes(blob: bytes, name: str) -> bytes:
    """取某个 section 的文件内容（用于挖类名）"""
    off, ncmds = 32, struct.unpack_from("<I", blob, 0x10)[0]
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", blob, off)
        if size == 0:
            break
        if cmd == LC_SEGMENT_64:
            nsect = struct.unpack_from("<I", blob, off + 64)[0]
            so = off + 72
            for _ in range(nsect):
                if so + 80 > len(blob):
                    break
                sn = blob[so:so + 16].rstrip(b"\0").decode("latin1")
                if sn == name:
                    foff = struct.unpack_from("<I", blob, so + 48)[0]
                    sz = struct.unpack_from("<Q", blob, so + 40)[0]
                    return blob[foff:foff + sz]
                so += 80
        off += size
    return b""


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    path = Path(sys.argv[1])
    data = path.read_bytes()
    print(f"=== {path.name}  {len(data)} bytes ===")

    errs, warns = [], []
    found = list(slices(data))
    if not found:
        print("[!] 不是 Mach-O，也没 fat 头")
        return 1
    print(f"[+] 架构: {', '.join(a for a, _ in found)}")

    for arch, blob in found:
        info = parse(blob)
        secs = info["sections"]
        cls = [c.decode("utf8", "replace")
               for c in section_bytes(blob, "__objc_classname").split(b"\0") if c]
        dyb = sorted(c for c in cls if c.startswith("DYB"))
        entry = {k: secs.get(k, 0) for k in
                 ("__objc_nlclslist", "__mod_init_func", "__init_offsets")}
        has_entry = any(v for v in entry.values())

        print(f"\n  --- {arch} ---")
        print(f"    filetype    : {info['filetype']} "
              f"({'MH_DYLIB ✓' if info['filetype'] == MH_DYLIB else '不是 dylib ✗'})")
        print(f"    min iOS     : {info['minos']}")
        print(f"    install_name: {info['id']}")
        print(f"    DYB 类      : {len(dyb)} 个" + (f"  {', '.join(dyb[:8])}..." if dyb else ""))
        print(f"    入口段      : " + "  ".join(f"{k}={v}" for k, v in entry.items()))
        print(f"    签名        : {'有' if LC_CODE_SIGNATURE in info['cmds'] else '无'}")
        print(f"    依赖        : {len(info['deps'])}")

        if info["filetype"] != MH_DYLIB:
            errs.append(f"{arch}: filetype={info['filetype']}，不是 MH_DYLIB")
        if not dyb:
            errs.append(f"{arch}: 一个 DYB* 类都没有，链接时代码被丢掉了")
        if not has_entry:
            errs.append(f"{arch}: 没有入口（nlclslist / mod_init_func / init_offsets 全空），"
                        f"注入后不会启动")
        if LC_CODE_SIGNATURE not in info["cmds"]:
            warns.append(f"{arch}: 无 LC_CODE_SIGNATURE（TrollFools 重签一般能补上）")
        for d in info["deps"]:
            if any(j in d.lower() for j in JAILBREAK_DEPS):
                errs.append(f"{arch}: 依赖了越狱库 {d}，巨魔环境加载不了")

    print()
    for w in warns:
        print(f"[~] {w}")
    for e in errs:
        print(f"[!] {e}")
    if errs:
        print("\n[!] 自检未通过")
        return 1
    print("[+] 自检通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
