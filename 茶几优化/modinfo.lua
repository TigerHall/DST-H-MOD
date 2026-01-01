-- 先获取当前游戏语言（放在配置项前面）
local L = locale ~= "zh" and locale ~= "zhr"

-- 优化后的开关配置函数（增加开启/关闭的hover提示）
local function addConfig(
    name,
    ch_label,
    en_label,
    default,
    ch_hover,
    en_hover,
    ch_on_hover,  -- 开启选项的中文hover
    en_on_hover,  -- 开启选项的英文hover
    ch_off_hover, -- 关闭选项的中文hover
    en_off_hover) -- 关闭选项的英文hover
  return {
    name = name,
    label = L and en_label or ch_label,
    hover = L and en_hover or ch_hover,
    options = {
      {
        description = L and "On" or "开启",
        data = true,
        hover = L and en_on_hover or ch_on_hover -- 开启选项的提示
      },
      {
        description = L and "Off" or "禁用",
        data = false,
        hover = L and en_off_hover or ch_off_hover -- 关闭选项的提示
      }
    },
    default = default
  }
end

-- 添加分段标题
local function addTitle(title)
  return {
    name = title:upper(),
    label = title,
    hover = nil,
    options = {
      { description = "", data = 0 }
    },
    default = 0,
    tags = { "ignore" }
  }
end

--  基础信息
name = L and "H-Table Enhancement" or "H-茶几强化"
version = "1.6"
description =
    L and
    ("V" .. version .. "\n\nEnd Table Enhancement Mod: it can prevent the coffee table from being destroyed by BOSS and allow it to serve as a blocking device. It can make flowers last longer.\n\nThe bird in the cage lives forever.\n\nSalt lick block has infinite durability.Ticoon enhanced.") or
    ("V" .. version .. "\n\n茶几强化mod，可以让茶几无法被BOSS摧毁，能作为卡位装置。可通过燃烧去除，燃烧后会立刻消失。可以让花朵更长期存在。\n\n鸟笼内的鸟永久存活。\n\n牛牛的舔盐块无限耐久。\n\n大虎获得强化效果。\n\n麻刺节点不阻碍放置。")
author = "hehu"
api_version = 10
dst_compatible = true
all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "End Table", "茶几" }

--优先级调高(刚好压过Insight)
priority = -19

configuration_options = {
  -- 基础配置项
  addTitle(L and "Endtable Configurations" or "茶几功能"),
  -- 茶几防BOSS摧毁+卡位功能开关配置
  addConfig(
    "endtable_immune",
    "茶几防BOSS摧毁与卡位",
    "End Table BOSS Immunity & Block",
    true,
    "控制茶几是否能抵御BOSS攻击且作为卡位装置",
    "Control whether the end table can resist BOSS attacks and act as a blocking device",
    "茶几不会被BOSS摧毁，且可作为卡位障碍阻挡BOSS移动，可通过燃烧移除",
    "The end table cannot be destroyed by BOSS and can be used as a blocking obstacle to stop BOSS movement. It can be removed by burning.",
    "不做修改",
    "No change"
  ),
  -- 茶几花朵枯萎时间配置
  addConfig(
    "endtable_flower_wilt",
    "茶几花朵枯萎时间",
    "End Table Flower Wilt Time",
    true,
    "控制茶几上的花朵是否极大延长枯萎时间",
    "Control whether the flowers on the end table have a greatly extended wilt time",
    "茶几上的花朵枯萎时间极大延长",
    "The wilt time of the flowers on the end table is greatly extended",
    "不做修改",
    "No change"
  ),
  addTitle(L and "Birdcage Configurations" or "鸟笼功能"),
  -- 鸟笼不腐败配置
  addConfig(
    "birdcage_immortal",
    "鸟笼内的鸟永久存活",
    "Birdcage Bird Immortal",
    true,
    "控制鸟笼内的鸟是否永远不会死亡或消失",
    "Control whether the bird in the birdcage will never die or disappear",
    "鸟笼内的鸟将永久存在，不会因任何原因死亡或消失",
    "The bird in the birdcage will exist permanently and will not die or disappear for any reason",
    "不做修改，鸟笼内的鸟遵循原版机制",
    "No change, the bird in the birdcage follows the original mechanism"
  ),
  addTitle(L and "Saltlick Configurations" or "无限舔盐块功能"),
  -- 舔盐块耐久无限配置
  addConfig(
    "saltlick_unlimited",
    "舔盐块耐久无限",
    "Saltlick Unlimited Uses",
    true,
    "控制舔盐块是否拥有无限耐久",
    "Control whether the saltlick has unlimited durability",
    "舔盐块耐久无限，不会因舔食而消耗",
    "The saltlick has unlimited durability and will not be consumed by licking",
    "不做修改，舔盐块遵循原版机制",
    "No change, the saltlick follows the original mechanism"
  ),
  addTitle(L and "Ticoon Configurations" or "大虎强化"),
  -- 大虎强化配置
  addConfig(
    "ticoon_enhance",
    "大虎强化",
    "Ticoon Enhancement",
    true,
    "控制大虎是否获得强化效果",
    "Control whether Ticoon gets enhancement effects",
    "大虎获得强化效果：更高的生命值、更快的移动速度、更强的攻击力",
    "Ticoon gets enhancement effects: higher health, faster movement speed, stronger attack power",
    "不做修改，大虎遵循原版机制",
    "No change, Ticoon follows the original mechanism"
  ),
  addTitle(L and "Fence Electric Configurations" or "麻刺节点强化"),
  -- 麻刺节点强化配置
  addConfig(
    "fence_electric_enhance",
    "麻刺节点强化",
    "Fence Electric Enhancement",
    true,
    "控制麻刺节点是否获得强化效果",
    "Control whether Fence Electric gets enhancement effects",
    "麻刺节点获得强化效果：不阻碍放置",
    "Fence Electric gets enhancement effects: higher health, faster movement speed, stronger attack power",
    "不做修改，麻刺节点遵循原版机制",
    "No change, Fence Electric follows the original mechanism"
  ),
}
