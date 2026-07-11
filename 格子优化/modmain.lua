-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })


-- 获取配置项（统一管理配置变量）
local config = {
  -- 腐败/保鲜配置
  preserve_settings = GetModConfigData("preserve_settings"),
  -- 无限堆叠配置
  infinite_stack = GetModConfigData("infinite_stack"),
  -- 强化配置
  pet_strong = GetModConfigData("pet_strong"),
  -- 月眼配置
  moonrockcrater_teleport = GetModConfigData("moonrockcrater_teleport"),
  colormooneye_toggle = GetModConfigData("colormooneye_toggle"),
  mooneye_map_reveal = GetModConfigData("mooneye_map_reveal"),
  -- 眼骨/星空配置
  item_trade_function = GetModConfigData("item_trade_function"),
  auto_get_range = GetModConfigData("auto_get_range"),
  -- 自动修复配置
  repair_to_full = GetModConfigData("repair_to_full"),
  -- 定时整理配置
  auto_sort_repair = GetModConfigData("auto_sort_repair"),
}

-- ═══════════════════════════════════════════════════════
-- 持久化数据：地图揭示记录（防止重上游戏重复触发）
-- 纯 Lua 字符串序列化，不依赖 json/DataDumper/RunInSandbox
-- ═══════════════════════════════════════════════════════
local REVEALED_DATA = {} -- [userid][key] = true
local REVEALED_SAVE_KEY = "hslot_mooneye_revealed"

-- 序列化格式："uid1=k1,k2|uid2=k1,k2"（纯 Lua 操作，无外部依赖）
local function SerializeRevealed(t)
  local parts = {}
  for uid, keys in pairs(t) do
    local kp = {}
    for k in pairs(keys) do
      table.insert(kp, k)
    end
    table.insert(parts, uid .. "=" .. table.concat(kp, ","))
  end
  return table.concat(parts, "|")
end

local function DeserializeRevealed(str)
  local t = {}
  for entry in str:gmatch("([^|]+)") do
    local uid, keys_str = entry:match("([^=]+)=(.+)")
    if uid and keys_str then
      t[uid] = {}
      for k in keys_str:gmatch("([^,]+)") do
        t[uid][k] = true
      end
    end
  end
  return t
end

local function SaveRevealedData()
  if not TheWorld then return end
  local str = SerializeRevealed(REVEALED_DATA)
  TheSim:SetPersistentString(REVEALED_SAVE_KEY, str, true)
end

local function LoadRevealedData()
  TheSim:GetPersistentString(REVEALED_SAVE_KEY, function(success, str)
    if success and str and #str > 0 then
      local loaded = DeserializeRevealed(str)
      -- 合并到当前内存（避免异步覆盖同时写入）
      for uid, keys in pairs(loaded) do
        REVEALED_DATA[uid] = REVEALED_DATA[uid] or {}
        for k in pairs(keys) do
          REVEALED_DATA[uid][k] = true
        end
      end
    end
  end)
end

-- 世界初始化后加载存档
AddPrefabPostInit("world", function(inst)
  if not TheWorld.ismastersim then return end
  inst:DoTaskInTime(0, LoadRevealedData)
end)

-- 月眼地图传送的 UI 字符串
GLOBAL.STRINGS.ACTIONS.TELEPORT_MOONEYE = "传送至月眼"

-- 实体/特效引用
PrefabFiles = {
  "hslot_container",
}

-- 注册动画资源（放在 modmain.lua 开头）
Assets = {
  -- 加载自定义UI动画包
  -- Asset("ANIM", "anim/ui_boat_ancient_4x4.zip"),
}


-- 物品交换映射表
-- 格式1：["输入"] = "输出"                   -- 1个换1个
-- 格式2：["输入"] = { "甲", "乙" }            -- 1个换各1个（甲×1 + 乙×1）
-- 注意：给一堆（如5个石头）= 每份各5个（甲×5 + 乙×5），不支持不等份
local TRADE_MAPPING = {
  -- 绝望石 → 彩虹宝石 → 启迪碎片 → 七色宝石
  ["dreadstone"]               = "opalpreciousgem",
  ["opalpreciousgem"]          = "alterguardianhatshard",
  ["alterguardianhatshard"]    = { "yellowgem", "orangegem", "greengem", "purplegem", "redgem", "bluegem" },
  -- 骨片 → 犬牙 → 一角鲸角
  ["boneshard"]                = "houndstooth",
  ["houndstooth"]              = "gnarwail_horn",
  -- 海象牙 → 克劳斯钥匙
  ["walrus_tusk"]              = "klaussackkey",
  -- 龙鳞 → 古树种子
  ["dragon_scales"]            = "ancienttree_seed",
  -- 树汁酱 → 猴王冠
  ["treegrowthsolution"]       = "monkey_mediumhat",
  -- 花瓣 → 暗红花瓣
  ["petals"]                   = "petals_evil",
  -- 海带 → 公牛海带茎
  ["kelp"]                     = "bullkelp_root",

  -- 蝴蝶 → 黄油
  ["butterfly"]                = "butter",

  -- 石果 →岩石 → 燧石 → 硝石 → 大理石 → 月岩 → 盐晶
  ["rock_avocado_fruit"]       = "rocks",
  ["rocks"]                    = "flint",
  ["flint"]                    = "nitre",
  ["nitre"]                    = "marble",
  ["marble"]                   = "moonrocknugget",
  ["moonrocknugget"]           = "saltrock",

  -- 干海带 → 黄金 → 齿轮
  ["kelp_dried"]               = "goldnugget",
  ["goldnugget"]               = "gears",

  -- 灰烬 → 月亮碎片 → 空瓶子 → 瓶中信
  ["ash"]                      = "moonglass",
  ["moonglass"]                = "messagebottleempty",
  ["messagebottleempty"]       = "messagebottle",

  -- 腐烂物 → 粪肥 → 鸟粪 → 腐烂鸟蛋
  ["spoiled_food"]             = "poop",
  ["poop"]                     = "guano",
  ["guano"]                    = "rottenegg",

  -- 无花果 → 格罗姆粘液 → 嗡嗡肥料 → 受潮营养砖
  ["fig"]                      = "glommerfuel",
  ["glommerfuel"]              = "mosquitofertilizer",
  ["mosquitofertilizer"]       = "wx78_foodbrick",

  -- 怪物肉 → 肉 → 猪皮 → 兔绒 → 兔子
  ["monstermeat"]              = "meat",
  ["meat"]                     = "pigskin",
  ["pigskin"]                  = "manrabbit_tail",
  ["manrabbit_tail"]           = "rabbit",

  -- 棕榈松果树鳞片 → 棕榈松果树芽
  ["palmcone_scale"]           = "palmcone_seed",
  -- 香蕉 → 香蕉丛
  ["cave_banana"]              = "dug_bananabush",
  -- 荧光果 → 球状光虫
  ["lightbulb"]                = "lightflier",

  -- 种子 → 外壳碎片 → 发光蟹
  ["seeds"]                    = "slurtle_shellpieces",
  ["slurtle_shellpieces"]      = "lightcrab",

  -- 勋章少肝点
  -- 格罗姆精华 → 时空碎片 → 时空灵石 → 时空宝石 → 暗影魔法石 → 本源精华
  ["medal_glommer_essence"]    = "medal_time_slider",
  ["medal_time_slider"]        = "medal_spacetime_lingshi",
  ["medal_spacetime_lingshi"]  = "medal_space_gem",
  ["medal_space_gem"]          = "medal_shadow_magic_stone",
  ["medal_shadow_magic_stone"] = "medal_origin_essence",

  -- 曼德拉果 → 杂草/曼德拉/不朽/包果种子
  ["mandrakeberry"]            = { "mandrake_seeds", "medal_weed_seeds", "immortal_fruit_seed", "medal_gift_fruit_seed" },

  -- 血汗钱 → 弯曲的叉子
  ["toil_money"]               = "trinket_17",

  -- 遗失的藏宝图 → 全部 trinket（1-31）
  ["medal_loss_treasure_map"]  = { "trinket_1", "trinket_2", "trinket_3", "trinket_4", "trinket_5",
    "trinket_6", "trinket_7", "trinket_8", "trinket_9", "trinket_10",
    "trinket_11", "trinket_12", "trinket_13", "trinket_14", "trinket_15",
    "trinket_16", "trinket_17", "trinket_18", "trinket_19", "trinket_20",
    "trinket_21", "trinket_22", "trinket_23", "trinket_24", "trinket_25",
    "trinket_26", "trinket_27", "trinket_28", "trinket_29", "trinket_30",
    "trinket_31" },

  -- 食人花手杖 → 吞噬法杖 → 流星法杖
  ["lureplant_rod"]            = "devour_staff",
  ["devour_staff"]             = "meteor_staff",
  -- 淘气铃铛 → 瓶装灵魂 → 瓶装月光
  ["medal_naughtybell"]        = "bottled_soul",
  ["bottled_soul"]             = "bottled_moonlight",
  -- 血糖 → 黑暗血糖
  ["spice_blood_sugar"]        = "spice_rage_blood_sugar",
}

-- 交易成功回调（支持 1:1 和 1:多不同物品）
local function OnGivenItem(inst, giver, item, count)
  if not giver or not giver.components.inventory then return end

  local mapping = TRADE_MAPPING[item.prefab]
  if not mapping then return end

  local trade_count = count or (item.components.stackable and item.components.stackable.stacksize or 1)

  -- 解析输出列表：支持单字符串或数组
  local output_list = {}
  if type(mapping) == "string" then
    output_list = { mapping }
  elseif type(mapping) == "table" then
    output_list = mapping
  else
    return
  end

  -- 按堆叠数量生成每个输出
  for i = 1, trade_count do
    for _, prefab in ipairs(output_list) do
      local reward = SpawnPrefab(prefab)
      if reward then
        giver.components.inventory:GiveItem(reward, nil, giver:GetPosition())
      end
    end
  end

  -- 交易提示
  if giver.components.talker then
    local names = {}
    for _, prefab in ipairs(output_list) do
      local r = SpawnPrefab(prefab)
      if r then
        table.insert(names, r:GetDisplayName())
        r:Remove()
      end
    end
    giver.components.talker:Say("󰀧 " .. item:GetDisplayName() .. " 󰀩 " .. table.concat(names, "+"))
  end
end

-- 通用挂载交易组件函数（简化重复代码）
local function AddTradeComponent(inst)
  inst:AddComponent("trader")
  inst.components.trader:SetAcceptStacks()
  inst.components.trader.acceptnontradable = true
  -- 简化验证逻辑：直接内联，省去单独函数
  inst.components.trader:SetAbleToAcceptTest(function(inst, item)
    return item ~= nil and TRADE_MAPPING[item.prefab] ~= nil
  end)
  inst.components.trader.onaccept = OnGivenItem
end

-- 定义自动收集函数
local function AutoCollectItems(inst)
  local collect_range = config.auto_get_range or 6.6
  -- 查找眼骨周围6.6单位内的可拾取物品
  local x, y, z = inst.Transform:GetWorldPosition()
  local items = TheSim:FindEntities(x, y, z, collect_range,
    { "_inventoryitem" },                                                           -- 包含标签
    { "INLIMBO", "NOCLICK", "catchable", "fire", "irreplaceable", "donotautopick" } -- 排除标签
  )

  -- 标记是否成功收集了物品（用于控制特效只显示一次）
  local has_collected = false

  if #items > 0 then
    -- 获取兔洞容器
    local rabbit_container = TheWorld:GetPocketDimensionContainer("rabbitkinghorn")
    if rabbit_container and rabbit_container.components.container then
      local container = rabbit_container.components.container

      -- 尝试将物品放入容器
      for _, item in ipairs(items) do
        -- 校验条件：物品有效 + 未被持有 + 容器有空间
        if item:IsValid()
            and not item.components.inventoryitem:IsHeld()
            and item.prefab ~= "cane"
            and container:CanAcceptCount(item, 1) > 0 then
          container:GiveItem(item)
          has_collected = true -- 只要收集到一个物品就标记为true
        end
      end

      -- 特效生成函数（封装复用）
      local function spawn_fx(name, scale, pos)
        local fx = SpawnPrefab(name)
        if fx then                                  -- 增加空值校验，避免报错
          fx.Transform:SetScale(scale, scale, scale)
          fx.Transform:SetPosition(pos.x, 0, pos.z) -- Y轴设为地面高度
        end
      end

      -- 只有成功收集到物品时，才显示一次特效
      if has_collected then
        spawn_fx("carnival_streamer_fx", 0.66, inst:GetPosition())
      end
    end
  end
end

-- 每6秒修复容器内物品：耐久/燃料/护甲/新鲜度恢复至100%（跳过 ≤1% 将毁的物品，使用 0.9999 避免浮点精度将 100% 误判）
local function RepairContainerItems(inst)
  if not inst or not inst:IsValid() then return end
  local container = inst.components.container
  if not container then return end
  for i = 1, container:GetNumSlots() do
    local item = container:GetItemInSlot(i)
    if item and item:IsValid() then
      local repaired = false
      -- 耐久/燃料/护甲：跳过 ≤1%（接近损坏）和 ≈100%（已满）的物品
      if item.components.finiteuses then
        local pct = item.components.finiteuses:GetPercent()
        if pct > 0.01 and pct < 0.9999 then
          item.components.finiteuses:SetPercent(1.0)
          repaired = true
        end
      elseif item.components.fueled then
        local pct = item.components.fueled:GetPercent()
        if pct > 0.01 and pct < 0.9999 then
          item.components.fueled:SetPercent(1.0)
          repaired = true
        end
      elseif item.components.armor then
        local pct = item.components.armor:GetPercent()
        if pct > 0.01 and pct < 0.9999 then
          item.components.armor:SetPercent(1.0)
          repaired = true
        end
      end
      -- 食物新鲜度恢复至100%（和反鲜机制互补，即时拉满）
      if item.components.perishable then
        local pct = item.components.perishable:GetPercent()
        if pct > 0.01 and pct < 0.9999 then
          item.components.perishable:SetPercent(1.0)
          repaired = true
        end
      end
      if repaired then
        item:PushEvent("repaired")
      end
    end
  end
end

-- 反修复：将容器内物品耐久/燃料/护甲/新鲜度降低至 6%（红眼暗影空间用）
local function DegradeContainerItems(inst)
  if not inst or not inst:IsValid() then return end
  local container = inst.components.container
  if not container then return end
  for i = 1, container:GetNumSlots() do
    local item = container:GetItemInSlot(i)
    if item and item:IsValid() then
      local degraded = false
      -- 耐久/燃料/护甲：将 > 6% 的物品降到 6%（跳过 ≤ 1% 将毁的物品）
      if item.components.finiteuses then
        local pct = item.components.finiteuses:GetPercent()
        if pct > 0.0601 then
          item.components.finiteuses:SetPercent(0.06)
          degraded = true
        end
      elseif item.components.fueled then
        local pct = item.components.fueled:GetPercent()
        if pct > 0.0601 then
          item.components.fueled:SetPercent(0.06)
          degraded = true
        end
      elseif item.components.armor then
        local pct = item.components.armor:GetPercent()
        if pct > 0.0601 then
          item.components.armor:SetPercent(0.06)
          degraded = true
        end
      end
      -- 食物新鲜度也降到 6%（跳过 ≤ 1% 已腐烂的食物）
      if item.components.perishable then
        local pct = item.components.perishable:GetPercent()
        if pct > 0.0601 then
          item.components.perishable:SetPercent(0.06)
          degraded = true
        end
      end
      if degraded then
        item:PushEvent("repaired")
      end
    end
  end
end

-- 一键整理容器：清除空洞 → 合并堆叠 → 按物品名排序
local function ArrangeContainerItems(inst)
  if not inst or not inst:IsValid() then return end
  local container = inst.components.container
  if not container then return end

  container.ignoreoverstacked = true -- 允许整理时保留超上限堆叠

  -- Step 1: 从后往前取出所有物品
  local items = {}
  for i = container:GetNumSlots(), 1, -1 do
    local item = container:RemoveItemBySlot(i)
    if item then
      table.insert(items, item)
    end
  end

  -- Step 2: 堆叠合并（直接 SetStackSize 合并总量，避免 stackable:Put 受 maxsize 限制）
  for i = #items, 1, -1 do
    local src = items[i]
    if src and src.components.stackable then
      local src_size = src.components.stackable:StackSize()
      for j = 1, i - 1 do
        local dst = items[j]
        if dst and dst.components.stackable and dst.prefab == src.prefab then
          local dst_size = dst.components.stackable:StackSize()
          dst.components.stackable:SetStackSize(dst_size + src_size)
          src:Remove()
          table.remove(items, i)
          break
        end
      end
    end
  end

  -- Step 3: 按 prefab 字母顺序排序
  table.sort(items, function(a, b)
    return a.prefab < b.prefab
  end)

  -- Step 4: 重新放入容器
  for _, item in ipairs(items) do
    container:GiveItem(item)
  end

  container.ignoreoverstacked = false
end

-- 统一的整理逻辑：先排序，再根据容器做修复或降级（按钮和定时任务共用）
local function DoSortAndRepair(inst)
  if not inst or not inst:IsValid() then return end
  ArrangeContainerItems(inst)
  local prefab = inst.prefab
  if prefab == "rabbitkinghorn_container" then
    RepairContainerItems(inst)
  elseif prefab == "shadow_container" then
    DegradeContainerItems(inst)
  end
end

-- 给两个容器添加原生 buttoninfo 按钮：排序 + 对应空间的修复/降级（一步到位）
local function SetupOneButtonPerContainer()
  if not config.repair_to_full then return end -- 配置关闭则不生成按钮

  local containers = GLOBAL.require("containers")
  local params = containers.params

  -- 统一的按钮回调：先整理，再根据容器做修复或降级
  local function btn_fn(inst, doer)
    if inst.components.container ~= nil then                                          -- 服务端
      DoSortAndRepair(inst)
    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then -- 客户端
      SendRPCToServer(RPC.DoWidgetButtonAction, nil, inst, nil)
    end
  end

  local function validfn(inst)
    return inst.replica.container ~= nil and not inst.replica.container:IsEmpty()
  end

  if params.shadow_container then
    params.shadow_container.widget.buttoninfo = {
      text = "󰀞 󰀯",
      position = Vector3(0, -190, 0),
      fn = btn_fn,
      validfn = validfn,
    }
  end
  if params.rabbitkinghorn_container then
    params.rabbitkinghorn_container.widget.buttoninfo = {
      text = "󰀞 󰀨",
      position = Vector3(0, -190, 0),
      fn = btn_fn,
      validfn = validfn,
    }
  end
end

-- 打开格子的通用函数
local function TogglePocketDimensionChest(viewer, container_key)
  -- 1. 基础有效性校验
  if not viewer or not viewer:HasTag("player") or not viewer:IsValid() then
    return
  end

  -- 2. 获取目标储物格容器
  local target_chest = TheWorld:GetPocketDimensionContainer(container_key)
  if not target_chest or not target_chest.components.container then
    return -- 容器不存在或无container组件则退出
  end

  -- 3. 切换容器开关状态（仅影响当前玩家）
  local container = target_chest.components.container
  if container:IsOpen() and container:IsOpenedBy(viewer) then
    -- 仅关闭当前玩家的界面（传入viewer作为参数）
    container:Close(viewer)
  else
    -- 打开容器，让当前查看者成为打开者
    container:Open(viewer)
  end
end

-- 眼骨
AddPrefabPostInit("chester_eyebone", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end
  if config.item_trade_function then
    AddTradeComponent(inst)
    inst:AddTag("NOBLOCK")
  end
  -- 启动定时收集任务（每隔1.6秒执行一次）
  if config.auto_get_range > 0 then
    inst:DoPeriodicTask(1.6, AutoCollectItems)
  end

  -- 右键检查打开兔子洞空间（同绿色月眼逻辑）
  local old_EyeboneGetDesc = inst.components.inspectable.GetDescription
  inst.components.inspectable.GetDescription = function(self, viewer)
    if config.colormooneye_toggle then
      TogglePocketDimensionChest(viewer, "rabbitkinghorn")
    end
    return old_EyeboneGetDesc(self, viewer)
  end
end)

-- 星空
AddPrefabPostInit("hutch_fishbowl", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end
  if config.item_trade_function then
    AddTradeComponent(inst)
    inst:AddTag("NOBLOCK")
  end
  -- 启动定时收集任务（每隔1.6秒执行一次）
  if config.auto_get_range > 0 then
    inst:DoPeriodicTask(1.6, AutoCollectItems)
  end

  -- 右键检查打开兔子洞空间（同绿色月眼逻辑）
  local old_FishbowlGetDesc = inst.components.inspectable.GetDescription
  inst.components.inspectable.GetDescription = function(self, viewer)
    if config.colormooneye_toggle then
      TogglePocketDimensionChest(viewer, "rabbitkinghorn")
    end
    return old_FishbowlGetDesc(self, viewer)
  end
end)


-- 1. 提前定义切斯特状态枚举（和官方代码保持一致，避免冲突）
local ChesterStateNames = {
  "NORMAL",
  "SNOW",
  "SHADOW",
}
local ChesterState = table.invert(ChesterStateNames)

-- 2. 封装切斯特状态获取函数（通用）
local function GetChesterState(inst)
  -- 兼容不存在_chesterstate的情况（比如旧版存档）
  return inst._chesterstate and inst._chesterstate:value() or ChesterState.NORMAL
end

-- 3. 封装切斯特属性更新函数（核心，处理不同状态的属性）
local function UpdateChesterProperties(inst)
  if not TheWorld.ismastersim or not inst then return end

  local current_state = GetChesterState(inst)
  -- 普通/冰雪切斯特的无限堆叠
  if config.infinite_stack and inst.components.container then
    inst.components.container:EnableInfiniteStackSize(true)
  end

  -- ********** 腐烂速率：按状态区分 **********
  -- 先移除原有preserver组件（避免叠加）
  if inst.components.preserver then
    inst:RemoveComponent("preserver")
  end

  if config.preserve_settings then
    if current_state == ChesterState.NORMAL then
      -- 普通切斯特：永久保鲜
      inst:AddComponent("preserver")
      inst.components.preserver:SetPerishRateMultiplier(0)
    elseif current_state == ChesterState.SNOW then
      -- 冰雪切斯特：恢复原生冰箱效果 + 可选反鲜
      inst:AddTag("fridge")
      inst:AddComponent("preserver")
      inst.components.preserver:SetPerishRateMultiplier(-16)
    elseif current_state == ChesterState.SHADOW then
      -- 暗影切斯特：这里不处理，单独在shadow_container中处理
      inst:RemoveTag("fridge")
    end
  end
end

-- 切斯特修改
AddPrefabPostInit("chester", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end
  -- 初始化时执行一次属性更新
  UpdateChesterProperties(inst)

  -- 监听切斯特状态变化事件（形态转换时触发）
  inst:ListenForEvent("chesterstatedirty", function()
    UpdateChesterProperties(inst)
  end)

  -- 兼容切斯特形态转换时的容器切换（比如暗影切斯特的container_proxy）
  inst:ListenForEvent("oncontainerchanged", function()
    UpdateChesterProperties(inst)
  end)
  if config.pet_strong then
    -- 回血和伤害吸收百分比
    if inst.components.health then
      inst.components.health:SetMaxHealth(666)
      inst.components.health:StartRegen(66, 6)
      inst.components.health:SetAbsorptionAmount(0.66)
    end
    if inst.components.locomotor then
      inst.components.locomotor.walkspeed = 10
      inst.components.locomotor.runspeed = 10
    end
  end
end)

-- 哈奇修改
AddPrefabPostInit("hutch", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end
  -- 处理无限堆叠
  if config.infinite_stack and inst.components.container then
    inst.components.container:EnableInfiniteStackSize(true)
  end

  -- 如果开启防腐功能，添加preserver组件并设置速率为0（不腐败）
  if config.preserve_settings then
    inst:AddComponent("preserver")
    inst.components.preserver:SetPerishRateMultiplier(0)
  end
  if config.pet_strong then
    -- 回血和伤害吸收百分比
    if inst.components.health then
      inst.components.health:SetMaxHealth(666)
      inst.components.health:StartRegen(66, 6)
      inst.components.health:SetAbsorptionAmount(0.66)
    end
    if inst.components.locomotor then
      inst.components.locomotor.walkspeed = 10
      inst.components.locomotor.runspeed = 10
    end
  end
end)

-- ═══════════════════════════════════════════════════════
-- 地图揭示布景位置（模仿 messagebottle 一次性揭示机制）
-- 核心思路：setpiece 布景用 TheWorld.topology 搜房间中心
--           有明确 tag 的实体用 TheSim:FindEntities 兜底
--   每个玩家首次触发时标记，后续不再重复
-- ═══════════════════════════════════════════════════════

-- 通过房间名关键词搜索布景中心（官方调试指令 c_findroom 的方式）
local function FindRoomByKeyword(keyword)
  if not TheWorld or not TheWorld.topology or not TheWorld.topology.nodes then
    return nil
  end
  local lower_kw = string.lower(keyword)
  for i, node in ipairs(TheWorld.topology.nodes) do
    if string.lower(TheWorld.topology.ids[i]):find(lower_kw) then
      return node.cent[1], 0, node.cent[2], TheWorld.topology.ids[i]
    end
  end
  return nil
end

-- 搜索配置格式：{ type="room", keyword="Moonbase", label="月亮石" }
--               { type="entity", prefab="critterlab", label="宠物巢穴" }
local function RevealSetPieceLocation(viewer, search_list)
  -- 1. 基础有效性校验
  if not viewer or not viewer:IsValid() or not viewer:HasTag("player") then
    return false
  end
  if not search_list or type(search_list) ~= "table" or #search_list == 0 then
    return false
  end

  -- 2. 一次性检查：查找第一个未揭示的搜索项
  --     使用持久化数据（类似 messagebottlemanager 的 hermit_has_been_found_by）
  local uid = viewer.userid
  if not uid then
    return false
  end
  REVEALED_DATA[uid] = REVEALED_DATA[uid] or {}
  local player_data = REVEALED_DATA[uid]
  local found_x, found_z, found_label, found_key = nil, nil, nil, nil

  for _, item in ipairs(search_list) do
    local key = item.keyword or item.prefab -- 房间名或 prefab 名作为唯一 key
    if not player_data[key] then
      local x, z, name
      if item.type == "room" then
        -- 按房间名关键词搜拓扑（布景专用）
        x, _, z, name = FindRoomByKeyword(item.keyword)
      elseif item.type == "entity" then
        -- 按实体 tag 搜（critterlab 等有显式 AddTag 的实体）
        local entities = TheSim:FindEntities(0, 0, 0, 9999, { item.prefab })
        if #entities > 0 and entities[1]:IsValid() then
          x, _, z = entities[1].Transform:GetWorldPosition()
          name = item.prefab
        end
      end
      if x then
        found_x, found_z = x, z
        found_label = item.label or name or key
        found_key = key
        break
      end
    end
  end

  -- 3. 未找到或已全部揭示
  if not found_x then
    if viewer.components.talker then
      viewer.components.talker:Say("󰀯 已探索所有区域")
    end
    return false
  end

  -- 4. 标记已揭示（先标记防并发）
  player_data[found_key] = true
  -- 立即写盘（不依赖不可靠的 save 事件）
  SaveRevealedData()

  -- 5. 防护：玩家必须有 player_classified
  if not viewer.player_classified then
    return true
  end

  -- 6. 设置地图标记坐标 → 同步到客户端（打开地图并显示标记）
  viewer.player_classified.revealmapspot_worldx:set(found_x)
  viewer.player_classified.revealmapspot_worldz:set(found_z)
  viewer.player_classified.revealmapspotevent:push()

  -- 7. 4 帧后揭示该区域（移除战争迷雾）
  viewer:DoTaskInTime(4 * FRAMES, function()
    if viewer:IsValid() and viewer.player_classified and viewer.player_classified.MapExplorer then
      viewer.player_classified.MapExplorer:RevealArea(found_x, 0, found_z)
    end
  end)

  -- 8. 玩家说话提示
  if viewer.components.talker then
    viewer.components.talker:Say("󰀏 发现" .. (found_label or "布景"))
  end

  return true
end

-- 通用月眼传送函数（支持传入多个目标，仅传送到第一个有效目标）
local function GenericMoonEyeTeleport(inst, viewer, target_prefabs)
  -- 1. 基础有效性验证
  if not viewer or not viewer:IsValid() or not viewer:HasTag("player") then
    return
  end
  -- 验证目标列表有效性
  if not target_prefabs or type(target_prefabs) ~= "table" or #target_prefabs == 0 then
    if viewer.components.talker then
      viewer.components.talker:Say("󰀯") -- 无传送目标提示
    end
    return
  end

  -- 2. 搜索目标实体（仅取第一个有效目标）
  local target = nil
  for _, prefab in ipairs(target_prefabs) do
    local entities = TheSim:FindEntities(0, 0, 0, 9999, { prefab })
    if #entities > 0 and entities[1]:IsValid() then
      target = entities[1]
      break -- 找到第一个有效目标后立即退出循环
    end
  end

  -- 3. 初始化激活状态（防止重复触发）
  if inst._is_teleport_activated == nil then
    inst._is_teleport_activated = false
  end

  -- 4. 清理任务的通用方法
  local function ClearAllTasks()
    if inst._teleport_task ~= nil then
      inst._teleport_task:Cancel()
      inst._teleport_task = nil
    end
    if inst._talk_task ~= nil then
      inst._talk_task:Cancel()
      inst._talk_task = nil
    end
    inst._is_teleport_activated = false
  end

  -- 5. 防止重复触发
  if inst._is_teleport_activated then
    ClearAllTasks()
    return
  else
    ClearAllTasks()
    inst._is_teleport_activated = true
  end

  -- 6. 执行传送逻辑
  if target then
    -- 玩家说话动画
    inst._talk_task = inst:DoTaskInTime(0.6, function()
      if viewer.components.talker then
        viewer.components.talker:Say("󰀏󰀏󰀏󰀃")
        inst._talk_task = inst:DoTaskInTime(1.0, function()
          viewer.components.talker:Say("󰀏󰀏󰀃")
          inst._talk_task = inst:DoTaskInTime(1.0, function()
            viewer.components.talker:Say("󰀏󰀃")
          end)
        end)
      end
    end)

    -- 延时传送
    inst._teleport_task = inst:DoTaskInTime(3.6, function()
      if viewer and viewer:IsValid() and target and target:IsValid() then
        local x, y, z = target.Transform:GetWorldPosition()
        if viewer.components.talker then
          viewer.components.talker:Say("󰀃")
        end
        -- 执行传送
        if viewer.Physics then
          viewer.Physics:Teleport(x, y, z)
        else
          viewer.Transform:SetPosition(x, y, z)
        end
      end
      ClearAllTasks()
    end)
  else
    -- 未找到任何目标的提示
    inst._talk_task = inst:DoTaskInTime(0.6, function()
      if viewer.components.talker then
        viewer.components.talker:Say("󰀯")
      end
      ClearAllTasks()
    end)
  end
end

-- ═══════════════════════════════════════════════════════
-- 地图点击月眼传送（完全复现参考MOD2 代码）
-- 参考MOD 3540476559 的坐标转换 + 双击检测 + RPC 模式
-- ═══════════════════════════════════════════════════════

-- 给六色月眼 + 月眼建筑加 "mooneye" tag（可搜到的传送目标）
local MOONEYE_PREFABS = { "purplemooneye", "bluemooneye", "redmooneye",
  "orangemooneye", "yellowmooneye", "greenmooneye",
  "sentryward", "moondial", "townportal" }
for _, prefab in ipairs(MOONEYE_PREFABS) do
  AddPrefabPostInit(prefab, function(inst)
    inst:AddTag("mooneye")
  end)
end

-- 服务端 RPC：搜月眼 tag，传送到目标位置
AddModRPCHandler("hslot_mooneye", "teleport_to_eye", function(player, x, z)
  if not TheWorld.ismastersim then return end
  local ents = GLOBAL.TheSim:FindEntities(x, 0, z, 30, { "mooneye" })
  if #ents == 0 or not ents[1]:IsValid() then return end
  if ents[1].components.inventoryitem and ents[1].components.inventoryitem:IsHeld() then return end
  local tx, _, tz = ents[1].Transform:GetWorldPosition()
  if player.Physics then player.Physics:Teleport(tx, 0, tz) end
  if player.components.talker then
    player.components.talker:Say("󰀏 󰀯")
  end
end)

-- 客户端：参考 MOD2 的坐标转换 + 单击右键（防拖拽误触）
if not GLOBAL.TheNet:IsDedicated() then
  local _mouse_down_pos = nil
  local HalfResolution = { x = GLOBAL.RESOLUTION_X / 2, y = GLOBAL.RESOLUTION_Y / 2 }
  local screen_width, screen_height = GLOBAL.TheSim:GetScreenSize()

  local function ScreenPosToWorldPos()
    local screen_w, screen_h = GLOBAL.TheSim:GetPosition()
    local screen_x = (screen_w / screen_width * GLOBAL.RESOLUTION_X - HalfResolution.x) / HalfResolution.x
    local screen_y = (screen_h / screen_height * GLOBAL.RESOLUTION_Y - HalfResolution.y) / HalfResolution.y
    return GLOBAL.TheWorld.minimap.MiniMap:MapPosToWorldPos(screen_x, screen_y, 0)
  end

  local function MouseCallBack(button, down, x, y)
    if button ~= 1001 then return end -- 只处理右键
    if not config.moonrockcrater_teleport then return end

    if down then
      -- 记下鼠标按下位置，用于判断是否拖拽
      _mouse_down_pos = { x = x, y = y }
      return
    end

    -- 鼠标抬起：检查地图是否打开
    if not GLOBAL.ThePlayer or not GLOBAL.ThePlayer.HUD or not GLOBAL.ThePlayer.HUD:IsMapScreenOpen() then return end

    -- 防止拖拽地图时误触发：如果鼠标移动超过 10 像素，视为拖拽而非点击
    if _mouse_down_pos then
      local dx, dy = x - _mouse_down_pos.x, y - _mouse_down_pos.y
      if dx * dx + dy * dy > 100 then return end -- 拖拽地图，不触发传送
    end

    -- 单次右键触发传送
    local targetX, targetZ = ScreenPosToWorldPos()
    GLOBAL.SendModRPCToServer(GLOBAL.MOD_RPC["hslot_mooneye"]["teleport_to_eye"], targetX, targetZ)
    -- 立即关闭地图，避免传送后地图跟着角色飞
    local active_screen = GLOBAL.TheFrontEnd:GetActiveScreen()
    if active_screen and active_screen.name == "MapScreen" then
      GLOBAL.TheFrontEnd:PopScreen()
    end
  end

  AddPlayerPostInit(function(inst)
    if TheWorld.ismastersim then return end
    inst:DoTaskInTime(0.1, function()
      GLOBAL.TheInput:AddMouseButtonHandler(MouseCallBack)
    end)
  end)
end

-- 挖孔月岩旧传送逻辑
AddPrefabPostInit("moonrockcrater", function(inst)
  if not TheWorld.ismastersim then return end
  if not inst.components.inspectable then return end

  local old = inst.components.inspectable.GetDescription
  inst.components.inspectable.GetDescription = function(self, viewer)
    if viewer and viewer:HasTag("player") and viewer:IsValid() then
      if config.moonrockcrater_teleport then
        GenericMoonEyeTeleport(self.inst, viewer, { "chester_eyebone", "hutch_fishbowl" })
      end
    end
    return old(self, viewer)
  end
end)

-- 黄色月眼：地图揭示月台/中庭柱子 + 开箱子（可同步触发）
-- 地面 → room:MoonbaseOne（月亮石布景） | 洞穴 → entity:pillar_atrium（中庭柱子）
AddPrefabPostInit("yellowmooneye", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end
  local old_GetDescription = inst.components.inspectable.GetDescription
  inst.components.inspectable.GetDescription = function(self, viewer)
    if viewer and viewer:HasTag("player") and viewer:IsValid() then
      if config.mooneye_map_reveal then
        RevealSetPieceLocation(viewer, {
          { type = "room", keyword = "Moonbase", label = "月亮石[地面]" },
          { type = "room", keyword = "Altar", label = "圣地祭坛[洞穴]" }, -- AltarRoom 布景
        })
      end
      if config.colormooneye_toggle then
        TogglePocketDimensionChest(viewer, "yellow_fish")
      end
    end
    return old_GetDescription(self, viewer)
  end
end)

-- 橙色月眼：地图揭示宠物巢穴/梦魇疯猪 + 开箱子（可同步触发）
-- entity:critterlab（宠物巢穴）有显式 tag 可靠 | entity:daywalker 梦魇疯猪
AddPrefabPostInit("orangemooneye", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end
  local old_GetDescription = inst.components.inspectable.GetDescription
  inst.components.inspectable.GetDescription = function(self, viewer)
    if viewer and viewer:HasTag("player") and viewer:IsValid() then
      if config.mooneye_map_reveal then
        RevealSetPieceLocation(viewer, {
          { type = "entity", prefab = "critterlab", label = "宠物巢穴[地面]" },
          { type = "entity", prefab = "daywalker_pillar", label = "梦魇疯猪[洞穴]" },
          { type = "entity", prefab = "daywalker", label = "梦魇疯猪[洞穴]" },
        })
      end
      if config.colormooneye_toggle then
        TogglePocketDimensionChest(viewer, "orange_fish")
      end
    end
    return old_GetDescription(self, viewer)
  end
end)

-- 紫色月眼：地图揭示格罗姆雕像/猪王/迷宫废墟 + 开箱子（可同步触发）
-- 地面 → room:PigKingdom（猪王布景）→ room:Deciduous（格罗姆池塘）
-- 洞穴 → room:Walled（迷宫废墟）→ room:RuinedCity（远古遗迹）
AddPrefabPostInit("purplemooneye", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end
  local old_GetDescription = inst.components.inspectable.GetDescription
  inst.components.inspectable.GetDescription = function(self, viewer)
    if viewer and viewer:HasTag("player") and viewer:IsValid() then
      if config.mooneye_map_reveal then
        RevealSetPieceLocation(viewer, {
          { type = "room", keyword = "PigKing", label = "猪王花园[地面]" },
          { type = "room", keyword = "Deciduous", label = "格罗姆池塘[地面]" },
          { type = "room", keyword = "Guarden", label = "围墙花园[洞穴]" }, -- 匹配 RuinedGuarden / LabyrinthGuarden（内含WalledGarden布景）
          { type = "room", keyword = "ToadstoolArena", label = "毒菌蟾蜍竞技场[洞穴]" }, -- 匹配 ToadstoolArenaMud / ToadstoolArenaCave
        })
      end
      if config.colormooneye_toggle then
        TogglePocketDimensionChest(viewer, "purple_fish")
      end
    end
    return old_GetDescription(self, viewer)
  end
end)

-- 共享空间设置
-- 兔洞格子相关修改（反鲜）
AddPrefabPostInit("rabbitkinghorn_container", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end
  -- 无限堆叠
  if config.infinite_stack and inst.components.container then
    inst.components.container:EnableInfiniteStackSize(true)
  end
  -- 兔洞反鲜
  if config.preserve_settings then
    if inst.components.preserver == nil then
      inst:AddComponent("preserver")
    end
    inst.components.preserver:SetPerishRateMultiplier(-36)
  end
  -- 定时整理修复（每6秒自动排序+修复至100%）
  if config.auto_sort_repair then
    local task = inst:DoPeriodicTask(6, function()
      DoSortAndRepair(inst)
    end)
    inst:ListenForEvent("onremove", function()
      task:Cancel()
    end)
  end
end)

-- 修改暗影格子属性（腐败）
AddPrefabPostInit("shadow_container", function(inst)
  -- 只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end
  -- 无限堆叠
  if config.infinite_stack and inst.components.container then
    inst.components.container:EnableInfiniteStackSize(true)
  end
  -- 腐烂加快
  if config.preserve_settings then
    if inst.components.preserver == nil then
      inst:AddComponent("preserver")
    end
    inst.components.preserver:SetPerishRateMultiplier(36)
  end
  -- 定时整理降级（每6秒自动排序+降级至6%）
  if config.auto_sort_repair then
    local task = inst:DoPeriodicTask(6, function()
      DoSortAndRepair(inst)
    end)
    inst:ListenForEvent("onremove", function()
      task:Cancel()
    end)
  end

  -- 结束
end)

-- 绿色月眼打开兔洞格子
AddPrefabPostInit("greenmooneye", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end
  -- 劫持检查方法，调用通用抽象函数
  local old_GetDescription = inst.components.inspectable.GetDescription
  inst.components.inspectable.GetDescription = function(self, viewer)
    if config.colormooneye_toggle then
      TogglePocketDimensionChest(viewer, "rabbitkinghorn")
    end
    return old_GetDescription(self, viewer)
  end
end)

-- 红色月眼打开暗影格子
AddPrefabPostInit("redmooneye", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end
  -- 劫持检查方法，调用通用抽象函数
  local old_GetDescription = inst.components.inspectable.GetDescription
  inst.components.inspectable.GetDescription = function(self, viewer)
    if config.colormooneye_toggle then
      TogglePocketDimensionChest(viewer, "shadow")
    end
    return old_GetDescription(self, viewer)
  end
end)

-- 蓝色月眼打开自制格子（古董船 4x4 空间）
AddPrefabPostInit("bluemooneye", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end
  local old_GetDescription = inst.components.inspectable.GetDescription
  inst.components.inspectable.GetDescription = function(self, viewer)
    if config.colormooneye_toggle then
      TogglePocketDimensionChest(viewer, "hslot")
    end
    return old_GetDescription(self, viewer)
  end
end)

-- 给 rabbitkinghorn_container 和 shadow_container 添加原生 buttoninfo 按钮
SetupOneButtonPerContainer()

-- 为所有口袋空间添加：注册世界 + 无限堆叠 + 保鲜 + 整理按钮
local POCKET_MAP = {
  hslot_container = "hslot",
  purple_fish_box = "purple_fish",
  orange_fish_box = "orange_fish",
  yellow_fish_box = "yellow_fish",
}
local sortonly_btn_fn = function(inst, doer)
  if inst.components.container ~= nil then
    ArrangeContainerItems(inst)
  elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
    SendRPCToServer(RPC.DoWidgetButtonAction, nil, inst, nil)
  end
end
local sortonly_validfn = function(inst)
  return inst.replica.container ~= nil and not inst.replica.container:IsEmpty()
end

-- 蓝色月眼空间的增强按钮：排序 + 消耗彩虹宝石 → 堆叠+16 + 复制bundle/gift
local function hslot_btn_fn(inst, doer)
  if inst.components.container ~= nil then
    -- 1. 先排序
    ArrangeContainerItems(inst)

    -- 2. 遍历容器找宝石、可堆叠物品、bundle/gift
    local container = inst.components.container
    local gem_total = 0          -- 彩虹宝石总数
    local gem_consume_slot = nil -- 要从哪个槽消耗
    local stackable_items = {}
    local first_bundle = nil

    for slot = 1, container:GetNumSlots() do
      local item = container:GetItemInSlot(slot)
      if item then
        if item.prefab == "opalpreciousgem" then
          local stack = item.components.stackable and item.components.stackable:StackSize() or 1
          gem_total = gem_total + stack
          -- 记下第一个有宝石的槽，后续消耗用
          if gem_consume_slot == nil then gem_consume_slot = slot end
        elseif item.components.stackable and item.prefab ~= "opalpreciousgem" then
          table.insert(stackable_items, item)
        end
        if first_bundle == nil and item:HasTag("bundle") then
          first_bundle = item
        end
      end
    end

    -- 3. 宝石数 > 10 才消耗 1 个执行增强效果
    if gem_total > 10 then
      local has_effect = false

      -- 给所有可堆叠物品各增加 16 数量
      if #stackable_items > 0 then
        for _, item in ipairs(stackable_items) do
          if item.components.stackable then
            local old = item.components.stackable:StackSize()
            item.components.stackable:SetStackSize(old + 16)
          end
        end
        has_effect = true
      end

      -- 还有空格则深度复制第一个 bundle/gift（含内部物品）
      if first_bundle and container:CanAcceptCount(first_bundle, 1) > 0 then
        local copy = SpawnPrefab(first_bundle.prefab)
        if copy and first_bundle.components.unwrappable and first_bundle.components.unwrappable.itemdata then
          -- 深度复制 itemdata（bundle 内部的物品清单）
          local itemdata_copy = {}
          for i, v in ipairs(first_bundle.components.unwrappable.itemdata) do
            itemdata_copy[i] = deepcopy(v)
          end
          copy.components.unwrappable.itemdata = itemdata_copy
          copy.components.unwrappable.origin = first_bundle.components.unwrappable.origin
          -- 更新 bundle 外观（大小/图标匹配物品数量）
          if copy.components.unwrappable.onwrappedfn then
            copy.components.unwrappable.onwrappedfn(copy, #itemdata_copy)
          end
        end
        if copy then
          container:GiveItem(copy)
          has_effect = true
        end
      end

      -- 至少有一个效果生效时才消耗 1 颗宝石
      if has_effect then
        local gem = container:RemoveItemBySlot(gem_consume_slot)
        if gem then
          if gem.components.stackable and gem.components.stackable:StackSize() > 1 then
            -- 有多颗宝石堆叠，只取一颗，剩下的放回
            gem.components.stackable:SetStackSize(gem.components.stackable:StackSize() - 1)
            container:GiveItem(gem)
          else
            gem:Remove()
          end
        end
      end
    end
  elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
    SendRPCToServer(RPC.DoWidgetButtonAction, nil, inst, nil)
  end
end
for prefab_name, world_key in pairs(POCKET_MAP) do
  AddPrefabPostInit(prefab_name, function(inst)
    if not TheWorld.ismastersim then return end
    -- 注册到世界（首次创建 + 存档加载时重新注册）
    if TheWorld:GetPocketDimensionContainer(world_key) == nil then
      TheWorld:SetPocketDimensionContainer(world_key, inst)
    end
    -- 给服务端的 container widget 补上按钮回调（text+position 已在 params 中定义）
    if inst.components.container ~= nil and inst.components.container.widget ~= nil then
      inst.components.container.widget.buttoninfo = inst.components.container.widget.buttoninfo or {}
      if prefab_name == "hslot_container" then
        inst.components.container.widget.buttoninfo.fn = hslot_btn_fn
      else
        inst.components.container.widget.buttoninfo.fn = sortonly_btn_fn
      end
      inst.components.container.widget.buttoninfo.validfn = sortonly_validfn
    end
    -- 无限堆叠
    if config.infinite_stack and inst.components.container then
      inst.components.container:EnableInfiniteStackSize(true)
    end
    -- 保鲜
    if config.preserve_settings then
      if inst.components.preserver == nil then
        inst:AddComponent("preserver")
      end
      inst.components.preserver:SetPerishRateMultiplier(0)
    end
  end)
end

-- 在 container_replica 构造时补上按钮回调（客户端用）
-- params 已有 buttoninfo 结构（含 text/position），但 fn/validfn 需在此补上
AddClassPostConstruct("components/container_replica", function(self)
  if not POCKET_MAP[self.inst.prefab] then return end
  if self.widget and self.widget.buttoninfo and self.widget.buttoninfo.fn == nil then
    self.widget.buttoninfo.fn = sortonly_btn_fn
    self.widget.buttoninfo.validfn = sortonly_validfn
  end
end)

-- 在世界初始化后创建各色口袋空间
AddPrefabPostInit("world", function(inst)
  if not TheWorld.ismastersim then return end
  -- 等 3 帧确保存档实体已恢复，只创建尚不存在的
  local spawn_task
  local frame_count = 0
  spawn_task = inst:DoPeriodicTask(0, function()
    frame_count = frame_count + 1
    if frame_count < 4 then return end -- 前 3 帧不做事，等存档恢复

    local TO_SPAWN = {
      hslot = "hslot_container",
      purple_fish = "purple_fish_box",
      orange_fish = "orange_fish_box",
      yellow_fish = "yellow_fish_box",
    }
    for key, prefab in pairs(TO_SPAWN) do
      if TheWorld:GetPocketDimensionContainer(key) == nil then
        SpawnPrefab(prefab)
      end
    end
    spawn_task:Cancel()
  end)
end)

-- 客户端：调大这两个容器按钮的字体
if not GLOBAL.TheNet:IsDedicated() then
  AddClassPostConstruct("widgets/containerwidget", function(self)
    local old_Open = self.Open
    self.Open = function(self, container, doer)
      old_Open(self, container, doer)
      local prefab = container and container.prefab
      if (prefab == "rabbitkinghorn_container" or prefab == "shadow_container") and self.button then
        self.button:SetTextSize(36)
      end
    end
  end)
end

-- 客户端：修复 ShowMap 在地图已打开时不居中的问题
-- 官方 Controls:ShowMap 检查 not IsMapScreenOpen()，如果地图已打开直接跳过居中
-- 这里劫持 ShowMap，当有 world_position 参数时（地图揭示），强制关闭再打开以确保居中
if not GLOBAL.TheNet:IsDedicated() then
  AddClassPostConstruct("widgets/controls", function(self)
    local _ShowMap = self.ShowMap
    function self:ShowMap(world_position)
      -- 仅当传入了位置参数时（地图揭示场景），强制关闭地图再重开
      if world_position ~= nil then
        if self.owner ~= nil and self.owner.HUD ~= nil and self.owner.HUD:IsMapScreenOpen() then
          TheFrontEnd:PopScreen() -- 关掉已打开的地图
        end
        -- 调用原版（会重新打开并调用 FocusMapOnWorldPosition 居中）
        _ShowMap(self, world_position)
        return
      end
      -- 无位置参数（常规 ShowMap 调用），走原版逻辑
      _ShowMap(self, world_position)
    end
  end)
end
