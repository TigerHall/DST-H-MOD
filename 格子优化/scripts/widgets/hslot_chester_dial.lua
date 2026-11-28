-- 切斯特月眼轮盘（A 版：点击宝石 → 直接开关对应口袋空间）
-- 复用【切斯特实体动画】bank=chester build=chester_build（不是容器 UI 背景 ui_chester_*）：
--   待机 idle_loop（循环呼吸）→ 点击张嘴 open → idle_loop_open → 关闭 closed → idle_loop。
--   拖动切 walk_loop；未打开时跑马灯炫彩，打开张嘴时停（手杖同款）。
--   hover 切斯特/宝石放大 + 宝石往外弹（吸附感，官方 Wheel 的 focus_pos 思路）。
--   ⚠️ hover 绝不用 SetModFocus 防穿透——那会让 PlayerController:IsEnabled() 变 false，
--      连 WASD 移动一起禁掉。改由 modmain 的 PlayerController:OnControl hook 只吞左右键。
-- 交互全走 TheInput 坐标判定（4K 下 ImageButton 焦点不可靠），照搬本 mod 大容器方案。

local Widget = require("widgets/widget")
local Image = require("widgets/image")
local UIAnim = require("widgets/uianim")

local CHESTER_BANK = "chester"
local CHESTER_BUILD = "chester_build"

-- ===== 位置记忆（客户端本地存盘，照搬 hslot_vault_list）=====
local DIAL_POS_SAVE_KEY = "hslot_chester_dial_pos"
local saved_dial_pos = nil
local saved_dial_pos_loaded = false
local active_dial = nil   -- 当前 dial 实例（异步读盘回来时应用位置）

local function LoadDialPos()
    if saved_dial_pos_loaded then return saved_dial_pos end
    saved_dial_pos_loaded = true
    TheSim:GetPersistentString(DIAL_POS_SAVE_KEY, function(ok, data)
        if not ok or data == nil or data == "" then return end
        local sx, sy = string.match(data, "([%-%d%.]+),([%-%d%.]+)")
        if sx == nil or sy == nil then return end
        saved_dial_pos = Vector3(tonumber(sx), tonumber(sy), 0)
        -- 读盘回调时才把值应用上去（widget 可能已经建好）
        if active_dial ~= nil and active_dial.inst ~= nil and active_dial.inst:IsValid() then
            active_dial:SetPosition(saved_dial_pos)
            active_dial:UpdateFacing()
        end
    end)
    return saved_dial_pos
end

local function SaveDialPos(self)
    local p = self:GetPosition()
    saved_dial_pos = Vector3(p.x, p.y, 0)
    TheSim:SetPersistentString(DIAL_POS_SAVE_KEY,
        string.format("%.2f,%.2f", p.x, p.y), false)
end

-- ⭐ 2026-11-23 顺序=角度：ang = 90° - (i-1)*60°
--   i=1 正上=绿 / i=2 右上=紫 / i=3 右下=黄 / i=4 正下=红 / i=5 左下=橙 / i=6 左上=蓝
--   绿上红下，四色按四象限（与 hslot_vault_list 的面板象限一致：蓝左上/紫右上/橙左下/黄右下）。
local GEMS = {
    { key = "rabbitkinghorn", tex = "greenmooneye.tex",  label = "绿月眼（兔洞）空间" }, -- 正上
    { key = "purple_fish",    tex = "purplemooneye.tex", label = "紫月眼空间" },          -- 右上
    { key = "yellow_fish",    tex = "yellowmooneye.tex", label = "黄月眼空间" },          -- 右下
    { key = "shadow",         tex = "redmooneye.tex",    label = "红月眼（暗影）空间" },  -- 正下
    { key = "orange_fish",    tex = "orangemooneye.tex", label = "橙月眼空间" },          -- 左下
    { key = "hslot",          tex = "bluemooneye.tex",   label = "蓝月眼空间" },          -- 左上
}

local CHESTER_SCALE = 0.28
local GEM_SCALE = 0.72              -- 月眼再放大（原 0.48）
local RADIUS = 70               -- 轮盘半径（宝石离远一点，原 44 → 58 → 70）
local CHESTER_CY = 22              -- 切斯特上移 1/4 个月眼图标（64×0.72/4≈12px）：10+12=22；tooltip 共用此值
local GEM_OFFSET_Y = 44         -- 整圈宝石上移（原 30，再上移一些）
local CHESTER_RADIUS = 52     -- 以月眼圆心为准的内圈半径=切斯特开关范围（月眼在 RADIUS=70 处，留余量）
local DIAL_RADIUS = 132       -- 整个轮盘区域的命中半径（含宝石+空白，抑制穿透）

local HOVER_CHESTER_SCALE = 1.15   -- 鼠标放切斯特上放大倍数
local HOVER_GEM_SCALE = 1.3        -- 宝石悬停放大倍数
local GEM_FOCUS_OUT = 10           -- 宝石悬停往外弹（吸附感，像素）

-- 切斯特自己的张嘴/闭嘴音效（官方 prefabs/chester.lua:54-55 SOUNDS.open / SOUNDS.close）
local SOUND_OPEN = "dontstarve/creatures/chester/open"
local SOUND_CLOSE = "dontstarve/creatures/chester/close"
-- 鼠标示意图标（官方 strings.lua:1235-1237 / hslot_vault_list.lua:143）
local ICON_MOUSE_LEFT = "\238\132\128"
local ICON_MOUSE_RIGHT = "\238\132\129"
local ICON_MOUSE_MIDDLE = "\238\132\130"

local function play_chester_sound(path)
    -- 用本地玩家实体的 SoundEmitter（前端 SoundEmitter 对部分音效静默失败）
    local player = ThePlayer
    if player ~= nil and player:IsValid() and player.SoundEmitter ~= nil then
        player.SoundEmitter:PlaySound(path)
    end
end

local COLOR_CYCLE_SPEED = 1.6
local BREATH_SPEED = 1.2
local BREATH_INTENSITY = 0.6
local function HueToRGB(hue)
    return (math.sin(hue) + 1) / 2,
           (math.sin(hue + 2.094) + 1) / 2,
           (math.sin(hue + 4.189) + 1) / 2
end

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

local ChesterDial = Class(Widget, function(self, on_gem_click, unlock_enabled, on_gem_unlock, on_scan)
    Widget._ctor(self, "hslot_chester_dial")
    self.on_gem_click = on_gem_click
    self.on_gem_unlock = on_gem_unlock        -- 未解锁点击 → 发 unlock RPC
    self.on_scan = on_scan                    -- ⭐ 4.6.2：打开/关闭轮盘 → 请求后台扫描解锁（静默）
    self.unlock_enabled = (unlock_enabled == true)
    self._unlocked = {}                        -- [key]=true，服务端 netvar 同步过来
    self.is_open = false
    self._gem_buttons = {}
    self._gem_base_pos = {}
    self._world_scale = nil
    self._drag_button = nil
    self._rainbow_time = 0
    self._hover_kind = nil        -- "chester" / "gem" / "dial" / nil
    self._hover_gem = 0
    self._hovering = false        -- 鼠标是否在切斯特本体上（睡眠/清醒判定）
    self._facing = 1              -- 1=朝右（默认），-1=朝左（镜像）；始终朝向屏幕中心

    -- 切斯特动画：默认睡眠（鼠标没放上去），睡眠动画 sleep_loop 循环
    self.chester_anim = self:AddChild(UIAnim())
    self.chester_anim:GetAnimState():SetBank(CHESTER_BANK)
    self.chester_anim:GetAnimState():SetBuild(CHESTER_BUILD)
    self.chester_anim:GetAnimState():PlayAnimation("sleep_loop", true)
    self.chester_anim:SetScale(CHESTER_SCALE)
    self.chester_anim:SetPosition(0, CHESTER_CY)
    self.chester_anim:SetClickable(false)

    -- 悬停提示：带饥荒鼠标图标的官方 tooltip（照搬蓝眼空间 hslot_vault_list.lua:446-454）
    -- 用几乎全透明的抓取层只负责显示 tooltip；点击/拖动仍走坐标判定，不依赖这层。
    self.tooltip = self:AddChild(Image("images/global.xml", "square.tex"))
    -- 提示区只覆盖切斯特图标本体（不覆盖宝石）：鼠标在宝石上时不显示这三条提示
    self.tooltip:SetSize(50, 50)            -- 响应区再缩小（原 70）
    self.tooltip:SetPosition(0, CHESTER_CY) -- 提示区往上对齐切斯特视觉中心
    self.tooltip:SetTint(1, 1, 1, 0.001)   -- 肉眼不可见
    self.tooltip:SetClickable(true)
    self.tooltip:SetTooltip(ICON_MOUSE_LEFT .. " 打开\n" .. ICON_MOUSE_RIGHT .. " 移动\n" .. ICON_MOUSE_MIDDLE .. " 复原")

    -- 轮盘：六个宝石
    self.wheel = self:AddChild(Widget("hslot_chester_wheel"))
    self.wheel:SetClickable(false)
    for i, gem in ipairs(GEMS) do
        local ang = math.pi / 2 - (i - 1) * (math.pi / 3)
        local dx, dy = math.cos(ang), math.sin(ang)
        local x = dx * RADIUS
        local y = dy * RADIUS + GEM_OFFSET_Y
        local atlas = GetInventoryItemAtlas(gem.tex) or "images/inventoryimages1.xml"
        local img = self.wheel:AddChild(Image(atlas, gem.tex))
        img:SetScale(GEM_SCALE)
        img:SetPosition(x, y)
        img:SetClickable(false)
        -- 本体保持原色 1.0（不再压暗），发光交给下面的 additive glow 层
        -- ⭐ 发光层：同贴图 + Additive 混合 + 彩色呼吸 tint，选中时显示 → 真正提亮（SetTint>1 会被 clamp）
        local glow = img:AddChild(Image(atlas, gem.tex))
        glow:SetBlendMode(BLENDMODE.Additive)
        glow:SetTint(1, 1, 1, 1)
        glow:SetClickable(false)
        glow:Hide()
        img._glow = glow
        -- ⭐ 第二层：白色作祟光（模拟手杖 SetHaunted 的幽灵白光闪烁）。
        --    月眼贴图本身深色，只叠彩色不明显；白色 additive 层把整体提亮，彩色再叠上去。
        local whiteglow = img:AddChild(Image(atlas, gem.tex))
        whiteglow:SetBlendMode(BLENDMODE.Additive)
        whiteglow:SetTint(1, 1, 1, 1)
        whiteglow:SetClickable(false)
        whiteglow:Hide()
        img._whiteglow = whiteglow
        self._gem_buttons[i] = img
        self._gem_base_pos[i] = { x = x, y = y, dx = dx, dy = dy }
    end
    self.wheel:Hide()

    local function to_local(x, y)
        if self._world_scale == nil then self._world_scale = refresh_world_scale(self) end
        local w = self:GetWorldPosition()
        local s = self._world_scale
        return (x - w.x) * s.x, (y - w.y) * s.y
    end

    -- ⭐ 以【六色月眼为基准圆】：所有命中都以轮盘圆心 (0, GEM_OFFSET_Y) 为原点算距离，
    --    内圈=切斯特（开关），外圈扇区=月眼。两者同心 → 底部扇区不再错位。
    local function hit_test(x, y)
        local lx, ly = to_local(x, y)
        local dx, dy = lx, ly - GEM_OFFSET_Y       -- 相对轮盘圆心的偏移
        local dist2 = dx * dx + dy * dy
        local inner2 = CHESTER_RADIUS * CHESTER_RADIUS

        -- 内圈：切斯特的左键打开/关闭范围（同心圆，覆盖偏下的切斯特本体）
        if dist2 <= inner2 then
            return "chester"
        end
        if self.is_open then
            -- 外圈：月眼选中区 = 正六边形扇区（官方 Wheel 思路），按角度分 6 份。
            -- 宝石 i 角度 = π/2 - (i-1)*π/3（正上方起顺时针）。
            if dist2 <= DIAL_RADIUS * DIAL_RADIUS then
                local ang = math.atan2(dy, dx)
                local rel = math.pi / 2 - ang
                if rel < 0 then rel = rel + 2 * math.pi end
                local sector = math.floor(rel / (math.pi / 3) + 0.5) % 6 + 1
                return "gem", sector
            end
        end
        return nil
    end
    -- 暴露给 modmain 的 PlayerController:OnControl hook：只吞鼠标点击，不动键盘移动。
    self._hit_test = hit_test

    -- hover 放大/吸附：切斯特放大，宝石放大 + 往外弹
    local function apply_hover(kind, idx)
        if self._hover_kind == kind and self._hover_gem == idx then return end
        self._hover_kind, self._hover_gem = kind, idx
        -- 鼠标是否放在切斯特本体上（睡眠/清醒切换）
        local was_hovering = self._hovering
        self._hovering = (kind == "chester")
        if was_hovering ~= self._hovering then self:SyncAnim() end
        -- 切斯特 hover 放大（含朝向镜像）
        self:ApplyChesterScale()
        -- 宝石：全部复位；只有【已解锁】的悬停项才放大+外弹+呼吸（未解锁保持灰黑静止）
        for i, img in ipairs(self._gem_buttons) do
            local base = self._gem_base_pos[i]
            local unlocked = self:IsGemUnlocked(i)
            if kind == "gem" and i == idx and unlocked then
                img:SetScale(GEM_SCALE * HOVER_GEM_SCALE)
                img:SetPosition(base.x + base.dx * GEM_FOCUS_OUT,
                                base.y + base.dy * GEM_FOCUS_OUT)
                self:StartGemBreath(img)   -- 已解锁月眼：呼吸灯
            else
                img:SetScale(GEM_SCALE)
                img:SetPosition(base.x, base.y)
                if self._gem_breath_img == img then self:StopGemBreath() end
            end
        end
        if kind ~= "gem" then self:StopGemBreath() end
    end

    self._hover_handler = TheInput:AddMoveHandler(function(x, y)
        if not self:IsVisible() then
            apply_hover(nil, 0)
            return
        end
        local hit, idx = hit_test(x, y)
        apply_hover(hit, idx or 0)
    end)

    self._mousebtn = TheInput:AddMouseButtonHandler(function(button, down, x, y)
        if not self:IsVisible() then return end
        if button == MOUSEBUTTON_MIDDLE and down then
            self:ResetToDefaultPos()   -- 中键复原（任何位置都响应）
            return
        end
        local hit, idx = hit_test(x, y)
        if button == MOUSEBUTTON_LEFT then
            if down then
                if hit == "gem" then
                    self:_OnGem(idx)
                elseif hit == "chester" then
                    self._left_down_on_chester = true
                end
            else
                if self._left_down_on_chester and hit == "chester" then self:Toggle() end
                self._left_down_on_chester = false
            end
        elseif button == MOUSEBUTTON_RIGHT then
            if down then
                -- 右键在月眼上：和左键一样打开对应空间；在切斯特/轮盘空白区：拖动
                if hit == "gem" then
                    self:_OnGem(idx)
                elseif hit == "chester" or hit == "dial" then
                    self:StartDrag(button)
                end
            elseif self._drag_button == button then
                self:EndDrag()
            end
        end
    end)

    -- ⭐ 解锁状态刷新：widget 直接监听【自己 classified】的 netvar dirty，链路最短最可靠。
    --    不再经 modmain 的 ThePlayer 中转（那个判断在客户端引用不一致时会永远跳过）。
    if self.unlock_enabled then
        self:_BindUnlockListener()
    end

    -- 位置记忆：注册实例 + 应用已存位置（GetPersistentString 回调同步）。
    -- ⚠️ 默认定位也放这里统一处理——modmain 不能再 SetPosition，否则会覆盖存档位置！
    active_dial = self
    local cached_pos = LoadDialPos()
    self:SetPosition(cached_pos ~= nil and cached_pos or self:DefaultPos())

    -- ⚠️ 不要在构造里调 UpdateFacing：此时 dial 还没 AddChild/SetPosition，
    --    GetWorldPosition 是错的。朝向改到 OnShow 里判断（每次显示都重新算）。
    self:StartRainbow()   -- 初始睡眠态也跑马灯（用户要求睡眠也有炫彩）

    self.inst:ListenForEvent("onremove", function()
        if active_dial == self then active_dial = nil end
        self:StopRainbow()
        self:StopGemBreath()
        if self._hover_handler then self._hover_handler:Remove(); self._hover_handler = nil end
        if self._mousebtn then self._mousebtn:Remove(); self._mousebtn = nil end
        self:EndDrag()
    end)
end)

-- ===== 位置：默认位置 + 中键复原 + 出屏回位（照搬 hslot_vault_list）=====
function ChesterDial:DefaultPos()
    return Vector3(-154, 110, 0)   -- 与 modmain 一致：对齐 Insight 按钮(-154,40)的 x，放其上方
end

function ChesterDial:ResetToDefaultPos()
    local p = self:DefaultPos()
    self:SetPosition(p)
    self:UpdateFacing()
    SaveDialPos(self)   -- 复位后也记住（下次进来还是复位位置）
end

function ChesterDial:IsCenterOffScreen()
    local w = self:GetWorldPosition()
    local sw, sh = TheSim:GetScreenSize()
    local margin = 20
    return w.x < -margin or w.x > sw + margin
        or w.y < -margin or w.y > sh + margin
end

-- ===== 朝向：切斯特始终面向屏幕中心（右半屏朝左，左半屏朝右）=====
-- 用镜像 scale 实现（切斯特动画只有一侧视图），只翻子动画层，不动 root scale（world_scale 测量不受影响）。
function ChesterDial:UpdateFacing()
    local w = self:GetWorldPosition()
    local sw = TheSim:GetScreenSize()
    -- 在屏幕右半边 → 朝左（镜像）；左半边 → 朝右（默认）
    self._facing = (w.x > sw * 0.5) and -1 or 1
    self:ApplyChesterScale()
end

function ChesterDial:ApplyChesterScale()
    local hover = self._hovering and HOVER_CHESTER_SCALE or 1
    local s = CHESTER_SCALE * hover
    self.chester_anim:SetScale(s * self._facing, s, 1)
end

-- ⭐ 每次显示（初次创建 / H 键呼出 / 复活恢复）都重新判断朝向。
--    Widget:Show() 会无条件调 OnShow（widget.lua:322），此时位置已设好，GetWorldPosition 正确。
function ChesterDial:OnShow(was_hidden)
    self._base.OnShow(self, was_hidden)   -- 官方写法（pethungerbadge.lua:19）
    self:UpdateFacing()
    self:RefreshGemVisual()               -- 每次显示刷新解锁外观（存档可能刚同步到）
end

-- ===== 月眼解锁状态（服务端 netvar → 本地 _unlocked）=====
local GEM_LOCKED_TINT = 0.35   -- 未解锁灰黑

function ChesterDial:IsGemUnlocked(i)
    if not self.unlock_enabled then return true end   -- 配置关=全解锁
    return self._unlocked[GEMS[i].key] == true
end

function ChesterDial:SetUnlockState(unlocked_table)
    self._unlocked = unlocked_table or {}
    self:RefreshGemVisual()
end

-- 从本地 player_classified 的 netvar 主动重读解锁状态。
-- 用途：构造时读一次 + 每次点击月眼前兜底重读（防事件监听时序遗漏导致的状态不同步死循环）。
function ChesterDial:RefreshUnlockFromNetvar()
    if not self.unlock_enabled then return end
    local owner = ThePlayer
    local classified = owner ~= nil and owner.player_classified or nil
    if classified == nil or classified._hslot_unlock == nil then return end
    local s = classified._hslot_unlock:value()
    local unlocked = {}
    if s ~= nil and s ~= "" then
        for k in s:gmatch("([^,]+)") do unlocked[k] = true end
    end
    self:SetUnlockState(unlocked)
end

-- 直接监听本地玩家 classified 的 netvar dirty（不经 ThePlayer 事件中转）。
-- classified 可能在 widget 构造时还没关联 → 延迟重试。
function ChesterDial:_BindUnlockListener()
    local owner = ThePlayer
    local classified = owner ~= nil and owner.player_classified or nil
    if classified == nil or classified._hslot_unlock == nil then
        self.inst:DoTaskInTime(0.2, function()
            if self.inst ~= nil and self.inst:IsValid() then self:_BindUnlockListener() end
        end)
        return
    end
    if self._unlock_listener_bound then return end
    self._unlock_listener_bound = true
    -- 只监听本地玩家的 classified（天然不串号），dirty 时直接重读 netvar 刷新
    self.inst:ListenForEvent("hslotUnlockDirty", function()
        self:RefreshUnlockFromNetvar()
    end, classified)
    self:RefreshUnlockFromNetvar()   -- 绑定后立即读一次（存档可能已同步好）
end

-- 统一刷新 6 个月眼外观：未解锁=灰黑+隐藏发光+不放大；已解锁=原色+正常
function ChesterDial:RefreshGemVisual()
    for i, img in ipairs(self._gem_buttons) do
        local unlocked = self:IsGemUnlocked(i)
        local base = self._gem_base_pos[i]
        if unlocked then
            img:SetTint(1, 1, 1, 1)
        else
            img:SetTint(GEM_LOCKED_TINT, GEM_LOCKED_TINT, GEM_LOCKED_TINT, 1)
            -- 未解锁：清掉可能的 hover 发光/放大/位移
            if img._glow ~= nil then img._glow:Hide() end
            if img._whiteglow ~= nil then img._whiteglow:Hide() end
            img:SetScale(GEM_SCALE)
            img:SetPosition(base.x, base.y)
        end
    end
    if self._gem_breath_img ~= nil then
        local idx = nil
        for i, img in ipairs(self._gem_buttons) do
            if img == self._gem_breath_img then idx = i break end
        end
        if idx ~= nil and not self:IsGemUnlocked(idx) then self:StopGemBreath() end
    end
end

-- ===== 动画状态机：根据 睡眠/清醒/打开/拖动 切动画 =====
-- 鼠标没放切斯特上 → 睡眠 sleep_loop；放上 → 清醒待机 idle_loop；
-- 打开 → idle_loop_open；拖动 → walk_loop（StartDrag 单独切，松手调 SyncAnim 回来）。
function ChesterDial:SyncAnim()
    if self._drag_button ~= nil then return end  -- 拖动中不打断
    local a = self.chester_anim:GetAnimState()
    if self.is_open then
        a:PlayAnimation("idle_loop_open", true)
    elseif self._hovering then
        a:PlayAnimation("idle_loop", true)        -- 鼠标放上：清醒待机
    else
        a:PlayAnimation("sleep_loop", true)       -- 鼠标移走：睡眠
    end
    -- 炫彩：只在打开时停（PlayOpen 里 Stop），睡眠/清醒都保持（用户要求睡眠也有炫彩）
end

-- ===== 跑马灯炫彩（UIAnim 走 AnimState，SetAddColour 有效）=====
function ChesterDial:StartRainbow()
    if self._rainbow_task ~= nil then return end
    self._rainbow_time = 0
    self._rainbow_task = self.inst:DoPeriodicTask(0.05, function()
        if not self.inst:IsValid() then return end
        self._rainbow_time = self._rainbow_time + 0.05
        local phase = (math.sin(self._rainbow_time * 2 * math.pi / BREATH_SPEED) + 1) / 2
        local intensity = phase * BREATH_INTENSITY
        local hue = self._rainbow_time * 2 * math.pi / COLOR_CYCLE_SPEED
        local cr, cg, cb = HueToRGB(hue)
        self.chester_anim:GetAnimState():SetAddColour(cr * intensity, cg * intensity, cb * intensity, 0)
    end)
end

function ChesterDial:StopRainbow()
    if self._rainbow_task ~= nil then
        self._rainbow_task:Cancel()
        self._rainbow_task = nil
    end
    self.chester_anim:GetAnimState():SetAddColour(0, 0, 0, 0)
end

-- ===== 选中月眼的呼吸灯：Additive 发光层（SetTint 乘法>1 会被 clamp，靠叠加层才够亮）=====
local GEM_GLOW_MIN = 0.6    -- 发光强度下限（呼吸暗相，仍明显发光）
local GEM_GLOW_MAX = 1.0    -- 发光强度上限
function ChesterDial:StartGemBreath(img)
    self:StopGemBreath()
    self._gem_breath_img = img
    self._gem_breath_time = 0
    local glow = img._glow
    local whiteglow = img._whiteglow
    if glow ~= nil then glow:Show() end
    if whiteglow ~= nil then whiteglow:Show() end
    self._gem_breath_task = self.inst:DoPeriodicTask(0.05, function()
        if not self.inst:IsValid() or self._gem_breath_img == nil then return end
        self._gem_breath_time = self._gem_breath_time + 0.05
        local t = self._gem_breath_time
        -- 彩色层：跑马灯彩色 × 强度（加亮下限）
        local phase = (math.sin(t * 2 * math.pi / BREATH_SPEED) + 1) / 2
        local intensity = GEM_GLOW_MIN + (GEM_GLOW_MAX - GEM_GLOW_MIN) * phase
        local hue = t * 2 * math.pi / COLOR_CYCLE_SPEED
        local cr, cg, cb = HueToRGB(hue)
        if glow ~= nil then glow:SetTint(cr * intensity, cg * intensity, cb * intensity, 1) end
        -- 白色作祟层：模拟手杖 SetHaunted 的幽灵白光，用较快频率闪烁，把深色月眼整体提亮
        if whiteglow ~= nil then
            local w = (math.sin(t * 2 * math.pi / 0.9) + 1) / 2   -- 0.9s 周期闪烁
            local wi = 0.25 + 0.35 * w                             -- 0.25~0.60 白光强度
            whiteglow:SetTint(wi, wi, wi, 1)
        end
    end)
end

function ChesterDial:StopGemBreath()
    if self._gem_breath_task ~= nil then
        self._gem_breath_task:Cancel()
        self._gem_breath_task = nil
    end
    if self._gem_breath_img ~= nil then
        if self._gem_breath_img._glow ~= nil then self._gem_breath_img._glow:Hide() end
        if self._gem_breath_img._whiteglow ~= nil then self._gem_breath_img._whiteglow:Hide() end
        self._gem_breath_img = nil
    end
end

-- ===== 拖动（起始快照法）+ 松手出屏回位 =====
function ChesterDial:StartDrag(button)
    if self._draghandler ~= nil then return end
    if self._world_scale == nil then self._world_scale = refresh_world_scale(self) end
    self._drag_button = button or MOUSEBUTTON_RIGHT
    self.chester_anim:GetAnimState():PlayAnimation("walk_loop", true)
    local m = TheInput:GetScreenPosition()
    self._m_start = Vector3(m.x, m.y, 0)
    local p = self:GetPosition()
    self._p_start = Vector3(p.x, p.y, p.z)
    self._draghandler = TheInput:AddMoveHandler(function(x, y)
        if not TheInput:IsMouseDown(self._drag_button) then
            self:EndDrag()
            return
        end
        local s = self._world_scale
        self:SetPosition(
            self._p_start.x + (x - self._m_start.x) * s.x,
            self._p_start.y + (y - self._m_start.y) * s.y,
            0
        )
        self:UpdateFacing()   -- 拖动跨过屏幕中线时实时转身
    end)
end

function ChesterDial:EndDrag()
    if self._draghandler then
        self._draghandler:Remove()
        self._draghandler = nil
    end
    if self._drag_button ~= nil then
        self._drag_button = nil
        -- 出画面回默认位置（拖到屏幕外不合法）
        if self:IsCenterOffScreen() then
            self:ResetToDefaultPos()   -- 内部会保存位置
        else
            SaveDialPos(self)          -- 记住这次拖到的位置
        end
        -- 松手按当前状态回动画（打开→张嘴待机 / hover→清醒 / 否则→睡眠）
        self:SyncAnim()
    end
end

function ChesterDial:_OnGem(idx)
    local key = GEMS[idx].key
    -- ⭐ 兜底：点击前主动重读 netvar，纠正可能的状态不同步（服务端已解锁但本地还以为没解锁
    --    → 会一直发 unlock RPC 死循环，既不打开格子也不提示）
    self:RefreshUnlockFromNetvar()
    if not self:IsGemUnlocked(idx) then
        -- 未解锁：发 RPC 请求扫描解锁（服务端验证持有 → 说话提示或点亮）
        if self.on_gem_unlock then self.on_gem_unlock(key) end
        return
    end
    -- 已解锁：张嘴反馈 + 打开空间（服务端功能锁会再确认一次解锁状态）
    self:PlayOpen()
    if self.on_gem_click then self.on_gem_click(key) end
end

function ChesterDial:PlayOpen()
    local a = self.chester_anim:GetAnimState()
    a:PlayAnimation("open")
    a:PushAnimation("idle_loop_open", true)
    self:StopRainbow()    -- 张嘴（打开态）停炫彩
end

function ChesterDial:Toggle()
    if self.is_open then self:Close() else self:Open() end
end

function ChesterDial:Open()
    self.is_open = true
    self:PlayOpen()
    play_chester_sound(SOUND_OPEN)   -- 张开嘴：切斯特 open 声效
    self.wheel:Show()
    -- ⭐ 4.6.2：打开轮盘时后台扫描解锁（彩虹全解锁 + 逐月眼），开销小、静默不刷屏
    if self.on_scan then self.on_scan() end
end

function ChesterDial:Close()
    self.is_open = false
    play_chester_sound(SOUND_CLOSE)  -- 闭上嘴：切斯特 close 声效
    self.chester_anim:GetAnimState():PlayAnimation("closed")  -- 闭嘴动作（一次性）
    self:StartRainbow()   -- 关闭后恢复炫彩（睡眠/清醒都开）
    self.wheel:Hide()
    -- ⭐ 4.6.2：关闭轮盘时也扫一次（兜底：开轮盘期间才捡到彩虹物品的情况）
    if self.on_scan then self.on_scan() end
    -- 闭嘴动画放完（~0.6s）后按当前状态回睡眠或清醒待机
    self.inst:DoTaskInTime(0.6, function()
        if self.inst:IsValid() then self:SyncAnim() end
    end)
end

-- 供 PlayerController:OnControl hook 查询：鼠标是否落在轮盘上（命中类型, 月眼序号）。
function ChesterDial:HitTest(x, y)
    if self._hit_test == nil then return nil end
    return self._hit_test(x, y)
end

return ChesterDial
