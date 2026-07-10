-- scripts/prefabs/hslot_container.lua
-- 口袋空间容器合集：hslot（古董船4x4）+ 紫/橙/黄月眼（鱼箱5x4）

local function OnAnyOpenStorage(inst, data)
  if inst.components.container.opencount > 1 then
    inst.Network:SetClassifiedTarget(nil)
  else
    inst.Network:SetClassifiedTarget(data.doer)
  end
end

local function OnAnyCloseStorage(inst, data)
  local opencount = inst.components.container.opencount
  if opencount == 0 then
    inst.Network:SetClassifiedTarget(inst)
  elseif opencount == 1 then
    local opener = next(inst.components.container.openlist)
    inst.Network:SetClassifiedTarget(opener)
  end
end

local containers = require("containers")
local params = containers.params

-- ====================================================================
-- hslot：古董船 4x4（蓝色月眼）
-- ====================================================================
params.hslot_container = {
  widget = {
    slotpos = {},
    animbank = "ui_boat_ancient_4x4",
    animbuild = "ui_boat_ancient_4x4",
    pos = Vector3(-350, 240, 0),
    buttoninfo = {
      text = "󰀞",
      position = Vector3(0, -190, 0),
    },
  },
  type = "hslot_type",
  itemtestfn = function(inst, item, slot)
    return not item:HasTag("irreplaceable")
  end
}

for y = 3, 0, -1 do
  for x = 0, 3 do
    table.insert(params.hslot_container.widget.slotpos, Vector3(75 * x - 116, 75 * y - 116, 0))
  end
end

-- ====================================================================
-- 月眼鱼箱 5x4（紫/橙/黄色月眼，复用 fish_box 贴图）
-- ====================================================================
-- 共用同一套 widget 配置，但每个月眼独立的世界 key
local MOONEYE_FISH_COLOURS = { "purple", "orange", "yellow" }

-- 每个月眼容器在不同位置，避免重叠
-- 上下再分开一些
local FISH_POSITIONS = {
  purple = Vector3(350, 240, 0),
  orange = Vector3(-350, -60, 0),
  yellow = Vector3(350, -60, 0),
}

for _, colour in ipairs(MOONEYE_FISH_COLOURS) do
  local param_name = colour .. "_fish_box"
  params[param_name] = {
    widget = {
      slotpos = {},
      animbank = "ui_fish_box_5x4",
      animbuild = "ui_fish_box_5x4",
      pos = FISH_POSITIONS[colour],
      side_align_tip = 160,
      buttoninfo = {
        text = "󰀞",
        position = Vector3(0, -190, 0),
      },
    },
    type = colour .. "_fish_type",
    itemtestfn = function(inst, item, slot)
      return not item:HasTag("irreplaceable")
    end,
  }

  -- 5x4 格子布局（同 fish_box）
  for y = 2.5, -0.5, -1 do
    for x = -1, 3 do
      table.insert(params[param_name].widget.slotpos, Vector3(75 * x - 75 * 2 + 75, 75 * y - 75 * 2 + 75, 0))
    end
  end
end

-- ====================================================================
-- Prefab 工厂函数
-- ====================================================================
local function MakePocketContainer(prefab_name, widget_name, world_key, anim_asset)
  return Prefab(prefab_name, function()
    local inst = CreateEntity()

    if TheWorld.ismastersim then
      inst.entity:AddTransform()
    end

    inst.entity:AddNetwork()
    inst.entity:AddServerNonSleepable()
    inst.entity:SetCanSleep(false)
    inst.entity:Hide()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("irreplaceable")
    inst:AddTag("pocketdimension_container")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
      return inst
    end

    inst.Network:SetClassifiedTarget(inst)

    inst:AddComponent("container")
    inst.components.container:WidgetSetup(widget_name)

    inst.components.container.skipclosesnd = true
    inst.components.container.skipopensnd = true
    inst.components.container.skipautoclose = true
    inst.components.container.onanyopenfn = OnAnyOpenStorage
    inst.components.container.onanyclosefn = OnAnyCloseStorage

    TheWorld:SetPocketDimensionContainer(world_key, inst)

    return inst
  end, { Asset("ANIM", anim_asset) })
end

-- ====================================================================
-- 导出所有 Prefab
-- ====================================================================
return
-- 1. 蓝色月眼：古董船 4x4
    MakePocketContainer("hslot_container", "hslot_container", "hslot", "anim/ui_boat_ancient_4x4.zip"),
    -- 2. 紫色月眼：鱼箱 5x4
    MakePocketContainer("purple_fish_box", "purple_fish_box", "purple_fish", "anim/ui_fish_box_5x4.zip"),
    -- 3. 橙色月眼：鱼箱 5x4
    MakePocketContainer("orange_fish_box", "orange_fish_box", "orange_fish", "anim/ui_fish_box_5x4.zip"),
    -- 4. 黄色月眼：鱼箱 5x4
    MakePocketContainer("yellow_fish_box", "yellow_fish_box", "yellow_fish", "anim/ui_fish_box_5x4.zip")
