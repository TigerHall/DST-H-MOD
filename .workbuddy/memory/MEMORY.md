# DST-H-MOD 项目记忆

## 铁律（跨会话必守）

### DST API 调用
- 写任何 DST API 前先查 `~/.workbuddy/skills/dst-mod-dev/references/verified-api-calls.md`（已验证写法），命中直接抄；查不到再翻 `api-quick-reference.md`
- 每验证成功一个新 API、每踩一个新坑 → 当场回写 `verified-api-calls.md` + `pitfalls.md`（技能三副本同步）。专家 agent 定义与三份 SKILL.md 均已写入此规则

### 版本管理
- 改 `modinfo.lua` 必须升 `version`，否则玩家不同步
- **AI 改动一律三段式只升第三段**（2.4→2.4.1，6.0.1→6.0.2）；两段式仅用户上传前手动收尾，AI 不得写两段式
- 整体功能升档才动第二段（需用户明确指示）
- **排查/诊断改动也要升版本**（用户明确要求）：否则日志里分不清加载的是哪版代码，无法确认诊断是否生效。每次改完都升，重开后先用 `log_triage` 核对 `Loading mod: ... Version:` 与磁盘一致

### 数据只读
- `~/Documents/Klei/DoNotStarveTogether/` 是存档/用户数据根目录，**只读**，不得写/移/删；排查结论写项目 `.workbuddy/memory/`

## 项目结构
- GitHub ↔ DST `mods/` 用 `mklink /J` 联接，改即同步
- 模块：`hcane`=行走手杖 | `hslot`=格子优化 | `hfood`=零食 | `htree`=水中木 | `htable`=茶几 | `hpack`=背包 | `hh`=实验 | `hreturn`=离线回收 | `hpaper`=制图桌回收
- 代码风格：`AddPrefabPostInit`+闭包、`local config={...}`、定时任务 `onremove` 清理
- 配置项仅 Boolean（`addConfig()`）/ Multi-option（`options`）；改配置必升 version

## 技能 / 专家 / 工具
- 技能 `dst-mod-dev`（用户级 `~/.workbuddy/skills/dst-mod-dev/`）：`pitfalls.md`（67 条，3 副本 3 套编号）、`code-templates.md`、`api-quick-reference.md`、`mod-patterns.md`、`verified-api-calls.md`（13 节）、`dst-icon-glyphs.md`、`large_container_ui.md`（9 章）、`dst-item-names.md`（官方中文对照：2841 物品名 + 970 配方描述）、`client-log-triage.md`、`scripts/log_triage.py`
- **遇到未知物品中文名先查 `references/dst-item-names.md`**（grep 中文找 key / grep key 找中文），不要猜；已写进专家定义 + 三份 SKILL.md
- 三副本：用户级主库 / 市场包 `my-experts/plugins/dst-mod-expert/skills/` / 缓存 `plugins/cache/my-experts/dst-mod-expert/1.0.0/skills/`
- 专家 `dst-mod-expert`：`~/.workbuddy/plugins/marketplaces/my-experts/plugins/dst-mod-expert/`，左侧「专家」入口
- **崩溃排查**：报崩溃先跑 `python scripts/log_triage.py [--mod hslot] [--all]` 切最近一轮会话，别修已修复的旧 bug
- 日志两处：`client_log.txt` + `backup/client_log/client_log_<时间戳>.txt`（DST 启动归档上一份）；专用服务器 `Cluster_N/Master|Caves/server_log.txt`
- 官方源码更新：`scripts/update_official_source.py`（CRC 比对 scripts.zip，只同步 .lua，自动备份/回滚）
- 工坊参考：只读 `C:/Program Files (x86)/Steam/steamapps/workshop/content/322330/<ID>/`，名单 `参考代码/MOD名单.md`；`--id <ID> --copy` 才复制。地标传送优先查 workshop `3638290455`

## hslot 核心技术（v3.8.10，实测稳定）
- **月眼空间开关**：客户端 `SendModRPCToServer(MOD_RPC["hslot_pocket"]["toggle"], key)` → 服务端 `TogglePocketDimensionChest(player,key)`（`container:Open/Close(viewer)`）；蓝眼专用 `toggle_blue`
- **大容器 UI**：完整流程见技能 `references/large_container_ui.md`（9 章）。扩容抬 `containers.MAXITEMSLOTS`（两端顶层、SetPristine 前）
- 挂载链：`containerroot.parent` → `hslot_vault_root`（`SetScale(GetHUDScale())` + hook `SetHUDSize`）→ 面板（不设锚点不缩放）→ gridroot(0.6)
- 换皮：劫持 `ContainerWidget.Open`，**绝不 Hide widget**（否则 Shift 转移/制作材料失效），只藏内容；格子用官方 `InvSlot`（ItemTile 空格会崩）
- 布局：面板 440×420（10列×6行）；`peek_height=0` 且**绝不传 `peek_percent`**；gridroot (0,-6)；`scrollbar_height_offset=-50`
- **拖动三件套**：① world_scale 动态测量（临时挪 10 单位量差值）② 起始快照 delta×world_scale ③ 命中判定直接 `abs(loc.x)`，不再减 `GetPosition()`
- 中键复位：用 `IsMouseOverPanel()` 命中判定复位鼠标所在面板；⚠️ 别用 `active_list==self` 门禁（多面板同开时只认最后打开的，别的面板按中键没反应=失效）
- **UI 出屏处理铁律（用户强制，所有 UI 通用）**：`IsCenterOffScreen()` 检出后**直接回屏幕正中 (0,0)**，不回默认/象限位置（默认位置在某些分辨率也可能看不到）；存盘偏移 = `0 - DefaultPos()` 保证下次打开仍在正中。检出时机=打开首帧 + EndDrag 松手各查一次，不在 move 里查
- **月眼地图揭示**：`player_classified.revealmapspot_*` + `OnRevealMapSpotEvent` → `MapExplorer:RevealArea`；room 型用 `TheWorld.topology`，entity 型用 `TheSim:FindEntities`（仅显式 AddTag）
- **地图传送**：`map_only` action + `maponly_checkvalidpos_fn`（客户端 GetActionPoint+FindEntities，绝不读 `globalmapicon._target`）；客户端 `ScreenFade` + 服务端 RPC 直接 Teleport；弃用 `pocketwatch_warpback`
- **UIAnim 坑**：Widget/UIAnim 无 `SetAlpha`/`DoTaskInTime`/`IsValid`，显隐只用 `Show/Hide`，用 `self.inst`；图标着色用 `image:SetTint()`，`AnimState:SetMultColour` 对 UI 无效
- 内置图标字形有**两套**：`dst-icon-glyphs.md`（`\243\176\128\xxx` U+F0000 段，50 条物品图标）+ `dst-pua-glyphs.md`（`\238\xxx\xxx` U+E000-E51B，179 条控制图标，strings.lua；鼠标左/右/中键=E100/E101/E102）。都三副本同步；「图标+数字」拼同一个 Text

## 详细历史
- 日志见 `.workbuddy/memory/2026-*.md`（按日归档），本文件只保留跨会话必用结论。
