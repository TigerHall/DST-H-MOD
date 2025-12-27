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

--  基础信息
name = en_zh("H-FOOD", "H-零食增强")
version = "0.2"
description = en_zh("V" .. version .. [[

The attributes of winter snacks and Halloween candies are doubled.󰀫
]], "V" .. version .. [[

冬季零食、万圣节零食属性翻倍󰀫。
]])
author = "hehu"
api_version = 10
dst_compatible = true
all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "winter food", "糖果" }

configuration_options = {
  -- 基础配置项
  -- addTitle("Basic Function Configurations", "基本功能"),
  -- addConfig(
  --   "halloween_candy_switch",
  --   "Halloween Candy Attribute Boost Switch", "万圣节糖果属性增强开关",
  --   true,
  --   "Control whether to enable the Halloween candy attribute boost function", "控制是否开启万圣节糖果属性增强功能",
  --   "Enabled: Halloween candy attributes will be boosted by the set multiplier", "已开启：万圣节糖果属性将按倍率增强",
  --   "已禁用：万圣节糖果属性保持默认", "Disabled: Halloween candy attributes remain default"
  -- ),

  addTitle("Multiplier Settings", "倍率设置"),
  -- 冬季食物属性翻倍倍率
  {
    name = "冬季食物",
    label = en_zh("Winter Food Attribute Multiplier", "冬季食物属性翻倍倍率"),
    hover = en_zh("0 means no change to winter food attributes", "0为不变化"),
    options = {
      { description = "0", data = 0, hover = en_zh("No change to winter food attributes", "不改变冬季食物属性") },
      { description = "6󰀫", data = 6, hover = en_zh("Increased by 6x, like real snacks", "属性翻了6倍，这才像真正的小零食") },
      { description = "16󰀫", data = 16, hover = en_zh("Increased by 16x, almost like a meal", "属性翻了16倍，都快像正餐了") },
      { description = "36󰀫", data = 36, hover = en_zh("Increased by 36x, a pretty good food", "属性翻了36倍，比较好的食物了") },
      { description = "66󰀫", data = 66, hover = en_zh("Increased by 66x, like sugar beans", "属性翻了66倍，堪比小糖豆") },
      { description = "126󰀫", data = 216, hover = en_zh("Increased by 126x, invincible", "属性翻了126倍，无敌了") },
    },
    default = 16
  },
  -- 万圣节糖果属性翻倍倍率
  {
    name = "万圣节糖果",
    label = en_zh("Halloween Candy Attribute Multiplier", "万圣节糖果属性翻倍倍率"),
    hover = en_zh("0 means no change to Halloween Candy attributes", "0为不变化"),
    options = {
      { description = "0", data = 0, hover = en_zh("No change to Halloween Candy attributes", "不改变冬季食物属性") },
      { description = "6󰀫", data = 6, hover = en_zh("Increased by 6x, like real snacks", "属性翻了6倍，这才像真正的小零食") },
      { description = "16󰀫", data = 16, hover = en_zh("Increased by 16x, almost like a meal", "属性翻了16倍，都快像正餐了") },
      { description = "36󰀫", data = 36, hover = en_zh("Increased by 36x, a pretty good food", "属性翻了36倍，比较好的食物了") },
      { description = "66󰀫", data = 66, hover = en_zh("Increased by 66x, like sugar beans", "属性翻了66倍，堪比小糖豆") },
      { description = "126󰀫", data = 216, hover = en_zh("Increased by 126x, invincible", "属性翻了126倍，无敌了") },
    },
    default = 6
  },
}
