#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
calibrate.py - 真机校准：把设备导出的类名清单，变成新的候选类名表

输入三选一：
  1) DYBoost-report.txt   —— 面板「导出校准报告（分享）」出来的那个
  2) DYBoost-classes.txt  —— 面板「导出全部类名（分享）」
  3) --macho <砸壳后的 Aweme 可执行文件>   直接从 Mach-O 的 __objc_classname 抠

用法：
    python3 tools/calibrate.py report.txt                # 只看建议
    python3 tools/calibrate.py report.txt --apply        # 直接改写 src/DYBBeauty.m
    python3 tools/calibrate.py --macho ./Aweme --apply
    python3 tools/calibrate.py report.txt --out sug.json # 导出建议 JSON

改完重新编译即可；--apply 会先备份成 src/DYBBeauty.m.bak
"""

import argparse
import json
import os
import re
import shutil
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BEAUTY = os.path.join(ROOT, "src", "DYBBeauty.m")

# 规则 id -> strong / weak 关键词
# strong：命中任意一个才纳入候选（避免 "ad" 命中 AWEGradientView 这种)
# weak  ：只加分，不能单独决定
RULES = {
    "hideAd":           {"strong": ["advert", "adtag", "adfeed", "adavatar", "adcard", "adview",
                                    "adcell", "adbanner", "promotion", "sponsor", "mixvideo"],
                         "weak": ["ad", "commercial"]},
    "hideLive":         {"strong": ["livemark", "livetab", "liveroom", "liveentrance", "livestatus",
                                    "liveindicator", "livefeed", "liveavatar", "livingtag"],
                         "weak": ["live"]},
    "hideShop":         {"strong": ["anchor", "ecommerce", "ecom", "shop", "mall", "goods",
                                    "productcard", "orderentry", "ecommerceentry"],
                         "weak": ["buy", "product"]},
    "hideSearchBtn":    {"strong": ["searchentrance", "searchbar", "searchbubble", "topbarsearch",
                                    "hotsearch", "searchicon", "searchbtn"],
                         "weak": ["search"]},
    "hideAntiAddict":   {"strong": ["antiaddict", "addicted", "timelock", "teenmode", "youngmode",
                                    "timeremind", "restremind", "antiaddiction"],
                         "weak": ["teen", "young"]},
    "hideDanmaku":      {"strong": ["danmaku", "barrage", "bulletchat"], "weak": []},
    "hideAIBall":       {"strong": ["aiball", "aimode", "aiassistant", "aiassist", "aiinput",
                                    "aifloat", "aibutton", "voiceinput"],
                         "weak": ["ai", "voicesearch"]},
    "hideStoryRing":    {"strong": ["storyring", "ringview", "storyprogress", "storycontainer",
                                    "coverring", "storyavatar"],
                         "weak": ["story", "ring"]},
    "hideCommentInput": {"strong": ["commentinput", "inputbackground", "commentbar", "inputbar",
                                    "inputcontainer", "commentedit"],
                         "weak": ["input"]},
    "hideTyping":       {"strong": ["typing", "inputstatus", "inputing"], "weak": []},
    "hideReadReceipt":  {"strong": ["readreceipt", "readstatus", "messageread", "hasread",
                                    "readflag"], "weak": ["receipt"]},
}
PROGRESS = {"strong": ["progressslider", "playprogress", "seekbar", "progressbar", "progressview",
                       "progresscontainer", "fakeprogress"],
            "weak": ["progress", "slider"]}

# 不是视图的东西，直接排除
BAD_SUFFIX = ("Model", "Manager", "Service", "Data", "Config", "Item", "Object", "Protocol",
              "API", "Request", "Response", "Util", "Utils", "Helper", "Bridge", "Delegate",
              "Store", "Cache", "Tracker", "Monitor", "Log", "Logger", "Setting", "Settings",
              "Provider", "Adapter", "Factory", "Parser", "Handler", "Router", "Context",
              "Task", "Command", "Event", "Info", "Result", "Session", "Client", "Server",
              "WebView", "Impl", "ServiceImpl", "DataController", "DataSource", "Layout",
              "Animator", "Transition", "Gesture", "Recognizer", "Tracker", "Wrapper")

PREFIX = ("AWE", "AWEM", "AWEF", "FDS", "IES", "BDX", "HTS", "TT", "AFD", "ACC", "DYS")

MAX_PER_RULE = 8


# ---------------------------------------------------------------- 输入解析

def parse_text(path: str):
    names = set()
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip().rstrip(",")
            if not line or line.startswith("#") or line.startswith("//"):
                continue
            if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{3,80}", line):
                names.add(line)
    return names


def parse_macho(path: str):
    """从 Mach-O 里抠 __objc_classname（要求已砸壳 / cryptid=0）"""
    d = open(path, "rb").read()
    if d[:4] not in (b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe"):
        print("[!] 不是 Mach-O：", path)
        return set()
    magic = struct.unpack_from("<I", d, 0)[0]
    is64 = magic in (0xFEEDFACF, 0xFEEDFACE)
    ncmds = struct.unpack_from("<I", d, 16 if is64 else 12)[0]
    off = 32 if is64 else 28
    out = set()
    for _ in range(ncmds):
        cmd, sz = struct.unpack_from("<II", d, off)
        if cmd in (0x19 if is64 else 0x1):  # SEGMENT_64 / SEGMENT
            if is64:
                nsects = struct.unpack_from("<I", d, off + 64)[0]
                so = off + 72
                secsize = 80
            else:
                nsects = struct.unpack_from("<I", d, off + 48)[0]
                so = off + 56
                secsize = 68
            for _j in range(nsects):
                sname = d[so:so + 16].rstrip(b"\0").decode("latin1")
                if sname == "__objc_classname":
                    size = struct.unpack_from("<Q" if is64 else "<I", d, so + 40 if is64 else so + 36)[0]
                    fo = struct.unpack_from("<I", d, so + 48 if is64 else so + 40)[0]
                    blob = d[fo:fo + size]
                    for part in blob.split(b"\0"):
                        if part:
                            try:
                                out.add(part.decode("utf-8"))
                            except UnicodeDecodeError:
                                pass
                so += secsize
        off += sz
        if sz == 0:
            break
    return out


# ---------------------------------------------------------------- 打分

def score(name: str, spec):
    n = name.lower()
    body = re.sub(r"^(awe|awem|awed|fds|ies|bdx|hts|tt|ttv|afd|acc|dys)", "", n)
    if not any(k in n for k in spec["strong"]):
        return 0        # 没有强命中 → 直接不要，宁缺勿滥
    s = 5
    for k in spec["strong"]:
        if k in n:
            s += 3
            if body.startswith(k):
                s += 2
    for k in spec.get("weak", []):
        if k in n:
            s += 1
    if n.endswith("view") or n.endswith("viewcontroller") or n.endswith("cell"):
        s += 3
    elif n.endswith("component") or n.endswith("container") or n.endswith("bar"):
        s += 1
    if any(n.endswith(b.lower()) for b in BAD_SUFFIX):
        return 0
    if len(name) > 45:
        s -= 2
    if not name.startswith(PREFIX):
        s -= 1
    return s


def suggest(names, spec, keep):
    ranked = []
    for nm in names:
        sc = score(nm, spec)
        if sc >= 6:
            ranked.append((sc, len(nm), nm))
    ranked.sort(key=lambda x: (-x[0], x[1], x[2]))
    out = list(keep)
    for sc, _l, nm in ranked:
        if nm in out:
            continue
        out.append(nm)
        if len(out) >= MAX_PER_RULE:
            break
    return out


def current_lists():
    """从 DYBBeauty.m 里读出每条规则现有的候选，作为保底项"""
    src = open(BEAUTY, encoding="utf-8").read()
    cur = {}
    for rid in RULES:
        m = re.search(r'@"id":\s*DYBKey_' + rid + r'\b.*?@"classes":\s*@\[(.*?)\]', src, re.S)
        if m:
            cur[rid] = re.findall(r'@"([^"]+)"', m.group(1))
    m = re.search(r'DYBProgressClasses\(void\)\s*\{\s*return\s*@\[(.*?)\];', src, re.S)
    if m:
        cur["__progress__"] = re.findall(r'@"([^"]+)"', m.group(1))
    return cur, src


def apply_to_source(src: str, newmap: dict) -> str:
    for rid, names in newmap.items():
        if rid == "__progress__":
            pat = re.compile(r'(DYBProgressClasses\(void\)\s*\{\s*return\s*@\[)(.*?)(\];)', re.S)
            rep = lambda m: m.group(1) + ", ".join('\n             @"%s"' % n for n in names) + m.group(3)
            src = pat.sub(rep, src, count=1)
            continue
        pat = re.compile(r'(@"id":\s*DYBKey_' + rid + r'\b.*?@"classes":\s*@\[)(.*?)(\])', re.S)
        def rep(m):
            return m.group(1) + ", ".join('@"%s"' % n for n in names) + m.group(3)
        src = pat.sub(rep, src, count=1)
    return src


def main() -> int:
    ap = argparse.ArgumentParser(description="用真机导出的类名校准 DYBoost 候选类名表")
    ap.add_argument("input", nargs="?", help="report.txt / classes.txt")
    ap.add_argument("--macho", help="砸壳后的 Aweme 可执行文件")
    ap.add_argument("--apply", action="store_true", help="直接改写 src/DYBBeauty.m")
    ap.add_argument("--out", help="把建议写成 JSON")
    ap.add_argument("--max", type=int, default=MAX_PER_RULE)
    args = ap.parse_args()

    if args.macho:
        names = parse_macho(args.macho)
    elif args.input:
        names = parse_text(args.input)
    else:
        print("[!] 给一个输入文件，或用 --macho", file=sys.stderr)
        return 2

    if not names:
        print("[!] 没解析到类名", file=sys.stderr)
        return 2

    cur, src = current_lists()
    print(f"[+] 类名总数 {len(names)}")
    newmap = {}
    for rid, keys in RULES.items():
        keep = [n for n in cur.get(rid, [])]
        got = suggest(names, keys, keep)[:args.max]
        newmap[rid] = got
        added = [n for n in got if n not in keep]
        print(f"\n== {rid} ==\n   保留 {len(keep)}，新增 {len(added)}")
        if added:
            print("   新增: " + ", ".join(added))
    pg = suggest(names, PROGRESS, cur.get("__progress__", []))[:args.max]
    newmap["__progress__"] = pg
    print(f"\n== progress ==\n   {', '.join(pg)}")

    if args.out:
        json.dump(newmap, open(args.out, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        print("\n[+] 建议已写入", args.out)

    if args.apply:
        shutil.copyfile(BEAUTY, BEAUTY + ".bak")
        open(BEAUTY, "w", encoding="utf-8").write(apply_to_source(src, newmap))
        print("[+] 已改写", BEAUTY, " 备份：", BEAUTY + ".bak")
    else:
        print("\n（只打印建议。加 --apply 才会改文件）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
