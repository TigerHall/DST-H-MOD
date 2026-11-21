# DST-H-MOD 项目记忆

## 项目约定

### ⭐ DST API 调用铁律（2026-11-21 用户明确要求，时常执行）
- **调用前**：写任何 DST API 前，先查技能 `references/verified-api-calls.md`（实战验证清单，12 节）
  有没有记录；命中直接抄，不要凭记忆另写。查不到再翻 `api-quick-reference.md`（官方源码索引）。
- **调用后**：每验证成功一个新 API、每发现文档写法有误或踩新坑，**当场回写**
  `verified-api-calls.md` / `pitfalls.md`（技能三副本同步），并更新踩坑条数。
- 这条规则已写入：专家 agent 定义 `dst-mod-expert.md` 工作流程 + 三份 SKILL.md，专家启动时必读。
- 目的：积累"调用成功/踩坑确认"的可靠写法，避免重复踩坑（如 UIAnim SetAlpha、peek_percent 覆盖等）。

### 版本管理
- 每次修改 `modinfo.lua` 必须更新 `version`，否则玩家不会自动同步
- **【铁律】所有 AI 的改动一律用三段式、只递增第三段**：`主.次.修订`（如 6.0.1 → 6.0.2 → 6.0.3）。
  不论改动来自哪个会话/哪个专家/是否是 bug 修复，只要是被 AI 修改，就进第三位。
  遇到当前版本是两段式（如 `2.4`），AI 改动时补全为三段式第三段（`2.4.1`）。
- **两段式只由用户手动收尾**：测试完毕、准备上传时由用户改成 `主.次`（如 6.0）。
  AI 在任何情况下都不要写成两段式、也不要在收尾阶段帮用户改两段式。
- 只有在功能层面整体升一档时才动第二段（开发期也很少用；真要动需用户明确指示）

### 目录联接
- GitHub ↔ DST `mods/` 通过 `mklink /J` 联接，修改即同步

### 模块映射
- `hcane` = 行走手杖优化 | `hslot` = 格子优化 | `hfood` = 零食优化
- `htree` = 水中木优化 | `htable` = 茶几优化 | `hpack` = 背包优化 | `hh` = 实验代码
- `hreturn` = 离线物品回收（离线玩家物品托管 + 到期生成归还箱）
- `hpaper` = 制图桌回收（擦除解锁+重制，全服共享，含 world 组件 `hmod_carto_erased`）

### 功能触发方式
- `hcane`：右键使用手杖（`useableitem.SetOnUseFn`）
- `hslot`：右键检查物品（劫持 `inspectable.GetDescription`）
- `hpack`：装备/卸下事件监听
- `hfood`/`htree`/`htable`：纯数值/属性修改，无玩家交互
- 所有 MOD 均无键盘快捷键

### 代码风格
- `AddPrefabPostInit` + 闭包结构
- `local config = { ... }` 统一读配置
- 所有定时任务在 `onremove` 清理

### 配置项规范
- 仅两种类型：Boolean（`addConfig()` 辅助函数）/ Multi-option（直接写 `options` 数组）
- 改配置必须更新 `version`

---

## 技能和专家

### 已创建技能
- `dst-mod-dev`（用户级 `~/.workbuddy/skills/dst-mod-dev/`）
- 包含：踩坑库 `references/pitfalls.md`、代码模板 `references/code-templates.md`、API 速查 `references/api-quick-reference.md`、MOD 模式索引 `references/mod-patterns.md`、⭐实战验证 API `references/verified-api-calls.md`（2026-11-21 新增，只记调用成功/踩坑确认的写法，12 节）
- **崩溃日志排查能力**（2026-11-15 新增）：`references/client-log-triage.md`（先按 `Loading mod: ... Version:` 锚点切到最近一轮会话，再找报错；用版本号+堆栈行号交叉验证磁盘代码）+ `scripts/log_triage.py`（自动切最近一轮、去重 Insight 重复输出、报错最新在前）
  - 用法：`python scripts/log_triage.py [--mod hslot] [--pattern BODYDEPTH] [--all] [--log <path>]`
  - 触发：用户报崩溃/贴堆栈时，**先跑这个**再动手修，避免修一个已修复的旧 bug
  - **只读铁律**：`~/Documents/Klei/DoNotStarveTogether/` 是存档/用户数据根目录，排查时**只能读**，不得写入/修改/移动/删除（含 `backup/`、`<userid>/Cluster_N/` 存档）；结论写到项目 `.workbuddy/memory/`
  - **两处日志**：当前 `client_log.txt` + 归档 `backup/client_log/client_log_<时间戳>.txt`（DST 启动时归档上一份）；排查用 `--all-logs` 两个都扫，别只看当前日志
  - 日志路径补充：`client_log.cr.txt`、`master_server_log.txt` / `caves_server_log.txt`；专用服务器在 `Cluster_N/Master|Caves/server_log.txt`
- 触发词：DST mod、饥荒 mod、modmain、modinfo、AddPrefabPostInit 等

### 已创建专家
- `dst-mod-expert`（`~/.workbuddy/plugins/marketplaces/my-experts/plugins/dst-mod-expert/`）
- 类型：Agent | 分类：03-GameSpatial | 内嵌技能：dst-mod-dev
- 含 plugin.json、agents/dst-mod-expert.md、avatars/expert.png、skills/dst-mod-dev/
- 已通过 validate_expert.py + register_expert.py 注册
- 从左侧「专家」入口可进入对话

### 技能三副本路径（2026-11-21 核对）
- 用户级主库：`~/.workbuddy/skills/dst-mod-dev/`
- 市场包（专家包源头）：`~/.workbuddy/plugins/marketplaces/my-experts/plugins/dst-mod-expert/skills/dst-mod-dev/`
- 运行缓存：`~/.workbuddy/plugins/cache/my-experts/dst-mod-expert/1.0.0/skills/dst-mod-dev/`（⚠️ 带 `1.0.0` 版本层）
- 三份 SKILL.md 内容不同（历史演进），但都有 `### scripts/log_triage.py` 段，可作同步锚点

### 官方源码更新脚本（归入技能）
- `scripts/update_official_source.py`（三份技能副本均已放入），也可从项目 `参考代码/` 运行
- 用途：CRC 比对项目 `参考代码/官方源码/` 与游戏 `scripts.zip`，有变动才解压覆盖
- 关键：内置绝对 DEST 路径（`DST-H-MOD/参考代码/官方源码`），从任意目录/技能目录运行都对
- 只同步 `.lua`（保留本地 `fx/*.tex`），自动备份 + `.source_manifest.json` 基线 + 失败回滚
- 用法：`python scripts/update_official_source.py`（检测）/ 加 `--update`（更新）

### 创意工坊参考 MOD（2026-11-21）
- 只读来源：`C:/Program Files (x86)/Steam/steamapps/workshop/content/322330/<ID>/`（124 目录 / 99 有效 / 5.15GB）
- ID→名字表：`参考代码/MOD名单.md`，由 `scripts/sync_workshop_mods.py` 无参数生成（只读 modinfo，2 秒）
- 默认**只读不复制**；需要长期持有时 `--id <ID> --copy` → `参考MOD_ID/<ID>/`；更新用 `--id <ID> --update` / `--update-all`
- 旧 `参考代码/参考MOD/`（中文命名+嵌套分类+汉化）**保留不动**，非简单 workshop 副本
- 详细工作流：`docs/workshop_mod_reference_workflow.md`
- ⭐ **地标/传送跳转清单优先查** workshop `3638290455`（新版T键）：
  `scripts/TMIR/debug_commands/debug_commands_teleport_landmark.lua` 有全套森林/洞穴地标
  （DEFAULT_FOREST_ORDER / DEFAULT_CAVE_ORDER / TELEPORT_LANDMARK）；已记入技能 mod-patterns.md 三副本

### 踩坑记录
- 踩坑库主文件 `~/.workbuddy/skills/dst-mod-dev/references/pitfalls.md`（2026-11-21 已 67 条）
- ⚠️ 技能有 **3 份副本、3 套编号**：用户级主库（67 条 `## #N`）、市场包（36 条 `## N.`）、cache（32 条）。新增坑要同步 3 份，各按自己体系递增
- 核心坑概要：`Text` 需 `GLOBAL.require` | UI 图标用 `self.image:SetTint` | `GLOBAL.AddXxx` 会 strict 报错 | `finiteuses.Use` 无预检 | `globalmapicon._target` 客户端为 nil
- 2026-11-21 新增 #63~#67（全部围绕月眼面板 UI，详见下方专节）：Widget 无 DoTaskInTime/IsValid | 锚点无关的 world_scale 坐标 | 拖动防抖用起始快照 | 位置状态单一化 | 坐标语义改变要同步改命中判定

### 大容量容器 UI + 拖动（2026-11-21 定稿，hslot v3.8.10，已实测稳定）
- **完整流程写入技能** `references/large_container_ui.md`（三副本同步，9 章），同类需求先读它
- 扩容：抬 `containers.MAXITEMSLOTS`（两端顶层、SetPristine 前）；真容器 + 换 UI 最稳
- 挂载链：`containerroot.parent` → `hslot_vault_root`(SetScale GetHUDScale + hook SetHUDSize) → 面板(不设锚点不缩放) → gridroot(缩 0.6)
- 换皮：劫持 ContainerWidget.Open，**绝不 Hide widget**（GetOpenContainers 靠 IsVisible，藏了 Shift转移/制作材料全失效），只藏内容；格子用官方 `InvSlot`（ItemTile 空格会崩），零 RPC
- 布局：面板 440×420（10列×6行，原 680/15列×7行）；严格 6 行用 `peek_height=0` 且**绝不传 peek_percent**（它会覆盖 peek_height，peek_percent=1→peek=80 露出第7行）；gridroot (0,-6)（peek 80→0 上移24px，GRID_Y 补偿 +24）；scrollbar_height_offset=-50；面板收窄时筛选 x/数量 x/分隔线宽同步内收
- **拖动稳定三件套（缺一不可）**：
  ① world_scale 动态测量（临时挪 10 单位量 GetWorldPosition 变化，锚点无关）——抄简存 terminalwidget.lua:967-993
  ② 防抖用起始快照差值（StartDrag 存鼠标/面板起点，move 只算 delta×world_scale，全程不读实时世界坐标）——抄能力勋章 medal_globalfn.lua:540-568
  ③ **命中判定与①语义一致**：GetMouseLocal 返回「相对面板中心偏移」后，IsMouseOverPanel/Grid 必须直接 `abs(loc.x)`，**绝不能再减 self:GetPosition()**（重复减位置→只有角落响应）
- **位置状态单一化**：默认位置恒 (0,0)，只有一个 `_offset`；删除制作栏开/关让位 hook（两个 ApplyPos(true) 补间打架会让中键复位失效）
- 中键复位**独立于命中判定**：面板开着 anywhere 按中键都回中心；右键拖动才需 IsMouseOverPanel
- 出画面回中心：`IsCenterOffScreen()`（中心世界坐标超 [0,screen]±20）→ 打开首帧(延迟1帧)+EndDrag 各查一次，**不在 move 里查**
- 当前版本 3.8.10；改动必须三段式递增第三段

### UI 图标着色
- 完整模板已迁移至技能 `references/code-templates.md`
- 核心：`AnimState:SetMultColour()` 不影响 UI 图标 → 用 `self.image:SetTint()`

### DST 内置图标字符（PUA 字形，2026-11-15 实测）
- 游戏字体自带一套**私有区图标字形**（U+F0000 起）：背包/箱子/宝石/红心/箭头等
- 可用在 `Text`、`ImageButton:SetText`、`modinfo.description`、`STRINGS`，
  走字体 fallback 链，**和中文同排一行没问题**（mod 描述里「阿比盖尔 + 图标」就是它）
- 完整 50 条对照表：技能 `references/dst-icon-glyphs.md`（用户级 + 专家包 + cache 三份已同步）
- 常用几个（务必用**字节转义**，4 字节，防文件编码变动）：
  - 背包 `"\243\176\128\158"` | 箱子 `"\243\176\128\130"` | 红宝石 `"\243\176\128\146"`
  - 灯泡 `"\243\176\128\143"` | 点赞 `"\243\176\128\171"` | 手 `"\243\176\128\174"`
- ⚠️ 本文件旧版写的 `"\239\129\128\143"` 是**错的**（漏了首字节，只有 3 字节），
  实际都是 `\243\176\128\xxx` 四字节；字形来源见 `实验代码/modinfo.lua` 的中文描述区
- 做「图标 + 数字」布局时拼进同一个 `Text`，别用两个 Text 算 x 偏移（位数变化会错位）

---

## HSLOT 月眼地图揭示布景（2026-07-11 新增）

将橙/黄/紫色月眼的传送改为**在地图上展示布景位置**（模仿 messagebottle 的 `player_classified.revealmapspot` 机制）。

### 核心链路
```
server: player_classified.revealmapspot_worldx:set(x)
        player_classified.revealmapspot_worldz:set(z)  
        player_classified.revealmapspotevent:push()
client: OnRevealMapSpotEvent → HUD.controls:ShowMap(pos)
        4帧后 MapExplorer:RevealArea(x, y, z) 移除迷雾
```

### 找布景方式（双层搜索）
- **room 型**：`TheWorld.topology` 按房间名模糊匹配 → `node.cent`（官方 c_findroom 方式）
- **entity 型**：`TheSim:FindEntities` 仅用于有显式 `AddTag` 的实体（critterlab / pillar_atrium / pillar_ruins）
- **搜索配置格式**：`{ type="room", keyword="Moonbase", label="月亮石[地面]" }`

### 布景→房间名映射
| 月眼 | 地面 room | 洞穴 room |
|------|-----------|-----------|
| 🟡 黄 | `Moonbase`（MoonbaseOne） | `Altar`（AltarRoom） |
| 🟠 橙 | `critterlab`（显式 AddTag 搜实体） | `daywalker`（搜实体） |
| 🟣 紫 | `PigKing`（PigKingdom）→ `Deciduous`（DeciduousPond） | `Guarden`（RuinedGuarden/LabyrinthGuarden，内含WalledGarden）→ `ToadstoolArena` |

### 踩坑
- **`ShowMap` 不居中**：官方 `Controls:ShowMap` 检查 `not IsMapScreenOpen()`，地图已打开时不做居中 → 劫持 `ShowMap` 在传 `world_position` 时强制关地图重开
- **FindEntities 不可靠**：多数实体没有显式 `AddTag(prefab名)`，搜 prefab 名不可靠。用房间拓扑代替
- **`"save"` 事件不在 TheWorld 推送**：DST 实体保存数据走组件 `OnSave/OnLoad`，不是事件。持久化调用 `TheSim:SetPersistentString` 在每次揭示后立即写盘
- **纯 Lua 序列化**：`DataDumper+RunInSandbox` 和 `json.encode` 在 mod 环境可能不可用 → 用 `gmatch/match/tconcat` 自编序列化 `"uid=k1,k2|uid2=k1,k3"`

### 配置项
- `mooneye_map_reveal`：黄/橙/紫色月眼地图揭示布景位置（Boolean，默认 false）
- 与 `colormooneye_toggle`（开箱子）可同步触发，不再 elseif 互斥

模仿 wortox / wx78：在地图界面右键点击某实体的地图图标即触发传送/动作。

### 纯地图专属动作（推荐）—— `map_only` + `maponly_checkvalidpos_fn`

1. **定义 Action**：`GLOBAL.Action({ priority=10, rmb=true, mount_valid=true, encumbered_valid=true, map_only=true, map_works_on_unexplored=true, closes_map=true })`
2. **`maponly_checkvalidpos_fn`**（核心，跑在客户端）：用 `act:GetActionPoint()` 取点击点，用 `TheSim:FindEntities(pos, r, {"xxx_tag"})` 搜目标实体。**绝不能读 `globalmapicon._target`**（客户端恒为 nil）
3. **`fn`**（跑在服务端）：重新调用 `maponly_checkvalidpos_fn` 拿目标，执行传送 `doer.Physics:Teleport(x,y,z)`
4. **玩家 hook**：`AddPlayerPostInit` 中给 `playeractionpicker.pointspecialactionsfn` 赋值

### 关键事实
- `map_only` 的动作直接进地图动作槽；`map_action` 需配 `ACTIONS_MAP_REMAP`，纯地图传送用 `map_only` 最省事
- 官方 `mooneye.lua` 为六种月眼自动 `SpawnPrefab("globalmapicon")` 并 `TrackEntity`
- 让无地图图标的实体可点击：`inst:AddComponent("maprevealable"); inst.components.maprevealable:SetIconPrefab("globalmapicon")`
- 自定义标签可能不同步到客户端代理，需 `TheSim:FindEntities` 验证
- 相关源码：playercontroller.lua、actions.lua、wortox.lua、globalmapicon.lua、maprevealable.lua、mooneye.lua

---

## HSLOT 月眼地图传送改进（2026-07-18 新增）

### 传送过场动画（纯净 ScreenFade 黑屏过场，❌ 弃用 pocketwatch_warpback）
- **⚠️ 不要用 `pocketwatch_warpback` 状态图做过场**：该状态图（SGwilson.lua 第 20305 行）硬编码了 wanda 怀表特效（`pocketwatch_warpback_fx` / `pocketwatch_warpbackout_fx`）和声音（`wanda2/characters/wanda/watch/recall`，pst 状态 timeline），且渐隐仅在距离>30 触发 —— 做不到"只渐隐"。能力勋章 `medal_spacetime_runes`（medal_delivery.lua:276）其实也用它，所以勋章时空符文**本身也有** wanda 特效+声音（用户感知"干净"是因它是消耗品/近距离用完即毁）
- **现方案（客户端驱动纯净黑屏过场）**：
  - 客户端双击触发时本地 `ThePlayer:ScreenFade(false, 0.4)` 黑屏（屏幕效果本地，专用服务器也有效）+ `DoTaskInTime(0.6)` 兜底渐显
  - 服务端 RPC 直接 `player.Physics:Teleport`，再 `SendModRPCToClient(MOD_RPC["hslot_mooneye"]["teleport_done"], player)` 通知客户端
  - 客户端 `AddClientModRPCHandler("hslot_mooneye","teleport_done", fn)` 收到后 `ThePlayer:ScreenFade(true, 0.4)` 渐显
  - 移除原 `talker:Say("󰀏 󰀯")` 多余冒字

### 地图点击传送（RPC 模式）
- **触发方式**：左键双击（`button == 1000`），间隔 < 0.4 秒，位置差 < 20 像素
- **鼠标常量**：左键=1000，右键=1001
- **传送目标**：月眼 tag + 玩家 tag（排除自己 + 鬼魂），搜索范围 50
- **RPC**：`AddModRPCHandler("hslot_mooneye", "teleport_to_eye", fn)` + `SendModRPCToServer`
- **坐标转换**：`TheWorld.minimap.MiniMap:MapPosToWorldPos(screen_x, screen_y, 0)`
- **左键单击副作用**：会在地图放置标记（ping），双击放两个，但标记几秒后消失

---

## 背包探查器 HH（2026-07-11 新增）

### 方案 A：容器模式（当前使用）

**打开时**：`Unequip` NPC 装备 → `GiveItem` 移入容器 → `skipautoclose=true` → 玩家自由操作  
**关闭时**：遍历容器 slots → `Equip` 回装备位 / `GiveItem` 回物品栏 → `RemoveComponent("container")`  
**移动检测**：`DoPeriodicTask(0.1)` 检测玩家位置变化 > 3 单位 → `Close()`

### 方案 B：自定义 UI + RPC（已删除，代码保存至技能库）

**代码位置**：`~/.workbuddy/skills/dst-mod-dev/references/custom_ui_panel_ref.lua`  
**RPC 模式**：`AddModRPCHandler`（客户端→服务端）+ `SendModRPCToServer`  
**Widget 模式**：继承 `Widget` → `StartUpdating()` + `OnUpdate(dt)` → `Image` 组件渲染格子 → `TheInput:AddMouseButtonHandler` 处理点击  
**坐标坑**：`self.root` 以屏幕左下角为原点，`self.overlayroot` 以屏幕中心为原点  
**交互坑**：`TheInput` 鼠标坐标与 Widget 的 `GetWorldPosition()` 坐标系不一致，点击检测不准

### 简易存储的滚动列表参考（保留）
- 服务端创建 Lua 表模拟 `replica.container`/`replica.inventoryitem` 结构
- JSON 序列化 + `TheSim:EncodeAndZipString()` 压缩 → 发给客户端
- 客户端 `TheSim:DecodeAndUnzipString()` + `json.decode()` 还原
- 好处：不需要实体在客户端同步，可用作远程/跨世界物品显示

### 简易存储的滚动列表（未来 hslot 月眼空间用）

文件：`简易存储 3383078008/scripts/widgets/terminalscrolllist.lua`

**TrueScrollList 核心结构**：
```
Widget
├── bg (Image)          — 防焦丢失的填充图
├── scissored_root       — 裁剪区域（Widget）
│   └── list_root        — 滚动内容（Widget，y偏移实现滚动）
└── scrollbar            — 滚动条（自动构建）
```

**构造参数**：
```lua
TrueScrollList(context, create_widgets_fn, update_fn,
    scissor_x, scissor_y, scissor_width, scissor_height,
    scrollbar_offset, scrollbar_height_offset, scroll_per_click)
```

- `create_widgets_fn(context, list_root, self)` — 创建格子Widget并返回 `{widgets数组, 每行个数, 行高, 可见行数, 末尾偏移}`
- `update_fn(context, widgets, data, index)` — 更新单个格子内容
- `SetItemsData(data_arr)` — 设置数据源，自动计算 `end_pos`
- 滚动用 `CONTROL_SCROLLBACK` / `CONTROL_SCROLLFWD` 按键
- 全部格子都可见时自动隐藏滚动条

**适用场景**：格子数量远超屏幕显示范围时，比如月眼空间无限存储的格子列表。

