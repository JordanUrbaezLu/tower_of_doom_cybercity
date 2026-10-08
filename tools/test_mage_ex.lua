-- node tools/test_staff_name_feed.js first, then run under Lua 5.1.
-- Executes the real name renderer and real scriptNotify callback.
local f=assert(io.open('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumLoadout.lua'))
local source=f:read('*a'); f:close()
assert(loadstring(source))
local function span(first,last)
    local a=assert(source:find(first,1,true))
    local b=assert(source:find(last,a+#first,true))
    return source:sub(a,b-1)
end
local tableCode=span('local TOD_STAFF_NAME = {','\n}')..'\n}'
local render=span('local function setWeaponName( raw )','-- BOTH MODELS FEED THE ICON')
local at=assert(source:find('if Engine.GetModelValue( model ) ~= "tod_pap_tier"',1,true))
local finish=assert(source:find('\n\tend )',at,true))
local receive='local function receive(model)\n'..source:sub(at,finish-1)..'\nend\n'
local harness=[[
local self={name_row={hide=function() end},name_row2={hide=function() end},weapon_name={}}
function self.weapon_name:setText(s) self.text=s end
function self.weapon_name:setAlpha(a) end
local Engine={Localize=function(s) return s end,GetModelValue=function(m) return m.name end}
local CoD={GetScriptNotifyData=function(m) return m.data end}
local TOD_GLYPHS,TOD_HUD_DEBUG=false,false
local function setPapTier(t) self.tier=t end
]]..tableCode..render..receive..[[
local expected={
    {'LIGHTNING STAFF',"KIMAT'S BITE"},
    {'FIRE STAFF',"KAGUTSUCHI'S BLOOD"},
    {'ICE STAFF',"ULL'S ARROW"},
}
-- A server update must render even before the engine weapon-name model exists.
receive({name='tod_pap_tier',data={1,1}})
assert(self.weapon_name.text=="KIMAT'S BITE",'server-first staff name missing')
for _,packet in ipairs(dofile('tmp/staff_name_packets.lua')) do
    local tier,id=packet[1],packet[2]
    setWeaponName('MR6') -- deliberately stale engine text
    receive({name='tod_pap_tier',data=packet})
    local want=id>0 and expected[id][tier>0 and 2 or 1] or 'MR6'
    assert(self.weapon_name.text==want, 'wrong staff name: '..tostring(self.weapon_name.text)..' expected '..want)
    assert(self.tier==tier)
    if id>0 then
        -- A late/untranslated engine label cannot replace the correct staff name.
        setWeaponName('STALE ENGINE LABEL')
        assert(self.weapon_name.text==want,'late engine update overwrote staff name')
    end
end
receive({name='tod_pap_tier',data={1,2}})
receive({name='another_event',data={0,0}})
assert(self.weapon_name.text=="KAGUTSUCHI'S BLOOD")
setWeaponName('Stormbreaker EX')
receive({name='tod_pap_tier',data={1,0}})
assert(self.weapon_name.text=='STORMBREAKER EX','nonstaff label not restored')
]]
assert(loadstring(harness))()
-- Removing the authoritative override reproduces the stale/absent-name failure.
local broken,n=harness:gsub('self%.todStaffName or Engine%.Localize','Engine.Localize',1)
assert(n==1)
local ok=pcall(assert(loadstring(broken)))
assert(not ok,'negative control did not fail')
print('Staff names passed: actual server packets, base/packed names, same-tier switches, both event orders, missing/stale engine names, reset and nonstaff fallback; negative control fails.')
