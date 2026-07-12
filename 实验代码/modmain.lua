-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })

-- 获取配置项（统一管理配置变量）
local config = {
  hsee_enable = GetModConfigData("hsee_enable"),
}

-- 实体引用
PrefabFiles = {
  "hsee", -- 包含 hsee + hsee_pool
}

Assets = {
  -- 临时复用勋章 MOD 素材（已复制到本地），后续可替换
  Asset("ANIM", "anim/medal_skin_staff.zip"),
  Asset("IMAGE", "images/inventoryimages/medal_skin_staff.tex"),
  Asset("ATLAS", "images/inventoryimages/medal_skin_staff.xml"),
  -- 容器格子 UI（鱼箱 5×4 布局）
  Asset("ANIM", "anim/ui_fish_box_5x4.zip"),
}

---------------------------------------------------------------------
-- HSee 配方
---------------------------------------------------------------------
-- 当配置开启时才注册配方
if config.hsee_enable then
  AddRecipe2(
    "hsee",
    {
      Ingredient("goldnugget", 1),
      Ingredient("cutgrass", 1),
    },
    TECH.NONE,
    {
      atlas = "images/inventoryimages/medal_skin_staff.xml",
      image = "medal_skin_staff.tex",
      numtogive = 1,
      nounlock = false,
    },
    { "TOOLS" }
  )

  -----------------------------------------
  -- 本地化（英文 & 中文）
  -----------------------------------------
  STRINGS.NAMES.HSEE = "HSee"
  STRINGS.RECIPE_DESC.HSEE = "A portable viewer for inspecting and swapping items."
  STRINGS.CHARACTERS.GENERIC.DESCRIBE.HSEE = "Let me see what's in here!"

  -- 中文覆盖（配合 modinfo 的语言判断）
  local lang = GLOBAL.LanguageTranslator and GLOBAL.LanguageTranslator.defaultlang or "en"
  if lang == "zh" or lang == "zhr" or lang == "zht" then
    STRINGS.NAMES.HSEE = "HSee"
    STRINGS.RECIPE_DESC.HSEE = "便携式物品查看器，可查看和交换物品。"
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.HSEE = "让我看看这里面有什么！"
  end
end
