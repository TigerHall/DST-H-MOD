require("constants")
local Text = require "widgets/text"
local Image = require "widgets/image"
local Widget = require "widgets/widget"
local UIAnim = require "widgets/uianim"

local ItemTile = Class(Widget, function(self, invitem, overridequantity)
    Widget._ctor(self, "ItemTile")
    -- 与insight不兼容
    self.fakeitem = invitem

	self.updatingflags = {}
    self.overridequantity = overridequantity or nil
    self.basescale = 1

    self:Init()
    self:Refresh()
end)

function ItemTile:Init()
    -- 新鲜度相关
    self.bg = self:AddChild(Image(HUD_ATLAS, "inv_slot_spoiled.tex"))
    self.bg:SetClickable(false)
    self.bg:Hide()

    self.spoilage = self:AddChild(UIAnim())
    self.spoilage:GetAnimState():SetBank("spoiled_meter")
    self.spoilage:GetAnimState():SetBuild("spoiled_meter")
    self.spoilage:GetAnimState():AnimateWhilePaused(false)
    self.spoilage:SetClickable(false)
    self.spoilage:Hide()

    -- rechargeframe
    self.rechargepct = 1
    self.rechargetime = math.huge

    self.rechargeframe = self:AddChild(UIAnim())
    self.rechargeframe:GetAnimState():SetBank("recharge_meter")
    self.rechargeframe:GetAnimState():SetBuild("recharge_meter")
    self.rechargeframe:GetAnimState():PlayAnimation("frame")
    self.rechargeframe:GetAnimState():AnimateWhilePaused(false)
    self.rechargeframe:SetClickable(false)
    self.rechargeframe:Hide()

    -- inv_image_bg
    local atlas = resolvefilepath(CRAFTING_ATLAS)
    local IconsUseCC = GetGameModeProperty("icons_use_cc")
    self.imagebg = self:AddChild(Image(atlas, "filterslot_bg.tex"))
    self.imagebg:SetClickable(false)
    if IconsUseCC then
        self.imagebg:SetEffect("shaders/ui_cc.ksh")
    end
    self.imagebg:Hide()

    -- image
    self.image = self:AddChild(Image(atlas, "filterslot_bg.tex"))
    if IconsUseCC then
        self.image:SetEffect("shaders/ui_cc.ksh")
    end

    -- recharge（覆盖在image前）
    self.recharge = self:AddChild(UIAnim())
    self.recharge:GetAnimState():SetBank("recharge_meter")
    self.recharge:GetAnimState():SetBuild("recharge_meter")
    self.recharge:GetAnimState():AnimateWhilePaused(false)
    self.recharge:SetClickable(false)

    -- 数量
    self.quantity = self:AddChild(Text(NUMBERFONT, 42))

    -- percent
    self.percent = self:AddChild(Text(NUMBERFONT, 42))
    if JapaneseOnPS4() then
        self.percent:SetHorizontalSqueeze(0.7)
    end
    self.percent:SetPosition(5, -32+15, 0)

    -- event
    self.inst:ListenForEvent("refreshcrafting",function()
        if self.focus and not TheInput:ControllerAttached() then
            self:UpdateTooltip()
        end
    end, ThePlayer)

    -- new event
    self.inst:ListenForEvent("simplestorage_updatetooltip",function()
        if self.focus and not TheInput:ControllerAttached() then
            self:UpdateTooltip()
        end
    end, ThePlayer)

    -- clinet event
    if not TheWorld.ismastersim then
        self.inst:ListenForEvent("newactiveitem",function()
            if self.focus and not TheInput:ControllerAttached() then
                self:UpdateTooltip()
            end
        end, ThePlayer)
    end

    -- tooltip colour
    self:SetTooltipColour(unpack(NORMAL_TEXT_COLOUR))
end

function ItemTile:Refresh()
    local invitem = self.fakeitem

    if invitem == nil then
        self:Hide()
        return
    end
    self:Show()

    -- 新鲜度相关
    local show_spoiled_meter = self:HasSpoilage() or invitem:HasTag("show_broken_ui")

	if show_spoiled_meter or invitem:HasTag("show_spoiled") then
		self.bg:Show()
    else
        self.bg:Hide()
    end

	if show_spoiled_meter then
        self.spoilage:Show()
    else
        self.spoilage:Hide()
    end

    -- 充能相关
    if invitem.components.rechargeable then -- and rechargeable.percent < 0.999
        
        if invitem:HasTag("rechargeable_bonus") then
            self.rechargeframe:GetAnimState():SetMultColour(0, 0.2, 0, 0.7)
            self.recharge:GetAnimState():SetMultColour(0, 0.3, 0, 0.8)
        else
            self.rechargeframe:GetAnimState():SetMultColour(0, 0, 0.3, 0.54)
            self.recharge:GetAnimState():SetMultColour(0, 0, 0.4, 0.64)
        end

        self.rechargepct = 1
        self.rechargetime = math.huge

        self:SetChargePercent(invitem.components.rechargeable.percent)
        self:SetChargeTime(invitem.components.rechargeable.time)
    else
        self:StopUpdatingCharge()
    end

    -- inv_image_bg
    if invitem.inv_image_bg then
        self.imagebg:Show()
        self.imagebg:SetTexture(invitem.inv_image_bg.atlas, invitem.inv_image_bg.image)
    else
        self.imagebg:Hide()
    end

    -- image
    self.image:SetTexture(invitem.replica.inventoryitem:GetAtlas(), invitem.replica.inventoryitem:GetImage())

    -- 数量
    if invitem.replica.stackable then
        self:SetQuantity(invitem.replica.stackable:StackSize())
    else
        self.quantity:SetString("")
    end

    -- percent
    if invitem.components.armor then
        self:SetPercent(invitem.components.armor.percent)
    elseif invitem.components.perishable then
        if self:HasSpoilage() then
            self:SetPerishPercent(invitem.components.perishable.percent)
        else
            self:SetPercent(invitem.components.perishable.percent)
        end
    elseif invitem.components.finiteuses then
        self:SetPercent(invitem.components.finiteuses.percent)
    elseif invitem.components.fueled then
        self:SetPercent(invitem.components.fueled.percent)
    else
        self.percent:SetString("")
    end
end

function ItemTile:SetBaseScale(sc)
    self.basescale = sc
    self:SetScale(sc)
end

function ItemTile:OnControl(control, down)
    self:UpdateTooltip()
    return false
end

function ItemTile:UpdateTooltip()
    local str = self:GetDescriptionString()
    self:SetTooltip(str)
end

function ItemTile:GetDescriptionString()
    if self.fakeitem == nil then
        return ""
    end
    local adj = self.fakeitem:GetAdjective()
    local name = self.fakeitem:GetDisplayName() or self.fakeitem.prefab or ""
    if adj ~= nil and adj ~= "" then
        return adj .. " " .. name
    end
    return name
end

function ItemTile:OnGainFocus()
    self:UpdateTooltip()
end

function ItemTile:SetOverrideQuantity(quantity)
    self.overridequantity = quantity
    self:SetQuantity()
end

function ItemTile:SetQuantity(quantity)
    local quantity = self.overridequantity or quantity or 1
	if quantity > 9999 then
        self.quantity:SetSize(45)
		self.quantity:SetPosition(2, 16, 0)
        local num = math.floor(quantity/1000)
		self.quantity:SetString(num.."k")
	else
		self.quantity:SetSize(42)
		self.quantity:SetPosition(2, 16, 0)
		self.quantity:SetString(tostring(quantity))
	end
end

function ItemTile:SetPerishPercent(percent)
    if self.fakeitem == nil or type(percent) ~= "number" then return end
    self.percent:SetString("")
    --percent is approximated over the network, so check tags to
    --determine the correct color at the 50% and 20% boundaries.
    if percent < .51 and percent > .49 and self.fakeitem:HasTag("fresh") then
        self.spoilage:GetAnimState():OverrideSymbol("meter", "spoiled_meter", "meter_green")
        self.spoilage:GetAnimState():OverrideSymbol("frame", "spoiled_meter", "frame_green")
    elseif percent < .21 and percent > .19 and self.fakeitem:HasTag("stale") then
        self.spoilage:GetAnimState():OverrideSymbol("meter", "spoiled_meter", "meter_yellow")
        self.spoilage:GetAnimState():OverrideSymbol("frame", "spoiled_meter", "frame_yellow")
    else
        self.spoilage:GetAnimState():ClearAllOverrideSymbols()
    end
    --don't use 100% frame, since it should be replace by something like "spoiled_food" then
    self.spoilage:GetAnimState():SetPercent("anim", math.clamp(1 - percent, 0, 0.99))
end

function ItemTile:SetPercent(percent)
    if self.fakeitem == nil then return end

	if self.fakeitem:HasTag("hide_percentage") then
        self.percent:SetString("")
        return
    end

    -- ⚠️ 有些 mod 的 armor / fueled 组件没有 percent 字段，
    --    直接乘会 arithmetic on nil。空着不显示即可。
    if type(percent) ~= "number" then
        self.percent:SetString("")
        return
    end

    local val_to_show = percent * 100
    if val_to_show > 0 and val_to_show < 1 then
        val_to_show = 1
    end

    self.percent:SetString(string.format("%2.0f%%", val_to_show))

    -- 耐久度覆盖新鲜度显示
    if self.fakeitem:HasTag("show_broken_ui") then
        if percent > 0 then
            self.bg:Hide()
            self.spoilage:Hide()
        else
            self.bg:Show()
            self.spoilage:Show()
            self:SetPerishPercent(0)
        end
    end
end

function ItemTile:SetChargePercent(percent)
    if type(percent) ~= "number" then
        self:StopUpdatingCharge()
        return
    end
	local prev_precent = self.rechargepct
    self.rechargepct = percent
    if percent < 1 then
        self.recharge:GetAnimState():SetPercent("recharge", percent)
        if percent >= 0.9999 then
            self:StopUpdatingCharge()
        elseif self.rechargetime < math.huge then
            self:StartUpdatingCharge()
        end
    else
        if prev_precent < 1 and not self.recharge:GetAnimState():IsCurrentAnimation("frame_pst") then
            self.recharge:GetAnimState():PlayAnimation("frame_pst")
        end
        self:StopUpdatingCharge()
    end
end

function ItemTile:SetChargeTime(t)
    self.rechargetime = t
    if self.rechargetime >= math.huge then
		self:StopUpdatingCharge()
    elseif self.rechargepct < 0.9999 then
		self:StartUpdatingCharge()
    end
end

function ItemTile:HasSpoilage()
    return self.fakeitem and self.fakeitem.hasspoilage
end

local function _StartUpdating(self, flag)
	if next(self.updatingflags) == nil then
		self:StartUpdating()
	end
	self.updatingflags[flag] = true
end

local function _StopUpdating(self, flag)
	self.updatingflags[flag] = nil
	if next(self.updatingflags) == nil then
		self:StopUpdating()
	end
end

function ItemTile:StartUpdatingCharge()
    self.rechargeframe:Show()
    self.recharge:Show()
	_StartUpdating(self, "charge")
end

function ItemTile:StopUpdatingCharge()
    self.rechargeframe:Hide()
    if not self.recharge:GetAnimState():IsCurrentAnimation("frame_pst") then
        self.recharge:Hide()
    end
	_StopUpdating(self, "charge")
end

function ItemTile:OnUpdate(dt)
    if TheNet:IsServerPaused() then return end

	if self.updatingflags.charge then
		self:SetChargePercent(self.rechargetime > 0 and self.rechargepct + dt / self.rechargetime or .9999)
	end

end

function ItemTile:StartDrag()
	self.dragging = true

    self.spoilage:Hide()
    self.bg:Hide()
    self.recharge:Hide()
    self.rechargeframe:Hide()

    self:StopUpdating()
    self.image:SetClickable(false)
end

return ItemTile
