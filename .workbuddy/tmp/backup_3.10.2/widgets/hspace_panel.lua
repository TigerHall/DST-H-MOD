require "class"

local ItemTile = require "widgets/hspace_itemtile"
local InvSlot = require "widgets/hspace_invslot"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local UIAnim = require "widgets/uianim"
local ImageButton = require "widgets/imagebutton"
local TEMPLATES = require "widgets/redux/templates"
local TerminalScrolllist = require "widgets/hspace_scrolllist"

local chs = true  -- 本 mod 只做中文

local NAME_PINYIN = {}
-- 搜索框已去掉，pinyin 只做兜底 stub，避免残留代码引用 nil
local pinyin = function(s) return s end
local FILTER_ATLAS = resolvefilepath(CRAFTING_ICONS_ATLAS)
local FNS = require("hspace/terminalfn")
local FakeContainer = require("hspace/fakecontainer")
local HSpaceRPC = require("hspace/rpc")
local Log = require("hspace/log")

local FILTER_DEFS = {
    {name = "EVERYTHING", label = chs and "全部" or "Everything", atlas = FILTER_ATLAS, image = "filter_none.tex"},

    {name = "TOOLS", label = chs and "工具" or "Tools", atlas = FILTER_ATLAS, image = "filter_tool.tex", fn = FNS.tool_filter_fn},

    {name = "WEAPONS", label = chs and "武器" or "Weapons", atlas = FILTER_ATLAS, image = "filter_weapon.tex", fn = FNS.weapon_filter_fn},

	{name = "CLOTHING", label = chs and "装备&衣服" or "Armor & Clothing", atlas = FILTER_ATLAS, image = "filter_warable.tex", fn = FNS.warable_filter_fn},

    {name = "REFINE", label = chs and "精炼" or "Refine", atlas = FILTER_ATLAS,	image = "filter_refine.tex", fn = FNS.refine_filter_fn},

    {name = "MAGIC", label = chs and "魔法" or "Magic", atlas = FILTER_ATLAS, image = "filter_skull.tex", fn = FNS.magic_filter_fn},

    {name = "GARDENING", label = chs and "食物&耕种" or "Food & Gardening", atlas = FILTER_ATLAS, image = "filter_gardening.tex", fn = FNS.gardening_filter_fn},

    {name = "FAVORITES", label = chs and "使用F键收藏物品" or "Collect items with key F", atlas = FILTER_ATLAS, image = "filter_favorites.tex", fn = FNS.favorites_filter_fn},
}

local SORTMODE = {
    QUANTITY = 1,
    STRING = 2,
}

local HspacePanel = Class(Widget, function(self, owner, vault_id)
    Widget._ctor(self, "HspacePanel")
    self.owner = owner
    self.vault_id = vault_id or "hslot"
    self._offset = Vector3(0, 0, 0)

    if self.owner.HUD:IsCraftingOpen() then
        self:SetPosition(260, 0, 0)
    else
        self:SetPosition(0, 0, 0)
    end

    self.bgroot = self:AddChild(Widget("HspacePanelBGRoot"))

    self.root = self:AddChild(Widget("HspacePanelRoot"))

    self.left_root = self:AddChild(Widget("HspacePanelLeftRoot"))
    self.left_root:SetPosition(-410, 0)

    self.isopen = false
    self.containers = {}

    self.itempool = {}
    self.grouped_itempool = {}

    self.griddata = {}
    self.itemnum = {}

    self.inv = {}

    self.sortmode = FNS.get_sortmode()

    -- ===== 右键拖动 / 中键复位（简存没有这个功能，从旧 hslot_vault_list 搬）=====
    self:LoadSavedPos()
    self._mousebtn = TheInput:AddMouseButtonHandler(function(button, down)
        if not self.isopen then
            return
        end
        if button == MOUSEBUTTON_RIGHT then
            if down then
                if self:IsMouseOverPanel() then
                    Log.D("panel", "右键开始拖动")
                    self:StartDrag()
                end
            else
                self:EndDrag()
            end
        elseif button == MOUSEBUTTON_MIDDLE then
            -- 中键不复用别的功能，面板开着就复位（不再判断命中，
            -- 之前用世界坐标估算矩形经常算偏，导致按了没反应）
            if down then
                self:ResetToDefaultPos()
            end
        end
    end)
end)

-- 打开面板：containers 是 { [GUID] = 真实容器实体 }
-- ⭐ 回到真实容器方案：物品真的存在容器里，
--    所以 Insight 识别、右键检查、完整物品信息全部天然可用。
function HspacePanel:Open(containers)
    self:Close()

    self.isopen = true
    self.containers = containers or {}

    self:InitPanel()
    self:Refresh()

    self:Show()
    self:Enable()
end

function HspacePanel:InitPanel()

    if not self.bg then

        local str1 = chs and "排序: " or "Sort: "
        local str2 = {
            [SORTMODE.QUANTITY] = chs and "数量" or "Quantity",
            [SORTMODE.STRING] = chs and "字母" or "Alphabet",
        }

        local function sortfn()
            self.sortmode = (self.sortmode == SORTMODE.QUANTITY) and SORTMODE.STRING or SORTMODE.QUANTITY
            FNS.save_sortmode(self.sortmode)
            self.bgbuttons[1]:SetText(str1..str2[self.sortmode])
            self:MakeInvGrid()
        end

        local function closefn()
            self:DoCloseAction()
        end

        self.bg = self.bgroot:AddChild(TEMPLATES.RectangleWindow(680, 420, "", {
            {text = str1..str2[self.sortmode], cb = sortfn},
            {text = chs and "关闭终端" or "Close Terminal", cb = closefn},
        }))

        self.bgbuttons = {
            [1] = self.bg.actions.items[1],
            [2] = self.bg.actions.items[2],
        }

        for i, button in ipairs(self.bgbuttons) do
            button:ClearFocusDirs()
            -- 手柄兼容
            button.Highlight = function(button) button:SetFocus() end
            button.DeHighlight = function(button) button:ClearFocus() end
            button.hide_cursor = true
            button.is_terminal_button = true
        end

        self.bg:SetBackgroundTint(0, 0, 0, 0.6)

        -- 右键拖动改由 TheInput:AddMouseButtonHandler 处理（见构造函数）：
        -- TEMPLATES.RectangleWindow 的根 widget 收不到 OnControl，
        -- 挂在这里右键永远不会触发。
    end

    if not self.line then

        self.line = self.root:AddChild(Image("images/ui.xml", "line_horizontal_white.tex"))
        self.line:SetPosition(0, 144)
        self.line:SetTint(1, 1, 1, 0.4)
        self.line:ScaleToSize(700, 5)
    end

    if not self.filterpanel then
        
        self.filterpanel = self.root:AddChild(Widget("FilterPanel"))
        self.filterpanel:SetPosition(0, 175)

        local pos_x = -336
        self.filterbuttons = {}
        for i, filter_def in ipairs(FILTER_DEFS) do
            local filterbutton = self:MakeFilterButton(filter_def)
            self.filterbuttons[filter_def.name] = self.filterpanel:AddChild(filterbutton)
            self.filterbuttons[filter_def.name]:SetPosition(pos_x, 0)
            pos_x = pos_x + 48
        end

        local text_size = chs and 30 or 28
        self.numslots_text = self.filterpanel:AddChild(Text(BODYTEXTFONT, text_size))
        self.numslots_text:SetPosition(292, 0)
        self.numslots_text:SetString("")

        self:SelectFilter("EVERYTHING")
    end

    -- 侧边栏去掉：我们只有一个数据仓库，没有多容器可选
end

-- filter button
function HspacePanel:SelectFilter(name)
    if name == self.current_filter_name then
        return
    end
    if self.current_filter_name then
        self.filterbuttons[self.current_filter_name].button:Unselect()
    end
    self.filterbuttons[name].button:Select()
    self.current_filter_name = name
end

function HspacePanel:MakeFilterButton(filter_def)
    local button_size = 39
	local atlas = resolvefilepath(CRAFTING_ATLAS)

	local w = Widget("filter_"..filter_def.name)
    w.scalingroot = w:AddChild(Widget("ScalingRoot"))
	w.scalingroot:SetScale(button_size/64)

	local button = w.scalingroot:AddChild(ImageButton(atlas, "filterslot_frame.tex", "filterslot_frame_highlight.tex", nil, nil, "filterslot_frame_highlight.tex"))
	w.button = button
	button:SetOnClick(function()
		self:SelectFilter(filter_def.name)
	end)
	button:SetOnSelect(function()
        -- 设置筛选函数
        self.filter_fn = filter_def.fn -- or nil
        -- 搜索框已去掉，这里只清掉搜索态，不能再碰 self.searchbox（是 nil）
        if filter_def.name ~= "EVERYTHING" then
            self:SetSearchText(nil)
        end
        -- 刷新UI
        self:MakeInvGrid()
        w.bg:SetTexture(atlas, "filterslot_bg_highlight.tex")
	end)
	button:SetOnUnSelect(function()
        w.bg:SetTexture(atlas, "filterslot_bg.tex")
	end)

    w:SetTooltip(filter_def.label)

	w.focus_forward = button

	----------------
	local filter_atlas = FunctionOrValue(filter_def.atlas, self.owner, filter_def)
	local filter_image = FunctionOrValue(filter_def.image, self.owner, filter_def)

	local filter_img = button:AddChild(Image(filter_atlas, filter_image))

	filter_img:ScaleToSize(54, 54)

	filter_img:MoveToBack()
	w.filter_img = filter_img

	w.filter_def = filter_def

	w.bg = button:AddChild(Image(atlas, "filterslot_bg.tex"))
	w.bg:MoveToBack()

    -- 用于手柄
    w.Highlight = function() self:SelectFilter(filter_def.name) end
    w.DeHighlight = function() end
    w.hide_cursor = true
    w.is_terminal_filter = true

	return w
end

-- favorite
function HspacePanel:ToggleFavorite(itemtile)
    -- 收藏功能暂时禁用（简存用独立文件存收藏，我们还没做持久化）
end

-- search box
function HspacePanel:SetSearchText(str)
    if type(str) == "string" and str:len() > 0 then
        self.search_str = string.lower(str)
    else
        -- 退出搜索状态
        self.search_str = nil
    end
end

local function CheckChinese(s)
	local f = '[%z\1-\127\194-\244][\128-\191]*'
	local line, lastLine, isBreak = '', false, false
	for v in s:gfind(f) do
		local isChinese = (#v~=1)
		if isChinese then
            return s
		end
	end
	return nil
end

function HspacePanel:MakeSearchBox(box_width, box_height)
    local searchbox = Widget("search")

    searchbox.textbox_root = searchbox:AddChild(TEMPLATES.StandardSingleLineTextEntry(nil, box_width, box_height))
    searchbox.textbox = searchbox.textbox_root.textbox
    searchbox.textbox:SetTextLengthLimit(200)
    searchbox.textbox:SetForceEdit(true)
    searchbox.textbox:EnableWordWrap(false)
    searchbox.textbox:EnableScrollEditWindow(true)
    searchbox.textbox:SetHelpTextEdit("")
    searchbox.textbox:SetHelpTextApply(STRINGS.UI.SERVERCREATIONSCREEN.SEARCH)
    searchbox.textbox:SetTextPrompt("English/拼音", UICOLOURS.GREY)
    searchbox.textbox.prompt:SetHAlign(ANCHOR_MIDDLE)
    searchbox.textbox.OnTextInputted = function()
        -- 切换到EVERYTHING
        self:SelectFilter("EVERYTHING")
        -- 设置SearchText
		self:SetSearchText(self.searchbox.textbox:GetString())
        -- 刷新
        self:MakeInvGrid()
    end

    searchbox:SetOnGainFocus(function() searchbox.textbox:OnGainFocus() end)
    searchbox:SetOnLoseFocus(function() searchbox.textbox:OnLoseFocus() end)

    searchbox.focus_forward = searchbox.textbox

    self.search_filter_fn = function(data)
        if data then
            -- 根据prefab名匹配
            if data.prefab then
                local s = tostring(data.prefab)
                if string.find(s, self.search_str, 1, true) then
                    return true
                end
            end
            -- 根据name匹配
            if data.item and data.item:IsValid() then
                local name = data.item:GetBasicDisplayName()
                local py
                if NAME_PINYIN[name] then
                    -- 已经保存的中文name
                    py = NAME_PINYIN[name]
                else
                    if CheckChinese(name) then
                        -- 未保存的中文name
                        py = pinyin(name, true, "")
                        NAME_PINYIN[name] = py
                    else
                        -- 其他语言直接匹配name
                        name = string.lower(name)
                        return string.find(name, self.search_str, 1, true)
                    end
                end
                -- 尝试根据拼音匹配
                return string.find(py, self.search_str, 1, true)
            end
        end
        return false
    end

    return searchbox
end

-- show available slots
local function GetAvailableNumslots(containers, unselect_containers)
    unselect_containers = unselect_containers or {}
    local available = 0
    local total = 0

    for guid, container in pairs(containers) do
        if not unselect_containers[container.prefab] then
            local numslots = container.replica.container:GetNumSlots()
            total = total + numslots
            for slot = 1, numslots do
                local item = container.replica.container:GetItemInSlot(slot)
                if item == nil then
                    available = available + 1
                end
            end
        end
    end
    -- 剩余格子/总的格子
    return available, total
end

function HspacePanel:RefreshPanel()
    -- 刷新剩余格子数
    local unselect_containers = self:GetUnselectContainers()
    local available_slots, total_slots = GetAvailableNumslots(self.containers, unselect_containers)
    local numslots_str

    if chs then
        numslots_str = "容量: "..tostring(available_slots).."/"..tostring(total_slots)
    else
        numslots_str = "Usable: "..tostring(available_slots).."/"..tostring(total_slots)
    end

    self.numslots_text:SetString(numslots_str)
    if available_slots == 0 then
        self.numslots_text:SetColour(1, 0.4, 0.4, 1)
    else
        self.numslots_text:SetColour(1, 1, 1, 1)
    end
end

-- RefreshItem fns
local function AddItemToGroup(self, new_data)
    -- item get
    local prefab = new_data.prefab
    if self.grouped_itempool[prefab] == nil then
        self.grouped_itempool[prefab] = {}
    end
    local skinname = new_data.skinname or "nil"
    if self.grouped_itempool[prefab][skinname] == nil then
        self.grouped_itempool[prefab][skinname] = {
            [0] = 0, --总数
        }
    end
    -- prefab总数
    local stacksize = new_data.stacksize
    if self.itemnum[prefab] == nil then
        self.itemnum[prefab] = 0
    end
    self.itemnum[prefab] = self.itemnum[prefab] + math.max(stacksize, 1)
    -- prefab - skin总数
    local tbl = self.grouped_itempool[prefab][skinname]
    tbl[0] = tbl[0] + stacksize
    table.insert(tbl, new_data)
end

local function RemoveItemFromGroup(self, old_data)
    -- item lose
    local prefab = old_data.prefab
    if self.grouped_itempool[prefab] == nil then
        return
    end
    local skinname = old_data.skinname or "nil"
    if self.grouped_itempool[prefab][skinname] == nil then
        return
    end
    local tbl = self.grouped_itempool[prefab][skinname]
    for i, data in ipairs(tbl) do
        if data == old_data then
            table.remove(tbl, i)
            break
        end
    end
    -- prefab总数
    local stacksize = old_data.stacksize
    if self.itemnum[prefab] then
        self.itemnum[prefab] = self.itemnum[prefab] - math.max(stacksize, 1)
    end
    -- prefab - skin总数
    if tbl[1] == nil then
        self.grouped_itempool[prefab][skinname] = nil
        return
    end
    tbl[0] = tbl[0] - stacksize
end

local function CtorItemData(item, container, slot)
    local stacksize = item.replica.stackable and item.replica.stackable:StackSize() or 0
    local skinname = item.skinname or item.AnimState:GetSkinBuild()
    local new_data = {
        item = item,
        stacksize = stacksize,
        prefab = item.prefab,
        skinname = skinname,
        container = container,
        slot = slot,
    }
    return new_data
end

local function RefreshSingleItem(self, container, slot)
    -- print("RefreshSingleItem")
    -- 检查格子里是否有新物品
    local new_data, added
    local item = container.replica.container:GetItemInSlot(slot)
    if item then
        new_data = CtorItemData(item, container, slot)
    end
    -- 移除这个格子原来的物品(如果有)
    local guid = container.GUID
    for i, old_data in ipairs(self.itempool) do
        if old_data.container.GUID == guid and old_data.slot == slot then
            RemoveItemFromGroup(self, old_data)
            if new_data then
                self.itempool[i] = new_data
                AddItemToGroup(self, new_data)
                added = true
            else
                table.remove(self.itempool, i)
            end
            break
        end
    end
    -- 如果前面还未添加新物品
    if new_data and not added then
        table.insert(self.itempool, new_data)
        AddItemToGroup(self, new_data)
    end
end

local function RefreshSingleContainer(self, container)
    local guid = container.GUID
    local new_itempool = {}
    -- 保留不是这个容器的物品
    for i, old_data in ipairs(self.itempool) do
        if old_data.container.GUID == guid then
            RemoveItemFromGroup(self, old_data)
        else
            table.insert(new_itempool, old_data)
        end
    end
    self.itempool = new_itempool
    -- 仅关闭用途
    if container.only_for_close then
        return
    end
    -- 重新遍历这个容器的物品
    local numslots = container.replica.container:GetNumSlots()
    for slot = 1, numslots do
        local item = container.replica.container:GetItemInSlot(slot)
        if item then
            local new_data = CtorItemData(item, container, slot)
            table.insert(self.itempool, new_data)
            --------------------------------------------------
            AddItemToGroup(self, new_data)
        end
    end
end

local function RefreshAllContainers(self)
    -- 初始化的时候
    self.itempool = {}
    self.grouped_itempool = {}
    for guid, container in pairs(self.containers) do
        local numslots = container.replica.container:GetNumSlots()
        --遍历格子
        for slot = 1, numslots do
            local item = container.replica.container:GetItemInSlot(slot)
            if item then
                local new_data = CtorItemData(item, container, slot)
                table.insert(self.itempool, new_data)
                --------------------------------------------------
                AddItemToGroup(self, new_data)
            end
        end
    end
end

-- handle item change
function HspacePanel:RefreshItemPool(container, slot)
    if container and slot then
        -- print("refresh item in slot " .. slot .. " of container " .. container.GUID)
        RefreshSingleItem(self, container, slot)
    elseif container then
        -- print("refresh container " .. container.GUID)
        RefreshSingleContainer(self, container)
    else
        -- print("refresh all containers")
        RefreshAllContainers(self)
    end
end

function HspacePanel:RefreshGridData()
    -- ⚠️ 刻意**不做**简存那种「同 prefab 跨容器合并成一格」：
    --    合并后 overridequantity 显示的是总数，但点一下只能取到 tbl[choose]
    --    那一条记录，于是出现「显示 120、实际只给 40」的错位。
    --    我们这里是 1 条记录 = 1 格，取物和数字永远对得上。
    self.griddata = {}
    for i = 1, #self.itempool do
        local data = self.itempool[i]
        if data ~= nil and data.item ~= nil then
            table.insert(self.griddata, shallowcopy(data))
        end
    end
end

-- filter and sort
local function ApplyFilter(griddata, filter_fn)
    if not filter_fn then
        return griddata
    end
    local ret = {}
    for i, data in ipairs(griddata) do
        if filter_fn(data) then
            table.insert(ret, data)
        end
    end
    return ret
end

local function SortGridData(griddata, sortmode)

    local function sortbyquantity(l, r)
        if l.overridequantity and r.overridequantity then
            if l.overridequantity == r.overridequantity then
                return nil
            else
                return l.overridequantity > r.overridequantity
            end
        elseif l.overridequantity then
            return true
        elseif r.overridequantity then
            return false
        else
            return nil
        end
    end

    local function sortbyprefab(l, r)
        if l.prefab and r.prefab and l.prefab ~= r.prefab then
            return tostring(l.prefab) < tostring(r.prefab)
        else
            return nil
        end
    end

    local function sortbyskinname(l, r)
        if l.skinname and r.skinname and l.skinname ~= r.skinname then
            return tostring(l.skinname) < tostring(r.skinname)
        elseif l.item and r.item then
            -- 皮肤相同根据guid排序
            return l.item.GUID < r.item.GUID
        else
            -- 这里无论如何只能返回false
            return false
        end
    end

    local ret = shallowcopy(griddata)
    if sortmode == SORTMODE.QUANTITY then
        table.sort(ret,
        function(l, r)
            -- 数量
            local result = sortbyquantity(l, r)
            if result ~= nil then return result end
            -- prefab
            result = sortbyprefab(l, r)
            if result ~= nil then return result end
            -- skinname
            return sortbyskinname(l, r)
        end)
    elseif sortmode == SORTMODE.STRING then
        table.sort(ret,
        function(l, r)
            -- prefab
            local result = sortbyprefab(l, r)
            if result ~= nil then return result end
            -- 数量
            result = sortbyquantity(l, r)
            if result ~= nil then return result end
            -- skinname
            return sortbyskinname(l, r)
        end)
    end
    return ret
end

-- refresh filter/sort only
function HspacePanel:MakeInvGrid()
    local griddata = self.griddata or {}

    -- 基础筛选（分类\搜索）
    local filter_fn = self.search_str and self.search_filter_fn or self.filter_fn
    griddata = ApplyFilter(griddata, filter_fn)

    -- 按侧边栏容器筛选
    griddata = ApplyFilter(griddata, self.sidebar_filter_fn)

    -- 排序
    griddata = SortGridData(griddata, self.sortmode)

    if not self.grid then
        local row_w = 64
        local row_h = 64
        local row_spacing = 16
        local atlas = resolvefilepath(CRAFTING_ATLAS)

        local function GridInvCtor(context, index)
            local w = Widget("terminal-inv-cell-".. index)

            -- ⚠️ 简存原版签名是 InvSlot(num, atlas, bgim, owner, container)，
            --    第一个参数是**槽位号**不是 atlas。少了这个 nil 会把
            --    "images/hud.xml" 当 num、"inv_slot.tex" 当 atlas →
            --    Image("inv_slot.tex", nil) → resolvefilepath 断言崩溃。
            local invslot = InvSlot(
                nil,
                "images/hud.xml",
                "inv_slot.tex",
                self.owner,
                nil
            )
            -- 简存原版：先塞一个空 ItemTile 占位，之后只改 tile.fakeitem 再 Refresh
            invslot:SetTile(ItemTile())

            invslot:SetOnGainFocus(function()
                self:HighlightContainerIcon(invslot.container_prefab)
            end)

            -- 用于手柄兼容
            invslot.terminal_index = index
            self.inv[index] = invslot

            invslot.terminalwidget = self

            w.invslot = w:AddChild(invslot)
            w.focus_forward = w.invslot

            return w
        end

        local function GridInvSetData(context, widget, data, index)
            local invslot = widget.invslot
            local tile = invslot.tile
            if tile == nil then
                return
            end

            local old_fakeitem = tile.fakeitem
            local old_overridequantity = tile.overridequantity

            if data then
                -- ⭐ 回到真实容器语义：slot / container 都来自真容器
                invslot.container = data.container.replica.container
                invslot.container_prefab = data.container.prefab
                invslot.num = data.slot

                if data.item then
                    tile.fakeitem = data.item
                    tile.overridequantity = data.overridequantity
                else
                    tile.fakeitem = nil
                    tile.overridequantity = nil
                end
            else
                invslot.container = nil
                invslot.container_prefab = nil
                invslot.num = nil

                tile.fakeitem = nil
                tile.overridequantity = nil
            end

            if old_fakeitem ~= tile.fakeitem
                or old_overridequantity ~= tile.overridequantity then
                tile:Refresh()
            end

            invslot.terminal_index = index
            self.inv[index] = invslot

            if invslot.focus and invslot.ongainfocusfn ~= nil then
                invslot.ongainfocusfn()
            end
        end

        local grid = TerminalScrolllist(
        griddata,
        {
            context = {},
            widget_width  = row_w+row_spacing,
            widget_height = row_h+row_spacing,
            peek_percent     = 1,
            num_visible_rows = 6,
            num_columns      = 15,
            item_ctor_fn = GridInvCtor,
            apply_fn     = GridInvSetData,
            scrollbar_offset = 8,
            scrollbar_height_offset = -50,
            end_offset = 1,
            peek_height = -5,
        })
    
        grid.up_button:SetTextures(atlas, "scrollbar_arrow_up.tex", "scrollbar_arrow_up_hl.tex")
        grid.up_button:SetScale(0.4)
    
        grid.down_button:SetTextures(atlas, "scrollbar_arrow_down.tex", "scrollbar_arrow_down_hl.tex")
        grid.down_button:SetScale(0.4)
    
        grid.scroll_bar_line:SetTexture(atlas, "scrollbar_bar.tex")
        grid.scroll_bar_line:ScaleToSize(11, grid.scrollbar_height - 15)
    
        grid.position_marker:SetTextures(atlas, "scrollbar_handle.tex")
        grid.position_marker.image:SetTexture(atlas, "scrollbar_handle.tex")
        grid.position_marker:SetScale(.3)

        grid.custom_focus_check = function() return self.focus end

        grid:SetOnLoseFocus(function()
            self:HighlightContainerIcon(nil)
        end)

        local scale = 0.6
        self.gridroot = self.root:AddChild(Widget("GridRoot"))
        self.gridroot:SetScale(scale,scale,scale)
        self.gridroot:SetPosition(0, -30, 0)

        self.grid = self.gridroot:AddChild(grid)

        self.grid.OnFocusMove = function(self, dir, down) end
        self.grid:Show()

        self.focus_forward = self.grid
    else
        self.grid:SetItemsData(griddata)
    end

end

-- compeltely refresh
function HspacePanel:Refresh(container, slot)
    if next(self.containers) == nil then
        self:DoCloseAction()
        return
    end

    -- 物品变动数据刷新
    self:RefreshItemPool(container, slot)
    self:RefreshGridData()

    -- UI刷新
    self:MakeInvGrid()
    self:RefreshPanel()
end

-- close
function HspacePanel:DoCloseAction()
    self:Close()
    local hud = ThePlayer ~= nil and ThePlayer.HUD or nil
    if hud ~= nil and hud.controls ~= nil
        and hud.controls.CloseHspacePanel ~= nil then
        hud.controls:CloseHspacePanel(self.vault_id)
    end
    self:OnDestroy()
    self:Kill()
end

function HspacePanel:Close()
    -- 关闭ui
    if self.isopen then

        self.containers = {}

        self.itempool = {}
        self.grouped_itempool = {}

        self.griddata = {}
        self.itemnum = {}

        self.inv = {}

        if self.searchbox then
            self.searchbox.textbox:SetString("")
            self:SetSearchText(nil)
        end

        self.isopen = false

        self:ClearFocus()
        self:Hide()
        self:Disable()
    end
end

-- builder count item
function HspacePanel:CalcItemNum(prefab)
    return self.itemnum[prefab] or 0

    -- local data = self.grouped_itempool

    -- local skin_tbl = data[prefab]
    -- if skin_tbl == nil then return 0 end

    -- local num_add = 0
    -- for skinname, tbl in pairs(skin_tbl) do
    --     if tbl[0] and tbl[0] > 0 then --可堆叠物品
    --         num_add = num_add + tbl[0]
    --     else
    --         num_add = num_add + #tbl
    --     end
    -- end

    -- return num_add
end

-- sidebar fn
function HspacePanel:HighlightContainerIcon(container_prefab)
    -- 没有侧边栏，无需高亮容器图标
end

function HspacePanel:GetUnselectContainers()
    return self.sidebar and self.sidebar.unselect_containers or {}
end

-- handle drag
function HspacePanel:OnControl(control, down)
    if HspacePanel._base.OnControl(self, control, down) then return true end
    if control == CONTROL_ACCEPT and down then
        self.ispressed = true
        self.startpress_time = GetTime()
        self:StartUpdating()
        return true
    else
        self.ispressed = false
    end
end

function HspacePanel:OnUpdate(dt)
    -- 右键拖动位移
    if self._drag_from ~= nil then
        local m = TheInput:GetScreenPosition()
        local dx = m.x - self._drag_from.x
        local dy = m.y - self._drag_from.y
        -- ⚠️ 死区：右键在格子上是"取 1 个"，全局 handler 也会 StartDrag，
        -- 没有这个阈值的话轻点一下格子面板就会跟着挪几像素
        if math.abs(dx) + math.abs(dy) < 6 then
            return
        end
        self._offset = Vector3(self._drag_from.ox + dx, self._drag_from.oy + dy, 0)
        self:ApplyPos()
    end

    if TheInput:IsControlPressed(CONTROL_PRIMARY) then
        if self.isdragging then
            return
        elseif GetTime() > self.startpress_time + 0.1 then
            self.isdragging = true
            self:RefreshWorldScale()
            self.drag_offset = TheInput:GetScreenPosition() - self:GetWorldPosition()
            self:FollowMouse()
        end
    else
        self.ispressed = false
        self.isdragging = false
        self:StopFollowMouse()
        self:StopUpdating()
    end
end

function HspacePanel:FollowMouse()
    if self.followhandler == nil then
        self.followhandler = TheInput:AddMoveHandler(function(x, y) 
            self:SetWorldPositon(Vector3(x, y, 0)-self.drag_offset)
        end)
    end
end

function HspacePanel:StopFollowMouse()
    if self.followhandler ~= nil then
        self.followhandler:Remove()
        self.followhandler = nil
    end
end

function HspacePanel:RefreshWorldScale()
    local old_local_pt = self:GetPosition()
    local old_world_pt = self:GetWorldPosition()

    local local_offset = Vector3(10, 10, 0)
    local new_local_pt = old_local_pt + local_offset
    self:SetPosition(new_local_pt)

    local new_world_pt = self:GetWorldPosition()
    local world_offset = new_world_pt - old_world_pt

    self:SetPosition(old_local_pt)

    self.world_scale = Vector3(world_offset.x/local_offset.x, world_offset.y/local_offset.y, 0)
end

function HspacePanel:SetWorldPositon(pos)
    if self.world_scale == nil then
        self:RefreshWorldScale()
    end
    local world_scale = self.world_scale
    local local_pt = self:GetPosition()
    local world_pt = self:GetWorldPosition()
    local world_offset = pos - world_pt
    local local_offset = Vector3(world_offset.x/world_scale.x, world_offset.y/world_scale.y, 0)
    self:SetPosition(local_pt+local_offset)
end


-- ====================================================================
-- 拖动 / 位置记忆
-- ====================================================================
local POS_FILE = "hspace_ui_pos"
local SAVED_POS = nil

local function EnsurePos()
    if SAVED_POS ~= nil then
        return
    end
    SAVED_POS = {}
    TheSim:GetPersistentString(POS_FILE, function(ok, str)
        if ok and str ~= nil and #str > 0 then
            local success, t = pcall(function()
                return json.decode(str)
            end)
            if success and type(t) == "table" then
                SAVED_POS = t
            end
        end
    end, false)
end

function HspacePanel:LoadSavedPos()
    EnsurePos()
    local p = SAVED_POS ~= nil and SAVED_POS[self.vault_id] or nil
    if p ~= nil and p.x ~= nil then
        self._offset = Vector3(p.x, p.y or 0, 0)
    end
    self:ApplyPos()
end

-- 实际位置 = 默认位置（制作栏打开时右移 260）+ 用户拖动偏移
-- ⚠️ modmain 的 playerhud:OpenCrafting/CloseCrafting 会调这个，
--    方法名必须叫 ApplyPos（旧面板就是这个名字）
function HspacePanel:ApplyPos(smooth)
    local base_x = (self.owner ~= nil and self.owner.HUD ~= nil
        and self.owner.HUD.IsCraftingOpen ~= nil
        and self.owner.HUD:IsCraftingOpen()) and 260 or 0
    local target = Vector3(base_x + self._offset.x, self._offset.y, 0)
    if smooth and self.inst ~= nil and self.inst:IsValid() then
        self:MoveTo(self:GetPosition(), target, 0.25)
    else
        self:SetPosition(target.x, target.y, 0)
    end
end

function HspacePanel:SavePos()
    EnsurePos()
    if SAVED_POS == nil then
        SAVED_POS = {}
    end
    SAVED_POS[self.vault_id] = { x = self._offset.x, y = self._offset.y }
    local ok, str = pcall(function()
        return json.encode(SAVED_POS)
    end)
    if ok and str ~= nil then
        SavePersistentString(POS_FILE, str, ENCODE_SAVES)
    end
end

-- 鼠标是否落在窗口矩形内（用 bg 自己的世界坐标 + 世界缩放判断，最准）
function HspacePanel:IsMouseOverPanel()
    if self.bg == nil then
        return false
    end
    local m = TheInput:GetScreenPosition()
    local p = self.bg:GetWorldPosition()
    local sc = 1
    local ok, ws = pcall(function()
        return self.bg:GetWorldScale()
    end)
    if ok and type(ws) == "table" and ws.x ~= nil then
        sc = ws.x
    end
    return math.abs(m.x - p.x) <= (680 * sc) / 2
       and math.abs(m.y - p.y) <= (420 * sc) / 2
end

function HspacePanel:StartDrag()
    local m = TheInput:GetScreenPosition()
    self._drag_from = { x = m.x, y = m.y,
                        ox = self._offset.x, oy = self._offset.y }
    self._dragging = true
    self:StartUpdating()
end

function HspacePanel:EndDrag()
    if not self._dragging then
        return
    end
    self._dragging = false
    self._drag_from = nil
    self:SavePos()
end

function HspacePanel:ResetToDefaultPos()
    self._offset = Vector3(0, 0, 0)
    self:ApplyPos(true)
    self:SavePos()
end

function HspacePanel:OnDestroy()
    if self._mousebtn ~= nil then
        self._mousebtn:Remove()
        self._mousebtn = nil
    end
    local hud = ThePlayer ~= nil and ThePlayer.HUD or nil
    if hud ~= nil and hud.controls ~= nil
        and hud.controls.hspace_panel == self then
        hud.controls.hspace_panel = nil
    end
    -- ⚠️ 不要调 Widget.OnDestroy：官方 Widget 没有这个方法
end

return HspacePanel