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
