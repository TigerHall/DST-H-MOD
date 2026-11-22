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
version = "4.0"
description = en_zh("V" .. version .. [[
󰀏 Your backpack wants a bigger home!

󰀞 Chester & Hutch: never spoil
󰀂 Stacking? No limits here
󰀒 4 moon eyes = 160-slot vaults
󰀏 Right-drag, middle-click, H key
󰀀 Red = shadow, green = rabbit
󰀐 Pig King, Glommer, wormholes
󰀰 Eyebone trades & fetches drops
󰀄 Green repairs, red ages gear
Every feature has a switch 󰀏
]], "V" .. version .. [[
󰀏 你的背包想要更大的房子！

󰀞 切斯特/哈奇：永不腐败
󰀂 堆叠？没有上限
󰀒 四色月眼：160 格滚动仓库
󰀏 右键拖动/中键归位/H 秒开
󰀀 红眼暗影，绿眼兔子窝
󰀐 猪王/格罗姆/虫洞地图跳
󰀰 眼骨星空：兑换+捡漏
󰀄 绿眼修复，红眼做旧
功能都能单独开关 󰀏
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
    "带孔月岩点击传送 + 地图左键双击月眼/地标/虫洞/玩家跳转（有过场动画）",
    "Moonrockcrater click teleport + map double-click teleport to moons/landmarks/wormholes/players (with fade)",
    "点击带孔月岩传送到眼骨/星空；地图上左键双击月眼/哨塔/月晷/制作站/猪王/格罗姆雕像/虫洞/玩家可直接跳转",
    "Click moonrockcrater to teleport; map double-left-click moons, pig king, statueglommer, wormholes, players to teleport",
    "不改变带孔月岩，禁用地图传送",
    "No change to moonrockcrater, disable map teleport"
  ),
  -- ⭐ 官方同款地图动效（独立开关，与双击传送分离）
  addConfig(
    "map_teleport_fx",
    "地图传送指示动效",
    "Map Teleport FX",
    true,
    "打开地图后，鼠标移到可传送点上显示官方同款旋转光环；传送仍用左键双击。两者独立",
    "Official-style rotating ring on hover over map teleport points; teleport via double-click. Independent",
    "开启：鼠标放到可传送点上显示旋转光圈（移开消失，平时只显示目标原图标）",
    "On: rotating ring appears on hover over teleport points (fades on leave, target icons stay normal)",
    "关闭：只用左键双击传送，地图无额外动效",
    "Off: double-click only, no extra map effects"
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
  addTitle("Hotkey", "快捷键"),
  addConfig(
    "pocket_hotkey",
    "快捷键 H 开关切斯特轮盘 UI",
    "Hotkey H toggles Chester dial UI",
    true,
    "按 H 显示/隐藏切斯特月眼轮盘（整个图标 UI）。与「切斯特月眼轮盘图标」组合：都关则 UI 不显示也无法唤出；图标关但 H 开，可按 H 唤出。",
    "Press H to show/hide the Chester moon-eye dial (whole icon UI). Combined with the dial option: both off means no UI and no way to open; dial off + H on lets H summon it.",
    "开启（默认）：H 可开关轮盘 UI 显示",
    "On (default): H toggles dial UI visibility",
    "关闭：H 不响应轮盘 UI",
    "Off: H does not affect the dial UI"
  ),
  addConfig(
    "chester_dial",
    "切斯特月眼轮盘图标",
    "Chester moon-eye dial icon",
    true,
    "画面右下角常驻切斯特小图标，点击张嘴后插入宝石开关六色月眼空间",
    "A small Chester icon at bottom-right; click to open its mouth and pick a gem to toggle six moon-eye spaces",
    "开启（默认）：显示切斯特图标，点击弹出六色宝石轮盘",
    "On (default): show Chester icon, click to open the six-gem dial",
    "关闭：图标默认隐藏；若「H 快捷键」开启可按 H 唤出，两者都关则完全不显示",
    "Off: icon hidden by default; if H hotkey is on, press H to summon it; both off means no UI at all"
  ),
  addTitle("Debug", "调试"),
  addConfig(
    "vault_debug",
    "月眼仓库诊断日志",
    "Vault debug logging",
    false,
    "排查与其他 MOD 的兼容问题时临时打开；正常游玩请关闭",
    "Turn on only when troubleshooting mod compatibility",
    "开启：打开月眼仓库时在日志里输出容器信息",
    "On: log container info when opening the vault",
    "关闭（默认）：不输出",
    "Off (default): silent"
  ),
}
