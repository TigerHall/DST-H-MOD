-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })


-- 获取配置项（统一管理配置变量）
local config = {
  -- 基础配置项
  endtable_immune = GetModConfigData("endtable_immune") or false,
  endtable_flower_wilt = GetModConfigData("endtable_flower_wilt") or true,
  birdcage_immortal = GetModConfigData("birdcage_immortal") or true,
  saltlick_unlimited = GetModConfigData("saltlick_unlimited") or true,
  ticoon_enhance = GetModConfigData("ticoon_enhance") or true,
  fence_electric_enhance = GetModConfigData("fence_electric_enhance") or true,
}

-- 实体/特效引用
PrefabFiles = {
  -- "hehu_light",
}


-- 修改茶几属性
AddPrefabPostInit("endtable", function(inst)
  -- 只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end
  -- 茶几防BOSS摧毁+卡位功能
  if config.endtable_immune then
    if inst:HasTag("NPC_workable") then
      inst:RemoveTag("NPC_workable")
    end
    if inst.components.workable then
      inst:RemoveComponent("workable")
    end
    -- 2. 燃烧后直接删除（核心简化逻辑）
    if not inst.components.burnable then
      MakeSmallBurnable(inst)   -- 确保有燃烧组件
      MakeSmallPropagator(inst) -- 可被火焰引燃
    end
    -- 重写燃烧完成逻辑：直接删实体，无任何残留
    inst.components.burnable:SetOnBurntFn(function(inst)
      inst:Remove() -- 核心：燃烧后直接删除
    end)
  end

  if config.endtable_flower_wilt then
    -- 极大延长花枯萎时间
    TUNING.ENDTABLE_FLOWER_WILTTIME = 666666
  end
  -- 结束
end)

-- 修改鸟笼属性
if config.birdcage_immortal then
  TUNING.PERISH_CAGE_MULT = 0
end

-- 核心函数：重写Use方法：执行原逻辑，但不消耗耐久
local function MakeSaltLickUnlimited(inst)
  if not TheWorld.ismastersim then
    return inst
  end
  -- 检查是否有finiteuses组件
  if inst.components.finiteuses then
    local old_Use = inst.components.finiteuses.Use
    function inst.components.finiteuses:Use(uses)
      old_Use(self, 0)
    end
  end
  return inst
end

-- 应用到舔盐块
AddPrefabPostInit("saltlick_improved", function(inst)
  if config.saltlick_unlimited then
    MakeSaltLickUnlimited(inst)
  end
end)

-- 应用到大虎
AddPrefabPostInit("ticoon", function(inst)
  if config.ticoon_enhance then
    TUNING.TICOON_SPEED = 6.6
    TUNING.TICOON_EMBARK_SPEED = 8.6

    inst:AddTag("NOBLOCK")
    if inst.components.health then
      inst.components.health:SetMaxHealth(666)
      inst.components.health:StartRegen(66, 6)
      inst.components.health:SetAbsorptionAmount(0.66)
      -- inst.components.health:SetInvincible(true)
    end
    if inst.components.combat then
      inst.components.combat:SetDefaultDamage(66)
      inst.components.combat:SetRange(6)
      inst.components.combat:SetAttackPeriod(0.6)
    end
  end
end)

-- 麻刺节点修改
AddPrefabPostInit("fence_electric", function(inst)
  if config.fence_electric_enhance then
    inst:AddTag("NOBLOCK")
  end
end)
