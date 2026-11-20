-- scripts/hspace/fakeitem.lua
-- ═══════════════════════════════════════════════════════════════════════
-- 假物品：客户端侧把「一份服务端快照」伪装成实体物品
--
-- 结构对齐「简易存储 338307330/ss_util/fakeitem.lua:88-256」，
-- 因为 datastore 的 view 就是照 FakeItem 的形状生成的，这里只是补元表。
--
-- 为什么要伪装：
--   官方 ItemTile / InvSlot 全都在调 item:HasTag() / item.replica.stackable:StackSize()
--   这类实体方法。仓库里的东西在客户端根本没有实体，只能拿一份表冒充。
-- ═══════════════════════════════════════════════════════════════════════

local Log = require("hspace/log")

local ReturnFalse = function()
    return false
end
local ReturnTrue = function()
    return true
end

-- Item
local function HasTag(item, tag)
    return item.tags ~= nil and item.tags[tag] ~= nil
end

local function HasTags(item, ...)
    local tags = select(1, ...)
    if type(tags) ~= "table" then
        tags = { ... }
    end
    for i = 1, #tags do
        if not HasTag(item, tags[i]) then
            return false
        end
    end
    return true
end

local function HasOneOfTags(item, ...)
    local tags = select(1, ...)
    if type(tags) ~= "table" then
        tags = { ... }
    end
    for i = 1, #tags do
        if HasTag(item, tags[i]) then
            return true
        end
    end
    return false
end

local function GetAdjective(item)
    return item.adjective
end

local function GetDisplayName(item)
    return item.name
end

local function StackableSkinHack(item, target)
    return target ~= nil and target.AnimState ~= nil
        and target.AnimState:GetSkinBuild() == item.AnimState.skinbuild
end

local function GetSkinBuild(anim)
    return anim.skinbuild
end

-- Stackable replica
local function IsStack(self)
    return (self.stacksize or 1) > 1
end
local function StackSize(self)
    return self.stacksize or 1
end
local function MaxSize(self)
    return self.maxsize or 1
end
local function IsFull(self)
    return (self.stacksize or 1) >= (self.maxsize or 1)
end
local function OriginalMaxSize(self)
    return self.originalmaxsize or self.maxsize or 1
end

-- Inventoryitem replica
local function GetAtlas(self)
    return self.atlas
end
local function GetImage(self)
    return self.image
end
local function IsWeapon(self)
    return self.inst ~= nil and self.inst:HasTag("weapon")
end

-- Equippable replica（筛选 GEAR 用得上）
local function EquipSlot(self)
    return self.equipslot
end

local item_meta = {
    __index = {
        HasTag = HasTag,
        HasTags = HasTags,
        HasAllTags = HasTags,
        HasOneOfTags = HasOneOfTags,
        HasAnyTag = HasOneOfTags,
        IsValid = ReturnTrue,
        IsAcidSizzling = ReturnFalse,
        GetAdjective = GetAdjective,
        GetDisplayName = GetDisplayName,
        GetAdjectivedName = GetDisplayName,
        GetBasicDisplayName = GetDisplayName,
        GetIsWet = ReturnFalse,
        StackableSkinHack = StackableSkinHack,
    },
}

local AnimState_meta = {
    __index = {
        GetSkinBuild = GetSkinBuild,
    },
}

local stackable_meta = {
    __index = {
        IsStack = IsStack,
        StackSize = StackSize,
        MaxSize = MaxSize,
        IsFull = IsFull,
        OriginalMaxSize = OriginalMaxSize,
    },
}

local inventoryitem_meta = {
    __index = {
        GetAtlas = GetAtlas,
        GetImage = GetImage,
        CanGoInContainer = ReturnTrue,
        CanOnlyGoInPocket = ReturnFalse,
        CanOnlyGoInPocketOrPocketContainers = ReturnFalse,
        IsGrandOwner = ReturnFalse,
        IsHeld = ReturnFalse,
        IsHeldBy = ReturnFalse,
        IsDeployable = ReturnFalse,
        IsWeapon = IsWeapon,
        GetWalkSpeedMult = function()
            return 1
        end,
        GetMoisture = function()
            return 0
        end,
        IsWet = ReturnFalse,
        IsAcidSizzling = ReturnFalse,
    },
}

local equippable_meta = {
    __index = {
        EquipSlot = EquipSlot,
        CanEquip = ReturnTrue,
        IsRestrictedDynamic = ReturnFalse,
    },
}

-- ====================================================================
-- 快照 → 可用的 fake item
-- snapshot 必须是 datastore.PackForClient() 里的一项（已经过 zip RPC）
-- ====================================================================
local function MakeFakeItem(snapshot)
    if snapshot == nil or snapshot.prefab == nil then
        return nil
    end

    -- 深拷一份，别让多个格子共享同一个表（改堆叠数会互相污染）
    local item = {}
    for k, v in pairs(snapshot) do
        item[k] = v
    end

    -- RPC / ItemTile 用 GUID 认物品，我们的稳定标识是 uid
    item.GUID = snapshot.uid

    item.AnimState = item.AnimState or {}
    -- maxsize 从服务端传来时可能是字符串 "inf"，这里还原成 math.huge
    local replica = item.replica or {}
    item.replica = replica
    local stackable = replica.stackable
    if stackable ~= nil and stackable.maxsize == "inf" then
        stackable.maxsize = math.huge
    end
    replica.inventoryitem = replica.inventoryitem or {}
    -- ⚠️ Image:SetTexture 是 assert(atlas ~= nil) / assert(tex ~= nil)
    -- （widgets/image.lua:84-85），传 nil 直接断言崩溃。
    -- 服务端算 atlas 时可能因为 atlas 未加载而拿到 nil，这里兜一层底，
    -- 顶多图标显示成一个空白格，不会让整个面板炸掉。
    if replica.inventoryitem.atlas == nil then
        replica.inventoryitem.atlas = "images/inventoryimages1.xml"
        Log.W("fakeitem", "缺 atlas，已兜底:", tostring(snapshot.prefab))
    end
    if replica.inventoryitem.image == nil then
        replica.inventoryitem.image = tostring(snapshot.prefab) .. ".tex"
        Log.W("fakeitem", "缺 image，已兜底:", tostring(snapshot.prefab))
    end

    if item.equipslot ~= nil then
        replica.equippable = replica.equippable or { equipslot = item.equipslot }
        replica.equippable.inst = item
        setmetatable(replica.equippable, equippable_meta)
    end

    setmetatable(item, item_meta)
    setmetatable(item.AnimState, AnimState_meta)
    if stackable ~= nil then
        stackable.inst = item
        setmetatable(stackable, stackable_meta)
    end
    replica.inventoryitem.inst = item
    setmetatable(replica.inventoryitem, inventoryitem_meta)

    return item
end

-- 就地给一个已经构造好的表补元表（服务端数据直接复用时用）
local function ModifyFakeItem(item)
    if item == nil then
        return nil
    end
    item.IsFake = true
    setmetatable(item, item_meta)
    item.AnimState = item.AnimState or {}
    setmetatable(item.AnimState, AnimState_meta)

    local replica = item.replica or {}
    item.replica = replica
    local stackable = replica.stackable
    if stackable ~= nil then
        if stackable.maxsize == "inf" then
            stackable.maxsize = math.huge
        end
        stackable.inst = item
        setmetatable(stackable, stackable_meta)
    end
    replica.inventoryitem = replica.inventoryitem or {}

    -- ⚠️ Image:SetTexture 里是 assert(atlas ~= nil) / assert(tex ~= nil)
    -- （widgets/image.lua:84-85）。服务端算 atlas 时可能因为 atlas 尚未加载
    -- 而拿到 nil，直接传进去就是整块面板崩。这里兜底成"空白图标"。
    if replica.inventoryitem.atlas == nil then
        replica.inventoryitem.atlas = "images/inventoryimages1.xml"
        Log.W("fakeitem", "缺 atlas，已兜底:", tostring(item.prefab))
    end
    if replica.inventoryitem.image == nil then
        replica.inventoryitem.image = tostring(item.prefab) .. ".tex"
        Log.W("fakeitem", "缺 image，已兜底:", tostring(item.prefab))
    end
    -- inv_image_bg 必须是带 atlas/image 的表，否则 ItemTile 里 SetTexture 也会崩
    if type(item.inv_image_bg) ~= "table"
        or item.inv_image_bg.atlas == nil
        or item.inv_image_bg.image == nil then
        item.inv_image_bg = nil
    end

    replica.inventoryitem.inst = item
    setmetatable(replica.inventoryitem, inventoryitem_meta)

    if item.equipslot ~= nil then
        replica.equippable = replica.equippable or { equipslot = item.equipslot }
        replica.equippable.inst = item
        setmetatable(replica.equippable, equippable_meta)
    end
    return item
end

return {
    MakeFakeItem = MakeFakeItem,
    ModifyFakeItem = ModifyFakeItem,
}
