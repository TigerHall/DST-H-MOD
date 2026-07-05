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

name = L and "H-Enhanced Waterlogged Tree" or "H-水中木强化"
version = "2.1"
description = L
    and
    ("V" .. version .. "\n\nAllows transplanted Waterlogged Trees to glow, reduces the visual size of large trees, shrinks moss vines, increases the shade range of the fig Tree, and adjusts the number of figs obtained per harvest.Modify the production speed and consumption effect of Glommer's Goop, and modify the fertilizer effect of tree jam and Glommer's Goop. When fertilizing with Glommer's Goop, the transplant marker of the crop can be removed (after becoming a native plant, there is no need to fertilize again), and it should no longer wither. The ambient temperature under the tree is 16 degrees. Farming hat enhancements: night vision+storm proof+waterproof+thermal / armor+planar defense+faction immunity+fireproof.")
    or
    ("V" .. version .. "\n\n让移植过来的水中木发光（光芒能让作物晚上生长），减小大树视觉体积，自定义增大树荫范围，减小苔藓藤条体积，修改获得的无花果数量，修改格罗姆粘液的产出速度和食用效果（应该任何人都能吃），自定义格罗姆的会san光环效果，修改树果酱和格罗姆粘液的肥料效果。格罗姆粘液施肥时可移除作物的移植标记（变为原生植物以后不用再施肥了）同时应该不会再枯萎。树下环境温度16度。水中木不会挡着码头地皮铺设。格罗姆可自带回血，海带无间隔放置。耕作帽强化：夜视+防风暴+防水+恒温 / 防御+位面防+阵营友好+防火。")
author = "hehu"
api_version = 10
dst_compatible = true
all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "oceantree_pillar", "水中木", "oceanvine", "苔藓藤条，无花果" }

--优先级调高
-- priority = -18

configuration_options = {
  -- 产物相关标题
  addTitle(L and "About Ocean Tree" or "水中木相关"),
  -- 发光半径
  {
    name = "OceanTreeLightRadius",
    label = L and "Waterlogged Tree Light Radius" or "水中木发光半径",
    hover = L and "Make your waterlogged trees glow" or "让你的水中木亮起来吧",
    options = {
      { description = "0", data = 0, hover = L and "No glow" or "不发光" },
      { description = "1.6", data = 1.6, hover = L and "A little light, just enough to see you" or "发点光，照到你就好了" },
      { description = "2.6", data = 2.6, hover = L and "A good glowing range" or "不错的发光范围了" },
      { description = "6.6", data = 6.6, hover = L and "Slightly larger than the tree itself, enough for a small base" or "比水中木本体大一点点，能建小基地了" },
      { description = "10.6", data = 10.6, hover = L and "Very larger" or "非常大的发光范围了" },
      { description = "16.6", data = 16.6, hover = L and "Very Very larger" or "发光范围太大了" },
    },
    default = 6.6
  },
  -- 水中木遮蔽范围
  {
    name = "OceanTreeShadeRange",
    label = L and "Waterlogged Tree Shade Range" or "水中木遮蔽范围",
    hover = L and "Adjust the shade coverage of waterlogged trees" or "调整水中木提供的荫蔽范围大小",
    options = {
      { description = L and "22 (Original)" or "22(原版)", data = 22, hover = L and "Default shade range" or "原版默认遮蔽范围" },
      { description = L and "36 (1.5x)" or "36(1.5倍)", data = 36, hover = L and "1.5 times the original range" or "原版的1.5倍遮蔽范围" },
      { description = L and "46 (2x)" or "46(2倍)", data = 46, hover = L and "2 times the original range" or "原版的2倍遮蔽范围" },
      { description = L and "56 (2.5x)" or "55(2.5倍)", data = 56, hover = L and "2.5 times the original range" or "原版的2.5倍遮蔽范围" },
      { description = L and "66 (3x)" or "66(3倍)", data = 66, hover = L and "3 times the original range" or "原版的3倍遮蔽范围" },
    },
    default = 66
  },
  -- 新增：水中木树荫降温开关
  addConfig(
    "ocean_tree_cooldown",
    "树下更凉快",
    "Cool Under Ocean Tree",
    true,
    "水中木树荫的温度调节开关",
    "Temperature adjustment switch for Ocean Tree shade",
    "开启后，水中木树荫下温度固定为16度，植物夏天不枯萎",
    "When enabled, the temperature under Ocean Tree shade is fixed at 16°C, preventing plants from withering in summer",
    "关闭后，水中木树荫温度恢复默认，植物夏天可能枯萎",
    "When disabled, the temperature under Ocean Tree shade returns to default, and plants may wither in summer"
  ),
  -- 缩小水中木大小
  {
    name = "OceanTreeShrinkScale",
    label = L and "Waterlogged Tree Shrink" or "水中木缩小",
    hover = L and "Too big, blocks the view a bit" or "太大了有点挡视线",
    options = {
      { description = "0", data = 0, hover = L and "Original size" or "原本的大小" },
      { description = "0.6x", data = 0.6, hover = L and "Shrunk by half, can barely see the top" or "缩小近一半，稍微能看到顶了" },
      { description = "0.36x", data = 0.36, hover = L and "36% of original size, bigger than regular trees" or "缩小到原来的30%，比普通树大点" },
      { description = "0.26x", data = 0.26, hover = L and "26% of original size, same as regular trees" or "缩小到原来的25%，普通树" },
      { description = "0.16x", data = 0.16, hover = L and "16% of original size, smaller than regular trees" or "缩小到原来的20%，比普通树小点" },
      { description = "0.1x", data = 0.1, hover = L and "10% of original size, same height as a person" or "缩小到原来的10%，和人一样高了" },
    },
    default = 0.26
  },
  -- 新增：水中木不阻碍码头铺设开关
  addConfig(
    "ocean_tree_no_block",
    "水中木不阻碍码头铺设",
    "Ocean Tree No Block Dock Placement",
    true,
    "是否允许在水中木区域铺设码头",
    "Whether to allow dock placement in Ocean Tree areas",
    "开启后，水中木不再阻挡码头的放置和建造",
    "When enabled, Ocean Trees no longer block dock placement and construction",
    "关闭后，水中木会阻碍码头铺设（原版逻辑）",
    "When disabled, Ocean Trees block dock placement (original logic)"
  ),
  -- 产物相关标题
  addTitle(L and "About Product" or "产物相关"),
  -- 缩小苔藓藤条大小
  {
    name = "OceanVineShrinkScale",
    label = L and "Moss Vine Shrink" or "苔藓藤条缩小",
    hover = L and "Moss vine scaling ratio" or "苔藓藤条缩放比例",
    options = {
      { description = "0", data = 0, hover = L and "Original size" or "原本的大小" },
      { description = "0.8x", data = 0.8, hover = L and "Slightly smaller" or "稍微小点" },
      { description = "0.6x", data = 0.6, hover = L and "Shrunk to 0.6" or "缩小近一半" },
      { description = "0.2x", data = 0.2, hover = L and "Shrunk to 0.2" or "缩小到0.2" },
    },
    default = 0.6
  },
  -- 无花果收获数量
  {
    name = "fig_harvest_count",
    label = L and "Fig Harvest Quantity" or "无花果收获数量",
    hover = L and "Adjust the number of figs harvested each time" or "调整无花果每次收获的数量",
    options = {
      { description = L and "1 fig" or "1个", data = 1, hover = L and "1 per harvest, same as original" or "一次收获1个，和原版一样" },
      { description = L and "3 figs" or "3个", data = 3, hover = L and "3 per harvest" or "一次收获3个" },
      { description = L and "6 figs" or "6个", data = 6, hover = L and "6 per harvest" or "一次收获6个" },
      { description = L and "10 figs" or "10个", data = 10, hover = L and "10 per harvest, 4 harvests make a full stack" or "一次收获10个，四次收获刚好一组" },
      { description = L and "16 figs" or "16个", data = 16, hover = L and "16 per harvest" or "一次收获16个" },
      { description = L and "20 figs" or "20个", data = 20, hover = L and "20 per harvest, half a stack at a time, do you need that many?" or "一次收获20个，一次半组，要这么多么？" },
      { description = L and "40 figs" or "40个", data = 40, hover = L and "40 per harvest, a full stack at a time, fills your fridge." or "一次收获40个，一次1组，给你冰箱都塞满。" },
    },
    default = 6
  },
  -- 耕作帽：功能强化（夜视+防风暴+防水+恒温）
  addConfig(
    "farming_utility",
    "耕作帽功能强化",
    "Farming Hat Utility",
    true,
    "种地的人应该风雨无阻。夜视、防风暴、完全防雨、恒温16~36°C",
    "Night vision, storm protection, waterproof, thermal 16~36°C",
    "开启后耕作帽获得功能强化，可以风雨无阻的种地了",
    "Farming hats gain utility enhancements",
    "关闭后耕作帽无功能强化",
    "Farming hats have no utility enhancements"
  ),

  -- 耕作帽：战斗强化（防御+阵营友好+防火）
  addConfig(
    "farming_combat",
    "耕作帽战斗强化",
    "Farming Hat Combat",
    true,
    "种地的人应该专心致志。耕作帽36/66防+36/66位面防，暗影+月亮友好，高级帽防火",
    "plantregistryhat 36armor+36planar, nutrientsgoggleshat 66armor+66planar, faction immunity, fireproof",
    "开启后耕作帽获得战斗强化，可以专心致志的种地了",
    "Farming hats gain combat enhancements",
    "关闭后耕作帽无战斗强化",
    "Farming hats have no combat enhancements"
  ),

  -- 种地相关优化标题
  addTitle(L and "About Farming" or "种地相关优化"),
  {
    name = "glommerfuel_period",
    label = L and "Glommer's Goop Production Rate" or "格罗姆粘液产出速度",
    hover = L and "Adjust the production rate of Glommer's Goop (0 = original rate)" or "调整格罗姆粘液的产出速度（0 = 原始速度）",
    options = {
      { description = "0", data = 0, hover = L and "Original production rate (no change)" or "原始产出速度（2个游戏日，8分钟）" },
      { description = "6.6", data = 6.6, hover = L and "Producing every 6.6 minutes " or "6.6分钟产出一个" },
      { description = "4.6", data = 4.6, hover = L and "Producing every 4.6 minutes" or "4.6分钟产出一个，一天不到2个" },
      { description = "3.6", data = 3.6, hover = L and "Producing every 3.6 minutes" or "3.6分钟产出一个，一天2个" },
      { description = "2.6", data = 2.6, hover = L and "Producing every 2.6 minutes" or "2.6分钟产出一个，一天3个" },
      { description = "1.6", data = 1.6, hover = L and "Producing every 1.6 minutes" or "1.6分钟产出一个，一天5个" },
      { description = "0.6", data = 0.6, hover = L and "Producing every 36 section" or "36s产出一个，一天有13个" },
    },
    default = 2.6
  },
  addConfig(
    "glmny_fl",
    "格罗姆粘液肥料效果修改",
    "Glommer's Goop Fertilizer Effect Modification",
    true,
    "修改格罗姆粘液的肥料效果（66点肥力值）",
    "Modify Glommer's Goop fertilizers",
    "开启后所有树果酱肥料的肥力值均为66",
    "Glommer's Goop fertilizers all set to 66 value",
    "不做修改",
    "No change"
  ),
  addConfig(
    "glommerfuel_remove_transplant",
    "格罗姆粘液移除移植标记",
    "Glommerfuel Remove Transplant Mark",
    true,
    "使用格罗姆粘液施肥时移除作物的移植标记",
    "Remove transplant mark of crops when fertilizing with Glommerfuel",
    "开启后用格罗姆粘液施肥会清除移植标记",
    "Fertilizing with Glommerfuel will clear transplant mark",
    "禁用后格罗姆粘液不再移除移植标记",
    "Glommerfuel no longer removes transplant mark"
  ),
  addConfig(
    "sgj_fl",
    "树果酱肥料效果修改",
    "Tree Jam Fertilizer Effect Modification",
    true,
    "修改树果酱肥料的效果（166点肥力值）",
    "Modify Tree Jam fertilizers",
    "开启后所有树果酱肥料的肥力值均为166",
    "Tree Jam fertilizers all set to 166 value",
    "不做修改",
    "No change"
  ),
  -- 其他设置标题
  addTitle(L and "Other" or "其他"),
  addConfig(
    "glommerfuel_edible",
    "格罗姆粘液食用效果修改",
    "Glommer's Goop Edible Effect Modification",
    true,
    "是否修改格罗姆粘液的食用效果",
    "Whether to modify the edible effect of Glommer's Goop ",
    "修改后食用格罗姆粘液回复饥饿166、生命166，减少理智166",
    "Modified effect: Eating Glommer's Goop restores 166 hunger, 166 health, and reduces sanity by 166",
    "保留原版格罗姆粘液的食用效果，不做数值修改",
    "don't change the original edible effect of Glommer's Goop"
  ),
  addConfig(
    "glommer_strong",
    "格罗姆更强一点，不容易gg",
    "Glommer Stronger",
    true,
    "修改格罗姆的血量等，让它更强一点",
    "Make Glommer Stronger",
    "修改后格罗姆血量666，伤害吸收百分比60%，每6s恢复66滴血",
    "Modified effect: Glommer has 666 health, 60% damage absorption, and restores 66 health every 6 seconds",
    "保留原版格罗姆的属性，不做修改",
    "don't change the original of Glommer"
  ),
  -- 回san光环效果修改
  {
    name = "glommer_sanityaura",
    label = L and "Glommer's Sanity Aura (per second)" or "格罗姆每秒回san光环",
    hover = L and "Adjust Glommer's sanity restoration per second (0 = disable aura)" or "调整格罗姆每秒的理智恢复值（0 = 禁用光环效果）",
    options = {
      { description = "0/s", data = 0, hover = L and "0 sanity per second (aura disabled)" or "不做改动" },
      { description = "0.2/s", data = 0.2, hover = L and "0.2 sanity restored per second" or "每秒恢复0.2理智，两倍于原本的格罗姆效果" },
      { description = "0.6/s", data = 0.6, hover = L and "0.6 sanity restored per second" or "每秒恢复0.6理智" },
      { description = "1.0/s", data = 1, hover = L and "1 sanity restored per second" or "每秒恢复1理智（原始速率）" },
      { description = "1.6/s", data = 1.6, hover = L and "1.6 sanity restored per second" or "每秒恢复1.6理智" },
      { description = "2.6/s", data = 2.6, hover = L and "2.6 sanity restored per second" or "每秒恢复2.6理智" },
      { description = "3.6/s", data = 3.6, hover = L and "3.6 sanity restored per second" or "每秒恢复3.6理智" },
      { description = "6.6/s", data = 6.6, hover = L and "6.6 sanity restored per second" or "每秒恢复6.6理智" },
      { description = "16.6/s", data = 16.6, hover = L and "16.6 sanity restored per second" or "每秒恢复16.6理智" },
      { description = "26.6/s", data = 26.6, hover = L and "26.6 sanity restored per second" or "每秒恢复26.6理智" },
      { description = "36.6/s", data = 36.6, hover = L and "36.6 sanity restored per second" or "每秒恢复36.6理智" },
    },
    default = 6.6
  },

  addConfig(
    "bullkelp_no_placement_space",
    "公牛海带可叠放无物理间隔",
    "Bull Kelp Stackable No Placement Space",
    true,
    "移除公牛海带放置时的物理间距限制，支持重叠放置",
    "Remove the physical spacing limit when placing Bull Kelp, support overlapping placement",
    "开启后可将多个公牛海带叠放在同一位置，无物理间隔限制",
    "When enabled, multiple Bull Kelp can be stacked in the same position without physical spacing limits",
    "关闭后恢复原版规则，公牛海带需间隔一定距离才能放置",
    "When disabled, restore the original rules, Bull Kelp requires a certain distance to be placed"
  )
}
