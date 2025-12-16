-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })


-- 获取配置项（统一管理配置变量）
local config = {
  -- 切斯特设置
  chester_preserver = GetModConfigData("chester_preserver"),
  shadow_chester_preserver = GetModConfigData("shadow_chester_preserver"),
  chester_infinite_stack = GetModConfigData("chester_infinite_stack"),
  -- 哈奇设置
  hutch_preserver = GetModConfigData("hutch_preserver"),
  hutch_infinite_stack = GetModConfigData("hutch_infinite_stack"),
  -- 带孔月岩传送功能
  moonrockcrater_teleport = GetModConfigData("moonrockcrater_teleport"),
}

-- 实体/特效引用
PrefabFiles = {
  -- "hehu_light",
}

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
  if config.chester_infinite_stack and inst.components.container then
    inst.components.container:EnableInfiniteStackSize(true)
  end

  -- ********** 腐烂速率：按状态区分 **********
  -- 先移除原有preserver组件（避免叠加）
  if inst.components.preserver then
    inst:RemoveComponent("preserver")
  end

  if current_state == ChesterState.NORMAL then
    -- 普通切斯特：腐烂加快
    if config.chester_preserver then
      inst:AddComponent("preserver")
      inst.components.preserver:SetPerishRateMultiplier(16)
    end
  elseif current_state == ChesterState.SNOW then
    -- 冰雪切斯特：恢复原生冰箱效果 + 可选反鲜
    inst:AddTag("fridge")
    if config.chester_preserver then
      inst:AddComponent("preserver")
      inst.components.preserver:SetPerishRateMultiplier(-16)
    end
  elseif current_state == ChesterState.SHADOW then
    -- 暗影切斯特：这里不处理，单独在shadow_container中处理
    inst:RemoveTag("fridge")
  end
end

-- 4. 修改切斯特主预制体
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
end)

-- 修改暗影切斯特格子属性
AddPrefabPostInit("shadow_container", function(inst)
  -- 只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end
  -- 腐烂加快
  if config.shadow_chester_preserver then
    if inst.components.preserver == nil then
      inst:AddComponent("preserver")
    end
    inst.components.preserver:SetPerishRateMultiplier(36)
  end
  -- 可以无限堆叠
  if config.chester_infinite_stack and inst.components.container then
    inst.components.container:EnableInfiniteStackSize(true)
  end
  -- 结束
end)

-- 新增哈奇相关修改
AddPrefabPostInit("hutch", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end

  -- 处理无限堆叠
  if config.hutch_infinite_stack and inst.components.container then
    inst.components.container:EnableInfiniteStackSize(true)
  end

  -- 如果开启防腐功能，添加preserver组件并设置速率为0（不腐败）
  if config.hutch_preserver then
    inst:AddComponent("preserver")
    inst.components.preserver:SetPerishRateMultiplier(0)
  end
end)

-- 带孔月岩
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
          end
        end)
        inst._talk_task = inst:DoTaskInTime(1.6, function()
          if viewer.components.talker then
            viewer.components.talker:Say("󰀏󰀏󰀃")
          end
        end)
        inst._talk_task = inst:DoTaskInTime(2.6, function()
          if viewer.components.talker then
            viewer.components.talker:Say("󰀏󰀃")
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
