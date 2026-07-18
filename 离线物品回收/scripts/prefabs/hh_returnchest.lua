-- scripts/prefabs/hh_returnchest.lua
-- “归还箱”：宽限期到期后，在离线玩家离开的坐标生成的巨大宝箱。
-- UI 复用官方 base-game 图集 ui_boat_ancient_4x4（4x4 = 16 格，已确认是官方资产，非某 MOD 私有）。
-- 物品超出 16 格时，由 modmain 逻辑额外生成多个归还箱兜底（确保装得完）。

local containers = require("containers")
local params = containers.params

-- ── 注册 4x4 巨型宝箱 UI（必须在 widget 构造前定义，客户端/服务端都会执行）──
params.hh_returnchest = {
    widget = {
        slotpos = {},
        animbank = "ui_boat_ancient_4x4",
        animbuild = "ui_boat_ancient_4x4",
        pos = Vector3(-350, 240, 0),
    },
    type = "hh_returnchest",
    -- 接受一切物品（玩家原本持有的都还回来，包括不可放入普通箱子的东西）
    itemtestfn = function(inst, item, slot)
        return true
    end,
}

-- 4x4 格子布局（与 ui_boat_ancient_4x4 图集严格对应，复用 hslot 已验证的偏移）
for y = 3, 0, -1 do
    for x = 0, 3 do
        table.insert(params.hh_returnchest.widget.slotpos, Vector3(75 * x - 116, 75 * y - 116, 0))
    end
end

local assets = {
    Asset("ANIM", "anim/treasure_chest.zip"),
    Asset("ANIM", "anim/ui_chest_3x3.zip"),
    Asset("ANIM", "anim/ui_boat_ancient_4x4.zip"),
}

local prefabs = { "collapse_small" }

local SOUNDS = {
    open = "dontstarve/wilson/chest_open",
    close = "dontstarve/wilson/chest_close",
    built = "dontstarve/common/chest_craft",
}

local function onopen(inst)
    if not inst:HasTag("burnt") then
        inst.AnimState:PlayAnimation("open")
        inst.SoundEmitter:PlaySound(inst.sounds.open)
    end
end

local function onclose(inst)
    if not inst:HasTag("burnt") then
        inst.AnimState:PlayAnimation("close")
        inst.AnimState:PushAnimation("closed", false)
        inst.SoundEmitter:PlaySound(inst.sounds.close)
    end
end

local function onhammered(inst, worker)
    if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then
        inst.components.burnable:Extinguish()
    end
    inst.components.lootdropper:DropLoot()
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
    end
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")
    inst:Remove()
end

local function onhit(inst, worker)
    if not inst:HasTag("burnt") then
        if inst.components.container ~= nil then
            inst.components.container:DropEverything()
            inst.components.container:Close()
        end
        inst.AnimState:PlayAnimation("hit")
        inst.AnimState:PushAnimation("closed", false)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("treasurechest.png")

    inst:AddTag("structure")
    inst:AddTag("chest")

    inst.AnimState:SetBank("chest")
    inst.AnimState:SetBuild("treasure_chest")
    inst.AnimState:PlayAnimation("closed")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.sounds = SOUNDS

    inst:AddComponent("inspectable")
    inst:AddComponent("container")
    inst.components.container:WidgetSetup("hh_returnchest")
    inst.components.container.onopenfn = onopen
    inst.components.container.onclosefn = onclose
    inst.components.container.skipclosesnd = true
    inst.components.container.skipopensnd = true

    inst:AddComponent("lootdropper")

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(2)
    inst.components.workable:SetOnFinishCallback(onhammered)
    inst.components.workable:SetOnWorkCallback(onhit)

    MakeSmallBurnable(inst, nil, nil, true)
    MakeMediumPropagator(inst)

    inst:AddComponent("hauntable")
    inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)

    return inst
end

return Prefab("hh_returnchest", fn, assets, prefabs)
