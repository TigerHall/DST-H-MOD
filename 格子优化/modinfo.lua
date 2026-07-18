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
version = "3.2"
description = en_zh("V" .. version .. [[

Items in Chester's and Hutch's grids do not spoil. Items in Shadow Chester's grid spoil at an accelerated rate, while items in Ice Chester's grid are preserved (remain fresh).
Items in Chester's and Hutch's grids can be stacked infinitely.
The red moon eye can open the shadow space, and the green moon eye can open the poaching rabbit space. Eyebone and Fishbowl can also open the rabbit space by inspecting.
The shadow space and the poaching rabbit space can be set with infinite stacking, corruption acceleration, and anti-fresh acceleration.
Trading feature added -- try trading various items with eyebone/fishbowl to discover hidden recipes!
Blue moon eye opens an pocket space (4x4 slots)!
Purple, orange, yellow moon eyes each open a pocket space (5x4 slots)!
Yellow/Orange/Purple moon eyes can reveal set piece locations on the map!
Open map and double-left-click moon eyes/sentry/moondial/townportal/players to teleport with fade transition!
]], "V" .. version .. [[

切斯特、哈奇格子内物品不腐败，暗影切斯特格子腐败加速，冰雪切斯特反鲜。
切斯特、哈奇格子可无限堆叠。
带孔月岩可传送到眼骨或星空处；打开地图左键双击月眼/哨塔/月晷/传送门/玩家可传送（有过场动画）。
黄色、橙色、紫色月眼可在地图揭示重要布景位置。
红色月眼可打开暗影空间，绿色月眼可打开挖角兔空间。眼骨和星空右键检查也可打开挖角兔空间。
暗影空间和挖角兔空间可设置无限堆叠，腐败加速和反鲜加速。
新增交易功能——尝试向眼骨或星空提交各种物品，发现隐藏配方彩蛋吧！
蓝色月眼可打开格子空间（4x4 格子）！
紫色、橙色、黄色月眼可各打开一个格子空间（5x4 格子）！
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
    "统一控制切斯特、哈奇以及各月眼空间的保鲜/腐败行为",
    "Unified control of preservation/decay behavior for Chester, Hutch, and moon eye pocket spaces",
    "普通切斯特/哈奇及月眼空间停止腐败，冰雪切斯特反鲜，暗影切斯特加速腐败",
    "Chester, Hutch, and moon eye pocket spaces stop decaying; Ice Chester preserves freshness; Shadow Chester accelerates decay",
    "不改变切斯特/哈奇及月眼空间的保鲜/腐败特性",
    "No change to preservation/decay for Chester, Hutch, or moon eye pocket spaces"
  ),
  -- 合并的无限堆叠设置
  addTitle("Infinite Stack", "无限堆叠设置"),
  addConfig(
    "infinite_stack",
    "切斯特与哈奇无限堆叠",
    "Chester & Hutch Infinite Stack",
    true,
    "统一控制切斯特、哈奇以及各月眼空间的物品堆叠数量",
    "Unified control of item stack quantity for Chester, Hutch, and moon eye pocket spaces",
    "切斯特、哈奇及月眼空间所有格子物品堆叠数量无上限",
    "All grid item stack quantities have no upper limit for Chester, Hutch, and moon eye pocket spaces",
    "不改变切斯特、哈奇及月眼空间的物品堆叠数量限制",
    "No change to item stack quantity limits for Chester, Hutch, or moon eye pocket spaces"
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
    "眼骨/星空拥有更高的血量、防御，更快的速度，不易被摧毁",
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
    "带孔月岩点击检查触发传送 + 地图左键双击月眼/玩家传送（有过场动画）",
    "Moonrockcrater click teleport + map double-left-click teleport to moon eyes/players (with fade transition)",
    "点击带孔月岩传送到眼骨/星空；打开地图左键双击月眼/哨塔/月晷/传送门/玩家可直接传送",
    "Click moonrockcrater to teleport to eyebone/hutch; open map and double-left-click moon eyes or players to teleport",
    "不改变带孔月岩，禁用地图传送",
    "No change to moonrockcrater, disable map teleport"
  ),
  -- 各色月眼开关宠物格子功能配置
  addConfig(
    "colormooneye_toggle",
    "各色月眼开关格子",
    "Color Moon Eye Toggle Container",
    true,
    "通过各色月眼来开关各种格子",
    "Whether to allow toggling container by inspecting color moon eye",
    "右键各色月眼时会开关各种格子",
    "Right-click color moon eye will toggle pet container",
    "禁用各色月眼的格子开关功能",
    "Disable color moon eye's pet container toggle function"
  ),
  addConfig(
    "mooneye_map_reveal",
    "月眼地图揭示布景位置",
    "Moon Eye Map Reveal Set Piece",
    true,
    "黄/橙/紫色月眼可在地图揭示一些重要位置（各玩家仅首次生效）",
    "Yellow/Orange/Purple moon eyes reveal important locations on the map (one-time per player)",
    "右键月眼时标示重要位置并移除迷雾（与开箱子互不冲突）",
    "Right-click reveals important locations on map and removes fog of war (works alongside container toggle)",
    "月眼保持原功能",
    "Moon eye keeps original function"
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
  addTitle("Auto Collect Settings", "自动收集设置"),
  -- 眼骨/星空自动收集范围配置
  {
    name = "auto_get_range",
    label = en_zh("Eye-bone/Star-sky Auto Collect Range", "眼骨/星空自动收集范围"),
    hover = en_zh("How far you can Eye-bone/Star-sky Auto Collect", "眼骨/星空可以自动收集多远"),
    options = {
      { description = "0", data = 0, hover = en_zh("No Auto Collect", "不自动采集") },
      { description = "6", data = 6.6, hover = en_zh("One and A Half Turfs Radius", "1.5个地皮远") },
      { description = "10", data = 10.6, hover = en_zh("2.5 * Turfs Radius", "2.5个地皮远") },
      { description = "16", data = 16.6, hover = en_zh("4 * Turfs Radius", "4个地皮远") },
      { description = "20", data = 20.6, hover = en_zh("5 * Turfs Radius", "5个地皮那么远") },
    },
    default = 6.6
  },
  addTitle("Repair Settings", "自动修复设置"),
  addConfig(
    "repair_to_full",
    "容器内物品整理修复",
    "Container Sort & Repair",
    true,
    "绿眼容器整理并修复至100%，红眼容器整理并降级至6%",
    "Green: sort + repair to 100%. Red: sort + degrade to 6%.",
    "开启整理修复/降级按钮",
    "Enable sort & repair/degrade button",
    "隐藏整理修复/降级按钮",
    "Hide sort & repair/degrade button"
  ),
  addConfig(
    "auto_sort_repair",
    "定时整理修复",
    "Auto Sort & Repair",
    false,
    "每6秒自动排序并修复(绿眼)/降级(红眼)容器内物品",
    "Every 6s auto sort + repair(green)/degrade(red) items",
    "开启定时整理修复",
    "Enable timed sort & repair",
    "关闭定时整理修复",
    "Disable timed sort & repair"
  ),
}
