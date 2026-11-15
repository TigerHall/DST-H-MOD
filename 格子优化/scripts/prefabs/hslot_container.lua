-- scripts/prefabs/hslot_container.lua
-- 口袋空间容器合集：hslot（蓝）+ 紫/橙/黄月眼，四个各 160 格，共用列表界面

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

-- 蓝色月眼仓库的真实容量（列表界面按这个值遍历槽位）
-- ⚠️ 必须和下面的 containers.MAXITEMSLOTS 保持同步，改这里就要改那里
local HSLOT_VAULT_SLOTS = 160

local containers = require("containers")
local params = containers.params

-- ⚠️ 踩坑：官方 containers.lua 在文件末尾（第 2498 行）一次性算出
-- containers.MAXITEMSLOTS（官方最大 20），而我们的 params 是在 require 之后
-- 才注册的，不会被统计进去。container_classified.lua:1057 按这个值预建
-- net_entity 池 _itemspool，且必须在 entity:SetPristine() 之前完成，
-- 所以事后用 AddPrefabPostInit 补池子是无效的（客户端不会创建对应 netvar）。
-- 不抬高的话 InitializeSlots(160) 取到第 21 格时池子已空，Lua 5.1 的
-- table.remove(空表, 1) 返回 0 个值，外层 table.insert 只收到 1 个参数
-- → "wrong number of arguments to 'insert'"（报错文本很误导，实际是池子耗尽）。
-- 这行必须在任何 container_classified 被 SpawnPrefab 之前执行，且服务端/客户端
-- 都要执行（prefab 文件顶层是两端共享的），否则 netvar 编号错位、物品同步全乱。
containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, HSLOT_VAULT_SLOTS)

-- ====================================================================
-- 互斥类型：四个月眼仓库共用同一个 type
-- ====================================================================
-- components/container.lua:504 的 Container:Open 里：
--     for k in pairs(inventory.opencontainers) do
--         if k.prefab == self.inst.prefab
--             or k.components.container.type == self.type then
--             k.components.container:Close(doer)
--         end
--     end
-- 也就是说「同 prefab 或同 type」的容器会被自动关掉。
-- 四个仓库的 prefab 各不相同，所以只能靠 type 来互斥：
-- type 一致 = 开一个自动关掉另一个，面板不会叠在一起
-- （官方红/绿眼 shadow_container / rabbitkinghorn_container 就是这么互斥的，
--  它们都是 deepcopy(params.shadowchester)，type 相同）。
-- ⚠️ 不要用 "chest"，inventory.lua:1921 CloseAllChestContainers 会连带关掉它们。
local HSLOT_TYPE = "hslot_type"

-- ====================================================================
-- hslot：古董船 4x4（蓝色月眼）
-- ====================================================================
params.hslot_container = {
  widget = {
    slotpos = {},
    -- 真实容量走 numslots（containers.widgetsetup 优先用它），slotpos 只保留 16 个占位：
    -- 蓝色月眼的界面已经换成列表（hslot_vault_list），网格 ContainerWidget 会被隐藏，
    -- 创建 160 个网格槽位纯属浪费，所以这里只留 16 个让它不报错
    numslots = HSLOT_VAULT_SLOTS,
    animbank = "ui_boat_ancient_4x4",
    animbuild = "ui_boat_ancient_4x4",
    pos = Vector3(-350, 240, 0),
    buttoninfo = {
      text = "󰀞",
      position = Vector3(0, -190, 0),
    },
  },
  type = HSLOT_TYPE,
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
      -- 和蓝月眼一样扩到 160 格（界面已换成滚动列表，slotpos 只留 20 个占位）
      numslots = HSLOT_VAULT_SLOTS,
      animbank = "ui_fish_box_5x4",
      animbuild = "ui_fish_box_5x4",
      pos = FISH_POSITIONS[colour],
      side_align_tip = 160,
      buttoninfo = {
        text = "󰀞",
        position = Vector3(0, -190, 0),
      },
    },
    -- 和蓝月眼共用 HSLOT_TYPE → 四色仓库互斥，开一个自动关另一个
    type = HSLOT_TYPE,
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
