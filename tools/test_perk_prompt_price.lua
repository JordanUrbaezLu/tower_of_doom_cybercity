-- Execute the actual prompt updater in Lua 5.1, including native-model handoff.
CoD = {}
LUI = { UIElement = {} }
InheritFrom = function() return {} end
local records = {}
DebugPrint = function(s) records[#records+1] = s end
Engine = {
    Localize = function(s) return s end,
    -- Reproduce the failing old UI path: the party dvar is unavailable.
    DvarString = function() error('unavailable') end,
    GetDvarString = function() return nil end
}
dofile('ui/uieditor/widgets/HUD/ZM_CursorHint/Prompts/PromptPerks.lua')

-- v19.12 — THE STUB NOW MODELS THE CARD THAT ACTUALLY SHIPS. This harness was
-- written against a widget with a `perkCost` member; the v19.3 refactor moved
-- every prompt onto CoD.TodPromptCard, whose price element is `todPrice` and
-- whose SetPrice writes "$" .. digits. Nothing here has had a `perkCost` since,
-- so EVERY assertion below was comparing nil to a string and this file had been
-- failing silently against a widget field that no longer exists. Modelled on the
-- real element names now, so the checks mean something again.
-- Every element the card reaches for answers to any layout call and records
-- only its text. Auto-vivified per member name, so a card that grows another
-- element does not need this harness edited again.
-- v19.18: the card now swaps its chassis image for the wide Quick Revive
-- variant, so the harness needs the engine's image registrar.
RegisterImage = RegisterImage or function( n ) return n end
local NOOP = function() end
local elmt = { __index = function( t, k )
    if k == 'text' then return nil end
    if k == 'setText' then return function( self, v ) rawset( self, 'text', v ) end end
    -- The card MEASURES its own rows to fit them; hand back real numbers/strings
    -- so the layout arithmetic runs instead of comparing against nil.
    if k == 'measure' then return function() return 0 end end
    if k == 'getText' then return function( self ) return rawget( self, 'text' ) or '' end end
    return NOOP
end }
local function el() return setmetatable( {}, elmt ) end
local w = setmetatable( {}, { __index = function( t, k )
    if type( k ) == 'string' and k:sub( 1, 3 ) == 'tod' then
        local e = el(); rawset( t, k, e ); return e
    end
    return nil
end } )
local qr = { specialty='specialty_quickrevive', cost=1500, soloCost=500 }
local function check(data,hint,expected)
    CoD.PromptPerks.UpdatePerkInfo(w,data,hint)
    local got = w.todPrice.text
    assert(got==expected, tostring(hint)..' => '..tostring(got)..' (wanted '..tostring(expected)..')')
end
-- v19.12 — QUICK REVIVE NO LONGER PRINTS A PRICE ROW AT ALL. Both of its
-- prices live in the two copy lines, so the panel states solo AND co-op and
-- never has to decide which party this is. These cases therefore assert the
-- OPPOSITE of what they did before, on purpose: WHATEVER the hint says, the
-- price row stays empty. That is the whole point — the card stopped asking.
check(qr,'Hold ^3[F]^7 for Quick Revive [Cost: 500]','')
check(qr,'Hold [4] for Quick Revive [Cost: 1500]','')
check(qr,'Hold [4] for Quick Revive [Cost: ^2500^7]','')
check(qr,'Hold [4] for Quick Revive [COST: 500 ]','')
check(qr,'Hold [4] for Quick Revive [Cost: 0]','')
check(qr,'Hold [4] for Quick Revive', '')
check(qr,nil,'')
check(qr,'Hold [4] for Quick Revive [Cost: 500bad]','')
check(qr,'Hold [4] for Quick Revive [Cost: -500]','')
-- ...and the copy carries both prices and both behaviours, which is where the
-- information went. Read off the real table in the module just loaded.
do
    local src=io.open('ui/uieditor/widgets/HUD/ZM_CursorHint/Prompts/PromptPerks.lua'):read('*a')
    local row=assert(src:match('%[ "specialty_quickrevive" %]%s*=%s*{(.-)},'),'quickrevive copy row')
    assert(row:find('500',1,true),'solo price missing from the copy')
    assert(row:find('1500',1,true),'co-op price missing from the copy')
    assert(row:find('SOLO',1,true) and row:find('CO%-OP'),'both party words must appear')
end
local fixed = {specialty='specialty_armorvest',cost=2500}
check(fixed,'Hold [F] for Juggernog [Cost: 2500]','$2500')
check(fixed,'Hold [F] for Juggernog [Cost: 2000]','$2000')
check(fixed,nil,'$2500')
check(qr,nil,'') -- never inherit the previous machine's price
local n=#records
check(qr,'Hold [F] for Quick Revive [Cost: 500]','')
assert(#records==n,'unchanged price must not spam diagnostics')
assert(records[n]:find('source=static_both_prices',1,true),'quick revive logs the static source')
-- Exercise the actual router callback body, so omitting the third argument
-- reproduces the bug even if the isolated updater is correct.
local f=assert(io.open('ui/uieditor/widgets/HUD/ZM_CursorHint/ZMCursorHintNew.lua'))
local s=f:read('*a'); f:close()
local body=assert(s:match('if state == "Perks" and self.promptPerks then(.-)\n\t\t\tend'))
local fn=assert(loadstring('return function(self, getPerkFromHint, cursorHintText) '..body..' end'))()
fn({promptPerks=w},function() return qr end,'Hold [F] for Quick Revive [Cost: 500]')
assert(w.todPrice.text=='','quick revive shows no price row whatever the hint carries')
-- The forwarding itself still matters for every OTHER perk, so prove it there.
fn({promptPerks=w},function() return fixed end,'Hold [F] for Juggernog [Cost: 2000]')
assert(w.todPrice.text=='$2000','router must forward the native hint, not only the table row')
-- v19.18 THE WIDE CARD IS QUICK REVIVE'S ALONE.
CoD.PromptPerks.UpdatePerkInfo(w,qr,'Hold [F] for Quick Revive [Cost: 500]')
assert(w.todWide==true,'quick revive takes the wide chassis')
CoD.PromptPerks.UpdatePerkInfo(w,fixed,'Hold [F] for Juggernog [Cost: 2500]')
assert(w.todWide==false,'every other perk goes back to the standard chassis')
assert(w.colDescL==nil or w.colDescL==620,'and its description column returns with it')
print('PASS: native-hint handoff, solo/co-op, missing/malformed, price changes and bounded logs')
