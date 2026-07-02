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
name = L and "H-Cane Enhancement" or "H-手杖强化"
version = "4.0"
description =
    L and
    ("V" .. version .. "\n\n" .. "󰀏All features can be turned on or off in the configuration options.\n\nEnhance your walking cane with features including custom movement speed bonuses, damage values (including planar damage values),Ramping Damage, ranged attacks and area-of-effect attacks, life leech (including restoring hunger and sanity), glowing (only when dropped on the ground), preventing being knocked off by bosses, being revivable via haunting, and being theft-proof, etc.\n\nIt also supports various multi-functional tool features, including axe, pickaxe, shovel (with customizable tool efficiency), hammer, circular harvesting, and other multi-functional tools. It can automatically pick harvestable crops around the player. It also features automatic tilling. The multi-functional tool features and light effect function of the cane can be turned off/on by right-clicking.\n\nIn addition, there are permanent features such as watering can, oar, freshwater fishing rod, brush, and razor (with a separate setting switch).\n\nYou can set to craft walrus ivory at the Alchemy Engine (1 bone and 2 fangs) or make walruses drop an extra walrus ivory. It can also resist lightning, rain, and maintain a constant temperature.\n\nYou can place seeds in the character's last inventory slot (the 15th one, closest to the equipment slot), and they will be sown automatically. You can also place gems, sand stones, bear skins (be careful of home destruction), etc., each of which has different abilities. But all abilities come with a hunger cost") or
    (
      "V" .. version .. "\n\n" .. "󰀏所有功能均可在配置项开启或关闭\n\n强化你的步行手杖，包括自定义移速加成、伤害值(包括位面伤害值)、越战越强、远程攻击与群体攻击、吸血(包括回复饥饿和理智)、发光（仅限丢在地上的时候）、防boss拍落、可作祟复活以及不会被偷窃等功能，\n还支持多种多功能工具功能，包括斧子、稿子、铲子（可自定义工具效率）、锤子、圆形收割等多功能工具，且可自动采摘玩家周围的可采摘作物，自动锄地。可通过右键关闭/开启手杖的多功能工具功能和光特效功能。\n另外有常驻功能浇水壶、船桨、淡水钓竿、刷子、剃刀（有单独设置开关）\n可以设置在二本合成海象牙（1骨头2犬牙）或让海象额外掉落一个海象牙，可以防雷、防雨、恒温。\n可以在人物最后一个格子（15个，最靠近装备那个）里放入种子，能自动播种（包括杂草）。还可以放入宝石、沙之石、熊皮（小心拆家）等，都有不同的能力。但所有的能力都有饥饿代价。")
author = "hehu"

api_version = 10
dst_compatible = true
all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "cane", "步行手杖", "移速", "speed", "伤害", "damage", "远程攻击", "range attack", "复活", "resurrection" }

--优先级调高
priority = -16

configuration_options = {
  -- 基础配置项
  addTitle(L and "Basic Function Configurations" or "基本功能"),
  -- 移速加成值（百分比）
  {
    name = "speed_buff_value",
    label = L and "Speed Bonus" or "移速加成",
    hover = L and "Speed bonus percentage (%)" or "移速加成百分比(%)",
    options = {
      { description = "0%", data = 0, hover = L and "No speed boost at all" or "原版都有加速你不加速，我说你牛的" },
      {
        description = "26%",
        data = 0.26,
        hover = L and "Similar to vanilla, 1% difference for clarity" or "和原版差不多的加速，差了1%能让人清楚开没开"
      },
      {
        description = "46%",
        data = 0.46,
        hover = L and "Vanilla + amulet effect, faster than beefalo" or "原版再加上护符的效果，比行牛快一点点"
      },
      {
        description = "66%",
        data = 0.66,
        hover = L and "Close to speed 10, slower than saddled beefalo" or "接近10的速度了，比牛加鞍具慢一点点"
      },
      {
        description = "116%",
        data = 1.16,
        hover = L and "Close to speed 13, faster than saddled beefalo" or "接近13的速度了，比行牛加鞍具快一点点，再快要炸档的。"
      }
    },
    default = 0.66
  },
  addConfig(
    "haunt_resurrect_enable",
    "可作祟复活",
    "Haunt Resurrection",
    true,
    "是否允许通过作祟手杖复活",
    "Allow resurrection by haunting the staff",
    "和重生护符一样效果的复活，说不定你需要做大骨头汤呢",
    "Resurrect like a life amulet, useful for big bone soup",
    "相信你在永恒大陆不怕死亡，毕竟也可以回档大法",
    "You're not afraid of death in the Constant, after all, you can reload"
  ),
  -- 发光范围设置
  {
    name = "hcane_light",
    label = L and "Light Emission Range" or "发光范围设置",
    hover = L and "Set the light emission range of the item (0 = disable light)" or "设置物品的发光范围(0 = 禁用发光)",
    options = {
      { description = "0", data = 0, hover = L and "Disable light emission" or "禁用发光效果" },
      { description = "1.6", data = 1.6, hover = L and "Small light range (radius 1.6)" or "保命微光(半径1.6)" },
      { description = "3.6", data = 3.6, hover = L and "Medium light range (radius 3.6)" or "中等发光范围(半径3.6)" },
      { description = "6.6", data = 6.6, hover = L and "Large light range (radius 6.6)" or "大发光范围(半径6.6)" },
      { description = "12.6", data = 12.6, hover = L and "Extra large light range (radius 12.6)" or "超大发光范围(半径12.6)" },
    },
    default = 3.6
  },
  -- 伤害值配置项
  addTitle(L and "About Damage" or "伤害相关"),
  -- 基础伤害值选项
  {
    name = "damage_value",
    label = L and "Damage" or "伤害",
    hover = L and "Attack damage value" or "攻击伤害值",
    options = {
      { description = "0.0000006", data = 0.0000006, hover = L and "Almost No damage but still useful" or "基本没伤害但也有用" },
      { description = "1.6", data = 1.6, hover = L and "Just right to hit some butterflies" or "刚好打打蝴蝶" },
      { description = "10", data = 10, hover = L and "weaker than vanilla" or "比原版弱一些" },
      { description = "16", data = 16, hover = L and "Slightly weaker than vanilla" or "比原版弱一点，刚好有点区分" },
      { description = "36", data = 36, hover = L and "A bit higher than spear" or "比长矛的伤害高一点点" },
      { description = "66", data = 66, hover = L and "Stronger than ham bat" or "比火腿棒强一点点" },
      { description = "166", data = 166, hover = L and "As strong as Ancient Fuelweaver's attack" or "你的普攻和远古织影者一样强" },
      { description = "666", data = 666, hover = L and "Kill Dragonfly in 42 hits" or "42下杀龙蝇" },
      {
        description = "1666",
        data = 1666,
        hover = L and "Kill Toadstool in 60 hits, most bosses in 10" or "60下杀苦难蟾蜍，大部分boss你只需打十下"
      },
      { description = "6666", data = 6666, hover = L and "You can conquer the饥荒 world" or "饥荒世界你都能杀穿了" }
    },
    default = 16
  },
  -- 真实伤害选项
  {
    name = "planardamage",
    label = L and "Planar Damage" or "位面伤害",
    hover = L and "Planar attack damage value" or "位面攻击伤害值",
    options = {
      { description = "0", data = 0, hover = L and "No planar damage" or "没有位面伤害" },
      { description = "10", data = 10, hover = L and "10 planar damage" or "普普通通的伤害" },
      { description = "16", data = 16, hover = L and "Slightly weaker than Shadow Reaper" or "比暗影收割者位面伤害弱一点" },
      { description = "36", data = 36, hover = L and "A bit higher than lunar spear" or "比阴郁回旋镖位面伤害高一点点" },
      { description = "66", data = 66, hover = L and "Brightshade Sword * 2" or "两倍亮茄剑位面伤害" },
      { description = "166", data = 166, hover = L and "nearly Brightshade Bomb" or "位面伤害与亮茄炸弹接近了" },
      { description = "666", data = 666, hover = L and "Brightshade Bomb * 3" or "3倍亮茄炸弹" },
      {
        description = "1666",
        data = 1666,
        hover = L and "Kill Ancient Fuelweaver in 15 hits" or "15下击杀远古织影者，多数位面Boss轻松应对"
      },
      { description = "6666", data = 6666, hover = L and "Dominate all planar creatures" or "碾压所有位面生物" }
    },
    default = 16
  },
  -- 越攻击越强
  addConfig(
    "extra_damage",
    "越战越强",
    "Ramping Damage",
    true,
    "是否启用攻击叠加伤害效果（每次攻击有概率增加1~6点伤害，上限166点，16秒无战斗重置）",
    "Enable ramping damage effect (Maybe randomly increase 1~6 damage per attack, max 66 damage, reset after 16s of inactivity)",
    "每次攻击都会变强，持续战斗伤害拉满",
    "Damage increases with each attack, max damage in continuous combat",
    "关闭叠加效果，伤害保持基础值不变",
    "Disable ramping effect, damage remains at base value"
  ),
  -- 远程攻击范围
  {
    name = "range_attack",
    label = L and "Attack Ranged" or "远程攻击范围",
    hover = L and "How far you can Attack" or "可以打多远",
    options = {
      { description = "0", data = 0, hover = L and "No Attack Ranged" or "原本就是近战" },
      { description = "2", data = 2, hover = L and "Half Turfs Radius" or "半个地皮远" },
      { description = "6", data = 6, hover = L and "One and A Half Turfs Radius" or "1.5个地皮远" },
      { description = "10", data = 10, hover = L and "2.5 * Turfs Radius" or "2.5个地皮远" },
      { description = "16", data = 16, hover = L and "4 * Turfs Radius" or "4个地皮远" },
      { description = "20", data = 20, hover = L and "5 * Turfs Radius" or "5个地皮那么远" },
    },
    default = 16
  },
  -- 群攻伤害百分比
  {
    name = "aoe_damage_ratio",
    label = L and "AOE Damage Percentage" or "群攻伤害百分比",
    hover = L and "Percentage of base damage for AOE attacks (0% = disable AOE)" or "群攻伤害占基础伤害的百分比(0% = 禁用群攻)",
    options = {
      { description = "0%", data = 0, hover = L and "Disable AOE attack" or "禁用群攻效果" },
      { description = "6%", data = 0.06, hover = L and "6% of base damage" or "基础伤害的6%" },
      { description = "16%", data = 0.16, hover = L and "16% of base damage" or "基础伤害的16%" },
      { description = "36%", data = 0.36, hover = L and "36% of base damage" or "基础伤害的36%" },
      { description = "50%", data = 0.5, hover = L and "50% of base damage" or "基础伤害的50%" },
      { description = "66%", data = 0.66, hover = L and "66% of base damage" or "基础伤害的66%" },
      { description = "80%", data = 0.8, hover = L and "80% of base damage" or "基础伤害的80%" },
      { description = "100%", data = 1.0, hover = L and "Same as base damage" or "与基础伤害相同" },
      { description = "166%", data = 1.66, hover = L and "166% of base damage" or "基础伤害的166%" }
    },
    default = 0.36
  },
  -- 攻击回血
  {
    name = "life_drain_ratio",
    label = L and "Life Drain Ratio" or "吸血比例",
    hover = L and "Percentage of damage (including AOE) converted to health (0% = disable life drain)" or
        "伤害（包括群攻造成的）转化为生命值的百分比(0% = 禁用吸血)",
    options = {
      { description = "0%", data = 0, hover = L and "Disable life drain" or "禁用攻击回血效果" },
      { description = "6%", data = 0.06, hover = L and "6% of damage as health" or "伤害的6%转化为生命" },
      { description = "16%", data = 0.16, hover = L and "16% of damage as health" or "伤害的16%转化为生命" },
      { description = "36%", data = 0.36, hover = L and "36% of damage as health" or "伤害的36%转化为生命" },
      { description = "66%", data = 0.66, hover = L and "66% of damage as health" or "伤害的66%转化为生命" },
      { description = "100%", data = 1.0, hover = L and "100% of damage as health" or "伤害的100%转化为生命" },
      { description = "166%", data = 1.66, hover = L and "166% of damage as health" or "伤害的166%转化为生命" }
    },
    default = 0.06
  },
  -- 攻击回饿
  {
    name = "hunger_conversion_ratio",
    label = L and "Hunger Conversion Ratio" or "伤害转饥饿比例",
    hover = L and "Percentage of damage (including AOE) converted to hunger points (0% = disable hunger conversion)" or
        "伤害（包括群攻造成的）转化为饥饿值的百分比(0% = 禁用伤害转饥饿)",
    options = {
      { description = "0%", data = 0, hover = L and "Disable hunger conversion" or "禁用伤害转饥饿效果" },
      { description = "6%", data = 0.06, hover = L and "6% of damage as hunger points" or "伤害的6%转化为饥饿值" },
      { description = "16%", data = 0.16, hover = L and "16% of damage as hunger points" or "伤害的16%转化为饥饿值" },
      { description = "36%", data = 0.36, hover = L and "36% of damage as hunger points" or "伤害的36%转化为饥饿值" },
      { description = "66%", data = 0.66, hover = L and "66% of damage as hunger points" or "伤害的66%转化为饥饿值" },
      { description = "100%", data = 1.0, hover = L and "100% of damage as hunger points" or "伤害的100%转化为饥饿值" },
      { description = "166%", data = 1.66, hover = L and "166% of damage as hunger points" or "伤害的166%转化为饥饿值" }
    },
    default = 0.06
  },
  -- 攻击回智
  {
    name = "sanity_conversion_ratio",
    label = L and "Sanity Conversion Ratio" or "伤害转理智比例",
    hover = L and "Percentage of damage (including AOE) converted to sanity points (0% = disable sanity conversion)" or
        "伤害（包括群攻造成的）转化为理智值的百分比(0% = 禁用伤害转理智)",
    options = {
      { description = "0%", data = 0, hover = L and "Disable sanity conversion" or "禁用伤害转理智效果" },
      { description = "6%", data = 0.06, hover = L and "6% of damage as sanity points" or "伤害的6%转化为理智值" },
      { description = "16%", data = 0.16, hover = L and "16% of damage as sanity points" or "伤害的16%转化为理智值" },
      { description = "36%", data = 0.36, hover = L and "36% of damage as sanity points" or "伤害的36%转化为理智值" },
      { description = "66%", data = 0.66, hover = L and "66% of damage as sanity points" or "伤害的66%转化为理智值" },
      { description = "100%", data = 1.0, hover = L and "100% of damage as sanity points" or "伤害的100%转化为理智值" },
      { description = "166%", data = 1.66, hover = L and "166% of damage as sanity points" or "伤害的166%转化为理智值" },
    },
    default = 0
  },


  -- 多功能配置项
  addTitle(L and "Multi-Tool Configurations(right-click to control the switch)" or "可开关工具"),
  -- 多工具组件
  addConfig(
    "tool_enable",
    "多功能",
    "Multi-Function",
    true,
    "是否启用手杖的多功能（可砍、锤、挖、捕网、挖矿等）",
    "Enable multi-tool capabilities (chop, hammer, dig, net, mine, etc.)",
    "让手杖拥有很多功能，解放双手",
    "Staff has many functions, free your hands",
    "功能太多确实也不好",
    "Too many functions are indeed not good"
  ),
  addConfig(
    "multi_tool_state_save",
    "工具状态保留",
    "Multi Tool Multi Tool Multi Tool State",
    true,
    "卸下装备时是否保留多功能工具各组件的开启状态",
    "Whether to retain the enabled state of multi-tool components when unequipping",
    "卸下时保留所有工具组件的当前状态，重新装备无需重新开启",
    "Retains current state of all tool components when unequipped; no need to re-enable after re-equipping",
    "卸下时自动关闭所有工具组件，重新装备需手动右键开启",
    "Automatically disables all tool components when unequipped; manual right-click to re-enable after re-equipping"
  ),
  addConfig(
    "enable_light_fx",
    "呼吸灯特效",
    "Enable Breathing Light",
    true,
    "控制手杖开启多功能时是否有彩色呼吸灯效果",
    "Control whether the cane shows a colorful breathing light effect when multi-function is on",
    "开启后手杖会有彩色呼吸灯效果",
    "Enables colorful breathing light effect on the cane",
    "关闭后手杖无呼吸灯效果",
    "Disables the breathing light effect on the cane"
  ),
  addConfig(
    "cane_icon_text",
    "小图标状态文字",
    "Icon Status Text",
    true,
    "手杖开关时在背包小图标上显示开/关状态文字",
    "Display ON/OFF status text on the cane's inventory icon",
    "开启后小图标显示开/关字，颜色由呼吸灯特效决定",
    "Shows status text; color controlled by Breathing Light setting",
    "关闭后小图标无任何文字叠加",
    "No text overlay on the inventory icon"
  ),
  -- 粒子特效类型（多选项）
  {
    name = "fx_particle_type",
    label = L and "Particle Effect Type" or "粒子特效类型",
    hover = L and "Select the particle effect type when multi-function is on" or "选择手杖多功能开启时的粒子特效类型",
    options = {
      {
        description = L and "Disabled" or "关闭",
        data = "none",
        hover = L and "No particle effects" or "不显示任何粒子特效"
      },
      {
        description = L and "Sparkle Particles" or "闪光粒子",
        data = "sparkle",
        hover = L and "Original green sparkle particle effect" or "原本的绿色闪光粒子效果"
      },
      {
        description = L and "Shadow Particles" or "暗影粒子",
        data = "shadow",
        hover = L and "Shadowy purple particle effect inspired by Alarming Clock" or "暗紫色暗影粒子效果，灵感来自Alarming Clock"
      },
    },
    default = "sparkle"
  },
  addConfig(
    "enable_tool_toggle_icon",
    "切换图标",
    "Sync Icon When Toggling Tools",
    false,
    "右键切换工具功能时同步切换图标显示（切换后会变成自定义图标）",
    "Whether to sync icon display when right-click toggling tool functions",
    "启用后右键切换工具功能时会自动切换对应图标",
    "Enables automatic icon switching when right-click toggling tool functions",
    "禁用后切换工具功能时保持原始图标不变",
    "Disables icon changes when toggling tool functions (keeps original icon)"
  ),
  addConfig(
    "enable_tool_toggle_rename",
    "更改名称",
    "Sync Name When Toggling Tools",
    false,
    "右键切换工具功能时同步更改手杖的名称",
    "Whether to sync the display name of the cane when right-click toggling tool functions",
    "启用后切换工具功能时会自动修改手杖名称为对应功能名称",
    "Enables automatic renaming of the cane to the corresponding function name when toggling tools",
    "禁用后切换工具功能时保持手杖原始名称不变",
    "Disables name changes when toggling tool functions (keeps the original cane name)"
  ),
  -- 锤子
  addConfig(
    "enable_hammer_action",
    "锤子敲击动作",
    "Enable Hammer Action",
    true,
    "控制是否允许作为锤子使用",
    "Control whether to allow using as a hammer",
    "启用后可执行敲击动作",
    "Enables hammer actions",
    "禁用后无法执行敲击动作",
    "Disables all hammer actions"
  ),
  -- 挖掘铲子
  addConfig(
    "enable_dig_action",
    "铲子挖掘动作",
    "Enable Shovel Dig Action",
    true,
    "控制是否允许作为挖掘铲子使用",
    "Control whether to allow using as a shovel",
    "启用后可执行挖掘动作",
    "Enables shovel digging actions",
    "禁用后无法执行挖掘动作",
    "Disables all shovel digging actions"
  ),
  -- 镰刀配置项
  addConfig(
    "enable_scythe",
    "镰刀收割功能",
    "Scythe Function",
    true,
    "控制是否启用镰刀功能",
    "Control whether to enable the scythe function",
    "开启后可作为镰刀使用",
    "Can be used as a scythe when enabled",
    "关闭后无法作为镰刀使用",
    "Cannot be used as a scythe when disabled"
  ),
  -- 工作效率
  {
    name = "tool_efficiency",
    label = L and "Tool Efficiency" or "工具效率",
    hover = L and
        "Efficiency level for chopping trees, mining, and hammering (the higher the level, the faster the speed)" or
        "砍树、挖矿和敲击的效率等级（越高越快）",
    options = {
      { description = "1x", data = 1, hover = L and "Basic efficiency" or "基础效率" },
      { description = "2x", data = 2, hover = L and "Faster than Pick/Axe" or "比多用斧稿快" },
      { description = "3x", data = 3, hover = L and "Faster than Brightshade Smasher" or "比亮茄粉碎者快" },
      { description = "6x", data = 6, hover = L and "Very fast" or "非常快" },
      { description = "10x", data = 10, hover = L and "Very Very fast" or "非常非常快" },
      { description = "16x", data = 16, hover = L and "Too fast" or "太快了" }
    },
    default = 6
  },
  -- 自动耕地
  {
    name = "auto_farm_range",
    label = L and "Auto-Farm Range" or "自动耕地范围",
    hover = L and
        "Effective range for auto-farming (set to 0 to disable)" or
        "自动耕地的有效范围（设置为0则关闭功能）",
    options = {
      { description = "0", data = 0, hover = L and "Disable auto-farming" or "关闭自动耕地功能" },
      { description = "1", data = 1, hover = L and "1 Turf range" or "周围1个地皮，9宫格" },
      { description = "2", data = 2, hover = L and "2 Turfs range, covers medium-sized farms" or "周围2个地皮" },
      { description = "3", data = 3, hover = L and "3 Turfs range, ideal for large farmlands" or "周围3个地皮" },
    },
    default = 1
  },

  -- 其他工具功能配置项
  addTitle(L and "Other tools (permanently active functions)" or "常驻工具"),
  -- 浇水壶
  addConfig(
    "enable_watering",
    "水壶功能",
    "Watering Function",
    true,
    "控制是否启用水壶功能",
    "Control whether to enable the watering function",
    "开启后可作为水壶使用",
    "Can be used as a water bottle when enabled",
    "关闭后无法作为水壶使用",
    "Cannot be used as a water bottle when disabled"
  ),
  -- 船桨功能
  addConfig(
    "enable_paddling",
    "船桨功能",
    "Paddle Function",
    true,
    "控制是否启用船桨功能",
    "Control whether to enable the paddle function",
    "开启后可作为船桨使用",
    "Can be used as a paddle when enabled",
    "关闭后无法作为船桨使用",
    "Cannot be used as a paddle when disabled"
  ),
  -- 淡水钓鱼竿配置项
  addConfig(
    "enable_fishingrod",
    "淡水钓鱼竿功能",
    "Freshwater Fishing Rod Function",
    true,
    "控制是否启用淡水钓鱼竿功能",
    "Control whether to enable the freshwater fishing rod function",
    "开启后可作为淡水钓鱼竿使用",
    "Can be used as a freshwater fishing rod when enabled",
    "关闭后无法作为淡水钓鱼竿使用",
    "Cannot be used as a freshwater fishing rod when disabled"
  ),
  -- 刷子配置项
  addConfig(
    "enable_brush",
    "刷子功能",
    "Brush Function",
    true,
    "控制是否启用刷子功能",
    "Control whether to enable the brush function",
    "开启后可作为刷子使用",
    "Can be used as a brush when enabled",
    "关闭后无法作为刷子使用",
    "Cannot be used as a brush when disabled"
  ),
  -- 剃刀配置项
  addConfig(
    "enable_razor",
    "剃刀功能",
    "Razor Function",
    true,
    "控制是否启用剃刀功能",
    "Control whether to enable the razor function",
    "开启后可作为剃刀使用",
    "Can be used as a razor when enabled",
    "关闭后无法作为剃刀使用",
    "Cannot be used as a razor when disabled"
  ),
  -- 锄头配置项
  addConfig(
    "enable_hoe",
    "锄头功能",
    "Hoe Function",
    true,
    "控制是否启用锄头功能（可耕作土地）",
    "Control whether to enable the hoe function (can till soil)",
    "开启后可作为锄头使用，右键耕地",
    "Can be used as a hoe for tilling when enabled",
    "关闭后无法作为锄头使用",
    "Cannot be used as a hoe when disabled"
  ),

  -- 其他配置项
  addTitle(L and "Others" or "其他"),
  addConfig(
    "anti_lose_enable",
    "防丢失",
    "Anti-Loss",
    true,
    "启用后手杖不会被偷窃、不会因BOSS攻击/潮湿脱手",
    "Prevent staff from being stolen/dropped by bosses/dampness",
    "My precious!（我的宝贝！）~咕噜扭曲的声音",
    "My precious! ~Gollum's voice",
    "你比较信任你自己的走位水平，这很好！",
    "You trust your positioning skills, good!"
  ),
  -- 防雷开关
  addConfig(
    "lightning_protect_enable",
    "防雷保护",
    "Lightning Protection",
    true,
    "是否启用防雷功能（防止雷电伤害和被雷劈）",
    "Whether to enable lightning protection (prevents lightning damage and being struck by lightning)",
    "启用后不会受到雷电伤害，也不会被雷劈中",
    "Enables immunity to lightning damage and prevents being struck by lightning",
    "禁用后恢复正常雷电效果，可能被雷劈或受雷电伤害",
    "Disables protection; restores normal lightning effects (may be struck or take lightning damage)"
  ),
  -- 防雨开关
  addConfig(
    "rain_protect_enable",
    "防雨保护",
    "Rain Protection",
    true,
    "是否启用防雨功能（避免被雨水打湿）",
    "Whether to enable rain protection (prevents getting wet from rain)",
    "启用后不会被雨水打湿，潮湿值不会因降雨上升",
    "Enables immunity to getting wet; moisture won't increase from rain",
    "禁用后恢复正常防雨逻辑，会被雨水打湿并积累潮湿值",
    "Disables protection; restores normal rain effects (gets wet and accumulates moisture)"
  ),
  addConfig(
    "constant_temp_effect_enable",
    "恒温效果",
    "Constant Temperature Effect",
    true,
    "是否启用恒温效果",
    "Whether to enable constant temperature effect.",
    "启用后体温始终保持适宜状态，不会过热也不会过冷",
    "Enables constant comfortable body temperature; neither overheating nor getting too cold",
    "禁用后恢复正常温度机制，会随环境变化出现过热或过冷",
    "Disables constant temperature effect; restores normal temperature mechanics (may overheat or get too cold with environment changes)"
  ),
  -- 海象牙制作开关
  addConfig(
    "enable_walrus_tusk_craft",
    "海象牙制作",
    "Walrus Tusk Crafting",
    true,
    "是否允许在炼金引擎制作海象牙",
    "Allow crafting Walrus Tusk with 1 boneshard + 1 houndstooth",
    "启用后可通过骨头碎片和犬牙在炼金引擎合成海象牙",
    "Enables crafting Walrus Tusk using 1 boneshard and 1 houndstooth at Alchemy Engine",
    "禁用海象牙的合成配方",
    "Disables the crafting recipe for Walrus Tusk"
  ),
  -- 海象固定掉落海象牙开关
  addConfig(
    "enable_walrus_tusk_drop",
    "海象固定掉落海象牙",
    "Walrus Tusk Fixed Drop",
    true,
    "是否让海象固定增加掉落1个海象牙",
    "Whether to make Walrus drop 1 Walrus Tusk consistently",
    "海象每次击杀必定掉落1个海象牙",
    "Walrus will drop 1 Walrus Tusk every time it's killed",
    "海象掉落海象牙恢复默认随机机制",
    "Reverts Walrus Tusk drop to default random mechanism"
  ),
  -- 其他工具功能配置项
  addTitle(L and "Combination function of the cane" or
    "手杖组合功能"),
  addConfig(
    "enable_slot",
    "启用扫描格子",
    "Enable Scan Slot",
    true,
    "控制是否启用手杖的扫描格子功能",
    "Control whether to enable the scan slot function of the cane",
    "手杖会根据第15个物品栏及装备栏物品解锁对应功能",
    "The cane will unlock corresponding functions based on the items in the 15th inventory slot and the equipment slot.",
    "没啥变化，而且不会有自动工作了",
    "nothing changes and no functions unlocked"),
  -- 自动工作范围
  {
    name = "auto_work_range",
    label = L and "Auto-Work Range" or "自动工作范围",
    hover = L and
        "Effective range for auto-working (set to 0 to disable)" or
        "自动工作的有效范围（设置为0则关闭功能）",
    options = {
      { description = "0", data = 0, hover = L and "Disable auto-work" or "关闭自动工作功能" },
      { description = "2.6", data = 2.6, hover = L and "Slightly more than 0.5 Turf Radius" or "稍大于0.5个地皮半径" },
      { description = "4.6", data = 4.6, hover = L and "Slightly more than 1 Turf Radius" or "稍大于1个地皮的半径范围" },
      { description = "6.6", data = 6.6, hover = L and "Slightly more than 1.5 Turfs Radius, allows the general grassland of grass lizards to be just fully harvested outside the fence." or "稍大于1.5个地皮的半径范围，围起来草蜥蜴的一般草场刚好能在栅栏外收完" },
      { description = "8.6", data = 8.6, hover = L and "Slightly more than 2 Turfs Radius" or "稍大于2个地皮的半径范围" },
      { description = "12.6", data = 12.6, hover = L and "Slightly more than 3 Turfs Radius" or "稍大于3个地皮的半径范围" },
      { description = "16.6", data = 16.6, hover = L and "Slightly more than 4 Turfs Radius" or "稍大于4个地皮的半径范围" }
    },
    default = 6.6
  },
}
