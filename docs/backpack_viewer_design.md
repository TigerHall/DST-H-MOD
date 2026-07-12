# 背包探查器（HH）设计文档

> 目标：重构 `实验代码/` 为一个干净、可维护的 DST 背包探查 MOD

---

## 一、项目定位

一个 DST 装备物品，**右键点击任意有 `inventory` 组件的 NPC/动物**，打开一个弹窗容器，查看和操作其背包与装备。类似共享物品三维 mod 的交互，但锁定于单实体。

---

## 二、文件结构（重构目标）

```
实验代码/
├── modmain.lua          # 入口：容器参数 + 探查逻辑 + 配方 + 跑马灯 UI
├── modinfo.lua          # 配置项（Boolean 开关）
├── scripts/
│   └── prefabs/
│       ├── backpack_viewer.lua  # 物品预制体（equippable + spellcaster）
│       └── backpack_viewer_pool.lua  # [可选] 独立池容器实体
└── images/
    └── inventoryimages/
        ├── backpack_viewer.tex   # 自定义图标（64x64 DXT1 KTEX）
        └── backpack_viewer.xml   # 图标 atlas
```

---

## 三、核心逻辑

### 3.1 物品预制体（`backpack_viewer.lua`）

| 组件 | 作用 |
|------|------|
| `inventoryitem` | 可拾取、设置图标（`reskin_tool.tex` 或自定义 `backpack_viewer`） |
| `equippable` | 可装备，`onequip` 显示 `swap_reskin_tool` 手持动画 |
| `spellcaster` | `canuseontargets = true`，右键目标时调用 `spellfn` |

**spellfn**: `PushEvent("inspect_target", { target, caster })`

### 3.2 探查逻辑（`modmain.lua`）

`AddPrefabPostInit("backpack_viewer")` 注册 `inspect_target` 事件监听 → `OnInspectTarget`。

### 3.3 三种实现方案

#### 方案 A：直接容器（当前最简版本）

| 步骤 | 操作 |
|------|------|
| 打开 | `target:AddComponent("container")` → `WidgetSetup("backpack_viewer")` → `Open(caster)` |
| 交互 | DST 原生容器拖拽（物品在 NPC 的容器组件中） |
| 关闭 | 容器组件被自动移除（无归还逻辑，物品留在 NPC 容器中） |

**优点**：最简单，代码最少  
**缺点**：NPC 被添加了容器组件，关闭时物品不归原位的风险；无物品同步逻辑

#### 方案 A2：搬入/搬出（已实现过）

```
打开 → Unequip NPC 装备 + GiveItem 物品 → 移入容器（skipautoclose=true）
关闭 → 遍历容器 slots → Equip 回装备位 / GiveItem 回物品栏 → RemoveComponent("container")
移动检测 → DoPeriodicTask(0.1) 检查玩家位置 > 3 单位 → 自动 Close()
```

#### 方案 B：自定义 UI + RPC（已删除，代码见 `~/.workbuddy/skills/dst-mod-dev/references/custom_ui_panel_ref.lua`）

```
架构：
  - 服务端：AddModRPCHandler("hh", "inspect_action" / "inspect_close") 处理操作
  - 客户端：Widget 自绘面板，0.3s 轮询 replica 更新图标
  
交互流程：
  右键目标 → spellcaster → OnInspectTarget → 客户端打开面板
  玩家点击格子 → SendModRPCToServer → 服务端操作 NPC inventory
  客户端 0.3s 轮询目标 replica → 更新格子图标

Widget 设计：
  InspectPanel(Widget)
  ├── bg (半透明遮罩)
  ├── title ("探查")
  ├── close_btn ("X")
  ├── equip_slots[3]  (手/头/身)
  └── inv_slots[15]   (5x3 物品栏)
  
  点击检测：s.bg:GetWorldPosition() 对比鼠标坐标（坑：坐标系统不一致）
```

**踩坑记录**：
- DST HUD `root` 以屏幕**左下角**为原点，`overlayroot` 以屏幕**中心**为原点
- `TheInput:AddMouseButtonHandler` 的鼠标坐标与 Widget `GetWorldPosition()` 坐标系不一致
- `self.image:SetTint()` 用于图标着色（非 `AnimState:SetMultColour`）

#### 方案 C：共享池模式（中间版本，冲突最多）

```
创建独立池实体（backpack_viewer_pool）→ SpawnPrefab 副本放入池 → 事件同步
NPC 物品永不动，池里放副本展示

同步方向：
  玩家拿副本 → pool:onitemlose → 删 NPC 原物
  玩家放物品 → pool:itemget → 给 NPC
  NPC 捡东西 → NPC:itemget → 补副本到池
  NPC 丢东西 → NPC:itemlose → 删池中对应副本
  NPC 换装 → NPC:equip/unequip → 刷新池中装备槽

反重入：syncing[pool] 标记防止事件循环
```

---

## 四、容器参数设计

```lua
-- 5x4 网格（fish box 贴图）
local params = containers.params
params.backpack_viewer = {
  widget = {
    slotpos = { 20 个坐标, 5 列 4 行 },
    slotbg  = { [16]=手装备, [17]=头装备, [18]=身装备, 其余=nil },
    animbank = "ui_fish_box_5x4",
    animbuild = "ui_fish_box_5x4",
    pos = Vector3(0, 220, 0),
    side_align_tip = 160,
    buttons = { { text="关闭", position=Vector3(0,-130,0), ... } },
  },
  type = "backpack_viewer",
  itemtestfn = function(container, item, slot)
    -- slot 16-18 只接受对应装备类型
    -- 其他 slot 接受任何有 inventoryitem 的物品
  end,
}
```

### 装备槽布局方案演变

| 版本 | 装备位置 | 理由 |
|------|---------|------|
| v1 | slot 1-3 | 最前面三格 |
| v2 | slot 18-20 | 最后一行最后三格（用户要求） |
| v3 | slot 16-18 | 最后一行前三格 |

当前参数使用 v3（slot 16-18 = 手/头/身）。

---

## 五、关键踩坑

| # | 坑 | 说明 | 解决方案 |
|---|----|------|---------|
| 1 | `AddRecipe2` 参数顺序 | atlas/image 在 opts 表内，不是位置参数 | `{ atlas = "...", image = "..." }` |
| 2 | XML 元素名匹配 | `Element name` 必须等于 `imagename`，不是文件名 | `name="backpack_viewer"` 而非 `"backpack_viewer.tex"` |
| 3 | `EQUIP_SLOT_MAP` 作用域 | `itemtestfn` 闭包中引用，必须在 params 定义前声明 | 移到文件头部 |
| 4 | 容器 `readonly` | `container.readonlycontainer = true` 被 `makereadonly` 锁定 | 用 `replica.container:EnableReadOnlyContainer(bool)` |
| 5 | 客户端容器 UI | `INLIMBO` 实体也能渲染容器 UI（通过 classified 复制体） | 池实体可以 INLIMBO |
| 6 | 双击右键 | 地图点击太灵敏 | 双击检测（0.22s 内两次点击）+ 坐标差 >10px 排除拖拽 |
| 7 | Spellcaster 右键 | 需 `canuseontargets=true` + 装备在手上 | 原生支持，无需额外 Action |
| 8 | `AddClassPostConstruct("widgets/itemtile")` | 劫持所有 ItemTile，如果其他 MOD 改了内部结构会崩溃 | 加 `self.image == nil` 和 `self.inst == nil` 防御检查 |

---

## 六、配置项

`modinfo.lua` 只有一个 Boolean 开关：

```lua
configuration_options = {
  addConfig("backpack_viewer_enable", "...", "...", true, "...", "...", "...", "...")
  -- 其他配置项：可扩展 UI 模式选择等
}
```

---

## 七、推荐重构路径

```
Phase 1（当前）→ 方案 A（直接容器，可开可关）
    ↓
Phase 2 → 方案 A2（搬入搬出，物品归位）
    ↓
Phase 3 → 副本池模式（NPC 物品永不动，事件驱动同步）
    ↓
Phase 4 → 方案 B 自定义 UI（全可控，但 Widget 调试成本高）
```

建议从 Phase 1（当前代码）出发，逐步升级。

---

## 八、代码参考文件

- 自定义 UI 模板：`~/.workbuddy/skills/dst-mod-dev/references/custom_ui_panel_ref.lua`
- DST 技能踩坑库：`~/.workbuddy/skills/dst-mod-dev/references/pitfalls.md`
- DST 技能代码模板：`~/.workbuddy/skills/dst-mod-dev/references/code-templates.md`
- 简易存储滚动列表：`参考代码/参考MOD/简易存储 3383078008/scripts/widgets/terminalscrolllist.lua`
- 共享物品三维同步：`参考代码/参考MOD/共享物品三维/3014871969/modmain.lua`（`copyItem` + `onUpdateInventory`）
