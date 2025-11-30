-- 先获取当前游戏语言（放在配置项前面）
local L = locale ~= "zh" and locale ~= "zhr"

name = L and "H-Enhanced backpack" or "H-背包强化"
description = L
    and
    "V1.5\n\nAll features can be turned on or off in the configuration options.\n\nSince backpacks and armor share the same equipment slot, it only makes sense for backpacks to provide armor effects too—including physical defense and planar defense. And if they have armor, why not add a counterattack ability as well?\n\nIt’s reasonable for a backpack to offer some insulation to keep you warm. If it can keep you warm, regaining a bit of Sanity (mental health) isn’t too much to ask. And if it helps with Sanity, shouldn’t it also protect you from rain? After all, raincoats share the same slot too.\n\nAdditionally, backpacks now have the ability to automatically collect nearby items on the ground (only picks up items that already exist in the backpack), freeing up your hands. Since they can auto-collect items, allowing infinite stack sizes for items inside feels perfectly logical!\n\nallow players to craft Krampus Sack (Need Stag Antler)\n\nThe Seed Pouch comes with the maximum tier of bonuses by default—after all, I’m a farming player. Farmers shouldn’t be disturbed… I’m just an old farmer tending to my crops."
    or
    "V1.5.1\n\n所有功能均可在配置项开启或关闭\n\n既然背包和护甲都在一个格子，那么就让背包也有护甲效果很合理吧。包括物理防御和位面防御。既然有护甲了，那是不是也应该可以反击呢？\n\n背包背着，有点保暖效果合理吧。能保暖了，回点SAN也不过分吧。能回san，那是不是不应该被雨淋了？毕竟雨衣也在这个格子里。\n\n另外增加自动采集地上物品到背包的能力（物品在背包中已存在才捡起），解放双手。都自动拣起地上的东西了，那东西可以无限堆叠很合理吧。\n\n可制作坎普斯背包（需要麋鹿茸）。\n\n种子袋默认是最强的一档，毕竟我是个种田玩家，种田的人不应该被打扰，我是个老农。"
author = "hehu"
version = "1.5.1"
api_version = 10
dst_compatible = true
all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "backpack", "背包", "Krampus Sack", "坎普斯背包" }
--优先级调高(刚好压过Insight)
priority = -10001

-- 通用开关配置函数（开关类型）
local function addToggleConfig(
    name,
    ch_label,
    en_label,
    default,
    ch_hover,
    en_hover,
    ch_on_hover,
    en_on_hover,
    ch_off_hover,
    en_off_hover
)
  return {
    name = name,
    label = L and en_label or ch_label,
    hover = L and en_hover or ch_hover,
    options = {
      {
        description = L and "On" or "开启",
        data = true,
        hover = L and en_on_hover or ch_on_hover
      },
      {
        description = L and "Off" or "禁用",
        data = false,
        hover = L and en_off_hover or ch_off_hover
      }
    },
    default = default
  }
end

-- 分段标题生成函数
local function addTitle(title)
  return {
    name = title:upper(),
    label = title,
    hover = nil,
    options = { { description = "", data = 0 } },
    default = 0,
    tags = { "ignore" }
  }
end

-- 背包参数表（集中管理所有背包信息，方便后续添加/修改）
local backpack_params = {
  { prefab = "backpack", ch_name = "普通背包", en_name = "Backpack", def_default = 0.66, planar_default = 1.6, collect_default = true, insulate_default = 0, infinite_stack_default = false, waterproof_default = false, sanity_default = 6, counter_dmg_default = 0, preserve_default = false, },
  { prefab = "piggyback", ch_name = "猪皮包", en_name = "Piggyback", def_default = 0.86, planar_default = 6.6, collect_default = true, insulate_default = 66, infinite_stack_default = false, waterproof_default = false, sanity_default = 16, counter_dmg_default = 16, preserve_default = false, },
  { prefab = "icepack", ch_name = "保鲜背包", en_name = "Insulated Pack", def_default = 0.86, planar_default = 9.6, collect_default = true, insulate_default = 126, infinite_stack_default = false, waterproof_default = true, sanity_default = 36, counter_dmg_default = 36, preserve_default = true, },
  { prefab = "krampus_sack", ch_name = "坎普斯背包", en_name = "Krampus Sack", def_default = 0.96, planar_default = 66, collect_default = true, insulate_default = 246, infinite_stack_default = true, waterproof_default = true, sanity_default = 66, counter_dmg_default = 66, preserve_default = true, },
  { prefab = "seedpouch", ch_name = "种子袋", en_name = "Seed Pack-It", def_default = 1, planar_default = 126, collect_default = true, insulate_default = 366, infinite_stack_default = true, waterproof_default = true, sanity_default = 126, counter_dmg_default = 126, preserve_default = true, },
  { prefab = "candybag", ch_name = "糖果袋", en_name = "Candy Bag", def_default = 0.16, planar_default = 1.6, collect_default = true, insulate_default = 0, infinite_stack_default = true, waterproof_default = false, sanity_default = 0, counter_dmg_default = 0, preserve_default = false, },
  { prefab = "spicepack", ch_name = "厨师袋", en_name = "Chef Pouch", def_default = 0.16, planar_default = 1.6, collect_default = true, insulate_default = 0, infinite_stack_default = true, waterproof_default = false, sanity_default = 0, counter_dmg_default = 0, preserve_default = false, },
}

-- 生成防御配置项
local function createDefenseConfig(param)
  return {
    name = param.prefab .. "_defense",
    label = L and (param.en_name .. " Defense") or (param.ch_name .. "的防御能力设置"),
    hover = L and ("Grants your " .. param.en_name .. " damage reduction") or ("让你的" .. param.ch_name .. "拥有防御减免"),
    options = {
      { description = "0", data = 0, hover = L and "No defense" or "没有防御能力" },
      { description = "16", data = 0.16, hover = L and "16% damage reduction" or "16%的普通伤害减免，心理安慰？" },
      { description = "36", data = 0.36, hover = L and "36% damage reduction" or "36%的普通伤害减免，这么低也没啥用吧" },
      { description = "66", data = 0.66, hover = L and "66% reduction, like Grass Suit" or "66%伤害减免，和草甲差不多" },
      { description = "86", data = 0.86, hover = L and "86% reduction, like Log Suit, now mobs are just tickling you" or "86%减免，和木甲差不多，现在怪物只能给你挠痒痒了" },
      { description = "96", data = 0.96, hover = L and "96% reduction, like Marble Suit, even fight? Just let them hit you" or "96%减免，大理石甲常驻，还怕打啥架啊？让它们随便捶就完事儿了" },
      { description = "100", data = 1, hover = L and "100% reduction, Invincible" or "100%减免，物理无敌了" }
    },
    default = param.def_default
  }
end

-- 生成位面防御配置项
local function createPlanarDefenseConfig(param)
  return {
    name = param.prefab .. "_planardefense",
    label = L and (param.en_name .. " Planar Defense") or (param.ch_name .. "的位面防御设置"),
    hover = L and ("Sets planar damage reduction for " .. param.en_name) or ("设置" .. param.ch_name .. "的位面伤害减免"),
    options = {
      { description = "0", data = 0, hover = L and "No planar defense" or "没有位面防御" },
      { description = "1.6", data = 1.6, hover = L and "planar defense 1.6" or "位面防御值1.6" },
      { description = "6.6", data = 6.6, hover = L and "planar defense 6.6" or "位面防御值6.6" },
      { description = "9.6", data = 9.6, hover = L and "planar defense 9.6" or "位面防御值9.6" },
      { description = "16", data = 16, hover = L and "planar defense 16" or "位面防御值16" },
      { description = "26", data = 26, hover = L and "planar defense 26" or "位面防御值26" },
      { description = "36", data = 36, hover = L and "planar defense 36" or "位面防御值36" },
      { description = "66", data = 66, hover = L and "planar defense 66" or "位面防御值66" },
      { description = "126", data = 126, hover = L and "planar defense 126" or "位面防御值126" },
    },
    default = param.planar_default
  }
end

-- 生成回san配置项（精神恢复速率）
local function createSanityConfig(param)
  return {
    name = param.prefab .. "_sanity",
    label = L and (param.en_name .. " Sanity Restore") or (param.ch_name .. "的回san设置"),
    hover = L and ("Sets sanity restoration rate for " .. param.en_name) or ("设置" .. param.ch_name .. "的精神恢复速率"),
    options = {
      { description = "0", data = 0, hover = L and "No sanity restoration" or "无精神恢复" },
      { description = "6", data = 6, hover = L and "Slow restoration" or "缓慢恢复精神" },
      { description = "16", data = 16, hover = L and "Moderate restoration" or "中等速度恢复精神" },
      { description = "36", data = 36, hover = L and "Fast restoration" or "快速恢复精神" },
      { description = "66", data = 66, hover = L and "Very fast restoration" or "极快恢复精神" },
      { description = "126", data = 126, hover = L and "Very Very fast restoration" or "超极快恢复精神" },
    },
    default = param.sanity_default
  }
end

-- 新增保温配置项生成函数
local function createInsulateConfig(param)
  return {
    name = param.prefab .. "_insulate",
    label = L and (param.en_name .. " Insulation") or (param.ch_name .. "的保温能力设置"),
    hover = L and ("Sets insulation value for " .. param.en_name) or ("设置" .. param.ch_name .. "的保温值"),
    options = {
      { description = "0", data = 0, hover = L and "No insulation" or "无保温效果" },
      { description = "66", data = 66, hover = L and "Insulation 66" or "保温值66" },
      { description = "126", data = 126, hover = L and "Insulation 126" or "保温值126" },
      { description = "246", data = 246, hover = L and "Insulation 246" or "保温值246" },
      { description = "366", data = 366, hover = L and "Insulation 366" or "保温值366" },
    },
    default = param.insulate_default
  }
end

-- 修改防雨配置项生成函数（改为开关型）
local function createWaterproofConfig(param)
  return addToggleConfig(
    param.prefab .. "_waterproof",
    param.ch_name .. "完全防雨",
    param.en_name .. " Perfect Waterproof",
    param.waterproof_default,
    "是否开启" .. param.ch_name .. "的完全防雨效果",
    "Whether to enable perfect waterproof for " .. param.en_name,
    param.ch_name .. "提供100%防雨效果",
    param.en_name .. " provides 100% waterproof",
    param.ch_name .. "无防雨效果",
    param.en_name .. " has no waterproof effect"
  )
end

-- 新增反击伤害配置项生成函数
local function createCounterDmgConfig(param)
  return {
    name = param.prefab .. "_counter_dmg",
    label = L and (param.en_name .. " Counter Damage") or (param.ch_name .. "反击伤害"),
    hover = L and ("Sets counter attack damage for " .. param.en_name) or ("设置" .. param.ch_name .. "的反击伤害值"),
    options = {
      { description = "0", data = 0, hover = L and "No counter attack" or "不开启反击" },
      { description = "6", data = 6, hover = L and "Counter damage 6" or "反击伤害6点" },
      { description = "16", data = 16, hover = L and "Counter damage 16" or "反击伤害16点" },
      { description = "36", data = 36, hover = L and "Counter damage 36" or "反击伤害36点" },
      { description = "66", data = 66, hover = L and "Counter damage 66" or "反击伤害66点" },
      { description = "126", data = 126, hover = L and "Counter damage 126" or "反击伤害126点" },
    },
    default = param.counter_dmg_default
  }
end

-- 新增保鲜开关配置项生成函数
local function createPreserveConfig(param)
  return addToggleConfig(
    param.prefab .. "_preserve",
    param.ch_name .. "保鲜功能",
    param.en_name .. " Preserve Function",
    param.preserve_default,
    "是否开启" .. param.ch_name .. "的保鲜功能（食物永不腐烂）",
    "Whether to enable preserve function for " .. param.en_name .. " (food never spoils)",
    param.ch_name .. "内食物永不腐烂",
    param.en_name .. " keeps food from spoiling",
    param.ch_name .. "内食物正常腐烂",
    param.en_name .. " food spoils normally"
  )
end

-- 生成自动采集配置项
local function createCollectConfig(param)
  return addToggleConfig(
    param.prefab .. "_collect",
    param.ch_name .. "自动采集",
    param.en_name .. " Auto-Collect",
    param.collect_default,
    "是否启用" .. param.ch_name .. "自动采集地上物品",
    "Whether to enable " .. param.en_name .. " auto-collect items on ground",
    param.ch_name .. "会自动采集地上物品（仅限背包中已存在的类型）",
    param.en_name .. " auto-collects items on ground (only existing types)",
    param.ch_name .. "不自动采集地上物品",
    param.en_name .. " does not auto-collect items"
  )
end

-- 新增无限堆叠配置项生成函数
local function createInfiniteStackConfig(param)
  return addToggleConfig(
    param.prefab .. "_infinite_stack",
    param.ch_name .. "无限堆叠",
    param.en_name .. " Infinite Stack",
    param.infinite_stack_default,
    "是否允许" .. param.ch_name .. "内物品无限堆叠",
    "Whether to allow infinite stack size in " .. param.en_name,
    param.ch_name .. "内物品可以无限堆叠",
    param.en_name .. " allows infinite stack size for items",
    param.ch_name .. "内物品保持默认堆叠上限",
    param.en_name .. " keeps default stack size limits"
  )
end

configuration_options = {
  -- 背包防御配置组
  addTitle(L and "Backpack Defense" or "背包防御能力"),
  createDefenseConfig(backpack_params[1]), -- 普通背包
  createDefenseConfig(backpack_params[2]), -- 猪皮包
  createDefenseConfig(backpack_params[3]), -- 保鲜背包
  createDefenseConfig(backpack_params[4]), -- 坎普斯背包
  createDefenseConfig(backpack_params[5]), -- 种子袋
  createDefenseConfig(backpack_params[6]), -- 糖果袋
  createDefenseConfig(backpack_params[7]), -- 厨师袋

  -- 位面防御配置组
  addTitle(L and "Planar Defense" or "位面防御能力"),
  createPlanarDefenseConfig(backpack_params[1]), -- 普通背包
  createPlanarDefenseConfig(backpack_params[2]), -- 猪皮包
  createPlanarDefenseConfig(backpack_params[3]), -- 保鲜背包
  createPlanarDefenseConfig(backpack_params[4]), -- 坎普斯背包
  createPlanarDefenseConfig(backpack_params[5]), -- 种子袋
  createPlanarDefenseConfig(backpack_params[6]), -- 糖果袋
  createPlanarDefenseConfig(backpack_params[7]), -- 厨师袋

  -- 反击伤害配置组
  addTitle(L and "Counter Attack Settings" or "反击伤害设置"),
  createCounterDmgConfig(backpack_params[1]), -- 普通背包
  createCounterDmgConfig(backpack_params[2]), -- 猪皮包
  createCounterDmgConfig(backpack_params[3]), -- 保鲜背包
  createCounterDmgConfig(backpack_params[4]), -- 坎普斯背包
  createCounterDmgConfig(backpack_params[5]), -- 种子袋
  createCounterDmgConfig(backpack_params[6]), -- 糖果袋
  createCounterDmgConfig(backpack_params[7]), -- 厨师袋

  -- 保温配置组
  addTitle(L and "Insulation Settings" or "保温能力设置"),
  createInsulateConfig(backpack_params[1]), -- 普通背包
  createInsulateConfig(backpack_params[2]), -- 猪皮包
  createInsulateConfig(backpack_params[3]), -- 保鲜背包
  createInsulateConfig(backpack_params[4]), -- 坎普斯背包
  createInsulateConfig(backpack_params[5]), -- 种子袋
  createInsulateConfig(backpack_params[6]), -- 糖果袋
  createInsulateConfig(backpack_params[7]), -- 厨师袋

  -- 防雨配置组（开关型）
  addTitle(L and "Waterproof Settings" or "防雨能力设置"),
  createWaterproofConfig(backpack_params[1]),
  createWaterproofConfig(backpack_params[2]),
  createWaterproofConfig(backpack_params[3]),
  createWaterproofConfig(backpack_params[4]),
  createWaterproofConfig(backpack_params[5]),
  createWaterproofConfig(backpack_params[6]),
  createWaterproofConfig(backpack_params[7]),

  -- 回san配置组
  addTitle(L and "Sanity Restoration" or "精神恢复设置"),
  createSanityConfig(backpack_params[1]), -- 普通背包
  createSanityConfig(backpack_params[2]), -- 猪皮包
  createSanityConfig(backpack_params[3]), -- 保鲜背包
  createSanityConfig(backpack_params[4]), -- 坎普斯背包
  createSanityConfig(backpack_params[5]), -- 种子袋
  createSanityConfig(backpack_params[6]), -- 糖果袋
  createSanityConfig(backpack_params[7]), -- 厨师袋

  -- 自动采集配置组
  addTitle(L and "Auto-Collect Settings" or "自动采集设置"),
  createCollectConfig(backpack_params[1]), -- 普通背包
  createCollectConfig(backpack_params[2]), -- 猪皮包
  createCollectConfig(backpack_params[3]), -- 保鲜背包
  createCollectConfig(backpack_params[4]), -- 坎普斯背包
  createCollectConfig(backpack_params[5]), -- 种子袋
  createCollectConfig(backpack_params[6]), -- 糖果袋
  createCollectConfig(backpack_params[7]), -- 厨师袋

  -- 保鲜功能配置组
  addTitle(L and "Preserve Settings" or "保鲜功能设置"),
  createPreserveConfig(backpack_params[1]), -- 普通背包
  createPreserveConfig(backpack_params[2]), -- 猪皮包
  createPreserveConfig(backpack_params[3]), -- 保鲜背包
  createPreserveConfig(backpack_params[4]), -- 坎普斯背包
  createPreserveConfig(backpack_params[5]), -- 种子袋
  createPreserveConfig(backpack_params[6]), -- 糖果袋
  createPreserveConfig(backpack_params[7]), -- 厨师袋

  -- 无限堆叠配置组
  addTitle(L and "Infinite Stack Settings" or "无限堆叠设置"),
  createInfiniteStackConfig(backpack_params[1]), -- 普通背包
  createInfiniteStackConfig(backpack_params[2]), -- 猪皮包
  createInfiniteStackConfig(backpack_params[3]), -- 保鲜背包
  createInfiniteStackConfig(backpack_params[4]), -- 坎普斯背包
  createInfiniteStackConfig(backpack_params[5]), -- 种子袋
  createInfiniteStackConfig(backpack_params[6]), -- 糖果袋
  createInfiniteStackConfig(backpack_params[7]), -- 厨师袋

  -- 其他设置标题
  addTitle(L and "Other" or "其他"),
  -- 坎普斯背包可制作开关
  addToggleConfig(
    "krampus_sack_craft",
    "坎普斯背包可制作",
    "Krampus Sack Craftable",
    true,
    "是否允许玩家制作坎普斯背包（需要麋鹿茸）",
    "Whether to allow players to craft Krampus Sack (Need Stag Antler)",
    "允许制作坎普斯背包",
    "Allows crafting Krampus Sack",
    "禁止制作坎普斯背包",
    "Disables crafting Krampus Sack"
  ),
}
