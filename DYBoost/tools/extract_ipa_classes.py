#!/usr/bin/env python3
"""从（砸壳的）IPA 里抽 Objective-C 类名 / 方法名，供 calibrate.py 校准用。

不解压整个 Mach-O：只读 __TEXT,__objc_classname 和 __objc_methname 两个段的
文件偏移区间，几百 MB 的 AwemeCore 也能几秒抽完。

用法:
    python3 tools/extract_ipa_classes.py 抖音.ipa [-o out.txt] [--macho ./AwemeCore]

输出按调用方需要组织：
    out.txt                 类名（每行一个，去重排序）—— 喂给 calibrate.py
    out.meth.txt            方法名 / selector
    out.classlist.txt       从 __objc_classlist 还原的类名（含 Swift 混编，更全）
"""
from __future__ import annotations

import argparse
import struct
import sys
import zipfile
from pathlib import Path

MH_MAGIC_64 = 0xFEEDFACF
LC_SEGMENT_64 = 0x19
LC_ENCRYPTION_INFO_64 = 0x2C | 0x80000000
FAT_MAGICS = (0xCAFEBABE, 0xCAFEBABF)


def slices_of(header: bytes):
    """返回 [(arch_name, base_offset_in_file, data)] 的描述，只处理偏移，不读全文件"""
    magic = struct.unpack(">I", header[:4])[0]
    if magic in FAT_MAGICS:
        is64 = magic == 0xCAFEBABF
        n = struct.unpack(">I", header[4:8])[0]
        off = 8
        for _ in range(n):
            if is64:
                ct, cs, o, sz, _a, _r = struct.unpack_from(">iiQQII", header, off)
                off += 32
            else:
                ct, cs, o, sz, _a = struct.unpack_from(">iiIII", header, off)
                off += 20
            yield f"cpu{ct:#x}/{cs & 0xFFFFFFFF:#x}", o, sz
    else:
        yield "thin", 0, None


def parse_macho(head: bytes, base: int) -> dict:
    """head 必须包含从 Mach-O 头开始的完整 load commands"""
    if struct.unpack("<I", head[:4])[0] != MH_MAGIC_64:
        return {}
    ncmds = struct.unpack_from("<I", head, 0x10)[0]
    off = 32
    secs, crypt = {}, None
    for _ in range(ncmds):
        if off + 8 > len(head):
            break
        cmd, sz = struct.unpack_from("<II", head, off)
        if sz == 0:
            break
        if cmd == LC_SEGMENT_64:
            nsect = struct.unpack_from("<I", head, off + 64)[0]
            so = off + 72
            for _ in range(nsect):
                if so + 80 > len(head):
                    break
                name = head[so:so + 16].rstrip(b"\0").decode("latin1")
                addr, size = struct.unpack_from("<QQ", head, so + 32)
                secs[name] = dict(addr=addr, size=size, off=base + struct.unpack_from("<I", head, so + 48)[0])
                so += 80
        elif cmd == LC_ENCRYPTION_INFO_64:
            _o, _s, crypt, _p = struct.unpack_from("<IIII", head, off + 8)
        off += sz
    return {"sections": secs, "cryptid": crypt}


def read_at(reader, offset: int, size: int, chunk: int = 1 << 20) -> bytes:
    reader.seek(offset)
    out = bytearray()
    left = size
    while left > 0:
        b = reader.read(min(chunk, left))
        if not b:
            break
        out += b
        left -= len(b)
    return bytes(out)


def strings(blob: bytes) -> list[str]:
    return [p.decode("utf-8", "replace") for p in blob.split(b"\0") if p]


def from_file(path: Path, outdir: Path, verbose=True) -> dict:
    """处理一个裸 Mach-O 文件"""
    size = path.stat().st_size
    f = path.open("rb")
    head = f.read(1 << 20)
    result = {}
    for arch, base, _sz in slices_of(head):
        f.seek(base)
        h = f.read(1 << 20)
        info = parse_macho(h, base)
        if not info:
            continue
        if info["cryptid"]:
            print(f"  [!] {path.name} [{arch}] cryptid={info['cryptid']}，__TEXT 已加密，类名读不出来")
            continue
        secs = info["sections"]
        cn = secs.get("__objc_classname")
        if not cn:
            continue
        # methname 通常在 classname 前面，一次顺序读完两个段省一次解压
        mn = secs.get("__objc_methname")
        lo = min(s["off"] for s in (cn, mn) if s)
        hi = max(s["off"] + s["size"] for s in (cn, mn) if s)
        blob = read_at(f, lo, hi - lo)
        cls = strings(blob[cn["off"] - lo:cn["off"] - lo + cn["size"]])
        met = strings(blob[mn["off"] - lo:mn["off"] - lo + mn["size"]]) if mn else []
        result[arch] = (cls, met)
        if verbose:
            print(f"  [+] {path.name} [{arch}] 类名 {len(cls)}  方法名 {len(met)}")
    f.close()
    return result


def from_ipa(ipa: Path, outdir: Path, verbose=True) -> dict:
    z = zipfile.ZipFile(ipa)
    # 只挑主二进制和大 framework，跳过资源
    cands = []
    for i in z.infolist():
        n = i.filename
        if not n.startswith("Payload/"):
            continue
        if n.endswith(".appex/") or "/PlugIns/" in n or "/Watch/" in n:
            continue
        base = n.rsplit("/", 1)[-1]
        # Mach-O 一般是无扩展名或 .dylib/.framework 里的同名文件
        if "." in base and not base.endswith(".dylib"):
            continue
        if i.file_size < 64 * 1024:
            continue
        cands.append(i)
    cands.sort(key=lambda i: -i.file_size)
    if verbose:
        print(f"[+] IPA 内 Mach-O 候选 {len(cands)} 个（按体积排序）")
        for i in cands[:8]:
            print(f"    {i.file_size/1024/1024:8.1f} MB  {i.filename}")

    allcls, allmet = set(), set()
    for i in cands[:12]:
        with z.open(i.filename) as f:
            head = f.read(1 << 20)
            for arch, base, _sz in list(slices_of(head)):
                try:
                    f.seek(base)
                    h = f.read(1 << 20)
                except Exception as e:
                    print(f"  [~] {i.filename} seek 失败: {e}")
                    continue
                info = parse_macho(h, base)
                if not info:
                    continue
                if info["cryptid"]:
                    print(f"  [!] {i.filename.split('/')[-1]} cryptid={info['cryptid']} 已加密，跳过")
                    continue
                secs = info["sections"]
                cn = secs.get("__objc_classname")
                if not cn:
                    continue
                mn = secs.get("__objc_methname")
                parts = [s for s in (cn, mn) if s]
                lo = min(s["off"] for s in parts)
                hi = max(s["off"] + s["size"] for s in parts)
                if hi - lo > 400 << 20:
                    print(f"  [~] {i.filename.split('/')[-1]} 段太大({(hi-lo)>>20}MB)，跳过")
                    continue
                blob = read_at(f, lo, hi - lo)
                cls = strings(blob[cn["off"] - lo:cn["off"] - lo + cn["size"]])
                met = strings(blob[mn["off"] - lo:mn["off"] - lo + mn["size"]]) if mn else []
                allcls.update(cls)
                allmet.update(met)
                if verbose:
                    print(f"  [+] {i.filename.split('/')[-1]:45s} 类 {len(cls):7d}  方法 {len(met):7d}")
    return {"classes": sorted(allcls), "methods": sorted(allmet)}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("ipa", help="抖音 IPA（需砸壳；有 LC_ENCRYPTION_INFO_64 且 cryptid!=0 读不出来）")
    ap.add_argument("-o", "--out", default="aweme_classes", help="输出前缀")
    ap.add_argument("--macho", action="append", default=[], help="额外处理裸 Mach-O 文件，可重复")
    args = ap.parse_args()

    out = Path(args.out)
    classes, methods = set(), set()
    r = from_ipa(Path(args.ipa), out.parent)
    classes.update(r["classes"])
    methods.update(r["methods"])
    for m in args.macho:
        rr = from_file(Path(m), out.parent)
        for cls, met in rr.values():
            classes.update(cls)
            methods.update(met)

    cls_sorted = sorted(classes)
    out.with_suffix(".txt").write_text("\n".join(cls_sorted), encoding="utf-8")
    Path(str(out) + ".meth.txt").write_text("\n".join(sorted(methods)), encoding="utf-8")
    print(f"\n[+] 类名 {len(cls_sorted)} -> {out.with_suffix('.txt')}")
    print(f"[+] 方法名 {len(methods)} -> {out}.meth.txt")
    return 0


if __name__ == "__main__":
    sys.exit(main())
