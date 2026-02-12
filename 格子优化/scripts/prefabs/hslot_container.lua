-- scripts/prefabs/hslot_container.lua
-- 仅创建一个名为 "hslot" 的私有空间容器

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

local assets = {
  Asset("ANIM", "anim/ui_boat_ancient_4x4.zip"),
}

local containers = require("containers")
local params = containers.params

-- 给容器对象添加一个名为 hslot 的容器，用的是坎普斯背包的配置修改的
params.hslot = {
  widget = {
    slotpos = {},
    animbank = "ui_boat_ancient_4x4",
    animbuild = "ui_boat_ancient_4x4",
    pos = Vector3(300, -70, 0)
  },
  type = "hslot",
  itemtestfn = function(inst, item, slot) -- 容器里可以装的物品的条件
    return not item:HasTag("_container") and not item:HasTag("bundle") and not item:HasTag("irreplaceable") and
        item.prefab ~= "hslot_flower"
  end
}

-- 循环容器里小格子

for y = 3, 0, -1 do
  for x = 0, 3 do
    table.insert(params.hslot.widget.slotpos, Vector3(75 * x - 116, 75 * y - 116, 0))
  end
end

local function fn()
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
  inst:AddTag("pocket_container")

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    return inst
  end

  inst.Network:SetClassifiedTarget(inst)

  inst:AddComponent("container")
  inst.components.container:WidgetSetup("hslot") -- ← 修改这里！

  inst.components.container.skipclosesnd = true
  inst.components.container.skipopensnd = true
  inst.components.container.skipautoclose = true
  inst.components.container.onanyopenfn = OnAnyOpenStorage
  inst.components.container.onanyclosefn = OnAnyCloseStorage

  TheWorld:SetPocketDimensionContainer("hslot", inst) -- 注册为 "hslot"

  return inst
end

-- return Prefab("hslot_container", fn, assets)
