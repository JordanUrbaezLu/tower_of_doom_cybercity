-- Run with Lua 5.1 from the repo root. Native rendering still needs BO3.
CoD = { TweenType = { Linear = 0 } }
Engine = { GetModelValue = function(m) return m.value end }
CoD.GetScriptNotifyData = function(m) return m.data end
LUI = { UIElement = {} }
local function element()
    local e = { handlers = {}, animations = 0, completed = 0, children = {} }
    function e:setLeftRight(...) self.left = {...} end
    function e:setTopBottom(...) self.top = {...} end
    function e:setRGB(r,g,b) self.rgb = {r,g,b} end
    function e:addElement(child) self.children[#self.children+1] = child; child.parent=self end
    function e:getFirstChild() return self.children[1] end
    function e:getNextSibling()
        if not self.parent then return nil end
        for i,c in ipairs(self.parent.children) do if c==self then return self.parent.children[i+1] end end
    end
    function e:registerEventHandler(name, fn) self.handlers[name] = fn end
    function e:beginAnimation(...) self.animations = self.animations + 1 end
    function e:completeAnimation() self.completed = self.completed + 1 end
    function e:close()
        assert(not self.closed, 'double close')
        self.closed = true
        if self.parent then
            for i,c in ipairs(self.parent.children) do if c==self then table.remove(self.parent.children,i); break end end
            self.parent=nil
        end
    end
    function e:linkToElementModel(_, _, _, fn) self.bind = fn end
    function e:subscribeToGlobalModel(controller, _, _, fn)
        self.controller = controller; self.receive = fn; self.subs = (self.subs or 0) + 1
    end
    return e
end
LUI.UIElement.new = element
LUI.OverrideFunction_CallOriginalSecond = function(e, name, fn)
    local old = e[name]
    e[name] = function(self) fn(self); old(self) end
end
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodHealthTint.lua')
local function widget(controller, id, isLocal)
    local w = element(); w.health_fill = element(); w.currentPlayerState = 0
    CoD.TodHealthTint.Attach(w, controller, isLocal)
    w.bind({value=id}); return w
end
local function send(w, mask) w.receive({value='tod_arch_bars',data={mask}}) end
local function cycle(w) w.health_tint.handlers.transition_complete_tod_arch_color(w.health_tint,{}) end
for mask=0,15 do
    for controller=0,3 do
        for id=0,3 do
            local w=widget(controller,id,id==controller); send(w,mask)
            local expected=math.floor(mask/2^id)%2==1
            assert((w.todHealthMode=='arch')==expected,'wrong player/controller tinted')
            assert(w.health_fill.animations==0 and w.health_fill.completed==0,'health animation was changed')
            w:close()
            assert(w.health_fill.closed, 'closing tint must also close remaining fill')
        end
    end
end
local w=widget(0,1,false); send(w,2)
local colors={}
for i=1,18 do
    local c=w.health_tint.rgb; colors[table.concat(c,',')]=true; cycle(w)
end
local n=0; for _ in pairs(colors) do n=n+1 end; assert(n==6,'must visit six rainbow colors')
local before=w.health_tint.animations; send(w,2); assert(w.health_tint.animations==before,'heartbeat restarted animation')
for i=1,20 do w.bind({value=i%4}) end
assert(w.subs==1,'roster rebinding leaked subscriptions')
w.bind({value=0}); assert(w.todHealthMode=='normal','old occupant kept rainbow')
w.bind({value=1}); assert(w.todHealthMode=='arch','new occupant lost active state')
w.currentPlayerState=1; CoD.TodHealthTint.Paint(w); assert(w.todHealthMode=='down')
before=w.health_tint.animations; cycle(w); assert(w.health_tint.animations==before,'downed animation must stop')
w.currentPlayerState=0; CoD.TodHealthTint.Paint(w); assert(w.todHealthMode=='arch')
send(w,0); assert(w.todHealthMode=='normal','end/disconnect snapshot must clear tint')
local mine=widget(1,1,true); mine.receive({value='tod_mage_aura',data={1}})
assert(mine.todHealthMode=='aura'); send(mine,2); assert(mine.todHealthMode=='arch')
send(mine,0); assert(mine.todHealthMode=='aura','must restore healing green')
w.receive({value='tod_mage_aura',data={1}}); assert(w.todHealthMode=='normal','viewer aura leaked onto teammate')
send(w,2); before=w.health_tint.animations; w:close(); cycle(w)
assert(w.health_tint.animations==before and w.health_tint.closed,'closed widget restarted animation')
assert(w.health_fill.animations==0 and w.health_fill.completed==0,'health/bleedout animation was touched')
print('Archmage tint passed: 256 controller/player/mask cases; six colors, stable heartbeat, rebind, down/revive, aura priority and cleanup.')
