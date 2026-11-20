-- scripts/hspace/fakecontainer.lua
-- ═══════════════════════════════════════════════════════════════════════
-- 假容器（搬自「简易存储 / ss_util/fakecontainer.lua」，数据源换成记录池）
--
-- 简存的 FakeContainer 从**真实容器实体**拍快照；我们没有任何实体，
-- 直接由 datastore 的快照数组生成。
--
-- ⚠️ 槽位号用的是 **uid**，不是数组下标：
--    客户端会按筛选/排序重排格子，下标在服务端毫无意义；
--    uid 单调递增、永不复用，RPC 拿它一定能定位到记录。
--
-- 只在客户端构造：服务端由 RPC handler 直接操作 datastore。
-- ═══════════════════════════════════════════════════════════════════════

local Log = require("hspace/log")
local FakeItem = require("hspace/fakeitem")

local RPC_NAME = "hspace"

local function ServerRpc(name)
    if GetModRPC ~= nil then
        return GetModRPC(RPC_NAME, name)
    end
    local t = MOD_RPC ~= nil and MOD_RPC[RPC_NAME] or nil
    return t ~= nil and t[name] or nil
end

-- ====================================================================
-- 生成
-- ====================================================================
local function GetTableSize(t)
    local n = 0
    if t ~= nil then
        for _ in pairs(t) do
            n = n + 1
        end
    end
    return n
end

local function HspaceFakeContainer(vault_id, items)
    -- ⚠️ 必须是**数组**：简存的 Refresh/MakeInvGrid 用 `for slot = 1, numslots`
    -- 数字索引取物品。uid 挂在元素自己身上，只在发 RPC 时读出来用。
    local slots = {}
    local n = 0
    for i = 1, #(items or {}) do
        local it = items[i]
        if it ~= nil and it.uid ~= nil then
            n = n + 1
            slots[n] = it
        end
    end

    return {
        GUID = "hspace_" .. tostring(vault_id),
        prefab = "hspace_vault",
        vault_id = vault_id,
        ispreserver = true,   -- 仓库里不吃腐烂
        replica = {
            container = {
                numslots = n,
                slots = slots,
                acceptsstacks = true,
                infinitestacksize = true,
                widgetprefab = nil,
            },
        },
    }
end

-- ====================================================================
-- 客户端元表
-- ====================================================================
local ReturnFalse = function()
    return false
end
local ReturnTrue = function()
    return true
end

local inst_meta = {
    __index = {
        IsValid = ReturnTrue,
        HasTag = ReturnFalse,
        HasTags = ReturnFalse,
        HasAllTags = ReturnFalse,
        HasOneOfTags = ReturnFalse,
        HasAnyTag = ReturnFalse,
    },
}

-- 数组下标 → uid（RPC 只认 uid）
local function UidOf(self, slot)
    local it = self.slots[slot]
    return it ~= nil and it.uid or nil
end

local function GetNumSlots(self)
    return self.numslots
end

local function GetItemInSlot(self, slot)
    return self.slots[slot]
end

local function GetItems(self)
    return self.slots
end

local function GetWidget(self)
    return {}
end

local function IsInfiniteStackSize(self)
    return self.infinitestacksize
end

local function AcceptsStacks(self)
    return self.acceptsstacks
end

local function CanTakeItemInSlot(self, item, uid)
    return item ~= nil
        and item.replica ~= nil
        and item.replica.inventoryitem ~= nil
        and item.replica.inventoryitem:CanGoInContainer()
end

local function Has(self, prefab, amount, iscrafting)
    local found = 0
    for _, v in pairs(self.slots) do
        if v ~= nil and v.prefab == prefab
            and not (iscrafting and v:HasTag("nocrafting")) then
            if v.replica ~= nil and v.replica.stackable ~= nil then
                found = found + v.replica.stackable:StackSize()
            else
                found = found + 1
            end
        end
    end
    return found >= amount, found
end

local function HasItemWithTag(self, tag, amount)
    local found = 0
    for _, v in pairs(self.slots) do
        if v ~= nil and v:HasTag(tag) then
            if v.replica ~= nil and v.replica.stackable ~= nil then
                found = found + v.replica.stackable:StackSize()
            else
                found = found + 1
            end
        end
    end
    return found >= amount, found
end

local function IsFull(self)
    return GetTableSize(self.slots) >= (self.numslots or 0)
end

local function IsEmpty(self)
    return GetTableSize(self.slots) == 0
end

-- ---- 取到鼠标上 ----
local function TakeToMouse(self, slot, count)
    local rpc = ServerRpc("take_mouse")
    if rpc == nil then
        Log.E("fakecontainer", "RPC 未注册（take_mouse）")
        return
    end
    local uid = UidOf(self, slot)
    if uid == nil then
        return
    end
    local vault_id = self.inst ~= nil and self.inst.vault_id or nil
    SendModRPCToServer(rpc, vault_id, uid, count or -1)
end

local function TakeActiveItemFromAllOfSlot(self, slot)
    TakeToMouse(self, slot, -1)
end

local function TakeActiveItemFromHalfOfSlot(self, slot)
    local item = self.slots[slot]
    local half = -1
    if item ~= nil and item.replica ~= nil and item.replica.stackable ~= nil then
        half = math.max(1, math.floor(item.replica.stackable:StackSize() / 2))
    end
    TakeToMouse(self, uid, half)
end

local function TakeActiveItemFromOneOfSlot(self, slot)
    TakeToMouse(self, slot, 1)
end

-- ---- 取到背包 ----
local function TakeToInventory(self, slot, count)
    local rpc = ServerRpc("take")
    if rpc == nil then
        Log.E("fakecontainer", "RPC 未注册（take）")
        return
    end
    local uid = UidOf(self, slot)
    if uid == nil then
        return
    end
    local vault_id = self.inst ~= nil and self.inst.vault_id or nil
    SendModRPCToServer(rpc, vault_id, uid, count or -1)
end

local function MoveItemFromAllOfSlot(self, slot, dest)
    TakeToInventory(self, slot, -1)
end

local function MoveItemFromHalfOfSlot(self, slot, dest)
    local item = self.slots[slot]
    local half = -1
    if item ~= nil and item.replica ~= nil and item.replica.stackable ~= nil then
        half = math.max(1, math.floor(item.replica.stackable:StackSize() / 2))
    end
    TakeToInventory(self, uid, half)
end

local container_meta = {
    __index = {
        Open = ReturnFalse,
        Close = ReturnFalse,
        IsBusy = ReturnFalse,
        IsSideWidget = ReturnFalse,
        IsOpenedBy = ReturnTrue,
        CanBeOpened = ReturnTrue,
        IsInfiniteStackSize = IsInfiniteStackSize,
        IsReadOnlyContainer = ReturnFalse,
        ShouldPrioritizeContainer = ReturnFalse,

        GetNumSlots = GetNumSlots,
        GetItemInSlot = GetItemInSlot,
        GetItems = GetItems,
        GetWidget = GetWidget,

        CanTakeItemInSlot = CanTakeItemInSlot,
        AcceptsStacks = AcceptsStacks,
        Has = Has,
        IsFull = IsFull,
        IsEmpty = IsEmpty,
        HasItemWithTag = HasItemWithTag,

        TakeActiveItemFromAllOfSlot = TakeActiveItemFromAllOfSlot,
        TakeActiveItemFromHalfOfSlot = TakeActiveItemFromHalfOfSlot,
        TakeActiveItemFromOneOfSlot = TakeActiveItemFromOneOfSlot,
        MoveItemFromAllOfSlot = MoveItemFromAllOfSlot,
        MoveItemFromHalfOfSlot = MoveItemFromHalfOfSlot,
    },
}

local function ModifyFakeContainer(inst)
    inst.IsFake = true
    setmetatable(inst, inst_meta)
    local container = inst.replica.container
    container.inst = inst
    setmetatable(container, container_meta)

    for i = 1, #container.slots do
        local item = container.slots[i]
        if item ~= nil then
            FakeItem.ModifyFakeItem(item)
        end
    end
end

return {
    HspaceFakeContainer = HspaceFakeContainer,
    ModifyFakeContainer = ModifyFakeContainer,
}
