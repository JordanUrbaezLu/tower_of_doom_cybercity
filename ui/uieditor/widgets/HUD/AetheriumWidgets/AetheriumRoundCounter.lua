require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodUIOwnership" )
-- =============================================================================
-- AetheriumRoundCounter — "ROUND n", top right, in the map's own typeface.
--
-- v17.25 (user 2026-09-04): "We have the round image in the top right of screen
-- but I am looking to replace with the alphabet and letters we have downloaded.
-- so I want it to be Round X. Instead of how stock cod does it. Lets remove
-- stock and track ourselves."
--
-- WHAT WAS HERE: CoD.ZmRndContainer, the vanilla BO3 round widget — its own
-- baked digit images, its own round-change animation, its own idea of what a
-- round counter looks like. It is GONE, require and all. Nothing else in this
-- tree references it.
--
-- ---------------------------------------------------------------------------
-- THE NUMBER COMES FROM US, NOT FROM THE ENGINE.
--
-- The obvious shortcut was the engine's own "gameScore.roundsPlayed" model,
-- which is free and needs no GSC at all. It was NOT taken, for a reason that is
-- visible three lines away in AetheriumStartMenu.lua: the pause menu reads that
-- model and prints `math.max( 1, roundsPlayed - 1 )`. Whatever that model
-- counts, it is not "the round number" — somebody had to subtract one to make
-- it read right, and this map overrides stock's whole round flow (the twist:
-- the next round starts when the last zombie of this one SPAWNS,
-- _tod_endless_rounds.gsc replaces round_wait_func, zombie_round_change_custom
-- and func_get_delay_between_rounds). Reading a stock counter through three
-- replaced functions and an unexplained -1 is how a HUD ends up off by one in
-- exactly the mode nobody tests.
--
-- So _tod_gauge.gsc pushes level.round_number — the number the SERVER acts on,
-- the one the boss cadence and the spawn budget read — down the int-only
-- LuiNotifyEvent lane as "tod_round". That lane costs ZERO clientuimodel bits,
-- which is the whole reason it is used here: the clientuimodel pool sits at 60
-- of its PROVEN 61 bits (_tod_upgrade_ui.gsc), and a round number needs ten.
--
-- IT IS CHANGE-GATED SERVER-SIDE, so a fresh HUD hears nothing until the round
-- flips. _tod_upgrade_ui::player_lui_life clears p.tod_round_shown on every
-- spawn for exactly that reason — same list the tower gauge's re-arms are on.
-- Until the first push lands this reads ROUND 1, which is also the truth.
--
-- CoD.TodRound is published for the pause menu, so the two readouts can never
-- disagree (same cross-menu global trick as CoD.TodOwned).
--
-- ---------------------------------------------------------------------------
-- LAYOUT. Canvas 1280x720; x1.5 = 1080p, and there is no post-scale arithmetic
-- because AetheriumHud.lua no longer wraps this widget in TodScaleHud — same
-- move AetheriumLoadout made, and for the same reason: at 1.15 about (1175,75)
-- a right edge of 1268 lands at 1282, two pixels off the screen.
--
--   right edge 1268   FLUSH with the tower gauge (tod_upgrade.lua GA_X 1216 +
--                     GA_W 52) and with the gun HUD, which was pushed to the
--                     same edge in v17.22. Three right-hand elements, one line.
--   baseline 60       the cells span y30.5..62.6, so the block clears the
--                     gauge's top at y150 by eighty-seven canvas pixels.
--                     Nothing else is authored in this corner.
--
-- ONE STRING, ONE SIZE (user 2026-09-04: "Why are they not the same size?").
-- The first cut set the word at cap 16 against the number's 40 — a deliberate
-- hierarchy, and it read as a mistake, which is the only verdict that counts.
-- Both are now RC_CAP, and the way they are kept equal is that there is nothing
-- left to keep in step: "ROUND n" is ONE string through ONE row, so the size,
-- the baseline, the tracking and the word space all come from the same call.
-- Two rows with two caps and a hand-tuned gap between them was three numbers
-- that could disagree; this is one.
--
-- The gap is the TYPEFACE'S OWN space advance (TOD_SPACE_ADV, 30% of the cell)
-- rather than a constant invented here — the same space the gun HUD sets
-- between the words of "BLITZKRIG 99". Mixing the two sheets on one line is the
-- proven path, not a new one: the weapon-name row does it for every "AK-47".
--
-- SIZE AND HEIGHT, both set from play (user 2026-09-04, after seeing 34 at
-- baseline 96): "Lets move it up a bit more towards the corner and make it 25%
-- smaller." RC_CAP 34 -> 25.5 is that 25% exactly, not a re-guess, and because
-- the readout is one string it is the ONLY number that had to move to shrink
-- it — the word, the number, the tracking and the word space all scale off it.
--
-- The baseline follows the shrink rather than being chosen independently. Left
-- at 96 a smaller block would have drifted DOWN the screen, since the row hangs
-- glyphs UP from the baseline: cap 25.5 at baseline 96 tops out at y66, nine
-- canvas pixels LOWER than cap 34 did. Baseline 60 puts the block at
-- y30.5..62.6 (physical 46..94 at 1080p), which also lands its top edge on the
-- LUCK bar cluster's — the mirror readout in the opposite corner.
--
-- RC_R IS NOT PART OF "towards the corner". It stays 1268 because that edge is
-- shared with the tower gauge and the gun HUD, and the remaining 12 canvas
-- pixels to the screen edge are not worth breaking a three-element alignment
-- for. Widths for reference: 188 physical px at one digit, 255 at three.
-- =============================================================================

require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodGlyphRow" )

-- Canvas geometry. RC_R moves the whole readout sideways, RC_BASE up and down,
-- RC_CAP resizes ALL of it — word and number together, because they are one
-- string. Three numbers, no fourth.
local RC_R    = 1268
local RC_BASE = 60
local RC_CAP  = 25.5   -- 38 physical px at 1080p, word and number alike

CoD.AetheriumRoundCounter = InheritFrom( LUI.UIElement )
CoD.AetheriumRoundCounter.new = function ( menu, controller )
	local self = LUI.UIElement.new()
    CoD.TodUIOwnership.Attach( self )

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumRoundCounter )
	self.id = "AetheriumRoundCounter"
	self.soundSet = "HUD"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self.anyChildUsesUpdateState = true

	-- ONE pool, created once. "ROUND" is five glyphs and the number at most four;
	-- the space between them consumes no slot (the row advances the pen and
	-- moves on), so nine is the ceiling and ten is the headroom.
	self.row = CoD.TodGlyphRow.make( self, 10 )

	local round = 1

	local function paint()
		-- nameSet, not digitSet: this string mixes both sheets, exactly as the
		-- gun HUD's weapon name does. The row cap-normalizes them onto the
		-- shared baseline, which is what makes "ROUND" and "1" the same height
		-- despite being drawn on cells of different sizes.
		-- %d, not concatenation: `round` came through math.floor and Lua would
		-- render a float as "3.0" — and "." IS a glyph on the letter sheet, so
		-- that would draw silently rather than fail.
		self.row.set( string.format( "ROUND %d", round ), RC_CAP, RC_R, RC_BASE,
			CoD.TodGlyphRow.nameSet )
	end

	paint()
	CoD.TodRound = round

	-- The GSC feed. Same PerController scriptNotify lane the kill feed, the
	-- powerup notification and the max-HP readout already ride.
	self:subscribeToGlobalModel( controller, "PerController", "scriptNotify", function ( model )
		if Engine.GetModelValue( model ) ~= "tod_round" then
			return
		end
		local d = CoD.GetScriptNotifyData( model )
		local r = d and tonumber( d[ 1 ] )
		if r == nil then
			return
		end
		r = math.floor( r )
		-- Refuse a nonsense value rather than draw one: this element has no
		-- other source to fall back to, and a blanked round counter is a
		-- support ticket.
		if r < 1 or r == round then
			return
		end
		round = r
		CoD.TodRound = r
		paint()
	end )

	return self
end
