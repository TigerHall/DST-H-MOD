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
    defense = GetModConfigData(prefab .. "_defense"),
    planardefense = GetModConfigData(prefab .. "_planardefense"),
    collect = GetModConfigData(prefab .. "_collect")
  }
end

-- 通用背包强化函数（处理所有背包的共性逻辑）
local function enhance_backpack(inst, prefab)
  -- 获取当前背包的配置
  local cfg = config[prefab]

  -- 1. 普通防御设置
  if cfg.defense > 0 then
    inst:AddComponent("armor")
    inst.components.armor:InitCondition(666666, cfg.defense)
    -- 受伤不消耗耐久（直接重置为满耐久）
    inst.components.armor.ontakedamage = function()
      inst.components.armor:SetCondition(666666)
    end
  end

  -- 2. 位面防御设置（预留扩展）
  if cfg.planardefense > 0 then
    inst:AddComponent("planardefense")
    inst.components.planardefense:SetBaseDefense(cfg.planardefense)
  end



  -- 3. 自动采集功能
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

-- ARMOR STORAGE WEAPONS TOOLS
