-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })

local config = { hsee_enable = GetModConfigData("hsee_enable") }

PrefabFiles = { "hsee" }

Assets = {
  --Asset("ANIM", "anim/medal_skin_staff.zip"), -- 旧勋章素材，保留以备用
  Asset("ANIM", "anim/cutless.zip"),
  Asset("IMAGE", "images/inventoryimages/heh.tex"),
  Asset("ATLAS", "images/inventoryimages/heh.xml"),
  Asset("ANIM", "anim/ui_fish_box_5x4.zip"),
}

-- ========== 注册 HSee 的容器参数 ==========
-- 在 containers.params 中注册，这样客户端 replica 自动构造时能查到 widget 配置
-- （官方模式：fish_box / treasurechest 的 widget 都是通过 params 查找的）
do
  local containers = require("containers")
  local params = containers.params

  -- 拷贝鱼箱的 5×5 网格布局（原 5×4 扩展一行）
  local hsee_slotpos = {}
  for y = 3.5, -0.5, -1 do
    for x = -1, 3 do
      table.insert(hsee_slotpos, Vector3(
        75 * x - 75 * 2 + 75,
        75 * y - 75 * 2 + 75,
        0
      ))
    end
  end

  params.hsee = {
    widget = {
      slotpos = hsee_slotpos,
      animbank = "ui_fish_box_5x4",
      animbuild = "ui_fish_box_5x4",
      pos = Vector3(0, 220, 0),
      side_align_tip = 160,
      -- 第一行五格各有独立背景底图（官方 hud.xml）
      -- 第 1-3 格：装备图标（手/身/头），第 4-5 格：装备变体
      slotbg = {
        { atlas = "images/hud.xml", image = "equip_slot.tex" },          -- slot 1: 手
        { atlas = "images/hud.xml", image = "equip_slot_body.tex" },     -- slot 2: 身
        { atlas = "images/hud.xml", image = "equip_slot_head.tex" },     -- slot 3: 头
        { atlas = "images/hud.xml", image = "equip_slot_hud.tex" },
        { atlas = "images/hud.xml", image = "equip_slot_body_hud.tex" },
      },
      -- ▼ 底部关闭按钮（文字和位置在此修改）
      buttoninfo = {
        text = "󰀯",
        position = Vector3(0, -300, 0),  -- 5行容器，按钮下移
      },
    },
    type = "chest",
  }

  -- 更新最大槽位数，让 container_classified 的格子池足够大（25格）
  containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, #hsee_slotpos)

  -- 关闭按钮的回调（全局设置，服务器端和客户端共用）
  params.hsee.widget.buttoninfo.fn = function(inst, doer)
    if inst.components.container ~= nil then
      print("[HSee] Close button fired (server), doer=", doer and doer.prefab or "nil")
      inst.components.container:Close(doer)
    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
      print("[HSee] Close button fired (client), sending RPC to server")
      GLOBAL.SendRPCToServer(GLOBAL.RPC.DoWidgetButtonAction, nil, inst, nil)
    end
  end
  params.hsee.widget.buttoninfo.validfn = function(inst)
    return inst.replica.container ~= nil
  end
end

-- ========== 容器背景拉伸（适配 5 行格子） ==========
if not GLOBAL.TheNet:IsDedicated() then
  AddClassPostConstruct("widgets/containerwidget", function(self)
    local _Open = self.Open
    self.Open = function(self, container, doer)
      _Open(self, container, doer)
      -- HSee 从 5×4 扩展到 5×5，背景纵向拉伸 25%
      if container and container.prefab == "hsee" and self.bganim then
        self.bganim:SetScale(1, 1.25, 1)
      end
    end
  end)
end

-- ========== UI 图标呼吸跑马灯效果 ==========
-- 给 HSee 的物品栏图标添加呼吸彩色跑马灯效果，常开无开关
if not GLOBAL.TheNet:IsDedicated() then
  AddClassPostConstruct("widgets/itemtile", function(self)
    if self.item and self.item.prefab == "hsee" then
      self._hsee_effect = true
      self._hsee_time = 0
      self:StartUpdating()
    end

    local _OnUpdate = self.OnUpdate
    self.OnUpdate = function(self, dt)
      if self._hsee_effect and self.image then
        self._hsee_time = (self._hsee_time or 0) + dt
        local hue = self._hsee_time * 2 * math.pi / 1.6
        local cr = (math.sin(hue) + 1) / 2 * 0.7 + 0.3
        local cg = (math.sin(hue + 2.094) + 1) / 2 * 0.7 + 0.3
        local cb = (math.sin(hue + 4.189) + 1) / 2 * 0.7 + 0.3
        self.image:SetTint(cr, cg, cb, 1)
      end
      if _OnUpdate then
        _OnUpdate(self, dt)
      end
    end
  end)
end

if config.hsee_enable then
  -- ⚠️ 施法距离改为 26（默认 20）
  -- 全局改了 ACTIONS.CASTSPELL，所有用 spellcaster 的物品都受影响。
  -- 如果只想改 HSee 一个，需要：AddAction 定义专属动作 →
  -- AddComponentAction("SCENE", "spellcaster", fn) 检测 inst.prefab=="hsee" →
  -- 返回新动作。暂时测试用就全局了，后续可优化。
  GLOBAL.ACTIONS.CASTSPELL.distance = 26

  -- ========== 配方 ==========
  AddRecipe2("hsee",
    { Ingredient("goldnugget", 1), Ingredient("cutgrass", 1) },
    TECH.NONE,
    { atlas = "images/inventoryimages/heh.xml", image = "heh.tex", numtogive = 1 },
    { "TOOLS" }
  )

  STRINGS.NAMES.HSEE = "󰀅HSee󰀞"
  STRINGS.RECIPE_DESC.HSEE = "A portable viewer for inspecting and swapping items."
  STRINGS.CHARACTERS.GENERIC.DESCRIBE.HSEE = "Let me see what's in here!"
  local lang = GLOBAL.LanguageTranslator and GLOBAL.LanguageTranslator.defaultlang or "en"
  if lang == "zh" or lang == "zhr" or lang == "zht" then
    STRINGS.NAMES.HSEE = "󰀅让我看看󰀞"
    STRINGS.RECIPE_DESC.HSEE = "便携式物品查看器，可查看和交换NPC的物品。"
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.HSEE = "让我看看这里面有什么！"
  end
end
