-- 中英双语支持
local function en_zh(en, zh)
  return (locale == "zh" or locale == "zhr" or locale == "zht") and zh or en
end

-- 优化后的开关配置函数（增加开启/关闭的hover提示）
local function addConfig(
    name,
    label_zh, label_en,         -- 配置项名称（中文，英文）
    default,
    hover_zh, hover_en,         -- 配置项整体hover提示（中文，英文）
    on_hover_zh, on_hover_en,   -- 开启选项hover（中文，英文）
    off_hover_zh, off_hover_en) -- 关闭选项hover（中文，英文）
  return {
    name = name,
    label = en_zh(label_en, label_zh), -- 使用en_zh函数切换显示文本
    hover = en_zh(hover_en, hover_zh),
    options = {
      {
        description = en_zh("On", "开启"), -- 固定选项文本也用en_zh处理
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
name = en_zh("H-SLOT", "H-无限格子")
description = en_zh([[
V0.5
Chester Perish Quickly, Ice Chester resists spoilage. Infinite stacking of slots. Moonrockcrater Teleport Function.
]], [[
V0.5.1
切斯特腐败加速（冰雪切斯特反鲜）、格子无限堆叠，带孔月岩传送功能。
]])
author = "hehu"
version = "0.5.1"
api_version = 10
dst_compatible = true
all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "Infinite Slot", "无限格子", "Chester", "切斯特" }

configuration_options = {
  -- 基础配置项
  addTitle("Chester Perish Quickly", "切斯特腐败/反鲜加成"),
  -- 切斯特腐败加速
  addConfig(
    "chester_preserver",
    "切斯特腐败/反鲜加成",
    "Chester Preserver Perish Quickly or Ice Resists",
    true,
    "切斯特腐败加成",
    "Chester perish quickly",
    "切斯特腐败速度提升为正常的16倍",
    "Chester's perish speed is increased to 16 times normal",
    "不改变切斯特腐败速度",
    "No change to Chester's preservation speed"
  ),
  -- 暗影切斯特腐败加速
  addConfig(
    "shadow_chester_preserver",
    "暗影切斯特腐败加成",
    "Shadow Chester perish quickly",
    true,
    "暗影切斯特（暗影容器）腐败加成",
    "Shadow Chester (shadow container) perish quickly",
    "暗影切斯特腐败速度提升为正常的36倍",
    "Shadow Chester's perish speed is increased to 36 times normal",
    "不改变暗影切斯特腐败速度",
    "No change to Shadow Chester's preservation speed"
  ),
  -- 切斯特/暗影切斯特格子无限堆叠
  addConfig(
    "chester_infinite_stack",
    "切斯特无限堆叠",
    "Chester infinite stack",
    true,
    "切斯特物品栏无限堆叠",
    "Chester inventory infinite stack",
    "切斯特所有格子物品堆叠数量无上限",
    "Chester all grid item stack quantity has no upper limit",
    "不改变切斯特格子堆叠数量限制",
    "No change to Chester original item stack quantity limit"
  ),
  addTitle("Hutch Settings", "哈奇设置"),
  -- 哈奇不腐败开关
  addConfig(
    "hutch_preserver",
    "哈奇防腐功能",
    "Hutch Preserve Function",
    true,
    "哈奇物品防腐功能设置",
    "Hutch preservation function settings",
    "哈奇内物品不会腐败",
    "Items in Hutch will not perish",
    "不改变哈奇的腐败速度",
    "No change to Hutch's preservation speed"
  ),
  -- 哈奇无限堆叠
  addConfig(
    "hutch_infinite_stack",
    "哈奇无限堆叠",
    "Hutch Infinite Stack",
    true,
    "哈奇物品栏无限堆叠",
    "Hutch inventory infinite stack",
    "哈奇所有格子物品堆叠数量无上限",
    "Hutch all grid item stack quantity has no upper limit",
    "不改变哈奇格子堆叠数量限制",
    "No change to Hutch original item stack quantity limit"
  ),
  addTitle("Other", "其他设置"),
  -- 带孔月岩传送功能配置
  addConfig(
    "moonrockcrater_teleport",
    "带孔月岩传送功能",
    "Moonrockcrater Teleport Function",
    true,
    "带孔月岩点击检查触发传送功能",
    "Moonrockcrater click inspect to trigger teleport function",
    "点击带孔月岩可传送到眼骨/星空位置",
    "Check moonrockcrater to teleport to the eyebone/hutch location",
    "不改变带孔月岩",
    "No change to moonrockcrater"
  ),
}
