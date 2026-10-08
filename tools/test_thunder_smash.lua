-- Lua 5.1: shipping HUD closure and setters, with native elements mocked.
local f=assert(io.open('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumLoadout.lua','r'))
local source=f:read('*a');f:close();assert(loadstring(source))
local function span(a,b)
    local first=assert(source:find(a,1,true));local last=assert(source:find(b,first+#a,true))
    return source:sub(first,last-1)
end
local setup=[[
local manaOn,smashMode,smashState,smashUses=false,false,0,0
local tutUses={blink=0,heal=0};local TUT_USES=3;local tutLog=nil
local OFF_MONKEY='monkey';local HUD_DX=0;local todNameSet={}
local stock=2;local function model(k) return k end
Engine={GetModelValue=function() return stock end}
local self={lethal={everHad=false,charges=0},tactical={}}
local slot=self.tactical
slot.icon={setAlpha=function(_,v) slot.alpha=v end,setImage=function(_,v) slot.image=v end}
slot.smashMark={hide=function() slot.mark=nil end,set=function(s) slot.mark=s end,setRGB=function(...) slot.rgb={...} end}
slot.setCount=function(v) slot.charges=v end
local function paintBadge(s,token,on) s.badge=on end
local function ready(s) return s.everHad and (s.charges or 0)>0 end
CoD={TodAbilityFeedback={Smash=function(_,p) slot.progress=p end}}
local paintSmash
]]
local chunk=setup..span('local function refreshTut()','local mageIcons = nil')
    ..span('paintSmash = function( code, percent, seconds )','\n\t-- =========================================================================\n\t-- THE PACK-A-PUNCH TIER BADGE')
    ..[[
paintSmash(1,100,0);assert(slot.mark=='SM' and slot.charges==0 and not slot.badge)
paintSmash(2,100,0);assert(slot.charges==1 and slot.badge and slot.alpha==0)
paintSmash(3,40,27);assert(slot.charges==27 and slot.progress==40 and not slot.badge)
paintSmash(4,0,45);assert(slot.charges==0 and not slot.badge and slot.progress==0)
paintSmash(4,50,44);assert(slot.progress==50 and not slot.badge)
paintSmash(2+8*3,100,0);assert(slot.charges==1 and not slot.badge)
paintSmash(0,100,0);assert(slot.mark==nil and slot.charges==2 and slot.image=='monkey' and slot.progress==-1)
manaOn=true;slot.everHad=true;slot.charges=1
paintSmash(2,100,0);assert(slot.mark==nil and slot.charges==1 and slot.badge,'mage keeps its tile')
]]
assert(loadstring(chunk))()
print('Thunder Smash HUD: actual Lua closure compiles; locked, ready, casting, recharge, learned prompt, stock and Mage transitions pass.')
