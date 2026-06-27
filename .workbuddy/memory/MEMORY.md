# DST-H-MOD 项目记忆

## 项目约定

### 版本管理

- 每次对 `modinfo.lua` 做任何配置修改后，必须同时更新 `version` 字段（如 `"3.3"` → `"3.4"`），否则已安装 MOD 的玩家不会自动同步更改
- 版本号格式：主版本.次版本（如 `"3.4"`）

### 目录联接 (Junction)

- GitHub 项目与 DST 游戏 `mods/` 目录通过 `mklink /J`（或 `New-Item -ItemType Junction`）建立联接，实现修改即同步

### 模块映射（用户报错前缀 → GitHub 目录名，硬链接对应）

- `hcane` = "行走手杖优化"
- `hslot` = "格子优化"
- `hfood` = "零食优化"
- `htree` = "水中木优化"
- `htable` = "茶几优化"
- `hpack` = "背包优化"
- `hh` = "实验代码"

### 各 MOD 功能触发方式（无键盘快捷键）

- `hcane` 行走手杖优化：**右键使用**手杖切换总开关（`useableitem` 组件 `SetOnUseFn`）
- `hslot` 格子优化：**右键检查**物品（劫持 `inspectable.GetDescription`）触发格子开关/月眼传送
- `hpack` 背包优化：**装备/卸下**事件监听，自动触发防御、保鲜、自动采集
- `hfood` 零食优化：纯数值修改（`edible` 组件属性翻倍），无玩家交互
- `htree` 水中木优化：纯属性修改 + 事件监听，无玩家交互
- `htable` 茶几优化：纯属性修改，无玩家交互
- 6 个 MOD 均无 `TheInput`/`AddKeyUpHandler`/`KEY_` 等键盘快捷键代码

### 代码风格

- 使用 `AddPrefabPostInit` + 闭包结构
- 用 `local config = { ... }` 统一读取配置
- 中文注释标注每个功能块
- 所有定时任务在 `onremove` 事件中清理

### 配置项规范

- 所有 MOD 的配置项有且仅有两种类型：
  1. **是否选项（Boolean）**：使用 `addConfig()` 辅助函数，生成 On/Off 两个选项
  2. **多选项（Multi-option）**：在 `configuration_options` 中直接写 `options = { ... }` 数组，自行指定 `default`
- 任何配置修改后必须更新 `version`

## DST UI 图标着色与文字叠加

### 核心原理

**修改实体 `inst.AnimState:SetMultColour()` 不会影响背包/装备栏 UI 图标。** ItemTile 用自己的独立 `Image` widget 渲染图标，不读取实体 AnimState 颜色。

正确做法（参考 Insight 2189004162）：**直接操作 ItemTile Widget**，调用 `self.image:SetTint()`。

### 客户端方案模板

```lua
if not GLOBAL.TheNet:IsDedicated() then
  local Text = GLOBAL.require("widgets/text")      -- modmain.lua 中没有 Text 全局变量！
  local Image = GLOBAL.require("widgets/image")    -- 同理
  local NUMBERFONT = GLOBAL.NUMBERFONT

  AddClassPostConstruct("widgets/itemtile", function(self, invitem)
    if invitem.prefab ~= "目标_prefab" then return end

    -- 图标着色（Insight 同款方式）
    self.image:SetTint(r, g, b, a)

    -- 文字叠加（仿 DST stack count / percentage 系统）
    local label = self:AddChild(Text(NUMBERFONT, 字号))
    label:SetPosition(x, y, 0)
    label:SetString("文字")

    -- 定期刷新，检查服务端标签判断状态
    local task = self.inst:DoPeriodicTask(间隔秒, function()
      if self.item and self.item:HasTag("某标签") then
        -- ON 状态的 UI
      else
        -- OFF 状态的 UI
      end
    end)

    -- 务必清理
    self.inst:ListenForEvent("onremove", function()
      if task then task:Cancel() end
      if label then label:Kill() end
    end)
  end)
end
```

### 服务端 → 客户端通信

- **标签（Tag）**：`inst:AddTag("xxx")` / `inst:RemoveTag("xxx")`，自动同步到客户端，客户端用 `inst:HasTag("xxx")` 检测。简单但有延迟，需要轮询。
- **net_bool**：`GLOBAL.net_bool(guid, "key", "dirty_event")`，值变化时自动推事件，客户端监听可实现零轮询。需要 `AddComponentPostInit` 修改 inventoryitem_replica，更复杂但更正统。

### 常见坑

| 坑 | 原因 | 解法 |
|----|------|------|
| `Text` 是 nil | modmain.lua 没有 `Text`/`Image` 全局变量 | `GLOBAL.require("widgets/text")` |
| `SetMultColour` 不染色 UI 图标 | ItemTile 用独立 Image，不读 AnimState | 直接 `self.image:SetTint()` |
| 配置关闭后图标/名称未恢复 | 切换逻辑只在 toggle 回调中，不在 UpdateAllFeatures | 将图标/名称切换抽成独立函数，加入 UpdateAllFeatures，内部判断 config OFF 时恢复默认值 |
| `ChangeImageName` 不即时刷新 | ItemTile 的 Image 只在 RebuildLayout 时重建，运行时改 imagename 不会触发 Widget 重绘。**右键切换后要移动物品到其他格子才刷新** | 避免用 `ChangeImageName` 做实时图标切换，考虑用 `self.image:SetTint()` 或叠加层代替 |
| 皮肤贴图被硬编码默认值覆盖 | `_cane_default_imagename = "cane"` 写死了无皮肤版 | 从 `invitem.imagename` / `invitem.atlasname` 动态读取创建时的实际值 |

### 文字标签中插入 DST 图标

使用 UTF-8 转义：`"\239\129\128\143"` = `󰀏`，`"\239\129\128\156"` = `󰀜`

### 呼吸灯绿底分析

ItemTile 的绿色光晕（`Image` widget + `SetTint`）要实现呼吸效果，可选方案：

| 方案 | 做法 | 优缺点 |
|------|------|--------|
| **α 正弦波** | 用 `DoPeriodicTask(0.05)` 高频更新 glow 的 alpha，`alpha = 0.3 + 0.2 * sin(time * 3)` | 轻量纯代码，无需额外资源。唯一缺点：CPU 略增（20fps × 1 widget，可忽略） |
| **UIAnim 动画** | 仿潮湿蓝框，创建自定义 bank/build 动画文件 | 最省 CPU，但需要制作动画资源（bank/build/anim），流程繁琐 |
| **改用 AddColour** | 服务端 cane 实体已有呼吸 `SetAddColour`，客户端 ItemTile 用 `image:SetTint` 时叠加 add 通道不可行（Image 不支持 AddColour） | 不可行 |

最实际的是 α 正弦波方案，需要在现有的 0.5s 轮询之外另起一个高频 DoPeriodicTask（0.03~0.05s），并在 `onremove` 时取消。

### 底光呼吸 + z-order 参考代码（手杖已废弃，备查）

```lua
-- 添加底光 Image（挂到 self.bg 不行——被其他 MOD 移除了，改用 self + 手动排序）
self._cane_glow = self:AddChild(Image("images/hud.xml", "inv_slot.tex"))
self._cane_glow:SetClickable(false)
self._cane_glow:SetTint(1, 1, 1, 0.4)       -- 白色底光
self._cane_glow:SetScale(1.1, 1.1, 1)
self._cane_glow:Hide()
-- 将 glow 挪到 image 下层渲染
do
  local children = self.children
  local glow_idx, img_idx = nil, nil
  for i, child in ipairs(children) do
    if child == self.image then img_idx = i end
    if child == self._cane_glow then glow_idx = i end
  end
  if glow_idx and img_idx and glow_idx > img_idx then
    table.remove(children, glow_idx)
    table.insert(children, img_idx, self._cane_glow)
  end
end

-- 呼吸灯 α 正弦波
local breath_task = nil
local function StartBreath()
  if breath_task then breath_task:Cancel() end
  local t0 = GLOBAL.GetTime()
  breath_task = self.inst:DoPeriodicTask(0.04, function()
    if not self._cane_glow or not self._cane_glow.shown then
      breath_task:Cancel(); breath_task = nil; return
    end
    local alpha = 0.1 + 0.4 * math.sin((GLOBAL.GetTime() - t0) * 3)
    self._cane_glow:SetTint(1, 1, 1, alpha)
  end)
end

-- 清理时必须 Cancel
self.inst:ListenForEvent("onremove", function()
  if breath_task then breath_task:Cancel() end
  if self._cane_glow then self._cane_glow:Kill(); self._cane_glow = nil end
end)
```

### 文字跑马灯参考代码（当前在用）

```lua
-- HueToRGB 必须在当前闭包内定义（服务端的 local function 客户端访问不到）
local function HueToRGB(hue)
  local r = (math.sin(hue) + 1) / 2
  local g = (math.sin(hue + 2.094) + 1) / 2
  local b = (math.sin(hue + 4.189) + 1) / 2
  return r, g, b
end

local COLOR_CYCLE_SPEED = 3.2  -- 跑马灯周期（秒）
local color_task = nil
local color_time = 0

local function StartColorCycle()
  if color_task then color_task:Cancel() end
  color_time = 0
  color_task = inst:DoPeriodicTask(0.05, function()
    color_time = color_time + 0.05
    if label and label.shown then
      local hue = color_time * 2 * math.pi / COLOR_CYCLE_SPEED
      local cr, cg, cb = HueToRGB(hue)
      label:SetColour(cr, cg, cb, 1)
    end
  end)
end
```
