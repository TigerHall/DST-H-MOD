name = "H-手杖强化-本地测试"
description = "可调整步行手杖的移速加成、伤害和远程攻击能力，以及防掉落等特性"
author = "hehu"
version = "0.61"
api_version = 10
dst_compatible = true
all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

configuration_options = {
  -- 移速加成值（百分比）
  {
    name = "speed_buff_value",
    label = "移速加成",
    hover = "移速加成百分比(%)",
    options = {
      { description = "0%", data = 0, hover = "原版都有加速你不加速，我说你牛的" },
      { description = "26%", data = 0.26, hover = "和原版差不多的加速，差了1%能让人清楚开没开" },
      { description = "46%", data = 0.46, hover = "原版再加上护符的效果，比行牛快一点点" },
      { description = "66%", data = 0.66, hover = "接近10的速度了，比牛加鞍具慢一点点" },
      { description = "116%", data = 1.16, hover = "接近13的速度了，比行牛加鞍具快一点点" },
      { description = "166%", data = 1.66, hover = "接近16的速度了，你跑的飞快了" }
    },
    default = 0.26
  },
  -- 伤害值选项
  {
    name = "damage_value",
    label = "伤害",
    hover = "攻击伤害值",
    options = {
      { description = "0", data = 0, hover = "没伤害也有用" },
      { description = "16", data = 16, hover = "比原版弱一点，刚好有点区分" },
      { description = "36", data = 36, hover = "比长矛的伤害高一点点" },
      { description = "66", data = 66, hover = "比火腿棒强一点点" },
      { description = "166", data = 166, hover = "你的普攻和远古织影者一样强" },
      { description = "666", data = 666, hover = "42下杀龙蝇" },
      { description = "1666", data = 1666, hover = "60下杀苦难蟾蜍，大部分boss你只需打十下" },
      { description = "6666", data = 6666, hover = "饥荒世界你都能杀穿了" }
    },
    default = 16
  },
  -- 远程伤害开关
  {
    name = "range_attack_enable",
    label = "远程攻击",
    hover = "是否启用远程攻击能力",
    options = {
      { description = "启用", data = true, hover = "远程的武器，那是完全不一样的概念" },
      { description = "禁用", data = false, hover = "你还是比较老实的" }
    },
    default = true
  },
  -- 防偷窃/防脱手/死亡不掉落开关
  {
    name = "anti_lose_enable",
    label = "防丢失",
    hover = "启用后手杖不会被偷窃、不会因BOSS攻击/潮湿脱手",
    options = {
      { description = "启用", data = true, hover = "My precious!（我的宝贝！）~咕噜扭曲的音效" },
      { description = "禁用", data = false, hover = "你比较信任你自己的走位水平，这很好！" }
    },
    default = true -- 默认启用防丢失特性
  },
  {
    name = "haunt_resurrect_enable",
    label = "可作祟复活",
    hover = "是否允许通过作祟手杖复活",
    options = {
      { description = "启用", data = true, hover = "和重生护符一样效果的复活，说不定你需要做大骨头汤呢" },
      { description = "禁用", data = false, hover = "相信你在永恒大陆不怕死亡，毕竟也可以回档大法" }
    },
    default = true
  },
}
