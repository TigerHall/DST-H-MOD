-- 环境设置 使用全局变量
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })


-- 获取配置项（统一管理配置变量）
local config = {
  -- 基础配置项
  endtable_immune = GetModConfigData("endtable_immune") or false,
  endtable_flower_wilt = GetModConfigData("endtable_flower_wilt") or true,
  birdcage_immortal = GetModConfigData("birdcage_immortal") or true,
}

-- 实体/特效引用
PrefabFiles = {
  -- "hehu_light",
}


-- 修改茶几属性
AddPrefabPostInit("endtable", function(inst)
  -- 只在主机端执行修改
  if not TheWorld.ismastersim then
    return inst
  end
  -- 茶几防BOSS摧毁+卡位功能
  if config.endtable_immune then
    if inst:HasTag("NPC_workable") then
      inst:RemoveTag("NPC_workable")
    end
    if inst.components.workable then
      inst:RemoveComponent("workable")
    end
    -- 2. 燃烧后直接删除（核心简化逻辑）
    if not inst.components.burnable then
      MakeSmallBurnable(inst)   -- 确保有燃烧组件
      MakeSmallPropagator(inst) -- 可被火焰引燃
    end
    -- 重写燃烧完成逻辑：直接删实体，无任何残留
    inst.components.burnable:SetOnBurntFn(function(inst)
      inst:Remove() -- 核心：燃烧后直接删除
    end)
  end

  if config.endtable_flower_wilt then
    -- 极大延长花枯萎时间
    TUNING.ENDTABLE_FLOWER_WILTTIME = 666666
  end
  -- 结束
end)

-- 修改鸟笼属性
if config.birdcage_immortal then
  TUNING.PERISH_CAGE_MULT = 0
end

-- 定义图纸配方的材料配置（可自定义，默认6张纸）
local MAP_RECIPE_MATERIALS = { Ingredient("papyrus", 6) }

-- 缓存已添加的配方，避免重复注册
local added_map_recipes = {}

-- 通过AddPrefabPostInit修改制图桌
AddPrefabPostInit("cartographydesk", function(inst)
  if not TheWorld.ismastersim then
    return inst -- 仅在服务端执行逻辑
  end

  -- ******** 核心修改：重写 PaperEraser 组件的 DoErase 方法 ********
  if inst.components.papereraser then
    -- 备份原版 DoErase 方法
    local old_DoErase = inst.components.papereraser.DoErase
    -- 重写 DoErase 方法
    function inst.components.papereraser:DoErase(paper, doer)
      -- 执行原版擦除逻辑（获取擦除结果）
      local erase_result = old_DoErase(self, paper, doer)
      -- 仅当擦除成功、目标是图纸时，注册配方
      if erase_result and paper and paper.prefab then
        -- 配方名=图纸prefab名
        local recipe_name = paper.prefab
        -- 避免重复注册配方
        if not added_map_recipes[recipe_name] then
          -- 配置AddRecipe2的config参数（必填atlas保证图标正常）
          local recipe_config = {
            -- 必填表集路径
            -- atlas = resolvefilepath("images/inventoryimages/" .. recipe_name .. ".xml"),
            -- 限定仅制图桌可制作
            station_tag = "cartographydesk",
          }

          -- 调用AddRecipe2注册配方
          AddRecipe2(
            recipe_name,          -- 1. 配方名（图纸名称）
            MAP_RECIPE_MATERIALS, -- 2. 材料（6张纸）
            TECH.NONE,            -- 3. 科技要求
            recipe_config,        -- 4. 配置表（含必填表集）
            { "DECOR" }           -- 5. 过滤器（制作栏分类）
          )
          -- 标记为已添加，避免重复注册
          added_map_recipes[recipe_name] = true
          -- 播放解锁音效（可选）
          if inst.SoundEmitter then
            inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl1_ding")
          end
        end
      end
      -- 返回原版擦除结果
      return erase_result
    end
  end

  return inst
end)
