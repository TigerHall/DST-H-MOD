-- 环境设置：让 mod 环境能直接访问全局符号（Add* 系列不需要 GLOBAL. 前缀，
-- 但 SpawnPrefab / TheWorld / TheSim / TUNING / ACTIONS / CreateEntity 等需要 GLOBAL. 前缀，见踩坑库 #12）
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })

-- ═══════════════════════════════════════════════════════
-- 配置读取（统一在 modinfo 中定义：return_enable / return_grace_days）
-- ═══════════════════════════════════════════════════════
local config = {
    return_enable = GetModConfigData("return_enable"),
    return_grace_days = GetModConfigData("return_grace_days") or 10,
}

-- ═══════════════════════════════════════════════════════
-- 预制体注册
-- ═══════════════════════════════════════════════════════
PrefabFiles = {
    "hh_offlinevault",
    "hh_returnchest",
}

-- ═══════════════════════════════════════════════════════
-- 物品转移工具函数
-- ═══════════════════════════════════════════════════════

-- inventory 组件没有 GetAllItems()，手动遍历物品栏 + 装备栏收集快照
local function CollectInventoryItems(inv)
    local items = {}
    if inv == nil then return items end
    if inv.itemslots then
        for _, item in pairs(inv.itemslots) do
            if item and item:IsValid() then
                table.insert(items, item)
            end
        end
    end
    if inv.equipslots then
        for _, item in pairs(inv.equipslots) do
            if item and item:IsValid() then
                table.insert(items, item)
            end
        end
    end
    return items
end

-- 把玩家身上的全部物品（装备 + 物品栏，背包作为一个整体随装备移动）转移到托管实体
local function TransferPlayerToVault(player, vault)
    local pinv = player.components.inventory
    local vinv = vault.components.inventory
    if not pinv or not vinv then return end

    -- 收集快照数组，遍历时 RemoveItem 不会破坏数组
    local all = CollectInventoryItems(pinv)
    for _, item in ipairs(all) do
        if item and item:IsValid() then
            local removed = pinv:RemoveItem(item, true) -- wholestack=true，整组移除
            if removed then
                vinv:GiveItem(removed)
            end
        end
    end
end

-- 把托管实体里的物品归还给重新上线的玩家（尝试恢复装备位，其余放回物品栏/脚下）
local function ReturnVaultToPlayer(vault, player)
    local vinv = vault.components.inventory
    local pinv = player.components.inventory
    if not vinv or not pinv then return end

    local all = CollectInventoryItems(vinv)
    for _, item in ipairs(all) do
        if item and item:IsValid() then
            local removed = vinv:RemoveItem(item, true)
            if removed then
                if removed.components.equippable then
                    local slot = removed.components.equippable.equipslot
                    if pinv:GetEquippedItem(slot) == nil then
                        pinv:Equip(removed)
                    else
                        pinv:GiveItem(removed, nil, player:GetPosition())
                    end
                else
                    pinv:GiveItem(removed, nil, player:GetPosition())
                end
            end
        end
    end
end

-- 把托管实体里的物品倒入归还箱；装不下时，在周围继续生成额外归还箱兜底
local function SpawnReturnChests(vault)
    local x, y, z = vault.Transform:GetWorldPosition()
    local vinv = vault.components.inventory

    local function NewChest(px, pz)
        local chest = SpawnPrefab("hh_returnchest")
        if chest then
            chest.Transform:SetPosition(px, 0, pz)
        end
        return chest
    end

    -- 第一个箱子
    local chest = NewChest(x, z)
    if not chest then return end

    local overflow = {}
    local all = CollectInventoryItems(vinv)
    for _, item in ipairs(all) do
        if item and item:IsValid() then
            local removed = vinv:RemoveItem(item, true)
            if removed then
                -- drop_on_fail=false：装不下时不掉地上，便于下个箱子继续装（避免重复掉落/丢失）
                if not chest.components.container:GiveItem(removed, nil, nil, false) then
                    table.insert(overflow, removed)
                end
            end
        end
    end

    -- 溢出部分：绕圈生成更多箱子，直到装完
    local angle = 0
    while #overflow > 0 and chest ~= nil do
        angle = angle + 0.8
        local ox = x + math.cos(angle) * 2.6
        local oz = z - math.sin(angle) * 2.6
        local c = NewChest(ox, oz)
        if not c then break end
        chest = c
        local still_over = {}
        for _, item in ipairs(overflow) do
            if not c.components.container:GiveItem(item, nil, nil, false) then
                table.insert(still_over, item)
            end
        end
        overflow = still_over
    end

    -- 极端情况下仍有剩余（理论上 16 格×堆叠足够），直接丢在脚下避免丢失
    for _, item in ipairs(overflow) do
        item.Transform:SetPosition(x, 0, z)
    end
end

-- 列出世界中所有的托管实体
local function GetAllVaults()
    if not TheWorld or not TheWorld.ismastersim then return {} end
    return TheSim:FindEntities(0, 0, 0, 99999, { "hh_offlinevault" })
end

-- 检查所有托管实体是否超过宽限期，超过则生成归还箱并移除
local function CheckExpiredVaults(cycles)
    if not config.return_enable then return end
    local grace = config.return_grace_days
    for _, vault in ipairs(GetAllVaults()) do
        if vault:IsValid() and vault.components.inventory then
            local leave = vault.leave_cycle or 0
            if cycles - leave >= grace then
                SpawnReturnChests(vault)
                vault:Remove()
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════
-- 世界事件：接管 / 归还 / 每日检查
-- ═══════════════════════════════════════════════════════
AddPrefabPostInit("world", function(inst)
    if not TheWorld.ismastersim then return end

    -- 1) 玩家下线：接管其物品到托管实体
    inst:ListenForEvent("playerdeactivated", function(world, player)
        if not config.return_enable then return end
        if not player or not player:IsValid() or not player:HasTag("player") then return end
        if not player.components.inventory then return end

        -- 仅当玩家真有物品时才创建托管实体（避免空壳垃圾）
        local items = CollectInventoryItems(player.components.inventory)
        if #items == 0 then return end

        local x, y, z = player.Transform:GetWorldPosition()
        local vault = SpawnPrefab("hh_offlinevault")
        if not vault then return end
        vault.Transform:SetPosition(x, y, z)
        vault.userid = player.userid
        vault.leave_cycle = TheWorld.state.cycles

        TransferPlayerToVault(player, vault)
    end)

    -- 2) 玩家重新上线（宽限期内）：原样归还并删除托管实体
    inst:ListenForEvent("playeractivated", function(world, player)
        if not config.return_enable then return end
        if not player or not player:IsValid() or not player.userid then return end

        for _, vault in ipairs(GetAllVaults()) do
            if vault:IsValid() and vault.userid == player.userid then
                ReturnVaultToPlayer(vault, player)
                vault:Remove()
                break
            end
        end
    end)

    -- 3) 每天开始时检查
    inst:WatchWorldState("cycles", function(world, cycles)
        CheckExpiredVaults(cycles)
    end)

    -- 4) 世界加载后补查一次：处理服务器离线期间已到期的托管实体
    inst:DoTaskInTime(2, function()
        if TheWorld and TheWorld.state then
            CheckExpiredVaults(TheWorld.state.cycles)
        end
    end)
end)

-- ═══════════════════════════════════════════════════════
-- 调试命令（控制台用）：c_listvaults()
-- 列出当前所有托管实体及其归属玩家/剩余天数
-- ═══════════════════════════════════════════════════════
if not GLOBAL.TheNet:IsDedicated() then
    GLOBAL.c_listvaults = function()
        local v = GetAllVaults()
        print("[hreturn] 当前托管实体数:", #v)
        for i, vault in ipairs(v) do
            local leave = vault.leave_cycle or 0
            local now = TheWorld.state.cycles
            print(string.format("  #%d userid=%s 离开第%d天 还需%d天到期",
                i, tostring(vault.userid), leave, math.max(0, config.return_grace_days - (now - leave))))
        end
    end
end
