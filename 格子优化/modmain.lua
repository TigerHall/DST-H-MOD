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
  -- 眼骨/星空配置
  item_trade_function = GetModConfigData("item_trade_function"),
}

-- 实体/特效引用
PrefabFiles = {
  "hslot_container",
}

-- 物品交换映射表（简化：直接定义核心映射关系）
local TRADE_MAPPING = {
  ["opalpreciousgem"] = "alterguardianhatshard",
  ["dreadstone"] = "opalpreciousgem",
  ["boneshard"] = "houndstooth",
  ["walrus_tusk"] = "klaussackkey",
}

-- 简化版交易成功回调：核心逻辑保留，精简冗余判断和注释
local function OnGivenItem(inst, giver, item, count)
  -- 基础空值保护
  if not giver or not giver.components.inventory then return end

  -- 获取兑换目标物品
  local output_prefab = TRADE_MAPPING[item.prefab]
  if not output_prefab then return end

  -- 计算交易数量（简化写法）
  local trade_count = count or (item.components.stackable and item.components.stackable.stacksize or 1)

  -- 生成并发放兑换物品
  for i = 1, trade_count do
    local reward = SpawnPrefab(output_prefab)
    if reward then
      giver.components.inventory:GiveItem(reward, nil, giver:GetPosition())
    end
  end

  -- 简化的交易提示（保留核心提示逻辑）
  if giver.components.talker then
    local reward = SpawnPrefab(output_prefab)
    giver.components.talker:Say(string.format("󰀧 %d %s 󰀩 %d %s！󰀒",
      trade_count, item:GetDisplayName(),
      trade_count, reward:GetDisplayName()))
    reward:Remove()
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

-- 眼骨
AddPrefabPostInit("chester_eyebone", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end
  if config.item_trade_function then
    AddTradeComponent(inst)
    inst:AddTag("NOBLOCK")
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
  end
end)

-- 带孔月岩传送
AddPrefabPostInit("moonrockcrater", function(inst)
  -- 仅在服务端执行
  if not TheWorld.ismastersim then return inst end

  -- 开启传送功能
  if config.moonrockcrater_teleport then
    -- . 定义传送核心函数
    local function DoTeleport(viewer)
      -- 验证玩家有效性
      if not viewer or not viewer:IsValid() or not viewer:HasTag("player") then
        return
      end
      -- 搜索目标：眼骨/星空
      local target = nil
      local targetPrefabs = { "chester_eyebone", "hutch_fishbowl" }
      for _, prefab in ipairs(targetPrefabs) do
        local entities = TheSim:FindEntities(0, 0, 0, 9999, { prefab })
        if #entities > 0 and entities[1]:IsValid() then
          target = entities[1]
          break
        end
      end

      -- 初始化激活状态标识（若未初始化）
      if inst._is_teleport_activated == nil then
        inst._is_teleport_activated = false
      end

      -- 延迟执行传送（添加任务标识，避免重复触发）
      local function ClearAllTasks()
        if inst._teleport_task ~= nil then
          inst._teleport_task:Cancel()
        end
        if inst._talk_task ~= nil then
          inst._talk_task:Cancel()
        end
        -- 重置激活状态
        inst._is_teleport_activated = false
      end
      if inst._is_teleport_activated then
        -- 当前处于激活状态，直接清理所有任务并返回
        ClearAllTasks()
        return
      else
        -- 当前未激活，先清理残留任务（保险），再标记为激活状态
        ClearAllTasks()
        inst._is_teleport_activated = true
      end
      -- 执行传送逻辑
      if target then
        -- 先让玩家说话
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

        -- 延时传送玩家到目标位置
        inst._teleport_task = inst:DoTaskInTime(3.6, function()
          -- 再次验证玩家和目标的有效性（防止延迟期间对象被销毁）
          if viewer and viewer:IsValid() and target and target:IsValid() then
            local x, y, z = target.Transform:GetWorldPosition()
            if viewer.components.talker then
              viewer.components.talker:Say("󰀃")
            end
            if viewer.Physics then
              viewer.Physics:Teleport(x, y, z)
            else
              viewer.Transform:SetPosition(x, y, z)
            end
          end
          -- 传送完成后清理任务并重置状态
          ClearAllTasks()
        end)
      else
        inst._talk_task = inst:DoTaskInTime(0.6, function()
          if viewer.components.talker then
            viewer.components.talker:Say("󰀯")
          end
          -- 提示后清理任务并重置状态
          ClearAllTasks()
        end)
      end
    end

    -- 3. 劫持检查组件的GetDescription方法（核心）
    local old_GetDescription = inst.components.inspectable.GetDescription
    inst.components.inspectable.GetDescription = function(self, viewer)
      -- 执行传送逻辑（仅当玩家点击/右键检查时触发，悬停不触发）
      if viewer and viewer:HasTag("player") and viewer:IsValid() then
        DoTeleport(viewer)
      end
      -- 执行原版的检查描述逻辑
      return old_GetDescription(self, viewer)
    end
  end
end)

-- 共享空间设置
-- 兔洞格子相关修改
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
end)

-- 修改暗影格子属性
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

  -- 结束
end)

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

-- 黄色月眼：打开自制格子（未完成）
AddPrefabPostInit("yellowmooneye", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end
end)
