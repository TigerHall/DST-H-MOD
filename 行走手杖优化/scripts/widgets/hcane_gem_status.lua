-- H-手杖宝石状态 UI（5.6.29 双实例）
--   ① corner_mode=true：格子左上角角标，只显示宝石贴图，无宝石留空。
--   ② corner_mode=false：装备栏手杖中心原 UI，有宝石显示贴图，无宝石显示鬼魂/灯泡。
--   总开关关 = 宝石亮起（白）；总开关开 = 宝石炫彩（色相循环）。
-- 数据源：手杖实例 _hcane_gem_net / _hcane_multi_net（itemtile 按实例读并 SetGem/SetMulti）。
-- ⚠️ Widget 用 StartUpdating()+OnUpdate(dt) 每帧钩子（frontend.lua:894），不是 Update()。

local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")

local GEM_VIEW =
{
    red    = "redgem.tex",
    orange = "orangegem.tex",
    yellow = "yellowgem.tex",
    green  = "greengem.tex",
    blue   = "bluegem.tex",
    purple = "purplegem.tex",
}

-- ⚠️ 用字节转义，别直接写 PUA 字符（防文件编码被改坏）
local GLYPH_LIGHT_ON = "\243\176\128\143"  -- 󰀏 U+F000F 灯泡 = 开
local GLYPH_LIGHT_OFF = "\243\176\128\137" -- 󰀉 U+F0009 鬼魂 = 关

local HcaneGemStatus = Class(Widget, function(self, owner, corner_mode)
    Widget._ctor(self, "HcaneGemStatus")
    self.owner = owner
    self.corner_mode = (corner_mode == true)
    self._key = nil
    self._multi = false
    self._hue_time = 0

    -- 宝石图标（选中宝石时显示，居中）
    self.gem = self:AddChild(Image("images/inventoryimages1.xml", "redgem.tex"))
    self.gem:SetScale(1.0)
    self.gem:SetPosition(0, 0, 0)
    self.gem:SetClickable(false)
    self.gem:Hide()

    -- 炫彩叠层：总开关开时 Additive 叠加，色相随时间循环
    self.glow = self:AddChild(Image("images/inventoryimages1.xml", "redgem.tex"))
    self.glow:SetScale(1.0)
    self.glow:SetPosition(0, 0, 0)
    self.glow:SetBlendMode(BLENDMODE.Additive)
    self.glow:SetTint(1, 1, 1, 1)
    self.glow:SetClickable(false)
    self.glow:Hide()

    -- 中心 UI 无宝石时显示鬼魂/灯泡；角标模式始终隐藏（开关状态由格子下方字形+文字承担）
    self.state = self:AddChild(Text(NEWFONT, 46, GLYPH_LIGHT_OFF))
    self.state:SetClickable(false)
    self.state:Hide()

    self:StartUpdating()
    self.inst:ListenForEvent("onremove", function()
        self:StopUpdating()
    end)
    self:Refresh()
end)

-- 官方每帧钩子：总开关开时给宝石跑色相循环（1.6s 一圈）
function HcaneGemStatus:OnUpdate(dt)
    if not self._multi or self._key == nil then return end
    if self.gem == nil or not self.gem:IsVisible() then return end
    self._hue_time = self._hue_time + dt
    local h = self._hue_time * 2 * math.pi / 1.6
    local r = (math.sin(h) + 1) / 2
    local g = (math.sin(h + 2.094) + 1) / 2
    local b = (math.sin(h + 4.189) + 1) / 2
    self.gem:SetTint(r * 0.4 + 0.6, g * 0.4 + 0.6, b * 0.4 + 0.6, 1)
    self.glow:SetTint(r, g, b, 1)
end

function HcaneGemStatus:Refresh()
    local key = self._key
    local tex = key ~= nil and GEM_VIEW[key] or nil
    local on = self._multi == true

    if tex ~= nil then
        local atlas = (GetInventoryItemAtlas ~= nil and GetInventoryItemAtlas(tex))
            or "images/inventoryimages1.xml"
        self.gem:SetTexture(atlas, tex)
        self.glow:SetTexture(atlas, tex)
        self.gem:Show()
        -- 关=亮起（重置白）；开=炫彩由 OnUpdate 接管
        if on then
            self.glow:Show()
        else
            self.gem:SetTint(1, 1, 1, 1)
            self.glow:Hide()
        end
        self.state:Hide()
    else
        self.gem:Hide()
        self.glow:Hide()
        if self.corner_mode then
            -- 角标留空（开关状态由格子下方字形+文字显示）
            self.state:Hide()
        else
            -- 原中心 UI：鬼魂=关 / 灯泡=开（显示当前状态）
            self.state:SetString(on and GLYPH_LIGHT_ON or GLYPH_LIGHT_OFF)
            self.state:SetColour(1, on and 1 or 0.95, on and 0.75 or 0.95, 1)
            self.state:Show()
        end
    end
end

function HcaneGemStatus:SetGem(key)
    if self._key == key then return end
    self._key = key
    self._hue_time = 0
    self:Refresh()
end

function HcaneGemStatus:SetMulti(on)
    on = (on == true)
    if self._multi == on then return end
    self._multi = on
    self._hue_time = 0
    self:Refresh()
end

return HcaneGemStatus
