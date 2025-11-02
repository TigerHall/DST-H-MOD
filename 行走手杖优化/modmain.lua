-- 获取配置项（统一管理配置变量）
local config = {
  speed_buff = GetModConfigData("speed_buff_value"),
  damage = GetModConfigData("damage_value"),
  range_attack = GetModConfigData("range_attack_enable"),
  anti_lose = GetModConfigData("anti_lose_enable"),
  haunt_resurrect = GetModConfigData("haunt_resurrect_enable"),
}

-- 修改步行手杖属性
AddPrefabPostInit("cane", function(inst)
  -- 只在主机端执行修改
  if not GLOBAL.TheWorld.ismastersim then
    return inst
  end

  -- 处理武器组件逻辑
  if inst.components.weapon then
    inst.components.weapon:SetDamage(config.damage)
    if config.range_attack then
      inst.components.weapon:SetRange(15, 16)
    end
  end

  -- 处理装备组件逻辑（移速加成）
  if inst.components.equippable then
    inst.components.equippable.walkspeedmult = 1 + config.speed_buff
  end

  -- 处理防丢失逻辑（根据开关决定是否启用）
  if config.anti_lose and inst.components.inventoryitem then
    -- 防止被偷窃
    inst:AddTag("nosteal")
    -- 防止BOSS攻击/潮湿导致脱手
    inst.components.inventoryitem:SetOnDroppedFn(nil)
  end

  -- 处理作祟复活逻辑（根据开关决定是否启用）
  if config.haunt_resurrect then
    -- 添加可被作祟组件（如果不存在）
    if not inst.components.hauntable then
      inst:AddComponent("hauntable")
      inst.components.hauntable:SetHauntValue(GLOBAL.TUNING.HAUNT_TINY)
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
        local fx = GLOBAL.SpawnPrefab("statue_transition_2")
        if fx then
          fx.Transform:SetPosition(x, y, z)
          fx.Transform:SetScale(0.8, 0.8, 0.8)
        end
        return true -- 表示作祟成功
      end
      return false  -- 非玩家鬼魂作祟不处理
    end)
  end


  -- 结束
end)
