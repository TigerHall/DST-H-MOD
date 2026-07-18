-- 中英双语支持
local function en_zh(en, zh)
  return (locale == "zh" or locale == "zhr" or locale == "zht") and zh or en
end

-- 优化后的开关配置函数（增加开启/关闭的hover提示）
local function addConfig(
    name,
    label_zh, label_en,
    default,
    hover_zh, hover_en,
    on_hover_zh, on_hover_en,
    off_hover_zh, off_hover_en)
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

-- 添加分段标题
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

name = en_zh("H-Return Items", "H-离线返还")
version = "1.0"
description = en_zh(
  "V" .. version .. [[

When a player goes offline, their items are held safely.
If they do not return within the configured grace period (in-game days),
all their items are placed into a return chest at their last position.
Players who rejoin within the grace period get their items back automatically.
]],
  "V" .. version .. [[

其他玩家离线后，其身上的物品会被安全托管。
若其在配置的天数（宽限期）内没有回归，
所有物品会在其离开的坐标生成「归还箱」返还。
宽限期内重新上线的玩家，物品会自动原样归还。
]])
author = "hehu"
api_version = 10
dst_compatible = true
all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "Offline Return", "离线返还", "Return Chest", "归还箱" }

configuration_options = {
  addTitle("Return Settings", "返还设置"),
  addConfig(
    "return_enable",
    "启用离线返还",
    "Enable Offline Return",
    true,
    "离线玩家物品托管与到期生成归还箱的总开关",
    "Master switch for holding offline players' items and spawning return chests",
    "启用：离线物品托管 + 到期生成归还箱",
    "Enable: hold offline items + spawn return chest on expiry",
    "禁用：完全不接管离线玩家物品（原版行为）",
    "Disable: do not touch offline players' items (vanilla behavior)"
  ),
  {
    name = "return_grace_days",
    label = en_zh("Grace Period (Days)", "宽限期（天）"),
    hover = en_zh(
      "Number of in-game days an offline player can be away before their items are returned via a chest",
      "离线玩家离开多少游戏天后，物品通过箱子返还"),
    options = {
      { description = "5",  data = 5,  hover = en_zh("5 天", "5 days") },
      { description = "10", data = 10, hover = en_zh("10 天", "10 days") },
      { description = "15", data = 15, hover = en_zh("15 天", "15 days") },
      { description = "30", data = 30, hover = en_zh("30 天", "30 days") },
    },
    default = 10
  },
}
