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
version = "2.1"

-- 动态版本号展示
local ver_line = "V" .. version .. "\n"
local en_desc = ver_line .. [[
Erasable paper recycling & random blueprint crafting at the cartography desk.
- Erase any paper (blueprint/recipe card/sketch/pirate map/fishing advert/costume pattern) to unlock its reissue recipe — world-persistent, shared across all desks.
- Read a blueprint to personally unlock its reissue recipe.
- Optional random blueprint / random recipe card / draw-known-blueprint recipes (configurable).
]]
local zh_desc = ver_line .. [[
制图桌擦拭回收 & 随机蓝图制作。
- 擦除 6 种纸（蓝图/食谱卡/草图/海盗地图/渔具广告/礼服款式）→ 解锁对应的重制配方（世界持久化，全服共享）。
- 阅读蓝图 → 个人解锁该蓝图的重制配方。
- 可选的随机蓝图/随机食谱卡/绘制已知蓝图配方（配置项控制）。
]]
description = en_zh(en_desc, zh_desc)

api_version = 10
dst_compatible = true
all_clients_require_mod = true
client_only_mod = false

icon_atlas = "modicon.xml"
icon = "modicon.tex"

configuration_options = {
    addTitle("Erase & Blueprint Reading → Reissue Recipes", "擦除/阅读蓝图 → 重制配方"),
    addConfig(
        "enabled",
        "Enable paper recycling", "启用纸张回收",
        true,
        "Toggle erasing/reading to unlock reissue recipes.", "开启/关闭擦除/阅读解锁重制配方功能。",
        "Recycling enabled.", "回收已启用。",
        "Recycling disabled.", "回收已禁用。"
    ),
    {
        name = "papyrus_cost",
        label = en_zh("Papyrus cost for re-craft", "重制所需莎草纸"),
        options = {
            { description = en_zh("1", "1 张"), data = 1, result = "1" },
            { description = en_zh("2", "2 张"), data = 2, result = "2" },
            { description = en_zh("3", "3 张"), data = 3, result = "3" },
        },
        default = 2,
    },
    addTitle("Random Blueprint / Recipe Card / Known Blueprint", "随机蓝图/食谱卡/已知蓝图"),
    addConfig(
        "enable_random",
        "Enable random recipes", "启用随机配方",
        true,
        "Add directly-available random blueprint, random recipe card, and draw-known-blueprint recipes.",
        "增加直接可用的随机蓝图、随机食谱卡、绘制已知蓝图配方。",
        "Random recipes enabled.", "随机配方已启用。",
        "Random recipes disabled.", "随机配方已禁用。"
    ),
    {
        name = "random_cost",
        label = en_zh("Papyrus cost for random recipe", "随机配方消耗莎草纸"),
        options = {
            { description = en_zh("1", "1 张"), data = 1, result = "1" },
            { description = en_zh("3", "3 张"), data = 3, result = "3" },
            { description = en_zh("5", "5 张"), data = 5, result = "5" },
            { description = en_zh("10", "10 张"), data = 10, result = "10" },
        },
        default = 5,
    },
    addConfig(
        "randombp_all",
        "Include ALL blueprint types", "蓝图包含全部类型",
        false,
        "When on, random blueprint can generate ANY recipe with _blueprint prefab (station/character/etc).",
        "开启后随机蓝图可以从所有 _blueprint prefab 配方中随机生成（制造站/角色专属等）。",
        "All blueprints included.", "包含全部蓝图。",
        "Only official filter.", "仅官方过滤。"
    ),
}
