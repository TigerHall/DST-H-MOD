-- 制图桌回收（静态预注册 + 擦除解锁接口预留）
-- 机制：加载时读官方数据表，为 6 种可擦纸预注册全部重制配方。
--       靠近任意制图桌即可花 papyrus_cost 张 papyrus 重新制作。
-- 支持的 6 种（每种用统一图标，避免页面混乱）：
--   1. 蓝图      blueprint     → 枚举 AllRecipes，有 _blueprint prefab 的注册（Mod 配方自动支持）
--   2. 食谱卡    cookingrecipecard → 枚举 cooking.recipe_cards
--   3. 草图      sketch        → 枚举 Prefabs 中的 *_sketch（排除 "sketch" 本身）
--   4. 海盗地图  stash_map     → 单一固定
--   5. 广告      tacklesketch  → 枚举 Prefabs 中的 *_tacklesketch（排除 "tacklesketch"）
--   6. 礼服款式  yotb 全套     → 枚举 yotb_costumes.costumes

-- 环境：裸写 AddRecipe2/Ingredient/TECH/TUNING/STRINGS/subfmt 自动回退 GLOBAL（Klei 标准写法）
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })
GLOBAL.require("recipes")

local config = {
    enabled = GetModConfigData("enabled"),
    papyrus_cost = GetModConfigData("papyrus_cost") or 2,
}
if config.enabled == false then return end
GLOBAL.TUNING.HMOD_CARTO = { papyrus_cost = config.papyrus_cost }

-- 语言（用 LanguageTranslator 取，避免 strict 模式下裸 locale 报错）
local cur_locale = (GLOBAL.LanguageTranslator and GLOBAL.LanguageTranslator.defaultlang) or ""
local iszh = (cur_locale == "zh" or cur_locale == "zhr" or cur_locale == "zht")
local function enzh(e, z) return iszh and z or e end

local HPAPER = {}                 -- 已注册的重制配方名（去重）
local reissue_cooking = {}        -- [配方名] = {recipe_name, cooker_name}，builditem 时补配食谱卡

-- ===== 擦除解锁接口（预留）=====
-- 当前所有配方全量显示。后续可在此钩接 DoErase 逻辑，
-- 将已擦除的配方名记入 ERASED 表，然后让 RegisterReissue 按
-- IsUnlocked 筛选——未擦除的配方不注册即不显示。
-- local ERASED = {}
-- function IsUnlocked(rname) return ERASED[rname] end

-- ===== 工具函数：注册一个重制配方 =====
-- 注册前会调用 IsUnlocked 检查（当前恒 true；后续改为查 ERASED 表）
local function RegisterReissue(rname, product, image, name_str)
    if HPAPER[rname] then return end
    if GLOBAL.Prefabs[product] == nil then return end
    HPAPER[rname] = true
    STRINGS.NAMES[string.upper(rname)] = name_str
    AddRecipe2(rname,
        { Ingredient("papyrus", TUNING.HMOD_CARTO.papyrus_cost) },
        TECH.CARTOGRAPHY_TWO,
        { nounlock = true, actionstr = "CARTOGRAPHY", product = product, image = image, no_deconstruction = true })
end

-- ===== 在加载完成时生成全部 6 种纸的重制配方 =====
AddGamePostInit(function()
    -- （闭包捕获了 modmain 顶层变量 HPAPER/reissue_cooking）

    -- 1. 蓝图：扫描 AllRecipes 中有 _blueprint prefab 的
    --    Mod 只要注册了 recipe 和对应的 _blueprint prefab，自动支持
    for _, recipe in pairs(GLOBAL.AllRecipes) do
        local bp = recipe.name .. "_blueprint"
        if GLOBAL.Prefabs[bp] then
            local rname = "reissue_blueprint_" .. recipe.name
            local name_str = (STRINGS.NAMES[string.upper(recipe.name)] or recipe.name)
                             .. " " .. (STRINGS.NAMES.BLUEPRINT or "蓝图")
            RegisterReissue(rname, bp, "blueprint.tex", name_str)
        end
    end

    -- 2. 食谱卡：读取 cooking.recipe_cards（官方表，含全部有效食谱卡条目）
    local cooking = require("cooking")
    if cooking and cooking.recipe_cards then
        for _, card in ipairs(cooking.recipe_cards) do
            local rname = "reissue_cooking_" .. card.recipe_name
            local name_str = subfmt(STRINGS.NAMES.COOKINGRECIPECARD, {
                item = STRINGS.NAMES[string.upper(card.recipe_name)] or card.recipe_name
            })
            RegisterReissue(rname, "cookingrecipecard", nil, name_str)
            reissue_cooking[rname] = {
                recipe_name = card.recipe_name,
                cooker_name = card.cooker_name,
            }
        end
    end

    -- 3. 草图：扫描 Prefabs 中 *_sketch（排除 "sketch" 本身）
    for key in pairs(GLOBAL.Prefabs) do
        local item = key:match("^(.+)_sketch$")
        if item and key ~= "sketch" then
            local rname = "reissue_sketch_" .. item
            local name_str = subfmt(STRINGS.NAMES.SKETCH, {
                item = STRINGS.NAMES[string.upper(item .. "_builder")] or item
            })
            RegisterReissue(rname, key, "sketch.tex", name_str)
        end
    end

    -- 4. 海盗地图（单一固定）
    if GLOBAL.Prefabs["stash_map"] then
        RegisterReissue("reissue_stash", "stash_map", "stash_map.tex",
            STRINGS.NAMES.STASH_MAP or enzh("Pirate Map", "海盗地图"))
    end

    -- 5. 广告（tacklesketch）：扫描 Prefabs 中 *_tacklesketch（排除 "tacklesketch"）
    for key in pairs(GLOBAL.Prefabs) do
        local item = key:match("^(.+)_tacklesketch$")
        if item and key ~= "tacklesketch" then
            local rname = "reissue_tacklesketch_" .. item
            local name_str = subfmt(STRINGS.NAMES.TACKLESKETCH, {
                item = STRINGS.NAMES[string.upper(item)] or item
            })
            RegisterReissue(rname, key, "tacklesketch.tex", name_str)
        end
    end

    -- 6. 礼服款式：读取 yotb_costumes 表
    local ok, yotb = pcall(require, "yotb_costumes")
    if ok and yotb and yotb.costumes then
        for _, v in pairs(yotb.costumes) do
            -- 只注册有 test 的（即官方实际注册为 prefab 的款式）
            if v.test ~= nil and v.prefab_name and GLOBAL.Prefabs[v.prefab_name] then
                local rname = "reissue_costume_" .. v.prefab_name
                local name_str = STRINGS.NAMES[string.upper(v.prefab_name)]
                            or enzh("Costume Pattern", "礼服款式")
                RegisterReissue(rname, v.prefab_name, "blueprint_sewing_machine_yotb.tex", name_str)
            end
        end
    end
end)

-- ===== 食谱卡：做出后补配具体内容 =====
-- cookingrecipecard 是泛用 prefab（无专用 prefab），spawn 后靠 SetRecipe 设定
AddPlayerPostInit(function(inst)
    inst:ListenForEvent("builditem", function(player, data)
        if data == nil or data.item == nil or data.recipe == nil then return end
        local cfg = reissue_cooking[data.recipe.name]
        if cfg == nil then return end
        local item = data.item
        if item.components ~= nil and item.components.named ~= nil then
            item.recipe_name = cfg.recipe_name
            item.cooker_name = cfg.cooker_name
            item.components.named:SetName(subfmt(STRINGS.NAMES.COOKINGRECIPECARD,
                { item = STRINGS.NAMES[string.upper(cfg.recipe_name)] or cfg.recipe_name }))
        end
    end)
end)
