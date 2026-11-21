#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Steam 创意工坊参考 MOD 索引 / 按需复制工具

设计原则：**参考 MOD 默认只读 workshop 目录**（C:/Program Files (x86)/Steam/steamapps/workshop/content/322330），
不做全量复制（124 个 MOD 约 5GB）。本脚本做三件事：

1. 生成 MOD名单.md —— ID → 名字 → 路径 对照表（只解析 modinfo.lua，秒级）
2. --id <ID> --copy —— 需要长期持有/改动某个 MOD 时，按需复制到 参考MOD_ID/<ID>/
3. --id <ID> --update —— 检测已复制的 MOD 是否有新版本，有变动则覆盖（自动备份）

用法:
    python sync_workshop_mods.py                       # 生成/刷新 MOD名单.md（只读）
    python sync_workshop_mods.py --list                # 终端列出有效 MOD + 名字
    python sync_workshop_mods.py --id 1909182187 --copy     # 按需复制单个 MOD
    python sync_workshop_mods.py --id 1909182187 --update   # 检测/更新该副本
    python sync_workshop_mods.py --update-all           # 更新所有已复制的 MOD
    python sync_workshop_mods.py --id 1909182187 --info    # 查看某 MOD 详情

专家读源码时：直接读 workshop/<ID>/ 下的 .lua 即可，用 MOD名单.md 查 ID；
        只有需要长期对比/改动时才 --copy 到本地。
"""

import argparse
import json
import os
import re
import shutil
import sys
import zlib
from datetime import datetime
from pathlib import Path

WS_ROOT = Path(r"C:/Program Files (x86)/Steam/steamapps/workshop/content/322330")
DEST_ROOT = Path("C:/Users/hehu/Documents/GitHub/DST-H-MOD/参考代码/参考MOD_ID")
NAMES_FILE = Path("C:/Users/hehu/Documents/GitHub/DST-H-MOD/参考代码/MOD名单.md")
MANIFEST_NAME = ".copy_manifest.json"
SKIP_NAMES = {"thumbs.db", "desktop.ini", ".ds_store"}
SKIP_DIRS = {".git", "__pycache__"}

# name 字段解析：覆盖常见写法
#   name = "xxx"
#   name = isCh and "中文" or "English"
#   name = L and "English" or "中文"
#   name = ChooseTranslationTable{...} (取 zh/中文项)
RE_NAME_PLAIN = re.compile(r'^\s*name\s*=\s*"([^"]+)"', re.M)
RE_NAME_SINGLE = re.compile(r"^\s*name\s*=\s*'([^']+)'", re.M)
RE_NAME_CH = re.compile(
    r'^\s*name\s*=\s*\w+\s+and\s+"([^"]+)"\s+or\s+"([^"]+)"', re.M
)
RE_NAME_TABLE = re.compile(
    r"\b(?:zh|zhr|chs)\s*=\s*[\"']([^\"']+)[\"']", re.I
)


def file_crc(path: Path) -> int:
    h = 0
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 16), b""):
            h = zlib.crc32(block, h)
    return h & 0xFFFFFFFF


def index_dir(root: Path) -> dict:
    result = {}
    if not root.exists():
        return result
    for dp, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f.lower() in SKIP_NAMES or f == MANIFEST_NAME:
                continue
            p = Path(dp) / f
            result[p.relative_to(root).as_posix()] = file_crc(p)
    return result


def read_mod_name(mod_dir: Path) -> str:
    info = mod_dir / "modinfo.lua"
    if not info.exists():
        return "(无 modinfo)"
    try:
        txt = info.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return "(读取失败)"
    m = RE_NAME_TABLE.search(txt)
    if m:
        return m.group(1)
    m = RE_NAME_CH.search(txt)
    if m:
        a, b = m.group(1), m.group(2)
        # 含中文字符的那一项优先展示
        cn = next((x for x in (a, b) if re.search(r"[\u4e00-\u9fff]", x)), b)
        en = a if cn == b else b
        return f"{cn} / {en}" if cn != en else cn
    m = RE_NAME_PLAIN.search(txt) or RE_NAME_SINGLE.search(txt)
    if m:
        return m.group(1)
    for line in txt.splitlines():
        if re.match(r"^\s*name\s*=", line):
            return line.strip()[:90]
    return "(未解析到名字)"


def mod_size(mod_dir: Path):
    n = 0
    size = 0
    for dp, dirs, files in os.walk(mod_dir):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f.lower() in SKIP_NAMES:
                continue
            p = Path(dp) / f
            n += 1
            try:
                size += p.stat().st_size
            except OSError:
                pass
    return n, size


def valid_mods():
    """返回有 modinfo.lua 的有效 MOD 目录列表"""
    if not WS_ROOT.exists():
        return []
    return sorted(d for d in WS_ROOT.iterdir() if d.is_dir() and (d / "modinfo.lua").exists())


def load_manifest(dest_dir: Path) -> dict:
    f = dest_dir / MANIFEST_NAME
    if f.exists():
        try:
            return json.loads(f.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            pass
    return {}


def build_names_table():
    mods = valid_mods()
    rows = []
    total_size = 0
    for d in mods:
        name = read_mod_name(d)
        nfiles, size = mod_size(d)
        total_size += size
        rows.append((d.name, name, nfiles, size))
    all_dirs = sum(1 for x in WS_ROOT.iterdir() if x.is_dir()) if WS_ROOT.exists() else 0
    lines = [
        "# 创意工坊参考 MOD 名单",
        "",
        f"> 来源（只读）：`{WS_ROOT}`",
        f"> 按需副本：`{DEST_ROOT}`（只有执行 `--id <ID> --copy` 才会创建）",
        f"> 有效 MOD {len(rows)} 个 / workshop 目录 {all_dirs} 个（空目录已跳过），总计 {total_size / 1024**3:.2f} GB",
        ">",
        "> **读源码**：直接读 `workshop/<ID>/` 下的 .lua，不用复制。",
        "> **长期持有/改动**：`python 参考代码/sync_workshop_mods.py --id <ID> --copy`。",
        "> **更新副本**：`python 参考代码/sync_workshop_mods.py --id <ID> --update`。",
        ">",
        "> 名字由 modinfo.lua 解析；若显示异常，直接看该 ID 目录下的 modinfo.lua。",
        "",
        "| 工坊 ID | MOD 名字 | 文件数 | 大小 |",
        "|---|---|---:|---:|",
    ]
    for mid, name, nfiles, size in rows:
        safe = name.replace("|", "\\|").replace("\n", " ")
        lines.append(f"| `{mid}` | {safe} | {nfiles} | {size / 1024**2:.1f} MB |")
    lines.append("")
    NAMES_FILE.write_text("\n".join(lines), encoding="utf-8")
    return len(rows)


def copy_or_update(mid: str, mode: str):
    ws_dir = WS_ROOT / mid
    if not ws_dir.exists() or not (ws_dir / "modinfo.lua").exists():
        print(f"❌ ID {mid} 不是有效 MOD（目录不存在或无 modinfo.lua）", file=sys.stderr)
        return 2
    dest_dir = DEST_ROOT / mid
    name = read_mod_name(ws_dir)
    ws_idx = index_dir(ws_dir)
    lc_idx = index_dir(dest_dir)

    if mode == "copy":
        if dest_dir.exists():
            print(f"ℹ {mid} 已有副本，改用 --update 检测更新。")
        else:
            dest_dir.mkdir(parents=True, exist_ok=True)
            cnt = 0
            for rel in sorted(ws_idx):
                src = ws_dir / Path(*rel.split("/"))
                dst = dest_dir / Path(*rel.split("/"))
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
                cnt += 1
            print(f"✅ 已复制 {mid} {name}：{cnt} 个文件 → {dest_dir}")
        manifest = {
            "workshop_id": mid,
            "name": name,
            "file_count": len(ws_idx),
            "sync_time": datetime.now().strftime("%Y%m%d_%H%M%S"),
            "digest": sum(ws_idx.values()) & 0xFFFFFFFF,
        }
        (dest_dir / MANIFEST_NAME).write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        return 0

    # update 模式
    if not dest_dir.exists():
        print(f"❌ {mid} 没有本地副本。先用 --copy。", file=sys.stderr)
        return 2
    common = set(ws_idx) & set(lc_idx)
    diff = sorted(k for k in common if ws_idx[k] != lc_idx[k])
    add = sorted(set(ws_idx) - set(lc_idx))
    local_only = sorted(set(lc_idx) - set(ws_idx))
    print(f"[{mid}] {name}")
    print(f"  workshop {len(ws_idx)} 文件 / 副本 {len(lc_idx)} 文件")
    if not diff and not add:
        print("  ✅ 无变动（副本已是最新）")
        return 0
    print(f"  🔴 变动：{len(diff)} 个修改 + {len(add)} 个新增；本地独有 {len(local_only)} 个（保留）")
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = DEST_ROOT.parent / f"参考MOD_ID_backup_{stamp}" / mid
    copied = backed = 0
    for rel in diff + add:
        src = ws_dir / Path(*rel.split("/"))
        dst = dest_dir / Path(*rel.split("/"))
        if not src.exists():
            continue
        if dst.exists():
            bk = backup / Path(*rel.split("/"))
            bk.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(dst, bk)
            backed += 1
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        copied += 1
    after = index_dir(dest_dir)
    bad = [k for k in diff + add if k in after and after[k] != ws_idx.get(k)]
    if bad:
        print(f"  ❌ 校验失败 {len(bad)} 个", file=sys.stderr)
        return 1
    manifest = {
        "workshop_id": mid,
        "name": name,
        "file_count": len(ws_idx),
        "sync_time": stamp,
        "digest": sum(ws_idx.values()) & 0xFFFFFFFF,
    }
    (dest_dir / MANIFEST_NAME).write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"  ✅ 已更新 {copied} 个文件，备份 {backed} 个 → {backup}")
    return 0


def main():
    ap = argparse.ArgumentParser(description="Steam 创意工坊参考 MOD 索引/按需复制工具")
    ap.add_argument("--list", action="store_true", help="列出所有有效 MOD + 名字")
    ap.add_argument("--id", help="指定 workshop ID")
    ap.add_argument("--copy", action="store_true", help="按需复制该 ID 到本地副本目录")
    ap.add_argument("--update", action="store_true", help="检测/更新指定 ID 的本地副本")
    ap.add_argument("--update-all", action="store_true", help="更新所有已复制的 MOD")
    ap.add_argument("--info", action="store_true", help="查看指定 ID 详情")
    ap.add_argument("--no-names", action="store_true", help="默认生成名单时跳过写文件")
    args = ap.parse_args()

    if not WS_ROOT.exists():
        print(f"❌ workshop 目录不存在: {WS_ROOT}", file=sys.stderr)
        return 2
    mods = valid_mods()
    if not mods:
        print("❌ 没有找到有效 MOD", file=sys.stderr)
        return 2

    if args.list:
        print(f"有效 MOD {len(mods)} 个:\n")
        for d in mods:
            print(f"  {d.name}  {read_mod_name(d)}")
        return 0

    if args.id:
        d = WS_ROOT / args.id
        if args.info:
            if not d.exists():
                print(f"❌ 无此 ID: {args.id}", file=sys.stderr)
                return 2
            n, size = mod_size(d)
            print(f"ID   : {args.id}")
            print(f"名字 : {read_mod_name(d)}")
            print(f"路径 : {d}")
            print(f"文件 : {n} 个 / {size / 1024**2:.1f} MB")
            info = d / "modinfo.lua"
            if info.exists():
                print("\n--- modinfo.lua 前 20 行 ---")
                print("\n".join(info.read_text(encoding="utf-8", errors="ignore").splitlines()[:20]))
            return 0
        if args.copy:
            return copy_or_update(args.id, "copy")
        if args.update:
            return copy_or_update(args.id, "update")
        print("ℹ --id 需配合 --info / --copy / --update 使用", file=sys.stderr)
        return 2

    if args.update_all:
        copies = [d for d in DEST_ROOT.iterdir() if d.is_dir()] if DEST_ROOT.exists() else []
        if not copies:
            print("ℹ 还没有任何本地副本（先 --id <ID> --copy）")
            return 0
        rc = 0
        for d in sorted(copies):
            rc |= copy_or_update(d.name, "update")
        return rc

    # 默认：生成名字表
    n = build_names_table()
    print(f"✅ 已生成 {NAMES_FILE}")
    print(f"   有效 MOD {n} 个（只读 workshop 源码；需要副本时 --id <ID> --copy）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
