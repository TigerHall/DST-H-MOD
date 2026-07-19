-- 中英双语支持
local function en_zh(en, zh)
    return (locale == "zh" or locale == "zhr" or locale == "zht") and zh or en
end

-- 开关配置函数（中英文）
local function addConfig(
    name,
    label_en, label_zh,
    default,
    hover_en, hover_zh,
    on_hover_en, on_hover_zh,
    off_hover_en, off_hover_zh)
    return {
        name = name,
        label = en_zh(label_en, label_zh),
        hover = en_zh(hover_en, hover_zh),
        options = {
            {
                description = en_zh("On", "开启"),
                data = true,
                hover = en_zh(on_hover_en, on_hover_zh)
            },
            {
                description = en_zh("Off", "禁用"),
                data = false,
                hover = en_zh(off_hover_en, off_hover_zh)
            }
        },
        default = default
    }
end

-- 添加分段标题（标题文本直接通过en_zh传入）
local function addTitle(title_en, title_zh)
    return {
        name = en_zh(title_en, title_zh):upper(),
        label = en_zh(title_en, title_zh),
        hover = nil,
        options = {
            { description = "", data = 0 }
        },
        default = 0,
        tags = { "ignore" }
    }
end

-- 基础信息
name = en_zh("H-Cartography Desk Enhancement", "H-制图桌强化")
author = "hehu"
version = "1.9"

-- 动态版本号展示
local ver_line = "V" .. version .. "\n"
local en_desc = ver_line .. [[
Cartography Desk enhancement: all 6 supported paper types (blueprint / recipe card / sketch / pirate map / fish tackle advert / costume pattern) are re-craftable from papyrus at any cartography desk. Recipes are locked by default; erase the corresponding paper to unlock (world-persistent, shared across all desks). Optional random blueprint / random recipe card recipes (configurable). Uniform icons per type.
]]
local zh_desc = ver_line .. [[
制图桌强化：6 种指定纸（蓝图/食谱卡/草图/海盗地图/渔具广告/礼服款式）均可在制图桌上消耗 papyrus 重新制作。配方默认锁定，需擦除对应纸张解锁（世界级持久化，所有制图桌共享）。可选的随机蓝图/随机食谱卡配方（配置项控制）。每种类型统一图标。
]]
description = en_zh(en_desc, zh_desc)

api_version = 10
dst_compatible = true
all_clients_require_mod = true
client_only_mod = false

icon_atlas = "modicon.xml"
icon = "modicon.tex"

configuration_options = {
    addTitle("Basic Settings", "基础设置"),
    addConfig(
        "enabled",
        "Enable cartography desk recycling", "启用制图桌回收",
        true,
        "Toggle the whole mod on/off.", "开启或关闭整个 MOD。",
        "Mod active.", "MOD 已启用。",
        "Mod disabled.", "MOD 已禁用。"
    ),
    {
        name = "papyrus_cost",
        label = en_zh("Papyrus cost for re-craft", "重制所需 papyrus 数量"),
        options = {
            { description = en_zh("1 sheet", "1 张"), data = 1, result = "1" },
            { description = en_zh("2 sheets", "2 张"), data = 2, result = "2" },
            { description = en_zh("3 sheets", "3 张"), data = 3, result = "3" },
        },
        default = 2,
    },
    addTitle("Random Recipes", "随机配方"),
    addConfig(
        "enable_random",
        "Enable random blueprint / recipe card", "启用随机蓝图/食谱卡",
        true,
        "Add directly-available recipes that consume papyrus to produce a random blueprint or recipe card.",
        "增加直接可用的配方，消耗 papyrus 产出随机蓝图或食谱卡。",
        "Random recipes available.", "随机配方已启用。",
        "Random recipes disabled.", "随机配方已禁用。"
    ),
    {
        name = "random_cost",
        label = en_zh("Papyrus cost for random recipe", "随机配方消耗 papyrus 数量"),
        options = {
            { description = en_zh("1 sheet", "1 张"), data = 1, result = "1" },
            { description = en_zh("3 sheets", "3 张"), data = 3, result = "3" },
            { description = en_zh("5 sheets", "5 张"), data = 5, result = "5" },
            { description = en_zh("10 sheets", "10 张"), data = 10, result = "10" },
        },
        default = 5,
    },
    addConfig(
        "randombp_all",
        "Include ALL blueprints (station/character/etc.)", "随机蓝图包含全部类型（制造站/角色专属等）",
        false,
        "When enabled, random blueprint can generate ANY recipe that has a _blueprint prefab, ignoring official restrictions (station recipes, character-specific, etc.).", "开启后随机蓝图可以从所有有 _blueprint prefab 的配方中随机生成，不限制制造站/角色专属等官方限制。",
        "All blueprints available.", "全部蓝图可用。",
        "Only official subset.", "仅官方子集。"
    ),
}
