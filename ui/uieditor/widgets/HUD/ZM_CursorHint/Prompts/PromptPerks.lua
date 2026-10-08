-- =============================================================================
-- PromptPerks.lua — the nine perk vending machines.
--
-- v19.3: REBUILT ON CoD.TodPromptCard. Chassis, typeface, footer and price all
-- come from the shared owner; this file keeps the perk lookup and the price
-- read, which are genuinely its own.
--
-- ⚠️ DO NOT REINTRODUCE AN INDEPENDENT PRICE GUESS. `HintCost()` below is the
-- v18.99l fix and it is load-bearing: the card used to infer solo/co-op from
-- the `tod_party` dvar and displayed 1500 while the server charged 500. The
-- machine's own hint carries the price. Read it; never recompute it.
--
-- ---------------------------------------------------------------------------
-- WHY THE DESCRIPTIONS ARE REWRITTEN HERE INSTEAD OF IN AetheriumPerks.lua
--
-- The shared perk table's descriptions are written for a TTF surface with room
-- to breathe — "Faster revives in co-op / Self-revive up to 3 times in solo",
-- 59 characters with a slash in it. Two things break when that is poured into
-- a prompt card:
--
--   1. THE GLYPH SET. `( ) , / : ;` all appear in that table and NONE of them
--      exist in the map's 42-glyph typeface. TodPromptCard.Sanitize now
--      converts what it can, but a sentence that needs a slash to make sense
--      is a sentence written for a different surface.
--   2. THE ROOM. The detail row holds 34 glyphs before it shrinks toward
--      unreadable. Those strings are up to 83.
--
-- So the prompt card gets its own short forms, two lines where a perk really
-- needs two. The long copy stays untouched for the perks container HUD, which
-- has the space and the font for it — changing it there would have degraded a
-- screen nobody complained about.
-- =============================================================================

require( "ui.uieditor.widgets.HUD.ZM_CursorHint.Prompts.TodPromptCard" )

CoD.PromptPerks = InheritFrom( LUI.UIElement )

-- The machine's cursor hint carries its price. Do not independently infer
-- solo/co-op here: the old tod_party dvar fallback displayed 1500 while the
-- server charged 500. Strip colour codes and read only the bracketed cost,
-- never a key binding or a number in the perk description.
local function HintCost( hintText )
	if type( hintText ) ~= "string" then return nil end
	local clean = string.lower( string.gsub( hintText, "%^%d", "" ) )
	local digits = string.match( clean, "%[cost:%s*(%d+)%s*%]" )
	return tonumber( digits )
end

-- PROMPT-CARD COPY, keyed on the stock specialty slot. Every line is inside the
-- 34-glyph detail row and uses only glyphs the typeface owns.
--
-- ⚠️ KEY ON `specialty`, NEVER ON THE PERK NAME. The specialty is an engine
-- slot a custom perk got hung on and several here are deliberately "wrong"
-- (PhD rides specialty_electriccherry, Wisp Tea rides specialty_nomotionsensor,
-- Death Perception rides specialty_combat_efficiency). That is documented in
-- AetheriumPerks.lua and in memory `perk-specialty-is-a-slot`; it is also what
-- perkData actually carries, so it is the only stable key.
local PERK_COPY = {
	[ "specialty_electriccherry" ]   = { "NO FALL OR BLAST DAMAGE",      "EXPLODE WHEN YOU GO DOWN" },
	[ "specialty_nomotionsensor" ]   = { "HITS CAN SUMMON A WISP",       "IT HUNTS THE NEAREST BOSS" },
	[ "specialty_deadshot" ]         = { "AIM ASSIST LOCKS ONTO HEADS",  "" },
	-- v19.58: a Mage fires no bullets - Double Tap swaps the ice staff to its
	-- faster twin (_tod_upgrades axis_level "doubletap"), so the card says so.
	[ "specialty_doubletap2" ]       = { "BULLETS DEAL DOUBLE DAMAGE",   "MAGE - ICE STAFF FIRES FASTER" },
	[ "specialty_armorvest" ]        = { "RAISES YOUR MAXIMUM HEALTH",   "" },
	[ "specialty_staminup" ]         = { "SPRINT FASTER AND FOR LONGER", "" },
	-- v19.12 — QUICK REVIVE IS STATIC AND SAYS BOTH (user 2026-09-15: "quick
	-- revive moving forward should not be dynamic at all. It should give all the
	-- information for solo and co-op on one panel ... the solo price, co-op
	-- price, and then what it does in solo and co-op").
	--
	-- THE PRICE MOVES INTO THE COPY and the price row is cleared for this perk
	-- alone (see UpdatePerkInfo). Every previous attempt to show ONE number here
	-- had to answer "which party is this?" from the client, and every one of them
	-- got it wrong at some point: a tod_party dvar read that returned co-op when
	-- it failed (v18.99l), then a hint parse that is only as right as whatever
	-- the server last stamped. A card that states BOTH prices cannot be wrong
	-- about the party, because it no longer asks.
	--
	-- ⚠️ THE CHARGE IS STILL PER-PARTY and still correct: _tod_perk_lights::
	-- solo_qr_price_fix sets the trigger cost to 500 solo / 1500 co-op after
	-- stock settles the party (all_players_connected). This changes what the
	-- panel SAYS, never what the machine takes.
	[ "specialty_quickrevive" ]      = { "SOLO $500 - REVIVE YOURSELF 3 TIMES", "CO-OP $1500 - REVIVE TEAMMATES FASTER" },
	[ "specialty_fastreload" ]       = { "RELOAD MUCH FASTER",           "" },
	[ "specialty_widowswine" ]       = { "MELEE AND GRENADES WEB ZOMBIES", "" },
	-- v19.72: Death Perception outlines EVERY enemy (it skipped bosses and
	-- elites until then, and the old patch notes said so - hence line 2).
	[ "specialty_combat_efficiency" ] = { "SEE EVERY ENEMY THROUGH WALLS", "EVEN BOSSES AND ELITES" },
}

function CoD.PromptPerks.SetFooter( self, verb )
	CoD.TodPromptCard.SetFooter( self, verb )
end

function CoD.PromptPerks.new( menu, controller )
	local self = LUI.UIElement.new()

	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end

	self:setUseStencil( false )
	self:setClass( CoD.PromptPerks )
	self.id = "PromptPerks"
	self.soundSet = "HUD"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self:setAlpha( 0 )  -- start hidden

	-- The PER-PERK art is set by UpdatePerkInfo and is better than any generic
	-- bottle — the nine machines each have their own i_tod_perk_* image. This
	-- is only what the well holds before a perk lands, and as of 2026-09-14 it
	-- is our own bottle (docs/136) instead of the stock documents glyph.
	CoD.TodPromptCard.Build( self, {
		icon   = "i_tod_prompt_icon_perk",
		footer = "BUY",
	} )

	CoD.TodPromptCard.SetTitle( self, "PERK MACHINE" )
	CoD.TodPromptCard.SetDetail( self, "", "" )
	CoD.TodPromptCard.SetPrice( self, nil )

	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end

	return self
end

-- Called by ZMCursorHintNew when a perk hint lands, with the row it matched out
-- of CoD.AetheriumPerks plus the raw hint.
function CoD.PromptPerks.UpdatePerkInfo( self, perkData, hintText )
	if not perkData then
		return
	end

	-- v19.18 — QUICK REVIVE GETS THE WIDE CARD, and only Quick Revive. It is the
	-- one prompt in the map that states two prices and two behaviours, and on the
	-- standard chassis those two lines had to shrink to fit. Set BEFORE the title
	-- and copy below, so every row is laid out once against the final columns.
	CoD.TodPromptCard.SetWide( self, perkData.specialty == "specialty_quickrevive" )

	-- Re-resolve the key every time: device and binds are read at the moment
	-- the line is set, not at HUD load.
	CoD.TodPromptCard.SetFooter( self, "BUY" )

	if perkData.name then
		CoD.TodPromptCard.SetTitle( self, Engine.Localize( perkData.name ) )
	end

	-- Our short copy if we have it, otherwise the shared table's long line —
	-- sanitized and shrunk by the card rather than dropped. A perk added later
	-- without a PERK_COPY row still says something true.
	local copy = perkData.specialty and PERK_COPY[ perkData.specialty ]
	if copy then
		CoD.TodPromptCard.SetDetail( self, copy[ 1 ], copy[ 2 ] )
	elseif perkData.description then
		CoD.TodPromptCard.SetDetail( self, Engine.Localize( perkData.description ), "" )
	else
		CoD.TodPromptCard.SetDetail( self, "", "" )
	end

	-- v19.12 — QUICK REVIVE PRINTS NO PRICE ROW: both of its prices are in the
	-- two copy lines above, so a single number here could only contradict one of
	-- them. Every other perk is a fixed price and keeps the row unchanged.
	--
	-- ⚠️ NOT AN EARLY RETURN. The icon is set at the END of this function, and
	-- returning here would leave Quick Revive wearing the PREVIOUS machine's
	-- picture — the same shape of bug as the price it is replacing.
	local cost = nil
	local source = "static_both_prices"
	if perkData.specialty == "specialty_quickrevive" then
		CoD.TodPromptCard.SetPrice( self, nil )
	else
		cost = HintCost( hintText )
		source = "hint"
		if cost == nil then
			-- Fixed-price perks retain the table fallback. A variable-price perk has
			-- no safe default; clear a previous machine's price rather than lie.
			if perkData.soloCost == nil then cost = perkData.cost end
			source = "missing_hint_cost"
		end
		CoD.TodPromptCard.SetPrice( self, cost )
	end

	-- Stock LUI's developer log channel; only record transitions, and keep one
	-- signature per widget rather than a growing history.
	local shown = cost ~= nil and tostring( cost ) or ""
	local signature = tostring( perkData.specialty ) .. ":" .. shown .. ":" .. source
	if self.todPriceLog ~= signature then
		self.todPriceLog = signature
		DebugPrint( "[TOD_PERK_PRICE] rev=hint2 perk=" .. tostring( perkData.specialty )
			.. " shown=" .. shown .. " source=" .. source .. " hint=" .. tostring( hintText ) )
	end

	if perkData.image then
		CoD.TodPromptCard.SetIconImage( self, perkData.image )
	end
end
