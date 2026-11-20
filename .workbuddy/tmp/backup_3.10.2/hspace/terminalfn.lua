local TOOLS = {}
local WEAPONS = {}
local REFINE = {
    ["charcoal"] = true,
    ["dreadstone"] = true,
    ["driftwood_log"] = true,
    ["horrorfuel"] = true,
    ["lunarplant_husk"] = true,
    ["purebrilliance"] = true,
    ["twigs"] = true,
    ["voidcloth"] = true,
    ["wagpunk_bits"] = true,
    ["flint"] = true,
    ["townportaltalisman"] = true,
    ["gears"] = true,
    ["moonglass"] = true,
    ["thulecite"] = true,
    ["goose_feather"] = true,
    ["feather_crow"] = true,
    ["feather_robin"] = true,
    ["feather_robin_winter"] = true,
    ["feather_canary"] = true,
    ["houndstooth"] = true,
    ["walrus_tusk"] = true,
    ["boneshard"] = true,
    ["fossil_piece"] = true,
    ["lightninggoathorn"] = true,
    ["slurtle_shellpieces"] = true,
    ["cookiecuttershell"] = true,
    ["pigskin"] = true,
    ["tentaclespots"] = true,
    ["slurper_pelt"] = true,
    ["dragon_scales"] = true,
    ["shroom_skin"] = true,
    ["manrabbit_tail"] = true,
    ["beefalowool"] = true,
    ["steelwool"] = true,
    ["beardhair"] = true,
    ["stinger"] = true,
    ["spidergland"] = true,
}
local MAGIC = {
    ["dreadstone"] = true,
    ["ancientfruit_gem"] = true,
}
local GARDENING = {}


for recipe_name, recipe in pairs(AllRecipes) do
    -- tool check
    for i, name in ipairs(CRAFTING_FILTERS.TOOLS.recipes) do
        if name == recipe_name then
            TOOLS[recipe.product] = true
            break
        end
    end
    -- weapon check
    for i, name in ipairs(CRAFTING_FILTERS.WEAPONS.recipes) do
        if name == recipe_name then
            WEAPONS[recipe.product] = true
            break
        end
    end
    -- refine check
    local isrefine
    for i, name in ipairs(CRAFTING_FILTERS.REFINE.recipes) do
        if name == recipe_name then
            isrefine = true
            break
        end
    end
    if isrefine then
        REFINE[recipe.product] = true
        if recipe.ingredients then
            for i, ingredient in ipairs(recipe.ingredients) do
                REFINE[ingredient.type] = true
            end
        end
    end
    -- magic check
    local ismagic = recipe.level.MAGIC > 1 and recipe.level.MAGIC < 5
    for i, name in ipairs(CRAFTING_FILTERS.MAGIC.recipes) do
        if name == recipe_name then
            ismagic = true
            break
        end
    end
    if ismagic then
        MAGIC[recipe.product] = true
    end
    -- gardening check
    for i, name in ipairs(CRAFTING_FILTERS.GARDENING.recipes) do
        if name == recipe_name then
            GARDENING[recipe.product] = true
            break
        end
    end
end

local function tool_filter_fn(data)
    if data.item then
        return TOOLS[data.prefab] or data.item:HasTag("tool")
    end
end

local function weapon_filter_fn(data)
    if data.item then
        if WEAPONS[data.prefab] then
            return true
        end
        if data.item:HasTag("weapon") then
            if TOOLS[data.prefab] or GARDENING[data.prefab] then
                return false
            else
                return true
            end
        end
    end
end

local function warable_filter_fn(data)
    if data.item then
        if data.item.warable then
            return true
        end
        local equipslot = data.item.replica.equippable and data.item.replica.equippable:EquipSlot()
        if equipslot then
            -- return equipslot == EQUIPSLOTS.BODY or equipslot == EQUIPSLOTS.HEAD
            return equipslot ~= EQUIPSLOTS.HANDS
        end
    end
end

local function refine_filter_fn(data)
    if data.prefab then
        return REFINE[data.prefab]
    end
end

local function magic_filter_fn(data)
    if data.item then
        if data.item:HasTag("gem") then
            return true
        end
        if data.item:HasTag("bookcabinet_item") then
            return true
        end
        if string.find(tostring(data.prefab),"staff") then
            return true
        end
        if string.find(tostring(data.prefab),"amulet") then
            return true
        end
        return MAGIC[data.prefab]
    end
end

local FOODTYPE =
{
    GENERIC = "GENERIC",
    MEAT = "MEAT",
    VEGGIE = "VEGGIE",
    SEEDS = "SEEDS",
    BERRY = "BERRY",
    RAW = "RAW",
    GOODIES = "GOODIES", 
}

local function gardening_filter_fn(data)
    if data.item then
        -- edible
        for k, foodtype in pairs(FOODTYPE) do
            if data.item:HasTag("edible_"..foodtype) then
                return true
            end
        end
        -- fertilizer
        if data.item:HasTag("fertilizer") then
            return true
        end
        return GARDENING[data.prefab]
    end
end

-- ====================================================================
-- 排序模式 / 收藏
-- 简存这里用 PersistentData 写独立文件；我们暂不做收藏持久化，
-- 排序模式只保留内存态（本次会话有效）。
-- ====================================================================
local sortmode = 2

local function get_sortmode()
    return sortmode
end

local function save_sortmode(m)
    sortmode = m
end

local function favorites_filter_fn(data)
    return false
end

local function is_favorite()
    return false
end

local function add_favorite()
end

local function remove_favorite()
end

return {
    tool_filter_fn = tool_filter_fn,
    weapon_filter_fn = weapon_filter_fn,
    warable_filter_fn = warable_filter_fn,
    refine_filter_fn = refine_filter_fn,
    magic_filter_fn = magic_filter_fn,
    gardening_filter_fn = gardening_filter_fn,
    favorites_filter_fn = favorites_filter_fn,
    is_favorite = is_favorite,
    add_favorite = add_favorite,
    remove_favorite = remove_favorite,
    get_sortmode = get_sortmode,
    save_sortmode = save_sortmode,
}
