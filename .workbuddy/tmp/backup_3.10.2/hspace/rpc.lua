-- scripts/hspace/rpc.lua
-- ═══════════════════════════════════════════════════════════════════════
-- hspace 网络层
--
-- ⚠️ 本文件只**提供**处理函数，注册动作统一放在 modmain 里做。
--    原因：require 加载的模块跑在 _G 环境，不是 modmain 的 env，
--    env 里的 AddModRPCHandler / AddClientModRPCHandler 包装函数在这里不可见；
--    而裸调全局版本又依赖 networkrpc/networkclientrpc 的加载时序。
--    由 modmain 注册就不存在这些不确定性。
--
-- 数据流：
--   打开面板 → pull → 服务端 PackForClient() → zip JSON → snapshot → 客户端渲染
--   点格子   → take/put → 服务端操作记录池 → 自动回推一次 snapshot
--
-- 为什么整包推：简易存储 main/rpc.lua:11-47 就是这条路
--   （TheSim:EncodeAndZipString → 一条 RPC 字符串 → DecodeAndUnzipString）
-- ═══════════════════════════════════════════════════════════════════════

local Log = require("hspace/log")
local Store = require("hspace/datastore")

local RPC_NAME = "hspace"

-- ⚠️ 两个方向用的是**两张不同的表**：
--   client → server : MOD_RPC        → GetModRPC(namespace, name)
--   server → client : CLIENT_MOD_RPC → GetClientModRPC(namespace, name)
-- 用 MOD_RPC 去取 server→client 的 id 永远是 nil，
-- 日志会显示「RPC 未注册」，但其实是查错了表。
local function ServerRpc(name)
    if GetModRPC ~= nil then
        return GetModRPC(RPC_NAME, name)
    end
    local t = MOD_RPC ~= nil and MOD_RPC[RPC_NAME] or nil
    return t ~= nil and t[name] or nil
end

local function ClientRpc(name)
    if GetClientModRPC ~= nil then
        return GetClientModRPC(RPC_NAME, name)
    end
    -- 兜底：专用服务器上可能没有 GetClientModRPC，但 CLIENT_MOD_RPC 表
    -- 是由 AddClientModRPCHandler 建立的
    local t = CLIENT_MOD_RPC ~= nil and CLIENT_MOD_RPC[RPC_NAME] or nil
    return t ~= nil and t[name] or nil
end

-- ====================================================================
-- 客户端：当前打开的面板
-- ====================================================================
local function ClientPanel()
    local pl = ThePlayer
    if pl == nil or pl.HUD == nil or pl.HUD.controls == nil then
        return nil
    end
    return pl.HUD.controls.hspace_panel
end

-- ====================================================================
-- 服务端 → 客户端
-- ====================================================================
local function PushSnapshot(player, id)
    if player == nil or not player:IsValid() then
        return
    end
    local store = Store.Get(id or "hslot")
    if store == nil then
        Log.W("rpc.push", "服务端没有这个库:", tostring(id))
        return
    end

    local ok, items = pcall(function()
        return store:PackForClient()
    end)
    if not ok then
        Log.E("rpc.push", "PackForClient 异常:", tostring(items))
        return
    end

    -- ⚠️ ZipAndEncodeString 直接吃 Lua 表，内部自己 DataDumper 序列化
    --    （官方 util.lua:1693-1695）。不要再套 json.encode，
    --    那样等于序列化两次，解压端还会因为拿到的是表而崩。
    local ok2, encoded = pcall(function()
        return ZipAndEncodeString(items)
    end)
    if not ok2 or encoded == nil then
        Log.E("rpc.push", "压缩失败:", tostring(encoded))
        return
    end

    local rpc = ClientRpc("snapshot")
    if rpc == nil then
        Log.E("rpc.push", "RPC 未注册（snapshot），快照发不出去")
        return
    end
    Log.D("rpc.push", string.format("推送 %s：%d 条，压缩后 %d 字节",
        tostring(id), #items, #encoded))
    SendModRPCToClient(rpc, player, id or "hslot", encoded)
end

-- 客户端收快照
local function OnSnapshot(id, encoded)
    Log.D("rpc", "收到快照 id=" .. tostring(id)
        .. " 压缩长度=" .. tostring(encoded ~= nil and #encoded or -1))

    -- ⚠️ DecodeAndUnzipString 返回的**已经是 Lua 表**（官方 util.lua:1698-1707，
    --    内部 DecodeAndUnzipString + RunInSandbox 反序列化），
    --    不是 JSON 文本。再套一层 json.decode 会直接崩。
    --    另外它解压失败时返回的是空表 {}，不抛错，所以只能靠类型判断。
    local ok, items = pcall(function()
        return DecodeAndUnzipString(encoded)
    end)
    if not ok or type(items) ~= "table" then
        Log.E("rpc", "解压失败:", tostring(items))
        return
    end

    local panel = ClientPanel()
    if panel == nil then
        Log.W("rpc", "解码成功但面板没开，丢弃快照")
        return
    end
    Log.D("rpc", "快照解析成功，共 " .. tostring(#items) .. " 条")
    Log.Safe("rpc.snapshot", function()
        panel:SetSnapshot(id, items)
    end)
end

-- ====================================================================
-- 客户端 → 服务端
-- ====================================================================

-- 拉快照
local function OnPull(player, id)
    Log.D("rpc", "收到 pull：" .. tostring(id) .. " from " .. tostring(player))
    local store = Store.Get(id)
    if store == nil then
        return
    end
    store:WhenReady(function()
        PushSnapshot(player, id)
    end)
end

-- 取出：count 为 nil 或 <= 0 表示整栈
local function OnTake(player, id, uid, count)
    if player == nil or not player:IsValid() then
        return
    end
    local store = Store.Get(id)
    if store == nil then
        return
    end

    store:WhenReady(function(s)
        local n = nil
        if type(count) == "number" and count > 0 then
            n = count
        end

        local item = nil
        Log.Safe("rpc.take", function()
            item = s:SpawnRecordByUID(uid, nil, n, player)
        end)

        if item == nil then
            Log.W("rpc.take", "取不出物品 uid=" .. tostring(uid))
            PushSnapshot(player, id)
            return
        end

        local inv = player.components ~= nil and player.components.inventory or nil
        if inv == nil then
            Log.E("rpc.take", "玩家没有 inventory 组件")
        else
            local ok, given = pcall(function()
                return inv:GiveItem(item)
            end)
            if not ok or not given then
                Log.W("rpc.take", "背包放不下，物品留在地上:", tostring(item.prefab))
                local p = player:GetPosition()
                item.Transform:SetPosition(p.x, 0, p.z)
                if item.components ~= nil and item.components.inventoryitem ~= nil then
                    item.components.inventoryitem:OnDropped(true, .5)
                end
            end
        end

        PushSnapshot(player, id)
    end)
end

-- 取到鼠标上（GiveActiveItem）——和官方容器"点一下拿到手上"的语义一致
local function OnTakeMouse(player, id, uid, count)
    if player == nil or not player:IsValid() then
        return
    end
    local store = Store.Get(id)
    if store == nil then
        return
    end

    store:WhenReady(function(s)
        local n = nil
        if type(count) == "number" and count > 0 then
            n = count
        end

        local item = nil
        Log.Safe("rpc.take_mouse", function()
            item = s:SpawnRecordByUID(uid, nil, n, player)
        end)

        if item == nil then
            Log.W("rpc.take_mouse", "取不出物品 uid=" .. tostring(uid))
            PushSnapshot(player, id)
            return
        end

        local inv = player.components ~= nil and player.components.inventory or nil
        if inv ~= nil then
            if inv:GetActiveItem() == nil then
                -- 手上空的：放到鼠标（这才是"抓取"的正确语义）
                local ok, err = pcall(function()
                    inv:GiveActiveItem(item)
                end)
                if not ok then
                    Log.W("rpc.take_mouse", "GiveActiveItem 失败，改放背包:", tostring(err))
                    inv:GiveItem(item)
                end
            else
                -- 手上已有：塞背包，避免把鼠标上的东西顶掉
                local ok, given = pcall(function()
                    return inv:GiveItem(item)
                end)
                if not ok or not given then
                    local pp = player:GetPosition()
                    item.Transform:SetPosition(pp.x, 0, pp.z)
                    if item.components ~= nil and item.components.inventoryitem ~= nil then
                        item.components.inventoryitem:OnDropped(true, .5)
                    end
                end
            end
        end

        PushSnapshot(player, id)
    end)
end

-- 存入：优先存玩家手上（active item），没有就存背包最后一格
local function OnPut(player, id, count)
    Log.D("rpc", "收到 put: id=" .. tostring(id) .. " count=" .. tostring(count))
    if player == nil or not player:IsValid() then
        return
    end
    local store = Store.Get(id)
    if store == nil then
        return
    end

    store:WhenReady(function(s)
        local inv = player.components ~= nil and player.components.inventory or nil
        if inv == nil then
            return
        end

        local item = inv:GetActiveItem()
        if item == nil then
            local slots = inv.maxslots or 15
            for i = slots, 1, -1 do
                local it = inv:GetItemInSlot(i)
                if it ~= nil and not it:HasTag("irreplaceable") then
                    item = it
                    break
                end
            end
        end

        if item == nil then
            Log.W("rpc.put", "没有可存的物品")
            PushSnapshot(player, id)
            return
        end

        local prefab = item.prefab
        local stacked = (item.components ~= nil
            and item.components.stackable ~= nil)
            and item.components.stackable:StackSize() or 1
        local put_n = stacked
        if type(count) == "number" and count > 0 and count < stacked then
            put_n = math.floor(count)
        end

        Log.Safe("rpc.put", function()
            if put_n < stacked then
                -- 部分存：分裂一份再入库
                local ok, ret = pcall(function()
                    return item.components.stackable:SplitStack(put_n)
                end)
                if ok and ret ~= nil and ret:IsValid() then
                    -- ⚠️ 千万别在这里 ret:Remove()，AddItem 内部会 Remove，
                    -- 提前删就等于凭空销毁这部分物品
                    s:AddItem(ret)
                else
                    Log.W("rpc.put", "SplitStack 失败，改为整栈存入")
                    s:AddItem(item)
                end
            else
                s:AddItem(item)
            end
            Log.D("rpc.put", string.format("存入 %s x%d", tostring(prefab), put_n))
        end)

        PushSnapshot(player, id)
    end)
end

-- 交换两格（排序）
local function OnSwap(player, id, uid1, uid2)
    local store = Store.Get(id)
    if store == nil then
        return
    end
    store:WhenReady(function(s)
        Log.Safe("rpc.swap", function()
            local a = s:FindIndexByUID(uid1)
            local b = s:FindIndexByUID(uid2)
            if a ~= nil and b ~= nil and a ~= b then
                s:Swap(a, b)
            end
        end)
        PushSnapshot(player, id)
    end)
end

-- 丢到地上（不经过背包）
local function OnDrop(player, id, uid)
    local store = Store.Get(id)
    if store == nil or player == nil or not player:IsValid() then
        return
    end
    store:WhenReady(function(s)
        local p = player:GetPosition()
        local pos = Vector3(p.x, 0, p.z)
        Log.Safe("rpc.drop", function()
            s:SpawnRecordByUID(uid, pos, nil, player)
        end)
        PushSnapshot(player, id)
    end)
end

-- ====================================================================
-- 导出
-- ====================================================================
local API = {}

API.RPC_NAME = RPC_NAME

-- 供 modmain 注册：AddModRPCHandler(RPC_NAME, name, fn)
API.ServerHandlers = {
    pull = OnPull,
    take_mouse = OnTakeMouse,
    take = OnTake,
    put = OnPut,
    swap = OnSwap,
    drop = OnDrop,
}

-- 供 modmain 注册：AddClientModRPCHandler(RPC_NAME, name, fn)
API.ClientHandlers = {
    snapshot = OnSnapshot,
}

API.PushSnapshot = PushSnapshot

-- --------------------------------------------------------------------
-- 客户端主动请求
-- --------------------------------------------------------------------
function API.RequestSnapshot(id)
    local rpc = ServerRpc("pull")
    if rpc == nil then
        Log.E("rpc", "RPC 未注册（pull）")
        return
    end
    Log.D("rpc", "请求快照：" .. tostring(id))
    SendModRPCToServer(rpc, id or "hslot")
end

function API.Take(id, uid, count)
    local rpc = ServerRpc("take")
    if rpc == nil then return end
    SendModRPCToServer(rpc, id or "hslot", uid, count or -1)
end

-- 取到鼠标上（"抓取"语义）
function API.TakeActive(id, uid, count)
    local rpc = ServerRpc("take_mouse")
    if rpc == nil then
        Log.E("rpc", "RPC 未注册（take_mouse）")
        return
    end
    Log.D("rpc", string.format("发送 take_mouse: id=%s uid=%s count=%s",
        tostring(id), tostring(uid), tostring(count)))
    SendModRPCToServer(rpc, id or "hslot", uid, count or -1)
end

function API.Put(id, count)
    local rpc = ServerRpc("put")
    if rpc == nil then
        Log.E("rpc", "RPC 未注册（put），存入发不出去")
        return
    end
    Log.D("rpc", "发送 put: id=" .. tostring(id) .. " count=" .. tostring(count))
    SendModRPCToServer(rpc, id or "hslot", count or -1)
end

function API.Drop(id, uid)
    local rpc = ServerRpc("drop")
    if rpc == nil then return end
    SendModRPCToServer(rpc, id or "hslot", uid)
end

return API
