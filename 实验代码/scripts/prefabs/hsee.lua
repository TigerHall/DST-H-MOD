--[[
HSee —— 自带容器的查看器物品（复用官方鱼箱 ui_fish_box_5x4 素材）
- 装备后右键施法 → 打开 HSee 自身的 5×4 容器
- 复制目标的装备/物品到容器（副本，不影响原物品）
- 容器参数通过 containers.params.hsee 注册（让客户端 replica 自动找到 widget）
]]

local assets = {
    --Asset("ANIM", "anim/medal_skin_staff.zip"),
    Asset("ANIM", "anim/cutless.zip"),
    Asset("ATLAS", "images/inventoryimages/heh.xml"),
    --Asset("ATLAS_BUILD", "images/inventoryimages/medal_skin_staff.xml", 256),
}

--------------------------------------------------------------------------
-- 复制目标的物品到容器（SpawnPrefab 创建副本）
--------------------------------------------------------------------------
local function SnapshotTargetItems(container, target)
    local target_inv = target.components.inventory
    if not target_inv then return end

    -- 清空容器上轮残留
    for i = container.numslots, 1, -1 do
        local item = container:RemoveItemBySlot(i)
        if item then item:Remove() end
    end

    -- 1. 装备栏 → 前 3 格：手 → 身 → 头（与底图顺序一致）
    local equip_order = { "hands", "body", "head" }
    for slot_num, eslot in ipairs(equip_order) do
        local item = target_inv:GetEquippedItem(eslot)
        if item then
            local copy = SpawnPrefab(item.prefab)
            if copy then
                container:GiveItem(copy, slot_num, nil, false)
                print("[HSee] Copy equip", item.prefab, "→ slot", slot_num)
            end
        end
    end

    -- 2. 物品栏 → 第 4 格起，一一对应
    local container_slot = 4
    for i = 1, target_inv:GetNumSlots() do
        if container_slot > container.numslots then break end
        local item = target_inv:GetItemInSlot(i)
        if item then
            local copy = SpawnPrefab(item.prefab)
            if copy then
                container:GiveItem(copy, container_slot, nil, false)
                print("[HSee] Copy item", item.prefab, "→ slot", container_slot)
                container_slot = container_slot + 1
            end
        end
    end
end

--------------------------------------------------------------------------
-- hsee 物品（自带容器）
--------------------------------------------------------------------------
local function hsee_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    -- 外观：复用官方木头短剑 cutless
    --inst.AnimState:SetBank("medal_skin_staff")
    --inst.AnimState:SetBuild("medal_skin_staff")
    --inst.AnimState:PlayAnimation("medal_skin_staff")
    inst.AnimState:SetBank("cutless")
    inst.AnimState:SetBuild("cutless")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("nopunch")

    -- 浮空效果
    MakeInventoryFloatable(inst, "med", 0.05, {1.1, 0.5, 1.1}, true, -18, {
        sym_name = "swap_cutless",
        sym_build = "cutless",
        bank = "cutless",
        anim = "idle",
    })

    -- 官方模式：SetPristine 之后再添加容器组件
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    -- ======== 服务端只此开始 ========

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "heh"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/heh.xml"

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(function(inst, owner)
        owner.AnimState:OverrideSymbol("swap_object", "cutless", "swap_cutless")
        owner.AnimState:Show("ARM_carry")
        owner.AnimState:Hide("ARM_normal")
    end)
    inst.components.equippable:SetOnUnequip(function(inst, owner)
        owner.AnimState:Hide("ARM_carry")
        owner.AnimState:Show("ARM_normal")
    end)

    -- 容器组件（SetPristine 之后，replica 已就绪）
    inst:AddComponent("container")
    inst.components.container:WidgetSetup("hsee")
    inst.components.container.onopenfn = function(inst, doer)
        -- ⚠️ onopenfn/onclosefn 参数是实体（self.inst），不是容器组件
        print("[HSee] opened by", doer and doer.prefab or "unknown")
    end
    inst.components.container.onclosefn = function(inst, doer, ...)
        local cc = inst.components.container
        if not cc then return end
        print("[HSee] closed by", doer and doer.prefab or "unknown")
        for i = cc.numslots, 1, -1 do
            local item = cc:RemoveItemBySlot(i)
            if item then item:Remove() end
        end
    end

    -- 右键施法 → 打开自身容器（仅对有物品栏+装备栏的实体）
    inst:AddComponent("spellcaster")
    inst.components.spellcaster:SetCanCastFn(function(sinst, target, pos, doer)
        print("[HSee] CanCast check: sinst=", sinst.prefab, " target=", target and target.prefab or "nil", " doer=", doer and doer.prefab or "nil")
        return true
    end)
    inst.components.spellcaster:SetSpellFn(function(sinst, target, pos, doer)
        print("[HSee] SpellCast: sinst=", sinst.prefab, " target=", target and target.prefab or "nil", " pos=", pos and tostring(pos) or "nil", " doer=", doer and doer.prefab or "nil")

        -- 过滤：必须是有物品栏（inventory）或有装备栏（equippable）的实体
        if target == nil then
            print("[HSee] Reject: no target")
            if doer and doer.components.talker then
                doer.components.talker:Say("I cannot do that!")
            end
            return
        end

        local has_inv = target.components.inventory ~= nil
        local has_equip = target.components.equippable ~= nil

        if not has_inv and not has_equip then
            print("[HSee] Reject: target has no inventory or equipment:", target.prefab)
            if doer and doer.components.talker then
                doer.components.talker:Say("I cannot do that!")
            end
            return
        end

        print("[HSee] Valid target:", target.prefab, " has_inv=", has_inv, " has_equip=", has_equip)

        -- 打开容器 + 复制物品
        if sinst.components.container ~= nil then
            local container = sinst.components.container
            container:Open(doer)
            print("[HSee] Container opened for doer:", doer and doer.prefab or "nil")

            -- 下一帧复制物品（等容器 UI 完全打开）
            sinst:DoTaskInTime(0, function()
                SnapshotTargetItems(container, target)
                print("[HSee] SnapshotTargetItems done")
            end)
        else
            print("[HSee] ERROR: sinst has no container component!")
        end
    end)
    inst.components.spellcaster.canuseontargets = true
    inst.components.spellcaster.canusefrominventory = true
    inst.components.spellcaster.veryquickcast = true

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("hsee", hsee_fn, assets)
