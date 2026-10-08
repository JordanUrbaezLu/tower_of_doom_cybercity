-- Lua 5.1 module-load regression for BO3's ban on new UI globals.
local path = "ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumLoadout.lua"
local f = assert(io.open(path, "r"))
local source = f:read("*a"); f:close()
local function check(s)
    local env = {
        CoD = {TodGlyphRow = {}}, LUI = {UIElement = {}},
        require = function() end,
        InheritFrom = function() return {} end,
    }
    setmetatable(env, {
        __index = _G,
        __newindex = function(_, key)
            error("LUI Error: Tried to create global variable " .. key)
        end,
    })
    local chunk = assert(loadstring(s, "@" .. path))
    setfenv(chunk, env)
    return pcall(chunk)
end
local ok, err = check(source)
assert(ok, err)
local old, count = source:gsub("local TOD_STAFF_NAME =", "TOD_STAFF_NAME =", 1)
assert(count == 1)
local oldOK, oldError = check(old)
assert(not oldOK and oldError:find("Tried to create global variable TOD_STAFF_NAME", 1, true), oldError)
print("HUD global guard passed: current module loads; old declaration reproduces the native error.")

