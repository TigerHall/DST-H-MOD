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
version = "0.9"
description = en_zh("V" .. version .. [[

Items in Chester's and Hutch's grids do not spoil. Items in Shadow Chester's grid spoil at an accelerated rate, while items in Ice Chester's grid are preserved (remain fresh).
Items in Chester's and Hutch's grids can be stacked infinitely.
The red moon eye can open the shadow space, and the green moon eye can open the poaching rabbit space. The shadow space and the poaching rabbit space can be set with infinite stacking, corruption acceleration, and anti-fresh acceleration.
]], "V" .. version .. [[

切斯特、哈奇格子内物品不腐败，暗影切斯特格子腐败加速，冰雪切斯特反鲜。
切斯特、哈奇格子可无限堆叠。
带孔月岩可传送到眼骨或星空处。
红色月眼可打开暗影空间，绿色月眼可打开挖角兔空间。暗影空间和挖角兔空间可设置无限堆叠，腐败加速和反鲜加速。
]])
author = "hehu"
api_version = 10
dst_compatible = true
all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "Infinite Slot", "无限格子", "Chester", "切斯特" }

configuration_options = {
  -- 合并的保鲜/腐败设置
  addTitle("Preservation Settings", "保鲜/腐败设置"),
  addConfig(
    "preserve_settings",
    "切斯特与哈奇保鲜/腐败",
    "Chester & Hutch Preservation",
    true,
    "统一控制切斯特和哈奇的保鲜/腐败行为",
    "Unified control of preservation/decay behavior for Chester and Hutch",
    "普通切斯特和哈奇停止腐败，冰雪切斯特反鲜，暗影切斯特加速腐败",
    "Chester and Hutch stop decaying, Ice Chester prevents freshness loss, and Shadow Chester accelerates decaying.",
    "不改变切斯特和哈奇的保鲜/腐败特性",
    "No change to preservation/decay characteristics of Chester and Hutch"
  ),
  -- 合并的无限堆叠设置
  addTitle("Infinite Stack", "无限堆叠设置"),
  addConfig(
    "infinite_stack",
    "切斯特与哈奇无限堆叠",
    "Chester & Hutch Infinite Stack",
    true,
    "统一控制切斯特和哈奇的物品堆叠数量",
    "Unified control of item stack quantity for Chester and Hutch",
    "切斯特和哈奇所有格子物品堆叠数量无上限",
    "All grid item stack quantities have no upper limit for Chester and Hutch",
    "不改变切斯特和哈奇的物品堆叠数量限制",
    "No change to item stack quantity limits for Chester and Hutch"
  ),
  -- 新增：宠物强化设置
  addTitle("Pet Enhancement", "宠物强化设置"),
  addConfig(
    "pet_strong",
    "眼骨/星空强化",
    "Eye-bone/Star-sky Entity Enhancement",
    true,
    "增强眼骨/星空相关的属性（血量、防御等）",
    "Enhance attributes (health, defense, etc.) of Eye-bone/Star-sky related entities",
    "眼骨/星空拥有更高的血量、防御，不易被摧毁",
    "Eye-bone/Star-sky entities have higher health and defense, making them harder to destroy",
    "眼骨/星空保持原版属性不变",
    "Eye-bone/Star-sky entities retain their original attributes"
  ),
  addTitle("Mooneye Sets", "月眼设置"),
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
  -- 紫色月眼开关宠物格子功能配置
  addConfig(
    "colormooneye_toggle",
    "各色月眼开关格子",
    "Color Moon Eye Toggle Container",
    true,
    "通过各色月眼来开关各种格子",
    "Whether to allow toggling container by inspecting color moon eye",
    "点击各色月眼时会开关各种格子",
    "Clicking color moon eye will toggle pet container",
    "禁用各色月眼的格子开关功能",
    "Disable color moon eye's pet container toggle function"
  ),
  addTitle("Trade Settings", "物品交易设置"),
  addConfig(
    "item_trade_function",
    "眼骨/星空交易功能",
    "Eye-bone/Star-sky Item Exchange",
    true,
    "控制眼骨/星空实体的物品兑换交易功能",
    "Item exchange By Eye-bone/Star-sky",
    "通过眼骨/星空兑换彩虹宝石、启迪碎片等物品",
    "Exchange Iridescent Gem, Enlightened Shard Or Something Else By Eye-bone/Star-sky",
    "禁用眼骨/星空交易功能",
    "Disables item exchange By Eye-bone/Star-sky"
  ),
}
