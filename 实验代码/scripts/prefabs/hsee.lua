--[[
HSee 查看器物品 —— NPC 版
- equippable（可装备）
- spellcaster（右键 NPC → 查看其物品栏 + 装备）
- 使用时创建 hsee_pool 容器实体，将目标的物品搬入，交互完毕后搬回

PS: 这个 prefab 同时也提供了 hsee_pool 容器实体的定义
]]

----------------------------------------------------------------------
-- 素材：暂时复用勋章 MOD 的 medal_skin_staff 素材（已复制到本地）
----------------------------------------------------------------------
local assets = {
    Asset("ANIM", "anim/medal_skin_staff.zip"),
    Asset("ATLAS", "images/inventoryimages/medal_skin_staff.xml"),
    Asset("ATLAS_BUILD", "images/inventoryimages/medal_skin_staff.xml", 256),
}

----------------------------------------------------------------------
-- HSee 装备回调
----------------------------------------------------------------------
local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_object", "medal_skin_staff", "swap_medal_skin_staff")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function onunequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end

----------------------------------------------------------------------
-- hsee_pool 池容器实体
-- 一个不可见的临时容器，承载 NPC 搬入的物品
----------------------------------------------------------------------
local function make_pool_fn()
    local function pool_fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddNetwork()

        -- 不可见，不可交互，不保存
        inst:AddTag("INLIMBO")
        inst:AddTag("NOBLOCK")
        inst:AddTag("CLASSIFIED")
        inst.persists = false

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        -- ========== 容器组件（参数由调用方动态设置） ==========
        inst:AddComponent("container")
        inst.components.container.skipclosesnd = true
        inst.components.container.skipopensnd = true

        -- 关闭容器后自动归还物品
        inst.components.container.onclosefn = function(pool_inst)
            if pool_inst.return_task == nil then
                pool_inst.return_task = pool_inst:DoTaskInTime(0, function()
                    pool_inst:PushEvent("returnitems")
                end)
            end
        end

        return inst
    end
    return Prefab("hsee_pool", pool_fn)
end

----------------------------------------------------------------------
-- 将目标 NPC 的物品搬入 pool 容器
----------------------------------------------------------------------
local function fill_pool_with_target_items(pool, target)
    local container = pool.components.container
    if not container then return end

    local equip_map = {}  -- slot_index -> equip_slot_name
    local item_index = 1

    -- ========== 1. 搬入装备 ==========
    for slot_name, slot_key in pairs(EQUIPSLOTS) do
        local equipped = target.components.inventory:GetEquippedItem(slot_key)
        if equipped then
            target.components.inventory:Unequip(slot_key, true)
            container:GiveItem(equipped)
        end
        equip_map[item_index] = slot_key  -- 空槽也记录，归还时才知道放回哪
        item_index = item_index + 1
    end

    -- ========== 2. 搬入物品栏 ==========
    local max_slots = target.components.inventory:GetMaxItemSlots()
    for i = 1, max_slots do
        local item = target.components.inventory:GetItemInSlot(i)
        if item then
            target.components.inventory:DropItemFromSlot(i, true)
            if item.components.inventoryitem then
                item.components.inventoryitem:RemoveFromOwner(true)
            end
            container:GiveItem(item)
            item_index = item_index + 1
        end
    end

    pool.equip_map = equip_map
end

----------------------------------------------------------------------
-- 将 pool 容器的物品归还给目标 NPC
----------------------------------------------------------------------
local function return_items_to_target(pool, target)
    local container = pool.components.container
    if not container or not target or not target:IsValid() or not target.components.inventory then
        -- 目标已死/消失 → 把物品掉落地上
        if container then
            for i = 1, container:GetNumSlots() do
                local item = container:DropItemBySlot(i)
                if item and item.components.inventoryitem then
                    item.components.inventoryitem:RemoveFromOwner(true)
                end
            end
        end
        pool:Remove()
        return
    end

    local equip_map = pool.equip_map or {}

    for i = 1, container:GetNumSlots() do
        local item = container:RemoveItemBySlot(i)
        if item then
            local equip_slot = equip_map[i]
            if equip_slot and target.components.inventory:GetEquippedItem(equip_slot) == nil then
                target.components.inventory:Equip(item, equip_slot, true)
            else
                target.components.inventory:GiveItem(item, nil, nil, true)
            end
        end
    end

    pool.equip_map = nil
    if pool.return_task then
        pool.return_task:Cancel()
        pool.return_task = nil
    end
    pool:Remove()
end

----------------------------------------------------------------------
-- 施法函数：打开 NPC 查看器容器
----------------------------------------------------------------------
local function spellfn(inst, target, pos, doer)
    -- 获取施法玩家
    local player = doer or (inst.components.inventoryitem and inst.components.inventoryitem.owner)
    if not player or not player:IsValid() or not player.components.inventory then
        return
    end

    -- 必须是实体目标，且目标得有 inventory 组件
    if not target or not target:IsValid() or not target.components.inventory then
        return
    end
    -- 不让自己当目标
    if target == player then
        return
    end

    -- 已经有打开的容器了？先关闭旧的
    if inst._active_pool and inst._active_pool:IsValid() then
        inst._active_pool.components.container:Close()
        return
    end

    -- ⚠️ 坑：NPC 可能在打开容器期间死亡/消失 ⇒ onclosefn 会触发归还，
    --     归还时如果目标无效则掉落物品。

    -- 生成 pool 实体
    local pool = SpawnPrefab("hsee_pool")
    if not pool then return end

    pool.Transform:SetPosition(target.Transform:GetWorldPosition())

    -- 计算 slot 布局：装备行  + 物品栏
    local equip_slot_list = {}
    for equip_name, equip_key in pairs(EQUIPSLOTS) do
        table.insert(equip_slot_list, equip_key)
    end
    local num_equip = #equip_slot_list
    local num_inv = target.components.inventory:GetMaxItemSlots()
    -- NPC 物品栏可能很小（如猪人只有 4 格），不小于 4 格以便显示
    if num_inv < 4 then
        num_inv = 4
    end
    local total_slots = num_equip + num_inv

    -- 动态计算 slot 位置
    local slotpos = {}
    local slotbg = {}

    -- 第 1 行：装备槽（居中）
    local row_y = 112.5
    local start_x = -75 * (num_equip - 1) / 2
    for i = 1, num_equip do
        table.insert(slotpos, Vector3(start_x + 75 * (i - 1), row_y, 0))
        slotbg[i] = { image = "fish_box_slot.tex" }
    end

    -- 第 2~4 行：物品栏（5 列）
    local inv_start_x = -150
    local rows = math.ceil(num_inv / 5)
    if rows > 3 then rows = 3 end  -- 最多 3 行物品栏
    for r = 1, rows do
        local y = 112.5 - 75 * r
        for c = 1, math.min(5, num_inv - (r - 1) * 5) do
            local x = inv_start_x + 75 * (c - 1)
            table.insert(slotpos, Vector3(x, y, 0))
        end
    end

    -- 自定义容器参数
    local custom_params = {
        widget = {
            slotpos = slotpos,
            slotbg = slotbg,
            animbank = "ui_fish_box_5x4",
            animbuild = "ui_fish_box_5x4",
            pos = Vector3(0, 220, 0),
            side_align_tip = 160,
        },
        type = "chest",
        itemtestfn = function(container, item, slot)
            return true
        end,
    }

    pool.components.container:WidgetSetup(nil, custom_params)

    -- 搬入目标物品
    fill_pool_with_target_items(pool, target)

    -- 注册归还事件
    pool:ListenForEvent("returnitems", function()
        return_items_to_target(pool, target)
    end)

    -- 记录活跃 pool
    inst._active_pool = pool

    -- HSee 被移除时紧急归还
    inst:ListenForEvent("onremove", function()
        if pool and pool:IsValid() then
            return_items_to_target(pool, target)
        end
        inst._active_pool = nil
    end, inst)

    -- 目标死亡时紧急归还
    target:ListenForEvent("death", function()
        if pool and pool:IsValid() then
            if pool.components.container then
                pool.components.container:Close()
            end
        end
    end, target)

    -- 打开容器（给玩家看）
    pool.components.container:Open(player)
end

----------------------------------------------------------------------
-- HSee 物品预制体
----------------------------------------------------------------------
local function hsee_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("medal_skin_staff")
    inst.AnimState:SetBuild("medal_skin_staff")
    inst.AnimState:PlayAnimation("medal_skin_staff")

    inst:AddTag("weapon")

    MakeInventoryFloatable(inst, "med", 0.1, {0.9, 0.4, 0.9}, true, -13, {
        sym_build = "medal_skin_staff",
        sym_name = "swap_medal_skin_staff",
        bank = "medal_skin_staff",
        anim = "medal_skin_staff"
    })

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- ====== 服务端组件 ======
    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(0)

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    -- ⚠️ 坑：imagename 不能带 .tex！replica 的 SetImage 会自动追加 ".tex"
    inst.components.inventoryitem.imagename = "medal_skin_staff"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/medal_skin_staff.xml"

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)

    -- Spellcaster：右键 NPC ⇒ 查看器
    inst:AddComponent("spellcaster")
    inst.components.spellcaster:SetSpellFn(spellfn)
    inst.components.spellcaster.canuseontargets = true
    inst.components.spellcaster.canusefrominventory = true
    inst.components.spellcaster.quickcast = true  -- 快速施法，减少动画时长

    MakeHauntableLaunch(inst)

    return inst
end

-- ========== 返回所有 Prefab ==========
return Prefab("hsee", hsee_fn, assets),
       make_pool_fn()
