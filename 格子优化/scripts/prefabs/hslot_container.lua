-- ======================== 核心配置（仅单个hslot容器） ========================
local HSLOT_NAME = "hslot"                               -- 容器唯一标识
local HSLOT_PREFAB = "hslot_container"                   -- 预制体名称
local HSLOT_UI = "anim/ui_portal_rabbitkinghorn_3x4.zip" -- 替换为你的UI资源
local HSLOT_WIDGET = "hslot_container"                   -- UI组件名称

-- ======================== 网络同步事件（极简版） ========================
local function OnAnyOpenStorage(inst, data)
  if inst.components.container.opencount > 1 then
    --multiple users, make it global to all players now
    inst.Network:SetClassifiedTarget(nil)
  else
    --just one user, only network to that player
    inst.Network:SetClassifiedTarget(data.doer)
  end
end

local function OnAnyCloseStorage(inst, data)
  local opencount = inst.components.container.opencount
  if opencount == 0 then
    --all closed, disable networking
    inst.Network:SetClassifiedTarget(inst)
  elseif opencount == 1 then
    --only one user remaining, only network to that player
    local opener = next(inst.components.container.openlist)
    inst.Network:SetClassifiedTarget(opener)
  end
end

-- ======================== 注册UI组件（极简3x4格子） ========================
local function RegisterHSlotWidget()
  local Widget = require "widgets/widget"
  local Image = require "widgets/image"
  local ItemSlot = require "widgets/itemslot"

  -- 直接定义3x4格子的UI，无多余配置
  local HSlotWidget = Class(Widget, function(self, owner)
    Widget._ctor(self, HSLOT_WIDGET)
    self.owner = owner

    -- UI背景（核心属性仅保留背景和格子）
    self.bg = self:AddChild(Image(HSLOT_UI, "ui_hslot_container_3x4.tex"))
    self.bg:SetScale(0.8)

    -- 固定3x4格子坐标（简化计算，直接写死）
    local slotpos = {
      { -100, 75 }, { -25, 75 }, { 50, 75 },
      { -100, 0 }, { -25, 0 }, { 50, 0 },
      { -100, -75 }, { -25, -75 }, { 50, -75 },
      { -100, -150 }, { -25, -150 }, { 50, -150 },
    }

    -- 创建格子（仅保留核心功能）
    self.slots = {}
    for i, pos in ipairs(slotpos) do
      local slot = self:AddChild(ItemSlot(nil, owner))
      slot:SetPosition(pos[1], pos[2])
      slot:SetSize(64, 64)
      self.slots[i] = slot
    end
  end)

  -- 注册到全局，无需单独widgets文件
  package.loaded["widgets/" .. HSLOT_WIDGET] = HSlotWidget
end
RegisterHSlotWidget()

-- ======================== 创建hslot容器预制体（核心逻辑） ========================
local assets = {
  Asset("ANIM", HSLOT_UI),
}

local function fn()
  local inst = CreateEntity()

  -- 服务器端添加Transform（仅用于数据保存）
  if TheWorld.ismastersim then
    inst.entity:AddTransform()
  end

  -- 核心组件（仅保留必须的）
  inst.entity:AddNetwork()
  inst.entity:Hide()                       -- 隐藏实体，纯逻辑容器
  inst:AddTag("CLASSIFIED")                -- 减少网络同步
  inst:AddTag("pocketdimension_container") -- 兼容官方逻辑
  inst:AddTag("irreplaceable")             -- 防止被替换

  -- 客户端直接返回
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then
    return inst
  end

  -- 容器核心配置（极简）
  inst:AddComponent("container")
  inst.components.container:WidgetSetup(HSLOT_WIDGET)
  inst.components.container.skipautoclose = true          -- 禁用自动关闭
  inst.components.container.onopenfn = OnAnyOpenStorage   -- 绑定打开事件
  inst.components.container.onclosefn = OnAnyCloseStorage -- 绑定关闭事件

  -- 注册到世界，方便全局获取
  TheWorld:SetPocketDimensionContainer(HSLOT_NAME, inst)

  return inst
end

-- 仅导出单个hslot容器预制体
return Prefab(HSLOT_PREFAB, fn, assets)
