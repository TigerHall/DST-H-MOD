-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })

-- 获取配置项（GetModConfigData 在 modmain 顶层可能返回 nil，均加 or 兜底）
local config = {
  light_radius = GetModConfigData("OceanTreeLightRadius") or 0,
  shrink_scale = GetModConfigData("OceanTreeShrinkScale") or 0,
  ocean_tree_cooldown = GetModConfigData("ocean_tree_cooldown"),
  ovshrink_scale = GetModConfigData("OceanVineShrinkScale") or 0,
  ocean_tree_no_block = GetModConfigData("ocean_tree_no_block"),
  fig_harvest_count = GetModConfigData("fig_harvest_count") or 1,
  show_leafcanopy = GetModConfigData("show_leafcanopy"),
  glommerfuel_edible = GetModConfigData("glommerfuel_edible"),
  glommerfuel_period = GetModConfigData("glommerfuel_period") or 0,
  glommerfuel_remove_transplant = GetModConfigData("glommerfuel_remove_transplant"),
  glommer_sanityaura = GetModConfigData("glommer_sanityaura") or 0,
  sgj_fl = GetModConfigData("sgj_fl"),
  glmny_fl = GetModConfigData("glmny_fl"),
  OceanTreeShadeRange = GetModConfigData("OceanTreeShadeRange") or 22,
  glommer_strong = GetModConfigData("glommer_strong"),
  bullkelp_no_placement_space = GetModConfigData("bullkelp_no_placement_space"),
  farming_utility = GetModConfigData("farming_utility"),
  farming_combat = GetModConfigData("farming_combat"),
  farming_mount = GetModConfigData("farming_mount"),
}

-- 设置全局调优参数
-- TUNING.OceanTreeLightRadius = GetModConfigData("OceanTreeLightRadius")

-- 实体/特效引用
PrefabFiles = {
  "oceantree_light",
}


if config.OceanTreeShadeRange > 22 then
  TUNING.SHADE_CANOPY_RANGE_SMALL = config.OceanTreeShadeRange
end

local function add_ocean_tree_cooldown(inst)
  -- 此处给主机和客机都添加这个组件
  if not inst.components.temperatureoverrider then
    inst:AddComponent("temperatureoverrider")
  end
  if not TheWorld.ismastersim then
    return
  end
  -- 此处是 deerclopseyeball_sentryward.lua 文件差不多 498 行官方的源代码
  inst.components.temperatureoverrider:SetRadius(TUNING.SHADE_CANOPY_RANGE_SMALL)
  inst.components.temperatureoverrider:SetTemperature(16)
  -- 如果是我，我会选择添加个延迟，这个延迟函数差不多会在游戏完全加载完再执行
  -- 为什么加这个延迟？因为原版需要塞眼球才会生效，那自然是游戏完全加载后（尽可能保持和原版逻辑接近）
  -- 虽然可能意义不大，单纯了预防措施罢了
  inst:DoTaskInTime(0.6, function()
    inst.components.temperatureoverrider:Enable()
  end)
end

-- 修改水中木
AddPrefabPostInit("oceantree_pillar", function(inst)
  -- 添加树冠控温效果 config.ocean_tree_cooldown
  if config.ocean_tree_cooldown then
    add_ocean_tree_cooldown(inst)
  end

  -- 只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end

  -- 范围不为0时添加发光效果
  if config.light_radius > 0 then
    inst.tree_light = SpawnPrefab('oceantree_light')
    if inst.tree_light then
      inst.tree_light.entity:SetParent(inst.entity)
      inst.tree_light.Light:SetRadius(config.light_radius)
      inst.tree_light.Light:Enable(true)
    else
      print("警告：树光效预制体创建失败！")
    end
    -- 时间监听函数：整合判断逻辑
    local function UpdateLightState(inst, phase)
      -- 非白天时开启发光（范围已在外部判定>0）
      if phase ~= "day" then
        inst.tree_light.Light:Enable(true)
      else
        inst.tree_light.Light:Enable(false)
      end
    end

    -- 监听世界时间变化
    inst:WatchWorldState("phase", UpdateLightState)
    -- 初始化时设置当前状态
    UpdateLightState(inst, TheWorld.state.phase)
  end

  -- 仅当比例值大于0时修改
  if config.shrink_scale > 0 then
    inst.Transform:SetScale(config.shrink_scale, config.shrink_scale, config.shrink_scale)
  end

  -- 不阻碍铺设地皮
  if config.ocean_tree_no_block then
    inst:AddTag("NOBLOCK")
  end


  -- 销毁处理
  inst:ListenForEvent("onremove", function()
    if inst.components.temperatureoverrider then
      inst.components.temperatureoverrider:Disable()
    end
    if inst.tree_light then
      inst.tree_light.Light:Enable(false)
    end
  end)
  --修改结束
end)

-- 修改苔藓藤条
AddPrefabPostInit("oceanvine", function(inst)
  -- 只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end

  -- 仅当比例值大于0时修改
  if config.ovshrink_scale > 0 then
    inst.Transform:SetScale(config.ovshrink_scale, config.ovshrink_scale, config.ovshrink_scale)
  end

  -- 应用收获数量配置
  if inst.components.pickable then
    -- 确保配置值有效（至少为1）
    local harvest_count = math.max(1, config.fig_harvest_count)
    -- 设置每次收获的数量
    inst.components.pickable.numtoharvest = harvest_count
    -- 重新初始化采摘组件（确保生效）
    inst.components.pickable:SetUp("fig", TUNING.OCEANVINE_REGROW_TIME, harvest_count)
  end

  --修改结束
end)

-- 修改格罗姆
AddPrefabPostInit("glommer", function(inst)
  -- 只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end
  -- 修改格罗姆粘液的产出速度
  if config.glommerfuel_period > 0 and inst.components.periodicspawner then
    inst.components.periodicspawner.basetime = config.glommerfuel_period * 60
    inst.components.periodicspawner.randtime = 1
  end
  --修改结束

  -- 修改格罗姆粘液的产出速度
  if config.glommer_sanityaura > 0 and inst.components.sanityaura then
    inst.components.sanityaura.aura = config.glommer_sanityaura
  end
  if config.glommer_strong then
    -- 回血和伤害吸收百分比
    if inst.components.health then
      inst.components.health:SetMaxHealth(666)
      inst.components.health:StartRegen(66, 6)
      inst.components.health:SetAbsorptionAmount(0.06)
    end
  end
end)

-- 修改格罗姆粘液
AddPrefabPostInit("glommerfuel", function(inst)
  -- 只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end
  -- 修改格罗姆粘液的食用效果
  if config.glommerfuel_edible and inst.components.edible then
    inst:AddTag("pre-preparedfood")
    inst.components.edible.foodtype = FOODTYPE.GOODIES
    inst.components.edible.healthvalue = 166
    inst.components.edible.hungervalue = 166
    inst.components.edible.sanityvalue = -166
  end

  -- 修改格罗姆粘液的肥料效果
  if config.glmny_fl and inst.components.fertilizer then
    inst.components.fertilizer:SetNutrients(66, 66, 66)
    -- 怎么让格罗姆粘液施肥移除种植标记？
  end

  --修改结束
end)

-- 修改树果酱
AddPrefabPostInit("treegrowthsolution", function(inst)
  -- 只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end
  -- 修改树果酱的肥料效果
  if config.sgj_fl and inst.components.fertilizer then
    inst.components.fertilizer:SetNutrients(166, 166, 166)
  end
  --修改结束
end)


-- 格罗姆粘液施肥移除移植标记
if config.glommerfuel_remove_transplant then
  -- 移除原有的施肥类型配置依赖，仅保留格罗姆粪便逻辑
  local function refertilize(self)
    local oldfertilize = self.Fertilize
    self.Fertilize = function(self, fertilizer, doer)
      -- 仅当使用格罗姆粪便施肥时，移除移植标记
      if fertilizer.prefab == "glommerfuel" then
        -- 移除移植标记变成原生作物
        self.transplanted = false
        -- 不会夏天枯萎
        if self.inst.components.witherable then
          -- 设置高温枯萎温度为极高值
          self.inst.components.witherable.wither_temp = 160
          -- 停止枯萎组件并移除
          -- self.inst.components.witherable:Stop()
          -- self.inst:RemoveComponent("witherable")
        end
        -- 添加野火保护标签
        self.inst:AddTag("wildfireprotected")
      end
      oldfertilize(self, fertilizer, doer)
      return true
    end
  end
  -- 所有可移植作物变为原生
  AddComponentPostInit("pickable", refertilize)
end


-- 修改公牛海带
AddPrefabPostInit("bullkelp_plant", function(inst)
  -- 只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end
  if config.bullkelp_no_placement_space then
    inst:AddTag("NOBLOCK")
  end
end)

---------------------------------------------------------------------------------------------------------
-- 耕作帽：功能强化（夜视+防风暴+防水+恒温）
---------------------------------------------------------------------------------------------------------
if config.farming_utility then
  local HAT_NV_COLOURCUBES = {
    day = "images/colour_cubes/identity_colourcube.tex",
    dusk = "images/colour_cubes/identity_colourcube.tex",
    night = "images/colour_cubes/identity_colourcube.tex",
    full_moon = "images/colour_cubes/identity_colourcube.tex",
  }

  -- 客户端：设置夜视（由 net_bool dirty 事件触发）
  local function SetHatNightVision(inst)
    if not inst.components.playervision then return end
    if inst._htree_nv and inst._htree_nv:value() then
      inst.components.playervision:ForceGoggleVision(true)
      inst.components.playervision:PushForcedNightVision(
        "htree_nightvision", 1, HAT_NV_COLOURCUBES, true)
    else
      inst.components.playervision:ForceGoggleVision(false)
      inst.components.playervision:PopForcedNightVision("htree_nightvision")
    end
  end

  -- 玩家初始化：添加 net_bool 同步夜视状态
  AddPlayerPostInit(function(inst)
    inst._htree_nv = GLOBAL.net_bool(inst.GUID, "_htree_nv", "_htree_nvdirty")
    inst:ListenForEvent("_htree_nvdirty", SetHatNightVision)
  end)

  -- hook 体温上限/下限
  AddComponentPostInit("temperature", function(self)
    local oldSetTemp = self.SetTemperature
    self.SetTemperature = function(self, value, ...)
      local inv = self.inst.components.inventory
      if inv then
        if inv:EquipHasTag("htree_nooverheat") then
          value = math.min(value, 36)
        end
        if inv:EquipHasTag("htree_nofreeze") then
          value = math.max(value, 16)
        end
      end
      oldSetTemp(self, value, ...)
    end
  end)

  -- 装备时立即钳位体温
  local function ClampPlayerTemp(owner)
    if not owner or not owner.components.temperature then return end
    local current = owner.components.temperature:GetCurrent()
    local inv = owner.components.inventory
    if inv then
      if inv:EquipHasTag("htree_nooverheat") and current > 36 then
        owner.components.temperature:SetTemperature(36)
      end
      if inv:EquipHasTag("htree_nofreeze") and current < 16 then
        owner.components.temperature:SetTemperature(16)
      end
    end
  end

  for _, prefab in ipairs({ "plantregistryhat", "nutrientsgoggleshat" }) do
    AddPrefabPostInit(prefab, function(inst)
      if not TheWorld.ismastersim then return end

      -- 防水
      inst:AddComponent("waterproofer")
      inst.components.waterproofer:SetEffectiveness(1)

      -- 恒温标签
      inst:AddTag("htree_nooverheat")
      inst:AddTag("htree_nofreeze")

      -- hook 装备/卸下
      local _onequip = inst.components.equippable.onequipfn
      inst.components.equippable.onequipfn = function(inst, owner)
        if _onequip then _onequip(inst, owner) end
        if owner and owner._htree_nv then
          owner._htree_nv:set(true)
        end
        ClampPlayerTemp(owner)
      end

      local _onunequip = inst.components.equippable.onunequipfn
      inst.components.equippable.onunequipfn = function(inst, owner)
        if _onunequip then _onunequip(inst, owner) end
        if owner and owner._htree_nv then
          owner._htree_nv:set(false)
        end
      end
    end)
  end

  ---------------------------------------------------------------------------------------------------------
  -- 客户端：屏蔽护目镜黑边（goggle_over.tex 四角黑边 + nutrients_over.tex 营养目镜覆盖）
  --
  -- 官方机制：ForceGoggleVision(true) → PushEvent("gogglevision") → 多个消费者同时响应：
  --   · GogglesOver:ToggleGoggles(true)  → 显示 goggle_over.tex【四角黑边，要去掉】
  --   · NutrientsOver（由 nutrientsvision 事件驱动）→ nutrients_over.tex【营养覆盖，一并去掉】
  --   · SandOver/MiasmaOver/MoonstormOver:BlindTo(0) → 沙暴/毒气/月暴不致盲【防风沙，必须保留】
  --   · SGwilson 护目镜动画 → 保留
  -- 官方没有"只关黑边"的设置（config.lua 的 hide_vignette 只关 PlayerHud 常驻暗角）。
  -- 滤镜RR 的 "过滤沙漠风沙" hook 的是 sandover 沙尘粒子，不碰 goggle_over；其
  -- Hooker_Specific_Goggles_Disable 定义了却没调用（死代码），所以没有现成开关可抄。
  --
  -- 判断依据：直接读 net_bool _htree_nv —— 它精准表示"本 MOD 帽子激活了强制护目镜视觉"，
  --   比运行时反查 head prefab 可靠，也不会误伤官方护目镜/别人的帽子。
  -- 时序：AddClassPostConstruct 在构造末尾才装 hook，构造内首次 ToggleGoggles(true) 走的是原方法，
  --   所以末尾按当前状态补一次强制隐藏；之后 _htree_nvdirty → ForceGoggleVision 再触发时已被 hook 拦住。
  -- 注意：只压 show=false 走原方法收起（保证 storm_overlays 归位），不 return 跳过，
  --   否则 show=false 时也会跳过原方法导致 storm_overlays 卡在 gogglesover 里。
  ---------------------------------------------------------------------------------------------------------
  if not GLOBAL.TheNet:IsDedicated() then
    local FARMING_HAT_PREFABS = { plantregistryhat = true, nutrientsgoggleshat = true }
    local function IsOurHatGoggle(owner)
      if owner == nil then return false end
      -- 首选：net_bool，与 ForceGoggleVision 同源，天然同步
      if owner._htree_nv ~= nil and owner._htree_nv:value() then
        return true
      end
      -- 兜底：反查头部装备名（net_bool 比 equip 事件慢一帧时仍能命中）
      local inv = (owner.replica ~= nil and owner.replica.inventory)
        or (owner.components ~= nil and owner.components.inventory)
      local head = inv ~= nil and inv.GetEquippedItem ~= nil
        and inv:GetEquippedItem(GLOBAL.EQUIPSLOTS.HEAD) or nil
      return head ~= nil and FARMING_HAT_PREFABS[head.prefab] == true
    end

    AddClassPostConstruct("widgets/gogglesover", function(self)
      local _ToggleGoggles = self.ToggleGoggles
      self.ToggleGoggles = function(self, show, ...)
        if show and IsOurHatGoggle(self.owner) then
          show = false  -- 本 MOD 帽子：压成隐藏，走原方法正常收起（含 storm_overlays 归位）
        end
        return _ToggleGoggles(self, show, ...)
      end
      -- 构造内可能已显示一次（hook 装上前来不及拦），按当前状态补隐藏
      if self.shown and IsOurHatGoggle(self.owner) then
        _ToggleGoggles(self, false)
      end
    end)

    AddClassPostConstruct("widgets/nutrientsover", function(self)
      local _ToggleNutrients = self.ToggleNutrients
      self.ToggleNutrients = function(self, show, ...)
        if show and IsOurHatGoggle(self.owner) then
          show = false
        end
        return _ToggleNutrients(self, show, ...)
      end
      if self.shown and IsOurHatGoggle(self.owner) then
        _ToggleNutrients(self, false)
      end
    end)
  end
end

---------------------------------------------------------------------------------------------------------
-- 耕作帽：战斗强化（防御+位面防+阵营友好+防火+不可燃烧冰冻催眠）
---------------------------------------------------------------------------------------------------------
if config.farming_combat then
  -- hook 冰冻免疫：检查装备上 htree_nofreeze 标签
  AddComponentPostInit("freezable", function(self)
    local oldAddColdness = self.AddColdness
    self.AddColdness = function(self, amount, ...)
      if self.inst and self.inst.components.inventory
          and self.inst.components.inventory:EquipHasTag("htree_nofreeze") then
        return -- 有免疫标签，拒绝冰冻
      end
      oldAddColdness(self, amount, ...)
    end
  end)

  -- hook 催眠免疫：检查装备上 htree_nosleep 标签
  AddComponentPostInit("sleeper", function(self)
    local oldGoToSleep = self.GoToSleep
    self.GoToSleep = function(self, sleeptime, ...)
      if self.inst and self.inst.components.inventory
          and self.inst.components.inventory:EquipHasTag("htree_nosleep") then
        return -- 有免疫标签，拒绝催眠
      end
      oldGoToSleep(self, sleeptime, ...)
    end
  end)

  -- 反伤断链标志（所有耕作帽共享）：防两个同款帽子玩家互殴时反伤无限递归
  -- 注：resistance 抵挡时推的是 blocked 事件（无 stimuli 字段），故用共享 flag 而非 stimuli 断链
  local reflecting = false

  local function SetupHatCombat(prefab, armor, planar, fireproof)
    AddPrefabPostInit(prefab, function(inst)
      if not TheWorld.ismastersim then return end

      -- 普通防御 + 位面防御
      inst:AddComponent("armor")
      inst:AddTag("hide_percentage")
      inst.components.armor:InitIndestructible(armor)

      inst:AddComponent("planardefense")
      inst.components.planardefense:SetBaseDefense(planar)

      -- 阵营友好
      inst:AddComponent("shadowdominance")
      inst:AddTag("shadowdominance")
      inst:AddTag("gestaltprotection")

      -- 防火 + 不可燃烧/冰冻/催眠（仅高级帽）
      if fireproof then
        -- 不自燃
        inst:AddTag("wildfireprotected")
        -- 不可冰冻
        inst:AddTag("htree_nofreeze")
        -- 不可催眠
        inst:AddTag("htree_nosleep")

        -- 装备/卸下 hook：防火 + 混沌实体抵抗
        local _onequip = inst.components.equippable.onequipfn
        inst.components.equippable.onequipfn = function(inst, owner)
          if _onequip then _onequip(inst, owner) end
          -- 火焰伤害免疫（龙鳞甲同款）
          if owner and owner.components.health then
            owner.components.health.externalfiredamagemultipliers:SetModifier(inst, 0)
          end
        end

        local _onunequip = inst.components.equippable.onunequipfn
        inst.components.equippable.onunequipfn = function(inst, owner)
          if _onunequip then _onunequip(inst, owner) end
          if owner and owner.components.health then
            owner.components.health.externalfiredamagemultipliers:RemoveModifier(inst)
          end
        end
      end

      -- ===== 无敌护盾 + 反伤（resistance 全免 + 铥矿皇冠 forcefieldfx + 彩色呼吸灯）=====
      -- 防护：resistance 命中 → inventory:ApplyDamage 直接 return 0,nil → 物理+位面(spdamage)全免
      -- 硬直：combat 走 blocked 分支 → 不推 attacked → SGwilson 不进 hit → 硬直自动免疫
      -- 参数复用：armor(0.36/0.66) 兼作触发概率与护盾时长基数；planar(36/66) 作反伤值
      local shield_chance = armor         -- 36% / 66%
      local shield_duration = armor * 10  -- 3.6s / 6.6s（远长于官方骨甲的 10 帧）
      local reflect_dmg = planar          -- 36 / 66

      -- armorskeleton 同款抵抗标签：_combat 覆盖一切带战斗组件的攻击者（物理+位面），
      -- 其余为环境伤害（爆炸/落石/月雹/洞穴塌陷/陷阱/树木）
      local SHIELD_RESISTANCES = {
        "_combat", "explosive", "quakedebris", "lunarhaildebris",
        "caveindebris", "trapdamage", "rock_tree",
      }

      inst:AddComponent("resistance")
      local shield_active = false
      -- 用私有标志而非 forcefield tag 门禁，避免与官方铥矿皇冠的 forcefield 语义冲突
      inst.components.resistance:SetShouldResistFn(function() return shield_active end)

      local shield_task = nil     -- 护盾持续时间上限
      local shield_fx = nil       -- forcefieldfx 持续特效（open→idle_loop 循环，kill_fx 清理）
      local breath_task = nil     -- 叠加呼吸灯
      local breath_time = 0

      -- 呼吸灯：照手杖跑马灯（HueToRGB 色相循环 + sin 呼吸亮度）叠在 forcefieldfx 上。
      -- forcefieldfx 是 networked 实体，服务端 AnimState 染色会同步到客户端（同手杖呼吸灯）。
      local BREATH_SPEED = 1.2
      local COLOR_CYCLE_SPEED = 1.6
      local BREATH_INTENSITY = 0.6
      local function HueToRGB(hue)
        local r = (math.sin(hue) + 1) / 2
        local g = (math.sin(hue + 2.094) + 1) / 2
        local b = (math.sin(hue + 4.189) + 1) / 2
        return r, g, b
      end

      local function ShieldFxBreath()
        if shield_fx == nil or not shield_fx:IsValid() then return end
        breath_time = breath_time + 0.05
        local phase = (math.sin(breath_time * 2 * math.pi / BREATH_SPEED) + 1) / 2
        local intensity = phase * BREATH_INTENSITY
        local cr, cg, cb = HueToRGB(breath_time * 2 * math.pi / COLOR_CYCLE_SPEED)
        if shield_fx.AnimState ~= nil then
          shield_fx.AnimState:SetAddColour(cr * intensity, cg * intensity, cb * intensity, 0)
        end
      end

      local function SpawnShieldFx(owner)
        if owner == nil or not owner:IsValid() then return end
        local fx = SpawnPrefab("forcefieldfx")
        if fx == nil then return end
        fx.entity:SetParent(owner.entity)
        fx.Transform:SetPosition(0, 0.2, 0)
        shield_fx = fx
        if breath_task ~= nil then breath_task:Cancel() end
        breath_time = 0
        breath_task = fx:DoPeriodicTask(0.05, ShieldFxBreath)
      end

      local function ShieldEnd(inst)
        shield_active = false
        -- ★ 关键：护盾结束必须移除抵抗标签，否则 resistance 永久生效
        for _, tag in ipairs(SHIELD_RESISTANCES) do
          inst.components.resistance:RemoveResistance(tag)
        end
        if breath_task ~= nil then
          breath_task:Cancel()
          breath_task = nil
        end
        if shield_fx ~= nil then
          -- forcefieldfx 官方清理：kill_fx 播 close 动画渐暗 0.6s 后移除，不能直接 Remove
          if shield_fx.kill_fx ~= nil then
            shield_fx:kill_fx()
          else
            shield_fx:Remove()
          end
          shield_fx = nil
        end
        if shield_task ~= nil then
          shield_task:Cancel()
          shield_task = nil
        end
      end

      local function ShieldStart(inst, owner)
        shield_active = true
        -- ★ 关键：护盾开启时加入抵抗标签（之前漏了这步，导致防护完全不生效）
        for _, tag in ipairs(SHIELD_RESISTANCES) do
          inst.components.resistance:AddResistance(tag)
        end
        -- forcefieldfx 常驻：首次才 spawn，续盾只延长时长，避免 kill_fx 的 close 闪烁
        if shield_fx == nil or not shield_fx:IsValid() then
          SpawnShieldFx(owner)
        end
        -- 护盾时间可刷新：每次触发重置到满时长（不叠加），可无限续盾
        if shield_task ~= nil then shield_task:Cancel() end
        shield_task = inst:DoTaskInTime(shield_duration, function()
          ShieldEnd(inst)
        end)
      end

      -- 反伤目标过滤（照搬背包强化 mod）
      local INVALID_REFLECT_TAGS = {
        "bramble_resistant", "INLIMBO", "FX", "invisible", "wall",
        "notarget", "noattack", "flight", "playerghost", "NOCLICK",
      }
      local function CanReflect(attacker, owner)
        if attacker == nil or not attacker:IsValid() or not attacker.entity:IsVisible() then
          return false
        end
        for _, tag in ipairs(INVALID_REFLECT_TAGS) do
          if attacker:HasTag(tag) then return false end
        end
        if attacker.components.combat == nil or attacker.components.health == nil then
          return false
        end
        if attacker.components.health:IsDead() then return false end
        if owner ~= nil and owner.components.combat ~= nil
            and owner.components.combat:IsAlly(attacker) then
          return false
        end
        return true
      end

      local function OnOwnerAttacked(inst, owner, data)
        if owner == nil or data == nil then return end
        -- 反伤伤害不再触发反伤/续盾，避免两个同款帽子玩家互殴无限递归崩服
        -- 注意：resistance 抵挡时推的是 blocked 且无 stimuli，故用共享 reflecting flag
        if reflecting then return end
        -- 护盾激活时受击 → 反伤（forcefieldfx 常驻 + 呼吸灯，无需每次重新 spawn 闪烁）
        if shield_active then
          local attacker = data.attacker
          if CanReflect(attacker, owner) then
            reflecting = true
            attacker.components.combat:GetAttacked(attacker, reflect_dmg, inst, "htree_reflect")
            reflecting = false
            if owner.SoundEmitter ~= nil then
              owner.SoundEmitter:PlaySound("dontstarve/common/together/armor/cactus")
            end
          end
        end
        -- 每次受击 roll 触发/刷新护盾（attacked 与 blocked 都监听，覆盖普通/全免两种伤害）
        if not data.redirected and math.random() < shield_chance then
          ShieldStart(inst, owner)
        end
      end

      local _old_onequip_shield = inst.components.equippable.onequipfn
      inst.components.equippable.onequipfn = function(inst, owner)
        if _old_onequip_shield then _old_onequip_shield(inst, owner) end
        inst._htree_onattacked = function(_owner, data)
          OnOwnerAttacked(inst, _owner, data)
        end
        inst:ListenForEvent("attacked", inst._htree_onattacked, owner)
        inst:ListenForEvent("blocked", inst._htree_onattacked, owner)
      end

      local _old_onunequip_shield = inst.components.equippable.onunequipfn
      inst.components.equippable.onunequipfn = function(inst, owner)
        ShieldEnd(inst)
        if inst._htree_onattacked ~= nil and owner ~= nil then
          inst:RemoveEventCallback("attacked", inst._htree_onattacked, owner)
          inst:RemoveEventCallback("blocked", inst._htree_onattacked, owner)
          inst._htree_onattacked = nil
        end
        if _old_onunequip_shield then _old_onunequip_shield(inst, owner) end
      end

      -- 帽子销毁时清理，防止 task/fx 泄漏
      local _old_onremove = inst.OnRemoveEntity
      inst.OnRemoveEntity = function(inst)
        ShieldEnd(inst)
        if _old_onremove ~= nil then _old_onremove(inst) end
      end
    end)
  end

  SetupHatCombat("plantregistryhat", 0.36, 36, false)
  SetupHatCombat("nutrientsgoggleshat", 0.66, 66, true)
end

---------------------------------------------------------------------------------------------------------
-- 耕作帽：骑乘增益（仿棱镜 hat_cowboy）
--   ▷ 尝试骑乘时忽略坐骑服从度与战斗仇恨
--   ▷ 骑行时免疫击退；任何坐骑（无论是否驯化）都不会被主动甩下来
--   ▷ 不被发情的“皮弗娄牛”主动攻击
--   ▷ 免疫电击
-- 注：棱镜用私有标签 cowboy_l / firmbody_l 实现，此处改用官方机制：
--     insulated（防电）、hardarmor（击退免疫，同 armormarble）、beefalo 标签（免被发情牛攻击）、
--     hook Rider:Mount + rideable:TestObedience（无视服从度）、hook rideable:Buck（戴帽即不甩下，不限驯化）、hook hunger:DoDelta（饥饿下限）
---------------------------------------------------------------------------------------------------------
if config.farming_mount then
  local COWBOY_HATS = { "plantregistryhat", "nutrientsgoggleshat" }

  -- 给两顶帽子打标记 + 防电 + 击退免疫（hardarmor，同大理石甲 armormarble）
  for _, prefab in ipairs(COWBOY_HATS) do
    AddPrefabPostInit(prefab, function(inst)
      if not TheWorld.ismastersim then return end
      inst:AddTag("htree_cowboy")                  -- 戴此帽即视为 cowboy，供下方全局 hook 识别
      inst.components.equippable.insulated = true  -- 防电（官方 insulated 机制，同雨衣）
      inst:AddTag("hardarmor")                     -- 击退免疫（倒树等；同 armormarble）
      inst:AddTag("heavyarmor")                    -- 被击退时落地不飞行 + 多数 Boss 降低击退强度（同 armormarble）
    end)
  end

  -- 装备/卸下：加/去 "beefalo" 标签 → 免被发情皮弗娄牛主动攻击
  for _, prefab in ipairs(COWBOY_HATS) do
    AddPrefabPostInit(prefab, function(inst)
      if not TheWorld.ismastersim then return end
      local _onequip = inst.components.equippable.onequipfn
      inst.components.equippable.onequipfn = function(inst, owner)
        if _onequip then _onequip(inst, owner) end
        if owner ~= nil and owner:IsValid() then
          owner:AddTag("beefalo")   -- 加牛牛标签，发情牛不会主动攻击（官方 RETARGET_CANT_TAGS 含 beefalo）
        end
      end
      local _onunequip = inst.components.equippable.onunequipfn
      inst.components.equippable.onunequipfn = function(inst, owner)
        if _onunequip then _onunequip(inst, owner) end
        if owner ~= nil and owner:IsValid() then
          owner:RemoveTag("beefalo")
        end
      end
    end)
  end

  -- 全局 hook：包裹 Rider:Mount，戴帽时忽略坐骑服从度/仇恨直接骑乘
  AddComponentPostInit("rider", function(self)
    local oldMount = self.Mount
    self.Mount = function(self, target, instant)
      if self.inst ~= nil
          and self.inst.components.inventory ~= nil
          and self.inst.components.inventory:EquipHasTag("htree_cowboy")
          and target ~= nil
          and target.components.rideable ~= nil
          and not target.components.rideable:IsBeingRidden() then
        target._htree_force_mount = true   -- 临时放行 rideable:TestObedience
        oldMount(self, target, instant)
        target._htree_force_mount = false
        return
      end
      oldMount(self, target, instant)
    end
  end)

  -- 全局 hook：TestObedience 读取放行标记（与上面 Mount 配合；官方 rideable.lua:102）
  AddComponentPostInit("rideable", function(self)
    local oldTest = self.TestObedience
    self.TestObedience = function(self, ...)
      if self.inst ~= nil and self.inst._htree_force_mount then
        return true
      end
      return oldTest(self, ...)
    end
  end)

  -- 全局 hook：骑行时不被主动甩下（戴帽即可，无论坐骑是否驯化；官方 rideable.lua:201 仅推送 bucked 事件）
  AddComponentPostInit("rideable", function(self)
    local oldBuck = self.Buck
    self.Buck = function(self, gentle)
      local rider = self.rider
      if rider ~= nil
          and rider:HasTag("htree_cowboy") then
        return  -- 戴帽：任何坐骑都不甩人（随之消除被甩时的击退）
      end
      oldBuck(self, gentle)
    end
  end)

  -- 全局 hook：戴帽时饥饿值（原始值）不低于下限 0.6（濒死但没死，非比例）
  --
  -- ⚠️ 踩坑：旧版 hook DoDelta 之后用 SetCurrent(floor) 抬升，会每帧额外 push 一次
  --   hungerdelta（且没传 overtime）→ statusdisplays.lua:699 判定 not data.overtime 为真，
  --   newpercent > oldpercent → PulseGreen + hunger_up 音效 → 饥饿条反复飘 +1。
  --
  -- 正解（仿 Too Many Items Plus 的 SetMinHealth / 官方 Health:SetVal）：把 clamp 放在
  --   数据入口 SetCurrent 内部，只产生一次 hungerdelta；稳定态 delta=0，既不飘绿也不响音效。
  --   · 自然衰减 DoDec → DoDelta → SetCurrent（overtime=true）→ 在此被夹到 0.6
  --   · current 恒 >0 → DoDec 永不进饿伤分支（hunger.lua:156）→ 不会饿死
  --   · 脱帽后 EquipHasTag 为 false → 不 clamp → 恢复原版自然衰减至饿伤
  local HUNGER_MIN_VALUE = 0.6   -- 原始饥饿值下限（濒死但没死）
  AddComponentPostInit("hunger", function(self)
    local oldSetCurrent = self.SetCurrent
    self.SetCurrent = function(self, current, overtime, ...)
      if current < HUNGER_MIN_VALUE
          and self.inst ~= nil
          and self.inst.components.inventory ~= nil
          and self.inst.components.inventory:EquipHasTag("htree_cowboy") then
        current = HUNGER_MIN_VALUE
      end
      -- 必须透传 overtime：自然衰减是 true，HUD 才不会当成"瞬间回饥饿"播特效
      return oldSetCurrent(self, current, overtime, ...)
    end
  end)

end
