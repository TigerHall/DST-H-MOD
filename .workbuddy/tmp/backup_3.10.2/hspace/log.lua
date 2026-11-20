-- scripts/hspace/log.lua
-- ═══════════════════════════════════════════════════════════════════════
-- hspace 统一日志
--
-- 调试期全部打开；稳定后把 ENABLED 改成 false 就整体静音，
-- 不用回去一行行注释 print。
--
-- 约定：
--   D()   普通流程日志，受 ENABLED 控制
--   W()   可疑但不致命，受 ENABLED 控制，前缀 ⚠
--   E()   错误，**永远打印**（不受开关影响），排查完再动
--   Safe() 把一段逻辑包起来跑，出错时打印 tag + 堆栈，不让异常冒到 DST 主循环
--
-- ⚠️ print 在服务端进 server_log / master_server_log，
--    客户端进 client_log。两边都要看。
-- ═══════════════════════════════════════════════════════════════════════

local Log = {}

-- ⭐ 总开关：调试期 true，全部稳定后改 false
local ENABLED = true

function Log.SetEnabled(v)
    ENABLED = v and true or false
end

function Log.IsEnabled()
    return ENABLED
end

local function fmt(...)
    local n = select("#", ...)
    if n == 0 then
        return ""
    end
    local parts = {}
    for i = 1, n do
        local v = select(i, ...)
        local t = type(v)
        if t == "string" then
            parts[i] = v
        elseif t == "table" and v.prefab ~= nil then
            parts[i] = "<" .. tostring(v.prefab) .. ">"
        elseif t == "table" and v.inst ~= nil then
            parts[i] = "<table:inst>"
        else
            parts[i] = tostring(v)
        end
    end
    return table.concat(parts, " ")
end

-- 普通流程日志
function Log.D(tag, ...)
    if ENABLED then
        print("[hspace][" .. tostring(tag) .. "] " .. fmt(...))
    end
end

-- 可疑但不致命
function Log.W(tag, ...)
    if ENABLED then
        print("[hspace][WARN][" .. tostring(tag) .. "] " .. fmt(...))
    end
end

-- 错误：永远打印
function Log.E(tag, ...)
    print("[hspace][ERROR][" .. tostring(tag) .. "] " .. fmt(...))
end

-- 执行一段逻辑，出错不抛出，只记录。返回是否成功。
-- 需要转发返回值的场合直接用 pcall，不要用这个。
-- 用法：
--   local ok = Log.Safe("rpc_take", function() ... end)
function Log.Safe(tag, fn, ...)
    local ret = { pcall(fn, ...) }
    if not ret[1] then
        Log.E(tag, "异常:", tostring(ret[2]))
        local tb = (debug ~= nil and debug.traceback ~= nil)
            and debug.traceback("", 2) or ""
        if tb ~= "" then
            print(tb)
        end
        return false
    end
    return true
end

return Log
