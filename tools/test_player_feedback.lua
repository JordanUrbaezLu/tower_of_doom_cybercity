-- Actual Lua 5.1 UI helpers with mocked elements/models; no screenshot claims.
CoD = { TweenType = { Linear = 0 } }
Enum = { LUIAlignment = { LUI_ALIGNMENT_LEFT = 0 } }
local function element()
    local e = { children = {} }
    function e:setAlpha(a) self.alpha=a end
    function e:setLeftRight(_,__,a,b) self.x1,self.x2=a,b end
    function e:setTopBottom(_,__,a,b) self.y1,self.y2=a,b end
    function e:setRGB(...) self.color={...} end
    function e:setText(t) self.text=t end
    function e:setImage(i) self.image=i end
    function e:setTTF(t) end
    function e:setAlignment(a) end
    function e:addElement(child) self.children[#self.children+1]=child end
    function e:completeAnimation() self.completed=true end
    function e:beginAnimation(name,ms) self.animation,self.ms=name,ms end
    function e:subscribeToModel(_,f) self.model=f end
    function e:subscribeToGlobalModel(_,__,___,f) self.notify=f end
    return e
end
LUI={UIImage={new=element},UIText={new=element}}
RegisterImage=function(s) return s end
Engine={GetModelForController=function(c) return c end,GetModel=function(_,s) return s end,GetModelValue=function(v) return v end}
local data
CoD.GetScriptNotifyData=function() return data end
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodAbilityFeedback.lua')
local feedback=CoD.TodAbilityFeedback
local w=element();feedback.Attach(w,0);feedback.Mode(w,true)
feedback.Progress(w,50,0)
local f=w.todHealRecharge.fills
assert(f[1].alpha>0 and f[2].alpha>0 and f[3].alpha==0 and f[4].alpha==0)
assert(f[1].x2-f[1].x1==46 and f[2].y2-f[2].y1==28,'half the perimeter filled')
for p=0,99 do
    feedback.Progress(w,p,p)
    for _,image in ipairs(w.todHealRecharge.fills) do assert(image.x2>=image.x1 and image.y2>=image.y1) end
end
feedback.Blocked(w);assert(w.todBlinkBlocked.ms==350 and w.todBlinkBlocked.color[1]==1)
feedback.Mode(w,false)
for _,image in ipairs(w.children) do assert(image.alpha==0,'class change hides feedback') end
feedback.Progress(w,50,50);feedback.Blocked(w);assert(w.todHealRecharge.fills[1].alpha==0)
feedback.Mode(w,true);feedback.Progress(w,-1,-1);assert(w.todBlinkRecharge.tracks[1].alpha==0)
dofile('ui/uieditor/widgets/HUD/ZM_CursorHint/Prompts/TodTeleportFeedback.lua')
local p=element();CoD.TodTeleportFeedback.Attach(p,0)
local label,track,fill=p.children[1],p.children[2],p.children[3]
local function notify(s,pct) data={s,pct};track.notify('tod_tp_recharge') end
label.model('^5TELEPORTER^7 - ^1recharging...');notify(30,50)
assert(label.alpha==1 and label.text=='Ready in 30s' and fill.x2==693.5)
label.model('^5AMMO CRATE^7 - buy ammo');assert(label.alpha==0 and fill.alpha==0)
label.model('^5TELEPORTER^7 - power required');assert(label.alpha==0)
label.model('^5TELEPORTER^7 - destination locked');assert(label.alpha==0)
label.model('^5TELEPORTER^7 - recharging...');notify(1,98);assert(label.text=='Ready in 1s')
notify(0,0);assert(label.alpha==0 and track.alpha==0)
notify(10,75);label.model('');assert(label.alpha==0)
local file=assert(io.open('ui/uieditor/menus/hud/tod_upgrade.lua'));local src=file:read('*a');file:close()
local first=assert(src:find('local DETAIL =',1,true))
local last=assert(src:find('CoD.TodDomainInfo = DOMAIN',first,true))
-- DETAIL initialization only stores functions; Blink invokes no other helpers.
assert(loadstring(src:sub(first,last-1)))()
for lv=1,5 do
    local normal=CoD.TodDomainDesc(55,lv,false)
    local dark,act=CoD.TodDomainDesc(55,lv,true)
    assert(dark==normal and not dark:find('{V}',1,true))
    assert(act:find('stores 3',1,true))
end
print('Player feedback Lua: perimeter progress, blocked pulse, class resets, prompt/countdown visibility and real Dark Blink descriptions pass.')
