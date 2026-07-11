-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })

-- 获取配置项
local config = {
  backpack_viewer_enable = GetModConfigData("backpack_viewer_enable"),
}

-- 实体/特效引用
PrefabFiles = {
  "backpack_viewer",
}

Assets = {
  Asset("ANIM", "anim/reskin_tool.zip"),
  Asset("ANIM", "anim/swap_reskin_tool.zip"),
}

-- 名字和检查描述字符串
STRINGS.NAMES.BACKPACK_VIEWER = "󰀞 实体背包探查器 󰀏 󰀅"
STRINGS.RECIPE_DESC.BACKPACK_VIEWER = "探查任意实体的背包和装备"

--------------------------------------------------------------------------
-- 容器配置
--------------------------------------------------------------------------

local containers = require("containers")
local params = containers.params

-- 装备槽背景图映射（DST hud.xml 内置贴图）
local EQUIP_BG = {
  ["hands"] = { atlas = "images/hud.xml", image = "equip_slot.tex" },
  ["head"]  = { atlas = "images/hud.xml", image = "equip_slot_head.tex" },
  ["body"]  = { atlas = "images/hud.xml", image = "equip_slot_body.tex" },
}

local EQUIP_SLOT_MAP = {
  [1] = EQUIPSLOTS.HANDS,
  [2] = EQUIPSLOTS.HEAD,
  [3] = EQUIPSLOTS.BODY,
}

local INSPECTION_NUMSLOTS = 20 -- 5x4

-- 构建 slotbg 数组
local function BuildInspectionSlotBG(num_total)
  local bg = {}
  for i = 1, num_total do
    if i == 16 then
      bg[i] = EQUIP_BG["hands"]
    elseif i == 17 then
      bg[i] = EQUIP_BG["head"]
    elseif i == 18 then
      bg[i] = EQUIP_BG["body"]
    else
      bg[i] = nil
    end
  end
  return bg
end

-- 注册容器参数
params.backpack_viewer = {
  widget = {
    slotpos = {},
    slotbg = BuildInspectionSlotBG(INSPECTION_NUMSLOTS),
    animbank = "ui_fish_box_5x4",
    animbuild = "ui_fish_box_5x4",
    pos = Vector3(0, 220, 0),
    side_align_tip = 160,
  },
  type = "backpack_viewer",
  itemtestfn = function(container, item, slot)
    if item == nil or item.components.inventoryitem == nil then return false end
    if slot ~= nil and EQUIP_SLOT_MAP[slot] ~= nil then
      return item.components.equippable ~= nil
          and item.components.equippable.equipslot == EQUIP_SLOT_MAP[slot]
    end
    return true
  end,
}

-- fish box 的 5x4 格子布局
for y = 2.5, -0.5, -1 do
  for x = -1, 3 do
    table.insert(params.backpack_viewer.widget.slotpos,
      Vector3(75 * x - 75 * 2 + 75, 75 * y - 75 * 2 + 75, 0))
  end
end

--------------------------------------------------------------------------
-- 背包探查器核心逻辑
-- 方案 A（最初）：把 NPC 物品移入临时容器 → 玩家操作 → 关闭时归还
--------------------------------------------------------------------------

local function OnInspectTarget(inst, data)
  if not config.backpack_viewer_enable or not data then return end
  local target, caster = data.target, data.caster
  if not target or not target:IsValid() or not caster or not caster:IsValid() then return end
  if not target.components.inventory then return end
  if target == caster then return end

  -- 已有容器 → 关闭
  if target.components.container then
    target.components.container:Close(caster)
    return
  end

  -- 添加临时容器
  target:AddComponent("container")
  target.components.container:WidgetSetup("backpack_viewer")
  target.components.container:Open(caster)
end

--------------------------------------------------------------------------
-- 给背包探查器挂载事件处理
--------------------------------------------------------------------------

if config.backpack_viewer_enable then
  AddPrefabPostInit("backpack_viewer", function(inst)
    if not TheWorld.ismastersim then
      return inst
    end
    inst:ListenForEvent("inspect_target", OnInspectTarget)
  end)
end

--------------------------------------------------------------------------
-- 合成配方
--------------------------------------------------------------------------

if config.backpack_viewer_enable then
  AddRecipe2("backpack_viewer", {
    Ingredient("twigs", 2),
  }, TECH.NONE)
end
