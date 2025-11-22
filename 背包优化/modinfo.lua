-- 先获取当前游戏语言（放在配置项前面）
local L = locale ~= "zh" and locale ~= "zhr"

name = L and "H-Enhanced backpack With defense" or "H-背包强化带护甲和采集能力"
description = L
    and
    "V1.1\nEnhanced backpacks with defense and auto-collect features. Since backpacks and armors share the same slot, backpacks now provide armor effects as well.\nAdditionally, backpacks can automatically collect nearby items on the ground, freeing up your hands.\nallow players to craft Krampus Sack (Need Stag Antler)"
    or "V1.2\n既然背包和护甲都在一个格子，那么就让背包也有护甲效果很合理吧。\n另外增加自动采集地上物品到背包的能力（物品在背包中已存在才捡起），解放双手。\n可制作坎普斯背包（需要麋鹿茸）"
author = "hehu"
version = "1.2"
api_version = 10
dst_compatible = true
all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "backpack", "背包", "Krampus Sack", "坎普斯背包" }

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
  { prefab = "backpack", ch_name = "普通背包", en_name = "Backpack", def_default = 0.66, planar_default = 1.6, collect_default = true },
  { prefab = "piggyback", ch_name = "猪皮包", en_name = "Piggyback", def_default = 0.86, planar_default = 6.6, collect_default = true },
  { prefab = "icepack", ch_name = "保鲜背包", en_name = "Insulated Pack", def_default = 0.86, planar_default = 9.6, collect_default = true },
  { prefab = "krampus_sack", ch_name = "坎普斯背包", en_name = "Krampus Sack", def_default = 0.96, planar_default = 16, collect_default = true },
  { prefab = "seedpouch", ch_name = "种子袋", en_name = "Seed Pack-It", def_default = 0.66, planar_default = 1.6, collect_default = true },
  { prefab = "candybag", ch_name = "糖果袋", en_name = "Candy Bag", def_default = 0.66, planar_default = 1.6, collect_default = true },
  { prefab = "spicepack", ch_name = "厨师袋", en_name = "Chef Pouch", def_default = 0.66, planar_default = 1.6, collect_default = true },
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
      { description = "99.96", data = 0.9996, hover = L and "99.96% reduction, Invincible" or "99.96%减免，无敌了" }
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
    },
    default = param.planar_default
  }
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

  -- 自动采集配置组
  addTitle(L and "Auto-Collect Settings" or "自动采集设置"),
  createCollectConfig(backpack_params[1]), -- 普通背包
  createCollectConfig(backpack_params[2]), -- 猪皮包
  createCollectConfig(backpack_params[3]), -- 保鲜背包
  createCollectConfig(backpack_params[4]), -- 坎普斯背包
  createCollectConfig(backpack_params[5]), -- 种子袋
  createCollectConfig(backpack_params[6]), -- 糖果袋
  createCollectConfig(backpack_params[7]), -- 厨师袋

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
