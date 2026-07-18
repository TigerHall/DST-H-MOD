-- scripts/prefabs/hh_offlinevault.lua
-- 离线托管实体：玩家下线时，其物品被转移到此隐藏实体中暂存。
-- 设计参考官方 powdermonkey：猴子把偷来的东西存在自己的 inventory 组件里（非 container）。
-- 这里复刻同一思路——用一个隐藏实体 + inventory 组件临时“带走”离线玩家的全部物品。
-- 实体与其中物品都会随世界存档自动持久化（inventory 组件自带 OnSave/OnLoad）。

local function OnSave(inst, data)
    data.userid = inst.userid
    data.leave_cycle = inst.leave_cycle
end

local function OnLoad(inst, data)
    if data ~= nil then
        inst.userid = data.userid
        inst.leave_cycle = data.leave_cycle or 0
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()
    -- 托管实体不应睡觉，避免被世界清理逻辑误删
    inst.entity:SetCanSleep(false)

    -- 标记：供 FindEntities 检索；CLASSIFIED/NOBLOCK 避免交互与阻挡
    inst:AddTag("hh_offlinevault")
    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOBLOCK")
    inst:Hide()

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        -- 客户端不需要 inventory 组件，提前返回（避免客户端 replica 负担）
        return inst
    end

    -- inventory 组件：maxslots 设大，确保能装下玩家全部物品（背包本身作为一个物品整体移入）
    inst:AddComponent("inventory")
    inst.components.inventory.maxslots = 120
    -- 托管时不发出拾取音效
    inst.components.inventory.ignoresound = true

    -- 持久化 userid / 离开时的天数的
    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

return Prefab("hh_offlinevault", fn, {}, {})
