-- 月眼仓库：蓝色月眼口袋空间的「类制作栏」界面
-- 打开蓝眼空间后弹出：顶部一行数字 + 背包图标，下面官方分类图标筛选，再下面是滚动网格。
-- 容器仍是官方 container，同步/存档/交互全部沿用；每格内嵌官方 InvSlot，
-- 点击、右键、拖入都走原版 ItemSlot 逻辑，不用自己写 RPC。
-- 参考：官方 widgets/redux/craftingmenu_widget.lua 的 MakeFilterButton 写法、
--       「简易存储 3383078008」scripts/widgets/terminalwidget.lua 的图标筛选 + 网格。
-- 图标字形用的是 DST 字体自带的 PUA 图标（见技能 references/dst-icon-glyphs.md）。

local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")
local ImageButton = require("widgets/imagebutton")
local InvSlot = require("widgets/invslot")
local ItemTile = require("widgets/itemtile")
local TrueScrollList = require("widgets/truescrolllist")
local TEMPLATES = require("widgets/redux/templates")

-- ====================================================================
-- 尺寸
-- ====================================================================
-- 一行 10 格（简易存储 3383078008 用的是 15 格，但那是全屏面板；
-- 我们还要给标题/筛选/按钮留地方，10 格是 160 格 ÷ 16 行的整数倍）。
-- 间距 84 是在官方箱子 80 上放大一档，SLOT_SCALE 跟着等比走。
local COLS = 10
local ROWS = 9       -- 可视行数
local EXTRA_ROWS = 1 -- 额外渲染的行数（滚动时从底部滑上来，不会突现）
local CELL = 80      -- 官方箱子槽位间距，SLOT_SCALE 1.0 = 和普通空间同款大小
local SLOT_SCALE = CELL / 80
local GRID_W = COLS * CELL
local GRID_H = ROWS * CELL
local SCROLLBAR_GAP = 18 -- 滚动条离格子区的距离（和格子拉开，别贴着）

-- 左右非对称留白：左边只留避让金边的量，右边包住「滚动条 + 呼吸」
local PAD_L = 6
local PAD_R = 16
local PANEL_W = GRID_W + PAD_L + PAD_R -- = 800 + 48 = 848
local PANEL_H = 908
-- 网格整体左移，让右侧空出的位置刚好包住滚动条
local GRID_CX = -(PAD_R - PAD_L) / 2

-- ⚠️ 关键：面板挂在 controls.containerroot 下，父级已经按 GetHUDScale()
-- （0.6~1.1，再乘分辨率补偿）缩过一遍，所以整块 UI 比「简易存储」小一圈 ——
-- 9-slice 的金边是固定像素厚度，被父级缩完就显得很细，文字/按钮同理。
-- 这里补一档自身缩放，把有效缩放拉回接近 1.0，金边厚度和整体观感才对得上。
-- 想再大/再小只改这一个数。
local PANEL_SCALE = 1.25
-- 默认位置：左上角，紧贴折叠制作栏右侧。
-- 两个偏移量的单位是**屏幕像素**（不是父级局部单位），换分辨率/改 HUD 缩放都不漂。
-- 嫌贴得太近就加 DEFAULT_LEFT_OFFSET，嫌远就减。
local DEFAULT_LEFT_OFFSET = 360
local DEFAULT_TOP_OFFSET = 660

-- ⚠️ 垂直排布按「金边」卡死：
--   金边下沿 → 筛选按钮 → 滚动列表 → 数字信息 → 两个按钮
--   → 底部金边
local FILTER_ICON = 76
local FILTER_GAP = 88        -- 选中时按钮放大到 1.15 倍，间距留够别互相压
local FILTER_SCALE_ON = 1.15 -- 选中时整个按钮放大
-- 头部只有一行：左侧筛选图标，右侧「n/N + 红色宝箱命中数」
local FILTER_Y = 406         -- 顶部留白：面板顶 454 - 12 - 36(图标半高)
local GRID_Y = 0             -- 网格顶 360，与筛选底(370)留 10
local BOTTOM_Y = -404        -- 底部按钮，网格底 -360 往上留 12
local BUTTON_W, BUTTON_H = 116, 64
local SORT_X, CLOSE_X = -85, 85
local EDGE = 2 -- 内容离面板左右边缘的距离

-- 底色：#99cc99（153,204,153），直接染在 9-slice 的底上 ——
-- 金边里面整片都是绿底，不会露出原本的黑色内衬。
-- ⚠️ 绿色只有这一层：TEMPLATES.RectangleWindow 的 SetBackgroundTint
-- （templates.lua:1863）只染 mid_left / mid_right / mid_center 三块同一材质，
-- 它们是并排不重叠的；面板上另有一层 alpha 0.001 的 Image，只是用来接
-- tooltip 的不可见抓取层，不参与观感。
-- 想更透就调小这个值（0.15 已经很淡），0 就是全透明只剩金边。
local BG_R, BG_G, BG_B = 0.6, 0.8, 0.6
local FRAME_BG_ALPHA = 0.22

-- 选中分类图标的手杖同款跑马灯（0.05 秒一帧，1.6 秒一圈色相）
local FLASH_STEP = 0.05
local FLASH_SPEED = 1.6

-- 右键拖动是否排除格子区域：
--   false = 整块面板都能按住右键拖（和「UI拖拽缩放」参考 MOD 一致，手感最省事）
--   true  = 格子区不响应（那里的右键留给「查看物品」），只能从四周空白/筛选行/按钮行抓
local DRAG_EXCLUDE_GRID = false

local REFRESH_INTERVAL = 0.12
local POLL_INTERVAL = 0.3

-- 面板由 modmain 挂到 controls.containerroot 下（MIDDLE 锚点 + SCALEMODE_PROPORTIONAL，
-- 缩放由 Controls:SetHUDSize 设成 GetHUDScale()），再乘上面的 PANEL_SCALE 补偿。

-- ⚠️ 面板打开期间屏蔽相机缩放。
-- 官方靠 playercontroller.lua:4463 的 HUD.controls.craftingmenu.focus 来阻止
-- 滚轮同时缩放镜头，我们的自定义面板不在那套机制里，只能直接在相机层拦。
local active_list = nil
local hooked_camera = nil

local function IsVaultOpen()
    return active_list ~= nil
        and active_list.inst ~= nil
        and active_list.inst:IsValid()
end

local function HookCameraZoom()
    local cam = TheCamera
    if cam == nil or cam == hooked_camera then
        return
    end
    hooked_camera = cam
    for _, name in ipairs({ "ZoomIn", "ZoomOut", "ContinuousZoomDelta" }) do
        local old = cam[name]
        if type(old) == "function" then
            cam[name] = function(self, ...)
                if IsVaultOpen() then
                    return
                end
                return old(self, ...)
            end
        end
    end
end

-- ⚠️ strict 模式坑：fonts.lua 里只有 BODYTEXTFONT / HEADERFONT / UIFONT，
-- 没有 BODYDEPTH（曾导致打开仓库直接崩）。中文用 UIFONT 的 fallback 最稳。
local BODY_FONT = UIFONT

-- DST 字体自带的图标字形（PUA），走 fallback 字体渲染，
-- HEADERFONT 里和中文混排没问题。背包 = U+F001E。
local ICON_BACKPACK = "\243\176\128\158" -- 背包（U+F001E）
local ICON_CHEST = "\243\176\128\130"    -- 宝箱（U+F0002），筛选时用这个
local ICON_WORMHOLE = "\243\176\128\175" -- 虫洞/黑洞（U+F002F），关闭按钮用
-- 鼠标示意图标（U+E0101 右键 / U+E0100 左键），字体 fallback 里有，
-- 来源：2885137047 modinfo.lua:35-42 的 INPUTS 表
local ICON_MOUSE_RIGHT = "\238\132\129"
local ICON_MOUSE_MIDDLE = "\238\132\130"

-- 图标名来自官方 recipes_filter.lua:28 CRAFTING_FILTER_DEFS
local FILTER_DEFS = {
    { id = "ALL", label = "全部", icon = "filter_none.tex" },
    -- 武器 + 防具合并成一个分区，用防具图标表示（不再单列「工具」）
    { id = "GEAR", label = "武器/防具", icon = "filter_armour.tex" },
    { id = "COOKING", label = "食物", icon = "filter_cooking.tex" },
    { id = "MAGIC", label = "魔法", icon = "filter_skull.tex" },
    { id = "REFINE", label = "材料", icon = "filter_refine.tex" },
}

-- ⚠️ 分类判定参考「简易存储」scripts/ss_util/terminalfn.lua。
-- 官方 CRAFTING_FILTERS[id].recipes 只列出**可制作的成品**，
-- 采集物 / 掉落物 / 原料（肉、浆果、蔬菜、木头、宝石…）全都不在里面，
-- 所以只靠配方反查时「食物」这类分类几乎永远是空的。
-- 正确做法：配方产物 + 物品自身 tag + 少量原料白名单，三者叠加。
local RECIPE_PRODUCTS = {}
for _, def in ipairs(FILTER_DEFS) do
    if def.id ~= "ALL" then
        local set = {}
        local filter = CRAFTING_FILTERS ~= nil and CRAFTING_FILTERS[def.id] or nil
        if filter ~= nil and filter.recipes ~= nil then
            for _, rname in ipairs(filter.recipes) do
                local recipe = AllRecipes ~= nil and AllRecipes[rname] or nil
                if recipe ~= nil and recipe.product ~= nil then
                    set[recipe.product] = true
                end
            end
        end
        RECIPE_PRODUCTS[def.id] = set
    end
end

-- GEAR 还要覆盖「工具」：TOOLS 已不是一个独立分区了，单独把它的配方产物捞出来
local TOOL_PRODUCTS = {}
local tools_filter = CRAFTING_FILTERS ~= nil and CRAFTING_FILTERS.TOOLS or nil
if tools_filter ~= nil and tools_filter.recipes ~= nil then
    for _, rname in ipairs(tools_filter.recipes) do
        local recipe = AllRecipes ~= nil and AllRecipes[rname] or nil
        if recipe ~= nil and recipe.product ~= nil then
            TOOL_PRODUCTS[recipe.product] = true
        end
    end
end

-- 魔法分区额外收进来的东西：六色月眼 + 带孔月岩
local MAGIC_PREFABS = {
    purplemooneye = true,
    bluemooneye = true,
    redmooneye = true,
    orangemooneye = true,
    yellowmooneye = true,
    greenmooneye = true,
    moonrockcrater = true,
}

-- 材料：REFINE 配方的产物 + 该配方的原料（ingredient.type）+ 常见原料白名单
local REFINE_MATERIALS = {}
local refine_filter = CRAFTING_FILTERS ~= nil and CRAFTING_FILTERS.REFINE or nil
if refine_filter ~= nil and refine_filter.recipes ~= nil then
    for _, rname in ipairs(refine_filter.recipes) do
        local recipe = AllRecipes ~= nil and AllRecipes[rname] or nil
        if recipe ~= nil then
            if recipe.product ~= nil then
                REFINE_MATERIALS[recipe.product] = true
            end
            if recipe.ingredients ~= nil then
                for _, ing in ipairs(recipe.ingredients) do
                    if ing.type ~= nil then
                        REFINE_MATERIALS[ing.type] = true
                    end
                end
            end
        end
    end
end
for _, p in ipairs({
    "twigs", "flint", "charcoal", "gears", "thulecite", "moonglass",
    "horrorfuel", "purebrilliance", "dreadstone", "boneshard", "houndstooth",
    "stinger", "spidergland", "pigskin", "beefalowool", "beardhair",
    "tentaclespots", "walrus_tusk", "dragon_scales", "fossil_piece",
    "slurtle_shellpieces", "cookiecuttershell", "goose_feather", "feather_crow",
    "feather_robin", "feather_robin_winter", "feather_canary", "manrabbit_tail",
    "slurper_pelt", "steelwool", "shroom_skin", "lightninggoathorn",
    "lunarplant_husk", "voidcloth", "wagpunk_bits", "driftwood_log",
    "townportaltalisman",
}) do
    REFINE_MATERIALS[p] = true
end

local function MatchesFilter(item, filter)
    if filter == nil or filter == "ALL" then
        return true
    end
    if item == nil then
        return false
    end

    local prefab = item.prefab
    local products = RECIPE_PRODUCTS[filter] or {}

    if filter == "GEAR" then
        -- 工具 + 武器 + 防具（含帽子/背包等非手部装备）合并成一个分区
        if products[prefab] or TOOL_PRODUCTS[prefab] then
            return true
        end
        if item:HasTag("tool") or item:HasTag("weapon")
            or item:HasTag("armor") or item:HasTag("hat") then
            return true
        end
        local eq = item.replica ~= nil and item.replica.equippable or nil
        if eq ~= nil then
            local slot = eq:EquipSlot()
            if slot ~= nil then
                return slot ~= EQUIPSLOTS.HANDS
            end
        end
        return false
    elseif filter == "COOKING" then
        -- 有新鲜度的物品（肉/菜/果/料理/种子…）一律算食物：
        -- 客户端物品实体没有 components，但有 replica.perishable
        if item.replica ~= nil and item.replica.perishable ~= nil then
            return true
        end
        -- 官方给所有可食用物打 edible_<FOODTYPE> tag，采集物和料理都覆盖
        for _, foodtype in pairs(FOODTYPE) do
            if item:HasTag("edible_" .. foodtype) then
                return true
            end
        end
        return products[prefab] == true
            or item:HasTag("cookable")
            or item:HasTag("preparedfood")
            or item:HasTag("fertilizer")
    elseif filter == "MAGIC" then
        if MAGIC_PREFABS[prefab] then
            return true
        end
        return products[prefab] == true
            or item:HasTag("gem")
            or item:HasTag("bookcabinet_item")
            or string.find(tostring(prefab), "staff") ~= nil
            or string.find(tostring(prefab), "amulet") ~= nil
    elseif filter == "REFINE" then
        return products[prefab] == true or REFINE_MATERIALS[prefab] == true
    end

    return false
end

local function StackOf(item)
    if item == nil then
        return 0
    end
    local st = item.replica ~= nil and item.replica.stackable or nil
    return st ~= nil and st:StackSize() or 1
end

-- TrueScrollList 的每个 widget 对应一个数据项（不是一行），
-- 所以这里创建独立格子并自己摆成网格。
-- ⚠️ 要多建 EXTRA_ROWS 行：TrueScrollList 滚动时是把 list_root 整体上移
-- （truescrolllist.lua:472 `list_root:SetPosition(0, row_offset * row_height)`），
-- 只建可见行数的话，滚动过程中窗口底部会露白，最后一行像是"突然刷出来"。
-- 多建一行放在窗口下方，滑动时它正好从底部升上来。
-- 返回 (widgets, widgets_per_row, row_height, visible_rows, end_offset)
local function CreateCells(context, list_root)
    local widgets = {}
    for i = 1, COLS * (ROWS + EXTRA_ROWS) do
        local cell = Widget("vaultcell")
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        cell:SetPosition(
            -((COLS - 1) * CELL) / 2 + col * CELL,
            ((ROWS - 1) * CELL) / 2 - row * CELL
        )

        -- 格子就是「普通月眼空间」同款的官方 inv_slot.tex
        local slot = InvSlot(1, "images/hud.xml", "inv_slot.tex", context.owner, context.container)
        -- 等比放大槽位（官方 containerwidget 的 slotscale 也是这么改 base_scale 的）
        slot.highlight_scale = SLOT_SCALE * 1.15
        slot.base_scale = SLOT_SCALE
        slot:SetScale(SLOT_SCALE)
        cell.slot = cell:AddChild(slot)

        list_root:AddChild(cell)
        widgets[i] = cell
    end
    -- ⚠️ 最后一个返回值 end_offset 必须等于 EXTRA_ROWS：
    -- TrueScrollList 的 `end_pos = total_rows - visible_rows + end_offset`
    -- （truescrolllist.lua:278）。多渲了几行却把 end_offset 传 0，
    -- 滚动行程就会少一行 —— 最后一行永远滚不上来（用户实测 bug）。
    return widgets, COLS, CELL, ROWS, EXTRA_ROWS
end

-- ⚠️ TrueScrollList:RefreshView（官方 truescrolllist.lua:453）传给 update_fn 的
-- 第二个参数是 self.widgets_to_update[i]，即**单个格子 widget**，不是 widgets 数组。
-- 曾写成 widgets[index] 恒为 nil，所有格子都不更新 → 图标全空白。
local function UpdateCell(context, cell, data, index)
    if cell == nil then
        return
    end
    if data == nil then
        cell.slot.num = nil
        cell.slot:SetTile(nil)
        cell:Hide()
        return
    end
    cell:Show()

    -- 空格子也要有槽位号，拖物品上去才能存进对应 slot
    cell.slot.num = data.slot
    local item = data.item
    if item == nil then
        cell.slot:SetTile(nil)
    elseif cell.slot.tile == nil or cell.slot.tile.item ~= item then
        cell.slot:SetTile(ItemTile(item))
    elseif cell.slot.tile.Refresh ~= nil then
        cell.slot.tile:Refresh()
    end
end

-- ====================================================================
-- 拖动位置记忆（关掉面板/再打开还在原地）
-- ====================================================================
local SAVE_KEY = "hslot_vault_pos"
local saved_pos = nil
local saved_pos_loaded = false

local function LoadSavedPos()
    if saved_pos_loaded then
        return saved_pos
    end
    saved_pos_loaded = true
    TheSim:GetPersistentString(SAVE_KEY, function(ok, data)
        if not ok or data == nil or data == "" then
            return
        end
        local sx, sy = string.match(data, "([%-%d%.]+),([%-%d%.]+)")
        if sx == nil or sy == nil then
            return
        end
        saved_pos = Vector3(tonumber(sx), tonumber(sy), 0)
        -- 面板已经开着的话，直接把位置搬过去
        if active_list ~= nil and active_list.inst ~= nil and active_list.inst:IsValid() then
            active_list:SetPosition(saved_pos.x, saved_pos.y, 0)
        end
    end)
    return saved_pos
end

local HslotVaultList = Class(Widget, function(self, owner, container_inst)
    Widget._ctor(self, "HslotVaultList")

    active_list = self
    HookCameraZoom()

    -- ⚠️ DST Widget 默认以屏幕左下角为原点，不设锚点会跑到左下角。
    self:SetHAnchor(ANCHOR_MIDDLE)
    self:SetVAnchor(ANCHOR_MIDDLE)
    -- 记录锚点：GetWorldPosition 返回的是相对锚点的坐标，
    -- 换算成屏幕绝对坐标时要靠它（见 GetMouseLocalPos）
    self.h_anchor = ANCHOR_MIDDLE
    self.v_anchor = ANCHOR_MIDDLE
    self:SetPosition(0, 0, 0)
    -- 补一档自身缩放，抵消父级 HUD 缩放，让金边/文字的观感接近官方窗口
    self:SetScale(PANEL_SCALE)

    -- 记忆上次拖动到的位置（异步读盘，读到了会自己搬过去）
    local p = LoadSavedPos()
    if p ~= nil then
        self:SetPosition(p.x, p.y, 0)
    end

    self.owner = owner
    self.container_inst = container_inst
    self.container = container_inst.replica.container
    self.filter = "ALL"

    -- 窗口外框：直接复用官方 9-slice 窗口（「简易存储 3383078008」
    -- terminalwidget.lua:109 用的同一套 TEMPLATES.RectangleWindow），
    -- 上下自带金色装饰冠。
    -- ⚠️ 模板默认 SetScale(0.7) 且尺寸被 clamp 到 620 高，这里显式覆盖掉。
    self.frame = self:AddChild(TEMPLATES.RectangleWindow(PANEL_W, PANEL_H, ""))
    self.frame:SetScale(1, 1, 1)
    self.frame:SetSize(PANEL_W, PANEL_H)
    -- 金边里面整片染成绿底（之前是黑的，跟绿色对不上）
    self.frame:SetBackgroundTint(BG_R, BG_G, BG_B, FRAME_BG_ALPHA)

    -- 悬停提示用的抓取层：铺满整块面板、几乎全透明（alpha 0.001，肉眼不可见）。
    -- 拖动/复原的命中判定走 IsMouseOverPanel() 的矩形计算，不依赖这个 widget，
    -- 所以它只负责「显示 tooltip」这一件事，不会再露出可见的边框。
    self.panel = self:AddChild(Image("images/global.xml", "square.tex"))
    self.panel:SetSize(PANEL_W - 6, PANEL_H - 6)
    self.panel:SetTint(1, 1, 1, 0.001)
    self.panel:SetClickable(true)
    -- 悬停提示：鼠标示意图标 + 极简文字（U+E0101 = 右键，U+E0102 = 中键）
    self.panel:SetTooltip(ICON_MOUSE_RIGHT .. " 拖动   " .. ICON_MOUSE_MIDDLE .. " 复原")
    -- 悬停提示必须能盖住格子：格子自己不带 tooltip，这里统一由面板兜底

    -- 右上角：宝箱图标 + 数量，一条 Text 搞定（参考简易存储的「容量: x/y」）。
    -- 字体用 NEWFONT_OUTLINE（官方黑描边版），在绿色底上更清楚。
    -- 全部时白字 n/N，筛选后整条变红 x/N。
    -- ⚠️ Text 的 region 以 position 为中心，右对齐要把 position 放在 region 中心。
    local right_edge = PANEL_W / 2 - EDGE
    local info_w = 400
    self.info = self:AddChild(Text(NEWFONT_OUTLINE, 64, ""))
    self.info:SetRegionSize(info_w, 80)
    self.info:SetHAlign(ANCHOR_RIGHT)
    self.info:SetPosition(right_edge - info_w / 2, FILTER_Y)
    self.info:SetClickable(false)

    -- 顶部一行分类图标：用官方制作栏的 filterslot_frame / filterslot_bg
    -- （craftingmenu_widget.lua:736 MakeFilterButton 同款），选中态用官方 select 贴图
    self.filter_buttons = {}
    self.filter_icons = {}
    self.filter_glows = {}
    -- 左对齐：从左边距开始排，右侧留给 n/N
    local x0 = -PANEL_W / 2 + EDGE + FILTER_ICON / 2
    for i, def in ipairs(FILTER_DEFS) do
        local btn = self:AddChild(ImageButton(
            CRAFTING_ATLAS,
            "filterslot_frame.tex",
            "filterslot_frame_highlight.tex",
            nil,
            nil,
            "filterslot_frame_select.tex"
        ))
        -- ⚠️ 官方 ImageButton 在 image_focus == image_normal 时会 SetScale(1.2)，
        -- 失去焦点时 SetScale(1,1,1) 会覆盖 ForceImageSize 的 ScaleToSize，
        -- 图标被还原成贴图原始尺寸（巨大且不再缩小）。直接关掉焦点缩放。
        btn.scale_on_focus = false
        btn:ForceImageSize(FILTER_ICON, FILTER_ICON)
        btn:SetTooltip(def.label)
        btn:SetOnClick(function()
            self:SetFilter(def.id)
        end)
        btn:SetPosition(x0 + (i - 1) * FILTER_GAP, FILTER_Y)

        local bg = btn:AddChild(Image(CRAFTING_ATLAS, "filterslot_bg.tex"))
        bg:ScaleToSize(FILTER_ICON - 8, FILTER_ICON - 8)

        local icon = btn:AddChild(Image(CRAFTING_ICONS_ATLAS, def.icon))
        icon:ScaleToSize(FILTER_ICON - 24, FILTER_ICON - 24)

        -- 白光叠加层：官方高亮框再复制一份，选中时做透明度呼吸
        local glow = btn:AddChild(Image(CRAFTING_ATLAS, "filterslot_frame_highlight.tex"))
        glow:ScaleToSize(FILTER_ICON + 10, FILTER_ICON + 10)
        glow:SetTint(1, 1, 1, 0)
        glow:SetClickable(false)

        self.filter_buttons[def.id] = btn
        self.filter_icons[def.id] = icon
        self.filter_glows[def.id] = glow
    end

    -- 下方滚动物品网格。第 9 参数是滚动条相对裁剪区右边的额外偏移，
    -- 第 10 参数是滚动条高度增量（传 0，别传一整个 GRID_H 导致滚动条过高）
    self.scrolllist = self:AddChild(TrueScrollList(
        { owner = owner, container = self.container },
        CreateCells,
        UpdateCell,
        -GRID_W / 2, -GRID_H / 2, GRID_W, GRID_H,
        SCROLLBAR_GAP,
        0,
        1
    ))
    self.scrolllist:SetPosition(GRID_CX, GRID_Y)

    -- 底部按钮：用官方 carny 系列贴图（简易存储/官方弹窗底部那套），
    -- 图标取自 DST 字体（背包 = 整理，黑洞 = 关闭），不再带任何文字。
    local function MakeBottomButton(icon, x, cb)
        local btn = self:AddChild(ImageButton(
            "images/global_redux.xml",
            "button_carny_long_normal.tex",
            "button_carny_long_hover.tex",
            "button_carny_long_disabled.tex",
            "button_carny_long_down.tex"
        ))
        btn.scale_on_focus = false
        btn:ForceImageSize(BUTTON_W, BUTTON_H)
        btn:SetText(icon)
        btn:SetTextSize(34) -- 图标别太大
        btn:SetPosition(x, BOTTOM_Y)
        btn:SetOnClick(cb)
        return btn
    end
    -- 整理：只发官方 DoWidgetButtonAction RPC，服务端仍走 hslot_btn_fn
    -- （排序 + 消耗彩虹宝石堆叠/复制 bundle），逻辑不重写
    self.btn_sort = MakeBottomButton(ICON_BACKPACK, SORT_X, function()
        self:DoSortButton()
    end)
    -- 关闭：复用同一个 mod RPC 把容器关掉（打开状态下 toggle 就是关闭）
    self.btn_close = MakeBottomButton(ICON_WORMHOLE, CLOSE_X, function()
        self:DoCloseButton()
    end)

    -- 右键拖动面板：鼠标落在空白背景上时由 panel 接住，落在格子上仍走格子自己的
    -- 右键（查看物品），互不抢。（参考「能力勋章 1909182187」
    -- scripts/medal_globalfn.lua:512-585 的 MakeMedalDragableUI）
    self.panel.OnControl = function(widget, control, down)
        return self:HandleDragControl(control, down)
    end

    -- 右键：拖动面板。**格子区域不响应**（右键在格子上是「查看物品」），
    --       要抓就从格子周围的空白、标题行、按钮区下手。
    -- 中键：位置复原，整块面板都生效（没别的功能占用中键）。
    -- 只在鼠标落在面板范围内时响应，避免抢占别处的点击。
    self._mousebtn = TheInput:AddMouseButtonHandler(function(button, down)
        if button ~= MOUSEBUTTON_RIGHT and button ~= MOUSEBUTTON_MIDDLE then
            return
        end
        if down then
            if not self:IsMouseOverPanel() then
                return
            end
            if button == MOUSEBUTTON_RIGHT then
                -- DRAG_EXCLUDE_GRID 为 true 时，格子区不接右键拖动
                if not (DRAG_EXCLUDE_GRID and self:IsMouseOverGrid()) then
                    self:StartDrag(button) -- 右键：拖动
                end
            else
                self:ResetToDefaultPos() -- 中键：位置复原
            end
        elseif self._drag_button == button then
            self:EndDrag()
        end
    end)

    -- 容器变化时刷新（0.12 秒合并一次，160 格频繁存取也不刷屏）
    self.onchanged = function()
        self:QueueRefresh()
    end
    -- 放入物品后跳到对应格子（非堆叠物品时容器会带 data.slot）
    self.onitemget = function(_, data)
        if data ~= nil and data.slot ~= nil then
            self._pending_slot = data.slot
        end
        self:QueueRefresh()
    end
    container_inst:ListenForEvent("itemget", self.onitemget)
    container_inst:ListenForEvent("itemlose", self.onchanged)
    container_inst:ListenForEvent("refresh", self.onchanged)

    self:UpdateFilterButtons()
    self:RefreshData()
    self:StartFlash()
    self:StartUpdating()
end)

-- 选中分类图标的跑马灯（手杖图标同款：色相循环 + 混白提亮 + 白光呼吸）
function HslotVaultList:StartFlash()
    if self._flashtask ~= nil then
        return
    end
    local t = 0
    self._flashtask = self.inst:DoPeriodicTask(FLASH_STEP, function()
        t = t + FLASH_STEP
        local hue = t * 2 * math.pi / FLASH_SPEED
        -- 40% 颜色 + 60% 白，暗色图标也看得清（和 hcane 完全一致）
        local r = (math.sin(hue) + 1) / 2 * 0.4 + 0.6
        local g = (math.sin(hue + 2.094) + 1) / 2 * 0.4 + 0.6
        local b = (math.sin(hue + 4.189) + 1) / 2 * 0.4 + 0.6
        local id = self.filter
        local btn = self.filter_buttons[id]
        if btn ~= nil then
            btn.image:SetTint(r, g, b, 1)
        end
        local icon = self.filter_icons[id]
        if icon ~= nil then
            icon:SetTint(r, g, b, 1)
        end
        -- 白光叠加层同步呼吸：0.1 ~ 1.0，让选中态更扎眼
        local glow = self.filter_glows[id]
        if glow ~= nil then
            local a = 0.1 + 0.9 * (math.sin(t * 2 * math.pi / FLASH_SPEED) + 1) / 2
            glow:SetTint(1, 1, 1, a)
        end
    end)
end

function HslotVaultList:StopFlash()
    if self._flashtask ~= nil then
        self._flashtask:Cancel()
        self._flashtask = nil
    end
end

function HslotVaultList:UpdateFilterButtons()
    for id, btn in pairs(self.filter_buttons) do
        if id == self.filter then
            btn:Select()
            btn:SetScale(FILTER_SCALE_ON) -- 选中整体放大
        else
            btn:Unselect()
            btn:SetScale(1)
            -- 复位上一轮跑马灯留下的颜色和白光
            btn.image:SetTint(1, 1, 1, 1)
            local icon = self.filter_icons[id]
            if icon ~= nil then
                icon:SetTint(1, 1, 1, 1)
            end
            local glow = self.filter_glows[id]
            if glow ~= nil then
                glow:SetTint(1, 1, 1, 0)
            end
        end
    end
end

-- ====================================================================
-- 右键拖动面板
-- ====================================================================
-- 只在「按下/松开右键」时判断，移动过程交给 TheInput:AddMoveHandler。
function HslotVaultList:HandleDragControl(control, down)
    if control ~= CONTROL_SECONDARY then
        return false
    end
    if down then
        -- DRAG_EXCLUDE_GRID 为 true 时，格子区的右键归格子自己「查看物品」
        if DRAG_EXCLUDE_GRID and self:IsMouseOverGrid() then
            return false
        end
        self:StartDrag(MOUSEBUTTON_RIGHT)
    else
        self:EndDrag()
    end
    return true
end

-- ====================================================================
-- 拖动 / 命中判定 / 复原位置
-- ====================================================================
-- 全部复用「UI 拖拽缩放 2885137047」common.lua:52-80 的成熟实现
-- （原作者注明来自「蘑菇慕斯」），不再自己推坐标系。
--
-- ⚠️ 关键坑：TheInput:GetScreenPosition() 返回的是**一个 Vector3**，
-- 不是 (x, y) 两个数字！写成 `local mx, my = TheInput:GetScreenPosition()`
-- 会得到 mx = Vector3、my = nil，随后 `mx - cx` 就在 vector3.lua:14 崩了
-- （attempt to index local 'rhs' (a number value)）。
local function GetMouseLocalPos(ui, mouse_pos)
    local g_s = ui:GetScale()
    local l_s = Vector3(0, 0, 0)
    l_s.x, l_s.y, l_s.z = ui:GetLooseScale()
    local scale = Vector3(
        (l_s.x ~= 0) and (g_s.x / l_s.x) or 1,
        (l_s.y ~= 0) and (g_s.y / l_s.y) or 1,
        (l_s.z ~= 0) and (g_s.z / l_s.z) or 1
    )

    local ui_local_pos = ui:GetPosition()
    ui_local_pos = Vector3(ui_local_pos.x * scale.x, ui_local_pos.y * scale.y, ui_local_pos.z * scale.z)
    local ui_world_pos = ui:GetWorldPosition()
    -- 改过锚点后 GetWorldPosition 返回的是「相对锚点」的坐标，要先换算回屏幕绝对坐标
    if not (not ui.v_anchor or ui.v_anchor == ANCHOR_BOTTOM)
        or not (not ui.h_anchor or ui.h_anchor == ANCHOR_LEFT) then
        local screen_w, screen_h = TheSim:GetScreenSize()
        if ui.v_anchor and ui.v_anchor ~= ANCHOR_BOTTOM then
            ui_world_pos.y = (ui.v_anchor == ANCHOR_MIDDLE)
                and (screen_h / 2 + ui_world_pos.y) or (screen_h - ui_world_pos.y)
        end
        if ui.h_anchor and ui.h_anchor ~= ANCHOR_LEFT then
            ui_world_pos.x = (ui.h_anchor == ANCHOR_MIDDLE)
                and (screen_w / 2 + ui_world_pos.x) or (screen_w - ui_world_pos.x)
        end
    end

    local origin_point = ui_world_pos - ui_local_pos
    mouse_pos = mouse_pos - origin_point
    return Vector3(mouse_pos.x / scale.x, mouse_pos.y / scale.y, mouse_pos.z / scale.z)
end

-- 鼠标在「面板父级局部坐标」里的位置（和 GetPosition 同一坐标系）
function HslotVaultList:GetMouseLocal()
    local m = TheInput:GetScreenPosition()
    return GetMouseLocalPos(self, Vector3(m.x, m.y, 0))
end

-- ====================================================================
-- 拖动（照搬参考 MOD 的 offset 模式）
-- ====================================================================
function HslotVaultList:StartDrag(button)
    if self._draghandler ~= nil then
        return
    end
    self._drag_button = button or MOUSEBUTTON_RIGHT
    -- 记录「抓取瞬间 面板位置 - 鼠标位置」的偏移，拖动期间保持不变，
    -- 这样面板不会跳到鼠标中心，手感自然
    local loc = self:GetMouseLocal()
    local pos = self:GetPosition()
    self._grab_dx = pos.x - loc.x
    self._grab_dy = pos.y - loc.y
    self._grab_dz = pos.z - loc.z

    self._draghandler = TheInput:AddMoveHandler(function(x, y)
        if not TheInput:IsMouseDown(self._drag_button) then
            self:EndDrag()
            return
        end
        local l = GetMouseLocalPos(self, Vector3(x, y, 0))
        self:SetPosition(
            l.x + self._grab_dx,
            l.y + self._grab_dy,
            l.z + self._grab_dz
        )
    end)
end

-- ====================================================================
-- 默认位置：左上角（DEFAULT_*_OFFSET 单位是屏幕像素）
-- ====================================================================
-- 父级缩放 = 累计缩放 / 自身缩放（GetScale 返回的是两者相乘）
function HslotVaultList:GetParentScale()
    local g_s = self:GetScale()
    local lx, ly = self:GetLooseScale()
    lx = (lx ~= nil and lx ~= 0) and lx or 1
    ly = (ly ~= nil and ly ~= 0) and ly or 1
    return g_s.x / lx, g_s.y / ly
end

function HslotVaultList:ApplyDefaultPos()
    local sw, sh = TheSim:GetScreenSize()
    local keep = self:GetPosition()

    -- ① 标定「父级逻辑单位 → 设备像素」：实测两点取差值，
    --    差值天然抵消「坐标原点在哪」的不确定性，只留比例。
    self:SetPosition(keep.x, keep.y, keep.z)
    local a = self:GetWorldPosition()
    self:SetPosition(keep.x + 100, keep.y + 100, keep.z)
    local b = self:GetWorldPosition()

    local kx = (b.x - a.x) / 100
    local ky = (b.y - a.y) / 100
    if kx == 0 or ky == 0 then
        -- 兜底：万一 GetWorldPosition 没即时更新，退回父级缩放
        local psx, psy = self:GetParentScale()
        kx, ky = psx, psy
    end

    -- ② 目标面板中心（屏幕绝对坐标，左下角为原点）
    local want_cx = DEFAULT_LEFT_OFFSET + (PANEL_W / 2) * kx
    local want_cy = sh - DEFAULT_TOP_OFFSET - (PANEL_H / 2) * ky

    local ha = self.h_anchor or ANCHOR_LEFT
    local va = self.v_anchor or ANCHOR_BOTTOM

    -- 把 GetWorldPosition 的结果换算成「屏幕绝对坐标」。
    -- ⚠️ 这一步有两种可能的语义（返回的是绝对坐标 / 是相对锚点的坐标），
    -- 不同版本/不同父级行为不一致，硬猜就会像之前那样整体偏移、面板被屏幕裁掉。
    -- 所以两种都算一遍，各设上去读回真实位置，选误差小的那个。
    local function ToScreen(w, with_fix)
        local x, y = w.x, w.y
        if with_fix then
            if ha == ANCHOR_MIDDLE then
                x = sw / 2 + x
            elseif ha == ANCHOR_RIGHT then
                x = sw - x
            end
            if va == ANCHOR_MIDDLE then
                y = sh / 2 + y
            elseif va == ANCHOR_TOP then
                y = sh - y
            end
        end
        return x, y
    end

    local best_x, best_y, best_err = keep.x, keep.y, math.huge
    for _, with_fix in ipairs({ true, false }) do
        self:SetPosition(0, 0, 0)
        local ox, oy = ToScreen(self:GetWorldPosition(), with_fix)
        local px = (want_cx - ox) / kx
        local py = (want_cy - oy) / ky

        self:SetPosition(px, py, 0)
        local cx2, cy2 = ToScreen(self:GetWorldPosition(), with_fix)
        local err = math.abs(cx2 - want_cx) + math.abs(cy2 - want_cy)
        if err < best_err then
            best_err, best_x, best_y = err, px, py
        end
    end

    self:SetPosition(best_x, best_y, 0)
end

-- 中键复原：搬回默认位置并写盘
function HslotVaultList:ResetToDefaultPos()
    self:ApplyDefaultPos()
    local pos = self:GetPosition()
    saved_pos = Vector3(pos.x, pos.y, 0)
    TheSim:SetPersistentString(SAVE_KEY, string.format("%.2f,%.2f", pos.x, pos.y), false)
end

-- ====================================================================
-- 鼠标命中判定（父级局部坐标）
-- ====================================================================
function HslotVaultList:IsMouseOverPanel()
    local loc = self:GetMouseLocal()
    local pos = self:GetPosition()
    local lx, ly = self:GetLooseScale()
    lx = (lx ~= nil and lx ~= 0) and lx or 1
    ly = (ly ~= nil and ly ~= 0) and ly or 1
    return math.abs(loc.x - pos.x) <= PANEL_W / 2 * lx
        and math.abs(loc.y - pos.y) <= PANEL_H / 2 * ly
end

-- 鼠标是否落在格子（滚动列表可视区）里
function HslotVaultList:IsMouseOverGrid()
    local loc = self:GetMouseLocal()
    local pos = self:GetPosition()
    local lx, ly = self:GetLooseScale()
    lx = (lx ~= nil and lx ~= 0) and lx or 1
    ly = (ly ~= nil and ly ~= 0) and ly or 1
    local dx = (loc.x - pos.x) / lx - GRID_CX
    local dy = (loc.y - pos.y) / ly - GRID_Y
    return math.abs(dx) <= GRID_W / 2 and math.abs(dy) <= GRID_H / 2
end

function HslotVaultList:EndDrag()
    if self._draghandler ~= nil then
        self._draghandler:Remove()
        self._draghandler = nil
    end
    self._grab_dx = nil
    self._grab_dy = nil
    self._grab_dz = nil
    self._drag_button = nil
    -- 记住这次拖到哪了，下次打开还在原地
    local pos = self:GetPosition()
    saved_pos = Vector3(pos.x, pos.y, 0)
    TheSim:SetPersistentString(SAVE_KEY, string.format("%.2f,%.2f", pos.x, pos.y), false)
end

function HslotVaultList:SetFilter(id)
    if self.filter == id then
        return
    end
    self.filter = id
    self._pending_slot = nil
    -- 切筛选：丢掉冻结布局，强制按新筛选重排，并回到顶部
    self._view_slots = nil
    self._view_set = nil
    self._scroll_top_until = GetTime()
    self:UpdateFilterButtons()
    self:RefreshData()
end

-- 整理按钮：和官方 ContainerWidget 的按钮走同一条 RPC
-- （networkclientrpc.lua:528 会校验 IsOpenedBy + validfn，再调用服务端 hslot_btn_fn）
function HslotVaultList:DoSortButton()
    local inst = self.container_inst
    if inst == nil or not inst:IsValid() then
        return
    end
    local rep = inst.replica.container
    if rep == nil or rep:IsBusy() then
        return
    end
    -- 整理是服务端异步做的，会连续来好几波物品变动事件。
    -- 用时间窗盖住整段过程：期间每次刷新都回顶、也不跟着物品乱跳
    self._scroll_top_until = GetTime() + 1.2
    SendRPCToServer(RPC.DoWidgetButtonAction, nil, inst, nil)
end

function HslotVaultList:QueueRefresh()
    if self._refreshtask ~= nil then
        return
    end
    self._refreshtask = self.inst:DoTaskInTime(REFRESH_INTERVAL, function()
        self._refreshtask = nil
        if self.inst:IsValid() then
            self:RefreshData()
        end
    end)
end

function HslotVaultList:OnUpdate(dt)
    -- 首次更新时才套默认位置：ctor 阶段还没 AddChild 到父级，
    -- GetScale() 拿不到父级缩放，算出来的屏幕半宽是错的
    if not self._pos_applied then
        self._pos_applied = true
        if saved_pos == nil then
            self:ApplyDefaultPos()
        end
    end

    -- 兜底：官方 ContainerWidget 只要被任何途径重新显示（refresh、暂停恢复、
    -- 别的 MOD 调 Show），立刻再藏回去
    local w = self.container_widget
    if w ~= nil and w.inst ~= nil and w.inst:IsValid() and w.shown then
        w:Hide()
    end

    -- ⚠️ 合并堆叠时容器不推 itemget（components/container.lua:494/511 直接 return），
    -- 只改物品自己的 stacksize 网络变量，我们收不到任何事件。
    -- 所以低频率轮询一个「物品数 + 堆叠总量」签名，变了就刷新一次。
    self._poll = (self._poll or 0) + dt
    if self._poll >= POLL_INTERVAL then
        self._poll = 0
        local sig = self:ContainerSignature()
        if sig ~= self._sig then
            self._sig = sig
            self:QueueRefresh()
        end
    end
end

function HslotVaultList:ContainerSignature()
    local items = self.container ~= nil and self.container:GetItems() or nil
    if items == nil then
        return 0
    end
    local n, s = 0, 0
    for _, item in pairs(items) do
        n = n + 1
        s = s + StackOf(item)
    end
    return n * 100003 + s
end

function HslotVaultList:RefreshData()
    if self.container == nil or self.container_inst == nil or not self.container_inst:IsValid() then
        return
    end

    local numslots = self.container:GetNumSlots() or 0
    if numslots <= 0 then
        -- 容器数据还没同步到位，稍后重试几次
        self._retry = (self._retry or 0) + 1
        if self._retry <= 5 then
            self.inst:DoTaskInTime(0.2, function()
                if self.inst:IsValid() then
                    self:RefreshData()
                end
            end)
        end
        return
    end
    self._retry = nil

    local items = self.container:GetItems() or {}
    local data = {}
    local used = 0
    local shown = 0

    -- 前后快照对比：实体从无到有、换了个实体、或堆叠变大 = 「刚放进来」
    local added = nil
    local snap = {}
    for slot = 1, numslots do
        local item = items[slot]
        local stack = StackOf(item)
        snap[slot] = { item = item, stack = stack }
        if self._snap ~= nil then
            local p = self._snap[slot]
            if item ~= nil
                and (p == nil or p.item == nil or p.item ~= item or stack > p.stack)
            then
                added = added or slot
            end
        end
    end
    self._snap = snap

    -- 统计：已用槽位 / 当前筛选命中数
    for slot = 1, numslots do
        local item = items[slot]
        if item ~= nil then
            used = used + 1
            if MatchesFilter(item, self.filter) then
                shown = shown + 1
            end
        end
    end

    -- ⚠️ 布局是「冻结」的：只在 打开面板 / 切筛选 / 点整理 时重排（压缩成列表），
    -- 中途拿走物品**不重排**——那一格清空留着，后面的物品不会缩上来。
    -- 这样既是筛选后的紧凑列表，又不会一取东西就整片刷新跳动。
    local rebuild = (self._scroll_top_until ~= nil and GetTime() <= self._scroll_top_until)
        or self._view_slots == nil
    if rebuild then
        self:RebuildViewSlots(items, numslots)
    end

    for i = 1, #self._view_slots do
        local slot = self._view_slots[i]
        local item = items[slot]
        if item ~= nil and MatchesFilter(item, self.filter) then
            data[#data + 1] = { slot = slot, item = item }
        else
            -- 被拿走 / 不再匹配：格子留着，空着（和箱子一致）
            data[#data + 1] = { slot = slot, item = nil }
        end
    end

    -- 新放进来的匹配物品：追加到末尾（冻结布局不回头填洞）
    for slot = 1, numslots do
        local item = items[slot]
        if item ~= nil and not self._view_set[slot] and MatchesFilter(item, self.filter) then
            self._view_slots[#self._view_slots + 1] = slot
            self._view_set[slot] = true
            data[#data + 1] = { slot = slot, item = item }
        end
    end

    -- 底部左侧信息：n/N 固定；筛选时后面追加「宝箱图标 + 命中数」，并标红
    -- 右上角：宝箱图标固定在前；全部 = 白字「已用/总数」，筛选后 = 红字「命中/总数」
    if self.filter == "ALL" then
        self.info:SetString(string.format("%s %d/%d", ICON_CHEST, used, numslots))
        self.info:SetColour(1, 1, 1, 1)
    else
        self.info:SetString(string.format("%s %d/%d", ICON_CHEST, shown, numslots))
        self.info:SetColour(1, 0.32, 0.26, 1)
    end

    self.scrolllist:SetItemsData(data)

    if self._scroll_top_until ~= nil and GetTime() <= self._scroll_top_until then
        -- 点了整理 / 切了筛选：直接回顶，不要跟着被移动的物品乱跳
        self._pending_slot = nil
        self.scrolllist:ResetScroll()
    else
        -- 跳到刚放进去的那一格：优先用 itemget 给的槽位，其次用快照对比出来的
        local target_slot = self._pending_slot or added
        self._pending_slot = nil
        if target_slot ~= nil then
            -- 列表是压缩过的，index ≠ slot，得按 slot 反查
            for i = 1, #data do
                if data[i].slot == target_slot then
                    if not self.scrolllist:IsItemFullyVisible(i) then
                        self.scrolllist:ScrollToDataIndex(i)
                        -- 跳过去之后给那一格一个「放大 + 跑马灯」的示意
                        self:FlashDataIndex(i)
                    end
                    break
                end
            end
        end
    end
end

-- 重建「冻结布局」：当前筛选下匹配的槽位列表（按槽位顺序压缩）
-- ⚠️ 「全部」要把 160 个槽位全列出来（空格也要有格子，才能直接往里拖），
-- 只有真正的筛选才压缩成「仅匹配物品」。
function HslotVaultList:RebuildViewSlots(items, numslots)
    items = items or (self.container ~= nil and self.container:GetItems()) or {}
    numslots = numslots or (self.container ~= nil and self.container:GetNumSlots()) or 0
    self._view_slots = {}
    self._view_set = {}
    for slot = 1, numslots do
        local item = items[slot]
        if self.filter == "ALL" or (item ~= nil and MatchesFilter(item, self.filter)) then
            self._view_slots[#self._view_slots + 1] = slot
            self._view_set[slot] = true
        end
    end
end

-- 关闭按钮：容器现在是打开的，走同一个 mod RPC 的 toggle 就是关闭
function HslotVaultList:DoCloseButton()
    SendModRPCToServer(MOD_RPC["hslot_pocket"]["toggle_blue"])
end

-- ====================================================================
-- 跳转到某格后的「放大 + 跑马灯」提示
-- ====================================================================
function HslotVaultList:FlashDataIndex(index)
    local list = self.scrolllist
    if list == nil or list.widgets_to_update == nil then
        return
    end
    -- 数据 index → 当前可见的格子 widget index
    local wi = index - (list.displayed_start_index or 0)
    local cell = list.widgets_to_update[wi]
    if cell ~= nil then
        self:FlashCell(cell)
    end
end

function HslotVaultList:FlashCell(cell)
    self:StopCellFlash()
    self._flashcell = cell
    local t = 0
    cell:SetScale(1.22)
    self._cellflashtask = self.inst:DoPeriodicTask(FLASH_STEP, function()
        t = t + FLASH_STEP
        -- 跑马灯着色（同 hcane：40% 颜色 + 60% 白）
        local hue = t * 2 * math.pi / 0.8
        local r = (math.sin(hue) + 1) / 2 * 0.4 + 0.6
        local g = (math.sin(hue + 2.094) + 1) / 2 * 0.4 + 0.6
        local b = (math.sin(hue + 4.189) + 1) / 2 * 0.4 + 0.6
        local img = (cell.slot ~= nil and cell.slot.tile ~= nil) and cell.slot.tile.image or nil
        if img ~= nil and img.inst ~= nil and img.inst:IsValid() then
            img:SetTint(r, g, b, 1)
        end
        -- 0.4 秒内缩回原尺寸
        local k = math.min(t / 0.4, 1)
        cell:SetScale(1 + 0.22 * (1 - k))
        if t >= 1 then
            if img ~= nil and img.inst ~= nil and img.inst:IsValid() then
                img:SetTint(1, 1, 1, 1)
            end
            cell:SetScale(1)
            self:StopCellFlash()
        end
    end)
end

function HslotVaultList:StopCellFlash()
    if self._cellflashtask ~= nil then
        self._cellflashtask:Cancel()
        self._cellflashtask = nil
    end
    local cell = self._flashcell
    self._flashcell = nil
    if cell ~= nil and cell.inst ~= nil and cell.inst:IsValid() then
        cell:SetScale(1)
    end
end

function HslotVaultList:OnDestroy()
    if active_list == self then
        active_list = nil
    end
    self:StopFlash()
    self:StopCellFlash()
    self:EndDrag()
    if self._mousebtn ~= nil then
        self._mousebtn:Remove()
        self._mousebtn = nil
    end
    if self._refreshtask ~= nil then
        self._refreshtask:Cancel()
        self._refreshtask = nil
    end
    if self.container_inst ~= nil and self.container_inst:IsValid() then
        self.container_inst:RemoveEventCallback("itemget", self.onitemget)
        self.container_inst:RemoveEventCallback("itemlose", self.onchanged)
        self.container_inst:RemoveEventCallback("refresh", self.onchanged)
    end
end

return HslotVaultList
