# DST-H-MOD 项目记忆

## 项目约定

### 版本管理

- 每次修改 `modinfo.lua` 必须更新 `version`（如 `"3.3"` → `"3.4"`），否则玩家不会自动同步
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

## DST UI 图标着色与文字叠加

### 核心原理

**实体 `AnimState:SetMultColour()` 不影响背包/装备栏 UI 图标。** ItemTile 用自己的 `Image` widget 渲染，正确做法是直接调 `self.image:SetTint()`（参考 Insight 2189004162）。

### 客户端模板

```lua
if not GLOBAL.TheNet:IsDedicated() then
  local Text = GLOBAL.require("widgets/text")      -- modmain.lua 无此全局变量！
  local Image = GLOBAL.require("widgets/image")
  local NUMBERFONT = GLOBAL.NUMBERFONT

  AddClassPostConstruct("widgets/itemtile", function(self, invitem)
    if invitem.prefab ~= "目标" then return end

    -- 图标着色
    self.image:SetTint(r, g, b, a)

    -- 文字叠加（仿 DST stack count / percentage）
    local label = self:AddChild(Text(NUMBERFONT, 字号))
    label:SetPosition(x, y, 0)

    -- 轮询检测状态变化并跳过无变化帧
    local function Update()
      local is_on = self.item and self.item:HasTag("xxxtag")
      if is_on == self._last_state then return end  -- 无变化跳过
      self._last_state = is_on
      -- 按状态设置 UI...
    end
    Update()
    local task = self.inst:DoPeriodicTask(0.5, Update)
    self.inst:ListenForEvent("onremove", function()
      if task then task:Cancel() end
      if label then label:Kill() end
    end)
  end)
end
```

### 文字/图标中插入 DST 内置图标

`"\239\129\128\143"` = `󰀏` | `"\239\129\128\156"` = `󰀜`

---

## 踩坑记录

| 坑                                          | 说明                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Text` 是 nil                               | modmain.lua 无此全局变量 → `GLOBAL.require("widgets/text")`                                                                                                                                                                                                                                                                                                                                                                                            |
| `SetMultColour` 不染色 UI 图标              | ItemTile 用独立 Image 渲染 → 直接 `self.image:SetTint()`                                                                                                                                                                                                                                                                                                                                                                                               |
| `ChangeImageName` 不即时刷新                | ItemTile 只在 RebuildLayout 重建 Image → 右键切换后需移动物品才刷新                                                                                                                                                                                                                                                                                                                                                                                    |
| net_bool dirty 事件不到 Widget              | dirty 是网络层内部事件，不会自动 PushEvent 到 Widget → 需要 `AddComponentPostInit("inventoryitem_replica")` 显式转发，或直接用轮询                                                                                                                                                                                                                                                                                                                     |
| `ChangeImageName` 同值不触发                | netvar 值没变，客户端收不到任何事件                                                                                                                                                                                                                                                                                                                                                                                                                    |
| 皮肤贴图被硬编码覆盖                        | `"cane"` 写死无皮肤版 → 从 `invitem.imagename` 动态读                                                                                                                                                                                                                                                                                                                                                                                                  |
| 配置关闭后图标/名称未恢复                   | 切换逻辑不在 UpdateAllFeatures → 抽成独立函数加入统一调度                                                                                                                                                                                                                                                                                                                                                                                              |
| `HueToRGB` 客户端不可用                     | 是服务端闭包内的 local function → 客户端单独复制一份                                                                                                                                                                                                                                                                                                                                                                                                   |
| `self.bg` 可能被其他 MOD 移除               | 不可靠 → 用 `self:AddChild` + 手动 `table.remove/insert` 调 z-order                                                                                                                                                                                                                                                                                                                                                                                    |
| `finiteuses.Use` 无耐久预检                 | `Use(n)` 直接 `SetUses(current - n)`，没有 `if current < n then return` 的检查——即使耐久不够也会执行动作然后碎掉                                                                                                                                                                                                                                                                                                                                       |
| `GLOBAL.locale` 触发 strict 报错            | DST strict 模式不认 `locale` 这个全局字段，`GLOBAL.locale` 会报 "variable 'locale' is not declared"。取当前语言用 `GLOBAL.LanguageTranslator and GLOBAL.LanguageTranslator.defaultlang`（参考官方 fonts.lua:37，返回 "zh"/"zhr"/"zht"/"en" 等）                                                                                                                                                                                                        |
| `GLOBAL.AddXxx` 触发 strict 报错            | `AddAction`/`AddPrefabPostInit`/`AddPlayerPostInit`/`AddClassPostConstruct` 等是注入到 mod 环境（modenv）的全局函数，直接调用即可，加 `GLOBAL.` 前缀会因该字段不在主 `GLOBAL` 表而报 "variable 'Xxx' is not declared"。而 `Action`/`ACTIONS_MAP_REMAP`/`TheSim`/`TheWorld`/`SpawnPrefab`/`Vector3`/`BufferedAction`/`LanguageTranslator` 等是主游戏 `_G` 全局，用 `GLOBAL.` 访问。原则：mod 辅助 API 直接调，游戏内建全局用 `GLOBAL.`                  |
| `globalmapicon` 代理 `_target` 客户端为 nil | `globalmapicon` 是 `SetIsProxy(true)` 实体，客户端只拿到代理；`_target` 仅在服务端 `TrackEntity` 时设置，客户端恒为 nil。`GetMapActions`/`pointspecialactionsfn`/`maponly_checkvalidpos_fn` 都跑在**客户端**，读 `_target` 会永远匹配不上（本 MOD 初版因此"点击完全无反应"）。正确做法：给目标实体本身 `AddTag("xxx")` 打标签，直接 `TheSim:FindEntities(pos, r, {"xxx"})` 搜实体本体（客户端/服务端通用，实体就在点击点位置），别读图标的 `_target`。 |
| 自定义标签可能不复制到客户端代理 | `globalmapicon`/`CLASSIFIED` 等官方标签能复制到代理，但 MOD 通过 `AddPrefabPostInit` 在服务端添加的自定义标签（如 `h_mooneye_icon`）是否同步到客户端代理不确定。本 MOD vault_orb 方案（给图标打 `h_mooneye_icon` 标签）在客户端搜不到该标签的实体 → 动作不返回。测试方式：游戏内 `TheSim:FindEntities(0,0,0,9999,{"h_mooneye_icon"})` 看客户端能否搜到。若搜不到 → 标签未同步。 |

---

## 参考代码（备查）

### 底光呼吸 + z-order（已废弃，可复用）

```lua
self._glow = self:AddChild(Image("images/hud.xml", "inv_slot.tex"))
self._glow:SetTint(1, 1, 1, 0.4)
-- 手动挪到 self.image 下层
do
  local c = self.children; local gi, ii
  for i, ch in ipairs(c) do
    if ch == self.image then ii = i elseif ch == self._glow then gi = i end
  end
  if gi and ii and gi > ii then table.remove(c, gi); table.insert(c, ii, self._glow) end
end
-- α 正弦波呼吸
local bt; local function StartB()
  if bt then bt:Cancel() end; local t0 = GLOBAL.GetTime()
  bt = self.inst:DoPeriodicTask(0.04, function()
    if not self._glow or not self._glow.shown then bt:Cancel(); bt = nil; return end
    self._glow:SetTint(1, 1, 1, 0.1 + 0.4 * math.sin((GLOBAL.GetTime() - t0) * 3))
  end)
end
```

### 文字跑马灯（当前在用）

```lua
local function HueToRGB(h)  -- 客户端闭包内必须本地定义
  return (math.sin(h)+1)/2, (math.sin(h+2.094)+1)/2, (math.sin(h+4.189)+1)/2
end
local ct = 0; local COLOR_CYCLE_SPEED = 4.0
local task = inst:DoPeriodicTask(0.05, function()
  ct = ct + 0.05
  if label and label.shown then
    local hue = ct * 2 * math.pi / COLOR_CYCLE_SPEED
    label:SetColour(HueToRGB(hue))
  end
end)

---

## DST MOD 地图点击传送（可复用模式）

模仿 wortox / wx78：在地图界面右键点击某实体的地图图标即触发传送/动作。

### 纯地图专属动作（推荐，本 MOD 采用）—— `map_only` + `maponly_checkvalidpos_fn`
适合“只在地图上点击图标才触发”的传送。直接照搬官方 `DIRECTCOURIER_MAP` / `SWAPBODIES_MAP`。

1. **定义 Action**：`GLOBAL.Action({ priority=10, rmb=true, mount_valid=true, encumbered_valid=true, map_only=true, map_works_on_unexplored=true, closes_map=true })`，设 `.id`/`.str`/`.fn`。
2. **`maponly_checkvalidpos_fn`**（核心）：赋给 `MY_ACTION.maponly_checkvalidpos_fn = function(act)`，返回 `(valid, reason, x, z, mapent)`。
   - 用 `act:GetActionPoint()` 取点击点（该 `act` 是由 `pointspecialactionsfn` 经 `SortActionList` 包成的 `BufferedAction`，`pos` 即地图点击坐标）。
   - **客户端陷阱**：`globalmapicon` 是 `SetIsProxy(true)` 的代理实体，其 `_target` 在客户端恒为 nil（只有服务端 `TrackEntity` 设过）。`maponly_checkvalidpos_fn`/`pointspecialactionsfn` 都跑在客户端，**绝不能读 `_target`**。正确做法：给目标实体本身 `AddTag("xxx")` 打标签，直接 `TheSim:FindEntities(pos, r, {"xxx"})` 搜实体本体（客户端/服务端通用，实体就在点击点位置）。**注意**：自定义标签（如 MOD 添加的 `h_mooneye_icon`）在服务端加在 `globalmapicon` 实体上后，不确定是否会同步到客户端代理——官方标签（`globalmapicon`/`CLASSIFIED`）会，但自定义标签可能不会。需游戏内 `TheSim:FindEntities` 验证标签是否存在。
3. **`fn`**：重新调用 `maponly_checkvalidpos_fn(act)` 拿到目标，执行实际逻辑（跑在服务端）。
4. **玩家 hook**：`AddPlayerPostInit` 中给 `inst.components.playeractionpicker.pointspecialactionsfn` 赋值（先存 `old_fn` 并回退）。
   约定：`function(player, pos, useitem, right)` → 当 `right and useitem==nil and player.checkingmapactions and 附近有目标` 时 `return { MY_ACTION }`，否则回退 `old_fn`。
   - 坑：`GetMapActions` 只会收集 `v.action.map_only` 的动作进地图动作槽；若动作用了 `map_action=true`（非 `map_only`），必须再配 `ACTIONS_MAP_REMAP` 且由普通右键动作触发，纯地图传送用 `map_only` 最省事（本 MOD 最初用 `map_action` 导致动作被丢弃、完全不生效）。

### 关键事实
- 地图动作经由 `PlayerController:GetMapActions` → `RemapMapAction` 处理；`map_only` 分支用 `maponly_checkvalidpos_fn` 校验并取坐标，`map_action` 分支走 `ACTIONS_MAP_REMAP[code]`。
- 官方 `mooneye.lua` 已为放置的**所有六种**彩色月眼（`yellow/orange/purple/green/red/bluemooneye`）自动 `SpawnPrefab("globalmapicon")` 并 `TrackEntity`，天然就是可点击地图图标，无需额外代码。
- 想让没有地图图标的实体（如 `moonrockcrater`）也可点击：服务端 `inst:AddComponent("maprevealable"); inst.components.maprevealable:SetIconPrefab("globalmapicon")`。
- `globalmapicon` 实体带 `globalmapicon`/`CLASSIFIED` 标签；服务端 `TrackEntity` 会设 `._target`，但**客户端代理的 `_target` 为 nil**，不要依赖它做客户端侧判断。
- 兼容所有角色：传送用 `doer.Physics:Teleport(x,y,z)`，不要依赖特定角色状态机（如 `portal_jumpin`）。
- 相关官方源码：playercontroller.lua（GetMapActions / RemapMapAction）、actions.lua（DIRECTCOURIER_MAP.maponly_checkvalidpos_fn 范例）、wortox.lua（pointspecialactionsfn）、globalmapicon.lua、maprevealable.lua、mooneye.lua（六种月眼自动 globalmapicon）。
```
