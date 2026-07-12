--[[
HSee —— 自带容器的查看器物品（复用官方鱼箱 ui_fish_box_5x4 素材）
- 装备后右键施法 → 打开 HSee 自身的 5×4 容器
- 不限制物品类型（区别于鱼箱只接受 smalloceancreature）
- 容器参数通过 containers.params.hsee 注册（让客户端 replica 自动找到 widget）
]]

local assets = {
    --Asset("ANIM", "anim/medal_skin_staff.zip"), -- 旧勋章素材，保留以备用
    Asset("ANIM", "anim/cutless.zip"),
    Asset("ATLAS", "images/inventoryimages/heh.xml"),
    --Asset("ATLAS_BUILD", "images/inventoryimages/medal_skin_staff.xml", 256),
}

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
    --MakeInventoryFloatable(inst, "med", 0.1, {0.9, 0.4, 0.9}, true, -13, {
    --    sym_build = "medal_skin_staff",
    --    sym_name = "swap_medal_skin_staff",
    --    bank = "medal_skin_staff",
    --    anim = "medal_skin_staff"
    --})
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
    --inst.components.inventoryitem.imagename = "medal_skin_staff"
    --inst.components.inventoryitem.atlasname = "images/inventoryimages/medal_skin_staff.xml"
    inst.components.inventoryitem.imagename = "heh"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/heh.xml"

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(function(inst, owner)
        --owner.AnimState:OverrideSymbol("swap_object", "medal_skin_staff", "swap_medal_skin_staff")
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
    inst.components.container.onopenfn = function(container, doer)
        print("[HSee] opened by", doer and doer.prefab or "unknown")
    end
    inst.components.container.onclosefn = function(container, doer, ...)
        print("[HSee] closed by", doer and doer.prefab or "unknown")
    end

    -- 右键施法 → 打开自身容器（仅对有物品栏+装备栏的实体）
    -- canuseontargets = true：需要面对实体才能施法（和之前一样）
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

        -- 打开容器
        if sinst.components.container ~= nil then
            sinst.components.container:Open(doer)
            print("[HSee] Container opened for doer:", doer and doer.prefab or "nil")
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
