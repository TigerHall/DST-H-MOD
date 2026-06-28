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

| 坑                             | 说明                                                                                                                               |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| `Text` 是 nil                  | modmain.lua 无此全局变量 → `GLOBAL.require("widgets/text")`                                                                        |
| `SetMultColour` 不染色 UI 图标 | ItemTile 用独立 Image 渲染 → 直接 `self.image:SetTint()`                                                                           |
| `ChangeImageName` 不即时刷新   | ItemTile 只在 RebuildLayout 重建 Image → 右键切换后需移动物品才刷新                                                                |
| net_bool dirty 事件不到 Widget | dirty 是网络层内部事件，不会自动 PushEvent 到 Widget → 需要 `AddComponentPostInit("inventoryitem_replica")` 显式转发，或直接用轮询 |
| `ChangeImageName` 同值不触发   | netvar 值没变，客户端收不到任何事件                                                                                                |
| 皮肤贴图被硬编码覆盖           | `"cane"` 写死无皮肤版 → 从 `invitem.imagename` 动态读                                                                              |
| 配置关闭后图标/名称未恢复      | 切换逻辑不在 UpdateAllFeatures → 抽成独立函数加入统一调度                                                                          |
| `HueToRGB` 客户端不可用        | 是服务端闭包内的 local function → 客户端单独复制一份                                                                               |
| `self.bg` 可能被其他 MOD 移除  | 不可靠 → 用 `self:AddChild` + 手动 `table.remove/insert` 调 z-order                                                                |
| `finiteuses.Use` 无耐久预检   | `Use(n)` 直接 `SetUses(current - n)`，没有 `if current < n then return` 的检查——即使耐久不够也会执行动作然后碎掉                |

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
```
