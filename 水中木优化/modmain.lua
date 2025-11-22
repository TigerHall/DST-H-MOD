-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })

-- 获取配置项（仅保留发光范围配置）
local config = {
  light_radius = GetModConfigData("OceanTreeLightRadius"),
  shrink_scale = GetModConfigData("OceanTreeShrinkScale"),
  ovshrink_scale = GetModConfigData("OceanVineShrinkScale"),
  fig_harvest_count = GetModConfigData("fig_harvest_count"),
  show_leafcanopy = GetModConfigData("show_leafcanopy"),
  glommerfuel_edible = GetModConfigData("glommerfuel_edible"),
  glommerfuel_period = GetModConfigData("glommerfuel_period"),
  glommer_sanityaura = GetModConfigData("glommer_sanityaura"),
  sgj_fl = GetModConfigData("sgj_fl"),
  glmny_fl = GetModConfigData("glmny_fl"),
}

-- 设置全局调优参数
-- TUNING.OceanTreeLightRadius = GetModConfigData("OceanTreeLightRadius")

-- 实体/特效引用
-- PrefabFiles = {
--   "OceanTree_light",
-- }


-- 修改水中木
AddPrefabPostInit("oceantree_pillar", function(inst)
  -- 只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end

  -- 范围为0时不添加发光效果
  if config.light_radius > 0 then
    -- 添加发光组件
    inst.entity:AddLight()

    -- 初始化发光属性（默认关闭，等待时间判定）
    inst.Light:Enable(false)
    inst.Light:SetRadius(config.light_radius) -- 使用配置的发光范围
    inst.Light:SetFalloff(0.6)                --衰减程度
    inst.Light:SetIntensity(0.5)              --发光强度
    inst.Light:SetColour(153 / 255, 204 / 255, 153 / 255)
    inst.Light:EnableClientModulation(false)

    -- 添加光源标签
    inst:AddTag("lightsource")

    -- 时间监听函数：整合判断逻辑
    local function UpdateLightState(inst, phase)
      -- 非白天时开启发光（范围已在外部判定>0）
      if phase ~= "day" then
        inst.Light:Enable(true)
      else
        inst.Light:Enable(false)
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
    inst:AddComponent("periodicspawner")
    inst.components.periodicspawner.basetime = config.glommerfuel_period * 60
    inst.components.periodicspawner.randtime = 1
  end
  -- 修改格罗姆的回san效果 无效的修改
  -- if config.glommer_sanityaura > 0 and inst.sanityaura then
  --   inst:AddComponent("sanityaura")
  --   inst.components.sanityaura.aura = 6666
  -- end

  --修改结束
end)

-- 修改格罗姆粘液
AddPrefabPostInit("glommerfuel", function(inst)
  -- 只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end
  -- 修改格罗姆粘液的食用效果
  if config.glommerfuel_edible and inst.components.edible then
    inst.components.edible.healthvalue = 166
    inst.components.edible.hungervalue = 166
    inst.components.edible.sanityvalue = -166
  end
  -- 修改树果酱的肥料效果
  if config.glmny_fl and inst.components.fertilizer then
    inst:AddComponent("fertilizer")
    inst.components.fertilizer:SetNutrients(66, 66, 66)
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
    inst:AddComponent("fertilizer")
    inst.components.fertilizer:SetNutrients(166, 166, 166)
  end
  --修改结束
end)
