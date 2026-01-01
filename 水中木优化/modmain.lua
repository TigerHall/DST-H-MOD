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
