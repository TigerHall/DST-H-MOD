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
name = en_zh("H-test", "H-测试")
version = "0.7.6"

-- 动态版本号展示
local ver_line = "V" .. version .. "\n"
local en_desc = ver_line .. [[
for test 󰀫
]]
local zh_desc = ver_line .. [[
测试用󰀫。请勿订阅！

阿比盖尔 󰀜 炼金引擎 󰀝 红色骷髅头 󰀀 背包 󰀞
战斗 󰀘 皮弗娄牛 󰀁 蜂箱 󰀟 浆果丛 󰀠 胡萝卜 󰀡
箱子 󰀂 切斯特 󰀃 烹饪锅 󰀄 煎蛋 󰀢 巨鹿眼球 󰀅
眼球草 󰀣 假牙 󰀆 农田 󰀇 火 󰀈 篝火 󰀤 肌肉手臂 󰀙
绚烂之门 󰀰 鬼魂 󰀉 金子 󰀚 坟墓 󰀊 火腿棒 󰀋
锤子 󰀌 心脏 󰀍 牛角 󰀥 饥饿值 󰀎 灯泡 󰀏
大肉 󰀦 猪头 󰀐 大便 󰀑 红宝石 󰀒 白色钻石 󰀧
试金石 󰀱 盐瓶 󰀨 大脑 󰀓 科学机器 󰀔 魔法二本 󰀩
铲子 󰀪 骷髅头 󰀕 点赞 󰀫 魔术帽 󰀖 火炬 󰀛 捕兔陷阱 󰀬
奖杯 󰀭 手 󰀮 蜘蛛网 󰀗 虫洞 󰀯

…·•°◌☉● 点
⬅⬆⬇➡⇐⇒←↑→↓↖↗↘↙⇦⇧⇨⇩☜☝☞☟♲♺♻ 箭头
☀☁☂☃★☆✿❀☖☗☯♀♂⚠♨ 混合
♠♡♢♣♤♥♦♧♩♪♫♬░▒▓ 混合
]]
description = en_zh(en_desc, zh_desc)
author = "hehu"

api_version = 10
dst_compatible = true
all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "test", "测试" }

configuration_options = {
  -- 基础配置项
  addTitle("󰀯Basic Function Configurations", "󰀯基本功能"),
  addConfig(
    "hsee_enable",
    "HSee Item Enable Switch", "󰀯HSee物品启用开关",
    true,
    "Control whether to enable the HSee viewing item", "󰀭控制是否启用HSee查看器物品",
    "Enabled: HSee can be crafted with Science Machine", "☀已开启：HSee可在科学二本中制作",
    "Disabled: HSee recipe is hidden", "☁已禁用：HSee配方隐藏"
  ),
}
