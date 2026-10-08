-- =============================================================================
-- TodHudVeil — ONE switch that hides the whole HUD while a full-screen moment
-- (COPIED 2026-10-02 from Tower of Doom II, verbatim below this note; in this map the
-- one owner so far is the rocket rides, key "rocket", TodRocketCine.lua)
-- owns the screen (user 2026-09-29: "Make sure the HUD doesnt show when cards
-- are getting pulled" / "Same thing I asked for the item shop wheel").
--
-- OWNERS raise it by key and drop it by key:
--     CoD.TodHudVeil.Set( "cards", true )   -- the upgrade card panel (tod_upgrade.lua)
--     CoD.TodHudVeil.Set( "spin",  true )   -- the Black Market wheel (TodSpinReel.lua)
-- The HUD is hidden while ANY owner holds it, so two moments overlapping can never
-- un-hide each other (the bug the scoreboard/pause pair had: two absolute writers).
--
-- LISTENERS are the widgets that hide: they register a function that is called
-- with the new state on every change (and once at registration), and they are
-- dropped automatically when their element closes. A listener never owns the
-- decision; it only applies it.
--
-- Client-side only, no clientfield, no server state. Loaded with pcall by every
-- user, so a missing rawfile degrades to "the HUD never hides", never to an error.
-- =============================================================================

CoD.TodHudVeil = CoD.TodHudVeil or { owners = {}, listeners = {} }
local V = CoD.TodHudVeil

function V.Hidden()
	for _, on in pairs( V.owners ) do
		if on then
			return true
		end
	end
	return false
end

local function Notify()
	local h = V.Hidden()
	for el, fn in pairs( V.listeners ) do
		if el.todVeilClosed then
			V.listeners[ el ] = nil
		else
			pcall( fn, h )
		end
	end
end

function V.Set( key, on )
	local was = V.Hidden()
	if on then
		V.owners[ key ] = true
	else
		V.owners[ key ] = nil
	end
	if V.Hidden() ~= was then
		Notify()
	end
end

-- el = the element that owns the listener (its close drops the listener)
function V.Listen( el, fn )
	V.listeners[ el ] = fn
	if LUI and LUI.OverrideFunction_CallOriginalSecond then
		LUI.OverrideFunction_CallOriginalSecond( el, "close", function ( element )
			element.todVeilClosed = true
			V.listeners[ element ] = nil
		end )
	end
	pcall( fn, V.Hidden() )
end
