-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })


-- 获取配置项（统一管理配置变量）
local config = {
  -- 基础配置项
  speed_buff = GetModConfigData("speed_buff_value"),
  haunt_resurrect = GetModConfigData("haunt_resurrect_enable"),
  hcane_light = GetModConfigData("hcane_light"),
  -- 伤害配置项
  damage = GetModConfigData("damage_value"),
  planardamage = GetModConfigData("planardamage"),
  range_attack = GetModConfigData("range_attack"),
  extra_damage = GetModConfigData("extra_damage"),
  aoe_damage_ratio = GetModConfigData("aoe_damage_ratio"),
  life_drain_ratio = GetModConfigData("life_drain_ratio"),
  hunger_conversion_ratio = GetModConfigData("hunger_conversion_ratio"),
  sanity_conversion_ratio = GetModConfigData("sanity_conversion_ratio"),
  -- 工具配置项
  tool_enable = GetModConfigData("tool_enable"),
  multi_tool_state_save = GetModConfigData("multi_tool_state_save"),
  enable_hammer_action = GetModConfigData("enable_hammer_action"),
  enable_dig_action = GetModConfigData("enable_dig_action"),
  enable_scythe = GetModConfigData("enable_scythe"),
  tool_efficiency = GetModConfigData("tool_efficiency"),
  auto_work_range = GetModConfigData("auto_work_range"),
  auto_farm_range = GetModConfigData("auto_farm_range"),
  enable_light_fx = GetModConfigData("enable_light_fx"),
  enable_player_glow = GetModConfigData("enable_player_glow"),
  fx_particle_type = GetModConfigData("fx_particle_type"),
  enable_tool_toggle_icon = GetModConfigData("enable_tool_toggle_icon"),
  enable_tool_toggle_rename = GetModConfigData("enable_tool_toggle_rename"),
  cane_icon_text = GetModConfigData("cane_icon_text"),
  -- 常驻功能配置项
  enable_watering = GetModConfigData("enable_watering"),
  enable_paddling = GetModConfigData("enable_paddling"),
  enable_fishingrod = GetModConfigData("enable_fishingrod"),
  enable_brush = GetModConfigData("enable_brush"),
  enable_hoe = GetModConfigData("enable_hoe"),
  enable_razor = GetModConfigData("enable_razor"),
  -- 其他配置项
  anti_lose = GetModConfigData("anti_lose_enable"),
  lightning_protect_enable = GetModConfigData("lightning_protect_enable"),
  rain_protect_enable = GetModConfigData("rain_protect_enable"),
  constant_temp_effect_enable = GetModConfigData("constant_temp_effect_enable"),
  enable_walrus_tusk_craft = GetModConfigData("enable_walrus_tusk_craft"),
  enable_walrus_tusk_drop = GetModConfigData("enable_walrus_tusk_drop"),
  enable_slot = GetModConfigData("enable_slot"),
}

TUNING.hcanelight = GetModConfigData("hcane_light")

-- 实体/特效引用
PrefabFiles = {
  "hehu_light",
  "cane_hh_fx",
  "cane_shadow_fx",
}

-- 注册动画资源（放在 modmain.lua 开头）
Assets = {
  -- 加载自定义UI动画包
  -- Asset("ANIM", "anim/ui_antlionhat_1x1.zip"),
  Asset("IMAGE", "images/inventoryimages/xin.tex"),
  Asset("ATLAS", "images/inventoryimages/xin.xml"),
  Asset("IMAGE", "images/inventoryimages/heh.tex"),
  Asset("ATLAS", "images/inventoryimages/heh.xml"),
  -- Asset("SHADER", "shaders/myshader.ksh")
}

-- 勋章面板兼容：消耗状态名称（能力勋章 1909182187）
STRINGS.NAMES.HCANE_WATER_HUNGER = "H-手杖踏水消耗"
STRINGS.NAMES.HCANE_RED_GEM     = "H-手杖红宝石消耗"
STRINGS.NAMES.HCANE_BLUE_GEM    = "H-手杖蓝宝石消耗"
STRINGS.NAMES.HCANE_ORANGE_GEM  = "H-手杖橙宝石消耗"
STRINGS.NAMES.HCANE_YELLOW_GEM  = "H-手杖黄宝石消耗"
STRINGS.NAMES.HCANE_PURPLE_GEM  = "H-手杖紫宝石消耗"
STRINGS.NAMES.HCANE_GREEN_GEM   = "H-手杖绿宝石消耗"
STRINGS.NAMES.HCANE_OPAL_GEM    = "H-手杖彩虹宝石消耗"
STRINGS.NAMES.HCANE_CELESTIAL   = "H-手杖天体珠宝消耗"
STRINGS.NAMES.HCANE_BEARGER     = "H-手杖熊大消耗"
STRINGS.NAMES.HCANE_ANTLION     = "H-手杖蚁狮坑消耗"
STRINGS.NAMES.HCANE_GLOMMER     = "H-手杖催熟消耗"

-- 修改步行手杖属性
AddPrefabPostInit("cane", function(inst)
  -- 以下只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end
  -- 基础配置项
  -- 处理装备组件逻辑（移速加成）
  if inst.components.equippable then
    inst.components.equippable.walkspeedmult = 1 + config.speed_buff
  end

  -- 发光功能实现
  if config.hcane_light > 0 then
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
          inst._light.Light:Enable(config.hcane_light > 0 or true)
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
        -- 作祟复活后恢复三维（饥饿、血量、理智）到满值（百分比回复）
        -- 使用2.5秒延迟确保复活动画完全结束后才恢复，避免被动画覆盖
        inst:DoTaskInTime(2.5, function()
          if haunter and haunter:IsValid() and not haunter:HasTag("playerghost") then
            if haunter.components.health ~= nil and not haunter.components.health:IsDead() then
              haunter.components.health:SetPercent(1)
            end
            if haunter.components.hunger ~= nil then
              haunter.components.hunger:SetPercent(1)
            end
            if haunter.components.sanity ~= nil then
              haunter.components.sanity:SetPercent(1)
            end
          end
        end)
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
    -- 确保位面伤害组件存在
    inst:AddComponent("planardamage"):SetBaseDamage(config.planardamage)
    -- 攻击范围
    if config.range_attack > 0 then
      inst.components.weapon:SetRange(config.range_attack, config.range_attack + 1)
    end
    -- 初始化实体的伤害倍率存储（首次使用时赋值，避免nil）
    if not inst._damage_mult then
      inst._damage_mult = 1 -- 基础伤害原始倍率
    end
    if not inst._planardamage_mult then
      inst._planardamage_mult = 1 -- 位面伤害原始倍率
    end
    -- 重置额外伤害函数（直接判断配置开关）
    local function ResetExtraDamage()
      inst.extra_damage = 0
      inst.combat_timer = nil
      -- 恢复基础伤害
      inst.components.weapon:SetDamage(config.damage * inst._damage_mult)
      inst.components.planardamage:SetBaseDamage(config.planardamage * inst._planardamage_mult)
    end

    -- 伤害转换逻辑封装（复用函数）
    local function ApplyDamageConversions(attacker, damage)
      -- 生命转换
      if config.life_drain_ratio > 0 and attacker.components.health then
        if attacker.components.oldager then
          attacker.components.oldager:StopDamageOverTime()
        end
        attacker.components.health:DoDelta(damage * config.life_drain_ratio, false, inst.prefab)
      end
      -- 饥饿转换
      if config.hunger_conversion_ratio > 0 and attacker.components.hunger then
        attacker.components.hunger:DoDelta(damage * config.hunger_conversion_ratio, false, inst.prefab)
      end
      -- 理智转换
      if config.sanity_conversion_ratio > 0 and attacker.components.sanity then
        attacker.components.sanity:DoDelta(damage * config.sanity_conversion_ratio, false, inst.prefab)
      end
    end

    -- 攻击逻辑处理
    inst.components.weapon.onattack = function(inst, attacker, target)
      -- 临时增益伤害计算
      local base_damage = config.damage * inst._damage_mult
      local base_planardamage = config.planardamage * inst._planardamage_mult
      -- 升级增益计算（未设置）
      local final_base_damage = base_damage
      local final_base_planardamage = base_planardamage

      inst.singlefight_target = target or false

      -- 越攻击越强 核心逻辑（简化版）
      if config.extra_damage then
        -- 初始化累加变量（首次触发时）
        inst.extra_damage = inst.extra_damage or 0
        inst.max_extra_damage = 166

        -- 刷新16秒重置计时器
        if inst.combat_timer ~= nil then
          inst.combat_timer:Cancel()
        end
        inst.combat_timer = inst:DoTaskInTime(16, ResetExtraDamage)

        -- 随机累加1-6点伤害，限制上限66
        if math.random() < 0.16 then
          local add_damage = math.random(1, 6)
          inst.extra_damage = math.min(inst.extra_damage + add_damage, inst.max_extra_damage)
        end

        -- 叠加额外伤害并更新武器伤害
        final_base_damage = base_damage + inst.extra_damage
        final_base_planardamage = base_planardamage + inst.extra_damage
        inst.components.weapon:SetDamage(final_base_damage)
        if not inst.components.planardamage then
          inst:AddComponent("planardamage")
        end
        inst.components.planardamage:SetBaseDamage(final_base_planardamage)
      end

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

            -- 群攻目标也带火焰/冰冻效果
            if inst._has_redgem then
              if ent.components.burnable and not ent.components.burnable:IsBurning() then
                if ent.components.burnable.canlight or ent.components.combat ~= nil then
                  ent.components.burnable:Ignite(true, attacker)
                end
              end
            end
            if inst._has_bluegem then
              if ent.components.freezable and not ent.components.freezable:IsFrozen() then
                ent.components.freezable:AddColdness(16)
                ent.components.freezable:SpawnShatterFX()
              end
            end
          end
        end
      end

      -- 4. 红宝石/蓝宝石攻击效果——由扫描标志控制
      if inst._has_redgem then
        if target.components.burnable and not target.components.burnable:IsBurning() then
          if target.components.burnable.canlight or target.components.combat ~= nil then
            target.components.burnable:Ignite(true, attacker)
          end
        end
      end
      if inst._has_bluegem then
        if target.components.freezable and not target.components.freezable:IsFrozen() then
          target.components.freezable:AddColdness(16)
          target.components.freezable:SpawnShatterFX()
        end
      end
    end
  end

  -- 工具配置项
  inst.persists = true
  -- 总开关（默认关闭）
  inst.all_active = false
  inst.light_fx = nil

  -- 同步高亮标签到客户端
  local function SyncCaneState()
    if inst.all_active then
      inst:AddTag("caneon")
    else
      inst:RemoveTag("caneon")
    end
  end

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
      -- 挖掘
      if config.enable_dig_action then
        inst.components.tool:SetAction(ACTIONS.DIG, config.tool_efficiency)
      end
      -- 捕虫网
      inst.components.tool:SetAction(ACTIONS.NET, config.tool_efficiency)

      -- 添加镰刀功能
      if config.enable_scythe then
        -- 整合并简化镰刀收割功能（圆形范围收割）
        local function DoScythe(inst, target, doer)
          -- 定义收割范围和标签过滤
          local HARVEST_RANGE = 6.6
          local HARVEST_MUSTTAGS = { "pickable" }
          local HARVEST_CANTTAGS = { "INLIMBO", "FX" }
          local HARVEST_ONEOFTAGS = { "plant", "lichen", "oceanvine", "kelp" }

          -- 获取玩家位置并查找范围内实体
          local x, y, z = doer:GetPosition():Get()
          local ents = TheSim:FindEntities(x, y, z, HARVEST_RANGE,
            HARVEST_MUSTTAGS, HARVEST_CANTTAGS, HARVEST_ONEOFTAGS)

          -- 遍历实体并收割
          for _, ent in pairs(ents) do
            if ent:IsValid() and ent.components.pickable then
              -- 播放收割音效
              if ent.components.pickable.picksound then
                doer.SoundEmitter:PlaySound(ent.components.pickable.picksound)
              end

              -- 执行采摘并处理掉落物
              local success, loot = ent.components.pickable:Pick(TheWorld)
              if loot then
                for _, item in ipairs(loot) do
                  Launch(item, doer, 1.5) -- 物品向玩家方向弹出
                end
              end
            end
          end
        end
        inst.components.tool:SetAction(ACTIONS.SCYTHE)
        inst.DoScythe = DoScythe
      end
    end
  end
  -- 关多工具组件
  local function RemoveToolComponents()
    if inst.components.tool then
      inst:RemoveComponent("tool")
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

  -- 不随右键关闭的功能
  -- 刷子
  if config.enable_brush and not inst.components.brush then
    inst:AddComponent("brush")
  end
  -- 剃刀
  if config.enable_razor and not inst.components.shaver then
    inst:AddComponent("shaver")
  end
  -- 锄头功能（通过 AddInherentAction + farmtiller 组件实现，区别于传统 tool 系统）
  if config.enable_hoe then
    if not inst.components.farmtiller then
      inst:AddComponent("farmtiller")
    end
    inst:AddInherentAction(ACTIONS.TILL)
  end
  -- 淡水钓鱼竿
  if config.enable_fishingrod and not inst.components.fishingrod then
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
  -- 添加 区域温度 组件(暂未添加，而且需要主客机同时才行)
  if false then
    inst:AddComponent("temperatureoverrider")
    inst.components.temperatureoverrider:SetTemperature(46)
    inst.components.temperatureoverrider:SetRadius(config.auto_work_range)
    inst.components.temperatureoverrider:Enable()
  end


  -- 自动采摘逻辑
  local auto_harvest_task = nil
  local AUTO_HARVEST_INTERVAL = 0.6
  local function DoAreaHarvest(inst)
    local doer = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
    if not doer or not doer:HasTag("player") then return end

    local x, y, z = doer.Transform:GetWorldPosition()
    local WORK_RADIUS = config.auto_work_range
    if WORK_RADIUS <= 0 then return end

    local ents = TheSim:FindEntities(x, y, z, WORK_RADIUS,
      { "pickable" },
      { "INLIMBO", "FX", "NOCLICK", "burnt", "flower", "dead", "thorny" }, -- 排除标签
      { "plant", "crop", "lichen", "oceanvine", "kelp" }                   -- 必须包含标签
    )
    for _, ent in ipairs(ents) do
      -- 普通采摘逻辑
      if ent:IsValid() and ent.components.pickable and ent.components.pickable:CanBePicked() and not ent.components.pickable:IsBarren() then
        -- 执行采摘
        doer.SoundEmitter:PlaySound(ent.components.pickable.picksound or "dontstarve/wilson/pickup_plants")
        ent.components.pickable:Pick(doer)
        -- 在植物位置生成沙子特效
        -- SpawnPrefab("sand_puff").Transform:SetPosition(ent.Transform:GetWorldPosition())
      end
    end
  end
  -- 自动采摘状态更新函数
  local function UpdateAutoHarvest()
    local should_run = config.auto_work_range > 0
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
    { -4 / 3, -4 / 3 }, { 0, -4 / 3 }, { 4 / 3, -4 / 3 },
    { -4 / 3, 0 }, { 0, 0 }, { 4 / 3, 0 },
    { -4 / 3, 4 / 3 }, { 0, 4 / 3 }, { 4 / 3, 4 / 3 }
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
    local AUTO_FARM_RANGE = config.auto_farm_range or 1
    local center_tile_x, center_tile_z = TheWorld.Map:GetTileCoordsAtPoint(x, y, z)
    if AUTO_FARM_RANGE <= 0 then
      return -- 范围无效则退出
    end

    -- 遍历以玩家为中心的周围格子
    for dx = -AUTO_FARM_RANGE, AUTO_FARM_RANGE do
      for dz = -AUTO_FARM_RANGE, AUTO_FARM_RANGE do
        local tile_x = center_tile_x + dx
        local tile_z = center_tile_z + dz

        -- 获取当前格子的中心世界坐标
        local cx, _, cz = TheWorld.Map:GetTileCenterPoint(tile_x, tile_z)

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
          end
        end
        -- 触发耕地音效/动画
        doer:PushEvent("tilling")
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

  -- 呼吸灯效果更新函数（由 enable_light_fx 控制）
  local function UpdateLightFX()
    -- 此函数已废弃，呼吸灯效果由 UpdateCaneTint() 处理
    -- 保留空函数避免调用报错
  end

  -- 粒子特效更新函数（由 fx_particle_type 多选项控制）
  local PARTICLE_PREFABS = {
    sparkle = "cane_hh_fx",
    shadow = "cane_shadow_fx",
  }

  local function GetParticlePrefabName()
    return PARTICLE_PREFABS[config.fx_particle_type] or "cane_hh_fx"
  end

  local function UpdateParticleFX()
    if inst.all_active and config.fx_particle_type ~= "none" then
      local prefab_name = GetParticlePrefabName()
      if not inst.light_fx or not inst.light_fx:IsValid() or inst.light_fx.prefab ~= prefab_name then
        -- 移除旧粒子
        if inst.light_fx then
          inst.light_fx:Remove()
          inst.light_fx = nil
        end
        -- 生成新粒子
        inst.light_fx = SpawnPrefab(prefab_name)
        if inst.light_fx then
          inst.light_fx.entity:SetParent(inst.entity)
        end
      end
    else
      if inst.light_fx then
        inst.light_fx:Remove()
        inst.light_fx = nil
      end
    end
  end

  -- 手杖呼吸染色效果（跑马灯版）
  local BREATH_SPEED = 1.2      -- 呼吸周期（秒，越小呼吸越快）
  local BREATH_INTENSITY = 0.6  -- 呼吸强度（0~0.5，越大颜色越鲜艳）
  local COLOR_CYCLE_SPEED = 1.6 -- 颜色跑马灯周期（秒，越小颜色变化越快）
  local cane_tint_task = nil    -- 呼吸定时器
  local cane_tint_time = 0      -- 呼吸计时器

  local function HueToRGB(hue)
    local r = (math.sin(hue) + 1) / 2
    local g = (math.sin(hue + 2.094) + 1) / 2
    local b = (math.sin(hue + 4.189) + 1) / 2
    return r, g, b
  end

  local function StopCaneBreathTint()
    if cane_tint_task then
      cane_tint_task:Cancel()
      cane_tint_task = nil
    end
    cane_tint_time = 0
    -- 清除实体染色
    if inst.AnimState then
      inst.AnimState:SetAddColour(0, 0, 0, 0)
      inst.AnimState:SetHaunted(false)
    end
    -- 清除玩家装备染色
    local owner_t = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()
    if owner_t and owner_t:HasTag("player") and owner_t.AnimState then
      owner_t.AnimState:SetSymbolMultColour("swap_object", 1, 1, 1, 1)
      owner_t.AnimState:SetSymbolAddColour("swap_object", 0, 0, 0, 0)
      -- 清除玩家全身跑马灯
      if owner_t.AnimState then
        owner_t.AnimState:SetAddColour(0, 0, 0, 0)
      end
      owner_t.AnimState:SetHaunted(false)
    end
  end

  local function StartCaneBreathTint()
    StopCaneBreathTint()
    cane_tint_time = 0
    if inst.AnimState then
      inst.AnimState:SetHaunted(true)
    end
    cane_tint_task = inst:DoPeriodicTask(0.05, function() -- 每0.05秒更新一次，让呼吸平滑
      cane_tint_time = cane_tint_time + 0.05

      -- 呼吸强度：0 → 1 → 0 平滑变化
      local phase = (math.sin(cane_tint_time * 2 * math.pi / BREATH_SPEED) + 1) / 2
      local intensity = phase * BREATH_INTENSITY

      -- 跑马灯色相：随时间循环
      local hue = cane_tint_time * 2 * math.pi / COLOR_CYCLE_SPEED
      local cr, cg, cb = HueToRGB(hue)

      -- 1. 手杖实体染色（地上/背包里）→ 彩色发光呼吸
      if inst.AnimState then
        inst.AnimState:SetAddColour(cr * intensity, cg * intensity, cb * intensity, 0)
      end

      -- 2. 玩家手持染色（装备栏 swap_object 符号）
      local owner_t2 = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()
      if owner_t2 and owner_t2:HasTag("player") and owner_t2.AnimState then
        -- MultColour：模型本身轻微偏色（1-intensity*0.2 到 1 之间变化，按当前色相偏转）
        local cm = 1 - intensity * 0.25
        local mr = 1 - (1 - cr) * intensity * 0.25
        local mg = 1 - (1 - cg) * intensity * 0.25
        local mb = 1 - (1 - cb) * intensity * 0.25
        owner_t2.AnimState:SetSymbolMultColour("swap_object", mr, mg, mb, 1)

        -- AddColour：彩色发光叠加层
        local glow_intensity = intensity * 0.8
        if cr + cg + cb > 0.01 then
          owner_t2.AnimState:SetSymbolAddColour("swap_object", cr * glow_intensity, cg * glow_intensity,
            cb * glow_intensity, 0)
        end

        -- 3. 玩家全身跑马灯——仅在手持装备时才显示，物品栏/丢地时清除
        local is_equipped = owner_t2.components.inventory and
            owner_t2.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == inst
        if is_equipped and config.enable_player_glow then
          owner_t2.AnimState:SetHaunted(true)
          local body_intensity = intensity * 0.46 -- 全身效果淡一些
          if cr + cg + cb > 0.01 then
            owner_t2.AnimState:SetAddColour(cr * body_intensity, cg * body_intensity,
              cb * body_intensity, 0)
          else
            owner_t2.AnimState:SetAddColour(0, 0, 0, 0)
          end
        else
          owner_t2.AnimState:SetHaunted(false)
          owner_t2.AnimState:SetAddColour(0, 0, 0, 0)
        end
      end
    end)
  end

  local function UpdateCaneTint()
    if config.enable_light_fx and inst.all_active then
      StartCaneBreathTint()
    else
      StopCaneBreathTint()
    end
  end

  -- 统一更新所有功能
  local function UpdateAllFeatures()
    UpdateToolState()
    UpdateAutoHarvest()
    UpdateAutoFarm()
    -- 粒子特效
    UpdateParticleFX()
    -- 手杖呼吸染色
    UpdateCaneTint()
  end



  -- 右键切换总开关（控制包括自动耕地在内的所有功能）

  -- 组件
  if not inst.components.inventoryitem then
    inst:AddComponent("inventoryitem")
  end
  inst:AddComponent("useableitem")
  inst:AddComponent("named")
  inst.components.useableitem:SetOnUseFn(function(inst)
    local owner = inst.components.inventoryitem:GetGrandOwner()
    if not owner or not owner:HasTag("player") then return false end
    -- 切换开关状态
    inst.all_active = not inst.all_active
    SyncCaneState()
    UpdateAllFeatures()
    -- 切换贴图（换皮肤会丢失logo）
    if config.enable_tool_toggle_icon then
      local invitem = inst.components.inventoryitem
      if inst.all_active then
        invitem.imagename = "xin"
        invitem.atlasname = "images/inventoryimages/xin.xml"
      else
        invitem.imagename = "heh"
        invitem.atlasname = "images/inventoryimages/heh.xml"
      end
      invitem:ChangeImageName(invitem.imagename)
    end
    -- 任务栏小图标显示文字（待实现）
    local status_text = inst.all_active and "󰀏 开/ON 󰀏" or "󰀜 关/OFF 󰀜"
      -- 修改装备名称（根据状态切换）
      if config.enable_tool_toggle_rename then
        inst.components.named:SetName(status_text)
        -- 玩家提示
        if owner.components.talker then
          owner.components.talker:Say("H-手杖 " .. status_text)
        end
      end
      -- 通过快速卸装触发客户端 ItemTile 重建来刷新 UI（替代轮询）
      if inst.components.equippable:IsEquipped() and owner.components.inventory then
        inst._quick_re_equip = true
        local eslot = inst.components.equippable.equipslot
        local returned = owner.components.inventory:Unequip(eslot)
        if returned then
          owner.components.inventory:Equip(returned)
        end
        inst._quick_re_equip = nil
      end
      return false
    end)



  -- 状态保存与加载（总开关统一控制，无需额外保存）
  inst.OnSave = function(inst, data)
    data.all_active = inst.all_active
  end

  inst.OnPreLoad = function(inst, data)
    inst.all_active = data and data.all_active or false
    SyncCaneState()
    UpdateAllFeatures()
  end

  -- 其他配置
  -- 处理防丢失逻辑（根据开关决定是否启用）
  if config.anti_lose and inst.components.inventoryitem then
    -- 防止被偷窃
    inst:AddTag("nosteal")
    -- 防流星破坏
    inst:AddTag("meteor_protection")
    -- 防止BOSS攻击/潮湿/落水导致脱手
    inst.components.inventoryitem.keepondrown = true
    inst.components.inventoryitem:SetOnDroppedFn(nil)
  end
  -- 防雷保护
  if config.lightning_protect_enable then
    if inst.components.equippable then
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
  local AUTO_TEMP_INTERVAL = 3.6

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
      -- 温度设定为36
      doer.components.temperature:SetTemperature(36)
    end
    -- 2. 自身解冻（仅当冻结时）
    -- if doer.components.freezable and doer.components.freezable:IsFrozen() then
    --   doer.components.freezable:Unfreeze()
    -- end
    -- 3. 自身灭火（仅当燃烧时）
    -- if doer.components.burnable and doer.components.burnable:IsBurning() then
    --   doer.components.burnable:Extinguish()
    -- end
  end

  -- 自动工作相关配置与变量
  local AUTO_WORK_INTERVAL = 0.36 -- 自动工作检测间隔（可根据需求调整）
  local auto_work_task = nil      -- 自动工作定时任务句柄

  -- 全科技加成表
  local tech_bonus = {
    SCIENCE = 2,
    MAGIC = 3,
    ANCIENT = 4,
    SEAFARING = 2,
    CELESTIAL = 3,
    SHADOW = 4,
    CARTOGRAPHY = 2,
    SCULPTING = 1,
    BOOKCRAFT = 1,
    ORPHANAGE = 1,
    PERDOFFERING = 3,
    FISHING = 1,
    WARGOFFERING = 3,
    PIGOFFERING = 3,
    CARRATOFFERING = 3,
    BEEFOFFERING = 3,
    DRAGONOFFERING = 3,
    WORMOFFERING = 3,
    RABBITOFFERING = 3,
    CATCOONOFFERING = 3,
    LUNARFORGING = 2,
    SHADOWFORGING = 2,
    MADSCIENCE = 1,
    CARNIVAL_HOSTSHOP = 3,
    FOODPROCESSING = 1,
    CARNIVAL_PRIZESHOP = 1,
    CARPENTRY = 3,
    WINTERSFEASTCOOKING = 1,
    HERMITCRABSHOP = 7,
    RABBITKINGSHOP = 2,
    WANDERINGTRADERSHOP = 2,
    WAGPUNK_WORKSTATION = 1,
    TURFCRAFTING = 2,
    MASHTURFCRAFTING = 2,
    SPIDERCRAFT = 1,
    ROBOTMODULECRAFT = 1,
    SHELLWEAVER = 3,
  }

  -- 独立的自动工作函数
  local _ripening_counter = 0
  local function DoAutotask(inst)
    -- 存在工作范围才开始
    local WORK_RADIUS = config.auto_work_range
    if WORK_RADIUS <= 0 then return end
    -- 通用的人物坐标信息
    local doer = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
    if not doer or not doer:HasTag("player") then return end
    local owner = inst.components.inventoryitem:GetGrandOwner()
    local x, y, z = doer.Transform:GetWorldPosition()

    -- 勋章面板兼容（能力勋章 1909182187）：一次性注册集中回调
    if not owner._hcane_medal_setup then
      owner._hcane_medal_setup = true

      -- 物品变化时立即刷新面板（事件驱动，不等20秒轮询）
      local function OnInventoryChanged()
        owner:PushEvent("medal_buff_update")
      end
      owner:ListenForEvent("itemget", OnInventoryChanged)
      owner:ListenForEvent("itemlose", OnInventoryChanged)

      local _prevGetMedalBuffInfo = owner.GetMedalBuffInfo
      owner.GetMedalBuffInfo = function(self, buff_info)
        if _prevGetMedalBuffInfo then _prevGetMedalBuffInfo(self, buff_info) end
        local inv = self.components.inventory
        if not inv then return end
        -- 收集所有相关的物品（15格 + 装备）
        local pool = { inv:GetItemInSlot(15) }
        if EQUIPSLOTS then
          for _, slot in pairs(EQUIPSLOTS) do
            local e = inv:GetEquippedItem(slot)
            if e then table.insert(pool, e) end
          end
        end
        local function hasAny(...)
          for _, item in ipairs(pool) do
            if item then
              for _, p in ipairs({...}) do
                if item.prefab == p then return true end
              end
            end
          end
          return false
        end
        if self.hwatergo_active then table.insert(buff_info, {buffname="hcane_water_hunger", bufftime=-1}) end
        if hasAny("redgem","redmooneye","amulet") then table.insert(buff_info, {buffname="hcane_red_gem", bufftime=-1}) end
        if hasAny("bluegem","bluemooneye","blueamulet") then table.insert(buff_info, {buffname="hcane_blue_gem", bufftime=-1}) end
        if hasAny("orangegem","orangemooneye","orangeamulet") then table.insert(buff_info, {buffname="hcane_orange_gem", bufftime=-1}) end
        if hasAny("yellowgem","yellowmooneye","yellowamulet") then table.insert(buff_info, {buffname="hcane_yellow_gem", bufftime=-1}) end
        if hasAny("purplegem","purplemooneye","purpleamulet") then table.insert(buff_info, {buffname="hcane_purple_gem", bufftime=-1}) end
        if hasAny("greengem","greenmooneye","greenamulet") then table.insert(buff_info, {buffname="hcane_green_gem", bufftime=-1}) end
        if hasAny("opalpreciousgem") then table.insert(buff_info, {buffname="hcane_opal_gem", bufftime=-1}) end
        if hasAny("lunar_seed") then table.insert(buff_info, {buffname="hcane_celestial", bufftime=-1}) end
        if hasAny("furtuft","bearger_fur") then table.insert(buff_info, {buffname="hcane_bearger", bufftime=-1}) end
        if hasAny("townportaltalisman","antlionhat") then table.insert(buff_info, {buffname="hcane_antlion", bufftime=-1}) end
        if hasAny("glommerflower","fruitflyfruit") then table.insert(buff_info, {buffname="hcane_glommer", bufftime=-1}) end
      end
    end

    -- 保存原始血量上限
    if doer and doer.components.health and not doer._original_maxhealth then
      doer._original_maxhealth = doer.components.health.maxhealth
      doer._health_mult = 1
    end
    -- 保存原始饥饿上限
    if doer and doer.components.hunger and not doer._original_maxhunger then
      doer._original_maxhunger = doer.components.hunger.max
      doer._hunger_mult = 1
    end
    -- 记录原始理智上限
    if doer and doer.components.sanity and not doer._original_maxsanity then
      doer._original_maxsanity = doer.components.sanity.max
      doer._sanity_mult = 1
    end
    -- 2. 计算倍率（基于实体属性取最大）
    local sanity_mult = doer._sanity_mult
    local health_mult = doer._health_mult
    local hunger_mult = doer._hunger_mult

    -- 获取人物15格的东西
    local item = doer.components.inventory:GetItemInSlot(15)
    -- 获取人物装备栏/15格子的东西
    -- 1. 遍历装备槽位
    local items = {}
    if EQUIPSLOTS then
      for k, v in pairs(EQUIPSLOTS) do
        local equip = doer.components.inventory:GetEquippedItem(v)
        if equip then
          items[v] = equip
        end
      end
    end
    items["slot_15"] = doer.components.inventory:GetItemInSlot(15)

    -- 封装检测物品函数
    local function HasTargetItem(items, target_prefabs)
      if not items or not target_prefabs or #target_prefabs == 0 then
        return false
      end
      -- 将目标预制名数组转为集合（键值对），提升查询效率
      local prefab_set = {}
      for _, prefab in ipairs(target_prefabs) do
        prefab_set[prefab] = true
      end
      -- 遍历物品集合
      for _, item in pairs(items) do
        if item and prefab_set[item.prefab] then
          return true
        end
      end
      return false
    end

    -- 封装饥饿代价逻辑为函数
    local function ApplyHungerCost(owner, delta, chance, source)
      if owner and owner.components.hunger and math.random() < chance then
        owner.components.hunger:DoDelta(delta, false, source)
      end
    end

    -- ！！！七色宝石类
    -- 绿色宝石开始
    if HasTargetItem(items, { "greengem", "greenmooneye", "greenamulet" }) then
      doer.components.builder.ingredientmod = 0.5
      if doer ~= nil and not doer:HasTag("fastbuilder") then
        doer:AddTag("fastbuilder")
      end
    else
      doer.components.builder.ingredientmod = 1
      if doer ~= nil and not doer:HasTag("handyperson") then
        doer:RemoveTag("fastbuilder")
      end
    end
    -- 绿色宝石结束

    -- 紫色宝石开始
    if HasTargetItem(items, { "purplegem", "purplemooneye", "purpleamulet" }) then
      doer.components.sanity:SetInducedInsanity(inst, true)
    else
      doer.components.sanity:SetInducedInsanity(inst, false)
    end
    -- 紫色宝石结束

    -- 黄色宝石开始
    if HasTargetItem(items, { "yellowgem", "yellowmooneye", "yellowamulet" }) then
      if config.hcane_light <= 0 then
        if inst._yellow_light == nil or not inst._yellow_light:IsValid() then
          inst._yellow_light = SpawnPrefab('hehu_light')
          if inst._yellow_light then
            -- 设置光效属性
            inst._yellow_light.entity:SetParent(owner and owner.entity or inst.entity)
            inst._yellow_light.entity:AddFollower()
            inst._yellow_light.Light:SetRadius(26)
            inst._yellow_light.Light:Enable(true)
          else
            print("警告：黄色宝石光效预制体创建失败！")
          end
        else
          -- 光效已存在，更新父对象和启用状态
          inst._yellow_light.entity:SetParent(owner and owner.entity or inst.entity)
          inst._yellow_light.Light:Enable(true)
        end
      else
        -- 全局发光已开启，直接修改原有光效的半径
        if inst._light and inst._light:IsValid() then
          inst._light.Light:SetRadius(26)
        end
      end
      inst.components.equippable.walkspeedmult = 1 + config.speed_buff + 0.36
    else
      -- 无黄色宝石或未装备，销毁独立光效
      if inst._yellow_light ~= nil and inst._yellow_light:IsValid() then
        inst._yellow_light:Remove()
      end
      inst._yellow_light = nil
      -- 全局发光开启时，恢复原有光效半径
      if config.hcane_light > 0 and inst._light and inst._light:IsValid() then
        inst._light.Light:SetRadius(config.hcane_light)
      end
      inst.components.equippable.walkspeedmult = 1 + config.speed_buff
    end
    -- 黄色宝石结束

    -- 橙色宝石开始
    if HasTargetItem(items, { "orangegem", "orangemooneye", "orangeamulet" }) then
      -- 传送功能
      if not inst.components.blinkstaff then
        inst:AddComponent("blinkstaff")
        inst.components.blinkstaff:SetFX("sand_puff_large_front", "sand_puff_large_back")
        inst.components.blinkstaff.onblinkfn = onblink
      end
      -- 拾取功能
      local ents = TheSim:FindEntities(x, y, z, WORK_RADIUS,
        nil,
        { "INLIMBO", "FX", "NOCLICK", "burnt", "flower", "dead", "knockbackdelayinteraction", "fire", "minesprung",
          "mineactive", "irreplaceable", "moonglass_geode", "thorny", },
        { "_inventoryitem", "plant", "witherable", "lureplant", "waterplant", "crop", "lichen", "oceanvine", "kelp",
          "catchable", "groundmushroom", "sludgestack", }
      )
      for _, ent in ipairs(ents) do
        -- 懒人护符一样的方式啥都捡起来
        if ent.components.inventoryitem and
            ent.components.inventoryitem.cangoincontainer and
            not ent.components.inventoryitem:IsHeld() and
            doer.components.inventory:CanAcceptCount(ent, 1) > 0 then
          -- 在物品位置生成沙子特效（视觉反馈）
          SpawnPrefab("sand_puff").Transform:SetPosition(ent.Transform:GetWorldPosition())
          -- 记录物品位置用于生成动画
          local v_pos = ent:GetPosition()
          -- 特殊处理陷阱：如果是已触发的陷阱，收获陷阱内容
          if ent.components.trap and ent.components.trap:IsSprung() then
            ent.components.trap:Harvest(doer)
          else
            -- 将物品放入玩家物品栏
            doer.components.inventory:GiveItem(ent, nil, v_pos)
          end
          ApplyHungerCost(owner, -0.6, 0.66, inst.prefab)
          return
        end
      end
    else
      if inst.components.blinkstaff then
        inst:RemoveComponent("blinkstaff")
      end
    end
    -- 橙色宝石结束

    -- 重置宝石攻击标志（由扫描决定是否启用冰火攻击）
    inst._has_redgem = nil
    inst._has_bluegem = nil

    -- 红色宝石开始
    if HasTargetItem(items, { "redgem", "redmooneye", "amulet" }) then
      inst._has_redgem = true
      -- 1. 自身灭火（仅当燃烧时）
      if doer.components.burnable and doer.components.burnable:IsBurning() then
        doer.components.burnable:Extinguish()
        if doer.components.inventory then
          doer.components.inventory:GiveItem(SpawnPrefab("ash"), nil, doer:GetPosition())
        end
      end
      -- 范围治疗周围的友方实体（参考 spider_healer 群体治疗机制 + wortox 灵魂治疗特效）
      if math.random() < 0.16 then
        ApplyHungerCost(owner, -1.6, 0.66, inst.prefab)
        local x, y, z = doer.Transform:GetWorldPosition()
        local HEAL_RADIUS = 6
        local ents = TheSim:FindEntities(x, y, z, HEAL_RADIUS,
          { "_health" },
          { "INLIMBO", "dead", "FX" }
        )
        for _, ent in ipairs(ents) do
          -- 治疗范围内所有有血量的生物（包括中立目标），排除史诗级Boss和建筑/墙体
          if ent.components.health and not ent.components.health:IsDead()
              and not ent:HasTag("epic")
              and not ent:HasTag("wall") and not ent:HasTag("structure") then
            ent.components.health:DoDelta(16, false, inst.prefab)
            -- 播放 wortox 灵魂治疗特效
            local fx = SpawnPrefab("wortox_soul_heal_fx")
            if fx and ent.components.combat and ent.components.combat.hiteffectsymbol then
              fx.entity:AddFollower():FollowSymbol(ent.GUID, ent.components.combat.hiteffectsymbol, 0, -50, 0)
              fx:Setup(ent)
            end
          end
        end
      end
    end
    -- 红色宝石结束

    -- 蓝色宝石开始
    if HasTargetItem(items, { "bluegem", "bluemooneye", "blueamulet" }) then
      inst._has_bluegem = true
      -- 2. 自身解冻（仅当冻结时）
      if doer.components.freezable and doer.components.freezable:IsFrozen() then
        doer.components.freezable:Unfreeze()
        if doer.components.inventory then
          doer.components.inventory:GiveItem(SpawnPrefab("ice"), nil, doer:GetPosition())
        end
      end
      -- 自身理智恢复（10%）
      if math.random() < 0.16 then
        ApplyHungerCost(owner, -1.6, 0.66, inst.prefab)
        if doer.components.sanity then
          doer.components.sanity:DoDelta(16, false, inst.prefab)
          -- 播放 ghostflower_spirit1_fx 特效
          local fx = SpawnPrefab("ghostflower_spirit1_fx")
          if fx then
            fx.Transform:SetPosition(doer.Transform:GetWorldPosition())
          end
        end
      end
    end
    -- 蓝色宝石结束

    -- ！！！高级能力
    -- 彩虹宝石开始
    if HasTargetItem(items, { "opalpreciousgem" }) then
      -- 复制概率为16%
      if math.random() < 0.16 then
        -- 1. 获取玩家第14个物品栏的物品
        local slot_14_item = doer.components.inventory:GetItemInSlot(14)
        -- 2. 严格校验：玩家有效+有物品栏+14栏有有效物品+物品可堆叠+堆叠未达上限
        if doer
            and doer.components.inventory
            and slot_14_item
            and slot_14_item:IsValid()
            and slot_14_item.components.stackable
            and not slot_14_item.components.stackable:IsFull()
        then
          local target_prefab = slot_14_item.prefab
          -- 3. 固定复制1个（不再复制余量）
          local item_copy = SpawnPrefab(target_prefab)
          if item_copy.components.stackable then
            item_copy.components.stackable:SetStackSize(1) -- 每次只加1个
          end
          -- 4. 放入物品栏（自动叠加到14栏物品中）
          doer.components.inventory:GiveItem(item_copy)
          ApplyHungerCost(owner, -16.6, 0.66, inst.prefab)
        end
      end
      if owner.components.hunger then
        owner.components.hunger.burnratemodifiers:SetModifier("hcnae_opalprehunger", 0.06)
      end
    else
      if owner.components.hunger then
        owner.components.hunger.burnratemodifiers:RemoveModifier("hcnae_opalprehunger")
      end
    end
    -- 彩虹宝石结束

    -- 启迪碎片开始（H-装备）
    if HasTargetItem(items, { "alterguardianhat", "alterguardianhatshard" }) then
      -- 全科技解锁
      local builder = owner and owner.components.builder
      if builder ~= nil then
        for k, v in pairs(tech_bonus) do
          builder[string.lower(k) .. "_tempbonus"] = v
        end
      end
    else
      -- 恢复原本科技
      local builder = owner and owner.components.builder
      if builder ~= nil then
        for k, _ in pairs(tech_bonus) do
          builder[string.lower(k) .. "_tempbonus"] = nil
        end
      end
    end
    -- 启迪碎片结束

    -- 天体珠宝开始
    if HasTargetItem(items, { "lunar_seed" }) then
      owner:Hide()
      ApplyHungerCost(owner, -1, 0.36, inst.prefab)
    else
      owner:Show()
    end
    -- 天体珠宝结束

    -- 独眼巨鹿眼球开始
    if HasTargetItem(items, { "deerclops_eyeball" }) then
      -- 触发单挑
      if inst.singlefight_target then
        local ents = TheSim:FindEntities(x, y, z, 36,
          { "_combat" },
          { "INLIMBO", "NOCLICK", "player", "notarget" }
        )
        for _, v in ipairs(ents) do
          -- 非当前单挑目标、存活、且仇恨目标是玩家
          if v ~= inst.singlefight_target
              and v.entity:IsVisible()
              and (not v.components.health or not v.components.health:IsDead())
              and v.components.combat
              and v.components.combat.target == owner then
            v.components.combat:DropTarget(nil) -- 强制清除仇恨
          end
        end
      end
    end
    -- 独眼巨鹿眼球结束

    -- 龙蝇开始
    if HasTargetItem(items, { "dragon_scales" }) then
      if not owner:HasTag("NOTARGET") then
        owner:AddTag("NOTARGET")
      end
    elseif owner:HasTag("NOTARGET") then
      owner:RemoveTag("NOTARGET")
    end
    -- 龙蝇结束

    -- 麋鹿鹅开始
    if HasTargetItem(items, { "goose_feather", "featherfan" }) and owner.components.drownable then
      if not owner.hwatergo_active then
        -- owner.Physics:ClearCollidesWith(COLLISION.LAND_OCEAN_LIMITS)
        -- owner.Physics:ClearCollidesWith(COLLISION.BOAT_LIMITS)
        if owner.Physics then
          RemovePhysicsColliders(owner)
        end
        owner.components.drownable.enabled = false
        if owner.components.hunger then
          owner.components.hunger.burnratemodifiers:SetModifier("hcnae_goose_hunger", 6)
        end
        -- 状态标记
        owner.hwatergo = true
        owner.hwatergo_active = true
      end
    elseif owner.components.drownable and owner.hwatergo then
      -- owner.Physics:CollidesWith(COLLISION.LAND_OCEAN_LIMITS)
      -- owner.Physics:CollidesWith(COLLISION.BOAT_LIMITS)
      if owner.Physics then
        ChangeToCharacterPhysics(owner)
      end
      owner.components.drownable.enabled = true
      if owner.components.hunger then
        owner.components.hunger.burnratemodifiers:RemoveModifier("hcnae_goose_hunger")
      end
      -- 状态标记去除
      owner.hwatergo = nil
      owner.hwatergo_active = nil
    end
    -- 麋鹿鹅结束

    -- 熊大破坏范围开始
    if HasTargetItem(items, { "furtuft", "bearger_fur" }) then
      -- 定义破坏范围（可根据需求调整）
      local DESTROY_RADIUS = config.auto_work_range
      -- 筛选可破坏目标的标签（同原逻辑）
      local WORKABLES_CANT_TAGS = { "insect", "INLIMBO", "structure", "wall", "ignorewalkableplatforms", "ancienttree" }
      local WORKABLES_ONEOF_TAGS = { "CHOP_workable", "DIG_workable", "HAMMER_workable", "MINE_workable" }

      -- 核心破坏函数：传入坐标(x,y,z)，按范围破坏物体
      local function DestroyInRange(inst, x, y, z)
        -- 查找范围内可破坏的物体
        local targets = TheSim:FindEntities(x, y, z, DESTROY_RADIUS, nil, WORKABLES_CANT_TAGS, WORKABLES_ONEOF_TAGS)

        for _, target in ipairs(targets) do
          if target:IsValid() and
              target.components.workable ~= nil and
              target.components.workable:CanBeWorked() and
              target.components.workable.action ~= ACTIONS.NET then
            -- 生成破坏特效（如坍塌效果）
            SpawnPrefab("collapse_small").Transform:SetPosition(target.Transform:GetWorldPosition())
            -- 执行破坏（玩家为主体，可刷勋章）
            target.components.workable:Destroy(owner)
            ApplyHungerCost(owner, -0.6, 0.36, inst.prefab)
          end
        end
      end

      -- 执行破坏
      if owner.components.talker then
        owner.components.talker:Say("󰀌 破坏/Broke 󰀌")
      end
      DestroyInRange(inst, x, y, z)
    end
    -- 熊大破坏范围结束

    -- 远古织影者骨头类装备开始
    if HasTargetItem(items, { "skeletonhat", "thurible", "armorskeleton" }) then
      if math.random() < 0.16 then
        -- 理智
        if owner.components.sanity then
          owner.components.sanity:DoDelta(16, false, inst.prefab)
        end
      end
    end
    -- 远古织影者骨头类装备结束

    -- 毒菌蟾蜍开始
    if HasTargetItem(items, { "sleepbomb", "shroom_skin" }) then
      if not owner.bufulj_active then
        for k, v in pairs(owner.components.inventory.itemslots) do
          if v.components.perishable ~= nil then
            v.components.perishable:StopPerishing()
          end
        end
        owner.bufulj = true
        owner.bufulj_active = true
      end
    elseif owner.bufulj then
      for k, v in pairs(owner.components.inventory.itemslots) do
        if v.components.perishable ~= nil then
          v.components.perishable:StartPerishing()
        end
      end
      owner.bufulj = nil
      owner.bufulj_active = nil
    end
    -- 毒菌蟾蜍结束

    -- ！！！伤害修改类开始
    -- 定义伤害修改的装备组及倍率规则（一站式管理，和三维修改类结构一致）
    local damage_mod_configs = {
      -- 绝望石/套装装备组
      dreadstone = {
        items = { "dreadstone", "armordreadstone", "dreadstonehat", "purebrilliance" },
        damage_mult = 2.6,      -- 基础伤害倍率
        planardamage_mult = 2.6 -- 位面伤害倍率
      },
      -- 暗影碎布类装备组
      voidcloth = {
        items = { "voidcloth", "voidcloth_boomerang", "armor_voidcloth", "voidcloth_umbrella" },
        damage_mult = 4.6,      -- 基础伤害倍率
        planardamage_mult = 3.6 -- 位面伤害倍率
      },
      -- 亮茄套装装备组
      lunarplant = {
        items = { "armor_lunarplant", "lunarplanthat", "sword_lunarplant", "staff_lunarplant" },
        damage_mult = 3.6,      -- 基础伤害倍率
        planardamage_mult = 4.6 -- 位面伤害倍率
      }
    }

    -- 合并所有伤害修改装备为总列表
    local all_damage_gear_list = {}
    for _, damage_config in pairs(damage_mod_configs) do
      for _, gear_item in ipairs(damage_config.items) do
        table.insert(all_damage_gear_list, gear_item)
      end
    end

    -- 伤害修改类外侧判断
    if HasTargetItem(items, all_damage_gear_list) then
      -- 从实体获取历史倍率（作为计算基础，保证只会变大不会变小）
      local current_damage_mult = inst._damage_mult
      local current_planardamage_mult = inst._planardamage_mult

      -- 遍历配置表计算新的倍率（取最大值，保证倍率只增不减）
      for _, damage_config in pairs(damage_mod_configs) do
        if HasTargetItem(items, damage_config.items) then
          current_damage_mult = math.max(current_damage_mult, damage_config.damage_mult or 1)
          current_planardamage_mult = math.max(current_planardamage_mult, damage_config.planardamage_mult or 1)
        end
      end

      -- 应用基础伤害变化（仅当倍率变动时才赋值）
      if inst._damage_mult ~= current_damage_mult then
        inst._damage_mult = current_damage_mult
        print("玩家装备伤害倍率更新：", current_damage_mult)
      end

      -- 应用位面伤害变化（仅当倍率变动时才赋值）
      if inst._planardamage_mult ~= current_planardamage_mult then
        inst._planardamage_mult = current_planardamage_mult
        print("玩家装备位面伤害倍率更新：", current_planardamage_mult)
      end
    end
    -- ！！！伤害修改类结束

    -- ！！！三维修改类开始
    -- 定义装备组及对应的倍率规则（一站式管理，更易维护）
    local gear_mod_configs = {
      -- 远古织影者骨头类装备组
      bone = {
        items = { "shadowheart", "skeletonhat", "thurible", "armorskeleton" },
        sanity_mult = 1.6,
        health_mult = 1.6,
        hunger_mult = 1.6
      },
      -- 暗影心房类装备组
      shadow = {
        items = { "shadowheart_infused", "shadow_beef_bell", "saddle_shadow", "shadow_battleaxe" },
        sanity_mult = 3.6
      },
      -- 火花柜类装备组
      spark = {
        items = { "coolant", "security_pulse_cage", "security_pulse_cage_full", "beargerfur_sack", "deerclopseyeball_sentryward_kit", "houndstooth_blowpipe" },
        health_mult = 3.6,
        hunger_mult = 3.6
      }
    }

    -- 三维修改类合并所有装备为总列表
    local all_mod_gear_list = {}
    for _, gear_config in pairs(gear_mod_configs) do
      for _, gear_item in ipairs(gear_config.items) do
        table.insert(all_mod_gear_list, gear_item)
      end
    end

    -- 三维修改类外侧判断
    if HasTargetItem(items, all_mod_gear_list) then
      -- 遍历配置表计算倍率
      for _, gear_config in pairs(gear_mod_configs) do
        if HasTargetItem(items, gear_config.items) then
          sanity_mult = math.max(sanity_mult, gear_config.sanity_mult or 1)
          health_mult = math.max(health_mult, gear_config.health_mult or 1)
          hunger_mult = math.max(hunger_mult, gear_config.hunger_mult or 1)
        end
      end

      -- 应用变化后的倍率
      if doer._sanity_mult ~= sanity_mult then
        doer.components.sanity.max = doer._original_maxsanity * sanity_mult
        doer._sanity_mult = sanity_mult
        owner.components.sanity:DoDelta(1, false, inst.prefab)
      end

      if doer._health_mult ~= health_mult then
        doer.components.health.maxhealth = doer._original_maxhealth * health_mult
        doer._health_mult = health_mult
        owner.components.health:DoDelta(1, false, inst.prefab)
      end

      if doer._hunger_mult ~= hunger_mult then
        doer.components.hunger.max = doer._original_maxhunger * hunger_mult
        doer._hunger_mult = hunger_mult
        owner.components.hunger:DoDelta(1, false, inst.prefab)
      end
    end
    -- 三维修改类结束

    -- ！！！杂类
    -- 理智减少开始
    if HasTargetItem(items, { "nightmarefuel", "horrorfuel" }) then
      -- 理智减少
      if owner.components.sanity then
        owner.components.sanity:DoDelta(-16, false, inst.prefab)
      end
    end
    -- 理智减少结束

    -- 三维恢复开始
    if HasTargetItem(items, { "moonrockcrater" }) then
      if math.random() < 0.16 then
        -- 生命
        if owner.components.health then
          owner.components.health:DoDelta(6, false, inst.prefab)
        end
        -- 饥饿
        if owner.components.hunger then
          owner.components.hunger:DoDelta(6, false, inst.prefab)
        end
        -- 理智
        if owner.components.sanity then
          owner.components.sanity:DoDelta(6, false, inst.prefab)
        end
      end
    end
    -- 三维恢复结束

    if HasTargetItem(items, { "cookbook" }) then
      if not owner.hfood_active then
        owner:PushEvent("learncookbookstats", inst.prefab)
        owner:AddDebuff("hungerregenbuff", "hungerregenbuff")
        owner.hfood = true
        owner.hfood_active = true
      end
    elseif owner.hfood then
      owner:RemoveDebuff("hungerregenbuff")
      if owner.components.foodmemory ~= nil then
        owner.components.foodmemory:RememberFood("hungerregenbuff")
      end
      owner.hfood = nil
      owner.hfood_active = nil
    end

    -- 范围训牛开始（H-装备）
    if HasTargetItem(items, { "beefalohat", "horn" }) then
      -- 查找范围内的牛
      local beefalos = TheSim:FindEntities(x, y, z, WORK_RADIUS,
        { "beefalo" },                 -- 只找牛
        { "INLIMBO", "dead", "ghost" } -- 排除无效目标
      )
      -- 增加驯服度
      for _, beefalo in ipairs(beefalos) do
        if beefalo:IsValid() and beefalo.components.domesticatable then
          beefalo.components.domesticatable:DeltaDomestication(0.0006)
        end
      end
    end
    -- 范围训牛结束

    -- 范围消除蚁狮坑开始（H-装备）
    if HasTargetItem(items, { "townportaltalisman", "antlionhat" }) then
      -- 查找范围内的蚁狮坑
      local sinkholes = TheSim:FindEntities(x, y, z, WORK_RADIUS,
        { "antlion_sinkhole" }, -- 只找蚁狮坑
        { "FX" }                -- 排除无效目标
      )

      for _, sinkhole in ipairs(sinkholes) do
        if sinkhole:IsValid() then
          -- 直接移除蚁狮坑
          sinkhole:Remove()
          ApplyHungerCost(owner, -6.6, 0.66, inst.prefab)
          -- 可选：生成消除特效
          local fx = SpawnPrefab("collapse_small")
          if fx then
            fx.Transform:SetPosition(sinkhole.Transform:GetWorldPosition())
          end

          -- 可选：播放消除音效
          sinkhole.SoundEmitter:PlaySound("dontstarve/common/destroy_rock")
        end
      end
    end
    -- 范围消除蚁狮坑结束

    -- 耕作先驱帽开始（H-装备）
    if HasTargetItem(items, { "plantregistryhat", "fertilizer" }) then
      local ents = TheSim:FindEntities(x, y, z, WORK_RADIUS, nil, { 'INLIMBO', 'wall', 'shadowminion' })
      for i, ent in ipairs(ents) do
        -- 对有"可照料"组件的植物执行照料操作
        if ent.components.farmplanttendable ~= nil then
          ent.components.farmplanttendable:TendTo(inst)
        end
      end
      -- 核心改进：仅对人物所在tile为中心的地皮补充营养
      local center_tile_x, center_tile_z = TheWorld.Map:GetTileCoordsAtPoint(x, y, z)
      TheWorld.components.farming_manager:AddTileNutrients(
        center_tile_x, center_tile_z, 6, 6, 6
      )
    end
    -- 耕作先驱帽结束

    -- 高级耕作先驱帽开始（H-装备）
    if HasTargetItem(items, { "nutrientsgoggleshat" }) then
      local ents = TheSim:FindEntities(x, y, z, 36, nil, { 'INLIMBO', 'wall', 'shadowminion' })
      for i, ent in ipairs(ents) do
        -- 对有"可照料"组件的植物执行照料操作
        if ent.components.farmplanttendable ~= nil then
          ent.components.farmplanttendable:TendTo(inst)
        end
      end
      -- 核心改进：仅对人物所在tile为中心的3x3（9格）地皮补充营养
      local center_tile_x, center_tile_z = TheWorld.Map:GetTileCoordsAtPoint(x, y, z)
      -- 遍历范围（中心tile ±）
      for dx = -3, 3 do
        for dz = -3, 3 do
          local tile_x = center_tile_x + dx
          local tile_z = center_tile_z + dz
          -- 为9格内的每块有效地皮补充营养
          TheWorld.components.farming_manager:AddTileNutrients(
            tile_x, tile_z, 16, 16, 16
          )
          -- 先将格子坐标转换为世界坐标（取格子中心）
          local world_x, _, world_z = TheWorld.Map:GetTileCenterPoint(tile_x, tile_z)
          -- 给该格子添加16点土壤湿度（和施肥同范围、同数值）
          TheWorld.components.farming_manager:AddSoilMoistureAtPoint(world_x, 0, world_z, 16)
        end
      end
    end
    -- 高级耕作先驱帽结束

    -- 格罗姆之花/友好果蝇果开始（催熟周围作物和植物）
    if HasTargetItem(items, { "glommerflower", "fruitflyfruit" }) then
      -- 催熟频率：每调用10次自动工作执行一次催熟（≈3.6秒）
      _ripening_counter = _ripening_counter + 1
      if _ripening_counter >= 10 then
        _ripening_counter = 0

        -- 查找范围内可催熟的目标
        local ents = TheSim:FindEntities(x, y, z, WORK_RADIUS, nil,
          { "INLIMBO", "FX", "burnt", "dead", "stump" })

        -- 仿官方 trygrowth 催熟逻辑（带过熟保护）
        local function TryGrowth(ent)
          if not ent:IsValid() then return end

          -- 前置跳过：枯萎/腐烂的植物不再处理
          if ent:HasTag("withered") or ent:HasTag("farm_plant_killjoy") then
            return
          end

          -- 前置跳过：已可采摘 → 防止过熟（对应 stage 5 full / 浆果成熟）
          if ent.components.pickable ~= nil and ent.components.pickable:CanBePicked() then
            return
          end

          -- 前置跳过：crop 已成熟
          if ent.components.crop ~= nil and ent.components.crop.matured then
            return
          end

          -- 1. Growable 组件（树木、农场作物等）
          if ent.components.growable ~= nil then
            if ent.components.simplemagicgrower ~= nil then
              ent.components.simplemagicgrower:StartGrowing()
              return
            elseif ent.components.growable.domagicgrowthfn ~= nil then
              -- 农场作物（domagicgrowthfn）：额外检查是否已到最终腐烂阶段
              if ent.components.growable.stage >= #ent.components.growable.stages then
                return
              end
              ent.components.growable:DoMagicGrowth()
              return
            else
              ent.components.growable:DoGrowth()
              return
            end
          end

          -- 2. Pickable 组件（浆果丛、草根等）— 仅催熟未成熟的
          if ent.components.pickable ~= nil then
            if not ent.components.pickable:CanBePicked() or not ent.components.pickable.caninteractwith then
              if ent.components.pickable:FinishGrowing() then
                ent.components.pickable:ConsumeCycles(1)
              end
            end
            return
          end

          -- 3. Crop 组件（旧版农场作物）
          if ent.components.crop ~= nil and (ent.components.crop.rate or 0) > 0 then
            ent.components.crop:DoGrow(1 / ent.components.crop.rate, true)
            return
          end

          -- 4. Harvestable 组件（蘑菇农场等）
          if ent.components.harvestable ~= nil then
            if ent.components.harvestable:IsMagicGrowable() then
              ent.components.harvestable:DoMagicGrowth()
            elseif not ent.components.harvestable:CanBeHarvested() then
              ent.components.harvestable:Grow()
            end
            return
          end
        end

        for _, ent in ipairs(ents) do
          TryGrowth(ent)
        end

        -- 为作物补充营养（仿 MaximizePlant / 高级耕作先驱帽）
        if TheWorld.components.farming_manager then
          local center_tile_x, center_tile_z = TheWorld.Map:GetTileCoordsAtPoint(x, y, z)
          for dx = -2, 2 do
            for dz = -2, 2 do
              TheWorld.components.farming_manager:AddTileNutrients(
                center_tile_x + dx, center_tile_z + dz, 12, 12, 12
              )
            end
          end
        end

        -- 播放催熟传送特效（vault_portal_fx）
        local fx = SpawnPrefab("vault_portal_fx")
        if fx then
          local px, py, pz = owner.Transform:GetWorldPosition()
          fx.Transform:SetPosition(px, py, pz)
        end

        ApplyHungerCost(owner, -16, 0.36, inst.prefab)
      end
    end
    -- 格罗姆之花/友好果蝇果结束

    -- 范围催眠开始（H-装备）
    if HasTargetItem(items, { "mandrake", "panflute" }) then
      -- 范围催眠10+WORK_RADIUS范围内的所有实体
      local ents = TheSim:FindEntities(x, y, z, WORK_RADIUS + 10, nil, { "INLIMBO", "player", "dead", "ghost" }) -- 直接过滤玩家标签
      for _, ent in ipairs(ents) do
        -- 排除特殊状态生物（可选，也可直接删掉这几行更简化）
        if not (ent.components.freezable and ent.components.freezable:IsFrozen()) then
          -- 给生物加睡眠值（10点足够直接入睡，时长用原版排箫的10秒即可）
          if ent.components.sleeper then
            ent.components.sleeper:AddSleepiness(16, 66)
          else
            ent:PushEvent("knockedout")
          end
        end
      end
    end
    -- 范围催眠结束

    -- 自动播种
    -- 种种子，先检查槽位物品是否为可种植物，避免误吞非种子物品
    if item and item.components.farmplantable then
      for _, soil_ent in ipairs(TheSim:FindEntities(x, y, z, WORK_RADIUS, { "soil" }, { "NOCLICK" })) do
        -- 在确认是可种植物后再从容器中取出尝试播种；失败则归还(搞不明白怎么直接用item播种会出问题，只能用复制品)
        local seed = SpawnPrefab(item.prefab)
        -- print("尝试自动播种：" .. item.prefab)
        if seed and seed.components.farmplantable then
          if not seed.components.farmplantable:Plant(soil_ent, doer) then
            doer.components.inventory:GiveItem(seed)
            break
          end
        else
          -- 如果取出后发现不是可种植物，归还并停止
          if seed then
            doer.components.inventory:GiveItem(seed)
          end
          break
        end
      end
    end
    -- 种杂草
    if HasTargetItem(items, { "forgetmelots", "forgetmelots_dried", "tillweed", "firenettles", "tillweed_dried", "firenettles_dried" }) then
      -- 杂草对应的实体
      local SPECIAL_SEED_WEED_MAP = {
        -- 必忘我
        forgetmelots = "weed_forgetmelots",
        forgetmelots_dried = "weed_forgetmelots",
        -- 犁地草
        tillweed = "weed_tillweed",
        tillweed_dried = "weed_tillweed",
        -- 火荨麻
        firenettles = "weed_firenettle",
        firenettles_dried = "weed_firenettle",
      }
      for _, soil_ent in ipairs(TheSim:FindEntities(x, y, z, WORK_RADIUS, { "soil" }, { "NOCLICK" })) do
        local s_x, s_y, s_z = soil_ent.Transform:GetWorldPosition()
        -- 获取杂草对应作物
        soil_ent:Remove()
        local weed = SpawnPrefab(SPECIAL_SEED_WEED_MAP[item.prefab])
        weed.Transform:SetPosition(s_x, s_y, s_z)
      end
    end
    -- 结束自动播种
  end

  -- 装备/卸下事件
  if inst.components.equippable then
    -- 装备时启动相关任务
    inst:ListenForEvent("equipped", function(_, data)
      inst.hdore = nil
      inst.hdore = data.owner
      if data and data.owner and data.owner:HasTag("player") then
        local doer = data.owner
        if config.constant_temp_effect_enable then
          -- 先停止可能存在的旧任务（避免重复启动）
          if auto_temp_task then
            auto_temp_task:Cancel()
            auto_temp_task = nil
          end
          -- 启动新的自动温控任务（0.6秒间隔）
          auto_temp_task = inst:DoPeriodicTask(AUTO_TEMP_INTERVAL, function()
            DoAutoTempControl(inst)
          end)
        end
        -- 自动工作：装备时启动
        if config.auto_work_range > 0 and config.enable_slot then
          if auto_work_task then
            auto_work_task:Cancel()
            auto_work_task = nil
          end
          auto_work_task = inst:DoPeriodicTask(AUTO_WORK_INTERVAL, function()
            DoAutotask(inst)
          end)
        end
        -- 装备时同步所有右键控制功能状态
        UpdateAllFeatures()
      end
    end)
    -- 卸下时停止相关任务
    inst:ListenForEvent("unequipped", function(_, data)
      if inst._quick_re_equip then return end  -- 快速切换卸装中，跳过清理
      if data and data.owner and data.owner:HasTag("player") then
        local doer = data.owner
        -- 自动工作任务清理
        if auto_work_task then
          auto_work_task:Cancel()
          auto_work_task = nil
        end
        -- 理智/建造恢复默认状态
        if doer.components.sanity then
          doer.components.sanity:SetInducedInsanity(inst, false)
        end
        if doer.components.builder then
          doer.components.builder.ingredientmod = 1
        end

        -- 显示人物
        doer:Show()
        -- 恢复原本科技
        local builder = doer and doer.components.builder
        if builder ~= nil then
          for k, _ in pairs(tech_bonus) do
            builder[string.lower(k) .. "_tempbonus"] = nil
          end
        end
        -- 移除传送功能（如果存在）
        if inst.components.blinkstaff then
          inst:RemoveComponent("blinkstaff")
        end
        -- 手杖呼吸染色清理（防止遗留在玩家身上）
        if doer.AnimState then
          doer.AnimState:SetSymbolMultColour("swap_object", 1, 1, 1, 1)
          doer.AnimState:SetSymbolAddColour("swap_object", 0, 0, 0, 0)
          doer.AnimState:SetAddColour(0, 0, 0, 0) -- 清除全身跑马灯
        end
        -- 右键状态
        if config.multi_tool_state_save then
          -- 卸下时同步所有右键控制功能状态
          UpdateAllFeatures()
        else
          -- 不保存状态时，关闭全部右键控制项
          inst.all_active = false
          SyncCaneState()
          UpdateAllFeatures()
        end
      end
    end)
  end

  -- 2. 物品掉落时的事件
  inst:ListenForEvent("ondropped", function(inst)
    -- 获取掉落前的持有者（通过inventoryitem组件）
    if inst.hdore then
      local doer = inst.hdore
      -- 停止自动温控任务
      if config.constant_temp_effect_enable then
        if auto_temp_task then
          auto_temp_task:Cancel()
          auto_temp_task = nil
        end
      end
      -- 三维恢复
      if doer and doer._original_maxhealth and doer.components.health then
        doer.components.health.maxhealth = doer._original_maxhealth
      end
      if doer and doer._original_maxhunger and doer.components.hunger then
        doer.components.hunger.max = doer._original_maxhunger
      end
      if doer and doer._original_maxsanity and doer.components.sanity then
        doer.components.sanity.max = doer._original_maxsanity
      end
      doer._original_maxhealth = nil
      doer._original_maxhunger = nil
      doer._original_maxsanity = nil
      -- 伤害恢复
      inst._damage_mult = 1
      inst._planardamage_mult = 1
    end
  end)

  -- 销毁清理
  inst:ListenForEvent("onremove", function()
    if auto_harvest_task then
      auto_harvest_task:Cancel()
    end
    if auto_farm_task then
      auto_farm_task:Cancel()
    end
    if auto_work_task then
      auto_work_task:Cancel()
    end
    -- 呼吸染色清理
    StopCaneBreathTint()
    -- 光效清理
    if inst.light_fx then
      inst.light_fx:Remove()
    end
  end)
  -- 结束
end)

--骨头碎片1和犬牙1制作海象牙
if config.enable_walrus_tusk_craft then
  AddRecipe2("walrus_tusk", { Ingredient("boneshard", 1), Ingredient("houndstooth", 1) },
    TECH.NONE, nil,
    { "REFINE", })

  AddPrefabPostInit("houndbone", function(inst)
    -- 只在服务端生效
    if not TheWorld.ismastersim then
      return inst
    end
    -- 检查是否有掉落物组件，有的话修改掉落配置
    if config.enable_walrus_tusk_drop then
      inst.components.lootdropper:AddChanceLoot("houndstooth", 0.66)
    end
  end)
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

-- 客户端：手杖图标高亮 + "开/关"文字显示
-- 参考 Insight 2189004162 的 Widget 着色方式：直接操纵 ItemTile 的 image:SetTint()
-- 参考 DST 原生潮湿系统：通过标签 + 定期检测来控制 UI 叠加层显示
if not GLOBAL.TheNet:IsDedicated() then
  -- 导入 widget 类（modmain.lua 全局作用域中没有 Text/Image）
  local Text = GLOBAL.require("widgets/text")
  local Image = GLOBAL.require("widgets/image")
  local NUMBERFONT = GLOBAL.NUMBERFONT

  AddClassPostConstruct("widgets/itemtile", function(self, invitem)
    if invitem.prefab ~= "cane" then return end

    -- 添加状态文字（仿照 DST 的堆叠数量/百分比文字系统）
    self._cane_label = self:AddChild(Text(NUMBERFONT, 40))
    self._cane_label:SetPosition(0, -22, 0)
    self._cane_label:Hide()

    -- 文字跑马灯动画（HueToRGB 色相循环）
    local color_cycle_time = 0
    local color_task = nil
    local COLOR_CYCLE_SPEED = 1.6 -- 跑马灯周期（秒，N 秒一圈）

    -- 复制服务端的 HueToRGB（客户端闭包内无法访问服务端 local 函数）
    local function HueToRGB(hue)
      local r = (math.sin(hue) + 1) / 2
      local g = (math.sin(hue + 2.094) + 1) / 2
      local b = (math.sin(hue + 4.189) + 1) / 2
      return r, g, b
    end

    local function StopColorCycle()
      if color_task then
        color_task:Cancel()
        color_task = nil
      end
      color_cycle_time = 0
    end

    local function StartColorCycle()
      StopColorCycle()
      color_task = self.inst:DoPeriodicTask(0.05, function()
        color_cycle_time = color_cycle_time + 0.05
        local hue = color_cycle_time * 2 * math.pi / COLOR_CYCLE_SPEED
        local cr, cg, cb = HueToRGB(hue)

        -- 图标着色（混入白色提亮暗色图标：40%颜色+60%白底）
        self.image:SetTint(cr * 0.4 + 0.6, cg * 0.4 + 0.6, cb * 0.4 + 0.6, 1)

        -- 文字着色（仅当文字可见时）
        if self._cane_label and self._cane_label.shown then
          self._cane_label:SetColour(cr, cg, cb, 1)
        end
      end)
    end

    -- 刷新高亮状态的函数（0.2s 轮询检测 ON/OFF 切换）
    local function UpdateCaneTileHighlight()
      if not self._cane_label or not self.image then return end
      local is_on = self.item and self.item:HasTag("caneon")
      -- 状态无变化则跳过
      if is_on == self._cane_last_on then return end
      self._cane_last_on = is_on

      if is_on then
        -- 图标着色 + 文字颜色（受 enable_light_fx 控制）
        if config.enable_light_fx then
          self.image:SetTint(0.4, 1, 0.4, 1) -- 初始绿色，跑马灯会接管
          StartColorCycle()
        else
          self.image:SetTint(1, 1, 1, 1)
          StopColorCycle()
        end
        -- 文字（受 cane_icon_text 控制）
        if config.cane_icon_text then
          self._cane_label:SetString("󰀏 开")
          if config.enable_light_fx then
            -- 跑马灯颜色由动画驱动
          else
            self._cane_label:SetColour(1, 1, 1, 1) -- 纯白
          end
          self._cane_label:Show()
        else
          self._cane_label:Hide()
        end
      else
        self.image:SetTint(1, 1, 1, 1)
        StopColorCycle()
        if config.cane_icon_text then
          self._cane_label:SetString("󰀜 关")
          self._cane_label:SetColour(1, 1, 1, 1)
          self._cane_label:Show()
        else
          self._cane_label:Hide()
        end
      end
    end

    -- 立即刷新（后续由服务端快速卸装触发 ItemTile 重建来刷新）
    UpdateCaneTileHighlight()

    -- 清理
    self.inst:ListenForEvent("onremove", function()
      StopColorCycle()
      if self._cane_label then
        self._cane_label:Kill(); self._cane_label = nil
      end
    end)
  end)
end
