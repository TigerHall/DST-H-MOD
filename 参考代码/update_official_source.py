#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
DST 官方源码同步工具

从游戏目录的 scripts.zip 检测 / 更新本地「官方源码」文件夹。
先用 CRC 逐文件比对（不解压，秒级），有变动才解压覆盖。

用法:
    python update_official_source.py                 # 只检测，打印差异报告（只读，不改任何文件）
    python update_official_source.py --update        # 检测，有变动则解压更新（自动备份旧目录）
    python update_official_source.py --update --keep-backup   # 更新并强制保留备份
    python update_official_source.py --force-update  # 无变动也强制重新解压

默认路径（可用 --zip / --dest 覆盖）:
    ZIP  : C:/Program Files (x86)/Steam/steamapps/common/Don't Starve Together/data/databundles/scripts.zip
    DEST : <本脚本所在目录>/官方源码

安全设计:
    - 检测模式纯只读
    - 更新采用「解压到临时目录 -> 旧目录改名备份 -> 新目录就位」，切换是原子改名
    - 备份目录带时间戳，默认保留（确认无误后手动删即可）
"""

import argparse
import hashlib
import json
import os
import shutil
import sys
import tempfile
import zipfile
import zlib
from datetime import datetime
from pathlib import Path

DEFAULT_ZIP = Path(
    "C:/Program Files (x86)/Steam/steamapps/common/"
    "Don't Starve Together/data/databundles/scripts.zip"
)
# 脚本可能被复制到专家技能的 scripts/ 目录运行，此时 __file__ 不在项目里，
# 所以默认目标写死为项目路径；仅当该路径不存在时才回退到脚本同级目录。
_PROJECT_DEST = Path(
    "C:/Users/hehu/Documents/GitHub/DST-H-MOD/参考代码/官方源码"
)
DEFAULT_DEST = _PROJECT_DEST if _PROJECT_DEST.parent.exists() else Path(__file__).resolve().parent / "官方源码"
MANIFEST_NAME = ".source_manifest.json"
ZIP_PREFIX = "scripts/"
# 只同步 .lua：本地「官方源码」里混有用户手动收集的 .tex 等资源，
# 新版 zip 已不含这些资源，全量同步会把它们误判为「删除」。默认只管 lua。
SYNC_EXT = ".lua"


def file_sha256(path: Path, chunk: int = 1 << 20) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(chunk), b""):
            h.update(block)
    return h.hexdigest()


def zip_index(zp: Path) -> dict:
    """返回 {相对路径: (crc, size)}，key 已去掉 scripts/ 前缀"""
    result = {}
    with zipfile.ZipFile(zp) as z:
        for info in z.infolist():
            name = info.filename.replace("\\", "/")
            if not name.startswith(ZIP_PREFIX) or name.endswith("/"):
                continue
            rel = name[len(ZIP_PREFIX):]
            if not rel.endswith(SYNC_EXT):
                continue
            result[rel] = (info.CRC & 0xFFFFFFFF, info.file_size)
    return result


def local_index(dest: Path) -> dict:
    """返回 {相对路径: (crc, size)}，跳过 manifest 与隐藏文件"""
    result = {}
    if not dest.exists():
        return result
    for p in dest.rglob("*"):
        if not p.is_file() or p.name == MANIFEST_NAME:
            continue
        if any(part.startswith(".") for part in p.relative_to(dest).parts):
            continue
        rel = p.relative_to(dest).as_posix()
        if not rel.endswith(SYNC_EXT):
            continue
        data = p.read_bytes()
        result[rel] = (zlib.crc32(data) & 0xFFFFFFFF, len(data))
    return result


def game_revision(zp: Path) -> str:
    """读 zip 同级 hashes.txt 里的 revision（游戏版本号），读不到返回空"""
    try:
        txt = (zp.parent / "hashes.txt").read_text(encoding="utf-8", errors="ignore")
        for line in txt.splitlines():
            if line.lower().startswith("revision"):
                return line.split(None, 1)[1].strip()
    except OSError:
        pass
    return ""


def compare(zi: dict, li: dict, known_extra=None):
    """返回 (新增, 修改, 删除) 三个相对路径列表。
    known_extra: 已知且确认保留的「本地多余文件」白名单，从基线里扣除，
    避免每次都把用户手工整理的副本/旧版遗留反复报成删除。"""
    known_extra = set(known_extra or ())
    added = sorted((set(zi) - set(li)) - known_extra)
    removed = sorted((set(li) - set(zi)) - known_extra)
    modified = sorted(k for k in (set(zi) & set(li)) if zi[k] != li[k])
    return added, modified, removed


def cleanup_stale_temp(parent: Path):
    """清理上次中断遗留的 _dst_src_new_* 临时目录（纯垃圾，避免污染 git）"""
    import glob
    import shutil as _shutil
    for p in glob.glob(str(parent / "_dst_src_new_*")):
        try:
            _shutil.rmtree(p, ignore_errors=True)
            print(f"ℹ 已清理上次中断的临时目录: {Path(p).name}")
        except OSError:
            pass


def load_manifest(dest: Path) -> dict:
    f = dest / MANIFEST_NAME
    if f.exists():
        try:
            return json.loads(f.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            pass
    return {}


def print_report(zp, dest, zi, li, added, modified, removed, manifest, rev):
    print("=" * 66)
    print("DST 官方源码同步检测")
    print("=" * 66)
    print(f"ZIP 来源 : {zp}")
    print(f"游戏版本 : {rev or '(未知)'}")
    print(f"本地目录 : {dest}")
    print(f"ZIP 文件 : {len(zi)} 个    本地文件 : {len(li)} 个")
    old_rev = manifest.get("game_revision", "(无记录)")
    old_time = manifest.get("sync_time", "(无记录)")
    print(f"上次同步 : 版本 {old_rev}  时间 {old_time}")
    print("-" * 66)
    if not added and not modified and not removed:
        print("✅ 无变动：本地源码与 scripts.zip 完全一致")
        return
    print(f"🔴 检测到变动：新增 {len(added)}  修改 {len(modified)}  删除 {len(removed)}")
    for title, items in (("新增", added), ("修改", modified), ("删除", removed)):
        if items:
            print(f"\n【{title}】共 {len(items)} 个，前 15 个：")
            for k in items[:15]:
                print(f"    {k}")
            if len(items) > 15:
                print(f"    ... 另有 {len(items) - 15} 个")
    print("-" * 66)


def do_update(zp, dest, zi, changed_files, force):
    """只覆盖发生变动的 .lua 文件；非 lua 资源与未变动文件原地不动。
    改动前把原文件复制到带时间戳的备份目录（保留相对路径）。"""
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    parent = dest.parent
    tmp = Path(tempfile.mkdtemp(prefix="_dst_src_new_", dir=str(parent)))
    backup = parent / f"{dest.name}_backup_{stamp}"
    backed_up = 0
    copied = 0
    print(f"→ 解压到临时目录: {tmp.name}")
    try:
        # 1) 解压全部 lua 到临时区（供校验与取用）
        with zipfile.ZipFile(zp) as z:
            for info in z.infolist():
                name = info.filename.replace("\\", "/")
                if not name.startswith(ZIP_PREFIX) or name.endswith("/"):
                    continue
                rel = name[len(ZIP_PREFIX):]
                if not rel.endswith(SYNC_EXT):
                    continue
                target = tmp / Path(*rel.split("/"))
                target.parent.mkdir(parents=True, exist_ok=True)
                with z.open(info) as src, open(target, "wb") as dst:
                    shutil.copyfileobj(src, dst)

        # 2) 校验解压完整性
        got = local_index(tmp)
        if got != zi:
            miss = sorted(set(zi) - set(got))
            diff = sorted(k for k in (set(zi) & set(got)) if zi[k] != got[k])
            raise RuntimeError(f"解压校验失败：缺 {len(miss)} 个，CRC 不符 {len(diff)} 个")

        # 3) 逐个覆盖变动文件；覆盖前备份原文件
        for rel in changed_files:
            src = tmp / Path(*rel.split("/"))
            if not src.exists():
                continue  # 本地多出的 lua（删除项）不处理，保守保留
            dst_file = dest / Path(*rel.split("/"))
            if dst_file.exists():
                bk = backup / Path(*rel.split("/"))
                bk.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(dst_file, bk)
                backed_up += 1
            dst_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst_file)
            copied += 1

        # 4) 写同步标记
        manifest = {
            "zip_sha256": file_sha256(zp),
            "game_revision": game_revision(zp),
            "sync_time": stamp,
            "file_count": len(zi),
            "synced_files": copied,
            "known_extra": sorted(set(local_index(dest)) - set(zi)),
        }
        (dest / MANIFEST_NAME).write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        print(f"✅ 更新完成：覆盖 {copied} 个 lua，备份 {backed_up} 个原文件")
        if backup.exists():
            print(f"ℹ 备份目录: {backup}")
            print("   确认无误后可手动删除以释放空间")
        return True
    except Exception as e:
        print(f"❌ 更新失败: {e}", file=sys.stderr)
        # 回滚：用备份还原已被覆盖的文件
        if backup.exists():
            restored = 0
            for bk in backup.rglob("*"):
                if bk.is_file():
                    rel = bk.relative_to(backup)
                    shutil.copy2(bk, dest / rel)
                    restored += 1
            print(f"→ 已回滚 {restored} 个文件", file=sys.stderr)
        return False
    finally:
        if tmp.exists():
            shutil.rmtree(tmp, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser(description="DST 官方源码同步工具")
    ap.add_argument("--zip", type=Path, default=DEFAULT_ZIP, help="scripts.zip 路径")
    ap.add_argument("--dest", type=Path, default=DEFAULT_DEST, help="本地官方源码目录")
    ap.add_argument("--update", action="store_true", help="有变动则解压更新")
    ap.add_argument("--keep-backup", action="store_true", help="更新时保留备份（默认也保留，仅显式表达意图）")
    ap.add_argument("--force-update", action="store_true", help="无变动也强制重新解压")
    args = ap.parse_args()

    zp, dest = args.zip, args.dest
    if not zp.exists():
        print(f"❌ 找不到 scripts.zip: {zp}", file=sys.stderr)
        return 2

    cleanup_stale_temp(dest.parent)
    zi = zip_index(zp)
    li = local_index(dest)
    manifest = load_manifest(dest)
    added, modified, removed = compare(zi, li, manifest.get("known_extra"))
    rev = game_revision(zp)
    print_report(zp, dest, zi, li, added, modified, removed, manifest, rev)

    changed = bool(added or modified or removed)
    if args.update and (changed or args.force_update):
        print()
        # force 时同步全部；平时只同步新增+修改（删除项保守不动，避免误删参考资料）
        targets = sorted(set(added) | set(modified)) if not args.force_update else sorted(zi)
        return 0 if do_update(zp, dest, zi, targets, args.force_update) else 1
    if not changed and not args.force_update:
        return 0
    if changed and not args.update:
        print("\nℹ 检测到变动但未更新。加 --update 参数执行解压更新。")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
