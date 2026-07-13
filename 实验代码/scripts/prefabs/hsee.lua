--[[
HSee —— 自带容器的查看器物品（复用官方鱼箱 ui_fish_box_5x4 素材）
- 装备后右键施法 → 打开 HSee 自身的 5×5 容器
- 复制目标的装备/物品到容器 → 双向同步
- 容器参数通过 containers.params.hsee 注册
]]

local assets = {
    Asset("ANIM", "anim/cutless.zip"),
    Asset("ATLAS", "images/inventoryimages/heh.xml"),
}

--------------------------------------------------------------------------
-- 复制目标的物品到容器
--------------------------------------------------------------------------
local function SnapshotTargetItems(container, target)
    -- 快照期间设置 syncing 标志，防止容器事件误触发同步
    local inst = container.inst
    local was_syncing = inst and inst._hsee_syncing
    if inst then inst._hsee_syncing = true end

    local target_inv = target.components.inventory
    if not target_inv then
        print("[HSee] ERROR: target has no inventory")
        if inst and not was_syncing then inst._hsee_syncing = false end
        return
    end

    for i = container.numslots, 1, -1 do
        local item = container:RemoveItemBySlot(i)
        if item then item:Remove() end
    end

    -- 装备栏：固定前三格（手/身/头），有装备放副本，无则空
    local EQUIP_MAP = { [1] = "hands", [2] = "body", [3] = "head" }
    local equip_count = 5  -- 第一行 5 格都是装备区，优先尝试装备
    local equip_keys = {}
    for slot_idx = 1, equip_count do
        local eslot = EQUIP_MAP[slot_idx]
        local item = target_inv.equipslots[eslot]
        if item then
            local record = item:GetSaveRecord()
            if record then
                local copy = SpawnSaveRecord(record)
                if copy then
                    local ok = container:GiveItem(copy, slot_idx, nil, false)
                    if not ok then copy:Remove() end
                end
            end
            equip_keys[slot_idx] = eslot
        end
    end
    if inst then
        inst._hsee_equip_keys = equip_keys
        inst._hsee_equip_count = equip_count
    end

    local container_slot = container.numslots
    local slot_items = {}
    for i, item in pairs(target_inv.itemslots or {}) do
        if item then table.insert(slot_items, { idx = i, item = item }) end
    end
    table.sort(slot_items, function(a, b) return a.idx < b.idx end)

    for _, entry in ipairs(slot_items) do
        if container_slot <= equip_count then break end  -- 跳过第一行装备区
        local item = entry.item
        local record = item:GetSaveRecord()
        if record then
            local copy = SpawnSaveRecord(record)
            if copy then
                local ok = container:GiveItem(copy, container_slot, nil, false)
                if ok then container_slot = container_slot - 1
                else copy:Remove() end
            end
        end
    end

    if inst and not was_syncing then inst._hsee_syncing = false end
end

--------------------------------------------------------------------------
-- 同步：容器 → 目标（实时比较，无映射）
-- 放东西 → GiveItem（官方自动处理装备/物品栏），满则丢地
-- 拿装备 → Unequip 销毁原件
-- 拿物品 → RemoveItemBySlot 丢原件
-- 完成后延迟快照刷新
--------------------------------------------------------------------------
local function SyncContainerToTarget(inst, target, data)
    if inst._hsee_syncing then return end
    inst._hsee_syncing = true

    local cc = inst.components.container
    local target_inv = target.components.inventory
    if not cc or not target_inv then
        inst._hsee_syncing = false
        return
    end

    local function Say(doer, msg)
        if doer and doer.components.talker then
            doer.components.talker:Say(msg)
        end
    end

    local function DropAtGround(item_inst, where_inst)
        local x,y,z = where_inst.Transform:GetWorldPosition()
        item_inst.Transform:SetPosition(x,y,z)
    end

    local function DestroyFromPlayer(item_inst, doer)
        if not item_inst or not item_inst:IsValid() then return end
        if doer and doer.components.inventory then
            local active = doer.components.inventory:GetActiveItem()
            if active == item_inst then
                doer.components.inventory:DropActiveItem()
                if item_inst:IsValid() then item_inst:Remove() end
                return
            end
            for slot = doer.components.inventory:GetNumSlots(), 1, -1 do
                if doer.components.inventory:GetItemInSlot(slot) == item_inst then
                    local removed = doer.components.inventory:RemoveItemBySlot(slot)
                    if removed and removed:IsValid() then removed:Remove() end
                    return
                end
            end
        end
        if item_inst:IsValid() then item_inst:Remove() end
    end

    local function GetDoer()
        for opener, _ in pairs(cc.openlist or {}) do return opener end
        return nil
    end
    local doer = GetDoer()

    -- 丢物品到目标脚下（玩家在容器 UI 上看不到自己脚下）
    local function DropAtTargetFeet(item_inst)
        if not item_inst or not item_inst:IsValid() then return end
        if target and target:IsValid() then
            local x,y,z = target.Transform:GetWorldPosition()
            item_inst.Transform:SetPosition(x + 1, y, z + 1)
        elseif doer then
            local x,y,z = doer.Transform:GetWorldPosition()
            item_inst.Transform:SetPosition(x + 1, y, z + 1)
        else
            item_inst:Remove()
        end
    end

    -- 强制堆叠 + GiveItem 兜底（跳过新鲜度检查）
    local function GiveForceStack(item_to_give)
        if not item_to_give or not item_to_give:IsValid() then return end
        for i = 1, target_inv:GetNumSlots() do
            local inv_item = target_inv:GetItemInSlot(i)
            if inv_item and inv_item.prefab == item_to_give.prefab
                and inv_item.components.stackable
                and not inv_item.components.stackable:IsFull() then
                local leftover = inv_item.components.stackable:Put(item_to_give)
                if leftover then
                    if not target_inv:GiveItem(leftover) then
                        DropAtTargetFeet(leftover)
                    end
                end
                return true
            end
        end
        if not target_inv:GiveItem(item_to_give) then
            DropAtTargetFeet(item_to_give)
            return false
        end
        return true
    end

    local equip_keys = inst._hsee_equip_keys or {}
    local equip_count = inst._hsee_equip_count or 5

    -- ======== 装备栏（slot 1 ~ equip_count）：全量对比 ========
    for slot = 1, equip_count do
        local eslot = equip_keys[slot]
        local item_in_slot = cc:GetItemInSlot(slot)
        local item_on_target = target_inv.equipslots[eslot]

        if item_in_slot and not item_on_target then
            -- 放装备 → Equip → GiveItem → 丢地
            cc:RemoveItemBySlot(slot)
            if item_in_slot.components.equippable then
                if not target_inv:Equip(item_in_slot) then
                    if not GiveForceStack(item_in_slot) then
                        Say(doer, "装不上也放不下，丢目标脚下了！")
                    else
                        Say(doer, "放物品栏了！")
                    end
                else
                    Say(doer, "装备自动穿戴到正确位置了！")
                end
            else
                GiveForceStack(item_in_slot)
            end

        elseif not item_in_slot and item_on_target then
            -- 拿装备 → Unequip(slip=true) 触发目标动画 → 销毁原件
            local removed = target_inv:Unequip(eslot, true)
            if not removed then
                if data and data.item and data.item:IsValid() then
                    DestroyFromPlayer(data.item, doer)
                end
                Say(doer, "摘不下来啊！")
            else
                if removed:IsValid() then removed:Remove() end
                Say(doer, "装备到手了！")
            end

        elseif item_in_slot and item_on_target
            and item_in_slot.prefab ~= item_on_target.prefab then
            -- 替换装备：双方都有但 prefab 不同 → 卸旧装新
            local old = target_inv:Unequip(eslot)
            if old and old:IsValid() then old:Remove() end
            cc:RemoveItemBySlot(slot)
            if item_in_slot.components.equippable then
                if not target_inv:Equip(item_in_slot) then
                    if not GiveForceStack(item_in_slot) then
                        Say(doer, "替换失败，丢地上了！")
                    end
                else
                    Say(doer, "替换装备成功！")
                end
            else
                GiveForceStack(item_in_slot)
            end
        end
    end

    -- ======== 物品栏（slot equip_count+1 ~ end）========
    -- 基于 data.item 精确处理堆叠
    if data and data.item and data.item:IsValid() and data.slot and data.slot > equip_count then
        local cc_now_has = cc:GetItemInSlot(data.slot) ~= nil

        if cc_now_has then
            -- ★ 放入了物品 → 从容器取出给目标
            local item = cc:GetItemInSlot(data.slot)
            if item then
                cc:RemoveItemBySlot(data.slot)
                GiveForceStack(item)
            end
        else
            -- ★ 取走了物品 → 在目标身上按 prefab 减堆叠
            local taken_item = data.item
            local taken_prefab = taken_item.prefab
            local taken_stack = taken_item.components.stackable and taken_item.components.stackable:StackSize() or 1

            -- 在目标物品栏找同名物品，减少堆叠数
            local removed_any = false
            for slot = target_inv:GetNumSlots(), 1, -1 do
                local target_item = target_inv:GetItemInSlot(slot)
                if target_item and target_item.prefab == taken_prefab then
                    if target_item.components.stackable then
                        local cur = target_item.components.stackable:StackSize()
                        if cur > taken_stack then
                            target_item.components.stackable:SetStackSize(cur - taken_stack)
                            taken_stack = 0
                            removed_any = true
                            break
                        else
                            taken_stack = taken_stack - cur
                            local removed_stack = target_inv:RemoveItemBySlot(slot)
                            if removed_stack and removed_stack:IsValid() then
                                removed_stack:Remove()
                            end
                            if taken_stack <= 0 then
                                removed_any = true
                                break
                            end
                        end
                    else
                        -- 非堆叠：直接移除并销毁原件
                        local removed = target_inv:RemoveItemBySlot(slot)
                        if removed and removed:IsValid() then
                            removed:Remove()
                        end
                        removed_any = true
                        break
                    end
                end
            end

            -- 如果拿走的堆叠数还没扣完（目标没有这么多），销毁玩家拿到的部分
            if not removed_any then
                if data.item and data.item:IsValid() then
                    DestroyFromPlayer(data.item, doer)
                end
                Say(doer, "它没有这么多！")
            else
                Say(doer, "拿到了！")
            end
        end
    end

    inst._hsee_syncing = false

    -- 关闭 + 重开容器，强制客户端重建 widget，清除残留
    local l_doer = doer
    inst:DoTaskInTime(0, function()
        if not inst:IsValid() or not target:IsValid() or not l_doer then return end
        local con = inst.components.container
        if not con then return end
        con:Close(l_doer)                -- 关闭（onclosefn 清物品、清监听、清 _hsee_target）
        inst._hsee_target = target       -- 恢复 target 引用
        con:Open(l_doer)                 -- 重开（onopenfn 重建监听）
        SnapshotTargetItems(con, target) -- 重新填充
    end)
end

--------------------------------------------------------------------------
-- 监听设置/清理
--------------------------------------------------------------------------
local function SetupListeners(inst, target, doer)
    -- 容器事件 → 同步到目标
    inst._hsee_c_get = function(src, data)
        local t = inst._hsee_target
        if t and t:IsValid() and t == target then
            SyncContainerToTarget(inst, t, data)
        end
    end
    inst._hsee_c_lose = function(src, data)
        -- 容器 itemlose 用 prev_item 而非 item
        local t = inst._hsee_target
        if t and t:IsValid() and t == target then
            data = data or {}
            data.item = data.item or data.prev_item
            SyncContainerToTarget(inst, t, data)
        end
    end
    inst:ListenForEvent("itemget", inst._hsee_c_get)
    inst:ListenForEvent("itemlose", inst._hsee_c_lose)

    -- 目标事件 → 重刷容器
    inst._hsee_t_get = function()
        local t = inst._hsee_target
        if t and t:IsValid() and t == target and not inst._hsee_syncing then
            SnapshotTargetItems(inst.components.container, t)
        end
    end
    inst._hsee_t_lose = function()
        local t = inst._hsee_target
        if t and t:IsValid() and t == target and not inst._hsee_syncing then
            print("[HSee] target itemlose, refreshing")
            SnapshotTargetItems(inst.components.container, t)
        end
    end
    target:ListenForEvent("itemget", inst._hsee_t_get)
    target:ListenForEvent("itemlose", inst._hsee_t_lose)
end

local function RemoveListeners(inst, target)
    inst:RemoveEventCallback("itemget", inst._hsee_c_get)
    inst:RemoveEventCallback("itemlose", inst._hsee_c_lose)
    inst._hsee_c_get = nil
    inst._hsee_c_lose = nil
    if target and target:IsValid() then
        target:RemoveEventCallback("itemget", inst._hsee_t_get)
        target:RemoveEventCallback("itemlose", inst._hsee_t_lose)
    end
    inst._hsee_t_get = nil
    inst._hsee_t_lose = nil
end

--------------------------------------------------------------------------
-- hsee 物品
--------------------------------------------------------------------------
local function hsee_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("cutless")
    inst.AnimState:SetBuild("cutless")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("nopunch")

    MakeInventoryFloatable(inst, "med", 0.05, { 1.1, 0.5, 1.1 }, true, -18, {
        sym_name = "swap_cutless",
        sym_build = "cutless",
        bank = "cutless",
        anim = "idle",
    })

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

    -- 容器组件
    inst:AddComponent("container")
    inst.components.container:WidgetSetup("hsee")

    inst.components.container.onopenfn = function(inst, doer)
        local target = inst._hsee_target
        print("[HSee] opened, target=", target and target.prefab or "nil")
        SetupListeners(inst, target, doer)
    end

    inst.components.container.onclosefn = function(inst, doer, ...)
        local cc = inst.components.container
        if not cc then return end
        print("[HSee] closed by", doer and doer.prefab or "unknown")
        RemoveListeners(inst, inst._hsee_target)
        for i = cc.numslots, 1, -1 do
            local item = cc:RemoveItemBySlot(i)
            if item then item:Remove() end
        end
        inst._hsee_target = nil
    end

    -- 右键施法
    inst:AddComponent("spellcaster")
    inst.components.spellcaster:SetCanCastFn(function(sinst, target, pos, doer)
        return true
    end)
    inst.components.spellcaster:SetSpellFn(function(sinst, target, pos, doer)
        if target == nil then
            if doer and doer.components.talker then
                doer.components.talker:Say("󰀯这是啥!")
            end
            return
        end

        local has_inv = target.components.inventory ~= nil
        if not has_inv then
            if doer and doer.components.talker then
                doer.components.talker:Say("󰀯啥也不是!")
            end
            return
        end

        if sinst.components.container ~= nil then
            local container = sinst.components.container
            -- 如果已打开（换目标施法），先关闭再重开，避免同步错乱
            if container.opencount > 0 then
                container:Close(doer)
            end
            sinst._hsee_target = target
            container:Open(doer)
            -- 立即快照（不延迟，避免玩家交互时映射未就绪）
            SnapshotTargetItems(container, target)
        end
    end)
    inst.components.spellcaster.canuseontargets = true
    inst.components.spellcaster.canusefrominventory = true
    inst.components.spellcaster.veryquickcast = true

    MakeHauntableLaunch(inst)

    -- 呼吸跑马灯效果
    inst:DoTaskInTime(0, function()
        if not inst:IsValid() or not inst.AnimState then return end
        inst.AnimState:SetHaunted(true)
        local BREATH_SPEED, BREATH_INTENSITY, COLOR_CYCLE_SPEED = 1.2, 1.2, 1.6
        local time = 0
        local function HueToRGB(hue)
            local r = (math.sin(hue) + 1) / 2
            local g = (math.sin(hue + 2.094) + 1) / 2
            local b = (math.sin(hue + 4.189) + 1) / 2
            return r, g, b
        end
        local breath_task = inst:DoPeriodicTask(0.05, function()
            time = time + 0.05
            local phase = (math.sin(time * 2 * math.pi / BREATH_SPEED) + 1) / 2
            local intensity = phase * BREATH_INTENSITY
            local hue = time * 2 * math.pi / COLOR_CYCLE_SPEED
            local cr, cg, cb = HueToRGB(hue)
            if inst.AnimState then
                inst.AnimState:SetAddColour(cr * intensity, cg * intensity, cb * intensity, 0)
            end
            local owner_t = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()
            if owner_t and owner_t:HasTag("player") and owner_t.AnimState then
                local mr = 1 - (1 - cr) * intensity * 0.25
                local mg = 1 - (1 - cg) * intensity * 0.25
                local mb = 1 - (1 - cb) * intensity * 0.25
                owner_t.AnimState:SetSymbolMultColour("swap_object", mr, mg, mb, 1)
                local glow = intensity * 0.8
                if cr + cg + cb > 0.01 then
                    owner_t.AnimState:SetSymbolAddColour("swap_object", cr * glow, cg * glow, cb * glow, 0)
                end
            end
        end)
        inst:ListenForEvent("onremove", function()
            if breath_task then breath_task:Cancel() end
        end)
    end)

    return inst
end

return Prefab("hsee", hsee_fn, assets)
