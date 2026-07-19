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
version = "1.8"

-- 动态版本号展示
local ver_line = "V" .. version .. "\n"
local en_desc = ver_line .. [[
Cartography Desk enhancement: all 6 supported paper types (blueprint / recipe card / sketch / pirate map / fish tackle advert / costume pattern) are instantly re-craftable from papyrus at any cartography desk. Uniform icons per type. Static pre-registration; reads official game data tables at load time. Mod recipes with _blueprint prefabs are auto-supported. Erase-unlock hook interface reserved.
]]
local zh_desc = ver_line .. [[
制图桌强化：6 种指定纸（蓝图/食谱卡/草图/海盗地图/渔具广告/礼服款式）均可在制图桌上消耗 papyrus 直接制作。每种类型统一图标。加载时从官方数据表静态预注册；Mod 配方如果注册了 _blueprint prefab 自动支持。预留擦除解锁接口。
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
}
