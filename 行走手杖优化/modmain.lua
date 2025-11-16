-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })


-- 获取配置项（统一管理配置变量）
local config = {
  -- 基础配置项
  speed_buff = GetModConfigData("speed_buff_value"),
  haunt_resurrect = GetModConfigData("haunt_resurrect_enable"),
  enable_light = GetModConfigData("enable_light"),
  -- 伤害配置项
  damage = GetModConfigData("damage_value"),
  planardamage = GetModConfigData("planardamage"),
  range_attack = GetModConfigData("range_attack_enable"),
  aoe_damage_ratio = GetModConfigData("aoe_damage_ratio"),
  life_drain_ratio = GetModConfigData("life_drain_ratio"),
  hunger_conversion_ratio = GetModConfigData("hunger_conversion_ratio"),
  sanity_conversion_ratio = GetModConfigData("sanity_conversion_ratio"),
  -- 工具配置项
  tool_enable = GetModConfigData("tool_enable"),
  multi_tool_state_save = GetModConfigData("multi_tool_state_save"),
  enable_hammer_action = GetModConfigData("enable_hammer_action"),
  tool_efficiency = GetModConfigData("tool_efficiency"),
  auto_harvest_range = GetModConfigData("auto_harvest_range"),
  auto_farm_range = GetModConfigData("auto_farm_range"),
  enable_light_fx = GetModConfigData("enable_light_fx"),
  enable_watering = GetModConfigData("enable_watering"),
  enable_paddling = GetModConfigData("enable_paddling"),
  -- 其他配置项
  anti_lose = GetModConfigData("anti_lose_enable"),
  lightning_protect_enable = GetModConfigData("lightning_protect_enable"),
  rain_protect_enable = GetModConfigData("rain_protect_enable"),
  constant_temp_effect_enable = GetModConfigData("constant_temp_effect_enable"),
  enable_walrus_tusk_craft = GetModConfigData("enable_walrus_tusk_craft"),
  enable_walrus_tusk_drop = GetModConfigData("enable_walrus_tusk_drop"),
}

-- GLOBAL.CANELIGHT = GetModConfigData("enable_light")

-- 实体/特效引用
PrefabFiles = {
  "hehu_light",
  "cane_hh_fx"
}


-- 修改步行手杖属性
AddPrefabPostInit("cane", function(inst)
  -- 只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end

  -- 基础配置项
  -- 处理装备组件逻辑（移速加成）
  if inst.components.equippable then
    inst.components.equippable.walkspeedmult = 1 + config.speed_buff
  end

  -- 发光功能实现
  if config.enable_light then
    -- 发光判断
    local function setLight(inst)
      local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil

      if owner ~= nil then
        if inst._light ~= nil and inst._light:IsValid() then
          inst._light.entity:SetParent(owner.entity)
          if inst.components.equippable ~= nil and inst.components.equippable:IsEquipped() then
            if TheWorld ~= nil and TheWorld.state ~= nil and TheWorld.state.isnight then
              inst._light.Light:Enable(true)
            else
              inst._light.Light:Enable(false)
            end
          else
            inst._light.Light:Enable(false)
          end
        end
      else
        if inst._light ~= nil and inst._light:IsValid() then
          inst._light.entity:SetParent(inst.entity)
          inst._light.Light:Enable(true)
        end
      end
    end
    local function onRemove(inst)
      if inst._light ~= nil then
        if inst._light:IsValid() then
          inst._light:Remove()
        end
        inst._light = nil
      end
    end
    -- 使用发光特效的方案
    inst._light = SpawnPrefab('hehu_light')
    if inst._light then
      inst._light.entity:SetParent(inst.entity)
      inst._light.entity:AddFollower()
      inst:ListenForEvent("onputininventory", setLight)
      inst:ListenForEvent("ondropped", setLight)
      inst:ListenForEvent("equipped", setLight)
      inst:ListenForEvent("unequipped", setLight)
      inst:WatchWorldState("isnight", function(ent, isnight) setLight(ent) end)
      inst:ListenForEvent("onremove", onRemove)
      setLight(inst)
    else
      print("警告：光效预制体创建失败！")
    end
  end

  -- 处理作祟复活逻辑（根据开关决定是否启用）
  if config.haunt_resurrect then
    -- 添加可被作祟组件（如果不存在）
    if not inst.components.hauntable then
      inst:AddComponent("hauntable")
      inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)
    end

    -- 重写作祟处理函数
    inst.components.hauntable:SetOnHauntFn(function(inst, haunter)
      -- 检查是否是玩家鬼魂作祟
      if haunter:HasTag("playerghost") then
        -- 触发复活事件
        haunter:PushEvent("respawnfromghost")
        -- 播放复活音效
        inst.SoundEmitter:PlaySound("dontstarve/common/ghost_spawn")
        -- 显示复活特效
        local x, y, z = inst.Transform:GetWorldPosition()
        local fx = SpawnPrefab("statue_transition_2")
        if fx then
          fx.Transform:SetPosition(x, y, z)
          fx.Transform:SetScale(0.8, 0.8, 0.8)
        end
        return true -- 表示作祟成功
      end
      return false  -- 非玩家鬼魂作祟不处理
    end)
  end


  -- 伤害配置项
  -- 处理武器组件逻辑
  if inst.components.weapon then
    -- 基础伤害设置
    inst.components.weapon:SetDamage(config.damage)
    -- 确保位面伤害组件存在（如果需要动态开关，可加判断）
    if config.planardamage > 0 then
      inst:AddComponent("planardamage"):SetBaseDamage(config.planardamage)
    end
    -- 攻击范围
    if config.range_attack then
      inst.components.weapon:SetRange(15, 16)
    end

    -- 伤害转换逻辑封装（复用函数）
    local function ApplyDamageConversions(attacker, damage)
      -- 生命转换
      if config.life_drain_ratio > 0 and attacker.components.health then
        attacker.components.health:DoDelta(damage * config.life_drain_ratio, false, "cane")
      end
      -- 饥饿转换
      if config.hunger_conversion_ratio > 0 and attacker.components.hunger then
        attacker.components.hunger:DoDelta(damage * config.hunger_conversion_ratio, false, "cane")
      end
      -- 理智转换
      if config.sanity_conversion_ratio > 0 and attacker.components.sanity then
        attacker.components.sanity:DoDelta(damage * config.sanity_conversion_ratio, false, "cane")
      end
    end

    -- 攻击逻辑处理
    inst.components.weapon.onattack = function(inst, attacker, target)
      -- 1. 计算最终基础伤害（包含所有增益）
      local final_base_damage = config.damage
      local final_base_planardamage = config.planardamage
      -- 这里可以添加其他增益计算，例如：
      -- if attacker:HasTag("some_buff") then
      --     final_base_damage = final_base_damage * 1.2  -- 20%增益
      -- end

      -- 2. 主目标伤害转换
      ApplyDamageConversions(attacker, final_base_damage)
      if config.planardamage > 0 then
        ApplyDamageConversions(attacker, final_base_planardamage)
      end

      -- 3. 群攻逻辑（当比例>0时启用）
      if config.aoe_damage_ratio > 0 then
        local exclude_tags = { "INLIMBO", "companion", "wall", "abigail", "shadowminion" }
        local x, y, z = target.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, 6, { "_combat" }, exclude_tags)

        for _, ent in ipairs(ents) do
          -- 过滤有效目标
          if ent ~= target
              and ent ~= attacker
              and ent.prefab == target.prefab
              and attacker.components.combat:IsValidTarget(ent)
              and (not attacker.components.leader or not attacker.components.leader:IsFollower(ent)) then
            -- 计算群攻伤害（基于最终基础伤害）
            local aoe_damage = final_base_damage * config.aoe_damage_ratio
            -- 计算群攻位面伤害（按相同比例计算）
            local aoe_planar_damage = config.planardamage * config.aoe_damage_ratio

            -- 应用群攻伤害
            attacker:PushEvent("onareaattackother", { target = ent, weapon = inst, stimuli = nil })
            ent.components.combat:GetAttacked(attacker, aoe_damage, inst, nil)
            -- 额外应用位面伤害
            if aoe_planar_damage > 0 and ent.components.health then
              ent.components.health:DoDelta(-aoe_planar_damage, false, "planar", nil, attacker)
            end

            -- 群攻目标的伤害转换
            ApplyDamageConversions(attacker, aoe_damage)
            if aoe_planar_damage > 0 then
              ApplyDamageConversions(attacker, aoe_planar_damage)
            end
          end
        end
      end
    end
  end

  -- 工具配置项
  inst.persists = true
  -- 总开关（默认关闭）
  inst.all_active = false
  inst.light_fx = nil

  -- 多工具组件管理
  -- 加多工具组件
  local function AddToolComponents()
    if not config.tool_enable then return end
    if not inst.components.tool then
      -- 工具组件
      inst:AddComponent("tool")
      -- 砍树
      inst.components.tool:SetAction(ACTIONS.CHOP, config.tool_efficiency)
      -- 采矿
      inst.components.tool:SetAction(ACTIONS.MINE, config.tool_efficiency)
      -- 强力开采
      inst.components.tool:EnableToughWork(true)
      -- 锤你
      if config.enable_hammer_action then
        inst.components.tool:SetAction(ACTIONS.HAMMER, config.tool_efficiency)
      end
      -- 捕虫网
      inst.components.tool:SetAction(ACTIONS.NET)
      -- 挖掘
      inst.components.tool:SetAction(ACTIONS.DIG)
      -- 刷子
      if not inst.components.brush then
        inst:AddComponent("brush")
      end
      -- 淡水钓鱼竿
      if not inst.components.fishingrod then
        inst:AddComponent("fishingrod")
        inst.components.fishingrod:SetWaitTimes(1, 1.6)
        inst.components.fishingrod:SetStrainTimes(0, 160)
      end
      -- 水壶浇水
      if config.enable_watering and not inst.components.wateryprotection then
        inst:AddComponent("wateryprotection")
        inst:AddTag("wateringcan")
        inst.components.wateryprotection.addwetness = 160
        inst.components.wateryprotection.temperaturereduction = 66
        inst.components.wateryprotection:AddIgnoreTag("player")
      end
      -- 划桨
      if config.enable_paddling and not inst.components.oar then
        inst:AddComponent("oar")
        inst:AddTag("allow_action_on_impassable")
        inst.components.oar.force = 1
        inst.components.oar.max_velocity = 16
      end
    end
  end
  -- 关多工具组件
  local function RemoveToolComponents()
    if inst.components.tool then
      inst:RemoveComponent("tool")
      inst:RemoveComponent("brush")
      inst:RemoveComponent("fishingrod")
      if config.enable_watering then
        inst:RemoveComponent("wateryprotection")
      end
      if config.enable_paddling then
        inst:RemoveComponent("oar")
      end
    end
  end
  -- 多工具功能状态更新函数
  local function UpdateToolState()
    if config.tool_enable and inst.all_active then
      AddToolComponents()
    else
      RemoveToolComponents()
    end
  end

  -- 自动采摘逻辑
  local auto_harvest_task = nil
  local AUTO_HARVEST_INTERVAL = 0.6
  local function DoAreaHarvest(inst)
    local doer = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
    if not doer or not doer:HasTag("player") then return end

    local x, y, z = doer.Transform:GetWorldPosition()
    local HARVEST_RADIUS = config.auto_harvest_range
    if HARVEST_RADIUS <= 0 then return end

    local ents = TheSim:FindEntities(x, y, z, HARVEST_RADIUS,
      { "pickable" },
      { "INLIMBO", "FX", "NOCLICK", "burnt", "flower", "dead", "thorny" },
      { "plant", "crop", "lichen", "oceanvine", "kelp" }
    )
    for _, ent in ipairs(ents) do
      if ent:IsValid() and ent.components.pickable and ent.components.pickable:CanBePicked() and not ent.components.pickable:IsBarren() then
        doer.SoundEmitter:PlaySound(ent.components.pickable.picksound or "dontstarve/wilson/pickup_plants")
        local success, loot = ent.components.pickable:Pick(doer)
        if success and loot then
          for _, item in ipairs(loot) do
            if item and item:IsValid() then
              Launch(item, doer, 1.6)
            end
          end
        end
      end
    end
  end
  -- 自动采摘状态更新函数
  local function UpdateAutoHarvest()
    local should_run = config.auto_harvest_range > 0
        and inst.all_active
        and inst.components.equippable
        and inst.components.equippable:IsEquipped()

    if should_run and not auto_harvest_task then
      auto_harvest_task = inst:DoPeriodicTask(AUTO_HARVEST_INTERVAL, DoAreaHarvest)
    elseif not should_run and auto_harvest_task then
      auto_harvest_task:Cancel()
      auto_harvest_task = nil
    end
  end

  -- 自动耕地逻辑
  -- 九宫格偏移坐标
  local MAP_3x3 = {
    { -1.333, -1.333 }, { 0, -1.333 }, { 1.333, -1.333 },
    { -1.333, 0 }, { 0, 0 }, { 1.333, 0 },
    { -1.333, 1.333 }, { 0, 1.333 }, { 1.333, 1.333 }
  }

  -- 自动耕地相关配置与变量
  local AUTO_FARM_INTERVAL = 0.6 -- 自动耕地检测间隔（可根据需求调整）
  local auto_farm_task = nil     -- 自动耕地定时任务句柄

  -- 自动耕地核心执行函数
  local function DoAreaFarm()
    -- 获取物品所有者（玩家）
    local doer = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
    if not doer or not doer:HasTag("player") then
      return -- 非玩家持有则退出
    end

    -- 获取玩家位置和配置的耕地范围
    local x, y, z = doer.Transform:GetWorldPosition()
    local AUTO_FARM_RANGE = config.auto_farm_range or 0
    if AUTO_FARM_RANGE <= 0 then
      return -- 范围无效则退出
    end

    -- 搜索范围内的可耕地块
    local found_centers = {} -- 存储已处理的地块中心，避免重复操作
    local ents = TheSim:FindEntities(
      x, y, z,
      AUTO_FARM_RANGE,
      nil,
      { "INLIMBO", "NOCLICK" } -- 排除无效实体
    )

    for _, ent in ipairs(ents) do
      -- 检查是否为可耕地或土壤实体
      if ent:IsValid() and (ent:HasTag("soil") or TheWorld.Map:CanTillSoilAtPoint(ent.Transform:GetWorldPosition())) then
        -- 获取地块中心坐标
        local cx, _, cz = TheWorld.Map:GetTileCenterPoint(ent.Transform:GetWorldPosition())
        local center_key = string.format("%.2f,%.2f", cx, cz) -- 用坐标字符串作为唯一标识

        -- 跳过已处理的地块
        if not found_centers[center_key] then
          found_centers[center_key] = true

          -- 坍塌当前地块上的旧土壤
          local tile_ents = TheWorld.Map:GetEntitiesOnTileAtPoint(cx, 0, cz)
          for _, tile_ent in ipairs(tile_ents) do
            if tile_ent ~= inst and tile_ent:HasTag("soil") then
              tile_ent:PushEvent("collapsesoil")
            end
          end

          -- 在地块中心执行3x3耕地
          for _, v in pairs(MAP_3x3) do
            local nx = v[1] + cx
            local nz = v[2] + cz
            if TheWorld.Map:CanTillSoilAtPoint(nx, 0, nz, false) then
              TheWorld.Map:CollapseSoilAtPoint(nx, 0, nz)
              SpawnPrefab("farm_soil").Transform:SetPosition(nx, 0, nz)
              doer:PushEvent("tilling") -- 触发耕地音效/动画
            end
          end
        end
      end
    end
  end

  -- 自动耕地状态更新函数（根据配置和装备状态控制任务启停）
  local function UpdateAutoFarm()
    -- 判定是否需要运行自动耕地：范围有效 + 总开关开启 + 已装备
    local should_run = config.auto_farm_range > 0
        and inst.all_active
        and inst.components.equippable
        and inst.components.equippable:IsEquipped()

    -- 任务启停控制
    if should_run and not auto_farm_task then
      -- 启动定时任务（立即执行一次，之后按间隔循环）
      auto_farm_task = inst:DoPeriodicTask(AUTO_FARM_INTERVAL, DoAreaFarm, 0.16)
    elseif not should_run and auto_farm_task then
      -- 停止并清理任务
      auto_farm_task:Cancel()
      auto_farm_task = nil
    end
  end

  -- 光特效更新函数
  local function UpdateLightFX()
    if not config.enable_light_fx then
      if inst.light_fx then
        inst.light_fx:Remove()
        inst.light_fx = nil
      end
      return
    end
    if inst.all_active then
      if not inst.light_fx then
        inst.light_fx = SpawnPrefab("cane_hh_fx")
        inst.light_fx.entity:SetParent(inst.entity)
      end
    else
      if inst.light_fx then
        inst.light_fx:Remove()
        inst.light_fx = nil
      end
    end
  end


  -- local hh_fx = SpawnPrefab("cane_hh_fx")
  -- hh_fx.entity:SetParent(inst.entity)

  -- 统一更新所有功能（新增自动耕地更新）
  local function UpdateAllFeatures()
    UpdateToolState()
    UpdateAutoHarvest()
    UpdateAutoFarm()
    UpdateLightFX()
  end

  -- 右键切换总开关（控制包括自动耕地在内的所有功能）
  inst:AddComponent("useableitem")
  inst:AddComponent("named")
  inst.components.useableitem:SetOnUseFn(function(inst)
    local owner = inst.components.inventoryitem:GetGrandOwner()
    if not owner or not owner:HasTag("player") then return false end
    -- 切换开关状态
    inst.all_active = not inst.all_active
    UpdateAllFeatures()

    -- 修改装备名称（根据状态切换）
    if inst.all_active then
      inst.components.named:SetName("H-手杖:󰀏开/ON")
    else
      inst.components.named:SetName("H-手杖:󰀜关/OFF")
    end

    -- 玩家提示
    if owner.components.talker then
      owner.components.talker:Say(inst.all_active and "󰀏开/ON" or "󰀜关/OFF")
    end

    return false
  end)

  -- 销毁清理（新增自动耕地任务清理）
  inst:ListenForEvent("onremove", function()
    if auto_harvest_task then
      auto_harvest_task:Cancel()
    end
    if auto_farm_task then
      auto_farm_task:Cancel()
    end
    RemoveToolComponents()
    if inst.light_fx then
      inst.light_fx:Remove()
    end
  end)

  -- 状态保存与加载（总开关统一控制，无需额外保存）
  inst.OnSave = function(inst, data)
    data.all_active = inst.all_active
  end

  inst.OnPreLoad = function(inst, data)
    inst.all_active = data and data.all_active or false
    UpdateAllFeatures()
  end


  -- 其他配置
  -- 处理防丢失逻辑（根据开关决定是否启用）
  if config.anti_lose and inst.components.inventoryitem then
    -- 防止被偷窃
    inst:AddTag("nosteal")
    -- 防流星破坏
    inst:AddTag("meteor_protection")
    -- 防止BOSS攻击/潮湿导致脱手
    inst.components.inventoryitem:SetOnDroppedFn(nil)
    -- 超级隔热
    -- if not inst.components.insulator then
    --   inst:AddComponent("insulator")
    --   inst.components.insulator:SetInsulation(360)
    --   inst.components.insulator:SetSummer()
    -- end
  end
  -- 防雷保护
  if config.lightning_protect_enable then
    if inst.components.equippable then
      inst:AddComponent("equippable")
      inst.components.equippable.insulated = true
    end
  end
  -- 防雨保护
  if config.rain_protect_enable then
    if not inst.components.waterproofer then
      inst:AddComponent("waterproofer")
      inst.components.waterproofer:SetEffectiveness(1)
    end
  end

  -- 定义自动温控相关变量
  local auto_temp_task = nil
  local AUTO_TEMP_INTERVAL = 0.6

  -- 自动温控核心逻辑函数
  local function DoAutoTempControl(inst)
    -- 获取装备所有者（玩家）
    local doer = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
    -- 检查所有者有效性（必须是存活的玩家）
    if not doer
        or not doer:IsValid()
        or not doer:HasTag("player")
        or (doer.components.health and doer.components.health:IsDead()) then
      -- 若所有者无效，停止任务
      if auto_temp_task then
        auto_temp_task:Cancel()
        auto_temp_task = nil
      end
      return
    end
    -- 1. 温度调整
    if doer.components.temperature then
      -- 温度设定为16
      doer.components.temperature:SetTemperature(16)
    end
    -- 2. 自身解冻（仅当冻结时）
    if doer.components.freezable and doer.components.freezable:IsFrozen() then
      doer.components.freezable:Unfreeze()
    end
    -- 3. 自身灭火（仅当燃烧时）
    if doer.components.burnable and doer.components.burnable:IsBurning() then
      doer.components.burnable:Extinguish()
    end
  end

  -- 装备/卸下事件
  if inst.components.equippable then
    inst:ListenForEvent("equipped", function(_, data)
      if data and data.owner and data.owner:HasTag("player") then
        -- 先停止可能存在的旧任务（避免重复启动）
        if auto_temp_task then
          auto_temp_task:Cancel()
          auto_temp_task = nil
        end
        -- 启动新的自动温控任务（0.6秒间隔）
        auto_temp_task = inst:DoPeriodicTask(AUTO_TEMP_INTERVAL, function()
          DoAutoTempControl(inst)
        end)
        -- 装备时同步所有右键控制功能状态
        UpdateAllFeatures()
      end
    end)
    inst:ListenForEvent("unequipped", function(_, data)
      if data and data.owner and data.owner:HasTag("player") then
        -- 停止自动温控任务
        if auto_temp_task then
          auto_temp_task:Cancel()
          auto_temp_task = nil
        end
        if config.multi_tool_state_save then
          -- 卸下时同步所有右键控制功能状态
          UpdateAllFeatures()
        else
          -- 不保存状态时，关闭全部右键控制项
          inst.all_active = false
          UpdateAllFeatures()
        end
      end
    end)
  end

  -- 结束
end)

--骨头碎片1和犬牙1制作海象牙
if config.enable_walrus_tusk_craft then
  AddRecipe2("walrus_tusk", { Ingredient("boneshard", 1), Ingredient("houndstooth", 1) },
    TECH.NONE, nil,
    { "REFINE", })
end

AddPrefabPostInit("walrus", function(inst)
  -- 只在服务端生效
  if not TheWorld.ismastersim then
    return inst
  end
  -- 检查是否有掉落物组件，有的话修改掉落配置
  if config.enable_walrus_tusk_drop then
    inst.components.lootdropper:AddChanceLoot("walrus_tusk", 1.00)
  end
end)
