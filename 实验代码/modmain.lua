-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })

local config = { hsee_enable = GetModConfigData("hsee_enable") }

PrefabFiles = { "hsee" }

Assets = {
  Asset("ANIM", "anim/medal_skin_staff.zip"),
  Asset("IMAGE", "images/inventoryimages/medal_skin_staff.tex"),
  Asset("ATLAS", "images/inventoryimages/medal_skin_staff.xml"),
  Asset("ANIM", "anim/ui_fish_box_5x4.zip"),
}

-- ========== 注册 HSee 的容器参数 ==========
-- 在 containers.params 中注册，这样客户端 replica 自动构造时能查到 widget 配置
-- （官方模式：fish_box / treasurechest 的 widget 都是通过 params 查找的）
do
  local containers = require("containers")
  local params = containers.params

  -- 拷贝鱼箱的 5×4 网格布局
  local hsee_slotpos = {}
  for y = 2.5, -0.5, -1 do
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
      -- 前三格：装备栏图标作为格子背景（官方 hud.xml）
      slotbg = {
        { atlas = "images/hud.xml", image = "equip_slot_head.tex" },
        { atlas = "images/hud.xml", image = "equip_slot_body.tex" },
        { atlas = "images/hud.xml", image = "equip_slot.tex" },
      },
      -- 底部关闭按钮（text+position 在 params 中定义，fn+validfn 在下面全局设置）
      buttoninfo = {
        text = "■ Close",
        position = Vector3(0, -190, 0),
      },
    },
    type = "chest",
    -- 物品过滤：前三格只允许对应装备类型的物品
    itemtestfn = function(container, item, slot)
      -- slot 是 1-based（对应 slotpos 数组下标）
      if slot > 3 then return true end

      local equip = item.components.equippable
      if not equip then return false end

      -- 获取装备槽位（服务端：.equipslot，客户端：:EquipSlot()）
      local eslot = equip.equipslot
      if eslot == nil and equip.EquipSlot then
        eslot = equip:EquipSlot()
      end
      if eslot == nil then return false end

      if slot == 1 then return eslot == "head" end
      if slot == 2 then return eslot == "body" end
      if slot == 3 then return eslot == "hands" end
      return true
    end,
  }

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

if config.hsee_enable then
  -- ========== 配方 ==========
  AddRecipe2("hsee",
    { Ingredient("goldnugget", 1), Ingredient("cutgrass", 1) },
    TECH.NONE,
    { atlas = "images/inventoryimages/medal_skin_staff.xml", image = "medal_skin_staff.tex", numtogive = 1 },
    { "TOOLS" }
  )

  STRINGS.NAMES.HSEE = "HSee"
  STRINGS.RECIPE_DESC.HSEE = "A portable viewer for inspecting and swapping items."
  STRINGS.CHARACTERS.GENERIC.DESCRIBE.HSEE = "Let me see what's in here!"
  local lang = GLOBAL.LanguageTranslator and GLOBAL.LanguageTranslator.defaultlang or "en"
  if lang == "zh" or lang == "zhr" or lang == "zht" then
    STRINGS.NAMES.HSEE = "HSee"
    STRINGS.RECIPE_DESC.HSEE = "便携式物品查看器，可查看和交换物品。"
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.HSEE = "让我看看这里面有什么！"
  end
end
