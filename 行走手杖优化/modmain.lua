-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })


-- 获取配置项（统一管理配置变量）
local config                     = {
  -- 基础配置项
  speed_buff = GetModConfigData("speed_buff_value"),
  haunt_resurrect = GetModConfigData("haunt_resurrect_enable"),
  hcane_light = GetModConfigData("hcane_light"),
  -- 伤害配置项
  damage = GetModConfigData("damage_value"),
  planardamage = GetModConfigData("planardamage"),
  range_attack = GetModConfigData("range_attack"),
  extra_damage = GetModConfigData("extra_damage"),
  pillow_knockback = GetModConfigData("pillow_knockback"),
  hit_flicker = GetModConfigData("hit_flicker"),
  aoe_damage_ratio = GetModConfigData("aoe_damage_ratio"),
  life_drain_ratio = GetModConfigData("life_drain_ratio"),
  hunger_conversion_ratio = GetModConfigData("hunger_conversion_ratio"),
  sanity_conversion_ratio = GetModConfigData("sanity_conversion_ratio"),
  -- 工具配置项
  tool_enable = GetModConfigData("tool_enable"),
  enable_gem_abilities = GetModConfigData("enable_gem_abilities"),
  gem_unlock_required = GetModConfigData("gem_unlock_required"),
  multi_tool_state_save = GetModConfigData("multi_tool_state_save"),
  enable_hammer_action = GetModConfigData("enable_hammer_action"),
  enable_dig_action = GetModConfigData("enable_dig_action"),
  enable_scythe = GetModConfigData("enable_scythe"),
  tool_efficiency = GetModConfigData("tool_efficiency"),
  auto_work_range = GetModConfigData("auto_work_range"),
  auto_farm_range = GetModConfigData("auto_farm_range"),
  enable_light_fx = GetModConfigData("enable_light_fx"),
  enable_player_glow = GetModConfigData("enable_player_glow"),
  fx_particle_type = GetModConfigData("fx_particle_type"),
  enable_tool_toggle_icon = GetModConfigData("enable_tool_toggle_icon"),
  enable_tool_toggle_rename = GetModConfigData("enable_tool_toggle_rename"),
  cane_icon_text = GetModConfigData("cane_icon_text"),
  -- 常驻功能配置项
  enable_watering = GetModConfigData("enable_watering"),  enable_paddling = GetModConfigData("enable_paddling"),
  enable_fishingrod = GetModConfigData("enable_fishingrod"),
  enable_brush = GetModConfigData("enable_brush"),
  enable_hoe = GetModConfigData("enable_hoe"),
  enable_razor = GetModConfigData("enable_razor"),
  -- 其他配置项
  anti_lose = GetModConfigData("anti_lose_enable"),
  lightning_protect_enable = GetModConfigData("lightning_protect_enable"),
  rain_protect_enable = GetModConfigData("rain_protect_enable"),
  constant_temp_effect_enable = GetModConfigData("constant_temp_effect_enable"),
  enable_walrus_tusk_craft = GetModConfigData("enable_walrus_tusk_craft"),
  enable_walrus_tusk_drop = GetModConfigData("enable_walrus_tusk_drop"),
  enable_slot = GetModConfigData("enable_slot"),
}

-- 5.6.27：右键开关配置已合并进 tool_enable（右键 use 与轮盘点击共用同一总开关）。
-- 常驻工具（刷子/剃刀/锄头/钓鱼/浇水/划桨）不再被"纯被动模式"连带关闭，
-- 完全由各自独立配置开关控制；passive_only 恒 false，仅保留占位避免改动多处判断。
local passive_only = false

TUNING.hcanelight                = GetModConfigData("hcane_light")

-- ============================================================
-- 六色宝石「新能力」系统（红=点燃 / 绿=拆解）
-- ⚠️ 完全独立于下面 DoAutotask 的扫描 15 格逻辑：
--    扫描那只靠背包/装备里的实物触发被动加成，这里靠 UI 解锁 + 主动选择的 active_gem，
--    二者字段、开关、触发时机都不共用，互不干扰。
-- 参照格子优化 hslot 已验证的「按 userid 存盘 + player_classified netvar + RPC」模式。
-- ============================================================
local GEM_ENABLED = config.enable_gem_abilities ~= false
local GEM_UNLOCK_REQUIRED = config.gem_unlock_required ~= false

-- 六色全部开放：能力照抄官方 king_cane / staff_common 的 fns。
-- 顺序与 UI 轮盘一致（红橙黄绿蓝紫）。
local GEM_KEYS = { "red", "orange", "yellow", "green", "blue", "purple" }
-- ⭐ 5.6.33：解锁材料扩到四类同色物品（宝石/月眼/护符/法杖）
--    prefab 名已对照官方源码：mooneye.lua=colour.."mooneye"、amulet.lua、staff.lua（蓝杖含 2/3 代）
local GEM_KEY_TO_PREFABS = {
  red    = { "redgem", "redmooneye", "redamulet", "firestaff" },
  orange = { "orangegem", "orangemooneye", "orangeamulet", "orangestaff" },
  yellow = { "yellowgem", "yellowmooneye", "yellowamulet", "yellowstaff" },
  green  = { "greengem", "greenmooneye", "greenamulet", "greenstaff" },
  blue   = { "bluegem", "bluemooneye", "blueamulet", "icestaff", "icestaff2", "icestaff3" },
  purple = { "purplegem", "purplemooneye", "purpleamulet", "telestaff" },
}
-- ⭐ 5.6.34：持有任一「彩虹宝石/虹彩法杖/不朽宝石」→ 直接解锁全部六色（无需逐颗持有）
--    opalstaff = 官方虹彩法杖（staff.lua:309），与彩虹宝石同为彩虹系全解锁材料
local GEM_ALL_UNLOCK_PREFABS = { "opalpreciousgem", "opalstaff", "immortal_gem" }
-- 提示文字（解锁/激活共用）
local GEM_LABEL = {
  red = "点燃", orange = "闪烁", yellow = "照明",
  green = "拆解", blue = "冰冻", purple = "传送",
}

-- ⭐ 5.6.26：解锁状态改为「按手杖 inst 记忆」——跟着手杖走，换人持有照样全解锁。
--    旧版按 userid 存在世界 persistent string（hcane_gem_abilities_unlock_v1），
--    现已废弃；新存档走 cane.OnSave/OnPreLoad 的 data.unlocked_gems。
--    旧档不迁移（测试阶段可放弃兼容），玩家需重新点宝石解锁一次。
-- ⚠️ 前向声明：RPC 闭包捕获 local 函数必须先声明再赋值，否则取到全局 nil。
local IsGemUnlocked, SyncGemStateToClient, GemUnlockedKeysString, SyncCaneSpellAvailability, SyncMultiStateToClient, ApplyGemAbility

local function UnlockedStringToTable(s)
  local t = {}
  if type(s) ~= "string" then return t end
  for k in s:gmatch("([^,]+)") do t[k] = true end
  return t
end

local function UnlockedTableToString(t)
  local list = {}
  for k in pairs(t or {}) do table.insert(list, k) end
  return table.concat(list, ",")
end

-- 手杖自身解锁（服务端普通表 + netvar 字符串，客户端 itemtile/轮盘镜像用）
local function GetCaneUnlocked(cane)
  if cane == nil then return {} end
  if cane.hcane_unlocked == nil then cane.hcane_unlocked = {} end
  return cane.hcane_unlocked
end

IsGemUnlocked = function(cane, key)
  if not GEM_UNLOCK_REQUIRED then return true end
  local t = GetCaneUnlocked(cane)
  return t[key] == true
end

GemUnlockedKeysString = function(cane)
  return UnlockedTableToString(GetCaneUnlocked(cane))
end

-- Legacy: 世界级旧存档加载函数保留空壳，避免下方 world postinit 调用到 nil
local function LoadGemUnlockData() end

-- ⚠️ 官方 inventory.lua:623 的 FindItem 只扫 itemslots+activeitem+背包容器，
--    **不扫 equipslots**；FindItems(:638) 才含装备栏。手杖/宝石常年在装备栏，
--    用 FindItem 会"装备着却找不到"。统一用 FindItems 取第一个。
--    必须定义在 SyncMultiStateToClient / CollectHeldPrefabs 之前（Lua local 先定义后引用）。
local function FindItemAnywhere(inv, fn)
  if inv == nil then return nil end
  local found = inv:FindItems(fn)
  return found ~= nil and found[1] or nil
end

-- ⚠️ 取"当前装备在手上的手杖"：多 cane 时 FindItems()[1] 可能是背包里那把，
--    字段写到它身上 → 攻击用的装备手杖读不到。装备栏优先，再回退全局查找。
local function GetEquippedCane(player)
  local inv = player ~= nil and player.components.inventory or nil
  if inv == nil then return nil end
  local equipped = inv:GetEquippedItem(EQUIPSLOTS.HANDS)
  if equipped ~= nil and equipped.prefab == "cane" then return equipped end
  return FindItemAnywhere(inv, function(item)
    return item ~= nil and item.prefab == "cane"
  end)
end

-- 服务端 → 客户端：解锁列表 + 当前激活宝石。classified 可能还没关联，带重试防死锁。
-- ⭐ 5.6.28：轮盘只服务「装备栏手杖」——状态镜像固定取 GetEquippedCane，
--    不再按 GUID 追视觉锚点（5.6.27 的焦点机制过度设计，已移除）。
SyncGemStateToClient = function(player, retry)
  if player == nil or not player:IsValid() then return end
  local classified = player.player_classified
  if classified == nil or classified._hcane_gem_unlock == nil then
    local tries = retry or 0
    if tries < 60 then
      player:DoTaskInTime(0.05, function()
        if player:IsValid() then SyncGemStateToClient(player, tries + 1) end
      end)
    end
    return
  end
  -- 解锁按手杖 inst；玩家级 classified 镜像固定反映装备栏那把（轮盘只服务装备栏）。
  -- 各 itemtile 状态格仍读自己手杖的 netvar，互不串。
  local cane_item = GetEquippedCane(player)
  classified._hcane_gem_unlock:set(GemUnlockedKeysString(cane_item))
  classified._hcane_gem_active:set(cane_item ~= nil and (cane_item._hcane_active_gem or "") or "")
  SyncMultiStateToClient(player)
  -- 进图/换图/存档恢复：把手杖自身状态补推一次到它自己的 netvar
  if cane_item ~= nil then
    if ApplyGemAbility ~= nil then ApplyGemAbility(cane_item) end
    if cane_item.hcane_sync_gem_net then cane_item.hcane_sync_gem_net() end
  end
end

-- 多功能总开关状态 → 客户端 UI（classified 未就绪时沿用上面的重试模式）
SyncMultiStateToClient = function(player, retry, cane_item)
  if player == nil or not player:IsValid() then return end
  local classified = player.player_classified
  if classified == nil or classified._hcane_multi_active == nil then
    local tries = retry or 0
    if tries < 60 then
      player:DoTaskInTime(0.05, function()
        if player:IsValid() then SyncMultiStateToClient(player, tries + 1, cane_item) end
      end)
    end
    return
  end
  -- cane_item（可选）= 本次右键切换的那把手杖，先推它自己的 netvar（itemtile 按实例读）。
  -- ⭐ 5.6.28：玩家级镜像只反映「装备栏手杖」——轮盘不再服务物品栏手杖，
  --    右键物品栏手杖改自己的状态，也不会把轮盘镜像带偏。
  if cane_item ~= nil and GEM_ENABLED and cane_item.hcane_sync_gem_net then
    cane_item.hcane_sync_gem_net()
  end
  local equipped = GetEquippedCane(player)
  if cane_item ~= nil and equipped ~= nil and cane_item.GUID == equipped.GUID then
    equipped = cane_item   -- 刚切换的就是装备栏那把，用新状态避免查找旧值
  end
  classified._hcane_multi_active:set(equipped ~= nil and equipped.all_active == true)
end

-- ⭐ 5.6.33：一次 FindItems 遍历收集玩家持有的全部 prefab（含装备栏），返回 prefab→true 集合。
--    开销：15 格 + 数个装备槽的线性扫描，只在「点灰宝石 / 开关手杖」这类手动操作时触发，
--    不是每帧 tick，开销可忽略。用集合做 O(1) 查找，避免逐 key 各扫一遍背包。
--    必须定义在 UnlockGemForPlayer / AutoUnlockGemsOnToggle 之前。
local function CollectHeldPrefabs(player)
  local set = {}
  local inv = player ~= nil and player.components.inventory or nil
  if inv == nil then return set end
  local items = inv:FindItems(function() return true end) or {}
  for _, item in pairs(items) do
    if item ~= nil and item.prefab ~= nil then set[item.prefab] = true end
  end
  return set
end

-- 持有任一全解锁宝石 → 返回 true
local function HasAllUnlockGem(held)
  for _, p in ipairs(GEM_ALL_UNLOCK_PREFABS) do
    if held[p] then return true end
  end
  return false
end

-- ⭐ 5.6.33：扫描并批量解锁「当前持有材料对应的、尚未解锁」的宝石。
--    返回本次新解锁的 key 列表（空表=没有变化），供调用方决定是否提示/同步。
local function UnlockGemsByHeldItems(player, cane)
  if not GEM_ENABLED or not GEM_UNLOCK_REQUIRED then return {} end
  if not TheWorld.ismastersim then return {} end
  if player == nil or not player:IsValid() or cane == nil then return {} end
  local unlocked = GetCaneUnlocked(cane)
  local held = CollectHeldPrefabs(player)
  local all_unlock = HasAllUnlockGem(held)
  local newly = {}
  for _, key in ipairs(GEM_KEYS) do
    if not unlocked[key] then
      local ok = all_unlock
      if not ok then
        for _, p in ipairs(GEM_KEY_TO_PREFABS[key]) do
          if held[p] then ok = true; break end
        end
      end
      if ok then
        unlocked[key] = true
        table.insert(newly, key)
      end
    end
  end
  if #newly > 0 then
    if cane.hcane_sync_gem_net then cane.hcane_sync_gem_net() end
    SyncGemStateToClient(player)
  end
  return newly
end

-- 把 key 列表拼成提示文字："已解锁「红」「蓝」"
local function UnlockSay(player, keys)
  if player == nil or player.components.talker == nil or #keys == 0 then return end
  local names = {}
  for _, k in ipairs(keys) do
    table.insert(names, "「" .. (GEM_LABEL[k] or k) .. "」")
  end
  player.components.talker:Say("已解锁" .. table.concat(names, ""))
end

-- ⭐ 5.6.33：右键开关 / 轮盘 UI 开关手杖时调用——顺手扫描解锁未解锁宝石。
--    复用同一套 held 集合，不额外增加扫描次数（开销见 CollectHeldPrefabs 注释）。
local function AutoUnlockGemsOnToggle(player, cane)
  if not GEM_ENABLED or not GEM_UNLOCK_REQUIRED then return end
  if not TheWorld.ismastersim then return end
  if player == nil or not player:IsValid() or cane == nil then return end
  local newly = UnlockGemsByHeldItems(player, cane)
  UnlockSay(player, newly)
end

-- ⭐ 5.6.26：解锁按手杖 inst（换人持有照样解锁），不再按 userid
-- ⭐ 5.6.28：轮盘只服务装备栏手杖，解锁目标固定 = GetEquippedCane
-- ⭐ 5.6.33：点灰宝石也走批量扫描（持有月眼/护符/法杖/彩虹宝石均可解锁）
local function UnlockGemForPlayer(player, key)
  if not GEM_ENABLED or not GEM_UNLOCK_REQUIRED then return end
  if not TheWorld.ismastersim then return end
  if type(key) ~= "string" or GEM_KEY_TO_PREFABS[key] == nil then return end
  if player == nil or not player:IsValid() then return end
  local cane = GetEquippedCane(player)
  if cane == nil then return end
  if IsGemUnlocked(cane, key) then
    SyncGemStateToClient(player)
    if cane.hcane_sync_gem_net then cane.hcane_sync_gem_net() end
    return
  end
  -- 扫描一次：命中目标 key（或持有彩虹宝石）即解锁；顺带把其它能满足的也解锁
  local newly = UnlockGemsByHeldItems(player, cane)
  local got_target = false
  for _, k in ipairs(newly) do if k == key then got_target = true end end
  if not got_target then
    if player.components.talker then
      player.components.talker:Say("需要持有对应的宝石/月眼/护符/法杖才能解锁")
    end
    return
  end
  UnlockSay(player, newly)
end

-- 两端都要注册 RPC id；真正逻辑只在主机端执行
AddModRPCHandler("hcane_gem", "unlock", function(player, key)
  UnlockGemForPlayer(player, key)
end)

AddModRPCHandler("hcane_gem", "set_active", function(player, key)
  if not GEM_ENABLED then return end
  if not TheWorld.ismastersim then return end
  if type(key) ~= "string" then return end
  -- ⭐ 5.6.17：轮盘第 7 项 "none" = 不选择宝石，不需要解锁，直接清空
  local valid = (key == "none")
  for _, k in ipairs(GEM_KEYS) do if k == key then valid = true end end
  if not valid then return end
  if player == nil or not player:IsValid() then return end
  -- ⭐ 5.6.28：目标固定为装备栏手杖；物品栏手杖不参与轮盘操作。
  local cane_item = GetEquippedCane(player)
  if cane_item == nil then return end
  if key ~= "none" and not IsGemUnlocked(cane_item, key) then
    SyncGemStateToClient(player)
    return
  end
  -- 选 "none" 或再次点击当前激活项 → 取消激活
  local current = cane_item._hcane_active_gem
  if key == "none" or current == key then
    cane_item._hcane_active_gem = nil
  else
    cane_item._hcane_active_gem = key
  end
  -- 能力逻辑（红点燃等）读手杖 inst 字段；netvar 推给该手杖自己的 itemtile UI
  ApplyGemAbility(cane_item)
  if cane_item.hcane_sync_gem_net then cane_item.hcane_sync_gem_net() end
  -- 镜像同步：GetEquippedCane 就是刚改的这把，轮盘读到一致状态
  SyncGemStateToClient(player)
  if player.components.talker then
    player.components.talker:Say(cane_item._hcane_active_gem
      and ("已启用「" .. (GEM_LABEL[key] or key) .. "」")
      or "已关闭宝石能力")
  end
end)

-- UI 中心图标 = 多功能总开关：服务端切手杖 all_active，netvar 把状态同步回 UI。
-- 与右键 useableitem 走同一个 cane.hcane_toggle_active，避免两个入口状态分叉。
AddModRPCHandler("hcane_gem", "toggle_multi", function(player)
  if not GEM_ENABLED or not TheWorld.ismastersim then return end
  if player == nil or not player:IsValid() then return end
  local inv = player.components.inventory
  if inv == nil then return end
  -- ⭐ 5.6.28：轮盘总开关只切装备栏手杖，与右键 useableitem 同一入口函数
  local cane_item = GetEquippedCane(player)
  if cane_item == nil or cane_item.hcane_toggle_active == nil then return end
  cane_item.hcane_toggle_active(player)
  SyncMultiStateToClient(player, nil, cane_item)
end)

-- ⭐ 5.6.29：客户端检测到装备栏手杖变化后后台请求重推镜像，
--    避免切换手杖时 netvar 还没到位 → 轮盘读空解锁整圈全黑。
AddModRPCHandler("hcane_gem", "refresh_state", function(player)
  if not GEM_ENABLED or not TheWorld.ismastersim then return end
  if player == nil or not player:IsValid() then return end
  SyncGemStateToClient(player)
end)

-- netvar 两端都要建（客户端只读，服务端写）
AddPrefabPostInit("player_classified", function(inst)
  inst._hcane_gem_unlock = GLOBAL.net_string(inst.GUID, "_hcane_gem_unlock", "hcaneGemUnlockDirty")
  inst._hcane_gem_active = GLOBAL.net_string(inst.GUID, "_hcane_gem_active", "hcaneGemActiveDirty")
  inst._hcane_multi_active = GLOBAL.net_bool(inst.GUID, "_hcane_multi_active", "hcaneMultiActiveDirty")
end)

-- ⭐ 5.6.26 调试命令：hcane_cleargems() 清除当前玩家所有手杖的解锁，
--    清完立即同步客户端（轮盘六色变回黑=未解锁），可逐个点击重新解锁测试。
local function ClearAllGemUnlocks()
  if TheWorld == nil or not TheWorld.ismastersim then return end
  for _, player in pairs(AllPlayers or {}) do
    if player ~= nil and player:IsValid() then
      local inv = player.components.inventory
      local canes = inv ~= nil and inv:FindItems(function(item)
        return item ~= nil and item.prefab == "cane"
      end) or {}
      for _, cane in pairs(canes) do
        cane.hcane_unlocked = {}
        cane._hcane_active_gem = nil
        if cane.hcane_sync_gem_net then cane.hcane_sync_gem_net() end
      end
      SyncGemStateToClient(player)
    end
  end
  print("[hcane] 已清除所有手杖的宝石解锁，可逐个重新解锁测试")
end
rawset(GLOBAL, "hcane_cleargems", ClearAllGemUnlocks)

-- 玩家进图（含换图）补同步一次
AddPlayerPostInit(function(inst)
  if not TheWorld.ismastersim then return end
  inst:DoTaskInTime(0, function()
    if inst:IsValid() then SyncGemStateToClient(inst) end
  end)
end)

-- ============================================================
-- 绿宝石「拆解」——完整移植官方 greenstaff 的 destroystructure
-- 来源：官方 prefabs/staff_common.lua（DESTSOUNDSMAP / SpawnLootPrefab / destroystructure）
-- 只把施法者从 staff.components.inventoryitem.owner 取，其余逻辑与官方一致。
-- 与扫描 15 格完全无关：是否可施法由 SyncGemSpellAvailability 按 active_gem 切换。
-- ============================================================
local HCANE_DESTSOUNDS = {
  { soundpath = "dontstarve/common/destroy_magic",
    ing = { "nightmarefuel", "horrorfuel", "livinglog", "shadowheart_infused", "alterguardianhatshard", "moonrockcrater" } },
  { soundpath = "dontstarve/common/destroy_clothing", ing = { "silk", "beefalowool" } },
  { soundpath = "dontstarve/common/destroy_tool", ing = { "twigs" } },
  { soundpath = "dontstarve/common/gem_shatter",
    ing = { "redgem", "bluegem", "greengem", "purplegem", "yellowgem", "orangegem", "purebrilliance" } },
  { soundpath = "dontstarve/common/destroy_wood", ing = { "log", "boards", "driftwood_log" } },
  { soundpath = "dontstarve/common/destroy_stone",
    ing = { "rocks", "cutstone", "saltrock", "flint", "marble", "nitre", "thulecite", "thulecite_pieces" } },
  { soundpath = "dontstarve/common/destroy_straw", ing = { "cutgrass", "cutreeds", "petals", "petals_evil", "rope" } },
  { soundpath = "dontstarve/common/destroy_metal",
    ing = { "gears", "wagpunk_bits", "transistor", "trinket_6", "scandata", "security_pulse_cage_full" } },
}
local HCANE_DESTSOUNDSMAP = {}
for _, v in ipairs(HCANE_DESTSOUNDS) do
  for _, ing in ipairs(v.ing) do HCANE_DESTSOUNDSMAP[ing] = v.soundpath end
end

local function HcaneCheckSpawnedLoot(loot)
  if loot.components.inventoryitem ~= nil then
    loot.components.inventoryitem:TryToSink()
  else
    local x, y, z = loot.Transform:GetWorldPosition()
    if ShouldEntitySink(loot, true) or TheWorld.Map:IsPointNearHole(Vector3(x, 0, z)) then
      SinkEntity(loot)
    end
  end
end

local function HcaneSpawnLootPrefab(inst, lootprefab)
  if lootprefab == nil then return end
  local loot = SpawnPrefab(lootprefab)
  if loot == nil then return end
  local x, y, z = inst.Transform:GetWorldPosition()
  if loot.Physics ~= nil then
    local angle = math.random() * TWOPI
    loot.Physics:SetVel(2 * math.cos(angle), 10, 2 * math.sin(angle))
    if inst.Physics ~= nil then
      local len = loot:GetPhysicsRadius(0) + inst:GetPhysicsRadius(0)
      x = x + math.cos(angle) * len
      z = z + math.sin(angle) * len
    end
    loot:DoTaskInTime(1, HcaneCheckSpawnedLoot)
  end
  loot.Transform:SetPosition(x, y, z)
  loot:PushEvent("on_loot_dropped", { dropper = inst })
  return loot
end

local function HcaneDestroyStructure(staff, target)
  if not GEM_ENABLED then return end
  -- ⭐ 5.6.26：绿杖拆解按手杖自身 active_gem 判断（owner 玩家级字段已废弃）
  if staff._hcane_active_gem ~= "green" then return end

  local recipe = AllRecipes[target.prefab]
  if recipe == nil or FunctionOrValue(recipe.no_deconstruction, target) then return end

  local ingredient_percent =
      ((target.components.finiteuses ~= nil and not FunctionOrValue(recipe.decon_ignores_finiteuses, target) and target.components.finiteuses:GetPercent())
        or (target.components.fueled ~= nil and target.components.inventoryitem ~= nil and target.components.fueled:GetPercent())
        or (target.components.armor ~= nil and target.components.inventoryitem ~= nil and target.components.armor:GetPercent())
        or 1) / recipe.numtogive

  local caster = staff.components.inventoryitem.owner
  if target.components.itemmimic then
    if caster then caster.SoundEmitter:PlaySound("dontstarve/creatures/monkey/poopsplat") end
    target.components.itemmimic:TurnEvil(caster)
  else
    for _, v in ipairs(recipe.ingredients) do
      if caster ~= nil and HCANE_DESTSOUNDSMAP[v.type] ~= nil then
        caster.SoundEmitter:PlaySound(HCANE_DESTSOUNDSMAP[v.type])
      end
      if string.sub(v.type, -3) ~= "gem" or string.sub(v.type, -11, -4) == "precious" then
        local amt = v.amount == 0 and 0 or math.max(1, math.ceil(v.amount * ingredient_percent))
        for _ = 1, amt do HcaneSpawnLootPrefab(target, v.type) end
      end
    end
    if target.components.inventory ~= nil then target.components.inventory:DropEverything() end
    if target.components.container ~= nil then target.components.container:DropEverything(nil, true) end
    if target.components.spawner ~= nil and target.components.spawner:IsOccupied() then
      target.components.spawner:ReleaseChild()
    end
    if target.components.occupiable ~= nil and target.components.occupiable:IsOccupied() then
      local item = target.components.occupiable:Harvest()
      if item ~= nil then
        item.Transform:SetPosition(target.Transform:GetWorldPosition())
        item.components.inventoryitem:OnDropped()
      end
    end
    if target.components.trap ~= nil then target.components.trap:Harvest() end
    if target.components.dryer ~= nil then target.components.dryer:DropItem() end
    if target.components.harvestable ~= nil then target.components.harvestable:Harvest() end
    if target.components.stewer ~= nil then target.components.stewer:Harvest() end
    if target.components.constructionsite ~= nil then target.components.constructionsite:DropAllMaterials() end
    if target.components.inventoryitemholder ~= nil then target.components.inventoryitemholder:TakeItem() end
    target:PushEvent("ondeconstructstructure", caster)
    if not target.no_delete_on_deconstruct then
      if target.components.stackable ~= nil then
        target.components.stackable:Get():Remove()
      else
        target:Remove()
      end
    end
  end
  if caster ~= nil then
    caster.SoundEmitter:PlaySound("dontstarve/common/staff_dissassemble")
    if caster.components.staffsanity then
      caster.components.staffsanity:DoCastingDelta(-TUNING.SANITY_MEDLARGE)
    elseif caster.components.sanity ~= nil then
      caster.components.sanity:DoDelta(-TUNING.SANITY_MEDLARGE)
    end
  end
  -- 手杖没有 finiteuses/rechargeable，不消耗耐久（与官方绿杖的差异，刻意为之）
end

-- ============================================================
-- 红宝石「点燃」——官方火魔杖 onattack_red 的点燃核心
-- 来源：官方 prefabs/staff_common.lua onattack_red（74-106 行）
-- 只用于六色 UI 的 active_gem=="red"，与扫描 15 格的 _has_redgem 无关
-- ============================================================
local function HcaneFireIgniteOnAttack(inst, attacker, target)
  if not GEM_ENABLED then return end
-- ⚠️ 判据以手杖自身字段 _hcane_active_gem 为准（攻击帧 attacker 在坐骑/代理场景可能不是玩家本体，
--    GetGrandOwner 也会短暂失效）。该字段由 set_active RPC 直接写到手杖上，与扫描 15 格同构，最可靠。
--    attacker 字段仅作回退：老存档手杖还没同步到新字段时用玩家本体兜底。
  -- 严格绑武器：字段为 nil（老存档尚未同步）才用玩家字段兜底一次；
  -- 已是其它颜色则直接 return，避免"武器没激活红但玩家选了红"误触发。
  if inst._hcane_active_gem == nil then
    if attacker == nil or not attacker:IsValid() or attacker._hcane_active_gem ~= "red" then return end
  elseif inst._hcane_active_gem ~= "red" then
    return
  end
  if target == nil or not target:IsValid() then return end

  -- 官方火魔杖音效（king_cane 红宝石同款）；不消耗理智、不重复推 attacked，
  -- 因为手杖本身有真实伤害和完整攻击事件，照抄的只是"点燃能力"。
  -- 纵火者/施法者：attacker 可能为 nil（代理攻击），回退到手杖 owner
  local doer = (attacker ~= nil and attacker:IsValid() and attacker) or
               (inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()) or nil
  if doer ~= nil and doer.SoundEmitter ~= nil then
    doer.SoundEmitter:PlaySound(inst.skin_sound or "dontstarve/wilson/fireball_explo")
  end

  if target.components.burnable ~= nil and not target.components.burnable:IsBurning() then
    if target.components.freezable ~= nil and target.components.freezable:IsFrozen() then
      target.components.freezable:Unfreeze()
    elseif target.components.fueled == nil
        or (target.components.fueled.fueltype ~= FUELTYPE.BURNABLE
            and target.components.fueled.secondaryfueltype ~= FUELTYPE.BURNABLE) then
      if target.components.burnable.canlight or target.components.combat ~= nil then
        target.components.burnable:Ignite(true, doer)
      end
    elseif target.components.fueled.accepting then
      local fuel = SpawnPrefab("cutgrass")
      if fuel ~= nil then
        if fuel.components.fuel ~= nil and fuel.components.fuel.fueltype == FUELTYPE.BURNABLE then
          target.components.fueled:TakeFuelItem(fuel)
        else
          fuel:Remove()
        end
      end
    end
  end
  if target.components.freezable ~= nil then
    target.components.freezable:AddColdness(-1)
    if target.components.freezable:IsFrozen() then target.components.freezable:Unfreeze() end
  end
  if target.components.sleeper ~= nil and target.components.sleeper:IsAsleep() then
    target.components.sleeper:WakeUp()
  end
  if target.components.combat ~= nil and doer ~= nil then
    target.components.combat:SuggestTarget(doer)
  end
end

-- ============================================================
-- 蓝宝石「冰冻」——官方冰魔杖 onattack_blue 核心（staff_common.lua:161-204）
-- 普攻命中触发，与红宝石点燃走同一条 onattack 分发。
-- ============================================================
local function HcaneIceFreezeOnAttack(inst, attacker, target)
  if not GEM_ENABLED then return end
  if inst._hcane_active_gem ~= "blue" then return end
  if target == nil or not target:IsValid() then return end

  if target.components.sleeper ~= nil and target.components.sleeper:IsAsleep() then
    target.components.sleeper:WakeUp()
  end
  if target.components.burnable ~= nil then
    if target.components.burnable:IsBurning() then
      target.components.burnable:Extinguish()
    elseif target.components.burnable:IsSmoldering() then
      target.components.burnable:SmotherSmolder()
    end
  end
  if target.components.combat ~= nil then
    target.components.combat:SuggestTarget(attacker)
  end
  -- 官方用 statetag 门禁避免重复 attacked；手杖本身已经有完整攻击事件，这里只补冰冻
  -- ⭐ 5.6.32：AddColdness(冷度16, 冻结16秒)。官方 icestaff3=冷度3、冻结默认10秒；
  --    本杖冷度 16 > 3（越过高抗性/boss 门槛），冻结 16 秒 > 10 秒，两个维度都更强。
  if target.components.freezable ~= nil and target:IsValid() then
    target.components.freezable:AddColdness(16, 16)
    target.components.freezable:SpawnShatterFX()
  end
end

-- ============================================================
-- 紫宝石「闪电」——官方 book_brimstone 召唤闪电（books.lua:348-380）
-- 普攻命中时在目标周围环形落雷：TheWorld:PushEvent("ms_sendlightningstrike", pos)，
-- 官方 weather.lua 会找落点 40 内最近实体重定向、造成伤害+点燃可燃物（componentutil.lua:1065）。
-- ⚠️ 与书不同：这里落点围绕**目标**而非玩家，且缩小范围(1-5)/数量(7道)/加冷却，
--    避免连续攻击刷屏。防点燃攻击者的 hack 照抄官方 teleport_end（临时置 burning=true）。
-- ============================================================
local function HcanePurpleLightningOnAttack(inst, attacker, target)
  if not GEM_ENABLED then return end
  if inst._hcane_active_gem ~= "purple" then return end
  if target == nil or not target:IsValid() then return end
  if attacker == nil or not attacker:IsValid() then return end

  -- 冷却：同一把杖 1.5 秒内只召唤一轮，防止连击刷屏/叠加线程
  if inst._hcane_lightning_busy then return end
  inst._hcane_lightning_busy = true
  inst:DoTaskInTime(1.5, function()
    if inst:IsValid() then inst._hcane_lightning_busy = false end
  end)

  local pt = target:GetPosition()
  local num_lightnings = 7
  attacker:StartThread(function()
    for k = 0, num_lightnings do
      if not attacker:IsValid() then break end
      local rad = math.random(1, 5)
      local angle = (k * 2 * math.pi / num_lightnings) + math.random() * 0.3
      local pos = pt + GLOBAL.Vector3(rad * math.cos(angle), 0, rad * math.sin(angle))
      -- 官方 hack：临时置 burning 防止闪电点燃攻击者自己（照抄 teleport_end）
      local preventburning = attacker.components.burnable ~= nil
          and not attacker.components.burnable.burning
      if preventburning then attacker.components.burnable.burning = true end
      TheWorld:PushEvent("ms_sendlightningstrike", pos)
      if preventburning then attacker.components.burnable.burning = false end
      GLOBAL.Sleep(0.08 + math.random() * 0.12)
    end
  end)
end

-- ============================================================
-- 黄宝石「照明」——官方黄魔杖 createlight（staff_common.lua:788-806）
-- ⭐ 红/蓝不再有右键 spellFn：红靠 rangedlighter 标签走官方 ATTACK（点燃），
--    蓝右键对目标无动作（熄灭只在左键弹道命中）。见 SyncCaneSpellAvailability。
-- ============================================================
local function HcaneCreateLight(staff, target, pos)
  if not GEM_ENABLED then return end
  if staff._hcane_active_gem ~= "yellow" then return end
  -- 总开关关=普通黄光 stafflight；开=极光 staffcoldlight（官方 opalstaff 同款）
  -- staff 本身就是施法手杖实体，ToggleCaneActive 直接写在它身上（inst.all_active）
  local light_name = staff.all_active and "staffcoldlight" or "stafflight"
  local light = SpawnPrefab(light_name)
  if light == nil then return end
  if pos ~= nil then
    light.Transform:SetPosition(pos:Get())
  else
    local x, y, z = staff.Transform:GetWorldPosition()
    light.Transform:SetPosition(x, y, z)
  end
  local caster = staff.components.inventoryitem and staff.components.inventoryitem:GetGrandOwner() or nil
  if caster ~= nil and caster.components.sanity ~= nil then
    caster.components.sanity:DoDelta(-TUNING.SANITY_MEDLARGE)
  end
end

-- ============================================================
-- 橙宝石「闪烁」——直接复用 DoGemStateTask 橙法杖分支挂的官方 blinkstaff 原生组件。
-- 橙法杖状态（active_gem=="orange"）时 AddComponent("blinkstaff") 并设好 SetFX，
-- 右键地面走官方 BLINK action，零重复实现。
-- 这里只负责：UI 橙激活时清掉 spellcaster 槽，避免 CASTSPELL 抢走 BLINK。
-- ⚠️ 5.6.18：绝不能加 cannotuse——BLINK 在 POINT 上下文（右键地面），
--    USEITEM 开关在 INVENTORY 上下文（右键物品格），两者天然不冲突；
--    加 cannotuse 只会禁掉右键 use 开关（用户实测"橙挤掉 use 组件"）。
-- ============================================================

-- ============================================================
-- 紫宝石「传送」——简约版：ScreenFade 黑屏直传（hslot 已验证管线，技能库 §5）
-- 去掉官方 teleport_start/continue/end 三件套的落雷/湿度/小地震/forcetele 3s+1s 等待，
-- 只保留：落点选择（传送台优先 → 地图房间中心）→ 黑屏 → 直接 Teleport → 渐显 + 传送音效。
-- 无卡黑屏风险（不做 forcetele 状态机 / loctarget:IsValid 判据）。
-- ============================================================
local function HcaneTeleportFunc(staff, target, pos, caster)
  if not GEM_ENABLED then return end
  if staff._hcane_active_gem ~= "purple" then return end
  caster = caster or (staff.components.inventoryitem and staff.components.inventoryitem:GetGrandOwner()) or nil
  target = target or caster
  if target == nil or not target:IsValid() then return end
  if target:HasTag("noteleport") then return end

  local x, y, z = target.Transform:GetWorldPosition()
  -- 官方同款禁传判定：禁区 / 玩家在水上时不传
  if GLOBAL.IsTeleportLinkingPermittedFromPoint ~= nil
      and not GLOBAL.IsTeleportLinkingPermittedFromPoint(x, y, z) then return end
  if target.components.locomotor ~= nil and target.components.locomotor:IsAquatic() then return end

  -- 落点：官方传送台优先（telebase.lua 定义的全局函数），没有则随机可行走房间中心
  local dest_x, dest_z = nil, nil
  local findbase = GLOBAL.FindNearestActiveTelebase
  if findbase ~= nil then
    local loctarget = findbase(x, y, z, nil, 1, "purplegem")
    if loctarget ~= nil and loctarget.GetPosition ~= nil then
      local px, _, pz = loctarget:GetPosition():Get()
      dest_x, dest_z = px, pz
      if loctarget.onteleto ~= nil then loctarget:onteleto() end
    end
  end
  if dest_x == nil and TheWorld.topology ~= nil and TheWorld.topology.nodes ~= nil then
    local centers = {}
    for _, node in ipairs(TheWorld.topology.nodes) do
      if TheWorld.Map:IsPassableAtPoint(node.x, 0, node.y) and node.type ~= NODE_TYPE.SeparatedRoom then
        table.insert(centers, { x = node.x, z = node.y })
      end
    end
    if #centers > 0 then
      local pick = centers[math.random(#centers)]
      dest_x, dest_z = pick.x, pick.z
    end
  end
  if dest_x == nil then return end

  if target.components.locomotor ~= nil then target.components.locomotor:StopMoving() end
  if caster ~= nil and caster.components.sanity ~= nil then
    caster.components.sanity:DoDelta(-TUNING.SANITY_HUGE)
  end

  local castsound = staff.skin_castsound or staff.castsound or "dontstarve/common/staffteleport"
  if target.SoundEmitter ~= nil then
    if staff.castsoundparams then
      target.SoundEmitter:PlaySoundWithParams(castsound, staff.castsoundparams)
    else
      target.SoundEmitter:PlaySound(castsound)
    end
  end
  -- ScreenFade 只在服务端玩家实体上有；非玩家目标直接传送
  if target:HasTag("player") and target.ScreenFade ~= nil then
    target:ScreenFade(false, 0.4)
    target:DoTaskInTime(0.45, function()
      if not target:IsValid() then return end
      if target.Physics ~= nil then
        target.Physics:Teleport(dest_x, 0, dest_z)
      else
        target.Transform:SetPosition(dest_x, 0, dest_z)
      end
      target:SnapCamera()
      target:ScreenFade(true, 0.4)
    end)
  else
    if target.Physics ~= nil then
      target.Physics:Teleport(dest_x, 0, dest_z)
    else
      target.Transform:SetPosition(dest_x, 0, dest_z)
    end
    target:PushEvent("teleported")
  end
end

-- 按 active_gem 切换手杖 spellcaster 标签与能力。
-- 红=点燃 / 蓝=熄灭 / 绿=拆解 / 黄=照明 / 紫=传送 → 走 spellcaster（同一时间一个 spellFn）。
-- 橙=闪烁 → 不占 spellcaster，直接复用扫描 15 格挂的官方 blinkstaff 原生组件（右键地面 BLINK）。
-- 源码确认（components/spellcaster.lua:89-99）：canuseontargets/canuseonpoint 等是
-- 带 ondefine 的字段，直接赋值就会自动维护 castontargets/castonpoint 等标签，
-- componentactions.lua 只读标签，所以这里改字段即可，不要手动 AddTag。
SyncCaneSpellAvailability = function(inst)
  if not GEM_ENABLED then return end
  local sc = inst.components.spellcaster
  if sc == nil then return end
  -- ⭐ 5.6.26：只认手杖自身字段（玩家级字段已废弃，owner 查询在攻击帧也可能失效）
  local gem = inst._hcane_active_gem

  local want_red    = gem == "red"
  local want_blue   = gem == "blue"
  -- ⭐ 5.6.19：绿杖拆解受多功能总开关门禁——总开关关时拆解完全不挂
  --    （spellFn 清空 + castontargets 标签移除），打开才有拆解。
  local want_green  = gem == "green" and inst.all_active == true
  local want_yellow = gem == "yellow"
  local want_purple = gem == "purple"
  -- ⭐ 红/蓝不走 spellcaster：红靠 rangedlighter 标签让右键目标走官方 ATTACK（点燃），
  --    蓝靠 extinguisher 标签让右键燃烧物走官方 ATTACK（熄灭）。橙走原生 BLINK。
  --    这三色都不占 spellcaster；cannotuse 5.6.18 起一律移除（见下方说明）。

  -- ⭐ 官方火魔杖同款：rangedlighter 标签让 componentactions.lua:2540 (right and CanLightTarget)
  --    对可点目标收集 ATTACK → weapon:SetProjectile 火弹 → onattack 点燃。
  -- ⭐ 官方冰魔杖同款：extinguisher 标签让 combat:CanHitTarget → CanExtinguishTarget 放行
  --    对燃烧/闷烧目标（含无 combat 的篝火/燃烧箱子）的 ATTACK，弹道命中后 onattack 熄灭。
  --    ⚠️ 官方 CanExtinguishTarget 不区分左右键：`componentactions.lua:2540` 里
  --       `CanExtinguishTarget(target, inst)` 无 right 门禁 → 右键燃烧物也会扑灭（官方冰杖行为，
  --       用户 5.6.15 确认接受）。对普通目标无标签时右键仍无任何 action。
  --    切走对应色时务必移除，避免残留标签继续点燃/熄灭。
  if want_red then
    inst:AddTag("rangedlighter")
  else
    inst:RemoveTag("rangedlighter")
  end
  if want_blue then
    inst:AddTag("extinguisher")
  else
    inst:RemoveTag("extinguisher")
  end

  -- 互斥设置 spellFn；红/蓝/橙/无都清空，避免残留标签继续触发旧动作
  if want_green then
    sc:SetSpellFn(HcaneDestroyStructure)
  elseif want_yellow then
    sc:SetSpellFn(HcaneCreateLight)
  elseif want_purple then
    sc:SetSpellFn(HcaneTeleportFunc)
  else
    sc:SetSpellFn(nil)
  end
  -- ⭐ 红/蓝不挂 castontargets——它们的右键走官方 ATTACK（红靠 rangedlighter），
  --    挂了会被 spellcaster 抢占成 CASTSPELL（施法动作），违背"点燃不是施法"。
  --    绿/紫才是右键目标施法；绿限制建筑配方，紫是传送。
  sc.canuseontargets          = want_green or want_purple
  sc.canonlyuseonrecipes      = want_green
  sc.canusefrominventory      = want_purple
  sc.canonlyuseonlocomotorspvp = want_purple
  sc.canuseonpoint            = want_yellow
  sc.canuseonpoint_water      = want_yellow
  -- 红蓝不再走 spellcaster，can_cast_fn 一律清空，避免带偏黄/紫的判定。
  sc:SetCanCastFn(nil)

  -- ⭐ 5.6.18 修复：cannotuse 绝不能按"是否激活宝石"全局加！
  --    官方 useableitem 的 USEITEM 在 INVENTORY 上下文收集（componentactions.lua:3055），
  --    条件就是 not HasAnyTag("inuse","cannotuse")。紫/橙一激活就 AddTag →
  --    右键物品栏手杖格的 use 开关被整个禁掉（用户实测"挤掉 use 组件"）。
  --    事实上两条路径天然分离：USEITEM 开关 = 右键物品栏格子（INVENTORY）；
  --    法杖能力 = 右键世界目标/地面（USEITEM/EQUIPPED/POINT）。
  --    且 USEITEM priority=1 > CASTSPELL priority=-1，紫的 castfrominventory 也抢不走开关。
  --    所以这里统一移除，右键开关在所有颜色下都保留；总开关另有状态图标左键入口。
  inst:RemoveTag("cannotuse")
  -- 官方 oncancast 的 spell==nil 分支漏清 castonpointwater，切橙/无施法色时会残留，
  -- 导致海面仍收集 CASTSPELL。这里显式清掉，避免标签污染。
  if not sc.canusefrominventory and not sc.canuseonpoint and not sc.canuseonpoint_water then
    inst:RemoveTag("castonpointwater")
  end
end

-- 六色能力总入口：刷新 spellcaster + 红蓝弹道。
-- ⭐ 红/蓝：给 weapon 挂官方弹道（fire_projectile / ice_projectile），
--    普攻变成发射弹道，命中走 combat:DoAttack → weapon.onattack → 现有全部效果
--    （伤害 + 点燃/冰冻 + 击退 + 位面伤害），完全复用现有 onattack 钩子，零重复。
--    弹道的 OnHit 官方自带 fire_fail_fx / shatter 特效；熄灭由 onattack 里的 Extinguish 完成。
--    切到其它颜色 / 取消激活 → 清掉 projectile 恢复近战。
-- 绿/黄/紫：右键 spellcaster；橙：原生 blinkstaff（见下）。
ApplyGemAbility = function(inst)
  if not GEM_ENABLED then return end
  local gem = inst._hcane_active_gem

  -- 红/蓝弹道：只改 weapon.projectile 字段，命中复用现有 onattack，不复制任何效果代码
  if inst.components.weapon ~= nil then
    local proj = (gem == "red" and "fire_projectile") or (gem == "blue" and "ice_projectile") or nil
    if inst.components.weapon.projectile ~= proj then
      inst.components.weapon:SetProjectile(proj)
    end
  end

  SyncCaneSpellAvailability(inst)
end

-- ============================================================
-- 掌掴击退（仿 handpillow_steelwool / bearger）
-- 只借用它的击退数据与 knockback 事件，**不借用前摇**：
--   加了 `pillow` 标签会让 SGwilson 走 attack_pillow_pre（0.16s 前摇），
--   这里刻意不加，攻击保持标准 attack 状态 = 普通武器攻速，命中后再附加击退位移
-- 官方参数来源：
--   prefabs/pillow_defs.lua        —— steelwool 原始值 strengthmult 2.2（本 MOD 按手感调高到 3.6）
--   prefabs/pillow_equipment.lua   —— inst._knockback / inst._strengthmult
--   prefabs/pillow_common.lua      —— DoKnockback：nopush 过滤 + 护具减伤 + PushEvent("knockback")
--   stategraphs/SGwilson.lua       —— 玩家 knockback 状态：speed = strengthmult * 12 * k
-- ============================================================
local PILLOW_KNOCKBACK           = {
  -- 击飞是独立开关，不再和"伤害是否为 0"绑死：有伤害也能击飞
  enabled = config.pillow_knockback == true,
  knockback = 0.16,     -- 击飞半径附加（写进 knockback 事件的 radius）
  strengthmult = 3.6,   -- 击飞力度（决定飞多远）
  push_fallback = true, -- 对没有 knockback 状态图的普通生物/ boss 补一次物理推力
}

-- 不可击退标签：官方 pillow_common 原本是 {"epic", "nopush"}，
-- 但 epic 覆盖了全部 31 个 boss（熊大/龙蝇/蜂后/克劳斯/远古犀牛…），全排掉就推不动 boss。
-- 源码里 nopush 目前没有任何 prefab 使用，属于官方预留位 —— 这里就只认它，
-- 也就是说：boss 照样能被拍飞，除非某个实体显式打了 nopush
local PILLOW_NOPUSH_TAGS         = { "nopush" }

-- ============================================================
-- 受击闪烁：被攻击命中的目标闪一下（含建筑、蜘蛛巢等没有击退的东西）
-- 颜色是客户端渲染属性，服务端设了不渲染，所以服务端广播 ClientModRPC，
-- 各客户端自己在本地闪。双端都要注册（服务端要 id 映射才能发，客户端要 handler 才能收）。
--
-- 视觉效果：**叠加发光色**（鬼魂作祟/冰冻用的那种 AddColour 叠加），红白急闪 6 拍
-- 不用 SetMultColour 是因为那是"乘算"，会把实体本色压掉（冰冻蓝、月圆白都会被打回白）；
-- 用 AddColour 是在原色上叠光，打完自动消失，不破坏任何原有底色
-- 有 colouradder 组件的实体走官方颜色栈（PushColour/PopColour），
-- 这样和冰冻、高亮等系统共存，不会互相顶掉
-- ============================================================
local FLICKER_STEP = 0.06                                   -- 每拍 0.06 秒，6 拍 ≈ 0.36 秒
local FLICKER_SWITCHES = 6
local FLICKER_RED = { 0.55, 0.04, 0.04 }                    -- 叠加红光
local FLICKER_WHITE = { 0.40, 0.40, 0.40 }                  -- 叠加白光（作祟那种泛白）

local function PushFlickerColour(inst, r, g, b)
  if inst.components ~= nil and inst.components.colouradder ~= nil then
    inst.components.colouradder:PushColour("hcane_flicker", r, g, b, 0)
  elseif inst.AnimState ~= nil then
    inst.AnimState:SetAddColour(r, g, b, 0)
  end
end

local function PopFlickerColour(inst)
  if inst == nil or not inst:IsValid() then
    return
  end
  if inst.components ~= nil and inst.components.colouradder ~= nil then
    inst.components.colouradder:PopColour("hcane_flicker")
  elseif inst.AnimState ~= nil then
    inst.AnimState:SetAddColour(0, 0, 0, 0)
  end
end

AddClientModRPCHandler("hcane", "hit_flicker", function(guid)
  local inst = Ents ~= nil and Ents[guid] or nil
  if inst == nil or not inst:IsValid() or inst.AnimState == nil then
    return
  end

  -- 同一目标连续受击时重置，避免多个 task 抢颜色
  if inst._hcane_flicker_task ~= nil then
    inst._hcane_flicker_task:Cancel()
    inst._hcane_flicker_task = nil
  end
  PopFlickerColour(inst) -- 清掉上一次可能残留的叠加色

  local step = 0
  local function Apply(k)
    local c = (k % 2 == 1) and FLICKER_RED or FLICKER_WHITE
    PushFlickerColour(inst, c[1], c[2], c[3])
  end

  Apply(1) -- 立刻先来一拍红的，别等第一个 tick
  step = 1

  local function Stop()
    PopFlickerColour(inst)
    if inst._hcane_flicker_task ~= nil then
      inst._hcane_flicker_task:Cancel()
      inst._hcane_flicker_task = nil
    end
  end

  inst._hcane_flicker_task = inst:DoPeriodicTask(FLICKER_STEP, function()
    if not inst:IsValid() or inst.AnimState == nil then
      Stop()
      return
    end
    step = step + 1
    if step > FLICKER_SWITCHES then
      Stop()
      return
    end
    Apply(step)
  end)
end)

-- 缓存 ClientModRPC 句柄（每次 GetClientModRPC 都会 initprint 打日志，别在攻击里反复调）
local _hit_flicker_rpc

-- 发一次受击闪烁（任何被命中的目标都能闪，不需要有 locomotor 或击退）
local function SendHitFlicker(target)
  if target == nil or not target:IsValid() then
    return
  end
  if _hit_flicker_rpc == nil then
    _hit_flicker_rpc = GetClientModRPC("hcane", "hit_flicker") or false
  end
  if _hit_flicker_rpc then
    SendModRPCToClient(_hit_flicker_rpc, nil, target.GUID)
  end
end

-- 官方 handpillow_common.DoKnockback 的通用版：
-- 不再局限于"兔人枕头大战"小游戏目标，对所有可攻击目标推送 knockback 事件
local function DoPillowKnockback(attacker, target)
  if attacker == nil or not attacker:IsValid() or target == nil or not target:IsValid() then
    return false
  end
  for _, tag in ipairs(PILLOW_NOPUSH_TAGS) do
    if target:HasTag(tag) then
      return false
    end
  end
  if target.components.health ~= nil and target.components.health:IsDead() then
    return false
  end

  -- 身体护具的击退抗性（官方 _defense_amount，只有枕头类身体护具才有值）
  local body_item = (target.components.inventory ~= nil and
        target.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)) or nil
  local defense = (body_item ~= nil and body_item._defense_amount) or 0
  local strengthmult = math.max(0.5, PILLOW_KNOCKBACK.strengthmult - defense)
  local radius = attacker:GetPhysicsRadius(0.5) + math.max(0.025, PILLOW_KNOCKBACK.knockback)

  -- 1. 官方标准 knockback 事件（玩家 / 鬼魂 / chester / 兔人 / 精英猪人等状态图自带处理）
  target:PushEvent("knockback", {
    knocker = attacker,
    radius = radius,
    strengthmult = strengthmult,
    forcelanded = (body_item ~= nil and body_item:HasTag("bodypillow")),
  })

  -- 2. 没有 knockback 状态图的目标（普通生物 + 绝大多数 boss）：
  --    官方的 knockback 状态图只有玩家/鬼魂/chester/兔人等几种，
  --    其余实体的 PushEvent 只会重置受击硬直，本体不动。
  --    物理通道的选择（三种都试过，结论如下）：
  --      · Physics:SetVel 设的是"实际速度"，而 loco 每帧用 SetMotorVel 设"目标速度"，
  --        物理引擎每步把实际速度拉回 motor vel → SetVel 一两帧就被吃掉，完全推不动
  --      · Physics:Teleport 每 0.05 秒一次要重建碰撞体+同步位置，目标一多就卡成 PPT
  --      · Physics:SetMotorVel 才是生物唯一有效的推力通道，但它是【实体局部坐标】，
  --        目标一转身方向就跟着变（warglet / shadow_rook 乱飘的根源）
  --    所以：每 tick 重新 SetRotation(远离角) 锁方向 + SetMotorVel，并在推挤期间
  --    反复 locomotor:Stop() 清掉它自己的移动目标，否则 brain 的追击指令会和推力抢通道
  if PILLOW_KNOCKBACK.push_fallback
      and not target:HasTag("player")
      and not target:HasTag("playerghost")
      and target.Physics ~= nil
      and target.components.locomotor ~= nil
      and (target.sg == nil or target.sg.states == nil or target.sg.states.knockback == nil)
      and target._hpillow_push_task == nil
  then
    -- 挂起 brain：0.3 秒内它没法下达新的移动/追击指令，等于强行走完整个击退
    -- StopBrain/RestartBrain 是引擎层的引用计数实现（entityscript.lua:1078/1091），
    -- 用独立 reason "hcane_pillow" 不会和其它系统（睡眠、冰冻等）互相干扰
    local brain_paused = false
    if target.brain ~= nil and target.StopBrain ~= nil then
      target:StopBrain("hcane_pillow")
      brain_paused = true
    end

    local tx, ty, tz = target.Transform:GetWorldPosition()
    local ax, _, az = attacker.Transform:GetWorldPosition()
    local dx, dz = tx - ax, tz - az
    local len = math.sqrt(dx * dx + dz * dz)
    if len < 0.05 then
      -- 完全重叠时退化：用攻击者朝向当远离方向。
      -- 官方角度约定下 rotation θ 对应的世界方向是 (cos θ, -sin θ)
      -- （见下方 GetAngleToPoint 推导），旧版写成 (sin, cos) 同样会把 Z 分量搞反。
      local arot = attacker.Transform:GetRotation() * math.pi / 180
      dx, dz, len = math.cos(arot), -math.sin(arot), 1
    end
    local ux, uz = dx / len, dz / len

    -- ⚠️ 远离方向对应的实体朝向，必须跟官方 GetAngleToPoint 用同一套角度约定。
    -- 官方 entityscript.lua:1398：GetAngleToPoint(px,pz) = atan2(z_self - pz, px - x_self)，
    -- 即"面朝世界方向 (dx,dz)"的 rotation = atan2(-dz, dx)。
    -- 这里 (ux,uz) 就是要面朝的远离方向，所以 rot = atan2(-uz, ux)。
    -- 旧版 atan2(uz, ux) 的 Z 分量符号相反：目标在 +Z 侧时会得到"面朝攻击者"的朝向，
    -- 大型生物（无 knockback 状态图、走这段 SetMotorVel fallback）就被往回推。
    local rot = math.atan2(-uz, ux) * 180 / math.pi
    -- 初速沿用 v5.6 已验证手感（strengthmult * 8.4，3.6 → 30），0.3 秒线性降到 0
    local speed = strengthmult * 8.4
    local steps = 6
    local decel = speed / steps
    local step = 0

    local function PushOnce(t, v)
      if t.Physics == nil or not t:IsValid() then
        return
      end
      if t.components.locomotor ~= nil then
        t.components.locomotor:Stop() -- 清掉它自己的移动目标，别和推力抢物理通道
      end
      t.Transform:SetRotation(rot) -- 锁死朝向，保证 motor vel 的局部 +x 始终是远离方向
      t.Physics:SetMotorVel(v, 0, 0)
    end

    PushOnce(target, speed)

    target._hpillow_push_task = target:DoPeriodicTask(0.05, function(t)
      if not t:IsValid() then
        return -- 实体已消失，task 会随实体自动清理
      end
      step = step + 1
      if step >= steps then
        if t._hpillow_push_task ~= nil then
          t._hpillow_push_task:Cancel()
          t._hpillow_push_task = nil
        end
        if t.Physics ~= nil then
          t.Physics:Stop() -- 收尾清掉 motor vel，否则会一直保持这个速度滑下去
        end
        -- 恢复 brain，让它重新决策（被击退后重新找目标）
        if brain_paused and t:IsValid() and t.RestartBrain ~= nil then
          t:RestartBrain("hcane_pillow")
        end
        return
      end
      local v = speed - decel * step
      if v < 0 then
        v = 0
      end
      PushOnce(t, v)
    end)
  end

  return true
end

-- 玩家当前打开着的口袋空间容器（格子优化的月眼空间）
-- 官方 world 自带注册表：prefabs/world.lua 的 `PocketDimensionContainers[name]` 表 +
-- GetPocketDimensionContainer(name)。直接遍历这张表即可，不用脚本名/标签，
-- 也不用 TheSim:FindEntities 全场扫（那样每捡一次东西都要遍历几千实体，会掉帧）
-- 有多个打开时，优先返回"里面已经有同类物品"的那个，让自动拾取物以类聚
local function GetOpenPocketContainer(doer, prefab)
  local pocket_containers = TheWorld ~= nil and TheWorld.PocketDimensionContainers
  if pocket_containers == nil then
    return nil
  end

  local fallback
  for _, inst in pairs(pocket_containers) do
    if inst ~= nil and inst:IsValid() and inst.components.container ~= nil then
      local container = inst.components.container
      if container:IsOpenedBy(doer) then
        if prefab ~= nil and container:Has(prefab, 1) then
          return container -- 这个空间里已经有同类物品，优先塞这里
        end
        fallback = fallback or container
      end
    end
  end
  return fallback
end

-- 把一件物品投递给玩家：先投进玩家打开的口袋空间（同类优先），其次才进背包
-- 返回 true 表示投递成功（无论进了空间还是背包）
local function GiveItemToPlayer(doer, item, src_pos)
  if doer == nil or item == nil or not item:IsValid() then
    return false
  end
  if doer.components.inventory == nil then
    return false
  end

  local pocket = GetOpenPocketContainer(doer, item.prefab)
  if pocket ~= nil and pocket:CanAcceptCount(item, 1) > 0 then
    if pocket:GiveItem(item, nil, src_pos) ~= nil then
      return true
    end
  end

  if doer.components.inventory:CanAcceptCount(item, 1) > 0 then
    doer.components.inventory:GiveItem(item, nil, src_pos)
    return true
  end
  return false
end

-- 临时接管玩家的 inventory:GiveItem，让"组件内部直接塞背包"的产出（如 pickable:Pick）
-- 也能先落进打开的口袋空间。fn 必须是同步执行的，跑完立刻还原（用 pcall 兜底）。
local function RunWithPocketRedirect(doer, fn)
  if doer == nil or doer.components.inventory == nil or GetOpenPocketContainer(doer, nil) == nil then
    -- 没有打开的口袋空间，完全走原逻辑，零开销
    fn()
    return
  end

  local inv = doer.components.inventory
  local old_give = inv.GiveItem
  inv.GiveItem = function(self, item, slot, src_pos, drop_on_fail, ...)
    if item ~= nil and item:IsValid() then
      local pocket = GetOpenPocketContainer(doer, item.prefab)
      if pocket ~= nil and pocket:CanAcceptCount(item, 1) > 0 then
        local placed = pocket:GiveItem(item, nil, src_pos)
        if placed ~= nil then
          return placed
        end
      end
    end
    return old_give(self, item, slot, src_pos, drop_on_fail, ...)
  end

  local ok, err = pcall(fn)
  inv.GiveItem = old_give
  if not ok then
    print("[hcane] 口袋空间转发失败:", err)
  end
end

-- 实体/特效引用
PrefabFiles                      = {
  "hehu_light",
  "cane_hh_fx",
  "cane_shadow_fx",
}

-- 注册动画资源（放在 modmain.lua 开头）
Assets                           = {
  -- 加载自定义UI动画包
  -- Asset("ANIM", "anim/ui_antlionhat_1x1.zip"),
  Asset("IMAGE", "images/inventoryimages/xin.tex"),
  Asset("ATLAS", "images/inventoryimages/xin.xml"),
  Asset("IMAGE", "images/inventoryimages/heh.tex"),
  Asset("ATLAS", "images/inventoryimages/heh.xml"),
  -- Asset("SHADER", "shaders/myshader.ksh")
}

-- 勋章面板兼容：消耗状态名称（能力勋章 1909182187）
STRINGS.NAMES.HCANE_WATER_HUNGER = "H-手杖踏水消耗"
STRINGS.NAMES.HCANE_RED_GEM      = "H-手杖红宝石消耗"
STRINGS.NAMES.HCANE_BLUE_GEM     = "H-手杖蓝宝石消耗"
STRINGS.NAMES.HCANE_ORANGE_GEM   = "H-手杖橙宝石消耗"
STRINGS.NAMES.HCANE_YELLOW_GEM   = "H-手杖黄宝石消耗"
STRINGS.NAMES.HCANE_PURPLE_GEM   = "H-手杖紫宝石消耗"
STRINGS.NAMES.HCANE_GREEN_GEM    = "H-手杖绿宝石消耗"
STRINGS.NAMES.HCANE_OPAL_GEM     = "H-手杖彩虹宝石消耗"
STRINGS.NAMES.HCANE_CELESTIAL    = "H-手杖天体珠宝消耗"
STRINGS.NAMES.HCANE_BEARGER      = "H-手杖熊大消耗"
STRINGS.NAMES.HCANE_ANTLION      = "H-手杖蚁狮坑消耗"
STRINGS.NAMES.HCANE_GLOMMER      = "H-手杖催熟消耗"

-- 修改步行手杖属性
AddPrefabPostInit("cane", function(inst)
  -- ⭐ 5.6.26：每把手杖独立记忆「激活宝石 + 总开关」——netvar 挂在 cane 自身。
  --    两端都要建（客户端只读）；解锁仍按 userid 玩家级共享，不动。
  --    ⚠️ 必须放在 ismastersim 提前 return 之前，否则客户端没有 netvar → value() 崩。
  if GEM_ENABLED then
    -- ⚠️ 不能复用 inst._hcane_active_gem（那是服务端普通字符串字段，能力逻辑读它）；
    --    独立的 netvar 名字，避免把字符串字段覆盖成 netvar 对象。
    inst._hcane_gem_net = GLOBAL.net_string(inst.GUID, "_hcane_gem_net", "hcaneCaneGemDirty")
    inst._hcane_multi_net = GLOBAL.net_bool(inst.GUID, "_hcane_multi_net", "hcaneCaneMultiDirty")
    inst._hcane_unlock_net = GLOBAL.net_string(inst.GUID, "_hcane_unlock_net", "hcaneCaneUnlockDirty")
  end

  -- 注意：这里**不加 `pillow` 标签**。
  -- 加了会让 SGwilson 的 ActionHandler 把攻击切成 attack_pillow_pre（0.16 秒前摇），
  -- 现在击飞不需要前摇，攻击走标准 attack 状态，和普通武器一样的攻速
  -- 以下只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end

  -- 把手杖自身状态推到 netvar（服务端写）。所有改状态入口都走这里，
  -- 保证物品栏手杖/装备手杖各自的 UI 显示与自身状态一致。
  if GEM_ENABLED then
    inst.hcane_sync_gem_net = function()
      if inst._hcane_gem_net ~= nil then
        inst._hcane_gem_net:set(inst._hcane_active_gem or "")
      end
      if inst._hcane_multi_net ~= nil then
        inst._hcane_multi_net:set(inst.all_active == true)
      end
      if inst._hcane_unlock_net ~= nil then
        inst._hcane_unlock_net:set(UnlockedTableToString(inst.hcane_unlocked))
      end
    end
  end

  -- ===== 六色宝石能力（绿/黄/紫 spellcaster、橙 blinkstaff、红/蓝 onattack）=====
  -- 与扫描 15 格完全独立：组件常驻，按手杖自身 _hcane_active_gem 切换。
  if GEM_ENABLED then
    if inst.components.spellcaster == nil then
      inst:AddComponent("spellcaster")
    end
    inst.components.spellcaster:SetSpellFn(HcaneDestroyStructure)
    -- 官方绿杖同款（staff_common.lua:780-783）：拆解 itemmimic 伪装的建筑时强制先揭示
    if not inst.components.itemmimicconfig then
      inst:AddComponent("itemmimicconfig")
    end
    inst.components.itemmimicconfig:AddActionForceMimicReveal(ACTIONS.CASTSPELL)
    -- ⭐ 5.6.26：状态按手杖独立——owner 变化时只重算能力，不再从玩家级字段覆盖
    --    （旧逻辑 owner._hcane_active_gem 已废弃，会把手杖自己的记忆冲掉）。
    local function refreshGemSpell(_, data)
      ApplyGemAbility(inst)
      if inst.hcane_sync_gem_net then inst.hcane_sync_gem_net() end
      -- ⭐ 5.6.26：装备/拾取切换手杖时，把新手杖状态推到玩家级镜像，
      --    全局轮盘的解锁/宝石/开关显示跟着切换到这把手杖。
      local owner = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner() or nil
      if owner ~= nil and owner:HasTag("player") then
        SyncGemStateToClient(owner)
        -- 5.6.29：装备切换瞬间 owner/归属可能还没稳定，0.1s 后补推一次，
        --    避免镜像推成旧手杖/空解锁导致轮盘整圈全黑。
        inst:DoTaskInTime(0.1, function()
          if not inst:IsValid() then return end
          local o = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner() or nil
          if o ~= nil and o:IsValid() and o:HasTag("player") then
            SyncGemStateToClient(o)
          end
        end)
      end
    end
    inst:ListenForEvent("equipped", refreshGemSpell)
    inst:ListenForEvent("unequipped", refreshGemSpell)
    inst:ListenForEvent("onputininventory", refreshGemSpell)
    inst:ListenForEvent("ondropped", refreshGemSpell)
    inst:DoTaskInTime(0, refreshGemSpell)
  end

  -- 基础配置项
  -- 处理装备组件逻辑（移速加成）
  if inst.components.equippable then
    inst.components.equippable.walkspeedmult = 1 + config.speed_buff
  end

  -- 发光功能实现
  if config.hcane_light > 0 then
    -- 发光判断
    local function setLight(inst)
      local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil

      if owner ~= nil then
        if inst._light ~= nil and inst._light:IsValid() then
          inst._light.entity:SetParent(owner.entity)
          if inst.components.equippable ~= nil and inst.components.equippable:IsEquipped() then
            if TheWorld ~= nil and TheWorld.state ~= nil and TheWorld.state.isnight then
              inst._light.Light:Enable(true)
            else
              inst._light.Light:Enable(false)
            end
          else
            inst._light.Light:Enable(false)
          end
        end
      else
        if inst._light ~= nil and inst._light:IsValid() then
          inst._light.entity:SetParent(inst.entity)
          inst._light.Light:Enable(config.hcane_light > 0 or true)
        end
      end
    end
    local function onRemove(inst)
      if inst._light ~= nil then
        if inst._light:IsValid() then
          inst._light:Remove()
        end
        inst._light = nil
      end
    end
    -- 使用发光特效的方案
    inst._light = SpawnPrefab('hehu_light')
    if inst._light then
      inst._light.entity:SetParent(inst.entity)
      inst._light.entity:AddFollower()
      inst:ListenForEvent("onputininventory", setLight)
      inst:ListenForEvent("ondropped", setLight)
      inst:ListenForEvent("equipped", setLight)
      inst:ListenForEvent("unequipped", setLight)
      inst:WatchWorldState("isnight", function(ent, isnight) setLight(ent) end)
      inst:ListenForEvent("onremove", onRemove)
      setLight(inst)
    else
      print("警告：光效预制体创建失败！")
    end
  end

  -- 处理作祟复活逻辑（根据开关决定是否启用）
  if config.haunt_resurrect then
    -- 添加可被作祟组件（如果不存在）
    if not inst.components.hauntable then
      inst:AddComponent("hauntable")
      inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)
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
        local fx = SpawnPrefab("statue_transition_2")
        if fx then
          fx.Transform:SetPosition(x, y, z)
          fx.Transform:SetScale(0.8, 0.8, 0.8)
        end
        -- 作祟复活后恢复三维（饥饿、血量、理智）到满值（百分比回复）
        -- 使用2.5秒延迟确保复活动画完全结束后才恢复，避免被动画覆盖
        inst:DoTaskInTime(2.5, function()
          if haunter and haunter:IsValid() and not haunter:HasTag("playerghost") then
            if haunter.components.health ~= nil and not haunter.components.health:IsDead() then
              haunter.components.health:SetPercent(1)
            end
            if haunter.components.hunger ~= nil then
              haunter.components.hunger:SetPercent(1)
            end
            if haunter.components.sanity ~= nil then
              haunter.components.sanity:SetPercent(1)
            end
          end
        end)
        return true -- 表示作祟成功
      end
      return false  -- 非玩家鬼魂作祟不处理
    end)
  end

  -- 伤害配置项
  -- 处理武器组件逻辑
  if inst.components.weapon then
    -- 基础伤害设置
    inst.components.weapon:SetDamage(config.damage)
    -- 确保位面伤害组件存在
    inst:AddComponent("planardamage"):SetBaseDamage(config.planardamage)
    -- 攻击范围：完全跟随"远程攻击范围"配置项
    if config.range_attack > 0 then
      inst.components.weapon:SetRange(config.range_attack, config.range_attack + 1)
    elseif PILLOW_KNOCKBACK.enabled then
      -- 远程攻击设为 0（近战）时，击打距离放宽到 2.5（官方 PILLOW_HIT_RANGE，比手杖默认的 2 好打中）
      inst.components.weapon:SetRange(TUNING.DEFAULT_ATTACK_RANGE, TUNING.PILLOW_HIT_RANGE)
    end
    -- 初始化实体的伤害倍率存储（首次使用时赋值，避免nil）
    if not inst._damage_mult then
      inst._damage_mult = 1 -- 基础伤害原始倍率
    end
    if not inst._planardamage_mult then
      inst._planardamage_mult = 1 -- 位面伤害原始倍率
    end
    -- 重置额外伤害函数（直接判断配置开关）
    local function ResetExtraDamage()
      inst.extra_damage = 0
      inst.combat_timer = nil
      -- 恢复基础伤害
      inst.components.weapon:SetDamage(config.damage * inst._damage_mult)
      inst.components.planardamage:SetBaseDamage(config.planardamage * inst._planardamage_mult)
    end

    -- 伤害转换逻辑封装（复用函数）
    local function ApplyDamageConversions(attacker, damage)
      -- 生命转换
      if config.life_drain_ratio > 0 and attacker.components.health then
        if attacker.components.oldager then
          attacker.components.oldager:StopDamageOverTime()
        end
        attacker.components.health:DoDelta(damage * config.life_drain_ratio, false, inst.prefab)
      end
      -- 饥饿转换
      if config.hunger_conversion_ratio > 0 and attacker.components.hunger then
        attacker.components.hunger:DoDelta(damage * config.hunger_conversion_ratio, false, inst.prefab)
      end
      -- 理智转换
      if config.sanity_conversion_ratio > 0 and attacker.components.sanity then
        attacker.components.sanity:DoDelta(damage * config.sanity_conversion_ratio, false, inst.prefab)
      end
    end

    -- 攻击逻辑处理
    inst.components.weapon.onattack = function(inst, attacker, target)
      -- 临时增益伤害计算
      local base_damage = config.damage * inst._damage_mult
      local base_planardamage = config.planardamage * inst._planardamage_mult
      -- 升级增益计算（未设置）
      local final_base_damage = base_damage
      local final_base_planardamage = base_planardamage

      inst.singlefight_target = target or false

      -- 越攻击越强 核心逻辑（简化版）
      -- 击飞现在是独立开关，和伤害互不干扰：开着击飞也能叠伤害
      if config.extra_damage then
        -- 初始化累加变量（首次触发时）
        inst.extra_damage = inst.extra_damage or 0
        inst.max_extra_damage = 1666

        -- 刷新16秒重置计时器
        if inst.combat_timer ~= nil then
          inst.combat_timer:Cancel()
        end
        inst.combat_timer = inst:DoTaskInTime(16, ResetExtraDamage)

        -- 随机累加1-6点伤害，限制上限1666
        if math.random() < 0.16 then
          local add_damage = math.random(1, 6)
          inst.extra_damage = math.min(inst.extra_damage + add_damage, inst.max_extra_damage)
        end

        -- 叠加额外伤害并更新武器伤害
        final_base_damage = base_damage + inst.extra_damage
        final_base_planardamage = base_planardamage + inst.extra_damage
        inst.components.weapon:SetDamage(final_base_damage)
        if not inst.components.planardamage then
          inst:AddComponent("planardamage")
        end
        inst.components.planardamage:SetBaseDamage(final_base_planardamage)
      end

      -- 2. 主目标伤害转换
      ApplyDamageConversions(attacker, final_base_damage)
      if config.planardamage > 0 then
        ApplyDamageConversions(attacker, final_base_planardamage)
      end

      -- 3. 群攻逻辑（当比例>0时启用）
      if config.aoe_damage_ratio > 0 then
        local exclude_tags = { "INLIMBO", "companion", "wall", "abigail", "shadowminion" }
        local x, y, z = target.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, 6, { "_combat" }, exclude_tags)

        for _, ent in ipairs(ents) do
          -- 过滤有效目标
          if ent ~= target
              and ent ~= attacker
              and ent.prefab == target.prefab
              and attacker.components.combat:IsValidTarget(ent)
              and (not attacker.components.leader or not attacker.components.leader:IsFollower(ent)) then
            -- 计算群攻伤害（基于最终基础伤害）
            local aoe_damage = final_base_damage * config.aoe_damage_ratio
            -- 计算群攻位面伤害（按相同比例计算）
            local aoe_planar_damage = config.planardamage * config.aoe_damage_ratio

            -- 应用群攻伤害
            attacker:PushEvent("onareaattackother", { target = ent, weapon = inst, stimuli = nil })
            ent.components.combat:GetAttacked(attacker, aoe_damage, inst, nil)
            -- 额外应用位面伤害
            if aoe_planar_damage > 0 and ent.components.health then
              ent.components.health:DoDelta(-aoe_planar_damage, false, "planar", nil, attacker)
            end

            -- 群攻目标的伤害转换
            ApplyDamageConversions(attacker, aoe_damage)
            if aoe_planar_damage > 0 then
              ApplyDamageConversions(attacker, aoe_planar_damage)
            end

            -- 群攻目标也带火焰/冰冻效果（标志已由 active_gem 法杖状态驱动，群攻只此一份）
            if inst._has_redgem then
              if ent.components.burnable and not ent.components.burnable:IsBurning() then
                if ent.components.burnable.canlight or ent.components.combat ~= nil then
                  ent.components.burnable:Ignite(true, attacker)
                end
              end
            end
            if inst._has_bluegem then
              if ent.components.freezable and not ent.components.freezable:IsFrozen() then
                -- ⭐ 5.6.32：与主目标一致 AddColdness(冷度16, 冻结16秒)，强于 icestaff3
                ent.components.freezable:AddColdness(16, 16)
                ent.components.freezable:SpawnShatterFX()
              end
            end

            -- 群攻目标一起被拍飞（掌掴模式下，像熊大拍地那样一片全飞）
            if PILLOW_KNOCKBACK.enabled then
              DoPillowKnockback(attacker, ent)
            end
            -- 群攻目标也闪一下
            if config.hit_flicker then
              SendHitFlicker(ent)
            end
          end
        end
      end

      -- 4. 红/蓝法杖·主目标点燃/冰冻——官方完整版（内部按 active_gem 判定，含点燃物品/fueled/解冻/唤醒）
      --    ⚠️ 不再保留扫描15格的简化点燃分支：两套并存会重复播放音效、重复 AddColdness(16,16)。
      HcaneFireIgniteOnAttack(inst, attacker, target)
      HcaneIceFreezeOnAttack(inst, attacker, target)
      -- 紫法杖：仿 book_brimstone 在目标周围召唤闪电（内部判 active_gem + 1.5s 冷却）
      HcanePurpleLightningOnAttack(inst, attacker, target)

      -- 5. 掌掴击退（伤害与位面伤害都为 0 时的核心效果，仿 handpillow_steelwool）
      --    注意：这不是"另一种状态"，攻击本身照常完整执行（受击动画/仇恨/伤害结算），
      --    伤害为 0 只是伤害数值是 0，击退是攻击命中后附加的位移
      if PILLOW_KNOCKBACK.enabled then
        DoPillowKnockback(attacker, target)
      end

      -- 6. 受击闪烁：只要命中就闪，和伤害无关、也不需要目标能被击退
      --    （蜘蛛巢、建筑、有伤害的攻击都会走这里）
      if config.hit_flicker then
        SendHitFlicker(target)
      end
    end
  end

  -- 工具配置项
  inst.persists = true
  -- 总开关（默认关闭）
  inst.all_active = false
  inst.light_fx = nil

  -- 同步高亮标签到客户端；同时把总开关状态推给轮盘 UI
  -- （右键 / UI 两种入口都走这里，状态永远一致）
  local function SyncCaneState()
    if inst.all_active then
      inst:AddTag("caneon")
    else
      inst:RemoveTag("caneon")
    end
    local owner = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner() or nil
    if owner ~= nil and owner:HasTag("player") then
      SyncMultiStateToClient(owner, nil, inst)  -- 传 inst 绕过查找，拿刚改过的 all_active
    end
  end

  -- 多工具组件管理
  -- 加多工具组件
  local function AddToolComponents()
    if not config.tool_enable then return end
    if not inst.components.tool then
      -- 工具组件
      inst:AddComponent("tool")
      -- 砍树
      inst.components.tool:SetAction(ACTIONS.CHOP, config.tool_efficiency)
      -- 采矿
      inst.components.tool:SetAction(ACTIONS.MINE, config.tool_efficiency)
      -- 强力开采
      inst.components.tool:EnableToughWork(true)
      -- 锤你
      if config.enable_hammer_action then
        inst.components.tool:SetAction(ACTIONS.HAMMER, config.tool_efficiency)
      end
      -- 挖掘
      if config.enable_dig_action then
        inst.components.tool:SetAction(ACTIONS.DIG, config.tool_efficiency)
      end
      -- 捕虫网
      inst.components.tool:SetAction(ACTIONS.NET, config.tool_efficiency)

      -- 添加镰刀功能
      if config.enable_scythe then
        -- 整合并简化镰刀收割功能（圆形范围收割）
        local function DoScythe(inst, target, doer)
          -- 定义收割范围和标签过滤
          local HARVEST_RANGE = 6.6
          local HARVEST_MUSTTAGS = { "pickable" }
          local HARVEST_CANTTAGS = { "INLIMBO", "FX" }
          local HARVEST_ONEOFTAGS = { "plant", "lichen", "oceanvine", "kelp" }

          -- 获取玩家位置并查找范围内实体
          local x, y, z = doer:GetPosition():Get()
          local ents = TheSim:FindEntities(x, y, z, HARVEST_RANGE,
            HARVEST_MUSTTAGS, HARVEST_CANTTAGS, HARVEST_ONEOFTAGS)

          -- 遍历实体并收割
          for _, ent in pairs(ents) do
            if ent:IsValid() and ent.components.pickable then
              -- 播放收割音效
              if ent.components.pickable.picksound then
                doer.SoundEmitter:PlaySound(ent.components.pickable.picksound)
              end

              -- 执行采摘并处理掉落物
              local success, loot = ent.components.pickable:Pick(TheWorld)
              if loot then
                for _, item in ipairs(loot) do
                  Launch(item, doer, 1.5) -- 物品向玩家方向弹出
                end
              end
            end
          end
        end
        inst.components.tool:SetAction(ACTIONS.SCYTHE)
        inst.DoScythe = DoScythe
      end
    end
  end
  -- 关多工具组件
  local function RemoveToolComponents()
    if inst.components.tool then
      inst:RemoveComponent("tool")
    end
  end
  -- 多工具功能状态更新函数
  local function UpdateToolState()
    if config.tool_enable and inst.all_active then
      AddToolComponents()
    else
      RemoveToolComponents()
    end
  end

  -- 不随右键关闭的功能（但纯被动模式下全部关闭，只留加速+攻击）
  -- 刷子
  if config.enable_brush and not passive_only and not inst.components.brush then
    inst:AddComponent("brush")
  end
  -- 剃刀
  if config.enable_razor and not passive_only and not inst.components.shaver then
    inst:AddComponent("shaver")
  end
  -- 锄头功能（通过 AddInherentAction + farmtiller 组件实现，区别于传统 tool 系统）
  if config.enable_hoe and not passive_only then
    if not inst.components.farmtiller then
      inst:AddComponent("farmtiller")
    end
    inst:AddInherentAction(ACTIONS.TILL)
  end
  -- 淡水钓鱼竿
  if config.enable_fishingrod and not passive_only and not inst.components.fishingrod then
    inst:AddComponent("fishingrod")
    inst.components.fishingrod:SetWaitTimes(1, 1.6)
    inst.components.fishingrod:SetStrainTimes(0, 160)
  end
  -- 水壶浇水
  if config.enable_watering and not passive_only and not inst.components.wateryprotection then
    inst:AddComponent("wateryprotection")
    inst:AddTag("wateringcan")
    inst.components.wateryprotection.addwetness = 160
    inst.components.wateryprotection.temperaturereduction = 66
    inst.components.wateryprotection:AddIgnoreTag("player")
  end
  -- 划桨
  if config.enable_paddling and not passive_only and not inst.components.oar then
    inst:AddComponent("oar")
    inst:AddTag("allow_action_on_impassable")
    inst.components.oar.force = 1
    inst.components.oar.max_velocity = 16
  end
  -- 添加 区域温度 组件(暂未添加，而且需要主客机同时才行)
  if false then
    inst:AddComponent("temperatureoverrider")
    inst.components.temperatureoverrider:SetTemperature(46)
    inst.components.temperatureoverrider:SetRadius(config.auto_work_range)
    inst.components.temperatureoverrider:Enable()
  end


  -- 自动采摘逻辑
  local auto_harvest_task = nil
  local AUTO_HARVEST_INTERVAL = 0.6
  local function DoAreaHarvest(inst)
    local doer = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
    if not doer or not doer:HasTag("player") then return end

    local x, y, z = doer.Transform:GetWorldPosition()
    local WORK_RADIUS = config.auto_work_range
    if WORK_RADIUS <= 0 then return end

    local ents = TheSim:FindEntities(x, y, z, WORK_RADIUS,
      { "pickable" },
      { "INLIMBO", "FX", "NOCLICK", "burnt", "flower", "dead", "thorny" }, -- 排除标签
      { "plant", "crop", "lichen", "oceanvine", "kelp" }                   -- 必须包含标签
    )
    -- pickable:Pick 内部是直接 inventory:GiveItem 把产出塞背包的，没法在外面拦，
    -- 所以整批用一次"临时接管 GiveItem"，让产物优先落进玩家打开的口袋空间
    RunWithPocketRedirect(doer, function()
      for _, ent in ipairs(ents) do
        -- 普通采摘逻辑
        if ent:IsValid() and ent.components.pickable and ent.components.pickable:CanBePicked() and not ent.components.pickable:IsBarren() then
          -- 执行采摘
          doer.SoundEmitter:PlaySound(ent.components.pickable.picksound or "dontstarve/wilson/pickup_plants")
          ent.components.pickable:Pick(doer)
          -- 在植物位置生成沙子特效
          -- SpawnPrefab("sand_puff").Transform:SetPosition(ent.Transform:GetWorldPosition())
        end
      end
    end)
  end
  -- 自动采摘状态更新函数
  local function UpdateAutoHarvest()
    local should_run = config.auto_work_range > 0
        and inst.all_active
        and inst.components.equippable
        and inst.components.equippable:IsEquipped()

    if should_run and not auto_harvest_task then
      auto_harvest_task = inst:DoPeriodicTask(AUTO_HARVEST_INTERVAL, DoAreaHarvest)
    elseif not should_run and auto_harvest_task then
      auto_harvest_task:Cancel()
      auto_harvest_task = nil
    end
  end

  -- 自动耕地逻辑
  -- 九宫格偏移坐标
  local MAP_3x3 = {
    { -4 / 3, -4 / 3 }, { 0, -4 / 3 }, { 4 / 3, -4 / 3 },
    { -4 / 3, 0 }, { 0, 0 }, { 4 / 3, 0 },
    { -4 / 3, 4 / 3 }, { 0, 4 / 3 }, { 4 / 3, 4 / 3 }
  }

  -- 自动耕地相关配置与变量
  local AUTO_FARM_INTERVAL = 0.6 -- 自动耕地检测间隔（可根据需求调整）
  local auto_farm_task = nil     -- 自动耕地定时任务句柄

  -- 自动耕地核心执行函数
  local function DoAreaFarm()
    -- 获取物品所有者（玩家）
    local doer = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
    if not doer or not doer:HasTag("player") then
      return -- 非玩家持有则退出
    end

    -- 获取玩家位置和配置的耕地范围
    local x, y, z = doer.Transform:GetWorldPosition()
    local AUTO_FARM_RANGE = config.auto_farm_range or 1
    local center_tile_x, center_tile_z = TheWorld.Map:GetTileCoordsAtPoint(x, y, z)
    if AUTO_FARM_RANGE <= 0 then
      return -- 范围无效则退出
    end

    -- 遍历以玩家为中心的周围格子
    for dx = -AUTO_FARM_RANGE, AUTO_FARM_RANGE do
      for dz = -AUTO_FARM_RANGE, AUTO_FARM_RANGE do
        local tile_x = center_tile_x + dx
        local tile_z = center_tile_z + dz

        -- 获取当前格子的中心世界坐标
        local cx, _, cz = TheWorld.Map:GetTileCenterPoint(tile_x, tile_z)

        -- 坍塌当前地块上的旧土壤
        local tile_ents = TheWorld.Map:GetEntitiesOnTileAtPoint(cx, 0, cz)
        for _, tile_ent in ipairs(tile_ents) do
          if tile_ent ~= inst and tile_ent:HasTag("soil") then
            tile_ent:PushEvent("collapsesoil")
          end
        end

        -- 在地块中心执行3x3耕地
        for _, v in pairs(MAP_3x3) do
          local nx = v[1] + cx
          local nz = v[2] + cz
          if TheWorld.Map:CanTillSoilAtPoint(nx, 0, nz, false) then
            TheWorld.Map:CollapseSoilAtPoint(nx, 0, nz)
            SpawnPrefab("farm_soil").Transform:SetPosition(nx, 0, nz)
          end
        end
        -- 触发耕地音效/动画
        doer:PushEvent("tilling")
      end
    end
  end

  -- 自动耕地状态更新函数（独立任务：只由 auto_farm_range + 装备状态控制，不受右键总开关）
  local function UpdateAutoFarm()
    local should_run = config.auto_farm_range > 0
        and inst.components.equippable
        and inst.components.equippable:IsEquipped()

    -- 任务启停控制
    if should_run and not auto_farm_task then
      -- 启动定时任务（立即执行一次，之后按间隔循环）
      auto_farm_task = inst:DoPeriodicTask(AUTO_FARM_INTERVAL, DoAreaFarm, 0.16)
    elseif not should_run and auto_farm_task then
      -- 停止并清理任务
      auto_farm_task:Cancel()
      auto_farm_task = nil
    end
  end

  -- 呼吸灯效果更新函数（由 enable_light_fx 控制）
  local function UpdateLightFX()
    -- 此函数已废弃，呼吸灯效果由 UpdateCaneTint() 处理
    -- 保留空函数避免调用报错
  end

  -- 粒子特效更新函数（由 fx_particle_type 多选项控制）
  local PARTICLE_PREFABS = {
    sparkle = "cane_hh_fx",
    shadow = "cane_shadow_fx",
  }

  local function GetParticlePrefabName()
    return PARTICLE_PREFABS[config.fx_particle_type] or "cane_hh_fx"
  end

  local function UpdateParticleFX()
    if inst.all_active and config.fx_particle_type ~= "none" then
      local prefab_name = GetParticlePrefabName()
      if not inst.light_fx or not inst.light_fx:IsValid() or inst.light_fx.prefab ~= prefab_name then
        -- 移除旧粒子
        if inst.light_fx then
          inst.light_fx:Remove()
          inst.light_fx = nil
        end
        -- 生成新粒子
        inst.light_fx = SpawnPrefab(prefab_name)
        if inst.light_fx then
          inst.light_fx.entity:SetParent(inst.entity)
        end
      end
    else
      if inst.light_fx then
        inst.light_fx:Remove()
        inst.light_fx = nil
      end
    end
  end

  -- 手杖呼吸染色效果（跑马灯版）
  local BREATH_SPEED = 1.2      -- 呼吸周期（秒，越小呼吸越快）
  local BREATH_INTENSITY = 0.6  -- 呼吸强度（0~0.5，越大颜色越鲜艳）
  local COLOR_CYCLE_SPEED = 1.6 -- 颜色跑马灯周期（秒，越小颜色变化越快）
  local cane_tint_task = nil    -- 呼吸定时器
  local cane_tint_time = 0      -- 呼吸计时器

  local function HueToRGB(hue)
    local r = (math.sin(hue) + 1) / 2
    local g = (math.sin(hue + 2.094) + 1) / 2
    local b = (math.sin(hue + 4.189) + 1) / 2
    return r, g, b
  end

  local function StopCaneBreathTint()
    if cane_tint_task then
      cane_tint_task:Cancel()
      cane_tint_task = nil
    end
    cane_tint_time = 0
    -- 清除实体染色
    if inst.AnimState then
      inst.AnimState:SetAddColour(0, 0, 0, 0)
      inst.AnimState:SetHaunted(false)
    end
    -- 清除玩家装备染色
    local owner_t = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()
    if owner_t and owner_t:HasTag("player") and owner_t.AnimState then
      owner_t.AnimState:SetSymbolMultColour("swap_object", 1, 1, 1, 1)
      owner_t.AnimState:SetSymbolAddColour("swap_object", 0, 0, 0, 0)
      -- 清除玩家全身跑马灯
      if owner_t.AnimState then
        owner_t.AnimState:SetAddColour(0, 0, 0, 0)
      end
      owner_t.AnimState:SetHaunted(false)
    end
  end

  local function StartCaneBreathTint()
    StopCaneBreathTint()
    cane_tint_time = 0
    if inst.AnimState then
      inst.AnimState:SetHaunted(true)
    end
    cane_tint_task = inst:DoPeriodicTask(0.05, function() -- 每0.05秒更新一次，让呼吸平滑
      cane_tint_time = cane_tint_time + 0.05

      -- 呼吸强度：0 → 1 → 0 平滑变化
      local phase = (math.sin(cane_tint_time * 2 * math.pi / BREATH_SPEED) + 1) / 2
      local intensity = phase * BREATH_INTENSITY

      -- 跑马灯色相：随时间循环
      local hue = cane_tint_time * 2 * math.pi / COLOR_CYCLE_SPEED
      local cr, cg, cb = HueToRGB(hue)

      -- 1. 手杖实体染色（地上/背包里）→ 彩色发光呼吸
      if inst.AnimState then
        inst.AnimState:SetAddColour(cr * intensity, cg * intensity, cb * intensity, 0)
      end

      -- 2. 玩家手持染色（装备栏 swap_object 符号）
      local owner_t2 = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()
      if owner_t2 and owner_t2:HasTag("player") and owner_t2.AnimState then
        -- MultColour：模型本身轻微偏色（1-intensity*0.2 到 1 之间变化，按当前色相偏转）
        local cm = 1 - intensity * 0.25
        local mr = 1 - (1 - cr) * intensity * 0.25
        local mg = 1 - (1 - cg) * intensity * 0.25
        local mb = 1 - (1 - cb) * intensity * 0.25
        owner_t2.AnimState:SetSymbolMultColour("swap_object", mr, mg, mb, 1)

        -- AddColour：彩色发光叠加层
        local glow_intensity = intensity * 0.8
        if cr + cg + cb > 0.01 then
          owner_t2.AnimState:SetSymbolAddColour("swap_object", cr * glow_intensity, cg * glow_intensity,
            cb * glow_intensity, 0)
        end

        -- 3. 玩家全身跑马灯——仅在手持装备时才显示，物品栏/丢地时清除
        local is_equipped = owner_t2.components.inventory and
            owner_t2.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == inst
        if is_equipped and config.enable_player_glow then
          owner_t2.AnimState:SetHaunted(true)
          local body_intensity = intensity * 0.46 -- 全身效果淡一些
          if cr + cg + cb > 0.01 then
            owner_t2.AnimState:SetAddColour(cr * body_intensity, cg * body_intensity,
              cb * body_intensity, 0)
          else
            owner_t2.AnimState:SetAddColour(0, 0, 0, 0)
          end
        else
          owner_t2.AnimState:SetHaunted(false)
          owner_t2.AnimState:SetAddColour(0, 0, 0, 0)
        end
      end
    end)
  end

  local function UpdateCaneTint()
    if config.enable_light_fx and inst.all_active then
      StartCaneBreathTint()
    else
      StopCaneBreathTint()
    end
  end

  -- 统一更新所有功能
  local function UpdateAllFeatures()
    UpdateToolState()
    UpdateAutoHarvest()
    UpdateAutoFarm()
    -- 粒子特效
    UpdateParticleFX()
    -- 手杖呼吸染色
    UpdateCaneTint()
  end



  -- ===== 多功能总开关：右键 useableitem 与六色轮盘 UI 共用的唯一入口 =====
  -- ⭐ 5.6.27：右键开关配置已合并进 tool_enable——右键 use 与轮盘左键都走
  --    ToggleCaneActive 这同一个函数，切的是同一个 all_active，状态不会分叉。
  --    tool_enable=false 时由 ToggleCaneActive 内部门禁拦下（提示"多功能未启用"），
  --    两个入口同步失效；不再单独提供"禁用右键"配置项。
  if not inst.components.inventoryitem then
    inst:AddComponent("inventoryitem")
  end

  local function ToggleCaneActive(owner)
    if owner == nil or not owner:HasTag("player") then return false end
    if not config.tool_enable then
      if owner.components.talker then
        owner.components.talker:Say("多功能未启用（配置里已关闭）")
      end
      return false
    end
    -- 切换开关状态
    inst.all_active = not inst.all_active
    SyncCaneState()
    UpdateAllFeatures()
    -- ⭐ 5.6.33：右键/轮盘开关手杖时顺手扫描解锁未解锁宝石（持有月眼/护符/法杖/彩虹宝石）。
    --    只在 GEM_UNLOCK_REQUIRED 且有新解锁时才 1 次背包扫描 + 同步，开销可忽略。
    AutoUnlockGemsOnToggle(owner, inst)
    -- ⭐ 5.6.19：绿杖拆解受总开关门禁，切换后立即重算 spellcaster（开=挂拆解 / 关=清空）
    if ApplyGemAbility ~= nil then ApplyGemAbility(inst) end
    -- 切换贴图（换皮肤会丢失logo）
    if config.enable_tool_toggle_icon then
      local invitem = inst.components.inventoryitem
      if inst.all_active then
        invitem.imagename = "xin"
        invitem.atlasname = "images/inventoryimages/xin.xml"
      else
        invitem.imagename = "heh"
        invitem.atlasname = "images/inventoryimages/heh.xml"
      end
      invitem:ChangeImageName(invitem.imagename)
    end
    local status_text = inst.all_active and "󰀏 开/ON 󰀏" or "\243\176\128\137 关/OFF \243\176\128\137"
    if config.enable_tool_toggle_rename and inst.components.named then
      inst.components.named:SetName(status_text)
    end
    if owner.components.talker then
      owner.components.talker:Say("H-手杖 " .. status_text)
    end
    -- ⭐ 5.6.30：卸装/重装备会重建整个物品栏 ItemTile（视觉上"整个 UI 刷一遍"）。
    --    状态格/角标/轮盘早在 5.6.26 就改走 netvar dirty 刷新，不需要靠重建；
    --    只有"切换图标/更改名称"这两项真的改了 ItemTile 渲染内容、必须重建才生效。
    --    故加门禁：两项都关（默认）时切总开关不再重建，避免无谓的全栏闪烁。
    if (config.enable_tool_toggle_icon or config.enable_tool_toggle_rename)
        and inst.components.equippable:IsEquipped() and owner.components.inventory then
      inst._quick_re_equip = true
      local eslot = inst.components.equippable.equipslot
      local returned = owner.components.inventory:Unequip(eslot)
      if returned then
        owner.components.inventory:Equip(returned)
      end
      inst._quick_re_equip = nil
    end
    return false
  end
  -- 暴露到实体上：UI RPC 找到手杖后调用同一个函数
  inst.hcane_toggle_active = ToggleCaneActive

  -- 右键 use 组件始终注册：与轮盘左键共用 ToggleCaneActive（同一 all_active 开关）
  inst:AddComponent("useableitem")
  inst:AddComponent("named")
  inst.components.useableitem:SetOnUseFn(function(inst)
    local owner = inst.components.inventoryitem:GetGrandOwner()
    return ToggleCaneActive(owner)
  end)

  -- ⭐ 5.6.26：状态按手杖各自存档（active_gem + 总开关），换手杖互不串
  inst.OnSave = function(inst, data)
    data.all_active = inst.all_active
    data.active_gem = inst._hcane_active_gem or nil
    data.unlocked_gems = UnlockedTableToString(inst.hcane_unlocked)
  end

  inst.OnPreLoad = function(inst, data)
    inst.all_active = data and data.all_active or false
    inst._hcane_active_gem = data and data.active_gem or nil
    -- ⭐ 5.6.26：解锁按手杖恢复（换人持有照样解锁）
    inst.hcane_unlocked = UnlockedStringToTable(data and data.unlocked_gems)
    SyncCaneState()   -- 内部 SyncMultiStateToClient 会推 netvar
    UpdateAllFeatures()
    if inst.hcane_sync_gem_net then inst.hcane_sync_gem_net() end
  end

  -- 其他配置
  -- 处理防丢失逻辑（根据开关决定是否启用）
  if config.anti_lose and inst.components.inventoryitem then
    -- 防止被偷窃
    inst:AddTag("nosteal")
    -- 防流星破坏
    inst:AddTag("meteor_protection")
    -- 防止BOSS攻击/潮湿/落水导致脱手
    inst.components.inventoryitem.keepondrown = true
    inst.components.inventoryitem:SetOnDroppedFn(nil)
  end
  -- 防雷保护
  if config.lightning_protect_enable then
    if inst.components.equippable then
      inst.components.equippable.insulated = true
    end
  end
  -- 防雨保护
  if config.rain_protect_enable then
    if not inst.components.waterproofer then
      inst:AddComponent("waterproofer")
      inst.components.waterproofer:SetEffectiveness(1)
    end
  end

  -- 定义自动温控相关变量
  local auto_temp_task = nil
  local AUTO_TEMP_INTERVAL = 3.6

  -- 自动温控核心逻辑函数
  local function DoAutoTempControl(inst)
    -- 获取装备所有者（玩家）
    local doer = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
    -- 检查所有者有效性（必须是存活的玩家）
    if not doer
        or not doer:IsValid()
        or not doer:HasTag("player")
        or (doer.components.health and doer.components.health:IsDead()) then
      -- 若所有者无效，停止任务
      if auto_temp_task then
        auto_temp_task:Cancel()
        auto_temp_task = nil
      end
      return
    end
    -- 1. 温度调整
    if doer.components.temperature then
      -- 温度设定为36
      doer.components.temperature:SetTemperature(36)
    end
    -- 2. 自身解冻（仅当冻结时）
    -- if doer.components.freezable and doer.components.freezable:IsFrozen() then
    --   doer.components.freezable:Unfreeze()
    -- end
    -- 3. 自身灭火（仅当燃烧时）
    -- if doer.components.burnable and doer.components.burnable:IsBurning() then
    --   doer.components.burnable:Extinguish()
    -- end
  end

  -- 饥饿代价：六色法杖任务与扫描15格任务共用（原先定义在 DoAutotask 内，拆任务后提到外层）
  local function ApplyHungerCost(owner, delta, chance, source)
    if owner and owner.components.hunger and math.random() < chance then
      owner.components.hunger:DoDelta(delta, false, source)
    end
  end

  -- 自动工作相关配置与变量
  local AUTO_WORK_INTERVAL = 0.36 -- 自动工作检测间隔（可根据需求调整）
  local auto_work_task = nil      -- 自动工作定时任务句柄

  -- 全科技加成表
  local tech_bonus = {
    SCIENCE = 2,
    MAGIC = 3,
    ANCIENT = 4,
    SEAFARING = 2,
    CELESTIAL = 3,
    SHADOW = 4,
    CARTOGRAPHY = 2,
    SCULPTING = 1,
    BOOKCRAFT = 1,
    ORPHANAGE = 1,
    PERDOFFERING = 3,
    FISHING = 1,
    WARGOFFERING = 3,
    PIGOFFERING = 3,
    CARRATOFFERING = 3,
    BEEFOFFERING = 3,
    DRAGONOFFERING = 3,
    WORMOFFERING = 3,
    RABBITOFFERING = 3,
    CATCOONOFFERING = 3,
    LUNARFORGING = 2,
    SHADOWFORGING = 2,
    MADSCIENCE = 1,
    CARNIVAL_HOSTSHOP = 3,
    FOODPROCESSING = 1,
    CARNIVAL_PRIZESHOP = 1,
    CARPENTRY = 3,
    WINTERSFEASTCOOKING = 1,
    HERMITCRABSHOP = 7,
    RABBITKINGSHOP = 2,
    WANDERINGTRADERSHOP = 2,
    WAGPUNK_WORKSTATION = 1,
    TURFCRAFTING = 2,
    MASHTURFCRAFTING = 2,
    SPIDERCRAFT = 1,
    ROBOTMODULECRAFT = 1,
    SHELLWEAVER = 3,
  }

  -- ============================================================
  -- 六色法杖能力：独立定时任务（与扫描15格 DoAutotask 完全解耦）
  -- 触发条件：装备手杖 + GEM_ENABLED，不再依赖 enable_slot / auto_work_range
  -- 效果全部由 inst._hcane_active_gem（轮盘当前激活色）驱动，实物不触发
  -- ============================================================
  local GEM_STATE_INTERVAL = 0.36
  local gem_state_task = nil

  local function DoGemStateTask(inst)
    if not GEM_ENABLED then return end
    local doer = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
    if not doer or not doer:HasTag("player") then return end
    local owner = inst.components.inventoryitem:GetGrandOwner()
    local x, y, z = doer.Transform:GetWorldPosition()
    -- 橙法杖拾取半径：即使关掉"自动工作范围"，法杖能力仍独立生效
    local GEM_PICKUP_RADIUS = config.auto_work_range > 0 and config.auto_work_range or 6.6

    -- 绿色法杖：制作材料减半 + fastbuilder
    if inst._hcane_active_gem == "green" then
      doer.components.builder.ingredientmod = 0.5
      if doer ~= nil and not doer:HasTag("fastbuilder") then
        doer:AddTag("fastbuilder")
      end
    else
      doer.components.builder.ingredientmod = 1
      if doer ~= nil and not doer:HasTag("handyperson") then
        doer:RemoveTag("fastbuilder")
      end
    end

    -- 紫色法杖：发疯（受 all_active 开关控制）
    if inst._hcane_active_gem == "purple" and inst.all_active then
      doer.components.sanity:SetInducedInsanity(inst, true)
    else
      doer.components.sanity:SetInducedInsanity(inst, false)
    end

    -- 黄色法杖：发光半径26 + 移速+0.36（点亮法术在 spellcaster）
    if inst._hcane_active_gem == "yellow" then
      if config.hcane_light <= 0 then
        if inst._yellow_light == nil or not inst._yellow_light:IsValid() then
          inst._yellow_light = SpawnPrefab('hehu_light')
          if inst._yellow_light then
            inst._yellow_light.entity:SetParent(owner and owner.entity or inst.entity)
            inst._yellow_light.entity:AddFollower()
            inst._yellow_light.Light:SetRadius(26)
            inst._yellow_light.Light:Enable(true)
          else
            print("警告：黄色宝石光效预制体创建失败！")
          end
        else
          inst._yellow_light.entity:SetParent(owner and owner.entity or inst.entity)
          inst._yellow_light.Light:Enable(true)
        end
      else
        if inst._light and inst._light:IsValid() then
          inst._light.Light:SetRadius(26)
        end
      end
      inst.components.equippable.walkspeedmult = 1 + config.speed_buff + 0.36
    else
      if inst._yellow_light ~= nil and inst._yellow_light:IsValid() then
        inst._yellow_light:Remove()
      end
      inst._yellow_light = nil
      if config.hcane_light > 0 and inst._light and inst._light:IsValid() then
        inst._light.Light:SetRadius(config.hcane_light)
      end
      inst.components.equippable.walkspeedmult = 1 + config.speed_buff
    end

    -- 橙色法杖：原生 blinkstaff 闪烁（不受总开关）+ 自动拾取（受 all_active）
    if inst._hcane_active_gem == "orange" then
      if not inst.components.blinkstaff then
        inst:AddComponent("blinkstaff")
        inst.components.blinkstaff:SetFX("sand_puff_large_front", "sand_puff_large_back")
        -- onblinkfn 官方默认就是 nil，不设回调（原先引用未定义全局 onblink）
      end
      if inst.all_active then
        local ents = TheSim:FindEntities(x, y, z, GEM_PICKUP_RADIUS,
          nil,
          { "INLIMBO", "FX", "NOCLICK", "burnt", "flower", "dead", "knockbackdelayinteraction", "fire", "minesprung",
            "mineactive", "irreplaceable", "moonglass_geode", "thorny", "donotautopick", },
          { "_inventoryitem", "plant", "witherable", "lureplant", "waterplant", "crop", "lichen", "oceanvine", "kelp",
            "catchable", "groundmushroom", "sludgestack", }
        )
        for _, ent in ipairs(ents) do
          if ent.components.inventoryitem and
              ent.components.inventoryitem.cangoincontainer and
              not ent.components.inventoryitem:IsHeld() then
            local v_pos = ent:GetPosition()
            if ent.components.trap and ent.components.trap:IsSprung() then
              if doer.components.inventory:CanAcceptCount(ent, 1) > 0 then
                SpawnPrefab("sand_puff").Transform:SetPosition(v_pos.x, v_pos.y, v_pos.z)
                ent.components.trap:Harvest(doer)
                ApplyHungerCost(owner, -0.6, 0.66, inst.prefab)
                return
              end
            else
              if GiveItemToPlayer(doer, ent, v_pos) then
                SpawnPrefab("sand_puff").Transform:SetPosition(v_pos.x, v_pos.y, v_pos.z)
                ApplyHungerCost(owner, -0.6, 0.66, inst.prefab)
                return
              end
            end
          end
        end
      end
    else
      if inst.components.blinkstaff then
        inst:RemoveComponent("blinkstaff")
      end
    end

    -- 红/蓝攻击标志：由当前法杖状态决定（onattack 主目标+群攻共用）
    inst._has_redgem = nil
    inst._has_bluegem = nil

    -- 红色法杖：自身灭火（常驻保命）+ 范围治疗（受总开关）+ 点燃（onattack/群攻在别处）
    if inst._hcane_active_gem == "red" then
      inst._has_redgem = true
      if doer.components.burnable and doer.components.burnable:IsBurning() then
        doer.components.burnable:Extinguish()
        if doer.components.inventory then
          doer.components.inventory:GiveItem(SpawnPrefab("ash"), nil, doer:GetPosition())
        end
      end
      if inst.all_active and math.random() < 0.16 then
        ApplyHungerCost(owner, -1.6, 0.66, inst.prefab)
        local hx, hy, hz = doer.Transform:GetWorldPosition()
        local HEAL_RADIUS = 6
        local heal_ents = TheSim:FindEntities(hx, hy, hz, HEAL_RADIUS,
          { "_health" }, { "INLIMBO", "dead", "FX" })
        for _, ent in ipairs(heal_ents) do
          if ent.components.health and not ent.components.health:IsDead()
              and not ent:HasTag("epic")
              and not ent:HasTag("wall") and not ent:HasTag("structure") then
            ent.components.health:DoDelta(16, false, inst.prefab)
            local fx = SpawnPrefab("wortox_soul_heal_fx")
            if fx and ent.components.combat and ent.components.combat.hiteffectsymbol then
              fx.entity:AddFollower():FollowSymbol(ent.GUID, ent.components.combat.hiteffectsymbol, 0, -50, 0)
              fx:Setup(ent)
            end
          end
        end
      end
    end

    -- 蓝色法杖：自身解冻（常驻保命）+ 理智恢复（受总开关）+ 冰冻（onattack/群攻在别处）
    if inst._hcane_active_gem == "blue" then
      inst._has_bluegem = true
      if doer.components.freezable and doer.components.freezable:IsFrozen() then
        doer.components.freezable:Unfreeze()
        if doer.components.inventory then
          doer.components.inventory:GiveItem(SpawnPrefab("ice"), nil, doer:GetPosition())
        end
      end
      if inst.all_active and math.random() < 0.16 then
        ApplyHungerCost(owner, -1.6, 0.66, inst.prefab)
        if doer.components.sanity then
          doer.components.sanity:DoDelta(16, false, inst.prefab)
          local fx = SpawnPrefab("ghostflower_spirit1_fx")
          if fx then
            fx.Transform:SetPosition(doer.Transform:GetWorldPosition())
          end
        end
      end
    end
  end

  -- 独立的自动工作函数
  local _ripening_counter = 0
  local function DoAutotask(inst)
    -- 存在工作范围才开始
    local WORK_RADIUS = config.auto_work_range
    if WORK_RADIUS <= 0 then return end
    -- 通用的人物坐标信息
    local doer = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
    if not doer or not doer:HasTag("player") then return end
    local owner = inst.components.inventoryitem:GetGrandOwner()
    local x, y, z = doer.Transform:GetWorldPosition()

    -- 勋章面板兼容（能力勋章 1909182187）：一次性注册集中回调
    if not owner._hcane_medal_setup then
      owner._hcane_medal_setup = true

      -- 物品变化时立即刷新面板（事件驱动，不等20秒轮询）
      local function OnInventoryChanged()
        owner:PushEvent("medal_buff_update")
      end
      owner:ListenForEvent("itemget", OnInventoryChanged)
      owner:ListenForEvent("itemlose", OnInventoryChanged)

      local _prevGetMedalBuffInfo = owner.GetMedalBuffInfo
      owner.GetMedalBuffInfo = function(self, buff_info)
        if _prevGetMedalBuffInfo then _prevGetMedalBuffInfo(self, buff_info) end
        local inv = self.components.inventory
        if not inv then return end
        -- 收集所有相关的物品（15格 + 装备）
        local pool = { inv:GetItemInSlot(15) }
        if EQUIPSLOTS then
          for _, slot in pairs(EQUIPSLOTS) do
            local e = inv:GetEquippedItem(slot)
            if e then table.insert(pool, e) end
          end
        end
        local function hasAny(...)
          for _, item in ipairs(pool) do
            if item then
              for _, p in ipairs({ ... }) do
                if item.prefab == p then return true end
              end
            end
          end
          return false
        end
        if self.hwatergo_active then table.insert(buff_info, { buffname = "hcane_water_hunger", bufftime = -1 }) end
        if hasAny("redgem", "redmooneye", "amulet") then
          table.insert(buff_info,
            { buffname = "hcane_red_gem", bufftime = -1 })
        end
        if hasAny("bluegem", "bluemooneye", "blueamulet") then
          table.insert(buff_info,
            { buffname = "hcane_blue_gem", bufftime = -1 })
        end
        if hasAny("orangegem", "orangemooneye", "orangeamulet", "orangestaff") then
          table.insert(buff_info,
            { buffname = "hcane_orange_gem", bufftime = -1 })
        end
        if hasAny("yellowgem", "yellowmooneye", "yellowamulet") then
          table.insert(buff_info,
            { buffname = "hcane_yellow_gem", bufftime = -1 })
        end
        if hasAny("purplegem", "purplemooneye", "purpleamulet") then
          table.insert(buff_info,
            { buffname = "hcane_purple_gem", bufftime = -1 })
        end
        if hasAny("greengem", "greenmooneye", "greenamulet") then
          table.insert(buff_info,
            { buffname = "hcane_green_gem", bufftime = -1 })
        end
        if hasAny("opalpreciousgem") then table.insert(buff_info, { buffname = "hcane_opal_gem", bufftime = -1 }) end
        if hasAny("lunar_seed") then table.insert(buff_info, { buffname = "hcane_celestial", bufftime = -1 }) end
        if hasAny("furtuft", "bearger_fur") then table.insert(buff_info, { buffname = "hcane_bearger", bufftime = -1 }) end
        if hasAny("townportaltalisman", "antlionhat") then
          table.insert(buff_info,
            { buffname = "hcane_antlion", bufftime = -1 })
        end
        if hasAny("glommerflower", "fruitflyfruit") then
          table.insert(buff_info,
            { buffname = "hcane_glommer", bufftime = -1 })
        end
      end
    end

    -- 保存原始血量上限
    if doer and doer.components.health and not doer._original_maxhealth then
      doer._original_maxhealth = doer.components.health.maxhealth
      doer._health_mult = 1
    end
    -- 保存原始饥饿上限
    if doer and doer.components.hunger and not doer._original_maxhunger then
      doer._original_maxhunger = doer.components.hunger.max
      doer._hunger_mult = 1
    end
    -- 记录原始理智上限
    if doer and doer.components.sanity and not doer._original_maxsanity then
      doer._original_maxsanity = doer.components.sanity.max
      doer._sanity_mult = 1
    end
    -- 2. 计算倍率（基于实体属性取最大）
    local sanity_mult = doer._sanity_mult
    local health_mult = doer._health_mult
    local hunger_mult = doer._hunger_mult

    -- 获取人物15格的东西
    local item = doer.components.inventory:GetItemInSlot(15)
    -- 获取人物装备栏/15格子的东西
    -- 1. 遍历装备槽位
    local items = {}
    if EQUIPSLOTS then
      for k, v in pairs(EQUIPSLOTS) do
        local equip = doer.components.inventory:GetEquippedItem(v)
        if equip then
          items[v] = equip
        end
      end
    end
    items["slot_15"] = doer.components.inventory:GetItemInSlot(15)

    -- 封装检测物品函数
    local function HasTargetItem(items, target_prefabs)
      if not items or not target_prefabs or #target_prefabs == 0 then
        return false
      end
      -- 将目标预制名数组转为集合（键值对），提升查询效率
      local prefab_set = {}
      for _, prefab in ipairs(target_prefabs) do
        prefab_set[prefab] = true
      end
      -- 遍历物品集合
      for _, item in pairs(items) do
        if item and prefab_set[item.prefab] then
          return true
        end
      end
      return false
    end

    -- 六色宝石法杖能力已拆到独立任务 DoGemStateTask（上方），此处只处理实物触发的扫描15格能力

    -- ！！！高级能力（彩虹/天体/熊皮等非宝石物品仍由实物触发）
    -- 彩虹宝石开始
    if HasTargetItem(items, { "opalpreciousgem" }) then
      -- 复制概率为16%
      if math.random() < 0.16 then
        -- 1. 获取玩家第14个物品栏的物品
        local slot_14_item = doer.components.inventory:GetItemInSlot(14)
        -- 2. 严格校验：玩家有效+有物品栏+14栏有有效物品+物品可堆叠+堆叠未达上限
        if doer
            and doer.components.inventory
            and slot_14_item
            and slot_14_item:IsValid()
            and slot_14_item.components.stackable
            and not slot_14_item.components.stackable:IsFull()
        then
          local target_prefab = slot_14_item.prefab
          -- 3. 固定复制1个（不再复制余量）
          local item_copy = SpawnPrefab(target_prefab)
          if item_copy.components.stackable then
            item_copy.components.stackable:SetStackSize(1) -- 每次只加1个
          end
          -- 4. 放入物品栏（自动叠加到14栏物品中）
          doer.components.inventory:GiveItem(item_copy)
          ApplyHungerCost(owner, -16.6, 0.66, inst.prefab)
        end
      end
      if owner.components.hunger then
        owner.components.hunger.burnratemodifiers:SetModifier("hcnae_opalprehunger", 0.06)
      end
    else
      if owner.components.hunger then
        owner.components.hunger.burnratemodifiers:RemoveModifier("hcnae_opalprehunger")
      end
    end
    -- 彩虹宝石结束

    -- 启迪碎片开始（H-装备）
    if HasTargetItem(items, { "alterguardianhat", "alterguardianhatshard" }) then
      -- 全科技解锁
      local builder = owner and owner.components.builder
      if builder ~= nil then
        for k, v in pairs(tech_bonus) do
          builder[string.lower(k) .. "_tempbonus"] = v
        end
      end
    else
      -- 恢复原本科技
      local builder = owner and owner.components.builder
      if builder ~= nil then
        for k, _ in pairs(tech_bonus) do
          builder[string.lower(k) .. "_tempbonus"] = nil
        end
      end
    end
    -- 启迪碎片结束

    -- 天体珠宝开始
    if HasTargetItem(items, { "lunar_seed" }) then
      owner:Hide()
      ApplyHungerCost(owner, -1, 0.36, inst.prefab)
    else
      owner:Show()
    end
    -- 天体珠宝结束

    -- 独眼巨鹿眼球开始
    if HasTargetItem(items, { "deerclops_eyeball" }) then
      -- 触发单挑
      if inst.singlefight_target then
        local ents = TheSim:FindEntities(x, y, z, 36,
          { "_combat" },
          { "INLIMBO", "NOCLICK", "player", "notarget" }
        )
        for _, v in ipairs(ents) do
          -- 非当前单挑目标、存活、且仇恨目标是玩家
          if v ~= inst.singlefight_target
              and v.entity:IsVisible()
              and (not v.components.health or not v.components.health:IsDead())
              and v.components.combat
              and v.components.combat.target == owner then
            v.components.combat:DropTarget(nil) -- 强制清除仇恨
          end
        end
      end
    end
    -- 独眼巨鹿眼球结束

    -- 龙蝇开始
    if HasTargetItem(items, { "dragon_scales" }) then
      if not owner:HasTag("NOTARGET") then
        owner:AddTag("NOTARGET")
      end
    elseif owner:HasTag("NOTARGET") then
      owner:RemoveTag("NOTARGET")
    end
    -- 龙蝇结束

    -- 麋鹿鹅开始
    if HasTargetItem(items, { "goose_feather", "featherfan" }) and owner.components.drownable then
      if not owner.hwatergo_active then
        -- owner.Physics:ClearCollidesWith(COLLISION.LAND_OCEAN_LIMITS)
        -- owner.Physics:ClearCollidesWith(COLLISION.BOAT_LIMITS)
        if owner.Physics then
          RemovePhysicsColliders(owner)
        end
        owner.components.drownable.enabled = false
        if owner.components.hunger then
          owner.components.hunger.burnratemodifiers:SetModifier("hcnae_goose_hunger", 6)
        end
        -- 状态标记
        owner.hwatergo = true
        owner.hwatergo_active = true
      end
    elseif owner.components.drownable and owner.hwatergo then
      -- owner.Physics:CollidesWith(COLLISION.LAND_OCEAN_LIMITS)
      -- owner.Physics:CollidesWith(COLLISION.BOAT_LIMITS)
      if owner.Physics then
        ChangeToCharacterPhysics(owner)
      end
      owner.components.drownable.enabled = true
      if owner.components.hunger then
        owner.components.hunger.burnratemodifiers:RemoveModifier("hcnae_goose_hunger")
      end
      -- 状态标记去除
      owner.hwatergo = nil
      owner.hwatergo_active = nil
    end
    -- 麋鹿鹅结束

    -- 熊大破坏范围开始
    if HasTargetItem(items, { "furtuft", "bearger_fur" }) then
      -- 定义破坏范围（可根据需求调整）
      local DESTROY_RADIUS = config.auto_work_range
      -- 筛选可破坏目标的标签（同原逻辑）
      local WORKABLES_CANT_TAGS = { "insect", "INLIMBO", "structure", "wall", "ignorewalkableplatforms", "ancienttree" }
      local WORKABLES_ONEOF_TAGS = { "CHOP_workable", "DIG_workable", "HAMMER_workable", "MINE_workable" }

      -- 核心破坏函数：传入坐标(x,y,z)，按范围破坏物体
      local function DestroyInRange(inst, x, y, z)
        -- 查找范围内可破坏的物体
        local targets = TheSim:FindEntities(x, y, z, DESTROY_RADIUS, nil, WORKABLES_CANT_TAGS, WORKABLES_ONEOF_TAGS)

        for _, target in ipairs(targets) do
          if target:IsValid() and
              target.components.workable ~= nil and
              target.components.workable:CanBeWorked() and
              target.components.workable.action ~= ACTIONS.NET then
            -- 生成破坏特效（如坍塌效果）
            SpawnPrefab("collapse_small").Transform:SetPosition(target.Transform:GetWorldPosition())
            -- 执行破坏（玩家为主体，可刷勋章）
            target.components.workable:Destroy(owner)
            ApplyHungerCost(owner, -0.6, 0.36, inst.prefab)
          end
        end
      end

      -- 执行破坏
      if owner.components.talker then
        owner.components.talker:Say("󰀌 破坏/Broke 󰀌")
      end
      DestroyInRange(inst, x, y, z)
    end
    -- 熊大破坏范围结束

    -- 远古织影者骨头类装备开始
    if HasTargetItem(items, { "skeletonhat", "thurible", "armorskeleton" }) then
      if math.random() < 0.16 then
        -- 理智
        if owner.components.sanity then
          owner.components.sanity:DoDelta(16, false, inst.prefab)
        end
      end
    end
    -- 远古织影者骨头类装备结束

    -- 毒菌蟾蜍开始
    if HasTargetItem(items, { "sleepbomb", "shroom_skin" }) then
      if not owner.bufulj_active then
        for k, v in pairs(owner.components.inventory.itemslots) do
          if v.components.perishable ~= nil then
            v.components.perishable:StopPerishing()
          end
        end
        owner.bufulj = true
        owner.bufulj_active = true
      end
    elseif owner.bufulj then
      for k, v in pairs(owner.components.inventory.itemslots) do
        if v.components.perishable ~= nil then
          v.components.perishable:StartPerishing()
        end
      end
      owner.bufulj = nil
      owner.bufulj_active = nil
    end
    -- 毒菌蟾蜍结束

    -- ！！！伤害修改类开始
    -- 定义伤害修改的装备组及倍率规则（一站式管理，和三维修改类结构一致）
    local damage_mod_configs = {
      -- 绝望石/套装装备组
      dreadstone = {
        items = { "dreadstone", "armordreadstone", "dreadstonehat", "purebrilliance" },
        damage_mult = 2.6,      -- 基础伤害倍率
        planardamage_mult = 2.6 -- 位面伤害倍率
      },
      -- 暗影碎布类装备组
      voidcloth = {
        items = { "voidcloth", "voidcloth_boomerang", "armor_voidcloth", "voidcloth_umbrella" },
        damage_mult = 4.6,      -- 基础伤害倍率
        planardamage_mult = 3.6 -- 位面伤害倍率
      },
      -- 亮茄套装装备组
      lunarplant = {
        items = { "armor_lunarplant", "lunarplanthat", "sword_lunarplant", "staff_lunarplant" },
        damage_mult = 3.6,      -- 基础伤害倍率
        planardamage_mult = 4.6 -- 位面伤害倍率
      }
    }

    -- 合并所有伤害修改装备为总列表
    local all_damage_gear_list = {}
    for _, damage_config in pairs(damage_mod_configs) do
      for _, gear_item in ipairs(damage_config.items) do
        table.insert(all_damage_gear_list, gear_item)
      end
    end

    -- 伤害修改类外侧判断
    if HasTargetItem(items, all_damage_gear_list) then
      -- 从实体获取历史倍率（作为计算基础，保证只会变大不会变小）
      local current_damage_mult = inst._damage_mult
      local current_planardamage_mult = inst._planardamage_mult

      -- 遍历配置表计算新的倍率（取最大值，保证倍率只增不减）
      for _, damage_config in pairs(damage_mod_configs) do
        if HasTargetItem(items, damage_config.items) then
          current_damage_mult = math.max(current_damage_mult, damage_config.damage_mult or 1)
          current_planardamage_mult = math.max(current_planardamage_mult, damage_config.planardamage_mult or 1)
        end
      end

      -- 应用基础伤害变化（仅当倍率变动时才赋值）
      if inst._damage_mult ~= current_damage_mult then
        inst._damage_mult = current_damage_mult
        print("玩家装备伤害倍率更新：", current_damage_mult)
      end

      -- 应用位面伤害变化（仅当倍率变动时才赋值）
      if inst._planardamage_mult ~= current_planardamage_mult then
        inst._planardamage_mult = current_planardamage_mult
        print("玩家装备位面伤害倍率更新：", current_planardamage_mult)
      end
    end
    -- ！！！伤害修改类结束

    -- ！！！三维修改类开始
    -- 定义装备组及对应的倍率规则（一站式管理，更易维护）
    local gear_mod_configs = {
      -- 远古织影者骨头类装备组
      bone = {
        items = { "shadowheart", "skeletonhat", "thurible", "armorskeleton" },
        sanity_mult = 1.6,
        health_mult = 1.6,
        hunger_mult = 1.6
      },
      -- 暗影心房类装备组
      shadow = {
        items = { "shadowheart_infused", "shadow_beef_bell", "saddle_shadow", "shadow_battleaxe" },
        sanity_mult = 3.6
      },
      -- 火花柜类装备组
      spark = {
        items = { "coolant", "security_pulse_cage", "security_pulse_cage_full", "beargerfur_sack", "deerclopseyeball_sentryward_kit", "houndstooth_blowpipe" },
        health_mult = 3.6,
        hunger_mult = 3.6
      }
    }

    -- 三维修改类合并所有装备为总列表
    local all_mod_gear_list = {}
    for _, gear_config in pairs(gear_mod_configs) do
      for _, gear_item in ipairs(gear_config.items) do
        table.insert(all_mod_gear_list, gear_item)
      end
    end

    -- 三维修改类外侧判断
    if HasTargetItem(items, all_mod_gear_list) then
      -- 遍历配置表计算倍率
      for _, gear_config in pairs(gear_mod_configs) do
        if HasTargetItem(items, gear_config.items) then
          sanity_mult = math.max(sanity_mult, gear_config.sanity_mult or 1)
          health_mult = math.max(health_mult, gear_config.health_mult or 1)
          hunger_mult = math.max(hunger_mult, gear_config.hunger_mult or 1)
        end
      end

      -- 应用变化后的倍率
      if doer._sanity_mult ~= sanity_mult then
        doer.components.sanity.max = doer._original_maxsanity * sanity_mult
        doer._sanity_mult = sanity_mult
        owner.components.sanity:DoDelta(1, false, inst.prefab)
      end

      if doer._health_mult ~= health_mult then
        doer.components.health.maxhealth = doer._original_maxhealth * health_mult
        doer._health_mult = health_mult
        owner.components.health:DoDelta(1, false, inst.prefab)
      end

      if doer._hunger_mult ~= hunger_mult then
        doer.components.hunger.max = doer._original_maxhunger * hunger_mult
        doer._hunger_mult = hunger_mult
        owner.components.hunger:DoDelta(1, false, inst.prefab)
      end
    end
    -- 三维修改类结束

    -- ！！！杂类
    -- 理智减少开始
    if HasTargetItem(items, { "nightmarefuel", "horrorfuel" }) then
      -- 理智减少
      if owner.components.sanity then
        owner.components.sanity:DoDelta(-16, false, inst.prefab)
      end
    end
    -- 理智减少结束

    -- 三维恢复开始
    if HasTargetItem(items, { "moonrockcrater" }) then
      if math.random() < 0.16 then
        -- 生命
        if owner.components.health then
          owner.components.health:DoDelta(6, false, inst.prefab)
        end
        -- 饥饿
        if owner.components.hunger then
          owner.components.hunger:DoDelta(6, false, inst.prefab)
        end
        -- 理智
        if owner.components.sanity then
          owner.components.sanity:DoDelta(6, false, inst.prefab)
        end
      end
    end
    -- 三维恢复结束

    if HasTargetItem(items, { "cookbook" }) then
      if not owner.hfood_active then
        owner:PushEvent("learncookbookstats", inst.prefab)
        owner:AddDebuff("hungerregenbuff", "hungerregenbuff")
        owner.hfood = true
        owner.hfood_active = true
      end
    elseif owner.hfood then
      owner:RemoveDebuff("hungerregenbuff")
      if owner.components.foodmemory ~= nil then
        owner.components.foodmemory:RememberFood("hungerregenbuff")
      end
      owner.hfood = nil
      owner.hfood_active = nil
    end

    -- 范围训牛开始（H-装备）
    if HasTargetItem(items, { "beefalohat", "horn", "hat_cowboy" }) then
      -- 查找范围内的牛
      local beefalos = TheSim:FindEntities(x, y, z, WORK_RADIUS,
        { "beefalo" },                 -- 只找牛
        { "INLIMBO", "dead", "ghost" } -- 排除无效目标
      )
      -- 增加驯服度
      for _, beefalo in ipairs(beefalos) do
        if beefalo:IsValid() and beefalo.components.domesticatable then
          beefalo.components.domesticatable:DeltaDomestication(0.0006)
        end
      end
    end
    -- 范围训牛结束

    -- 范围消除蚁狮坑开始（H-装备）
    if HasTargetItem(items, { "townportaltalisman", "antlionhat" }) then
      -- 查找范围内的蚁狮坑
      local sinkholes = TheSim:FindEntities(x, y, z, WORK_RADIUS,
        { "antlion_sinkhole" }, -- 只找蚁狮坑
        { "FX" }                -- 排除无效目标
      )

      for _, sinkhole in ipairs(sinkholes) do
        if sinkhole:IsValid() then
          -- 直接移除蚁狮坑
          sinkhole:Remove()
          ApplyHungerCost(owner, -6.6, 0.66, inst.prefab)
          -- 可选：生成消除特效
          local fx = SpawnPrefab("collapse_small")
          if fx then
            fx.Transform:SetPosition(sinkhole.Transform:GetWorldPosition())
          end

          -- 可选：播放消除音效
          sinkhole.SoundEmitter:PlaySound("dontstarve/common/destroy_rock")
        end
      end
    end
    -- 范围消除蚁狮坑结束

    -- 耕作先驱帽开始（H-装备）
    if HasTargetItem(items, { "plantregistryhat", "fertilizer" }) then
      local ents = TheSim:FindEntities(x, y, z, WORK_RADIUS, nil, { 'INLIMBO', 'wall', 'shadowminion' })
      for i, ent in ipairs(ents) do
        -- 对有"可照料"组件的植物执行照料操作
        if ent.components.farmplanttendable ~= nil then
          ent.components.farmplanttendable:TendTo(inst)
        end
      end
      -- 核心改进：仅对人物所在tile为中心的地皮补充营养
      local center_tile_x, center_tile_z = TheWorld.Map:GetTileCoordsAtPoint(x, y, z)
      TheWorld.components.farming_manager:AddTileNutrients(
        center_tile_x, center_tile_z, 6, 6, 6
      )
    end
    -- 耕作先驱帽结束

    -- 高级耕作先驱帽开始（H-装备）
    if HasTargetItem(items, { "nutrientsgoggleshat" }) then
      local ents = TheSim:FindEntities(x, y, z, 36, nil, { 'INLIMBO', 'wall', 'shadowminion' })
      for i, ent in ipairs(ents) do
        -- 对有"可照料"组件的植物执行照料操作
        if ent.components.farmplanttendable ~= nil then
          ent.components.farmplanttendable:TendTo(inst)
        end
      end
      -- 核心改进：仅对人物所在tile为中心的3x3（9格）地皮补充营养
      local center_tile_x, center_tile_z = TheWorld.Map:GetTileCoordsAtPoint(x, y, z)
      -- 遍历范围（中心tile ±）
      for dx = -3, 3 do
        for dz = -3, 3 do
          local tile_x = center_tile_x + dx
          local tile_z = center_tile_z + dz
          -- 为9格内的每块有效地皮补充营养
          TheWorld.components.farming_manager:AddTileNutrients(
            tile_x, tile_z, 16, 16, 16
          )
          -- 先将格子坐标转换为世界坐标（取格子中心）
          local world_x, _, world_z = TheWorld.Map:GetTileCenterPoint(tile_x, tile_z)
          -- 给该格子添加16点土壤湿度（和施肥同范围、同数值）
          TheWorld.components.farming_manager:AddSoilMoistureAtPoint(world_x, 0, world_z, 16)
        end
      end
    end
    -- 高级耕作先驱帽结束

    -- 格罗姆之花/友好果蝇果/植物图鉴开始（催熟周围作物和植物）
    if HasTargetItem(items, { "glommerflower", "fruitflyfruit", "medal_plant_book" }) then
      -- 巨大化模式：14格 与 15格 都必须为催化剂（格罗姆之花 / 友好果蝇果 / 植物图鉴）
      --（两格可同为其中一种，也可各一种；即需要两个催化剂）
      local _s14 = doer.components.inventory:GetItemInSlot(14)
      local _s15 = doer.components.inventory:GetItemInSlot(15)
      local function _isRipenCatalyst(it)
        return it ~= nil and it:IsValid()
            and (it.prefab == "glommerflower" or it.prefab == "fruitflyfruit" or it.prefab == "medal_plant_book")
      end
      local giant_ripen_mode = _isRipenCatalyst(_s14) and _isRipenCatalyst(_s15)

      -- 催熟频率：每调用10次自动工作执行一次催熟（≈3.6秒）
      _ripening_counter = _ripening_counter + 1
      if _ripening_counter >= 10 then
        _ripening_counter = 0

        -- 查找范围内可催熟的目标
        local ents = TheSim:FindEntities(x, y, z, WORK_RADIUS, nil,
          { "INLIMBO", "FX", "burnt", "dead", "stump" })

        -- 仿官方 trygrowth 催熟逻辑（带过熟保护）
        local function TryGrowth(ent)
          if not ent:IsValid() then return end

          -- 前置跳过：枯萎/腐烂的植物不再处理
          if ent:HasTag("withered") or ent:HasTag("farm_plant_killjoy") then
            return
          end

          -- 前置跳过：已可采摘 → 防止过熟（对应 stage 5 full / 浆果成熟）
          if ent.components.pickable ~= nil and ent.components.pickable:CanBePicked() then
            return
          end

          -- 前置跳过：crop 已成熟
          if ent.components.crop ~= nil and ent.components.crop.matured then
            return
          end

          -- 1. Growable 组件（树木、农场作物等）
          if ent.components.growable ~= nil then
            if ent.components.simplemagicgrower ~= nil then
              ent.components.simplemagicgrower:StartGrowing()
              return
            elseif ent.components.growable.domagicgrowthfn ~= nil then
              -- 农场作物（domagicgrowthfn）：额外检查是否已到最终腐烂阶段
              if ent.components.growable.stage >= #ent.components.growable.stages then
                return
              end
              -- 巨大化模式：强制 oversized 后再催熟（仿勋章植物图鉴 force_oversized）
              if giant_ripen_mode then
                ent.force_oversized = true
              end
              ent.components.growable:DoMagicGrowth()
              return
            else
              ent.components.growable:DoGrowth()
              return
            end
          end

          -- 2. Pickable 组件（浆果丛、草根等）— 仅催熟未成熟的
          if ent.components.pickable ~= nil then
            if not ent.components.pickable:CanBePicked() or not ent.components.pickable.caninteractwith then
              if ent.components.pickable:FinishGrowing() then
                ent.components.pickable:ConsumeCycles(1)
              end
            end
            return
          end

          -- 3. Crop 组件（旧版农场作物）
          if ent.components.crop ~= nil and (ent.components.crop.rate or 0) > 0 then
            ent.components.crop:DoGrow(1 / ent.components.crop.rate, true)
            return
          end

          -- 4. Harvestable 组件（蘑菇农场等）
          if ent.components.harvestable ~= nil then
            if ent.components.harvestable:IsMagicGrowable() then
              ent.components.harvestable:DoMagicGrowth()
            elseif not ent.components.harvestable:CanBeHarvested() then
              ent.components.harvestable:Grow()
            end
            return
          end
        end

        for _, ent in ipairs(ents) do
          TryGrowth(ent)
        end

        -- 为作物补充营养（仿 MaximizePlant / 高级耕作先驱帽）
        if TheWorld.components.farming_manager then
          local center_tile_x, center_tile_z = TheWorld.Map:GetTileCoordsAtPoint(x, y, z)
          for dx = -2, 2 do
            for dz = -2, 2 do
              TheWorld.components.farming_manager:AddTileNutrients(
                center_tile_x + dx, center_tile_z + dz, 12, 12, 12
              )
            end
          end
        end

        -- 播放催熟特效（仿勋章植物图鉴的 book_fx 书页粒子，替换原 vault_portal_fx）
        local fx = SpawnPrefab("book_fx")
        if fx then
          local px, py, pz = owner.Transform:GetWorldPosition()
          fx.Transform:SetPosition(px, py, pz)
        end
        -- 读书声效（仿勋章植物图鉴读时的 don_tstarve/common/book_spell）
        if owner.SoundEmitter ~= nil then
          owner.SoundEmitter:PlaySound("dontstarve/common/book_spell")
        end

        ApplyHungerCost(owner, -16, 0.36, inst.prefab)
      end
    end
    -- 格罗姆之花/友好果蝇果结束

    -- 范围催眠开始（H-装备）
    if HasTargetItem(items, { "mandrake", "panflute" }) then
      -- 范围催眠10+WORK_RADIUS范围内的所有实体
      local ents = TheSim:FindEntities(x, y, z, WORK_RADIUS + 10, nil, { "INLIMBO", "player", "dead", "ghost" }) -- 直接过滤玩家标签
      for _, ent in ipairs(ents) do
        -- 排除特殊状态生物（可选，也可直接删掉这几行更简化）
        if not (ent.components.freezable and ent.components.freezable:IsFrozen()) then
          -- 给生物加睡眠值（10点足够直接入睡，时长用原版排箫的10秒即可）
          if ent.components.sleeper then
            ent.components.sleeper:AddSleepiness(16, 66)
          else
            ent:PushEvent("knockedout")
          end
        end
      end
    end
    -- 范围催眠结束

    -- 自动播种
    -- 种种子，先检查槽位物品是否为可种植物，避免误吞非种子物品
    if item and item.components.farmplantable then
      for _, soil_ent in ipairs(TheSim:FindEntities(x, y, z, WORK_RADIUS, { "soil" }, { "NOCLICK" })) do
        -- 在确认是可种植物后再从容器中取出尝试播种；失败则归还(搞不明白怎么直接用item播种会出问题，只能用复制品)
        local seed = SpawnPrefab(item.prefab)
        -- print("尝试自动播种：" .. item.prefab)
        if seed and seed.components.farmplantable then
          if not seed.components.farmplantable:Plant(soil_ent, doer) then
            doer.components.inventory:GiveItem(seed)
            break
          end
        else
          -- 如果取出后发现不是可种植物，归还并停止
          if seed then
            doer.components.inventory:GiveItem(seed)
          end
          break
        end
      end
    end
    -- 种杂草
    if HasTargetItem(items, { "forgetmelots", "forgetmelots_dried", "tillweed", "firenettles", "tillweed_dried", "firenettles_dried" }) then
      -- 杂草对应的实体
      local SPECIAL_SEED_WEED_MAP = {
        -- 必忘我
        forgetmelots = "weed_forgetmelots",
        forgetmelots_dried = "weed_forgetmelots",
        -- 犁地草
        tillweed = "weed_tillweed",
        tillweed_dried = "weed_tillweed",
        -- 火荨麻
        firenettles = "weed_firenettle",
        firenettles_dried = "weed_firenettle",
      }
      for _, soil_ent in ipairs(TheSim:FindEntities(x, y, z, WORK_RADIUS, { "soil" }, { "NOCLICK" })) do
        local s_x, s_y, s_z = soil_ent.Transform:GetWorldPosition()
        -- 获取杂草对应作物
        soil_ent:Remove()
        local weed = SpawnPrefab(SPECIAL_SEED_WEED_MAP[item.prefab])
        weed.Transform:SetPosition(s_x, s_y, s_z)
      end
    end
    -- 结束自动播种
  end

  -- 装备/卸下事件
  if inst.components.equippable then
    -- 装备时启动相关任务
    inst:ListenForEvent("equipped", function(_, data)
      inst.hdore = nil
      inst.hdore = data.owner
      if data and data.owner and data.owner:HasTag("player") then
        local doer = data.owner
        -- 装备后补推一次总开关状态（OnPreLoad 时可能还没装备 → netvar 读到旧值）
        SyncMultiStateToClient(doer, nil, inst)
        -- ⭐ 5.6.19：补算绿杖拆解门禁（存档恢复时 all_active 可能晚于 active_gem 落地）
        if ApplyGemAbility ~= nil then ApplyGemAbility(inst) end
        if config.constant_temp_effect_enable then
          -- 先停止可能存在的旧任务（避免重复启动）
          if auto_temp_task then
            auto_temp_task:Cancel()
            auto_temp_task = nil
          end
          -- 启动新的自动温控任务（0.6秒间隔）
          auto_temp_task = inst:DoPeriodicTask(AUTO_TEMP_INTERVAL, function()
            DoAutoTempControl(inst)
          end)
        end
        -- 自动工作：装备时启动（扫描15格，受 enable_slot + auto_work_range 控制）
        if config.auto_work_range > 0 and config.enable_slot then
          if auto_work_task then
            auto_work_task:Cancel()
            auto_work_task = nil
          end
          auto_work_task = inst:DoPeriodicTask(AUTO_WORK_INTERVAL, function()
            DoAutotask(inst)
          end)
        end
        -- 六色法杖能力：独立任务（只受轮盘UI配置 GEM_ENABLED 控制，与扫描15格解耦）
        if GEM_ENABLED then
          if gem_state_task then
            gem_state_task:Cancel()
            gem_state_task = nil
          end
          gem_state_task = inst:DoPeriodicTask(GEM_STATE_INTERVAL, function()
            DoGemStateTask(inst)
          end)
        end
        -- 装备时同步所有右键控制功能状态
        UpdateAllFeatures()
      end
    end)
    -- 卸下时停止相关任务
    inst:ListenForEvent("unequipped", function(_, data)
      if inst._quick_re_equip then return end -- 快速切换卸装中，跳过清理
      if data and data.owner and data.owner:HasTag("player") then
        local doer = data.owner
        -- 自动工作任务清理
        if auto_work_task then
          auto_work_task:Cancel()
          auto_work_task = nil
        end
        -- 六色法杖独立任务清理 + 状态还原
        if gem_state_task then
          gem_state_task:Cancel()
          gem_state_task = nil
        end
        if inst._yellow_light ~= nil and inst._yellow_light:IsValid() then
          inst._yellow_light:Remove()
        end
        inst._yellow_light = nil
        inst._has_redgem = nil
        inst._has_bluegem = nil
        if inst.components.equippable then
          inst.components.equippable.walkspeedmult = 1 + config.speed_buff
        end
        -- 理智/建造恢复默认状态
        if doer.components.sanity then
          doer.components.sanity:SetInducedInsanity(inst, false)
        end
        if doer.components.builder then
          doer.components.builder.ingredientmod = 1
        end

        -- 显示人物
        doer:Show()
        -- 恢复原本科技
        local builder = doer and doer.components.builder
        if builder ~= nil then
          for k, _ in pairs(tech_bonus) do
            builder[string.lower(k) .. "_tempbonus"] = nil
          end
        end
        -- 移除传送功能（如果存在）
        if inst.components.blinkstaff then
          inst:RemoveComponent("blinkstaff")
        end
        -- 手杖呼吸染色清理（防止遗留在玩家身上）
        if doer.AnimState then
          doer.AnimState:SetSymbolMultColour("swap_object", 1, 1, 1, 1)
          doer.AnimState:SetSymbolAddColour("swap_object", 0, 0, 0, 0)
          doer.AnimState:SetAddColour(0, 0, 0, 0) -- 清除全身跑马灯
        end
        -- 右键状态
        if config.multi_tool_state_save then
          -- 卸下时同步所有右键控制功能状态
          UpdateAllFeatures()
        else
          -- 不保存状态时，关闭全部右键控制项
          inst.all_active = false
          SyncCaneState()
          UpdateAllFeatures()
        end
      end
    end)
  end

  -- 2. 物品掉落时的事件
  inst:ListenForEvent("ondropped", function(inst)
    -- 获取掉落前的持有者（通过inventoryitem组件）
    if inst.hdore then
      local doer = inst.hdore
      -- 停止自动温控任务
      if config.constant_temp_effect_enable then
        if auto_temp_task then
          auto_temp_task:Cancel()
          auto_temp_task = nil
        end
      end
      -- 三维恢复
      if doer and doer._original_maxhealth and doer.components.health then
        doer.components.health.maxhealth = doer._original_maxhealth
      end
      if doer and doer._original_maxhunger and doer.components.hunger then
        doer.components.hunger.max = doer._original_maxhunger
      end
      if doer and doer._original_maxsanity and doer.components.sanity then
        doer.components.sanity.max = doer._original_maxsanity
      end
      doer._original_maxhealth = nil
      doer._original_maxhunger = nil
      doer._original_maxsanity = nil
      -- 倍率也一起清：OnSave 守卫只看 _original_*，若倍率残留，
      -- 未装备时存档仍可能把 buff 状态写进去，重登后无任务重算、三维卡在增益值。
      doer._health_mult = nil
      doer._hunger_mult = nil
      doer._sanity_mult = nil
      -- 伤害恢复
      inst._damage_mult = 1
      inst._planardamage_mult = 1
    end
  end)

  -- 销毁清理
  inst:ListenForEvent("onremove", function()
    if auto_harvest_task then
      auto_harvest_task:Cancel()
    end
    if auto_farm_task then
      auto_farm_task:Cancel()
    end
    if auto_work_task then
      auto_work_task:Cancel()
    end
    if gem_state_task then
      gem_state_task:Cancel()
    end
    -- 呼吸染色清理
    StopCaneBreathTint()
    -- 光效清理
    if inst.light_fx then
      inst.light_fx:Remove()
    end
  end)
  -- 结束
end)

-- ============================================================
-- 三维倍率持久化（仿官方 wx78.lua OnSave/OnLoad）
-- 官方 health/hunger/sanity 组件只存 current，不存被 mod 改过的 max；
-- 重登时组件 OnLoad 先把 current 按「默认上限」clamp 掉，实体 OnLoad 在其后执行。
-- 所以这里：① 玩家存档时把倍率/原始上限/current 一起存；
--          ② 实体 OnLoad 里先恢复 max，再直接写回 current（不用 SetMaxHealth，
--             它会把 current 重置成满值）。
-- 字段与 DoAutotask 用的完全一致，读档后定时任务重算得到同一倍率，不会二次改动。
-- ============================================================
-- ⚠️ DST 没有 "player" 预制体（角色都是独立 prefab），AddPrefabPostInit("player") 永不触发；
--    官方 modutil.lua:586 的 AddPlayerPostInit 才是正解（内部 AddPrefabPostInitAny + HasTag("player")）。
AddPlayerPostInit(function(inst)
  if not TheWorld.ismastersim then return end

  local oldOnSave = inst.OnSave
  inst.OnSave = function(inst, data)
    if oldOnSave then oldOnSave(inst, data) end
    if inst._original_maxhealth == nil
        and inst._original_maxhunger == nil
        and inst._original_maxsanity == nil then
      return
    end
    data.hcane_stats = {
      base = {
        health = inst._original_maxhealth,
        hunger = inst._original_maxhunger,
        sanity = inst._original_maxsanity,
      },
      mult = {
        health = inst._health_mult,
        hunger = inst._hunger_mult,
        sanity = inst._sanity_mult,
      },
      current = {
        health = inst.components.health and inst.components.health.currenthealth,
        hunger = inst.components.hunger and inst.components.hunger.current,
        sanity = inst.components.sanity and inst.components.sanity.current,
      },
    }
  end

  local oldOnLoad = inst.OnLoad
  inst.OnLoad = function(inst, data)
    if oldOnLoad then oldOnLoad(inst, data) end
    local saved = data and data.hcane_stats
    if saved == nil or saved.base == nil or saved.mult == nil then return end
    local base, mult, current = saved.base, saved.mult, saved.current

    -- ⚠️ 组件 OnLoad 后，角色自身机制可能已合法改过上限（WX78 电路、Wolfgang 饥饿等），
    --    不能拿旧快照直接覆盖。取 max(角色当前值, 存档 base)：既不降低上限，又能恢复增益。
    --    is_health=true 时上限字段叫 maxhealth，其余组件叫 max。
    local function restore_max(component, is_health, field_original, field_mult, saved_base, saved_mult)
      if saved_base == nil or component == nil then return end
      local current_max = is_health and component.maxhealth or component.max
      local baseline = math.max(current_max or 0, saved_base)
      inst[field_original] = baseline
      inst[field_mult] = saved_mult or 1
      if is_health then
        component.maxhealth = baseline * inst[field_mult]
      else
        component.max = baseline * inst[field_mult]
      end
    end
    restore_max(inst.components.health, true, "_original_maxhealth", "_health_mult",
      base.health, mult.health)
    restore_max(inst.components.hunger, false, "_original_maxhunger", "_hunger_mult",
      base.hunger, mult.hunger)
    restore_max(inst.components.sanity, false, "_original_maxsanity", "_sanity_mult",
      base.sanity, mult.sanity)

    -- 组件 OnLoad 已按默认上限 clamp 过 current，这里直接写回保存值
    if current ~= nil then
      if current.health ~= nil and inst.components.health then
        inst.components.health:SetCurrentHealth(math.min(current.health,
          inst.components.health.maxhealth))
      end
      -- 用 SetCurrent 而不是 DoDelta(0)：后者会被 invincible / is_teleporting 挡掉，
      -- 登录瞬间正好可能在 teleporting 状态，导致 current 写回但不推 netvar。
      if current.hunger ~= nil and inst.components.hunger then
        inst.components.hunger:SetCurrent(current.hunger, true)
      end
      if current.sanity ~= nil and inst.components.sanity then
        inst.components.sanity:SetCurrent(current.sanity)
      end
    end
    if inst.components.health then inst.components.health:ForceUpdateHUD(true) end
  end
end)

--骨头碎片1和犬牙1制作海象牙
if config.enable_walrus_tusk_craft then
  -- TECH.NONE = 不需要任何科技等级；nounlock = 连"先解锁配方"都不要求，直接可做
  AddRecipe2("walrus_tusk", { Ingredient("boneshard", 1), Ingredient("houndstooth", 1) },
    TECH.NONE, { nounlock = true },
    { "REFINE", })

  -- 步行手杖（cane）的另一条制作路线：海象牙 + 黄金 + 木头 + 树枝
  -- ⚠️ 官方原配方是 Recipe2("cane", {goldnugget×2, walrus_tusk×1, twigs×4}, TECH.SCIENCE_TWO)
  -- （scripts/recipes.lua），配方名必须唯一，所以这里用 hcane_walkingcane 作 recipe 名，
  -- 再用 config.product 指定产物为 cane —— 两条配方并存，材料齐哪条就能用哪条。
  AddRecipe2("hcane_walkingcane", {
    Ingredient("walrus_tusk", 1),
    Ingredient("goldnugget", 2),
    Ingredient("log", 1),
    Ingredient("twigs", 2),
  }, TECH.NONE, {
    product = "cane",
    nounlock = true,
    -- ⚠️ 别用 `L`：那是 modinfo 里的局部变量，modmain 里读未声明的全局
    -- 会被 strict 直接报错（"variable 'L' is not declared"）。
    description = "用海象牙与木料制作步行手杖",
  }, { "TOOLS", })

  AddPrefabPostInit("houndbone", function(inst)
    -- 只在服务端生效
    if not TheWorld.ismastersim then
      return inst
    end
    -- 检查是否有掉落物组件，有的话修改掉落配置
    if config.enable_walrus_tusk_drop then
      inst.components.lootdropper:AddChanceLoot("houndstooth", 0.66)
    end
  end)
end

AddPrefabPostInit("walrus", function(inst)
  -- 只在服务端生效
  if not TheWorld.ismastersim then
    return inst
  end
  -- 检查是否有掉落物组件，有的话修改掉落配置
  if config.enable_walrus_tusk_drop then
    inst.components.lootdropper:AddChanceLoot("walrus_tusk", 1.00)
  end
end)

-- 客户端：手杖图标高亮 + "开/关"文字显示
-- 参考 Insight 2189004162 的 Widget 着色方式：直接操纵 ItemTile 的 image:SetTint()
-- 参考 DST 原生潮湿系统：通过标签 + 定期检测来控制 UI 叠加层显示
if not GLOBAL.TheNet:IsDedicated() then
  -- 导入 widget 类（modmain.lua 全局作用域中没有 Text/Image）
  local Text = GLOBAL.require("widgets/text")
  local Image = GLOBAL.require("widgets/image")
  local NUMBERFONT = GLOBAL.NUMBERFONT

  AddClassPostConstruct("widgets/itemtile", function(self, invitem)
    if invitem.prefab ~= "cane" then return end

    -- 添加状态文字（仿照 DST 的堆叠数量/百分比文字系统）
    self._cane_label = self:AddChild(Text(NUMBERFONT, 40))
    self._cane_label:SetPosition(0, -22, 0)
    self._cane_label:Hide()

    -- 文字跑马灯动画（HueToRGB 色相循环）
    local color_cycle_time = 0
    local color_task = nil
    local COLOR_CYCLE_SPEED = 1.6 -- 跑马灯周期（秒，N 秒一圈）

    -- 复制服务端的 HueToRGB（客户端闭包内无法访问服务端 local 函数）
    local function HueToRGB(hue)
      local r = (math.sin(hue) + 1) / 2
      local g = (math.sin(hue + 2.094) + 1) / 2
      local b = (math.sin(hue + 4.189) + 1) / 2
      return r, g, b
    end

    local function StopColorCycle()
      if color_task then
        color_task:Cancel()
        color_task = nil
      end
      color_cycle_time = 0
    end

    local function StartColorCycle()
      StopColorCycle()
      color_task = self.inst:DoPeriodicTask(0.05, function()
        color_cycle_time = color_cycle_time + 0.05
        local hue = color_cycle_time * 2 * math.pi / COLOR_CYCLE_SPEED
        local cr, cg, cb = HueToRGB(hue)

        -- 图标着色（混入白色提亮暗色图标：40%颜色+60%白底）
        self.image:SetTint(cr * 0.4 + 0.6, cg * 0.4 + 0.6, cb * 0.4 + 0.6, 1)

        -- 文字着色（仅当文字可见时）
        if self._cane_label and self._cane_label.shown then
          self._cane_label:SetColour(cr, cg, cb, 1)
        end
      end)
    end

    -- 刷新高亮状态的函数（0.2s 轮询检测 ON/OFF 切换）
    local function UpdateCaneTileHighlight()
      if not self._cane_label or not self.image then return end
      -- ⭐ 5.6.26：优先读手杖自己的 netvar（按实例、含物品栏），
      --    回退 caneon 标签（旧档/客户端未建 netvar 时兼容）。
      local is_on = nil
      if self.item ~= nil and self.item._hcane_multi_net ~= nil then
        is_on = self.item._hcane_multi_net:value() == true
      elseif self.item ~= nil then
        is_on = self.item:HasTag("caneon")
      end
      if is_on == nil then return end
      -- 状态无变化则跳过
      if is_on == self._cane_last_on then return end
      self._cane_last_on = is_on

      if is_on then
        -- 图标着色 + 文字颜色（受 enable_light_fx 控制）
        if config.enable_light_fx then
          self.image:SetTint(0.4, 1, 0.4, 1) -- 初始绿色，跑马灯会接管
          StartColorCycle()
        else
          self.image:SetTint(1, 1, 1, 1)
          StopColorCycle()
        end
        -- 文字（受 cane_icon_text 控制）
        if config.cane_icon_text then
          self._cane_label:SetString("󰀏 开")
          if config.enable_light_fx then
            -- 跑马灯颜色由动画驱动
          else
            self._cane_label:SetColour(1, 1, 1, 1) -- 纯白
          end
          self._cane_label:Show()
        else
          self._cane_label:Hide()
        end
      else
        self.image:SetTint(1, 1, 1, 1)
        StopColorCycle()
        if config.cane_icon_text then
          self._cane_label:SetString("\243\176\128\137 关")  -- 󰀉 鬼魂=关（与轮盘/状态格统一）
          self._cane_label:SetColour(1, 1, 1, 1)
          self._cane_label:Show()
        else
          self._cane_label:Hide()
        end
      end
    end

    -- 立即刷新（后续由服务端快速卸装触发 ItemTile 重建来刷新）
    UpdateCaneTileHighlight()

    -- ===== 六色宝石状态格：挂在手杖自己的 itemtile 上，跟随格子（装备栏/物品栏第几格）=====
    -- ⭐ 仿官方 antlionhat/wx78_inventorycontainer：状态徽标直接作为 itemtile 子 widget，
    --    itemtile 重建时自动跟随到新手杖格子，无需手动坐标换算。
    if GEM_ENABLED then
      local GemStatus = GLOBAL.require("widgets/hcane_gem_status")
      -- ① 左上角角标：只显示当前宝石贴图（无宝石留空），所有手杖都显示。
      self.hcane_gem_corner = self:AddChild(GemStatus(self.owner, true))
      self.hcane_gem_corner:SetPosition(-26, 26, 0)
      self.hcane_gem_corner:SetScale(0.85)
      -- ② 原中心 UI：宝石 / 鬼魂灯泡，只有装备栏手杖显示，同时仍作为轮盘锚点。
      self.hcane_gem_status = self:AddChild(GemStatus(self.owner))
      self.hcane_gem_status:SetPosition(0, 88, 0)
      self.hcane_gem_status:SetScale(1.25)

      -- ⭐ 5.6.29：只有「装备栏手杖」显示中心 UI 并写轮盘锚点；物品栏手杖只保留角标。
      --    ⚠️ ItemTile 可能在 HUD.controls 赋值前创建（Controls:ctor 还没返回），
      --       所以延迟 + 重试，避免锚点永远写不进去。
      local function SetDialAnchor(tries)
        tries = tries or 0
        if self.hcane_gem_status == nil then return end
        local hud = GLOBAL.ThePlayer ~= nil and GLOBAL.ThePlayer.HUD or nil
        local controls = hud ~= nil and hud.controls or nil
        if controls == nil then
          if tries < 20 and self.inst ~= nil and self.inst:IsValid() then
            self.inst:DoTaskInTime(0.1, function() SetDialAnchor(tries + 1) end)
          end
          return
        end
        -- 官方 itemtile.lua:472 同款判定：客户端 replica.equippable:IsEquipped()
        local equipped = self.item ~= nil and self.item.replica ~= nil
            and self.item.replica.equippable ~= nil
            and self.item.replica.equippable:IsEquipped() == true or false
        if equipped then
          controls.hcane_gem_anchor = self.hcane_gem_status
          self.hcane_gem_status:Show()
        else
          if controls.hcane_gem_anchor == self.hcane_gem_status then
            controls.hcane_gem_anchor = nil
          end
          self.hcane_gem_status:Hide()
        end
      end
      SetDialAnchor()
      -- 装备/卸下不一定重建 ItemTile：每 0.5s 复核一次装备状态，锚点不会留在物品栏手杖上
      self._hcane_anchor_task = self.inst:DoPeriodicTask(0.5, function()
        if self.hcane_gem_status ~= nil then SetDialAnchor() end
      end)

      -- ⭐ 5.6.26：状态从「这把 itemtile 对应的手杖实例」读，不再读玩家级 classified。
      --    多手杖/物品栏手杖各有自己的 netvar，切换互不串；dirty 事件直接驱动刷新，
      --    不再依赖"装备时快速卸装重建 ItemTile"（那条路对物品栏手杖无效）。
      local function RefreshGemStatus()
        if self.hcane_gem_status == nil and self.hcane_gem_corner == nil then return end
        local v = self.item ~= nil and self.item._hcane_gem_net ~= nil
            and self.item._hcane_gem_net:value() or nil
        local gem_key = v ~= nil and v ~= "" and v or nil
        local m = self.item ~= nil and self.item._hcane_multi_net ~= nil
            and self.item._hcane_multi_net:value() == true or false
        if self.hcane_gem_status ~= nil then
          self.hcane_gem_status:SetGem(gem_key)
          self.hcane_gem_status:SetMulti(m)
        end
        if self.hcane_gem_corner ~= nil then
          self.hcane_gem_corner:SetGem(gem_key)
          self.hcane_gem_corner:SetMulti(m)
        end
        -- 开关文字也按这把手杖自己的状态刷新（物品栏手杖同样生效）
        UpdateCaneTileHighlight()
      end
      self._hcane_gem_refresh = RefreshGemStatus
      local function BindGemStatus(tries)
        tries = tries or 0
        local item = self.item
        if item == nil or item._hcane_gem_net == nil then
          -- 物品实例/netvar 可能晚到，重试（上限 60=6 秒）
          if tries < 60 and self.inst ~= nil and self.inst:IsValid() then
            self.inst:DoTaskInTime(0.1, function() BindGemStatus(tries + 1) end)
          end
          return
        end
        self.inst:ListenForEvent("hcaneCaneGemDirty", RefreshGemStatus, item)
        if item._hcane_multi_net ~= nil then
          self.inst:ListenForEvent("hcaneCaneMultiDirty", RefreshGemStatus, item)
        end
        RefreshGemStatus()
      end
      BindGemStatus()
    end

    -- 清理
    self.inst:ListenForEvent("onremove", function()
      StopColorCycle()
      if self._hcane_anchor_task then
        self._hcane_anchor_task:Cancel()
        self._hcane_anchor_task = nil
      end
      if self._cane_label then
        self._cane_label:Kill(); self._cane_label = nil
      end
      -- 只清自己写入的锚点，避免 ItemTile 重建时误清新 tile 的锚点
      local hud = GLOBAL.ThePlayer ~= nil and GLOBAL.ThePlayer.HUD or nil
      local controls = hud ~= nil and hud.controls or nil
      if controls ~= nil and self.hcane_gem_status ~= nil
          and controls.hcane_gem_anchor == self.hcane_gem_status then
        controls.hcane_gem_anchor = nil
      end
      self.hcane_gem_status = nil   -- 让延迟中的 SetDialAnchor 重试自行终止
      self.hcane_gem_corner = nil
    end)
  end)

  -- ============================================================
  -- 客户端：六色宝石轮盘（红=点燃 / 绿=拆解）
  -- ⚠️ 与 hslot 轮盘同款防穿透：绝不用 SetModFocus（连 WASD 一起禁），
  --    只在 PlayerController:OnControl 里按命中吞鼠标左右键，down/up 成对。
  -- ============================================================
  if GEM_ENABLED then
    local GemDial = GLOBAL.require("widgets/hcane_gem_dial")

    AddClassPostConstruct("components/playercontroller", function(self)
      local old_OnControl = self.OnControl
      self._hcane_gem_dial_swallowed = {}
      function self:OnControl(control, down)
        if control == GLOBAL.CONTROL_PRIMARY or control == GLOBAL.CONTROL_SECONDARY then
          local which = (control == GLOBAL.CONTROL_PRIMARY) and "primary" or "secondary"
          if down then
            local owner = GLOBAL.ThePlayer
            local hud = owner ~= nil and owner.HUD or nil
            local dial = hud ~= nil and hud.controls ~= nil and hud.controls.hcane_gem_dial or nil
            local hit = false
            if dial ~= nil and dial:IsVisible() and dial.HitTest ~= nil then
              local sp = GLOBAL.TheInput:GetScreenPosition()
              hit = dial:HitTest(sp.x, sp.y) ~= nil
            end
            self._hcane_gem_dial_swallowed[which] = hit
            if hit then return true end   -- 只挡世界输入，WASD 继续有效
          else
            -- up 无条件清标志，避免焦点切换丢 up 后永久多吞一次
            local was = self._hcane_gem_dial_swallowed[which]
            self._hcane_gem_dial_swallowed[which] = false
            if was then return true end
          end
        end
        return old_OnControl(self, control, down)
      end
    end)

    AddClassPostConstruct("widgets/controls", function(self)
      -- ⚠️ 绝不挂 bottomright_root：它是 ANCHOR_RIGHT+BOTTOM，(0,0) 在屏幕右下角，
      --    默认正偏移 (230,40) 会直接跑出屏幕右侧 → 轮盘"创建了但看不见"。
      --    改挂 containerroot.parent（自带 MIDDLE 锚点，(0,0)=屏幕正中），
      --    与 hslot 大容器面板同款：自建 root + SetHUDScale + hook SetHUDSize。
      --    本轮盘点击/拖动全走 TheInput 坐标判定，不依赖 ImageButton 焦点，挂这里没问题。
      local Widget = GLOBAL.require("widgets/widget")
      local root = self.containerroot.parent
      self.hcane_gem_root = root:AddChild(Widget("hcane_gem_root"))
      self.hcane_gem_root:SetScale(GLOBAL.TheFrontEnd:GetHUDScale())
      -- ⭐ 5.6.18：物品栏 bottom_root 在 controls.lua:508 晚于 containerroot 创建，
      --    默认轮盘被物品栏盖在后面（截图"宝石在 UI 后面"）。MoveToFront 让轮盘
      --    渲染在物品栏之上；点击/命中仍走 TheInput 坐标判定，不依赖焦点。
      self.hcane_gem_root:MoveToFront()
      local old_SetHUDSize = self.SetHUDSize
      function self:SetHUDSize(...)
        if self.hcane_gem_root ~= nil then
          self.hcane_gem_root:SetScale(GLOBAL.TheFrontEnd:GetHUDScale())
        end
        return old_SetHUDSize(self, ...)
      end

      self.hcane_gem_dial = self.hcane_gem_root:AddChild(GemDial(
        GEM_UNLOCK_REQUIRED,
        function(key)
          SendModRPCToServer(MOD_RPC["hcane_gem"]["unlock"], key)
        end,
        function(key)
          SendModRPCToServer(MOD_RPC["hcane_gem"]["set_active"], key)
        end,
        function()
          SendModRPCToServer(MOD_RPC["hcane_gem"]["toggle_multi"])
        end,
        -- ⭐ 5.6.29：装备栏手杖变化时后台请求重推状态，修切换手杖轮盘全黑
        function()
          SendModRPCToServer(MOD_RPC["hcane_gem"]["refresh_state"])
        end
      ))
      -- 位置由 widget 构造统一处理（存档优先 + 出屏回正中），这里不再 SetPosition
      -- ⭐ 宝石状态格已移到手杖 itemtile 上（跟随格子），见上方 itemtile hook。
    end)
  end
end
