-- H-手杖七项宝石轮盘（6 宝石 + 1「鬼魂/灯泡」总开关）
-- ⭐ 5.6.26：tooltip 一律只留左键图标；提示热区缩到单个图标略小；
--   tooltip 随鼠标移到当前 hover 的扇区位置（不再是整圈大热区）。
-- ⭐ 5.6.24：
--   ① 单环半圆半径加大 82→104，命中扇区仍按角度划分（FAN_BOUNDS 不变）；
--   ② 选中/hover 恢复「向外放大」——只放大 scale、位置固定在原半径上；
-- ⭐ 5.6.23：
--   ① 恢复单环半圆（5.6.22 双环视觉乱、角度扇区与图标位置对不上）；
--   ② 修 tooltip：active 变化后即使鼠标不动也重刷，激活态只显示左键图标。
-- ⭐ 5.6.22：解锁差距拉大（未解锁 0.32 暗 / 已解锁满亮+常驻白光 0.3 / 选中·hover 0.8）。
-- ⭐ 5.6.20：
--   ① none 项只显示「目标状态」单字形：当前开→鬼魂（点它变关）、当前关→灯泡（点它变开）；
--      中心状态格显示「当前状态」，轮盘 none 与其相反，二者左键都切同一总开关。
--   ② hover 恢复放大（5.6.19 误删）；tooltip 精简为「左键 点击激活对应宝石」。
--   ③ 未解锁宝石仍显示图标（暗灰）而不是全黑消失。
-- ⭐ 5.6.19：上半圆 7 扇形命中；顺序红蓝紫-none-黄绿橙；四态配色。
-- ⚠️ 不用 SetModFocus（会连 WASD 一起禁掉）；穿透由 modmain 的
--    PlayerController:OnControl hook 只吞鼠标左右键解决，这里只提供 HitTest。
-- 交互全部走 TheInput 坐标判定（4K 下 ImageButton 焦点不可靠）。

local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")

local active_dial = nil

local GLYPH_OFF = "\243\176\128\137"  -- 󰀉 U+F0009 鬼魂 = 关
local GLYPH_ON  = "\243\176\128\143"  -- 󰀏 U+F000F 灯泡 = 开

-- i=1 正左(180°) → i=4 正上(90°) → i=7 正右(0°)
-- 从左到右：红、蓝、紫、鬼魂/灯泡、黄、绿、橙
-- ⭐ 5.6.24：5.6.22 交错双环视觉乱、角度扇区与图标位置对不上 → 单环半圆；
--   半径 82→104 让 7 项间距更宽松，hover 恢复向外放大（只放大不改位置）。
local GEMS = {
    { key = "red",    tex = "redgem.tex",    name = "红宝石", short = "点燃", enabled = true,
      label = "红宝石 · 火弹点燃", glow = { 1, 0.25, 0.25 } },
    { key = "blue",   tex = "bluegem.tex",   name = "蓝宝石", short = "冰冻", enabled = true,
      label = "蓝宝石 · 冰弹冰冻 / 右键熄灭", glow = { 0.3, 0.6, 1 } },
    { key = "purple", tex = "purplegem.tex", name = "紫宝石", short = "传送", enabled = true,
      label = "紫宝石 · 传送 / 落雷", glow = { 0.65, 0.3, 0.8 } },
    { key = "none",   name = "总开关", short = "鬼魂/灯泡", enabled = true, none = true,
      label = "鬼魂=关 · 灯泡=开（左键切换多功能）", glow = { 1, 1, 0.85 },
      glyph = true },  -- 单字形项：显示点击后的「目标状态」
    { key = "yellow", tex = "yellowgem.tex", name = "黄宝石", short = "照明", enabled = true,
      label = "黄宝石 · 照明", glow = { 0.87, 0.82, 0.27 } },
    { key = "green",  tex = "greengem.tex",  name = "绿宝石", short = "拆解", enabled = true,
      label = "绿宝石 · 拆解（需总开关开）", glow = { 0.25, 1, 0.35 } },
    { key = "orange", tex = "orangegem.tex", name = "橙宝石", short = "闪烁", enabled = true,
      label = "橙宝石 · 闪烁（右键地面传送）", glow = { 1, 0.57, 0 } },
}

local GEM_BY_KEY = {}
for i, gem in ipairs(GEMS) do
    if not gem.none then GEM_BY_KEY[gem.key] = i end
end

local CENTER_RADIUS = 26          -- 中心热区（总开关点击）
local GEM_SCALE = 0.68            -- 整体放大，配合解锁白光更明显
local HOVER_SCALE = 0.9           -- hover 进一步放大
local GEM_RADIUS = 104            -- 5.6.24 单环半圆半径加大（82→104），7 项间距更宽松
local FAN_OUTER_RADIUS = GEM_RADIUS + 40        -- 外边界，覆盖图标且留余量，扇区命中够大
local GLYPH_SIZE = 52             -- none 项单字形字号（只有鬼魂或灯泡）
local TOOLTIP_SIZE = 40           -- 5.6.26：tooltip 热区略小于宝石图标（图标约 43px）

-- 5.6.26：7 扇区均分——图标中心 i=1 正左 180° → i=4 正上 90° → i=7 正右 0°，
--   每档 30°；扇区边界取相邻中心的中点：{165,135,105,75,45,15}。
--   红/橙中心在最左/最右端点，扇区一半（15°）自然超出上半圆到 ly<0，
--   不再人为加宽成 34°（旧版偏大）。索引 1..6 = 前 6 项下边界，其余默认第 7 项（橙）。
local FAN_BOUNDS = { 165, 135, 105, 75, 45, 15 }
local FAN_EDGE_EXTRA = 15            -- 红/橙各允许超出上半圆 15°（即到 deg 195 / 345）
local FAN_LY_MIN = -45               -- ly 门禁放宽到 -45（半径144×sin15°≈37，留余量），
                                     -- 手杖格在中心下方约 100，仍靠角度区间排除

-- ⚠️ Text 继承 Widget（只有 SetColour），Image 才有 SetTint；统一着色入口防崩
local function set_item_tint(img, r, g, b, a)
    if img._is_text then
        img:SetColour(r, g, b, a)
    else
        img:SetTint(r, g, b, a)
    end
end

local function local_control(which)
    if TheInput == nil or TheInput.GetLocalizedControl == nil then return "" end
    local ok, s = pcall(function()
        return TheInput:GetLocalizedControl(TheInput:GetControllerID(), which)
    end)
    return ok and s or ""
end

-- 动态量 HUD world_scale（临时挪 10 单位测差值），命中/定位都靠它
local function refresh_world_scale(widget)
    local p = widget:GetPosition()
    local w0 = widget:GetWorldPosition()
    widget:SetPosition(p.x + 10, p.y + 10, p.z)
    local w1 = widget:GetWorldPosition()
    widget:SetPosition(p)
    local wx, wy = w1.x - w0.x, w1.y - w0.y
    return Vector3(
        (wx ~= 0) and 10 / wx or 1,
        (wy ~= 0) and 10 / wy or 1,
        1
    )
end

-- ⭐ 5.6.28：轮盘只服务装备栏手杖，移除 5.6.27 的 focus GUID 机制——
--   状态直接读玩家级 classified 镜像（永远=装备栏手杖），三个 on_* 回调不带 GUID。
-- ⭐ 5.6.29：新增 on_refresh_state——装备栏手杖 GUID 变化时后台请求服务端重推镜像。
local GemDial = Class(Widget, function(self, unlock_enabled, on_unlock, on_activate, on_toggle_multi, on_refresh_state)
    Widget._ctor(self, "hcane_gem_dial")
    self.unlock_enabled = (unlock_enabled == true)
    self.on_unlock = on_unlock
    self.on_activate = on_activate
    self.on_toggle_multi = on_toggle_multi
    self.on_refresh_state = on_refresh_state
    self._last_hands_guid = nil
    self._unlocked = {}
    self._active = ""
    self._multi_active = false
    self._gem_buttons = {}
    self._gem_base = {}
    self._hover_kind = nil
    self._hover_idx = 0
    self._world_scale = nil
    self._expanded = false
    self._has_cane = false
    self._used_fallback = false
    self._hue_time = 0

    -- 中心不再画手杖图标：视觉由手杖格上的 hcane_gem_status 承担。
    self.wheel = self:AddChild(Widget("hcane_gem_wheel"))
    self.wheel:SetClickable(false)
    for i, gem in ipairs(GEMS) do
        -- 上半圆：i=1 正左(180°) → i=4 正上(90°) → i=7 正右(0°)
        -- 5.6.24 单环半圆：所有项同一半径（加大到 104），视觉与角度扇区一一对应
        local ang = math.pi - (i - 1) * (math.pi / (#GEMS - 1))
        local dx, dy = math.cos(ang), math.sin(ang)
        local x, y = dx * GEM_RADIUS, dy * GEM_RADIUS
        local img
        if gem.none then
            -- 5.6.20：单字形 = 点击后的「目标状态」
            --   当前总开关开 → 显示鬼魂（点它变关）；当前关 → 显示灯泡（点它变开）。
            --   手杖状态格显示「当前状态」，二者语义相反，互相示意可切换。
            img = self.wheel:AddChild(Text(NEWFONT, GLYPH_SIZE, GLYPH_ON))
            img:SetString(GLYPH_ON)
            img:SetClickable(false)
            img._is_text = true
            img._is_none = true
        else
            local atlas = GetInventoryItemAtlas(gem.tex) or "images/inventoryimages1.xml"
            img = self.wheel:AddChild(Image(atlas, gem.tex))
        end
        img:SetScale(GEM_SCALE)
        img:SetPosition(x, y)
        img:SetClickable(false)
        -- 激活发光层：Image 用 Additive；none 用同字形提亮
        local glow
        local c = gem.glow or { 1, 1, 1 }
        if gem.none then
            glow = img:AddChild(Text(NEWFONT, GLYPH_SIZE, GLYPH_ON))
            glow:SetString(GLYPH_ON)
            glow:SetColour(1, 1, 1, 1)
        else
            local atlas = GetInventoryItemAtlas(gem.tex) or "images/inventoryimages1.xml"
            glow = img:AddChild(Image(atlas, gem.tex))
            glow:SetBlendMode(BLENDMODE.Additive)
            glow:SetTint(c[1], c[2], c[3], 1)
        end
        glow:SetClickable(false)
        glow:Hide()
        img._glow = glow
        -- 5.6.21：选中/解锁项的纯白提亮层（Additive 叠在同图上，比纯色 glow 更醒目）
        if not gem.none then
            local atlas = GetInventoryItemAtlas(gem.tex) or "images/inventoryimages1.xml"
            local shine = img:AddChild(Image(atlas, gem.tex))
            shine:SetBlendMode(BLENDMODE.Additive)
            shine:SetTint(0.55, 0.55, 0.55, 1)
            shine:SetClickable(false)
            shine:Hide()
            img._shine = shine
        end
        self._gem_buttons[i] = img
        self._gem_base[i] = { x = x, y = y, dx = dx, dy = dy }
    end
    self.wheel:Hide()

    -- 5.6.26：tooltip 热区缩到单个图标大小，随 hover 的扇区移动到该项位置。
    --   只在鼠标真正悬停某项时显示提示，不再整圈都能触发。
    self.tooltip = self:AddChild(Image("images/global.xml", "square.tex"))
    self.tooltip:SetSize(TOOLTIP_SIZE, TOOLTIP_SIZE)
    self.tooltip:SetTint(1, 1, 1, 0.001)
    self.tooltip:SetClickable(true)
    self.tooltip:SetTooltip(local_control(CONTROL_PRIMARY))
    self.tooltip:Hide()

    local function to_local(x, y)
        if self._world_scale == nil then self._world_scale = refresh_world_scale(self) end
        local w = self:GetWorldPosition()
        local s = self._world_scale
        return (x - w.x) * s.x, (y - w.y) * s.y
    end

    -- ⭐ 5.6.26 扇形命中：7 项均分 180°，边界取相邻中心中点。
    --    红(180°)/橙(0°)各有一半扇区超出上半圆 15°：角度用 345..360 表橙的超出部分、
    --    180..195 表红的超出部分。ly 门禁放宽到 -45，手杖格在下方约 100 单位不吞。
    local function hit_test(x, y)
        if not self._has_cane then return nil end
        local lx, ly = to_local(x, y)
        local c2 = lx * lx + ly * ly
        if c2 <= CENTER_RADIUS * CENTER_RADIUS then return "center" end
        if self._expanded and ly >= FAN_LY_MIN and c2 <= FAN_OUTER_RADIUS * FAN_OUTER_RADIUS then
            local ang = math.atan2(ly, lx)      -- -π..π；0=正右
            local deg = math.deg(ang)
            if deg < 0 then deg = deg + 360 end  -- 0..360，下半圆在 180..360
            local idx = nil
            if deg >= 360 - FAN_EDGE_EXTRA then
                idx = #GEMS                      -- 橙超出上半圆部分（345..360，atan2 负值）
            elseif deg <= 180 + FAN_EDGE_EXTRA then
                -- 上半圆 0..180 + 红超出(180..195)
                for i = 1, #FAN_BOUNDS do
                    if deg >= FAN_BOUNDS[i] then idx = i; break end
                end
                if idx == nil then idx = #GEMS end
            end
            -- 195..345（下半圆深处）：不命中，避免吞手杖格
            if idx ~= nil then return "gem", idx end
        end
        return nil
    end
    self._hit_test = hit_test

    self._hover_handler = TheInput:AddMoveHandler(function(x, y)
        if not self:IsVisible() then
            self:_ApplyHover(nil, 0)
            return
        end
        local kind, idx = hit_test(x, y)
        self:_ApplyHover(kind, idx or 0)
    end)

    -- ⭐ 5.6.21 左键语义：
    --   · 扇形宝石/鬼魂项：第一下 = 切到该项状态（不动总开关）；
    --     已在该状态再点 = 切该状态下的总开关（宝石与鬼魂逻辑一致）。
    --   · 轮盘中心：只切总开关，绝不改法杖状态。
    --   · 右键完全不处理，交给法杖能力。
    self._mousebtn = TheInput:AddMouseButtonHandler(function(button, down, x, y)
        if not self:IsVisible() or button ~= MOUSEBUTTON_LEFT then return end
        local kind, idx = hit_test(x, y)
        if down then
            if kind == "gem" then
                self:_OnGem(idx)
            elseif kind == "center" then
                self._left_down_on_center = true
            end
        else
            if self._left_down_on_center and kind == "center" then
                self:_ToggleCenterOnly()
            end
            self._left_down_on_center = false
        end
    end)

    active_dial = self
    self:ApplyPos()
    -- 官方 frontend.lua:894 每帧调 StartUpdating 注册的 widget:OnUpdate(dt)
    self:StartUpdating()
    self:_BindNetListeners()
    self:RefreshVisual()

    self._cane_check_task = self.inst:DoPeriodicTask(0.5, function()
        if self.inst ~= nil and self.inst:IsValid() then self:_CheckHasCane() end
    end)
    self:_CheckHasCane()

    self.inst:ListenForEvent("onremove", function()
        if active_dial == self then active_dial = nil end
        self:StopUpdating()
        if self._hover_handler then self._hover_handler:Remove(); self._hover_handler = nil end
        if self._mousebtn then self._mousebtn:Remove(); self._mousebtn = nil end
        if self._cane_check_task then self._cane_check_task:Cancel(); self._cane_check_task = nil end
    end)
end)

function GemDial:OnShow(was_hidden)
    self._base.OnShow(self, was_hidden)
    self._world_scale = nil
    self:RefreshStateFromNetvar()
end

function GemDial:DefaultPos()
    return Vector3(-260, 160, 0)
end

function GemDial:ApplyPos()
    local base = self:DefaultPos()
    self:SetPosition(base.x, base.y, 0)
end

-- 每帧跟随手杖格上方的状态图标：controls.hcane_gem_anchor 由 itemtile hook 写入。
function GemDial:OnUpdate(dt)
    local parent = self:GetParent()
    if parent == nil or not self:IsVisible() then return end
    local hud = ThePlayer ~= nil and ThePlayer.HUD or nil
    local controls = hud ~= nil and hud.controls or nil
    local anchor = controls ~= nil and controls.hcane_gem_anchor or nil
    if anchor == nil or anchor.inst == nil or not anchor.inst:IsValid() then
        if not self._used_fallback then
            self._used_fallback = true
            self:ApplyPos()
        end
    else
        self._used_fallback = false
        local p = anchor:GetWorldPosition()
        local pp = parent:GetWorldPosition()
        if self._world_scale == nil then self._world_scale = refresh_world_scale(self) end
        local s = self._world_scale
        self:SetPosition((p.x - pp.x) * s.x, (p.y - pp.y) * s.y, 0)
    end

    -- 炫彩：选中 + 总开关开 → 色相循环（只着色 active 项，不跑全量刷新）
    self._hue_time = self._hue_time + dt
    if self._multi_active and self._active ~= "" then
        local i = GEM_BY_KEY[self._active]
        local img = i ~= nil and self._gem_buttons[i] or nil
        if img ~= nil and not img._is_none then
            local h = self._hue_time * 2 * math.pi / 1.6
            local r = (math.sin(h) + 1) / 2
            local g = (math.sin(h + 2.094) + 1) / 2
            local b = (math.sin(h + 4.189) + 1) / 2
            set_item_tint(img, r * 0.4 + 0.6, g * 0.4 + 0.6, b * 0.4 + 0.6, 1)
        end
    end
end

function GemDial:_SetExpanded(v)
    if self._expanded == v then return end
    self._expanded = v
    if v then self.wheel:Show() else self.wheel:Hide() end
    self:RefreshVisual()
end

function GemDial:_SetHasCane(v)
    if self._has_cane == v then return end
    self._has_cane = v
    if v then
        self:Show()
    else
        self:_SetExpanded(false)
        self:_ApplyHover(nil, 0)
        self:Hide()
    end
end

function GemDial:_CheckHasCane()
    -- ⭐ 5.6.28：只有装备栏手杖可改宝石状态——没装备手杖则整个轮盘隐藏。
    local p = ThePlayer
    local inv = (p ~= nil and p:IsValid()) and p.replica and p.replica.inventory or nil
    local hands = inv ~= nil and inv:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    local is_cane = hands ~= nil and hands.prefab == "cane"
    local guid = is_cane and hands.GUID or nil
    local changed = (guid ~= self._last_hands_guid)
    self._last_hands_guid = guid
    self:_SetHasCane(is_cane)

    -- ⭐ 5.6.29：换手杖 → 后台请求服务端重推镜像；随后两次主动刷新吃掉晚到的 dirty。
    if changed and guid ~= nil then
        if self.on_refresh_state then self.on_refresh_state() end
        for _, delay in ipairs({ 0.15, 0.5 }) do
            self.inst:DoTaskInTime(delay, function()
                if self.inst ~= nil and self.inst:IsValid() then self:RefreshStateFromNetvar() end
            end)
        end
    end
end

function GemDial:_GemUsable(i)
    if GEMS[i].none then return true end
    if not GEMS[i].enabled then return false end
    if not self.unlock_enabled then return true end
    return self._unlocked[GEMS[i].key] == true
end

-- ⭐ 5.6.28：轮盘只服务装备栏手杖，状态直读玩家级 classified 镜像即可
--   （服务端 SyncGemStateToClient 固定推装备栏那把）；移除 5.6.27 的 GUID 焦点/实体监听。
--   物品栏手杖的状态格仍按各自 netvar 显示，但不参与轮盘。
function GemDial:RefreshStateFromNetvar()
    local owner = ThePlayer
    local cls = owner ~= nil and owner.player_classified or nil
    if cls == nil or cls._hcane_gem_unlock == nil then return end
    local s = cls._hcane_gem_unlock:value() or ""
    local unlocked = {}
    for k in s:gmatch("([^,]+)") do unlocked[k] = true end
    self._unlocked = unlocked
    self._active = cls._hcane_gem_active:value() or ""
    if cls._hcane_multi_active ~= nil then
        self._multi_active = cls._hcane_multi_active:value() == true
    end
    self:RefreshVisual()
end

function GemDial:_BindNetListeners()
    if self._net_bound then return end
    local owner = ThePlayer
    local cls = owner ~= nil and owner.player_classified or nil
    if cls == nil or cls._hcane_gem_unlock == nil then
        self._bind_retry = (self._bind_retry or 0) + 1
        if self._bind_retry <= 60 then
            self.inst:DoTaskInTime(0.2, function()
                if self.inst ~= nil and self.inst:IsValid() then self:_BindNetListeners() end
            end)
        end
        return
    end
    self._net_bound = true
    self._cls = cls
    self.inst:ListenForEvent("hcaneGemUnlockDirty", function() self:RefreshStateFromNetvar() end, cls)
    self.inst:ListenForEvent("hcaneGemActiveDirty", function() self:RefreshStateFromNetvar() end, cls)
    if cls._hcane_multi_active ~= nil then
        self.inst:ListenForEvent("hcaneMultiActiveDirty", function() self:RefreshStateFromNetvar() end, cls)
    end
    self:RefreshStateFromNetvar()
end

-- 四态配色：未解锁=暗灰（图标仍可见）/ 未选中=灰 / 选中=亮 / 选中+总开关开=炫彩
function GemDial:RefreshVisual()
    for i, img in ipairs(self._gem_buttons) do
        local gem = GEMS[i]
        local base = self._gem_base[i]
        local usable = self:_GemUsable(i)
        local active = (gem.none and self._active == "")
            or (not gem.none and usable and self._active == gem.key)
        local hovered = (self._hover_kind == "gem" and self._hover_idx == i)

        local r, g, b = 1, 1, 1               -- 5.6.22 已解锁=满亮 + 常驻白光
        if not usable then
            r, g, b = 0.32, 0.32, 0.32        -- 未解锁=暗（0.5→0.32，靠已解锁满亮+白光拉开差距，又不太黑）
        elseif active then
            r, g, b = 1, 1, 1                 -- 选中=亮（炫彩由 OnUpdate 接管）
        end

        if img._is_none then
            -- 5.6.20：单字形 = 点击后的目标状态。
            --   当前开 → 显示鬼魂（示意点击变关）；当前关 → 显示灯泡（示意点击变开）。
            local target = self._multi_active and GLYPH_OFF or GLYPH_ON
            img:SetString(target)
            if img._glow then img._glow:SetString(target) end
            img:SetColour(1, 1, 1, 1)
        else
            set_item_tint(img, r, g, b, 1)
        end

        -- none 项=总开关：发光层跟随 multi_active（开=灯泡亮），不是"有没有选宝石"
        local glow_on = img._is_none and self._multi_active or active
        if glow_on then
            if img._glow then img._glow:Show() end
        else
            if img._glow then img._glow:Hide() end
        end
        -- 5.6.22：已解锁常驻弱白光（0.3）；选中/hover 叠满白光（0.8）；未解锁不叠
        if img._shine then
            if usable then
                local a = (active or hovered) and 0.8 or 0.3
                img._shine:SetTint(a, a, a, 1)
                img._shine:Show()
            else
                img._shine:Hide()
            end
        end
        -- 5.6.24：选中/hover 恢复「向外放大」——只放大 scale，位置固定在原半径；
        --   半径已加大到 104，放大后离手杖格仍有距离；角度扇区命中不受影响。
        local enlarged = hovered or active
        img:SetScale(enlarged and HOVER_SCALE or GEM_SCALE)
        img:SetPosition(base.x, base.y)
    end
    -- 5.6.23：active/unlock 变化后即使鼠标不动也要重刷 tooltip——
    --   否则 hover 位置没变时 _ApplyHover 早退，tooltip 停留在旧的"左键+宝石名"，
    --   看起来像"激活的也显示宝石名"。
    self:_UpdateTooltip(self._hover_kind, self._hover_idx)
end

-- 5.6.26：tooltip 一律只有一个左键图标（未激活不再附 prefab 代码）。
--   热区缩到图标大小并移动到当前 hover 项，只有真正悬停某项才显示。
function GemDial:_UpdateTooltip(kind, idx)
    if self.tooltip == nil then return end
    self.tooltip:SetTooltip(local_control(CONTROL_PRIMARY))
    if kind == "gem" and self._gem_base[idx] ~= nil then
        local base = self._gem_base[idx]
        self.tooltip:SetPosition(base.x, base.y, 0)
        self.tooltip:Show()
    elseif kind == "center" then
        self.tooltip:SetPosition(0, 0, 0)
        self.tooltip:Show()
    else
        self.tooltip:Hide()
    end
end

function GemDial:_ApplyHover(kind, idx)
    if self._hover_kind == kind and self._hover_idx == idx then return end
    self._hover_kind, self._hover_idx = kind, idx
    self:_SetExpanded(kind ~= nil)
    self:RefreshVisual()   -- 5.6.20：hover 切换立即放大/还原
    self:_UpdateTooltip(kind, idx)
end

-- 5.6.21：轮盘中心 = 只切总开关，绝不改法杖状态
function GemDial:_ToggleCenterOnly()
    if self.on_toggle_multi then self.on_toggle_multi() end
end

-- 5.6.21：Gem/鬼魂统一逻辑。
--   第一下点某项 → 切到该项状态（on_activate，不动总开关）；
--   已在该状态下再点 → 切总开关（toggle_multi）。
--   总开关是独立状态：开的状态下红换蓝仍是开，不受切换影响。
local function state_key(gem)
    return gem.none and "" or gem.key
end

function GemDial:_OnGem(idx)
    local gem = GEMS[idx]
    if not gem.enabled then
        local p = ThePlayer
        if p ~= nil and p:IsValid() and p.components.talker then
            p.components.talker:Say(gem.label)
        end
        return
    end
    self:RefreshStateFromNetvar()
    -- 未解锁宝石：第一下仍是解锁（解锁后再按上面的逻辑）
    if not gem.none and not self:_GemUsable(idx) then
        if self.on_unlock then self.on_unlock(gem.key) end
        return
    end
    local key = state_key(gem)
    if self._active == key then
        -- 已在该状态 → 切该状态下的总开关
        self:_ToggleCenterOnly()
    else
        -- 第一下 → 切到该项状态（鬼魂项 = set_active("none") 清宝石）
        if self.on_activate then self.on_activate(gem.none and "none" or gem.key) end
    end
end

-- 供 modmain 的 PlayerController:OnControl hook 查询命中（只吞鼠标）
function GemDial:HitTest(x, y)
    if self._hit_test == nil then return nil end
    return self._hit_test(x, y)
end

return GemDial
