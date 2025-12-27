-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })


-- 获取配置项（统一管理配置变量）
local config = {
  -- 基础配置项
  winter_food = GetModConfigData("冬季食物"),
  halloween_candy = GetModConfigData("万圣节糖果"),
}

-- 实体/特效引用
PrefabFiles = {
  -- "hehu_light",
}


-- 修改步行手杖属性
AddPrefabPostInit("saddle_race", function(inst)
  -- 只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end
  -- 结束
end)

--冬季零食
local winter_food_prefabs = {
  "winter_food1",
  "winter_food2",
  "winter_food3",
  "winter_food4",
  "winter_food5",
  "winter_food6",
  "winter_food7",
  "winter_food8",
  "winter_food9",
}

--万圣节糖果
local halloweencandy =
{
  "halloweencandy_1",
  "halloweencandy_2",
  "halloweencandy_3",
  "halloweencandy_4",
  "halloweencandy_5",
  "halloweencandy_6",
  "halloweencandy_7",
  "halloweencandy_8",
  "halloweencandy_9",
  "halloweencandy_10",
  "halloweencandy_11",
  "halloweencandy_12",
  "halloweencandy_13",
  "halloweencandy_14",
}

-- ===================== 通用函数：食物属性翻倍 =====================
-- 定义通用的食物属性翻倍函数
-- 参数1：prefab_list - 要处理的预制体名称列表
-- 参数2：multiplier - 翻倍倍数（可选，默认6）
local function BuffFoodAttributes(prefab_list, multiplier)
  -- 设置默认倍数为6
  local BUFF_MULTIPLIER = multiplier or 6

  -- 遍历预制体列表，逐个处理
  for _, prefab_name in ipairs(prefab_list) do
    AddPrefabPostInit(prefab_name, function(inst)
      -- 只在主机端修改（避免客户端同步问题）
      if not TheWorld.ismastersim then
        return
      end
      -- 检查实体和edible组件是否存在
      if inst and inst.components and inst.components.edible then
        local edible = inst.components.edible
        -- 修改基础属性：健康、饥饿、理智
        edible.healthvalue = edible.healthvalue * BUFF_MULTIPLIER
        edible.hungervalue = edible.hungervalue * BUFF_MULTIPLIER
        edible.sanityvalue = edible.sanityvalue * BUFF_MULTIPLIER
      end
    end)
  end
end

-- ===================== 分开调用（可单独控制倍数） =====================
-- 冬季零食属性
if config.winter_food > 0 then
  BuffFoodAttributes(winter_food_prefabs, config.winter_food)
end

-- 万圣节糖果属性
if config.halloween_candy > 0 then
  BuffFoodAttributes(halloweencandy, config.halloween_candy)
end
