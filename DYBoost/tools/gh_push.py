#!/usr/bin/env python3
"""git push 走不通时的兜底：用 GitHub Git Data API 直接提交。

场景：代理 / 沙箱只允许 api.github.com，git 的 https:// 被 CONNECT 502 挡掉。
用法：
    python3 tools/gh_push.py -m "提交说明" [文件...]
不传文件就用 `git diff --name-only <base>` 里相对 base 的改动。
"""
from __future__ import annotations

import argparse
import base64
import json
import subprocess
import sys
from pathlib import Path

GH = r"C:\Program Files\GitHub CLI\gh.exe"


def gh_json(method: str, endpoint: str, payload: dict | None = None):
    cmd = [GH, "api", "-X", method, endpoint, "--input", "-"]
    r = subprocess.run(cmd, input=json.dumps(payload or {}), capture_output=True,
                       text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        print(f"[!] {method} {endpoint} 失败:\n{r.stdout[:500]}\n{r.stderr[:1500]}")
        sys.exit(1)
    return json.loads(r.stdout) if r.stdout.strip() else {}


def gh_raw(endpoint: str, jq: str) -> str:
    r = subprocess.run([GH, "api", endpoint, "--jq", jq], capture_output=True,
                       text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        print(f"[!] {endpoint} 失败:\n{r.stderr[:1500]}")
        sys.exit(1)
    return r.stdout.strip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("-m", "--message", required=True)
    ap.add_argument("--base", default="origin/main", help="基准 ref，缺省 origin/main")
    ap.add_argument("--branch", default="main")
    ap.add_argument("--repo", default="HONDA2567/DYBoost-tweak")
    ap.add_argument("files", nargs="*")
    args = ap.parse_args()

    repo = args.repo
    files = args.files or subprocess.run(
        ["git", "diff", "--name-only", args.base, "HEAD"],
        capture_output=True, text=True).stdout.split()
    files = [f for f in files if Path(f).is_file()]
    if not files:
        print("[!] 没有要提交的文件")
        return 1

    head = gh_raw(f"repos/{repo}/commits/{args.branch}", ".sha")
    print(f"[+] 远端 HEAD {head[:8]}  ({len(files)} 个文件)")

    tree = []
    for f in files:
        data = Path(f).read_bytes()
        blob = gh_json("POST", f"repos/{repo}/git/blobs",
                       {"content": base64.b64encode(data).decode(), "encoding": "base64"})
        tree.append({"path": f.replace("\\", "/"), "mode": "100644",
                     "type": "blob", "sha": blob["sha"]})
        print(f"    blob  {f}  ({len(data)} bytes)")

    new_tree = gh_json("POST", f"repos/{repo}/git/trees",
                       {"base_tree": head, "tree": tree})
    print(f"[+] tree  {new_tree['sha'][:8]}")

    commit = gh_json("POST", f"repos/{repo}/git/commits",
                     {"message": args.message, "tree": new_tree["sha"], "parents": [head]})
    print(f"[+] commit {commit['sha'][:8]}")

    gh_json("PATCH", f"repos/{repo}/git/refs/heads/{args.branch}", {"sha": commit["sha"]})
    print(f"[+] {args.branch} -> {commit['sha'][:8]}")
    print(f"    https://github.com/{repo}/commit/{commit['sha']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
