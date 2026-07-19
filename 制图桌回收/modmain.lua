-- 制图桌回收（nounlock=true + canbuild 灰显控制）
-- 机制：
--   - 全部配方预注册 nounlock=true → 显示在制图桌正确标签页
--   - canbuild 检查世界组件 hmod_carto_erased 是否已擦除
--   - 未擦除的配方灰显，擦除后可用（全服共享）
--   - 随机配方额外预注册，直接可用
-- 依赖：scripts/components/hmod_carto_erased.lua

GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })
GLOBAL.require("recipes")

local config = {
    enabled = GetModConfigData("enabled"),
    papyrus_cost = GetModConfigData("papyrus_cost") or 2,
    enable_random = GetModConfigData("enable_random") or false,
    random_cost = GetModConfigData("random_cost") or 5,
    randombp_all = GetModConfigData("randombp_all") or false,
}
if config.enabled == false then return end
GLOBAL.TUNING.HMOD_CARTO = { papyrus_cost = config.papyrus_cost }

local cur_locale = (GLOBAL.LanguageTranslator and GLOBAL.LanguageTranslator.defaultlang) or ""
local iszh = (cur_locale == "zh" or cur_locale == "zhr" or cur_locale == "zht")
local function enzh(e, z) return iszh and z or e end

local HPAPER = {}            -- 已注册配方名（去重）
local reissue_cooking = {}   -- [rname] = {recipe_name, cooker_name}
local PAPER_TO_RECIPE = {}   -- [product_prefab] = rname

-- ===== 注册一个重制配方 =====
-- nounlock=true → 始终在制图桌标签页显示（灰显/可用由 canbuild 控制）
local function RegisterReissue(rname, product, image, name_str)
    if HPAPER[rname] then return end
    if GLOBAL.Prefabs[product] == nil then return end
    HPAPER[rname] = true
    PAPER_TO_RECIPE[product] = rname
    STRINGS.NAMES[string.upper(rname)] = name_str
    AddRecipe2(rname,
        { Ingredient("papyrus", TUNING.HMOD_CARTO.papyrus_cost) },
        TECH.CARTOGRAPHY_TWO,
        {
            nounlock = true,
            actionstr = "CARTOGRAPHY",
            product = product,
            image = image,
            canbuild = function()
                return TheWorld and TheWorld.components.hmod_carto_erased
                    and TheWorld.components.hmod_carto_erased:HasEntry(rname)
            end,
            no_deconstruction = true,
        })
end

-- ===== 全量蓝图随机选择 =====
local function PickAllBlueprint(player)
    local candidates = {}
    for name in pairs(AllRecipes) do
        if GLOBAL.Prefabs[name.."_blueprint"]
            and not player.components.builder:KnowsRecipe(name) then
            table.insert(candidates, name)
        end
    end
    if #candidates == 0 then
        for name in pairs(AllRecipes) do
            if GLOBAL.Prefabs[name.."_blueprint"] then
                table.insert(candidates, name)
            end
        end
    end
    return #candidates > 0 and candidates[math.random(#candidates)] or nil
end

-- ===== 世界级擦除解锁组件 =====
AddPrefabPostInit("world", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.hmod_carto_erased then return end
    inst:AddComponent("hmod_carto_erased")
end)

-- ===== 擦除动作钩子 =====
-- 只写入世界组件，canbuild 自动放行
AddComponentPostInit("erasablepaper", function(self)
    local _DoErase = self.DoErase
    self.DoErase = function(self, eraser, doer)
        local paper = self.inst
        local prefab = paper.prefab
        local rname = nil

        -- 1. 从逆向查找表通过 prefab 名匹配
        rname = PAPER_TO_RECIPE[prefab]

        -- 2. imagename 兜底
        if not rname and paper.components.inventoryitem then
            local img = paper.components.inventoryitem.imagename
            if img and img ~= prefab and img ~= "blueprint" and img ~= "sketch"
                and img ~= "tacklesketch" and img ~= "cookingrecipecard" then
                rname = PAPER_TO_RECIPE[img]
            end
        end

        -- 3. cookingrecipecard
        if not rname and prefab == "cookingrecipecard" and paper.recipe_name then
            rname = "reissue_cooking_" .. paper.recipe_name
        end

        -- 4. 蓝图 teacher+recipetouse
        if not rname and paper.components.teacher and paper.recipetouse
            and type(paper.recipetouse) == "string" and paper.recipetouse ~= "unknown" then
            rname = "reissue_blueprint_" .. paper.recipetouse
        end

        if rname and TheWorld and TheWorld.components.hmod_carto_erased then
            TheWorld.components.hmod_carto_erased:Unlock(rname)
        end

        return _DoErase(self, eraser, doer)
    end
end)

-- ===== 预注册全部配方 =====
AddGamePostInit(function()
    -- 1. 蓝图
    for _, recipe in pairs(GLOBAL.AllRecipes) do
        local bp = recipe.name .. "_blueprint"
        if GLOBAL.Prefabs[bp] then
            local rname = "reissue_blueprint_" .. recipe.name
            local name_str = (STRINGS.NAMES[string.upper(recipe.name)] or recipe.name)
                             .. " " .. (STRINGS.NAMES.BLUEPRINT or "蓝图")
            RegisterReissue(rname, bp, "blueprint.tex", name_str)
        end
    end

    -- 2. 食谱卡
    local cooking = require("cooking")
    if cooking and cooking.recipe_cards then
        for _, card in ipairs(cooking.recipe_cards) do
            local rname = "reissue_cooking_" .. card.recipe_name
            local name_str = subfmt(STRINGS.NAMES.COOKINGRECIPECARD, {
                item = STRINGS.NAMES[string.upper(card.recipe_name)] or card.recipe_name
            })
            RegisterReissue(rname, "cookingrecipecard", "cookingrecipecard.tex", name_str)
            reissue_cooking[rname] = {
                recipe_name = card.recipe_name,
                cooker_name = card.cooker_name,
            }
        end
    end

    -- 3. 草图
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

    -- 4. 海盗地图
    if GLOBAL.Prefabs["stash_map"] then
        RegisterReissue("reissue_stash", "stash_map", "stash_map.tex",
            STRINGS.NAMES.STASH_MAP or enzh("Pirate Map", "海盗地图"))
    end

    -- 5. 渔具广告
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

    -- 6. 礼服款式
    local ok, yotb = pcall(require, "yotb_costumes")
    if ok and yotb and yotb.costumes then
        for _, v in pairs(yotb.costumes) do
            if v.test ~= nil and v.prefab_name and GLOBAL.Prefabs[v.prefab_name] then
                local rname = "reissue_costume_" .. v.prefab_name
                local name_str = STRINGS.NAMES[string.upper(v.prefab_name)]
                            or enzh("Costume Pattern", "礼服款式")
                RegisterReissue(rname, v.prefab_name, "blueprint_sewing_machine_yotb.tex", name_str)
            end
        end
    end

    -- 7. 随机配方（nounlock=true，无 canbuild → 始终可用）
    if config.enable_random then
        local rbp_name = "hmod_rand_blueprint"
        STRINGS.NAMES[string.upper(rbp_name)] = enzh("Random Blueprint", "随机蓝图")
        AddRecipe2(rbp_name,
            { Ingredient("papyrus", config.random_cost) },
            TECH.CARTOGRAPHY_TWO,
            {
                nounlock = true,
                actionstr = "CARTOGRAPHY",
                product = "blueprint",
                image = "blueprint.tex",
                no_deconstruction = true,
            })

        local rrc_name = "hmod_rand_recipecard"
        STRINGS.NAMES[string.upper(rrc_name)] = enzh("Random Recipe Card", "随机食谱卡")
        AddRecipe2(rrc_name,
            { Ingredient("papyrus", config.random_cost) },
            TECH.CARTOGRAPHY_TWO,
            {
                nounlock = true,
                actionstr = "CARTOGRAPHY",
                product = "cookingrecipecard",
                image = "cookingrecipecard.tex",
                no_deconstruction = true,
            })
    end
end)

-- ===== 食谱卡 builditem 补配 =====
AddPlayerPostInit(function(inst)
    inst:ListenForEvent("builditem", function(player, data)
        if data == nil or data.item == nil or data.recipe == nil then return end
        local item = data.item
        if item.components == nil or item.components.named == nil then return end

        local cfg = reissue_cooking[data.recipe.name]
        if cfg then
            item.recipe_name = cfg.recipe_name
            item.cooker_name = cfg.cooker_name
            item.components.named:SetName(subfmt(STRINGS.NAMES.COOKINGRECIPECARD,
                { item = STRINGS.NAMES[string.upper(cfg.recipe_name)] or cfg.recipe_name }))
            return
        end

        if data.recipe.name == "hmod_rand_recipecard" then
            local cooking = require("cooking")
            if cooking and cooking.recipe_cards then
                local card = cooking.recipe_cards[math.random(#cooking.recipe_cards)]
                item.recipe_name = card.recipe_name
                item.cooker_name = card.cooker_name
                item.components.named:SetName(subfmt(STRINGS.NAMES.COOKINGRECIPECARD,
                    { item = STRINGS.NAMES[string.upper(card.recipe_name)] or card.recipe_name }))
            end
        end

        if data.recipe.name == "hmod_rand_blueprint" and config.randombp_all then
            local chosen = PickAllBlueprint(player)
            if chosen then
                local item = data.item
                item.recipetouse = chosen
                item.components.teacher:SetRecipe(chosen)
                item.components.named:SetName(
                    (STRINGS.NAMES[string.upper(chosen)] or chosen)
                    .. " " .. (STRINGS.NAMES.BLUEPRINT or "蓝图"))
            end
        end
    end)
end)
