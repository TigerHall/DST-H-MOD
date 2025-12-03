-- 环境设置
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })

-- 背包参数表（与modinfo对应，集中管理）
local backpack_params = {
  { prefab = "backpack" },
  { prefab = "piggyback" },
  { prefab = "icepack" },
  { prefab = "krampus_sack" },
  { prefab = "seedpouch" },
  { prefab = "candybag" },
  { prefab = "spicepack" }
}

-- 批量获取配置项
local config = {}
for _, param in ipairs(backpack_params) do
  local prefab = param.prefab
  config[prefab] = {
    -- 防御和反击
    defense = GetModConfigData(prefab .. "_defense"),
    planardefense = GetModConfigData(prefab .. "_planardefense"),
    counter_dmg = GetModConfigData(prefab .. "_counter_dmg"),
    -- 保温防雨和回san
    insulate = GetModConfigData(prefab .. "_insulate"),
    waterproof = GetModConfigData(prefab .. "_waterproof"),
    sanity = GetModConfigData(prefab .. "_sanity"),
    -- 自动采集和无限堆叠，保鲜
    infinite_stack = GetModConfigData(prefab .. "_infinite_stack"),
    collect = GetModConfigData(prefab .. "_collect"),
    preserve = GetModConfigData(prefab .. "_preserve"),
    -- 其他选项
    fireproof = GetModConfigData(prefab .. "_fireproof"),
    shadow_immunity = GetModConfigData(prefab .. "_shadow_immunity"),
    moon_immunity = GetModConfigData(prefab .. "_moon_immunity"),
  }
end

-- 目标有效性过滤函数
local function IsValidCounterTarget(attacker, owner)
  if not attacker or not attacker:IsValid() or not attacker.entity:IsVisible() then
    return false
  end
  -- 排除特定标签
  local invalid_tags = { "bramble_resistant", "INLIMBO", "FX", "invisible", "wall", "notarget", "noattack", "flight",
    "playerghost", "NOCLICK", }
  for _, tag in ipairs(invalid_tags) do
    if attacker:HasTag(tag) then
      return false
    end
  end
  -- 排除无战斗组件的目标
  if not attacker.components.combat then
    return false
  end
  -- 排除友方单位
  if owner and owner.components.combat and owner.components.combat:IsAlly(attacker) then
    return false
  end
  return true
end
-- 直接执行反击（添加目标限制）
local function DoCounterAttack(inst, owner, attacker)
  -- 目标过滤
  if not IsValidCounterTarget(attacker, owner) then
    return
  end
  -- 新增：检查攻击者是否有health组件
  if not attacker.components or not attacker.components.health then
    return
  end

  -- 检查目标存活状态（此时已确保health组件存在）
  if attacker.components.health:IsDead() then
    return
  end

  -- 获取配置的反击伤害
  local dmg = config[inst.prefab].counter_dmg or 0
  if dmg <= 0 then return end
  -- 造成反击伤害
  attacker.components.health:DoDelta(-dmg, false, inst.prefab)
  -- 播放音效
  if owner.SoundEmitter then
    owner.SoundEmitter:PlaySound("dontstarve/common/together/armor/cactus")
  end
end
-- 通用反击触发函数
local function OnAttackTrigger(inst, owner, data)
  -- 提取攻击者
  local attacker = data.attacker or
      (data.target and data.target.components.combat and data.target.components.combat.target)
  if not attacker then return end
  -- 触发反击
  DoCounterAttack(inst, owner, attacker)
end



-- 通用背包强化函数（处理所有背包的共性逻辑）
local function enhance_backpack(inst, prefab)
  -- 获取当前背包的配置
  local cfg = config[prefab]
  inst.prefab = prefab

  -- 装备时注册事件
  local old_onequip = inst.components.equippable.onequipfn
  inst.components.equippable:SetOnEquip(function(inst, owner)
    if old_onequip then old_onequip(inst, owner) end
    -- 反击事件注册
    inst._onattacked = function(_owner, data) OnAttackTrigger(inst, _owner, data) end
    inst:ListenForEvent("attacked", inst._onattacked, owner)
    inst:ListenForEvent("blocked", inst._onattacked, owner)
    -- 防火：装备时添加火焰免疫（龙鳞甲同款逻辑）
    if cfg.fireproof and owner and owner.components.health ~= nil then
      owner.components.health.externalfiredamagemultipliers:SetModifier(inst, 0)
    end
    -- 暗影阵营不攻击
    if cfg.shadow_immunity then
      inst:AddComponent("shadowdominance")
      inst:AddTag("shadowdominance")
    end

    -- 月亮阵营不攻击
    if cfg.moon_immunity then
      inst:AddTag("gestaltprotection")
    end
  end)

  -- 卸下时清理
  local old_onunequip = inst.components.equippable.onunequipfn
  inst.components.equippable:SetOnUnequip(function(inst, owner)
    if old_onunequip then old_onunequip(inst, owner) end
    -- 反击事件清理
    if inst._onattacked then
      inst:RemoveEventCallback("attacked", inst._onattacked, owner)
      inst:RemoveEventCallback("blocked", inst._onattacked, owner)
      inst._onattacked = nil
    end
    -- 防火：卸装时移除火焰免疫
    if cfg.fireproof and owner and owner.components.health ~= nil then
      owner.components.health.externalfiredamagemultipliers:RemoveModifier(inst)
    end
    -- 去除暗影阵营不攻击
    if cfg.shadow_immunity and owner.components.shadowdominance ~= nil then
      inst:RemoveComponent("shadowdominance")
      inst:RemoveTag("shadowdominance")
    end

    -- 去除月亮阵营不攻击
    if cfg.moon_immunity then
      inst:RemoveTag("gestaltprotection")
    end
  end)


  -- 1. 普通防御设置
  if cfg.defense > 0 then
    inst:AddComponent("armor")
    inst:AddTag("hide_percentage")
    inst.components.armor:InitIndestructible(cfg.defense)
  end

  -- 2. 位面防御设置
  if cfg.planardefense > 0 then
    inst:AddComponent("planardefense")
    inst.components.planardefense:SetBaseDefense(cfg.planardefense)
  end

  -- 3. 保温功能
  if cfg.insulate > 0 then
    if not inst.components.insulator then
      inst:AddComponent("insulator")
    end
    inst.components.insulator:SetInsulation(cfg.insulate)
    -- 默认为保温效果，下面的注释去掉则为隔热效果
    -- inst.components.insulator:SetSummer()
  end

  -- 4.防雨功能（简化为完全防雨/关闭）
  if cfg.waterproof then
    if not inst.components.waterproofer then
      inst:AddComponent("waterproofer")
    end
    inst.components.waterproofer:SetEffectiveness(1)
  end

  -- 5. 回san功能（精神恢复）
  if cfg.sanity > 0 then
    -- 确保背包有equippable组件（装备时生效）
    if not inst.components.equippable then
      inst:AddComponent("equippable")
    end
    -- 按需求调整除数
    inst.components.equippable.dapperness = cfg.sanity / 54
  end

  -- 6. 保鲜功能实现
  if cfg.preserve then
    -- 添加preserver组件并设置保鲜倍率为0（食物永不腐烂）
    if not inst.components.preserver then
      inst:AddComponent("preserver")
    end
    inst.components.preserver:SetPerishRateMultiplier(0)
  end

  -- 7. 防火
  if cfg.fireproof then
    inst:AddTag("gestaltprotection")
  end

  -- 无限堆叠功能
  if cfg.infinite_stack then
    inst.components.container:EnableInfiniteStackSize(true)
  end

  -- 自动采集功能
  if cfg.collect then
    -- 修改自 心悦卿兮的宠物拾取代码
    local function spawn_fx(name, scale, pos)
      -- 仅客户端生成特效（服务器不执行）
      if not TheWorld.ismastersim then
        local fx = SpawnPrefab(name)
        fx.Transform:SetScale(scale, scale, scale)
        fx.Transform:SetPosition(pos.x, 0, pos.z) -- 修正Y轴为地面高度（0）
      end
    end

    local function collect_items_periodially(inst)
      if inst.components.container == nil then
        print("hpack: container component missing!")
        return
      end
      local container = inst.components.container
      if container:IsEmpty() then
        return
      end

      -- 遍历容器，找到可堆叠且未满的物品（服务器逻辑）
      local targets = {}
      for i = 1, container.numslots do
        local item = container.slots[i]
        if item ~= nil and item:IsValid() and item.components.stackable ~= nil and not item.components.stackable:IsFull() then
          targets[item.prefab] = (targets[item.prefab] or 0) + item.components.stackable:RoomLeft()
        end
      end

      if #table.getkeys(targets) == 0 then
        return
      end

      local owner = inst.components.inventoryitem.owner
      if owner == nil then
        return
      end

      local x, y, z = owner.Transform:GetWorldPosition()
      if x == nil or z == nil then
        return
      end

      local stop = false
      local must_tags = { "_inventoryitem", "_stackable" }
      local cant_tags = {
        -- Items
        "INLIMBO", "NOCLICK", "irreplaceable", "knockbackdelayinteraction", "event_trigger",
        "minesprung", "mineactive", "catchable",
        "fire", "light", "spider", "cursed", "paired", "bundle",
        "heatrock", "deploykititem", "boatbuilder", "singingshell",
        "archive_lockbox", "simplebook", "furnituredecor",
        -- Pickables
        "flower", "gemsocket", "structure",
        -- Either
        "donotautopick",
        -- chang
        "trap",
        -- others
        "FX", }                                                            -- 保持原过滤标签

      local ents = TheSim:FindEntities(x, 0, z, 6.6, must_tags, cant_tags) -- 修正Y轴为0（地面）
      for _, ent in ipairs(ents) do
        if not stop and targets[ent.prefab] ~= nil and ent.components.stackable then
          -- 拆分物品（服务器逻辑）
          local take = math.min(ent.components.stackable:StackSize(), targets[ent.prefab])
          local taken_item = ent.components.stackable:Get(take)

          -- 服务器执行物品转移（自动同步到客户端）
          container:GiveItem(taken_item)
          targets[ent.prefab] = targets[ent.prefab] - take

          if targets[ent.prefab] <= 0 then
            targets[ent.prefab] = nil
          end

          -- 触发特效（客户端执行，服务器不处理）
          spawn_fx("sand_puff", 0.6, inst:GetPosition())

          stop = true -- 保持一次拾取一个的逻辑
        end
      end
    end
    -- 自动拾取容器内有的物品

    inst:DoPeriodicTask(0.36, collect_items_periodially)
  end


  return inst
end

-- 批量应用强化逻辑到所有背包
for _, param in ipairs(backpack_params) do
  AddPrefabPostInit(param.prefab, function(inst)
    if not TheWorld.ismastersim then
      return inst
    end
    enhance_backpack(inst, param.prefab)
  end)
end

-- 其他选项
local configh = {
  krampus_sack_craft = GetModConfigData("krampus_sack_craft")
}

-- 坎普斯背包可制作
if configh.krampus_sack_craft then
  AddRecipe2("krampus_sack",
    { Ingredient("klaussackkey", 1), Ingredient("silk", 1) },
    TECH.NONE, nil,
    { "CONTAINERS", })
end
