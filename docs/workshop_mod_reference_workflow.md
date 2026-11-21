# 创意工坊参考 MOD 查阅工作流

## 设计原则

参考 MOD **默认只读 workshop 目录，不做全量复制**。

- workshop 有 124 个 MOD 目录（4 万文件、5.15GB），全量拷进项目太重且很快过时
- Steam 更新后 workshop 目录本身就是最新的，直接读即可
- 只有需要长期持有 / 改动 / 对比历史的 MOD，才按需复制到项目

## 两个路径

| 用途 | 路径 |
|---|---|
| 只读查阅源码（默认） | `C:/Program Files (x86)/Steam/steamapps/workshop/content/322330/<ID>/` |
| 按需副本（执行 --copy 后才有） | `参考代码/参考MOD_ID/<ID>/` |
| ID→名字对照表 | `参考代码/MOD名单.md` |
| 旧的手工整理资料（保留不动） | `参考代码/参考MOD/`（中文命名、嵌套分类、汉化补丁等） |

## 脚本：`参考代码/sync_workshop_mods.py`

```bash
# 生成/刷新名字表（只读，2 秒）
python 参考代码/sync_workshop_mods.py

# 查某个 MOD
python 参考代码/sync_workshop_mods.py --list
python 参考代码/sync_workshop_mods.py --id 1909182187 --info

# 按需复制单个 MOD（如能力勋章，1030 文件 84MB）
python 参考代码/sync_workshop_mods.py --id 1909182187 --copy

# 检测/更新副本（Steam 更新 MOD 后）
python 参考代码/sync_workshop_mods.py --id 1909182187 --update
python 参考代码/sync_workshop_mods.py --update-all
```

脚本已归入专家技能三副本的 `scripts/`（用户级 / 市场包 / cache），三份 SKILL.md 均有说明。

## 实现细节

- `MOD名单.md` 只解析每个 MOD 的 `modinfo.lua`（不遍历全部文件），所以秒级完成
- 有效 MOD 99 个 / workshop 目录 124 个；25 个空目录（已 unsubscribe 残留）自动跳过
- 名字解析覆盖：`name = "xxx"`、`isCh and "中" or "En"`、`L and "En" or "中"`、
  `ChooseTranslationTable{zh=...}`；解析失败回退展示原始行
- 空目录判定：没有 `modinfo.lua` 的目录视为无效
- `--copy` 会写 `.copy_manifest.json`（CRC 汇总），`--update` 靠它判断变动
- `--update` 只覆盖 workshop 有且内容不同的文件 + 补齐新增文件，本地独有文件（汉化/自制）保留
- 副本更新前把原文件备份到 `参考MOD_ID_backup_<时间戳>/<ID>/`

## 旧 `参考MOD/` 目录

保留不动。里面有大量手工整理的成果（中文命名、`箱子相关mod/`、`饥荒mod/` 嵌套分类、
汉化与自制修改），这些不是简单的 workshop 副本，删了会丢信息。

新查阅流程走 `MOD名单.md` → workshop 只读 → 按需 copy，与旧目录互不干扰。
