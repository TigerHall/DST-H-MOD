-- scripts/hspace/datastore.lua
-- ═══════════════════════════════════════════════════════════════════════
-- 蓝眼空间数据层：物品以「纯数据记录」形式存在，完全脱离世界实体
--
-- 设计来源：
--   · components/unwrappable.lua:47-70 / 80-138 / 182-199
--       GetSaveRecord 序列化 → 数组存起来 → SpawnPrefab + SetPersistData 还原
--   · 简易存储 3383078008 / scripts/ss_util/persistentdata.lua
--       SavePersistentString 写独立文件（不撑大 shard save、不跟 autosave 绑死）
--
-- 一条记录同时存两份数据：
--   .data = item:GetPersistData()   —— 还原用，组件存档（大、不能省）
--   .view = 展示快照                —— UI 用，名称/贴图/tag/堆叠/耐久（小、静态）
-- 分成两份是因为物品进了仓库就不再 tick，展示信息是死的，没必要每次重新算。
--
-- ⚠️ 本模块只在服务端有实际作用；客户端 require 后所有写操作都是空转。
-- ═══════════════════════════════════════════════════════════════════════

-- 需要用 simutil 里的 GetInventoryItemAtlas 兜底贴图
require("simutil")

local Log = require("hspace/log")

local SAVE_KEY_PREFIX = "hslot_space_"
local SAVE_VERSION = 1
local FLUSH_DELAY = 5 -- 脏了之后多久写盘（秒）。关面板 / 关服会提前 flush

-- ====================================================================
-- 大整数保护：json 不能编码 math.huge / NaN
-- ====================================================================
local function SafeNum(n, default)
    if type(n) ~= "number" then
        return default
    end
    if n ~= n or n == math.huge or n == -math.huge then
        return default
    end
    return n
end

-- ====================================================================
-- 展示快照：物品 → 一份够 UI 用的静态描述
--
-- ⚠️ 结构刻意对齐「简易存储 fakeitem.lua:7-85」的 FakeItem，
--    这样客户端的 ModifyFakeItem / 魔改 ItemTile 可以原样复用，
--    不用为我们的数据形状再写一套渲染。
--
-- 但数据源换成了服务端可靠字段：
--   简存用 replica.inventoryitem.classified（客户端专属），服务端恒为 nil，
--   会退化成 prefab..".tex" 这种错贴图。这里改用 components.inventoryitem 的
--   imagename / atlasname。
-- ====================================================================
local function MakeViewData(item)
    local invitem = item.components ~= nil and item.components.inventoryitem or nil
    local stackable = item.components ~= nil and item.components.stackable or nil

    local image = invitem ~= nil and invitem.imagename or nil
    local atlas = invitem ~= nil and invitem.atlasname or nil
    if image == nil or image == "" then
        image = item.prefab .. ".tex"
    end
    if atlas == nil then
        atlas = GetInventoryItemAtlas ~= nil and GetInventoryItemAtlas(image) or nil
    end

    local view = {
        prefab = item.prefab,
        skinname = item.skinname,
        skin_id = SafeNum(item.skin_id, nil),
        name = item.GetBasicDisplayName ~= nil and item:GetBasicDisplayName() or item.prefab,
        adjective = item.GetAdjective ~= nil and item:GetAdjective() or nil,
        -- ⚠️ 保持 nil 或原表，不要用 "" 兜底：
        -- 客户端判断的是 `inv_image_bg ~= nil`，空字符串也满足，
        -- 于是会拿 "".atlas（nil）去 Image:SetTexture，触发
        -- image.lua:85 的 assert(tex ~= nil) 崩溃。
        inv_image_bg = type(item.inv_image_bg) == "table" and item.inv_image_bg or nil,
        AnimState = {
            -- 皮肤染色靠 skinbuild，没有就留 nil
            skinbuild = item.AnimState ~= nil
                and item.AnimState:GetSkinBuild() or nil,
        },
        replica = {
            stackable = stackable ~= nil and {
                stacksize = stackable:StackSize(),
                -- maxsize 可能是 math.huge（无限堆叠），JSON 编码不了，转成 "inf"
                maxsize = stackable.maxsize == math.huge
                    and "inf" or SafeNum(stackable.maxsize, 1),
                originalmaxsize = SafeNum(stackable.originalmaxsize, nil),
            } or nil,
            inventoryitem = {
                atlas = atlas,
                image = image,
            },
        },
        components = {},
        tags = {},
        hasspoilage = false,
        warable = false,
        equipslot = nil,
    }

    -- tag 集合：服务端没有直接枚举 tag 的 API，靠 modmain 里给 EntityScript
    -- 打的 tags_backup（学简易存储 hook.lua:177-191）。拿不到就退化成空表，
    -- 代价只是筛选分类失效，不影响存取。
    if type(item.tags_backup) == "table" then
        for tag in pairs(item.tags_backup) do
            view.tags[tag] = 1
        end
    end
    if item:HasTag("irreplaceable") then
        view.tags.irreplaceable = 1
    end

    -- 装备槽位：客户端没有 components，GEAR 筛选靠这个字段而不是 replica.equippable
    local equippable = item.components ~= nil and item.components.equippable or nil
    if equippable ~= nil and equippable.equipslot ~= nil then
        view.equipslot = equippable.equipslot
        view.warable = (equippable.equipslot == EQUIPSLOTS.BODY
            or equippable.equipslot == EQUIPSLOTS.HEAD)
    end
    if item:HasTag("weapon") then
        view.warable = view.warable or true
    end

    -- 耐久 / 腐烂：只取一个百分比，UI 画条用。
    -- 优先级和官方 ItemTile:Refresh() 的 elseif 链一致：armor > perishable > finiteuses > fueled
    local armor = item.components ~= nil and item.components.armor or nil
    local perish = item.components ~= nil and item.components.perishable or nil
    local uses = item.components ~= nil and item.components.finiteuses or nil
    local fueled = item.components ~= nil and item.components.fueled or nil
    local recharge = item.components ~= nil and item.components.rechargeable or nil

    if armor ~= nil then
        view.components.armor = { percent = SafeNum(armor:GetPercent(), 1) }
    elseif perish ~= nil then
        view.components.perishable = { percent = SafeNum(perish:GetPercent(), 1) }
    elseif uses ~= nil then
        view.components.finiteuses = { percent = SafeNum(uses:GetPercent(), 1) }
    elseif fueled ~= nil then
        view.components.fueled = { percent = SafeNum(fueled:GetPercent(), 1) }
    end
    if recharge ~= nil then
        -- ⚠️ 判空必须用 `.` 不能用 `:`：
        --    `obj:Method ~= nil` 里冒号会强制要求参数列表，
        --    Lua 解析器直接抛 "function arguments expected near '~='"
        local rechargetime = nil
        if recharge.GetRechargeTime ~= nil then
            rechargetime = SafeNum(recharge:GetRechargeTime(), nil)
        end
        view.components.rechargeable = {
            percent = SafeNum(recharge:GetPercent(), 1),
            time = rechargetime,
        }
    end

    -- 腐烂程度条：有新鲜度且属于食物类才画
    if perish ~= nil then
        if item:HasTag("show_spoilage") then
            view.hasspoilage = true
        else
            for _, foodtype in pairs(FOODTYPE) do
                if item:HasTag("edible_" .. foodtype) then
                    view.hasspoilage = true
                    break
                end
            end
        end
    end

    return view
end

-- ====================================================================
-- 记录池
-- ====================================================================
local VaultStore = Class(function(self, id)
    self.id = id
    self.records = {}   -- [1..n] = { uid, prefab, data, view, skinname, skin_id }
    self.meta = {}      -- { version, migrated, created, next_uid }
    self.dirty = false
    self.ready = false  -- Load 完成前不允许写，否则会覆盖磁盘上的旧数据
    self._loading = false
    self.loaded_once = false
    self._flush_task = nil
    self._pending_load = {}
    -- uid：单调递增、永不复用。RPC 靠它定位记录，
    -- 不能用数组下标——中间删一条后面全体错位，点错格子的就是这个原因。
    self.next_uid = 1
end)

function VaultStore:Key()
    return SAVE_KEY_PREFIX .. tostring(self.id)
end

-- --------------------------------------------------------------------
-- 持久化
-- --------------------------------------------------------------------
function VaultStore:Load(cb)
    if self.ready then
        if cb ~= nil then cb(true) end
        return
    end
    -- 并发保护：多处同时要数据时只发起一次读盘。
    -- 后来的调用者不需要单独回调——读盘完成后 ready=true，
    -- 走 WhenReady 的人会在下面的 _pending_load 里统一收到通知。
    if self._loading then
        return
    end
    self._loading = true

    local _self = self
    Log.D("store", "开始载入 " .. self:Key())
    TheSim:GetPersistentString(self:Key(), function(ok, str)
        if ok and str ~= nil and #str > 0 then
            local decoded = nil
            -- json 解码失败不能让整个存档卡住，退化成空库
            local success, result = pcall(function()
                return json.decode(str)
            end)
            if success and type(result) == "table" then
                decoded = result
            else
                Log.E("store", "存档解码失败，按空库处理:", _self:Key(), tostring(result))
            end
            if decoded ~= nil then
                _self.records = type(decoded.records) == "table" and decoded.records or {}
                _self.meta = type(decoded.meta) == "table" and decoded.meta or {}
                -- 记录格式升级钩子（以后加字段在这里补默认值）
                _self.meta.version = _self.meta.version or SAVE_VERSION
            end
        else
            Log.D("store", "没有历史存档（首次使用）", self:Key())
        end

        -- uid 恢复：优先用 meta 里存的，没有就从现有记录里推最大值+1
        local max_uid = 0
        for i = 1, #_self.records do
            local u = _self.records[i].uid
            -- 老格式没有 uid：补一个，保证后续 RPC 能定位
            if u == nil then
                max_uid = max_uid + 1
                _self.records[i].uid = max_uid
                _self.dirty = true
            elseif u > max_uid then
                max_uid = u
            end
        end
        _self.next_uid = math.max(_self.meta.next_uid or 1, max_uid + 1)

        _self.ready = true
        _self._loading = false
        _self.loaded_once = true
        if not _self.dirty then
            _self.dirty = false
        end
        Log.D("store", string.format("%s 载入完成：%d 条记录，next_uid=%d",
            _self:Key(), #_self.records, _self.next_uid))

        if cb ~= nil then cb(true) end
        for _, fn in ipairs(_self._pending_load) do
            Log.Safe("store.whenready", fn, _self)
        end
        _self._pending_load = {}
    end, false)
end

-- 延迟到 Load 之后再执行（导入旧容器这类操作必须等库加载完）
function VaultStore:WhenReady(fn)
    if self.ready then
        fn(self)
    else
        table.insert(self._pending_load, fn)
    end
end

function VaultStore:MarkDirty()
    self.dirty = true
    if self._flush_task ~= nil then
        self._flush_task:Cancel()
        self._flush_task = nil
    end
    if TheWorld == nil or not TheWorld:IsValid() then
        return
    end
    local _self = self
    self._flush_task = TheWorld:DoTaskInTime(FLUSH_DELAY, function()
        _self._flush_task = nil
        _self:Flush()
    end)
end

function VaultStore:Flush(cb)
    if not self.ready then
        if cb ~= nil then cb(false) end
        return
    end
    if not self.dirty then
        if cb ~= nil then cb(true) end
        return
    end
    if self._flush_task ~= nil then
        self._flush_task:Cancel()
        self._flush_task = nil
    end

    local payload = {
        meta = self.meta,
        records = self.records,
    }

    local ok, str = pcall(function()
        return json.encode(payload)
    end)
    if not ok or str == nil then
        Log.E("store.flush", "json.encode 失败，跳过本次写盘:", tostring(str))
        if cb ~= nil then cb(false) end
        return
    end

    self.dirty = false
    local _self = self
    SavePersistentString(self:Key(), str, ENCODE_SAVES, function(success)
        -- ⚠️ 单机 / 客户端下 TheFrontEnd 存在，官方 SavePersistentString
        -- （mainfunctions.lua:18-31）会把回调再包一层，而且调用时**不传 success**。
        -- 所以这里只能判 `== false`，写成 `not success` 会把每次成功都报成失败。
        if success == false then
            _self.dirty = true
            Log.E("store.flush", "写盘失败:", _self:Key())
        else
            Log.D("store.flush", string.format("写盘完成 %s (%d 字节)", _self:Key(), #str))
        end
        if cb ~= nil then cb(success ~= false) end
    end)
end

-- --------------------------------------------------------------------
-- 查询
-- --------------------------------------------------------------------
function VaultStore:Count()
    return #self.records
end

function VaultStore:Get(index)
    return self.records[index]
end

function VaultStore:TotalStack()
    local n = 0
    for i = 1, #self.records do
        local rec = self.records[i]
        local s = (rec.view ~= nil and rec.view.replica ~= nil)
            and rec.view.replica.stackable or nil
        n = n + (s ~= nil and s.stacksize or 1)
    end
    return n
end

-- --------------------------------------------------------------------
-- 入库：实体物品 → 记录
-- --------------------------------------------------------------------
-- 返回新记录的 index；失败返回 nil, 原因
function VaultStore:AddItem(item)
    if item == nil or not item:IsValid() then
        return nil, "invalid"
    end
    if item:HasTag("irreplaceable") then
        Log.W("store.add", "拒绝入库（irreplaceable）:", item.prefab)
        return nil, "irreplaceable"
    end
    if item.components ~= nil and item.components.inventoryitem ~= nil
        and item.components.inventoryitem.canbepickedup == false then
        -- ⚠️ 必须写 == false：这个字段不是所有物品都有，
        -- 写成 not xxx 会把「字段为 nil 的正常物品」全部拒之门外
        Log.W("store.add", "拒绝入库（不可拾取）:", item.prefab)
        return nil, "nopickup"
    end

    -- ⚠️ 顺序不能反：view 必须在 Remove 之前拍，Remove 之后组件就没了
    local data = nil
    local ok, got = pcall(function()
        return item:GetPersistData()
    end)
    if ok then
        data = got
    else
        Log.E("store.add", "GetPersistData 失败:", item.prefab, tostring(got))
    end

    local rec = {
        uid = self.next_uid,
        prefab = item.prefab,
        skinname = item.skinname,
        skin_id = SafeNum(item.skin_id, nil),
        data = data,
        view = MakeViewData(item),
    }
    self.next_uid = self.next_uid + 1
    self.meta.next_uid = self.next_uid

    table.insert(self.records, rec)
    self:MarkDirty()

    Log.D("store.add", string.format("入库 %s uid=%d index=%d 共%d条",
        tostring(rec.prefab), rec.uid, #self.records, #self.records))

    item:Remove()
    return #self.records
end

-- 批量入库（用于旧容器迁移）。会跳过 irreplaceable 并在容器里留下它。
-- ⚠️ 必须先收集成数组再逐个 Remove：边遍历 slot 边 RemoveItem 会让
--    container 内部的 netvar / slots 表在迭代中途变动，是典型的悬空索引来源。
function VaultStore:AddContainer(container_inst)
    if container_inst == nil or container_inst.components == nil
        or container_inst.components.container == nil then
        return 0, 0
    end
    local container = container_inst.components.container
    local total = container.numslots or container:GetNumSlots() or 0

    local items = {}
    for slot = 1, total do
        local item = container:GetItemInSlot(slot)
        if item ~= nil and item:IsValid() then
            items[#items + 1] = item
        end
    end

    local moved, kept = 0, 0
    for i = 1, #items do
        local item = items[i]
        if item:IsValid() then
            local index, err = self:AddItem(item)
            if index ~= nil then
                moved = moved + 1
            else
                kept = kept + 1
                Log.W("store.migrate", "跳过物品:", item.prefab or "?", err or "")
            end
        end
    end

    return moved, kept
end

-- --------------------------------------------------------------------
-- 出库：记录 → 实体物品
-- --------------------------------------------------------------------
-- 一条记录的堆叠数：统一从 view.replica.stackable 取（FakeItem 结构）
local function RecStack(rec)
    if rec == nil or rec.view == nil then
        return 1
    end
    local s = rec.view.replica ~= nil and rec.view.replica.stackable or nil
    return s ~= nil and s.stacksize or 1
end

local function SetRecStack(rec, n)
    if rec == nil or rec.view == nil then
        return
    end
    rec.view.replica = rec.view.replica or {}
    rec.view.replica.stackable = rec.view.replica.stackable or {
        stacksize = 1,
        maxsize = 1,
    }
    rec.view.replica.stackable.stacksize = n
    -- 存档数据里的堆叠数同步，否则下次取出还是旧值
    if rec.data ~= nil and rec.data.stackable ~= nil then
        rec.data.stackable.stack = n
    end
end

-- pos      : Vector3，不传就丢在 doer 脚下
-- count    : 只取这么多（部分取出）。不传 = 整条取走
-- 返回生成的实体（可能为 nil）, 失败原因
function VaultStore:SpawnRecord(index, pos, count, doer)
    return self:_SpawnAt(index, pos, count, doer)
end

-- 按 uid 取（RPC 用这个，别用 index）
function VaultStore:SpawnRecordByUID(uid, pos, count, doer)
    local index = self:FindIndexByUID(uid)
    if index == nil then
        Log.W("store.take", "uid 找不到:", tostring(uid))
        return nil, "nouid"
    end
    return self:_SpawnAt(index, pos, count, doer)
end

function VaultStore:_SpawnAt(index, pos, count, doer)
    local rec = self.records[index]
    if rec == nil then
        Log.W("store.take", "index 越界:", tostring(index))
        return nil, "index"
    end

    local total = RecStack(rec)
    local want = total
    if count ~= nil and count < want then
        want = math.max(1, math.floor(count))
    end

    local item = SpawnPrefab(rec.prefab, rec.skinname, rec.skin_id)
    if item == nil or not item:IsValid() then
        Log.E("store.take", "SpawnPrefab 失败:", tostring(rec.prefab))
        return nil, "spawn"
    end

    -- 部分取出时要把存档数据里的堆叠数改成这次拿走的量，
    -- 剩下那条记录原地减堆叠，不能整条删掉。
    local ok, copied = pcall(function()
        return deepcopy(rec.data)
    end)
    local data = (ok and type(copied) == "table") and copied or nil
    if not ok then
        Log.E("store.take", "deepcopy 失败，物品将以默认状态生成:", tostring(copied))
    end

    if data ~= nil then
        if want < total then
            data.stackable = data.stackable or {}
            data.stackable.stack = want
        end
        local ok2, err2 = pcall(function()
            item:SetPersistData(data)
        end)
        if not ok2 then
            Log.E("store.take", "SetPersistData 失败:", tostring(rec.prefab), tostring(err2))
        end
    end

    if pos ~= nil and pos.x ~= nil then
        if item.Physics ~= nil then
            item.Physics:Teleport(pos.x, pos.y or 0, pos.z)
        elseif item.Transform ~= nil then
            item.Transform:SetPosition(pos.x, pos.y or 0, pos.z)
        end
    elseif doer ~= nil and doer:IsValid() then
        local dp = doer:GetPosition()
        item.Transform:SetPosition(dp.x, 0, dp.z)
    end

    if item.components ~= nil and item.components.inventoryitem ~= nil then
        item.components.inventoryitem:OnDropped(true, .5)
    end

    -- 扣减 / 移除记录
    if want >= total then
        self:RemoveAt(index)
    else
        SetRecStack(rec, total - want)
        self:MarkDirty()
    end

    Log.D("store.take", string.format("取出 %s x%d（原 %d）uid=%s",
        tostring(rec.prefab), want, total, tostring(rec.uid)))
    return item
end

function VaultStore:RemoveAt(index)
    if self.records[index] == nil then
        return false
    end
    local rec = self.records[index]
    table.remove(self.records, index)
    self:MarkDirty()
    Log.D("store.remove", "移除 index=" .. tostring(index) .. " uid=" .. tostring(rec.uid))
    return true
end

-- 线性查找。1 万条也就 1 万次整数比较，RPC 频率低，够用。
function VaultStore:FindIndexByUID(uid)
    if uid == nil then
        return nil
    end
    for i = 1, #self.records do
        if self.records[i].uid == uid then
            return i
        end
    end
    return nil
end

-- 交换两条记录（拖拽排序）
function VaultStore:Swap(a, b)
    if self.records[a] == nil or self.records[b] == nil then
        return false
    end
    self.records[a], self.records[b] = self.records[b], self.records[a]
    self:MarkDirty()
    return true
end

-- --------------------------------------------------------------------
-- 客户端快照：去掉还原用的 .data，只留展示结构
-- 体积差 5~10 倍，UI 一个字节的 data 都用不上
-- 结构直接就是 FakeItem（UID 挂在 uid 字段上，客户端会转成 GUID）
-- --------------------------------------------------------------------
local function ShallowCopy(t)
    if t == nil then
        return nil
    end
    local r = {}
    for k, v in pairs(t) do
        r[k] = v
    end
    return r
end

function VaultStore:PackForClient()
    local out = {}
    for i = 1, #self.records do
        local rec = self.records[i]
        local item = ShallowCopy(rec.view) or {}
        item.uid = rec.uid
        item.index = i
        -- skin_id 不进 view（view 里没有），单独带上，客户端还原皮肤要用
        if rec.skin_id ~= nil then
            item.skin_id = rec.skin_id
        end
        out[i] = item
    end
    return out
end

-- ====================================================================
-- 模块级 API（存档 id → store）
-- ====================================================================
local STORES = {}

local Store = {}

-- id 建议用 "hslot"（蓝眼）/ "purple_fish" 等，和 modmain 的 VAULT_THEMES key 对齐
function Store.Get(id)
    if TheWorld == nil or not TheWorld.ismastersim then
        return nil
    end
    local s = STORES[id]
    -- 回滚 / 换存档时 modmain 不会重跑，但 TheWorld 是新的实例。
    -- 缓存里还挂着上个世界的库，必须丢掉重建，否则读到回滚前的状态。
    if s ~= nil and s._world ~= TheWorld then
        if s._flush_task ~= nil then
            s._flush_task:Cancel()
        end
        s = nil
    end
    if s == nil then
        s = VaultStore(id)
        s._world = TheWorld
        STORES[id] = s
    end
    -- 兜底：世界启动时没被 HSPACE_IDS 载入过的库，这里补一次读盘。
    -- ⚠️ 不补的话 ready 永远是 false，WhenReady 的队列永远不执行，
    -- 面板打开就是一片空白（而且没有任何报错）。
    if not s.ready and not s.loaded_once and not s._loading then
        s:Load()
    end
    return s
end

-- 世界重载 / 回滚时清空，避免拿到上个世界的缓存
function Store.Reset()
    for id, s in pairs(STORES) do
        if s._flush_task ~= nil then
            s._flush_task:Cancel()
        end
        STORES[id] = nil
    end
end

-- 关服前把所有脏库刷盘
function Store.FlushAll()
    for _, s in pairs(STORES) do
        s:Flush()
    end
end

Store.VaultStore = VaultStore

return Store
