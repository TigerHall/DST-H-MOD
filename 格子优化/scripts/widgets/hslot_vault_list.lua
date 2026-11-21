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
-- 滚动网格改用官方 TEMPLATES.ScrollingGrid（内部就是 TrueScrollList），不再直接 require
local TEMPLATES = require("widgets/redux/templates")

-- ====================================================================
-- 尺寸 —— ⭐ 完全照搬「简易存储 3383078008」terminalwidget.lua 的设计
-- ====================================================================
-- 简存原文：
--   · 面板 RectangleWindow(680, 420)（InitPanel:109）
--   · 网格 row_w=64 + row_spacing=16 = 80 间距，15 列 × 6 行（MakeInvGrid:693/784-785）
--   · 网格层 gridroot 挂 self.root，SetScale(0.6)，SetPosition(0,-30)（813-816）
--   · 筛选行 y=175，分隔线 y=144（134/142）
--   · 搜索框 186×40，数量文字 x=292（153/159）
-- 面板自身不缩放；只有 gridroot 缩 0.6。这样格子屏幕尺寸/排布和简存逐像素一致。
local COLS = 15
local ROWS = 6       -- 可视行数（简存 num_visible_rows=6）
local EXTRA_ROWS = 1 -- 额外渲染的行数（滚动时从底部滑上来，不会突现）
local CELL = 80      -- 格子设计间距（gridroot 内部坐标 = 简存 row_w64+spacing16）
local GRID_SCALE = 0.6 -- ⭐ 网格层缩放，和简存 gridroot 的 0.6 同值
local GRID_W = COLS * CELL       -- gridroot 内部尺寸 1200
local GRID_H = ROWS * CELL       --                  480
local SCR_W, SCR_H = GRID_W, GRID_H -- TrueScrollList 裁剪区（gridroot 内部坐标）
local SCROLLBAR_GAP = 8 -- 简存 scrollbar_offset=8

-- 面板设计尺寸：直接照抄简存 680×420。
-- 网格屏幕尺寸 = GRID_W×0.6=720 宽（比面板略宽，两侧各溢出 20，简存原样）、
--               GRID_H×0.6=288 高。gridroot 位置 (0,-30)，见 GRID_CX/GRID_Y。
local PANEL_W = 680
local PANEL_H = 420
local GRID_CX = 0
local GRID_Y = -30    -- ⭐ 简存 gridroot:SetPosition(0,-30)
-- 默认位置恒为屏幕正中（0,0 = 屏幕中心，父级自带 MIDDLE 锚点）。
-- 曾照简存做「制作栏打开右移 260 让位」，但该让位与中键复位互相打断，
-- 2026-11-21 已去掉：位置只由用户拖动偏移 _offset 决定，中键永远回正中。

-- 垂直排布（照抄简存，面板 420 高、半高 210）：
--   筛选行 y=175、分隔线 y=144、网格中心 y=-30（占 -30±144）
--   底部按钮走 RectangleWindow actions（不是独立 ImageButton）。
local FILTER_ICON = 39      -- 简存 button_size=39
local FILTER_GAP = 48       -- 简存 pos_x 每格 +48
local FILTER_SCALE_ON = 1.15 -- 选中时整个按钮放大
local FILTER_Y = 175        -- ⭐ 简存 filterpanel y=175
local FILTER_X0 = -336      -- ⭐ 简存筛选按钮起始 x=-336
local INFO_SIZE = 30        -- 简存 text_size 30
local INFO_W = 160
local NUM_X = 292           -- ⭐ 简存 numslots_text x=292
-- 底部两个按钮（面板底部，RectangleWindow 下沿内侧）
local BUTTON_W, BUTTON_H = 116, 46
local BOTTOM_Y = -178       -- 面板半高 210，按钮区在底部
local SORT_X, CLOSE_X = -70, 70
local EDGE = 2
-- 筛选按钮底衬（filterslot_bg.tex）：false = 透明，只留按钮边框和图标
local FILTER_BG_VISIBLE = false

-- 底色：这里只是兜底值（蓝宝石色）；四种颜色由 modmain 的
-- VAULT_THEMES 传入 theme.r/g/b 覆盖。
-- 直接染在 9-slice 的底上 ——
-- 金边里面整片都是绿底，不会露出原本的黑色内衬。
-- ⚠️ 绿色只有这一层：TEMPLATES.RectangleWindow 的 SetBackgroundTint
-- （templates.lua:1863）只染 mid_left / mid_right / mid_center 三块同一材质，
-- 它们是并排不重叠的；面板上另有一层 alpha 0.001 的 Image，只是用来接
-- tooltip 的不可见抓取层，不参与观感。
-- 想更透就调小这个值（0.15 已经很淡），0 就是全透明只剩金边。
local BG_R, BG_G, BG_B = 0.28, 0.52, 0.95 -- 蓝宝石色（兜底；实际由 theme 传入）
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

-- 面板由 modmain 挂到 hslot_vault_root（controls 下，GetHUDScale 跟随）。
-- 面板自身不缩放；只有 gridroot 缩 0.6，和简存的分层完全一致。

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

-- ⭐ 官方 ScrollingGrid 的两个回调（templates.lua:1961）。
-- 官方 Grid:FillGrid 会自动摆放格子，这里只建结构、不 SetPosition。
-- item_ctor_fn(context, index) 返回单个格子 widget。
local function VaultItemCtor(context, index)
    local cell = Widget("vaultcell")
    -- ⭐ 官方 InvSlot，**不碰 scale** —— invslot.lua:466-467 构造末尾自带
    -- base_scale=1.5，这就是「真实格子」尺寸（和官方红/绿眼空间同款）。
    -- ⚠️ 不要照抄简存的 SetTile(ItemTile())：简存用魔改 terminal_itemtile 支持
    -- invitem=nil；官方 ItemTile 在 itemtile.lua:94 会索引 nil 直接崩。
    -- 空格子不设 tile，等 VaultApply 拿到真实 item 再 SetTile(ItemTile(item))。
    local slot = InvSlot(1, "images/hud.xml", "inv_slot.tex", context.owner, context.container)
    cell.slot = cell:AddChild(slot)
    return cell
end

-- apply_fn(context, widget, data, index) 给单个格子填数据。
-- context 用 opts.scroll_context 传进来，带 owner/container。
local function VaultApply(context, cell, data, index)
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
-- 拖动偏移记忆（关掉面板/再打开还在同一处）
-- ====================================================================
-- ⚠️ 存的是「相对默认位置的偏移」，不是屏幕绝对坐标：
--   默认位置会随「制作栏开关」变化（居中 ↔ 右移 260），
--   存偏移的话面板会跟着让位，用户拖过的那一点微调也不会丢。
-- ⚠️ 还要**按容器分开存**：四个月眼空间各有自己的默认位，
--   共用一个 key 的话，把蓝月眼拖到某处后紫月眼也会跑过去。
-- key 带 v2：v1 存的是屏幕绝对坐标，语义完全不同，换名让它自然作废。
local SAVE_KEY = "hslot_vault_pos2"
local saved_pos = {} -- [container_key] = Vector3 偏移（相对默认位置）
local saved_pos_loaded = {}

local function PosKeyOf(key)
    return key or "hslot"
end

local function LoadSavedPos(key)
    key = PosKeyOf(key)
    if saved_pos_loaded[key] then
        return saved_pos[key]
    end
    saved_pos_loaded[key] = true
    TheSim:GetPersistentString(SAVE_KEY .. "_" .. key, function(ok, data)
        if not ok or data == nil or data == "" then
            return
        end
        local sx, sy = string.match(data, "([%-%d%.]+),([%-%d%.]+)")
        if sx == nil or sy == nil then
            return
        end
        saved_pos[key] = Vector3(tonumber(sx), tonumber(sy), 0)
        -- 面板已经开着、而且是同一个容器的话，直接把位置搬过去
        if active_list ~= nil and active_list.inst ~= nil and active_list.inst:IsValid()
            and PosKeyOf(active_list.container_key) == key then
            active_list._offset = saved_pos[key]
            active_list:ApplyPos()
        end
    end)
    return saved_pos[key]
end

local HslotVaultList = Class(Widget, function(self, owner, container_inst, theme)
    Widget._ctor(self, "HslotVaultList")

    -- theme（由 modmain 的 VAULT_THEMES 传进来）：
    --   r/g/b    底色
    --   key      容器世界 key（关闭按钮按它发 RPC）
    -- 位置不再需要主题参数：默认就是屏幕正中（见 DefaultPos）
    theme = theme or {}
    self.theme = theme
    self.bg_r = theme.r or BG_R
    self.bg_g = theme.g or BG_G
    self.bg_b = theme.b or BG_B
    self.container_key = theme.key

    active_list = self
    HookCameraZoom()

    -- ⭐⭐ 关键修复：不设 SetHAnchor/SetVAnchor！
    -- 3.10 的 hspace_panel 和简存 TerminalWidget 都不设锚点，UI 尺寸才正常。
    -- 之前这里设了 ANCHOR_MIDDLE，子 widget 在带 SCALEMODE_PROPORTIONAL 的父层下
    -- 再设 MIDDLE 锚点，会导致 4K 下缩放被按不同基准计算 → 面板/格子偏小一半。
    -- 父层 containerroot 自带 MIDDLE 锚点，子 widget 位置 (0,0) 就是屏幕正中，
    -- 不需要、也不应该自己再设锚点。
    -- 保留 h_anchor/v_anchor 字段仅供其他代码读取（如某些 MOD 的 tooltip 定位），
    -- 不调用 SetHAnchor/SetVAnchor。鼠标换算现在用 world_scale 动态测量，不看锚点。
    self.h_anchor = ANCHOR_MIDDLE
    self.v_anchor = ANCHOR_MIDDLE
    -- ⭐ 面板本身不缩放（照搬简存：TerminalWidget 无 SetScale）。
    -- 分辨率自适应交给父级 hslot_vault_root（GetHUDScale 跟随）；
    -- 只有下方的网格层 gridroot 单独缩 GRID_SCALE，和简存 gridroot 同款。

    -- 用户手动拖动留下的偏移（相对默认位置），(0,0) = 屏幕正中
    self._offset = Vector3(0, 0, 0)
    -- 读上次的位置（按容器分开存）。
    -- ⚠️ BUG 修复：LoadSavedPos 命中缓存时会直接 return saved_pos[key]，
    -- 但异步读盘的回调只在「首次打开」把值写进 active_list._offset；
    -- 关掉再开时走缓存支路、回调不再触发，旧代码丢弃返回值 → _offset 回到 (0,0,0)
    -- → 面板又弹回正中。这里必须显式接收返回值。
    local cached_offset = LoadSavedPos(self.container_key)
    if cached_offset ~= nil then
        self._offset = cached_offset
    end

    self.owner = owner
    self.container_inst = container_inst
    self.container = container_inst.replica.container
    self.filter = "ALL"

    -- ⚠️ 不要在这里调 GetModConfigData：widget 模块不是 mod 的 main chunk 环境，
    -- 会抛 "modname must be supplied manually if calling GetModConfigData
    -- from an environment other than the mod's main chunk"（新档直接报错）。
    -- 诊断日志统一在 modmain 的 Open hook 里打（那边有 config）。

    -- ⭐ 窗口外框：官方 TEMPLATES.RectangleWindow，**完全保留模板原生缩放**
    -- （templates.lua:1813 自带 SetScale(0.7)）——简存 InitPanel:109 就是这么用的，
    -- 从不覆盖。之前 SetScale(1,1,1) 覆盖了官方 0.7，破坏了官方缩放链。
    self.frame = self:AddChild(TEMPLATES.RectangleWindow(PANEL_W, PANEL_H, ""))
    -- 金边里面整片染成主题色（蓝/紫/橙/黄）
    self.frame:SetBackgroundTint(self.bg_r, self.bg_g, self.bg_b, FRAME_BG_ALPHA)

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
    self.info = self:AddChild(Text(NEWFONT_OUTLINE, INFO_SIZE, ""))
    self.info:SetRegionSize(INFO_W, 44)
    self.info:SetHAlign(ANCHOR_RIGHT)
    self.info:SetPosition(NUM_X, FILTER_Y)  -- ⭐ 简存 numslots_text x=292
    self.info:SetClickable(false)

    -- ⭐ 分隔线：简存 InitPanel:133-136，y=144、700×5、白色 alpha0.4
    self.line = self:AddChild(Image("images/ui.xml", "line_horizontal_white.tex"))
    self.line:SetPosition(0, 144)
    self.line:SetTint(1, 1, 1, 0.4)
    self.line:ScaleToSize(700, 5)
    self.line:SetClickable(false)

    -- 顶部一行分类图标：用官方制作栏的 filterslot_frame / filterslot_bg
    -- （craftingmenu_widget.lua:736 MakeFilterButton 同款），选中态用官方 select 贴图
    self.filter_buttons = {}  -- button（Select/Unselect/tint 用）
    self.filter_roots = {}    -- 外层 w（位置/整体缩放用）
    self.filter_icons = {}
    self.filter_glows = {}
    -- ⭐ 简存 pos_x 从 -336 起、每格 +48（InitPanel:144-150）
    local x0 = FILTER_X0
    for i, def in ipairs(FILTER_DEFS) do
        -- ⭐ 逐行照抄简存 MakeFilterButton（terminalwidget.lua:184-226）：
        -- 外层 w → scalingroot:SetScale(39/64) → ImageButton(原图不缩放)，
        -- 图标 ScaleToSize(54,54) 再被 scalingroot 缩成 54×0.609≈33。
        -- 之前用 ForceImageSize(40)+图标(16) 导致图标只有简存的一半。
        local w = self:AddChild(Widget("filter_" .. def.id))
        local scalingroot = w:AddChild(Widget("ScalingRoot"))
        scalingroot:SetScale(FILTER_ICON / 64)

        local btn = scalingroot:AddChild(ImageButton(
            CRAFTING_ATLAS,
            "filterslot_frame.tex",
            "filterslot_frame_highlight.tex",
            nil,
            nil,
            "filterslot_frame_select.tex"
        ))
        btn:SetTooltip(def.label)
        btn:SetOnClick(function()
            self:SetFilter(def.id)
        end)
        w:SetPosition(x0 + (i - 1) * FILTER_GAP, FILTER_Y)

        local bg = btn:AddChild(Image(CRAFTING_ATLAS, "filterslot_bg.tex"))
        bg:SetTint(1, 1, 1, FILTER_BG_VISIBLE and 1 or 0)
        bg:SetClickable(false)

        local icon = btn:AddChild(Image(CRAFTING_ICONS_ATLAS, def.icon))
        icon:ScaleToSize(54, 54) -- 简存同款，再经 scalingroot 缩

        -- 白光叠加层：官方高亮框再复制一份，选中时做透明度呼吸
        local glow = btn:AddChild(Image(CRAFTING_ATLAS, "filterslot_frame_highlight.tex"))
        glow:ScaleToSize(70, 70)
        glow:SetTint(1, 1, 1, 0)
        glow:SetClickable(false)

        self.filter_buttons[def.id] = btn
        self.filter_roots[def.id] = w
        self.filter_icons[def.id] = icon
        self.filter_glows[def.id] = glow
    end

    -- ⭐ 网格专用缩放层（照搬简存 terminalwidget.lua:813-815）：
    -- gridroot 只包住网格，SetScale(0.6)；面板边框/筛选/按钮都在 self 上不缩放。
    self.gridroot = self:AddChild(Widget("GridRoot"))
    self.gridroot:SetScale(GRID_SCALE)
    self.gridroot:SetPosition(GRID_CX, GRID_Y)

    -- ⭐ 官方 ScrollingGrid（templates.lua:1961）：和简存 TerminalScrolllist 同源，
    -- 缩放链完全交给官方模板。scissor 由 widget_width×列数 自动算，不再手算。
    -- 数据稍后由 RefreshData 用 SetItemsData 灌入。
    self.scrolllist = self.gridroot:AddChild(TEMPLATES.ScrollingGrid({}, {
        context = {},
        scroll_context = { owner = owner, container = self.container },
        widget_width = CELL,
        widget_height = CELL,
        -- ⭐ 2026-11-21 对齐简存 terminalwidget.lua:777-792 的 peek 参数：
        -- 官方模板默认 peek_height = widget_height*0.25 = 20，会把整个网格往下推；
        -- 简存显式 peek_percent=1 + peek_height=-5（负值往上收紧）。
        -- 之前漏了这两个 → 格子区比简存低约 7.5 屏幕像素（截图里最后一行贴住底部按钮）。
        -- templates.lua:1989 `grid:SetPosition(..., widget_height*(rows-1)/2 + peek_height/2)`，
        -- peek_height 从 20 → -5 让网格上移 (25/2)×0.6 = 7.5px。
        peek_percent = 1,
        peek_height = -5,
        num_visible_rows = ROWS,
        num_columns = COLS,
        item_ctor_fn = VaultItemCtor,
        apply_fn = VaultApply,
        scrollbar_offset = SCROLLBAR_GAP,
        scrollbar_height_offset = -50,  -- 简存 :789 = -50
        end_offset = 1,
    }))
    self.scrolllist:SetPosition(0, 0)

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
            -- ⭐ 中键复位不需要命中判定：面板开着时 anywhere 按中键都回中心。
            -- 之前中键和右键共用 IsMouseOverPanel() 门禁，命中判定一偏中键就跟着失效。
            if button == MOUSEBUTTON_MIDDLE then
                self:ResetToDefaultPos()
                return
            end
            -- 右键拖动才要求鼠标在面板内（避免抢占别处的右键查看物品）
            if not self:IsMouseOverPanel() then
                return
            end
            -- DRAG_EXCLUDE_GRID 为 true 时，格子区不接右键拖动
            if not (DRAG_EXCLUDE_GRID and self:IsMouseOverGrid()) then
                self:StartDrag(button)
            end
        elseif self._drag_button == button then
            self:EndDrag()
        end
    end)

    -- 容器变化时刷新（0.12 秒合并一次，160 格频繁存取也不刷屏）
    self.onchanged = function()
        self:QueueRefresh()
    end
    -- ⚠️ 同步滚动坑：口袋容器是**世界单例**（一个 hslot_container 全服共用），
    -- A 玩家放入物品 → 服务端 itemget 广播给所有打开者 → B 客户端也收到 itemget，
    -- 于是 B 的界面也 ScrollToDataIndex 跟着跳。
    -- 判据：只有「本地玩家背包刚失去物品」后短时间内收到的 itemget 才算我上传的，
    -- 才滚动；别人上传只刷新数据、不滚。
    -- 玩家物品栏失物 push 在 ThePlayer 上（inventory_classified.lua），
    -- 别的玩家失物不会同步到我这里，所以能可靠区分操作者。
    self._my_put_until = 0
    self.onplayeritemlose = function()
        self._my_put_until = GetTime() + 0.5
    end
    if ThePlayer ~= nil then
        ThePlayer:ListenForEvent("itemlose", self.onplayeritemlose)
    end

    -- 放入物品后跳到对应格子（仅自己上传时；非堆叠物品时容器会带 data.slot）
    self.onitemget = function(_, data)
        if data ~= nil and data.slot ~= nil and GetTime() <= (self._my_put_until or 0) then
            self._pending_slot = data.slot
            self._my_put_until = 0 -- 一次失物只对应一次滚动，避免连滚
        end
        self:QueueRefresh()
    end
    container_inst:ListenForEvent("itemget", self.onitemget)
    container_inst:ListenForEvent("itemlose", self.onchanged)
    container_inst:ListenForEvent("refresh", self.onchanged)

    -- 位置：默认居中（制作栏开着就右移让位），有记忆偏移时叠上去
    self:ApplyPos()
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
        local root = self.filter_roots[id]
        if id == self.filter then
            btn:Select()
            if root ~= nil then root:SetScale(FILTER_SCALE_ON) end -- 选中整体放大
        else
            btn:Unselect()
            if root ~= nil then root:SetScale(1) end
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
-- ⭐ 2026-11-21 重写：改用「简易存储 3383078008」terminalwidget.lua:967-993
-- 的 world_scale 动态测量法，替代原先抄「UI拖拽缩放」的那套锚点换算。
--
-- 原因：面板改挂 hslot_vault_root（containerroot.parent + SetScale(GetHUDScale)）
-- 后，旧 GetMouseLocalPos 里按 ui.h_anchor/v_anchor 做的屏幕换算前提不成立，
-- 算出的鼠标局部坐标整体偏移 → IsMouseOverPanel() 恒 false → 右键/中键被吞。
-- 简存同款挂载结构下它的拖动一直正常，直接照搬它的坐标 scheme。
--
-- 做法：临时把 widget 挪 10 单位，看 GetWorldPosition 变化多少 → 得到
-- world_scale（世界坐标 / 局部坐标 的比例），之后用它双向换算，不依赖锚点假设。

-- 动态测量本 widget 的「世界坐标/局部坐标」比例（结果缓存）
function HslotVaultList:RefreshWorldScale()
    local old_local = self:GetPosition()
    local old_world = self:GetWorldPosition()
    self:SetPosition(old_local + Vector3(10, 10, 0))
    local new_world = self:GetWorldPosition()
    self:SetPosition(old_local)
    local wx = new_world.x - old_world.x
    local wy = new_world.y - old_world.y
    self._world_scale = Vector3(
        (wx ~= 0) and (10 / wx) or 1,   -- 局部 / 世界
        (wy ~= 0) and (10 / wy) or 1,
        1
    )
end

-- 鼠标屏幕坐标 → 本 widget 局部坐标（和 GetPosition 同一坐标系）
-- mouse_pos 可传入（MoveHandler 给的 x,y），不传则用 TheInput 当前位置
function HslotVaultList:GetMouseLocal(mouse_pos)
    if self._world_scale == nil then
        self:RefreshWorldScale()
    end
    local m = mouse_pos or TheInput:GetScreenPosition()   -- 一个 Vector3，不是两个数字
    local w = self:GetWorldPosition()
    local s = self._world_scale
    return Vector3(
        (m.x - w.x) * s.x,
        (m.y - w.y) * s.y,
        0
    )
end

-- ====================================================================
-- 拖动（照搬「能力勋章 1909182187」medal_globalfn.lua:540-568 的起始快照法）
-- ====================================================================
-- ⭐ 防抖关键：只记录「按下瞬间」的鼠标/面板坐标，之后每次 move 用
--   newpos = p_start + (鼠标 - m_start) × world_scale
--   全程**不再读实时 GetWorldPosition()**。旧版每次 move 都 GetMouseLocal →
--   读 GetWorldPosition，而它基于刚 SetPosition 的值（同帧未必刷新），
--   形成「读自己写的结果」的反馈环 → 面板抖动。
function HslotVaultList:StartDrag(button)
    if self._draghandler ~= nil then
        return
    end
    if self._world_scale == nil then
        self:RefreshWorldScale()
    end
    self._drag_button = button or MOUSEBUTTON_RIGHT
    -- 起始快照（勋章 m_startpos / p_startpos）
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
    end)
end

-- ====================================================================
-- 位置：默认屏幕正中，打开制作栏时右移让位
-- ====================================================================
-- 父级 controls.containerroot 自带 MIDDLE 锚点 + SCALEMODE_PROPORTIONAL
-- （controls.lua:261-264），所以位置 (0,0) 就是屏幕正中，不需要自己按
-- 屏幕比例去推算 —— 这正是「简易存储」能「一开出来就在画面中心」的原因
-- （main/ui.lua:10-13：挂到 containerroot 同级，只套一个 GetHUDScale，
--  面板自己永远 SetPosition(0,0)）。之前那套 MeasureScale / FitPanelSize
-- 是「先按屏幕比例硬算一遍」，屏幕一变就整体走形，已删除。
function HslotVaultList:DefaultPos()
    -- ⭐ 2026-11-21 简化：默认位置恒为屏幕正中，不再随制作栏开/关右移。
    -- 旧逻辑按 IsCraftingOpen 在 0↔260 间跳，且制作栏 hook 的 ApplyPos(true)
    -- 与中键复位的 ApplyPos(true) 互相打断 → 中键"复位"到 260 而非中心，效果像失效。
    -- 现在位置只有一个变量：_offset（用户拖动偏移），中键永远回 (0,0)。
    return Vector3(0, 0, 0)
end

-- 实际位置 = 默认位置(0,0) + 用户拖动留下的偏移
-- smooth = true 时用 0.25 秒补间（中键复位/出画面回中心时用）
function HslotVaultList:ApplyPos(smooth)
    local base = self:DefaultPos()
    local o = self._offset or Vector3(0, 0, 0)
    local target = Vector3(base.x + o.x, base.y + o.y, 0)
    if smooth and self.inst ~= nil and self.inst:IsValid() then
        self:MoveTo(self:GetPosition(), target, 0.25)
    else
        self:SetPosition(target.x, target.y, 0)
    end
end

-- 面板中心是否已跑出画面（世界坐标 vs 屏幕尺寸）。
-- 测试存档里旧偏移可能把面板拖到屏幕外，打开后完全看不到 → 用这个判定自动回中心。
-- 只在「打开时 / 松手时」各查一次，不在 move 里查，避免反馈抖动。
function HslotVaultList:IsCenterOffScreen()
    local w = self:GetWorldPosition()
    local sw, sh = TheSim:GetScreenSize()
    -- 留一点容差：中心至少要在屏幕内（含 20px 边缘余量）
    local margin = 20
    return w.x < -margin or w.x > sw + margin
        or w.y < -margin or w.y > sh + margin
end

-- 若中心出画面则回默认位置并清偏移；返回是否真的重置了
function HslotVaultList:EnsureCenterOnScreen()
    if self:IsCenterOffScreen() then
        self:ResetToDefaultPos()
        return true
    end
    return false
end

-- 中键复原：偏移清零 → 回默认位置（居中 / 制作栏右侧）并写盘
function HslotVaultList:ResetToDefaultPos()
    self._offset = Vector3(0, 0, 0)
    self:ApplyPos(true)
    local key = PosKeyOf(self.container_key)
    saved_pos[key] = Vector3(0, 0, 0)
    TheSim:SetPersistentString(SAVE_KEY .. "_" .. key, "0.00,0.00", false)
end

-- ====================================================================
-- 鼠标命中判定
-- ====================================================================
-- ⭐ 2026-11-21 修复：GetMouseLocal() 现在返回的是「鼠标相对面板中心的偏移」
-- （m - GetWorldPosition，面板中心=原点），**不是**旧版的父级绝对坐标。
-- 所以这里直接用 loc.x/loc.y 跟半宽比，**绝不能再减 self:GetPosition()**——
-- 旧代码 loc - pos 在面板居中(pos≈0)时碰巧对，一旦拖到右上角(pos=+300,+200)
-- 就把命中区整体推到左上，导致中键/右键只有特定区域才响应。
function HslotVaultList:IsMouseOverPanel()
    local loc = self:GetMouseLocal()
    local lx, ly = self:GetLooseScale()
    lx = (lx ~= nil and lx ~= 0) and lx or 1
    ly = (ly ~= nil and ly ~= 0) and ly or 1
    return math.abs(loc.x) <= PANEL_W / 2 * lx
        and math.abs(loc.y) <= PANEL_H / 2 * ly
end

-- 鼠标是否落在格子（滚动列表可视区）里。
-- loc 已是相对面板中心的偏移；网格在 gridroot 内（位置 GRID_CX/GRID_Y，缩放 GRID_SCALE），
-- 所以减掉 gridroot 偏移即可（同样不再减 self:GetPosition()）。
function HslotVaultList:IsMouseOverGrid()
    local loc = self:GetMouseLocal()
    local dx = loc.x - GRID_CX
    local dy = loc.y - GRID_Y
    return math.abs(dx) <= (GRID_W / 2) * GRID_SCALE
        and math.abs(dy) <= (GRID_H / 2) * GRID_SCALE
end

function HslotVaultList:EndDrag()
    if self._draghandler ~= nil then
        self._draghandler:Remove()
        self._draghandler = nil
    end
    self._m_start = nil
    self._p_start = nil
    self._drag_button = nil
    -- 出画面则回中心（松手时查一次；拖到屏幕外不合法）
    if self:EnsureCenterOnScreen() then
        return
    end
    -- 记住这次拖到哪了（存「相对默认位置的偏移」，按容器分开），下次打开还在原地
    local key = PosKeyOf(self.container_key)
    local base = self:DefaultPos()
    local pos = self:GetPosition()
    self._offset = Vector3(pos.x - base.x, pos.y - base.y, 0)
    saved_pos[key] = self._offset
    TheSim:SetPersistentString(SAVE_KEY .. "_" .. key,
        string.format("%.2f,%.2f", self._offset.x, self._offset.y), false)
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
        -- ctor 时父级可能还没挂上、锚点还没生效，这里再套一次位置兜底。
        -- 位置 = 默认位置（居中 / 制作栏右侧）+ 上次拖动留下的偏移。
        self:ApplyPos()
        -- 存档里的旧偏移可能把面板拖出画面（测试存档就遇到过）→ 检测并回中心。
        -- ⚠️ 延迟一帧：同一帧内 SetPosition 后 GetWorldPosition 可能还没刷新，
        -- 下一帧世界矩阵更新后再读才准。
        self.inst:DoTaskInTime(0, function()
            if self.inst:IsValid() then
                self:EnsureCenterOnScreen()
            end
        end)
    end

    -- 兜底：官方的底图/按钮/槽位被任何途径（refresh、暂停恢复、别的 MOD 调 Show）
    -- 重新显示时再藏回去。
    -- ⚠️ 只藏「内容」，绝不藏 widget 本身 —— widget 不可见会让客户端认为容器没打开，
    -- 导致 Shift+左键转移、制作时材料识别全部失效（见 modmain 里的详细注释）。

    -- ⚠️ 合并堆叠时容器不推 itemget（components/container.lua:494/511 直接 return），
    -- 只改物品自己的 stacksize 网络变量，我们收不到任何事件。
    -- 所以低频率轮询一个「物品数 + 堆叠总量」签名，变了就刷新一次。
    self._poll = (self._poll or 0) + dt
    if self._poll >= POLL_INTERVAL then
        self._poll = 0
        local w = self.container_widget
        if w ~= nil and w.inst ~= nil and w.inst:IsValid() then
            if w._hslot_keep_visible then
                -- 保可见模式：只藏内容，widget 本身必须 visible（否则容器不算已打开）
                if w.bgimage ~= nil and w.bgimage.shown then w.bgimage:Hide() end
                if w.bganim ~= nil and w.bganim.shown then w.bganim:Hide() end
                if w.button ~= nil and w.button.shown then w.button:Hide() end
                if w.inv ~= nil then
                    for _, slot in pairs(w.inv) do
                        if slot ~= nil and slot.shown then slot:Hide() end
                    end
                end
            elseif w.shown then
                w:Hide()
            end
        end
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
-- 关闭按钮：按容器自己的 key 走通用 toggle（蓝= hslot，紫/橙/黄= *_fish）
function HslotVaultList:DoCloseButton()
    local key = self.container_key
    if key == nil then
        SendModRPCToServer(MOD_RPC["hslot_pocket"]["toggle_blue"])
        return
    end
    SendModRPCToServer(MOD_RPC["hslot_pocket"]["toggle"], key)
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
    if ThePlayer ~= nil and self.onplayeritemlose ~= nil then
        ThePlayer:RemoveEventCallback("itemlose", self.onplayeritemlose)
        self.onplayeritemlose = nil
    end
    if self.container_inst ~= nil and self.container_inst:IsValid() then
        self.container_inst:RemoveEventCallback("itemget", self.onitemget)
        self.container_inst:RemoveEventCallback("itemlose", self.onchanged)
        self.container_inst:RemoveEventCallback("refresh", self.onchanged)
    end
end

return HslotVaultList
