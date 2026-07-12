-- 环境设置 使用全局变量
-- GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })


-- 获取配置项（统一管理配置变量）
local config = {
  -- 基础配置项
  -- speed_buff = GetModConfigData("speed_buff_value"),

}

-- 实体/特效引用
PrefabFiles = {
  -- "oceantree_light",
}

Assets = {
  -- Asset("SHADER", "shaders/myshader.ksh")
}
