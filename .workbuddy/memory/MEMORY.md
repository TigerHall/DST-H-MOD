# DST-H-MOD 项目记忆

## 项目约定

### 版本管理
- 每次修改 `modinfo.lua` 必须更新 `version`，否则玩家不会自动同步
- 格式：主版本.次版本

### 目录联接
- GitHub ↔ DST `mods/` 通过 `mklink /J` 联接，修改即同步

### 模块映射
- `hcane` = 行走手杖优化 | `hslot` = 格子优化 | `hfood` = 零食优化
- `htree` = 水中木优化 | `htable` = 茶几优化 | `hpack` = 背包优化 | `hh` = 实验代码
- `hreturn` = 离线物品回收（离线玩家物品托管 + 到期生成归还箱）
- `hpaper` = 制图桌回收（擦除记忆+重制，全服共享，仿陶轮 craftingstation 机制）

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
- 包含：踩坑库 `references/pitfalls.md`、代码模板 `references/code-templates.md`、API 速查 `references/api-quick-reference.md`、MOD 模式索引 `references/mod-patterns.md`
- 触发词：DST mod、饥荒 mod、modmain、modinfo、AddPrefabPostInit 等

### 已创建专家
- `dst-mod-expert`（`~/.workbuddy/plugins/marketplaces/my-experts/plugins/dst-mod-expert/`）
- 类型：Agent | 分类：03-GameSpatial | 内嵌技能：dst-mod-dev
- 含 plugin.json、agents/dst-mod-expert.md、avatars/expert.png、skills/dst-mod-dev/
- 已通过 validate_expert.py + register_expert.py 注册
- 从左侧「专家」入口可进入对话

### 踩坑记录
- 完整踩坑库已迁移至技能 `references/pitfalls.md`（14 条）
- 核心坑概要：`Text` 需 `GLOBAL.require` | UI 图标用 `self.image:SetTint` | `GLOBAL.AddXxx` 会 strict 报错 | `finiteuses.Use` 无预检 | `globalmapicon._target` 客户端为 nil

### UI 图标着色
- 完整模板已迁移至技能 `references/code-templates.md`
- 核心：`AnimState:SetMultColour()` 不影响 UI 图标 → 用 `self.image:SetTint()`
- 文字/图标中插入 DST 内置图标：`"\239\129\128\143"` = 󰀏 | `"\239\129\128\156"` = 󰀜

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

