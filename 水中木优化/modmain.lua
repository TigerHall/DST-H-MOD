-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })

-- 获取配置项（仅保留发光范围配置）
local config = {
  light_radius = GetModConfigData("OceanTreeLightRadius"),
  shrink_scale = GetModConfigData("OceanTreeShrinkScale"),
  ocean_tree_cooldown = GetModConfigData("ocean_tree_cooldown"),
  ovshrink_scale = GetModConfigData("OceanVineShrinkScale"),
  ocean_tree_no_block = GetModConfigData("ocean_tree_no_block"),
  fig_harvest_count = GetModConfigData("fig_harvest_count"),
  show_leafcanopy = GetModConfigData("show_leafcanopy"),
  glommerfuel_edible = GetModConfigData("glommerfuel_edible"),
  glommerfuel_period = GetModConfigData("glommerfuel_period"),
  glommerfuel_remove_transplant = GetModConfigData("glommerfuel_remove_transplant"),
  glommer_sanityaura = GetModConfigData("glommer_sanityaura"),
  sgj_fl = GetModConfigData("sgj_fl"),
  glmny_fl = GetModConfigData("glmny_fl"),
  OceanTreeShadeRange = GetModConfigData("OceanTreeShadeRange"),
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
  TUNING.SHADE_CANOPY_RANGE_SMALL = config.OceanTreeShadeRange or 22
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
  -- 自然衰减经 DoDec → DoDelta，本 hook 在其后抬升到下限，故不会饿死；脱帽后恢复自然衰减
  -- 官方 hunger.lua:128 DoDelta、:146 DoDec（current<=0 才触发饿伤，见 :160）
  local HUNGER_MIN_VALUE = 0.6   -- 原始饥饿值下限（濒死但没死）
  AddComponentPostInit("hunger", function(self)
    local oldDoDelta = self.DoDelta
    self.DoDelta = function(self, delta, overtime, ignore_invincible)
      oldDoDelta(self, delta, overtime, ignore_invincible)
      if self.inst ~= nil
          and self.inst.components.inventory ~= nil
          and self.inst.components.inventory:EquipHasTag("htree_cowboy") then
        local floor = HUNGER_MIN_VALUE
        if self.current < floor then
          self:SetCurrent(floor)   -- 仅抬升到下限，不触发额外衰减或致死分支
        end
      end
    end
  end)

  ---------------------------------------------------------------------------------------------------------
  -- 客户端：去掉本 MOD 农作帽的四角黑边（有两种来源，分别 hook 两个 widget）
  --
  -- 来源① NutrientOverlay（营养目镜护目镜边框，仅 nutrientsgoggleshat）
  --   根因：nutrientsgoggleshat 官方自带 "nutrientsvision" tag（hats.lua:3123）→ playervision 据此
  --         PushEvent("nutrientsvision")（playervision.lua:59）→ widgets/nutrientsover.lua:20 监听后
  --         显示 images/fx4.xml 的 nutrients_over.tex 全屏边框。
  --
  -- 来源② GogglesOver（防风沙护目镜边框，两顶帽子都中招，这才是真正的"四角黑边"）
  --   根因：本 MOD 夜视 SetHatNightVision 里调了 playervision:ForceGoggleVision(true)（modmain.lua:266），
  --         它是从勋章 ommateum_certificate 照搬的（medal_hook.lua:756 同样 ForceGoggleVision(true)）。
  --         ForceGoggleVision(true) 会 PushEvent("gogglevision",{enabled=true})（playervision.lua:289）
  --         → widgets/gogglesover.lua:22 监听 → ToggleGoggles(true) → 显示 images/fx3.xml 的
  --           goggle_over.tex 四角黑边。这就是玩家实际看到的黑边。
  --   注意：ForceGoggleVision(true) 同时是"防风沙"的来源（HasGoggleVision() 返回 true → 免疫沙暴致盲），
  --         所以【绝不能删这行】，只能隐藏边框视觉，功能照常保留。
  --
  -- 做法：Hook 两个 widget 的显示方法，装备本 MOD 农作帽（直接比对 prefab 名）时 show 直接 return 跳过。
  --       直接比对头部装备 prefab 名（prefab 名客户端永远已知，最稳）；不依赖 EquipHasTag 对自定义 tag
  --       的客户端同步——replica.inventory:EquipHasTag 在客户端走 classified:GetEquips() 分支，自定义 tag
  --       经此同步到客户端副本时不可靠，会导致 hook 失效。
  ---------------------------------------------------------------------------------------------------------
  if not GLOBAL.TheNet:IsDedicated() then
    -- Hook 营养目镜边框 widget：装备本 MOD 农作帽时跳过黑边显示
    -- 直接比对装备的头部 prefab 名（prefab 名客户端永远已知，最稳）；
    -- 不依赖 EquipHasTag 对自定义 tag 的客户端同步——replica.inventory:EquipHasTag 在客户端走
    -- classified:GetEquips() 分支，自定义 tag 经此同步到客户端副本时不可靠，会导致 hook 失效
    local COWBOY_PREFABS = {}
    for _, v in ipairs(COWBOY_HATS) do
      COWBOY_PREFABS[v] = true
    end
    AddClassPostConstruct("widgets/nutrientsover", function(self)
      local _ToggleNutrients = self.ToggleNutrients
      self.ToggleNutrients = function(self, show)
        if show and self.owner ~= nil then
          local inv = self.owner.replica.inventory or self.owner.components.inventory
          local head = inv ~= nil and inv:GetEquippedItem(GLOBAL.EQUIPSLOTS.HEAD) or nil
          if head ~= nil and COWBOY_PREFABS[head.prefab] then
            return  -- 本 MOD 农作帽：不显示四角黑边（其他来源的营养视觉不受影响）
          end
        end
        return _ToggleNutrients(self, show)
      end
    end)

    -- Hook 防风沙护目镜边框 widget：装备本 MOD 农作帽时跳过四角黑边
    -- 来源：ForceGoggleVision(true)（modmain.lua:266，照搬 ommateum_certificate medal_hook.lua:756）
    --       → gogglevision 事件 → GogglesOver:ToggleGoggles(true) 显示 goggle_over.tex
    -- 仅隐藏视觉，不动 HasGoggleVision() → 防风沙能力照常保留
    AddClassPostConstruct("widgets/gogglesover", function(self)
      local _ToggleGoggles = self.ToggleGoggles
      self.ToggleGoggles = function(self, show)
        if show and self.owner ~= nil then
          local inv = self.owner.replica.inventory or self.owner.components.inventory
          local head = inv ~= nil and inv:GetEquippedItem(GLOBAL.EQUIPSLOTS.HEAD) or nil
          if head ~= nil and COWBOY_PREFABS[head.prefab] then
            return  -- 本 MOD 农作帽：跳过防风沙护目镜四角黑边
          end
        end
        return _ToggleGoggles(self, show)
      end
    end)
  end
end
