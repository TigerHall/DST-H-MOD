-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })


-- 获取配置项（统一管理配置变量）
local config = {
  -- 基础配置项
  speed_buff = GetModConfigData("speed_buff_value"),

}

-- 实体/特效引用
PrefabFiles = {
  "oceantree_light",
}

Assets = {
  Asset("SHADER", "shaders/myshader.ksh")
}

AddPrefabPostInit("chester_eyebone", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end
  -- 添加容器组件
  -- inst:AddComponent("container")
end)


local containers = require("containers")
local params = containers.params

-- 给容器对象添加一个名为 abigail 的容器，用的是坎普斯背包的配置修改的
params.abigail = {
  widget = {
    slotpos = {},
    animbank = "ui_boat_ancient_4x4",
    animbuild = "ui_boat_ancient_4x4",
    pos = Vector3(300, 60, 0)
  },
  type = "abigail",
  itemtestfn = function(inst, item, slot) -- 容器里可以装的物品的条件
    return not item:HasTag("_container") and not item:HasTag("bundle") and not item:HasTag("irreplaceable") and
        item.prefab ~= "abigail_flower"
  end
}

-- 循环容器里小格子

for y = 3, 0, -1 do
  for x = 0, 3 do
    table.insert(params.abigail.widget.slotpos, Vector3(75 * x - 116, 75 * y - 116, 0))
  end
end



AddPrefabPostInit("abigail", function(inst)
  if not TheWorld.ismastersim then
    return inst
  end
  -- 添加容器组件
  inst:AddComponent("container")
  -- 设置容器名
  inst.components.container:WidgetSetup("abigail")
end)
