require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodUIOwnership" )
-- Aetherium Custom Scoreboard Widget
-- BO6-style scoreboard with custom design

CoD.AetheriumScoreboard = InheritFrom( LUI.UIElement )

-- ===========================================================================
-- [tod v15 item 13] YOUR UPGRADES, ON THE SCOREBOARD
-- ===========================================================================
-- User: "Can we put the upgrade menu in the scoreboard as well so players can
-- move and read?" The owned-upgrades list previously existed ONLY in the pause
-- menu, which freezes you. The scoreboard is a plain HUD widget with no focus
-- lock, so the player keeps moving while it is up — which is the whole ask.
--
-- THE DATA IS ALREADY HERE AND COSTS NOTHING NEW. CoD.TodOwned is populated by
-- the always-open `tod_upgrade` HUD menu from the GSC spawn push, NOT by the
-- pause menu opening — AetheriumStartMenu.lua is a plain reader of the same
-- global. So a player who has never opened the pause menu still has a full
-- table here. No clientfield, no new LuiNotifyEvent, no GSC change at all.
-- (That mattered: the clientuimodel pool is at 60 of a proven 61 bits and
-- overflow is a map-load abort, not a glitch.)
--
-- PERSONAL LIST ONLY. Showing all four players' upgrades would need a fourth
-- int on the sync event, and 4-arg LuiNotifyEvent is stock-proven but not
-- tod-proven — not worth spending on a convenience panel.
--
-- THE PAUSE PLATES, NOT TEXT ROWS (user 2026-09-01: "we should just reuse the
-- images on the pause menu since those are too good"). This panel now draws the
-- SAME baked art AetheriumStartMenu.lua draws — i_tod_pause_hdr, one
-- i_tod_pause_r<NN> name plate per domain, i_tod_pause_pip / _pip_empty level
-- pips, i_tod_pause_reset_mark and i_tod_pause_legend_reset. Same images, same
-- meaning, two screens: nothing new was baked and nothing new was zoned. It also
-- settles the images-over-LUI rule for this panel, which the text version was
-- the one live exception to.
--
-- THE COMMENT THAT USED TO SIT HERE ARGUED FOR TEXT ON THE GROUND THAT A NEW
-- DOMAIN COULD RENDER AS A BLANK PLATE. That risk is real, and it is handled the
-- way the pause menu handles it rather than by avoiding art: TOD_UPG_PLATE_MAX
-- below is the highest id with baked row art, and ids above it fall back to a
-- text label. RegisterImage on a missing image is undefined behavior, so nothing
-- here ever reaches for a plate that does not exist. Note the test is a <= over
-- a CONTIGUOUS range — r01..r43 all exist on disk, including the eight RETIRED
-- but still-mapped ids (9, 11, 12, 22, 28, 30, 32, 34), which a player can
-- legitimately still hold a level in.
-- ⚠️ LOCKSTEP: the same number lives in AetheriumStartMenu.lua as
-- PAUSE_PLATE_MAX. Raise BOTH when new row art lands, or one screen shows a
-- plate where the other shows text.
--
-- THE SPACE IS TIGHTER HERE THAN IN THE PAUSE MENU, AND THE BOUNDS ARE REAL
-- ELEMENTS, NOT TASTE (the user flagged this up front: "we may have less space
-- on that screen"). Measured against this widget's own geometry:
--   * TOP y=90. map_info_bg is x15..323, y48..86 — the panel clears it.
--   * BOTTOM y=392. The player rows FILL FROM THE BOTTOM and the column header
--     is re-topped to sit directly above the top-most one (see the Visible
--     clip), so the header's HIGHEST possible top is the four-player case,
--     y=397. Four players is the worst case and the only one worth planning
--     against.
--   * WIDTH is the compensation. The pause panel is walled in at x=814 by
--     BGBlood; this one has the full 1280.
-- That is 302 usable pixels of height against the pause menu's 413, and 1280 of
-- width against its 750. Hence THREE columns of SIX rather than two of seven: 18
-- slots at a 44px pitch (the pause menu's 59), and THE ACTIVATION LINE IS
-- DROPPED. The effect line at your current level is what players open the board
-- to read; the pause menu remains the full readout.
--
-- The AetheriumQuestsCustom widget nominally owns y0..182 across the full width,
-- which would collide head-on — but it is setAlpha(0) in both state clips ("no
-- quest system on this map"), so that band is genuinely free.
--
-- 18 SLOTS IS HEADROOM, NOT A GUESS. v15 item 19 made persistence the rule on a
-- class promotion, which took the worst case from the pause menu's stated 14 to
-- 15 owned rows for a maxed HEAVY. Overflow past 18 prints a truthful "+N MORE"
-- rather than dropping rows silently.
--
-- EVERY SIZE BELOW HOLDS THE ART'S OWN ASPECT — the v6.6 stretched-plate lesson.
-- Read off the PNGs 2026-09-01: hdr 1000x70 (14.2857) -> 400x28; legend_reset
-- 760x56 (13.5714) -> 380x28; r<NN> 300x44 (6.8182) -> 191x28; pip and
-- pip_empty 24x24 and reset_mark 128x128, all square.
--
-- ⚠️ LUI FAILURES ARE SILENT and lint_tod_lua.js only proves bracket balance, so
-- every access below is nil-guarded and the whole thing is wrapped so a nil
-- global can never take the scoreboard down with it.
-- ⚠️ **THIS PANEL IS AREA-BOUND, AND THE BINDING CONSTRAINT IS HEIGHT, NOT
-- WIDTH** (measured 2026-09-01 on the user's "we have more width space to make
-- our images bigger"). They were right that width was being wasted, and it is
-- taken below — but width alone could not have grown the plates, because the
-- plate's ASPECT IS FIXED at 300:44. A wider plate is a taller plate, a taller
-- plate is a taller row, and rows are what the 302px band runs out of. Solved
-- rather than guessed:
--
--   plate h=28 (w=191)  row 45  ->  6 rows/col  = 18 slots   <- was
--   plate h=33 (w=225)  row 50  ->  6 rows/col  = 18 slots   <- IS (the ceiling)
--   plate h=36 (w=245)  row 53  ->  5 rows/col  = 15 slots
--   plate h=44 (w=300)  row 61  ->  4 rows/col  = 12 slots   <- native art size
--
-- **h=33 IS THE LARGEST PLATE THAT STILL FITS 18 SLOTS**, and it is an EXACT
-- aspect match — 300:44 reduces to 225:33 in whole pixels, the only clean
-- multiple in the usable range. +18% linear on every plate for free. Anything
-- past it BUYS PIXELS WITH ROWS: 245-wide plates cost 3 slots, native 300-wide
-- art costs 6 and would put a maxed HEAVY's list behind "+3 MORE". That trade is
-- available and is a design call, not a technical limit — it is not taken here
-- because hiding owned upgrades to enlarge the label defeats the panel.
--
-- WHERE THE 32px CAME FROM. The header and legend used to sit at y96..124,
-- directly above the rows, which cost the panel a whole row of growth. They now
-- sit at y56..84 BESIDE the map-info block, which only reaches x=323 — so
-- everything at x>330 is free to the top of the screen. That band was invisible
-- until the quest widget was deleted, and reclaiming it is what pays for h=33.
--
-- THE WIDTH THE USER SAW IS ALSO TAKEN: margins 50 -> 30 and columns 350 -> 389,
-- which additionally gives the effect line +45px and lets it come up from 0.82
-- to 0.90 scale. Right edge 1249; 30px margins each side are deliberate TV
-- overscan headroom, not slack.
local TOD_UPG_COLS       = 3
local TOD_UPG_ROWS_COL   = 6                  -- per column; 3 x 6 = 18 slots
local TOD_UPG_COL_X      = { 30, 445, 860 }   -- 26px gaps; col 3 ends at 1249, matching the 30px left margin
local TOD_UPG_COL_W      = 389
local TOD_UPG_Y0         = 92                 -- 8px under the header band (bottom 84)
local TOD_UPG_ROW_H      = 50                 -- last row: 92 + 5*50 + 33 + 16 = 391 <= 392
local TOD_UPG_PLATE_W    = 225                -- 300x44 art at EXACT 3/4 scale
local TOD_UPG_PLATE_H    = 33
local TOD_UPG_PIP_D      = 13
local TOD_UPG_PIP_PITCH  = 15                 -- plate + a full 10-pip run = 381 <= COL_W 389
local TOD_UPG_PLATE_MAX  = 57                 -- LOCKSTEP with AetheriumStartMenu.lua's PAUSE_PLATE_MAX, and lint_tod_assets.js FAILS the build when they differ (2026-09-10). It sat at 47 while the pause menu went to 56 (r48..r56: the eight Mage rows and MYSTICAL HANDS), so every Mage row here was a text label with no red dark plate -- user: "Saw some misses there". r47 DEADSHOT 2026-09-03 (docs/85); r46 TRAILBLAZER; r45 RIOT SHIELD; r44 GUNSLINGER.

-- [tod 2026-09-27] ONE THING ON SCREEN AT A TIME (tester Nikolai: the upgrades
-- panel sat under the EXTRACT OR ASCEND plate and under YOU ESCAPED THE TOWER).
-- Two rules, both from the player's side:
--   * The board is a FORCED end screen (stock's forceScoreboard at game end):
--     the banner and the kills / downs / points rows are what everyone came to
--     read, so the upgrades panel stays down for it. The pause menu still has it.
--   * The player OPENED the board: they asked for it, so the board wins and the
--     server tucks that player's centre banners away until it closes
--     (SendMenuResponse below -> _tod_upgrade_ui::scoreboard_watch). Server
--     hudelems cannot read a LUI bit, which is why the server has to be told.
-- [tod v19.58] THE MAP'S TYPEFACE ON THE WHOLE BOARD (user 2026-09-27: "replace
-- all the text on the screen like ... score board descriptions ... add the
-- typography for the map"). TodLabel() is a drop-in for LUI.UIText.new() drawn
-- from the baked glyph sheets; engine text only if the widget is missing.
-- Player names pass a TTF fallback: a name with NO drawable character (all
-- CJK, all emoji) shows in a real font rather than vanishing.
local function TodLabel( opts )
	if CoD.TodGlyphText and CoD.TodGlyphText.Label then
		local ok, e = pcall( CoD.TodGlyphText.Label, opts )
		if ok and e then
			return e
		end
	end
	return LUI.UIText.new()
end

-- 2026-10-01 (docs/167 item 12): the line under MAP / ROUND names the floor
-- (CoD.TodFloorLabelText, AetheriumHud.lua); the map name before the first push.
local function TodFloorLine( controller )
	if CoD.TodFloorLabelText then
		local s = CoD.TodFloorLabelText( controller )
		if s then
			return s
		end
	end
	return Engine.Localize( CoD.UsermapName or "MAP_NAME" )
end

local function TodForcedBoard( controller )
	local fm = Engine.GetModel( Engine.GetModelForController( controller ), "forceScoreboard" )
	return fm ~= nil and Engine.GetModelValue( fm ) == 1
end

local function TodHideUpgradeList( self )
	if self.todUpgHeader then self.todUpgHeader:setAlpha( 0 ) end
	if self.todUpgLegend then self.todUpgLegend:setAlpha( 0 ) end
	if self.todUpgRows then
		for i = 1, #self.todUpgRows do
			if self.todUpgRows[ i ] then
				self.todUpgRows[ i ]:close()
			end
		end
		self.todUpgRows = {}
	end
end

-- [tod v19.58] THE END-SCREEN LINES. The stock "You Survived N Rounds" line and
-- the loss screen's "GAME OVER - FLOOR N" were server hudelem text (engine
-- font). _tod_gameover::end_screen_push now sends ( kind, rounds, floor ) on
-- "tod_gameover" and fades the stock line out; the forced end board draws them
-- here in the map's typeface. kind 1 = loss (both lines, top centre, where the
-- stock lines sat); kind 2 = a won ending (the banner art carries the title;
-- the survived line sits under it, clear of the four-player header at 397).
local function TodEndLines( self, controller )
	local e = CoD.TodEndScreen
	local on = TodForcedBoard( controller ) and e ~= nil
	if not self.todEndTitle or not self.todEndSurvived then
		return
	end
	if not on then
		self.todEndTitle:setAlpha( 0 )
		self.todEndSurvived:setAlpha( 0 )
		return
	end
	local rounds = e.rounds or 1
	self.todEndSurvived:setText( "YOU SURVIVED " .. rounds .. ( rounds == 1 and " ROUND" or " ROUNDS" ) )
	-- [tod v19.76] THE BOARD'S OWN "ROUND" READS THE SAME NUMBER (lead tester
	-- Nikolai, Oct 2026, three games in a row: the header said ROUND 3 under
	-- "YOU SURVIVED 4 ROUNDS"). The header was painted only when the stock
	-- roundsPlayed model changed, from whatever CoD.TodRound held at that moment;
	-- our tod_round push lands a beat AFTER the stock flip, so the header kept the
	-- previous round. At the end both lines now show the server's one number.
	if self.round_number then
		self.round_number:setText( Engine.Localize( tostring( rounds ) ) )
	end
	if e.kind == 1 then
		self.todEndTitle:setText( ( e.floor and e.floor > 0 ) and ( "GAME OVER - FLOOR " .. e.floor ) or "GAME OVER" )
		self.todEndTitle:setAlpha( 1 )
		self.todEndSurvived:setTopBottom( true, false, 196, 220 )
	else
		self.todEndTitle:setAlpha( 0 )
		self.todEndSurvived:setTopBottom( true, false, 360, 384 )
	end
	self.todEndSurvived:setAlpha( 1 )
end

local function TodBuildUpgradeList( self )
	-- Tear down last open's rows. One handle, closed before rebuild — the
	-- state-pool leak doctrine this kit has already been bitten by twice. EVERY
	-- element an open creates goes into this one list — plates, pips, badges and
	-- text alike — so nothing can outlive it. The header and the legend are the
	-- deliberate exceptions: they are built ONCE at construction and only
	-- alpha-toggled here, because their geometry never depends on the data.
	if self.todUpgRows then
		for i = 1, #self.todUpgRows do
			if self.todUpgRows[ i ] then
				self.todUpgRows[ i ]:close()
			end
		end
	end
	self.todUpgRows = {}

	local function hideChrome()
		if self.todUpgHeader then self.todUpgHeader:setAlpha( 0 ) end
		if self.todUpgLegend then self.todUpgLegend:setAlpha( 0 ) end
	end

	local owned = CoD.TodOwned
	local info = CoD.TodDomainInfo
	if type( owned ) ~= "table" then
		hideChrome()
		return
	end

	-- AT THE TOP TIER THERE IS NOTHING LEFT TO LOSE — the same rule the pause
	-- menu applies, read off the same row, so the two screens can never badge
	-- differently. Row 24 is the CLASS TIER row: lvl = the current tier, max =
	-- tier_max(), compared as lvl >= max rather than against a hardcoded 3.
	-- ABSENT MEANS TIER 1, not "unknown" — that row is only sent from tier 2 on
	-- — so the nil path must leave the badges showing.
	local tierRow = owned[ 24 ]
	local atTopTier = tierRow ~= nil and tierRow.lvl ~= nil and tierRow.max ~= nil
	                  and tierRow.lvl >= tierRow.max

	-- Collect held domains. Ids run 1..63 (the domain-id field is 6 bits);
	-- the body is nil-guarded so unused ids cost nothing.
	local rows = {}
	for id = 1, 63 do
		local o = owned[ id ]
		if o and o.lvl and o.lvl > 0 and id ~= 24 then   -- 24 is the CLASS TIER row, not an upgrade
			local name = ( info and info[ id ] and info[ id ].name ) or ( "UPGRADE " .. id )
			local eff = nil
			if CoD.TodDomainDesc then
				eff = CoD.TodDomainDesc( id, o.lvl, o.dark )   -- v17.10
			end
			if not eff then
				eff = ( info and info[ id ] and info[ id ].desc ) or ""
			end
			rows[ #rows + 1 ] = {
				id = id,
				-- DARK UPGRADE (fix 2026-09-04, user: "Also check the scoreboard
				-- menu as well. Also not wired up correctly"). v17.10 passed
				-- o.dark into TodDomainDesc above, so this panel has printed the
				-- DARK VALUE since the day the feature landed — and then drew the
				-- ordinary blue plate over it, so the number moved with nothing on
				-- screen saying why. HALF-WIRING IS WORSE THAN NOT WIRING: a plain
				-- row showing a number the plain row cannot explain reads as a bug
				-- in the number.
				dark = ( o.dark == true ),
				lvl = o.lvl,
				-- o.max is ALREADY UNPACKED. GSC sync_max() adds 100 to the max
				-- arg to smuggle the survives-promotion bit through an int-only
				-- LuiNotifyEvent (no 4-arg form exists in-tree); tod_upgrade.lua
				-- strips the 100 into .safe before storing. Never re-mask here.
				max = o.max or 10,
				name = name,
				eff = eff,
				-- THE BADGE IS SERVER-COMPUTED, AND ONLY SERVER-COMPUTED HERE.
				-- The bit is set by the same domain_survives_tier() that
				-- tier_up's reset actually runs, so badge and reset cannot
				-- disagree. AetheriumStartMenu.lua additionally carries a static
				-- TIER_RESETS table for the o.safe == nil case; this
				-- deliberately does NOT copy it. A duplicated list of 13 ids is
				-- a second source of truth that nothing regenerates, and it has
				-- already had to be INVERTED once (v15 item 19). That path is
				-- dead anyway: tod_upgrade.lua writes .safe as true or false on
				-- every row and never leaves it nil. So unknown reads as SAFE —
				-- a missing warning is a smaller lie than a confident wrong one.
				resets = ( o.safe == false ) and ( not atTopTier ),
			}
		end
	end

	if #rows == 0 then
		hideChrome()
		return
	end
	if self.todUpgHeader then self.todUpgHeader:setAlpha( 1 ) end

	local cap = TOD_UPG_ROWS_COL * TOD_UPG_COLS
	local shown = #rows
	local overflow = 0
	if shown > cap then
		overflow = shown - cap
		shown = cap
	end

	-- Balance the columns, and only open a column when there is enough to fill
	-- one: a 4-row list reads as a single short block, not as three stubs side
	-- by side. perCol is the tallest column and columns fill left to right;
	-- ceil( shown / 3 ) * 3 >= shown is what guarantees col never exceeds 3.
	local perCol
	if shown <= TOD_UPG_ROWS_COL then
		perCol = shown
	elseif shown <= TOD_UPG_ROWS_COL * 2 then
		perCol = math.ceil( shown / 2 )
	else
		perCol = math.ceil( shown / TOD_UPG_COLS )
	end

	local anyReset = false

	for i = 1, shown do
		local r = rows[ i ]
		local col = math.floor( ( i - 1 ) / perCol ) + 1
		local idx = ( i - 1 ) % perCol
		local cx = TOD_UPG_COL_X[ col ] or TOD_UPG_COL_X[ 1 ]
		local y = TOD_UPG_Y0 + idx * TOD_UPG_ROW_H

		-- The name plate, at true aspect. Ids past TOD_UPG_PLATE_MAX have no
		-- baked art and fall back to a text label.
		local darkMark = false   -- 2026-09-09: "DARK: " on the effect line when no red plate is baked
		if r.id <= TOD_UPG_PLATE_MAX then
			local plate = LUI.UIImage.new()
			plate:setLeftRight( true, false, cx, cx + TOD_UPG_PLATE_W )
			plate:setTopBottom( true, false, y, y + TOD_UPG_PLATE_H )
			-- DARK UPGRADE: red plate, or the ordinary plate tinted red where no
			-- red one was baked. CoD.TodDarkPlate (tod_upgrade.lua) owns which,
			-- and the pause menu asks the same function — never inline the rule,
			-- that is exactly how this panel fell a version behind. Nil-guarded
			-- for an older HUD lua, same as CoD.TodDomainDesc above.
			local img, tint = nil, false
			if r.dark and CoD.TodDarkPlate then
				img, tint, darkMark = CoD.TodDarkPlate( r.id, TOD_UPG_PLATE_MAX )
			end
			plate:setImage( RegisterImage( img or string.format( "i_tod_pause_r%02d", r.id ) ) )
			if tint then
				plate:setRGB( 1.0, 0.34, 0.36 )
			end
			self:addElement( plate )
			self.todUpgRows[ #self.todUpgRows + 1 ] = plate
		else
			local label = TodLabel()   -- v19.59b: the typeface here too
			label:setLeftRight( true, false, cx + 4, cx + TOD_UPG_PLATE_W )
			label:setTopBottom( true, false, y + 9, y + 25 )   -- cap 12.8 in the plate slot
			label:setText( Engine.Localize( r.name ) )
			label:setTTF( "fonts/orbitron.ttf" )
			label:setRGB( 0.86, 0.9, 0.95 )
			label:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
			self:addElement( label )
			self.todUpgRows[ #self.todUpgRows + 1 ] = label
		end

		-- Level pips: FILLED to the owned level, then the hollow pip out to the
		-- cap, so the row shows how much room is left as well as what you hold.
		-- Capped at 10 (the highest domain max) to bound the row width.
		local pipN = r.max
		if pipN > 10 then pipN = 10 end
		if pipN < r.lvl then pipN = r.lvl end
		local pipY = y + ( TOD_UPG_PLATE_H - TOD_UPG_PIP_D ) / 2
		for p = 1, pipN do
			local px = cx + TOD_UPG_PLATE_W + 6 + ( p - 1 ) * TOD_UPG_PIP_PITCH
			local pip = LUI.UIImage.new()
			pip:setLeftRight( true, false, px, px + TOD_UPG_PIP_D )
			pip:setTopBottom( true, false, pipY, pipY + TOD_UPG_PIP_D )
			if p > r.lvl then
				pip:setImage( RegisterImage( "i_tod_pause_pip_empty" ) )
			else
				pip:setImage( RegisterImage( "i_tod_pause_pip" ) )
			end
			self:addElement( pip )
			self.todUpgRows[ #self.todUpgRows + 1 ] = pip
		end

		-- TIER-UP WARNING BADGE, at the head of the effect line — the same place
		-- the pause menu puts it, and for the same reason: the plate plus a full
		-- 10-pip run already reaches cx+337 of a 350-wide column, so the effect
		-- line's left margin is the row's one piece of guaranteed empty space.
		local effX = cx + 2
		if r.resets then
			anyReset = true
			local mark = LUI.UIImage.new()
			mark:setLeftRight( true, false, cx + 2, cx + 16 )
			mark:setTopBottom( true, false, y + 35, y + 49 )
			mark:setImage( RegisterImage( "i_tod_pause_reset_mark" ) )
			self:addElement( mark )
			self.todUpgRows[ #self.todUpgRows + 1 ] = mark
			effX = cx + 21   -- indent the text clear of the badge
		end

		-- WHAT IT DOES, at this player's current level. The wider column (389 vs
		-- the old 350) is spent here as well as on the plate: +45px of line and
		-- 0.82 -> 0.90 scale, so the longer effect strings stop crowding.
		local effLine = TodLabel()
		effLine:setLeftRight( true, false, effX, cx + TOD_UPG_COL_W - 4 )
		effLine:setTopBottom( true, false, y + 34, y + 50 )
		effLine:setText( darkMark and ( "DARK: " .. r.eff ) or r.eff )
		effLine:setTTF( "fonts/orbitron.ttf" )
		effLine:setRGB( 0.42, 0.92, 1 )
		-- v19.59: 1.0 in the typeface (0.90 was tuned for the engine font and
		-- drew 11.5-unit caps). Box y+34..50 -> cap 12.8 on baseline y+49, clear
		-- of this row's plate (y+33) and the next row's (y+50).
		effLine:setScale( 1.0 )
		effLine:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
		self:addElement( effLine )
		self.todUpgRows[ #self.todUpgRows + 1 ] = effLine
	end

	-- THE LEGEND explains the badge, so it shows only when a badge is on screen.
	-- Pinned to the top right of the header band rather than chased down the
	-- panel the way the pause menu does it: here the rows can end anywhere
	-- between y=172 and y=390, and there is no spare row of height below them.
	if self.todUpgLegend then
		self.todUpgLegend:setAlpha( anyReset and 1 or 0 )
	end

	-- Can only fire past 18 concurrent domains (worst case today is 15, a maxed
	-- HEAVY). Better a truthful count than silently dropped rows.
	if overflow > 0 then
		-- MOVED WITH THE HEADER (2026-09-01). Its old y102..118 is now the second
		-- row of column 2 — the rows start at y=92 since the header vacated that
		-- band. It sits in the gap between header (ends 740) and legend (starts
		-- 869), the one place in the top band that is free whatever else shows.
		local more = TodLabel()   -- v19.59b: the typeface here too
		more:setLeftRight( true, false, 752, 862 )
		more:setTopBottom( true, false, 62, 80 )
		more:setText( "+" .. overflow .. " MORE" )
		more:setTTF( "fonts/orbitron.ttf" )
		more:setRGB( 0.6, 0.66, 0.74 )
		more:setScale( 0.8 )
		more:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
		self:addElement( more )
		self.todUpgRows[ #self.todUpgRows + 1 ] = more
	end
end

local PreLoadFunc = function ( self, controller )
	-- Set scoreboard UI models (BO6 pattern)
	if CoD.ScoreboardUtility and CoD.ScoreboardUtility.SetScoreboardUIModels then
		CoD.ScoreboardUtility.SetScoreboardUIModels( controller )
	end
end

local PostLoadFunc = function ( self, controller )
	-- Subscribe to scoreboard open/close events
	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN ), function ( model )
		local isOpen = Engine.GetModelValue( model )
		self.m_inputDisabled = not isOpen
		-- Tell the server, change-only (see TodForcedBoard above). A new HUD
		-- starts with todSbSent nil, so its first fire re-syncs a "closed".
		local open = ( isOpen ~= nil and isOpen ~= 0 and isOpen ~= false )
		if self.todSbSent ~= open and Engine.SendMenuResponse then
			self.todSbSent = open
			Engine.SendMenuResponse( controller, "StartMenu_Main", "tod_sb|" .. ( open and "1" or "0" ) )
		end
	end )
end

CoD.AetheriumScoreboard.new = function ( menu, controller )
	local self = LUI.UIElement.new()
    CoD.TodUIOwnership.Attach( self )

	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumScoreboard )
	self.id = "AetheriumScoreboard"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self:makeFocusable()
	self.onlyChildrenFocusable = true
	self.anyChildUsesUpdateState = true

	-- ========================================
	-- BACKGROUND LAYERS
	-- ========================================

	-- Main background overlay
	self.bg_overlay_1 = LUI.UIImage.new()
	self.bg_overlay_1:setLeftRight( true, false, 1, 1281 )
	self.bg_overlay_1:setTopBottom( true, false, 0, 720 )
	self.bg_overlay_1:setImage( RegisterImage( "i_mtl_image_67c0e1be4519503c" ) )
	self.bg_overlay_1:setRGB( 1, 1, 1 )
	self:addElement( self.bg_overlay_1 )

	-- Background particles
	self.bg_particles = LUI.UIImage.new()
	self.bg_particles:setLeftRight(true, false, 1, 1281)
	self.bg_particles:setTopBottom(true, false, 0, 720)
	self.bg_particles:setImage( RegisterImage( "i_mtl_image_2a0561747aef24aa" ) )
	self.bg_particles:setRGB( 1, 1, 1 )
	self:addElement( self.bg_particles )

	-- Secondary overlay
	self.bg_overlay_2 = LUI.UIImage.new()
	self.bg_overlay_2:setLeftRight(true, false, 1, 1281)
	self.bg_overlay_2:setTopBottom(true, false, 0, 720)
	self.bg_overlay_2:setImage( RegisterImage( "i_mtl_image_40d71e2f7898114c" ) )
	self.bg_overlay_2:setRGB( 1, 1, 1 )
	self:addElement( self.bg_overlay_2 )

	-- QUEST BAND — REMOVED (user 2026-09-01: "the top of the scoreboard menu is
	-- not needed for us. That's like easter egg and parts that this map doesn't
	-- have"). Correct: it drew a Power icon, three SHIELD PARTS slots, five
	-- EASTER EGG ITEMS slots and three WONDER WEAPON slots, all on the same
	-- placeholder image, for three systems this map has none of.
	--
	-- IT WAS ALREADY setAlpha(0) IN BOTH STATE CLIPS, and it is being DELETED
	-- anyway rather than left to the alpha. A guard nobody has watched fire is
	-- not a guard: nothing in this repo has ever confirmed that alpha on this
	-- container actually cascades to its ~20 children, and "it should" is the
	-- reasoning that has already cost this map two bugs. Deleting is correct in
	-- BOTH worlds — a no-op if the alpha worked, the fix if it did not — and it
	-- takes ~20 elements out of the pool either way.
	--
	-- Removed the way the compass was (AetheriumHud.lua): instantiation
	-- commented, require dropped since it was function-local here. The two
	-- `if self.questWidget then ... setAlpha(0)` sites in the state clips below
	-- are left in place — with the field never assigned they are no-ops, and
	-- keeping them makes this a four-line uncomment to bring back.
	--
	-- local AetheriumQuestsCustom = require("ui.uieditor.widgets.HUD.AetheriumWidgets.Scoreboard.AetheriumQuestsCustom")
	-- self.questWidget = AetheriumQuestsCustom.new(menu, controller)
	-- self:addElement(self.questWidget)

	-- THIS FREES y0..182 ACROSS THE FULL WIDTH. The upgrades panel above already
	-- assumed that band was free (it is why the header sits at y=96); it now is
	-- free by construction rather than by an unverified alpha.


	-- ========================================
	-- PLAYER ROW BACKGROUNDS
	-- ========================================

	-- Player 4 outline
	self.player_4_outline = LUI.UIImage.new()
	self.player_4_outline:setLeftRight(true, false, 124, 1158)
	self.player_4_outline:setTopBottom(true, false, 526, 558)
	self.player_4_outline:setImage( RegisterImage( "i_mtl_image_6d18dfae10338ee0" ) )
	self.player_4_outline:setRGB( 1, 1, 1 )
	self:addElement( self.player_4_outline )

	-- Player 4 outline background
	self.player_4_outline_bg = LUI.UIImage.new()
    self.player_4_outline_bg:setLeftRight(true, false, 124, 1157)
    self.player_4_outline_bg:setTopBottom(true, false, 526, 557)
	self.player_4_outline_bg:setImage( RegisterImage( "i_mtl_image_67118f82e09c58d9_light" ) )
	self.player_4_outline_bg:setRGB( 1, 1, 1 )
	self:addElement( self.player_4_outline_bg )

	-- Player 3 outline
	self.player_3_outline = LUI.UIImage.new()
	self.player_3_outline:setLeftRight( true, false, 124, 1158 )
	self.player_3_outline:setTopBottom( true, false, 494, 526 )
	self.player_3_outline:setImage( RegisterImage( "i_mtl_image_6d18dfae10338ee0" ) )
	self.player_3_outline:setRGB( 1, 1, 1 )
	self:addElement( self.player_3_outline )

	-- Player 3 outline background
	self.player_3_outline_bg = LUI.UIImage.new()
    self.player_3_outline_bg:setLeftRight(true, false, 124, 1157)
    self.player_3_outline_bg:setTopBottom(true, false, 493, 526)
	self.player_3_outline_bg:setImage( RegisterImage( "i_mtl_image_67118f82e09c58d9_light" ) )
	self.player_3_outline_bg:setRGB( 1, 1, 1 )
	self:addElement( self.player_3_outline_bg )

	-- Player 2 outline
	self.player_2_outline = LUI.UIImage.new()
	self.player_2_outline:setLeftRight( true, false, 124, 1158 )
	self.player_2_outline:setTopBottom( true, false, 462, 494 )
	self.player_2_outline:setImage( RegisterImage( "i_mtl_image_6d18dfae10338ee0" ) )
	self.player_2_outline:setRGB( 1, 1, 1 )
	self:addElement( self.player_2_outline )

	-- Player 2 outline background
	self.player_2_outline_bg = LUI.UIImage.new()
    self.player_2_outline_bg:setLeftRight(true, false, 124, 1157)
    self.player_2_outline_bg:setTopBottom(true, false, 462, 493)
	self.player_2_outline_bg:setImage( RegisterImage( "i_mtl_image_67118f82e09c58d9_light" ) )
	self.player_2_outline_bg:setRGB( 1, 1, 1 )
	self:addElement( self.player_2_outline_bg )

	-- Player 1 outline
	self.player_1_outline = LUI.UIImage.new()
	self.player_1_outline:setLeftRight( true, false, 124, 1158 )
	self.player_1_outline:setTopBottom( true, false, 430, 462 )
	self.player_1_outline:setImage( RegisterImage( "i_mtl_image_6d18dfae10338ee0" ) )
	self.player_1_outline:setRGB( 1, 1, 1 )
	self:addElement( self.player_1_outline )

	-- Player 1 outline background
	self.player_1_outline_bg = LUI.UIImage.new()
    self.player_1_outline_bg:setLeftRight(true, false, 124, 1157)
    self.player_1_outline_bg:setTopBottom(true, false, 431, 462)
	self.player_1_outline_bg:setImage( RegisterImage( "i_mtl_image_67118f82e09c58d9_light" ) )
	self.player_1_outline_bg:setRGB( 1, 1, 1 )
	self:addElement( self.player_1_outline_bg )

	-- Player hover element (currently not visible - can be enabled for focused player)
	self.player_hover_element = LUI.UIImage.new()
    self.player_hover_element:setLeftRight(true, false, 124, 1156)
    self.player_hover_element:setTopBottom(true, false, 430, 461)
	self.player_hover_element:setImage( RegisterImage( "i_mtl_image_31890d5179c65d58" ) )
	self.player_hover_element:setRGB( 1, 1, 1 )
	self.player_hover_element:setAlpha( 0 ) -- Hidden by default
	self:addElement( self.player_hover_element )

	-- ========================================
	-- BOTTOM INFO (Points & Salvage)
	-- ========================================

	-- Points icon
	self.points_icon = LUI.UIImage.new()
    self.points_icon:setLeftRight(true, false, 537, 556)
    self.points_icon:setTopBottom(true, false, 577, 597)
	self.points_icon:setImage( RegisterImage( "i_tod_hud_points_icon" ) )
	self.points_icon:setRGB( 1, 1, 1 )
	self:addElement( self.points_icon )

	-- Points label
	self.points_label = TodLabel()
	self.points_label:setLeftRight(true, false, 556, 649)
	self.points_label:setTopBottom(true, false, 586, 594)
	self.points_label:setText( Engine.Localize( "Points" ) )
	self.points_label:setTTF( "fonts/ltromatic.ttf" )
	self.points_label:setRGB( 0.941, 0.941, 0.941 )
	self.points_label:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.points_label )

	-- Points value (dynamic - subscribed to player score model)
	self.points_value = TodLabel()
	self.points_value:setLeftRight(true, false, 503, 650)
	self.points_value:setTopBottom(true, false, 600, 625)
	self.points_value:setText( Engine.Localize( "0" ) )
	self.points_value:setTTF( "fonts/ltromatic.ttf" )
	self.points_value:setRGB(0.996078431372549, 0.9921568627450981, 0.4980392156862745)
	self.points_value:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	-- Subscribe to local player score
	self.points_value:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "PlayerList." .. Engine.GetClientNum( controller ) .. ".playerScore" ), function ( model )
		local score = Engine.GetModelValue( model )
		if score then
			self.points_value:setText( Engine.Localize( score ) )
		end
	end )
	self:addElement( self.points_value )

	-- Salvage icon
	self.salvage_icon = LUI.UIImage.new()
	self.salvage_icon:setLeftRight(true, false, 701, 720)
	self.salvage_icon:setTopBottom(true, false, 576, 596)
	self.salvage_icon:setImage( RegisterImage( "i_mtl_ui_icons_zombie_squad_info_salvage" ) )
	self.salvage_icon:setRGB( 1, 1, 1 )
	self:addElement( self.salvage_icon )

	-- Salvage label
	self.salvage_label = LUI.UIText.new()
	self.salvage_label:setLeftRight(true, false, 721, 814)
	self.salvage_label:setTopBottom(true, false, 585, 593)
	self.salvage_label:setText( Engine.Localize( "Salvage" ) )
	self.salvage_label:setTTF( "fonts/ltromatic.ttf" )
	self.salvage_label:setRGB( 0.941, 0.941, 0.941 )
	self.salvage_label:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.salvage_label )

	-- Salvage value (dynamic - would need custom clientfield for salvage system)
	self.salvage_value = LUI.UIText.new()
	self.salvage_value:setLeftRight(true, false, 667, 814)
	self.salvage_value:setTopBottom(true, false, 600, 625)
	self.salvage_value:setText( Engine.Localize( "0" ) )
	self.salvage_value:setTTF( "fonts/ltromatic.ttf" )
	self.salvage_value:setRGB( 0.941, 0.941, 0.941 )
	self.salvage_value:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	-- TODO: Subscribe to salvage model when implemented
	self:addElement( self.salvage_value )

	-- ========================================
	-- TOP LEFT MAP INFO
	-- ========================================

	-- Map info background
	self.map_info_bg = LUI.UIImage.new()
    self.map_info_bg:setLeftRight(true, false, 15, 323)
    self.map_info_bg:setTopBottom(true, false, 48, 86)
	self.map_info_bg:setImage( RegisterImage( "i_mtl_image_6f2d9c8089a2153e" ) )
	self.map_info_bg:setRGB( 1, 1, 1 )
	self:addElement( self.map_info_bg )

	-- Game mode text -> THE FLOOR LINE (2026-10-01, docs/167 item 12: "Remove the
	-- redundant 'round based zombies' text right below the round counter,
	-- replacing it with the map name or floor"). The map name already leads the
	-- line above, so this one says where you are ("FLOOR 23" / "THE CROWN" /
	-- "SPIRE FLOOR 12"), refreshed on every open in the Visible clip below.
	-- Map name until the first floor push (TodFloorLine).
	self.game_mode_text = TodLabel()
	self.game_mode_text:setLeftRight(true, false, 39, 311)
	self.game_mode_text:setTopBottom(true, false, 38, 57)
	self.game_mode_text:setText( TodFloorLine( controller ) )
	self.game_mode_text:setTTF( "fonts/orbitron.ttf" )
	self.game_mode_text:setRGB( 0.941, 0.941, 0.941 )
	self.game_mode_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.game_mode_text )

	-- Map name (dynamic from CoD.UsermapName)
	self.map_name_text = TodLabel()
	self.map_name_text:setLeftRight(true, false, 50, 241)
	self.map_name_text:setTopBottom(true, false, 20, 31)
	self.map_name_text:setText( Engine.Localize( CoD.UsermapName or "MAP_NAME" ) )
	self.map_name_text:setTTF( "fonts/orbitron.ttf" )
	self.map_name_text:setRGB( 0.941, 0.941, 0.941 )
	self.map_name_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.map_name_text )

	-- Round label
	self.round_label = TodLabel()
	self.round_label:setLeftRight(true, false, 158, 211)
	self.round_label:setTopBottom(true, false, 20, 31)
	self.round_label:setText( Engine.Localize( "ROUND" ) )
	self.round_label:setTTF( "fonts/orbitron.ttf" )
	self.round_label:setRGB( 0.941, 0.941, 0.941 )
	self.round_label:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.round_label )

	-- Round number (dynamic from round model)
	self.round_number = TodLabel()
	self.round_number:setLeftRight(true, false, 210, 263)
	self.round_number:setTopBottom(true, false, 20, 31)
	self.round_number:setText( Engine.Localize( "1" ) )
	self.round_number:setTTF( "fonts/orbitron.ttf" )
	self.round_number:setRGB( 0.941, 0.941, 0.941 )
	self.round_number:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	-- Subscribe to round number
	self.round_number:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "gameScore.roundsPlayed" ), function ( model )
		local roundsPlayed = Engine.GetModelValue( model )
		if roundsPlayed then
			-- BO3 counts rounds starting at 1, but display shows current round (roundsPlayed - 1)
			local currentRound = math.max( 1, roundsPlayed - 1 )
			-- [tod v19.58] the HUD's own round wins, as in the pause menu (v17.25):
			-- three round readouts from two sources could disagree.
			if CoD.TodRound and CoD.TodRound >= 1 then
				currentRound = CoD.TodRound
			end
			self.round_number:setText( Engine.Localize( currentRound ) )
		end
	end )
	self:addElement( self.round_number )

	-- [tod v15 item 13] CHROME for the owned-upgrades list — the baked
	-- "YOUR UPGRADES" header plate and the "RESETS ON CLASS TIER-UP" legend, the
	-- same two images the pause menu uses. Both are created ONCE here and only
	-- alpha-toggled by TodBuildUpgradeList, because unlike the rows their
	-- geometry never depends on the data; the rows themselves are built and
	-- closed per open. Both start hidden: the header shows only once the player
	-- actually holds something, the legend only once a row carries the badge.
	--
	-- BOTH MOVED UP TO y56..84 (2026-09-01), OUT OF THE ROWS' WAY. They used to
	-- sit at y96..124 directly above the first row, which cost the panel a full
	-- row of height and capped the plates at 28px. The band beside the map-info
	-- block is free — map_info_bg reaches only x=323, so everything at x>330 is
	-- clear to the top of the screen — and it became usable only once the quest
	-- widget was deleted. Reclaiming those 32px is exactly what pays for the
	-- 225x33 plates; see the solved table on the constants above.
	-- Header starts at x=340 (17px clear of map_info_bg); legend right-aligns on
	-- 1249, the same edge as column 3.
	self.todUpgHeader = LUI.UIImage.new()
	self.todUpgHeader:setLeftRight( true, false, 340, 740 )   -- 1000x70 art -> 400x28, aspect 14.2857 held exactly
	self.todUpgHeader:setTopBottom( true, false, 56, 84 )
	self.todUpgHeader:setImage( RegisterImage( "i_tod_pause_hdr" ) )
	self.todUpgHeader:setAlpha( 0 )
	self:addElement( self.todUpgHeader )

	self.todUpgLegend = LUI.UIImage.new()
	self.todUpgLegend:setLeftRight( true, false, 869, 1249 )  -- 760x56 art -> 380x28, aspect 13.5714 held exactly; right edge shares the columns' 1249
	self.todUpgLegend:setTopBottom( true, false, 56, 84 )
	self.todUpgLegend:setImage( RegisterImage( "i_tod_pause_legend_reset" ) )
	self.todUpgLegend:setAlpha( 0 )
	self:addElement( self.todUpgLegend )

	-- ========================================
	-- SCOREBOARD HEADER
	-- ========================================

	-- Header background
	self.scoreboard_header = LUI.UIImage.new()
	self.scoreboard_header:setLeftRight( true, false, 124, 1158 )
	self.scoreboard_header:setTopBottom( true, false, 397, 430 )
	self.scoreboard_header:setImage( RegisterImage( "i_mtl_image_67118f82e09c58d9" ) )
	self.scoreboard_header:setRGB( 1, 1, 1 )
	self:addElement( self.scoreboard_header )

	-- Header Column: # (Player ID)
	self.header_id = TodLabel()
	self.header_id:setLeftRight( true, false, 152, 165 )
	self.header_id:setTopBottom( true, false, 407, 420 )
	self.header_id:setText( Engine.Localize( "#" ) )
	self.header_id:setTTF( "fonts/ltromatic.ttf" )
	self.header_id:setRGB( 0.047, 0.776, 0.913 ) -- BO6 cyan
	self.header_id:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_id )

	-- Header Column: Level
	self.header_level = LUI.UIText.new()
    self.header_level:setLeftRight(true, false, 200, 243)
    self.header_level:setTopBottom(true, false, 409, 420)
	self.header_level:setText( Engine.Localize( "Level" ) )
	self.header_level:setTTF( "fonts/ltromatic.ttf" )
	self.header_level:setRGB( 0.047, 0.776, 0.913 )
	self.header_level:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_level )

	-- Header Column: Name
	self.header_name = TodLabel()
    self.header_name:setLeftRight(true, false, 346, 382)
    self.header_name:setTopBottom(true, false, 409, 420)
	self.header_name:setText( Engine.Localize( "Name" ) )
	self.header_name:setTTF( "fonts/ltromatic.ttf" )
	self.header_name:setRGB( 0.047, 0.776, 0.913 )
	self.header_name:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_name )

	-- Header Column: Total Points
	self.header_points = TodLabel()
	self.header_points:setLeftRight(true, false, 526, 672)
	self.header_points:setTopBottom(true, false, 409, 418)
	self.header_points:setText( Engine.Localize( "Total Points" ) )
	self.header_points:setTTF( "fonts/ltromatic.ttf" )
	self.header_points:setRGB( 0.047, 0.776, 0.913 )
	self.header_points:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_points )

	-- Header Column: Eliminations
	self.header_kills = TodLabel()
	self.header_kills:setLeftRight(true, false, 661, 749)
	self.header_kills:setTopBottom(true, false, 409, 418)
	self.header_kills:setText( Engine.Localize( "Eliminations" ) )
	self.header_kills:setTTF( "fonts/ltromatic.ttf" )
	self.header_kills:setRGB( 0.047, 0.776, 0.913 )
	self.header_kills:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_kills )

	-- Header Column: Critical Kills
	self.header_headshots = TodLabel()
    self.header_headshots:setLeftRight(true, false, 788, 885)
    self.header_headshots:setTopBottom(true, false, 409, 419)
	self.header_headshots:setText( Engine.Localize( "Critical Kills" ) )
	self.header_headshots:setTTF( "fonts/ltromatic.ttf" )
	self.header_headshots:setRGB( 0.047, 0.776, 0.913 )
	self.header_headshots:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_headshots )

	-- Header Column: Downs
	self.header_downs = TodLabel()
    self.header_downs:setLeftRight(true, false, 934, 981)
    self.header_downs:setTopBottom(true, false, 409, 418)
	self.header_downs:setText( Engine.Localize( "Downs" ) )
	self.header_downs:setTTF( "fonts/ltromatic.ttf" )
	self.header_downs:setRGB( 0.047, 0.776, 0.913 )
	self.header_downs:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_downs )

	-- Header Column: Revives
	self.header_revives = TodLabel()
    self.header_revives:setLeftRight(true, false, 1062, 1118)
    self.header_revives:setTopBottom(true, false, 409, 418)
	self.header_revives:setText( Engine.Localize( "Revives" ) )
	self.header_revives:setTTF( "fonts/ltromatic.ttf" )
	self.header_revives:setRGB( 0.047, 0.776, 0.913 )
	self.header_revives:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_revives )

	-- ========================================
	-- PLAYER DATA ROWS
	-- ========================================

	-- Create player data rows dynamically
	self.playerRows = {}
	
	local playerYPositions = { 430, 462, 494, 527 } -- Y positions for players 1-4
	
	-- Function to update a player's stats
	local function UpdatePlayerStats( playerIndex, clientNum )
		if not self.playerRows[playerIndex] then
			return
		end
		
		local playerRow = self.playerRows[playerIndex]
		
		if clientNum and clientNum >= 0 then
			-- Update kills
			local kills = Engine.GetScoreboardColumnForClient( clientNum, 1 )
			if playerRow.kills_text then
				playerRow.kills_text:setText( Engine.Localize( kills ) )
			end
			
			-- Update headshots
			local headshots = Engine.GetScoreboardColumnForClient( clientNum, 4 )
			if playerRow.headshots_text then
				playerRow.headshots_text:setText( Engine.Localize( headshots ) )
			end
			
			-- Update downs
			local downs = Engine.GetScoreboardColumnForClient( clientNum, 2 )
			if playerRow.downs_text then
				playerRow.downs_text:setText( Engine.Localize( downs ) )
			end
			
			-- Update revives
			local revives = Engine.GetScoreboardColumnForClient( clientNum, 3 )
			if playerRow.revives_text then
				playerRow.revives_text:setText( Engine.Localize( revives ) )
			end
		end
	end
	
	for playerIndex = 0, 3 do
		local yPos = playerYPositions[playerIndex + 1]
		local playerNum = playerIndex + 1
		
		-- Create player row container
		local playerRow = LUI.UIElement.new()
        CoD.TodUIOwnership.Attach( playerRow )
		playerRow:setLeftRight( true, false, 124, 1158 )
		playerRow:setTopBottom( true, false, yPos, yPos + 32 )
		
		-- Set the model for this player row (required for linkToElementModel to work)
		playerRow:subscribeToGlobalModel( controller, "PlayerList", tostring(playerIndex), function ( model )
			playerRow:setModel( model, controller )
		end )
		
		-- Player ID number
		playerRow.id_text = TodLabel()
		playerRow.id_text:setLeftRight( true, false, 28, 41 )
		playerRow.id_text:setTopBottom( true, false, 10, 23 )
		playerRow.id_text:setText( Engine.Localize( playerNum ) )
		playerRow.id_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.id_text:setRGB( 0.941, 0.941, 0.941 )
		playerRow.id_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
		playerRow:addElement( playerRow.id_text )
		
		-- Prestige icon (placeholder - would need prestige system)
		playerRow.prestige_icon = LUI.UIImage.new()
		playerRow.prestige_icon:setLeftRight( true, false, 71, 95 )
		playerRow.prestige_icon:setTopBottom( true, false, 5, 28 )
		playerRow.prestige_icon:setImage( RegisterImage( "i_mtl_sat_ui_icon_rank_prestige_04" ) ) -- Placeholder
		playerRow.prestige_icon:setRGB( 1, 1, 1 )
		playerRow:addElement( playerRow.prestige_icon )
		playerRow.prestige_icon:setAlpha( 0 )   -- no leveling system on this map
		
		-- Level (placeholder - would need level system)
		playerRow.level_text = LUI.UIText.new()
		playerRow.level_text:setLeftRight( true, false, 76, 130 )
		playerRow.level_text:setTopBottom( true, false, 10, 23 )
		playerRow.level_text:setText( Engine.Localize( "1" ) )
		playerRow.level_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.level_text:setRGB( 0.941, 0.941, 0.941 )
		playerRow.level_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
		playerRow:addElement( playerRow.level_text )
		playerRow.level_text:setAlpha( 0 )   -- no leveling system on this map
		
		-- Player Name (dynamic from PlayerList model)
		playerRow.name_text = TodLabel( { fallbackTTF = "fonts/orbitron.ttf" } )
		playerRow.name_text:setLeftRight( true, false, 212, 380 )
		playerRow.name_text:setTopBottom( true, false, 10, 23 )
		playerRow.name_text:setText( Engine.Localize( "Player " .. playerNum ) )
		playerRow.name_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.name_text:setRGB( 0.941, 0.941, 0.941 )
		playerRow.name_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
		-- Subscribe to player name
		playerRow.name_text:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "PlayerList." .. playerIndex .. ".playerName" ), function ( model )
			local name = Engine.GetModelValue( model )
			if name then
				playerRow.name_text:setText( Engine.Localize( name ) )
			end
		end )
		playerRow:addElement( playerRow.name_text )
		
		-- Total Points (dynamic from playerScore model)
		playerRow.points_text = TodLabel()
		playerRow.points_text:setLeftRight( true, false, 367, 503 )
		playerRow.points_text:setTopBottom( true, false, 10, 23 )
		playerRow.points_text:setText( Engine.Localize( "0" ) )
		playerRow.points_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.points_text:setRGB(0.996078431372549, 0.9921568627450981, 0.4980392156862745)
		playerRow.points_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
		-- Subscribe to player score
		playerRow.points_text:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "PlayerList." .. playerIndex .. ".playerScore" ), function ( model )
			local score = Engine.GetModelValue( model )
			if score then
				playerRow.points_text:setText( Engine.Localize( score ) )
			end
		end )
		playerRow:addElement( playerRow.points_text )
		
		-- Eliminations (dynamic via GetScoreboardColumnForClient)
		playerRow.kills_text = TodLabel()
		playerRow.kills_text:setLeftRight( true, false, 506, 627 )
		playerRow.kills_text:setTopBottom( true, false, 10, 23 )
		playerRow.kills_text:setText( Engine.Localize( "0" ) )
		playerRow.kills_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.kills_text:setRGB( 0.941, 0.941, 0.941 )
		playerRow.kills_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
		playerRow:addElement( playerRow.kills_text )
		
		-- Critical Kills / Headshots (dynamic via GetScoreboardColumnForClient)
		playerRow.headshots_text = TodLabel()
		playerRow.headshots_text:setLeftRight( true, false, 641, 762 )
		playerRow.headshots_text:setTopBottom( true, false, 10, 23 )
		playerRow.headshots_text:setText( Engine.Localize( "0" ) )
		playerRow.headshots_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.headshots_text:setRGB( 0.941, 0.941, 0.941 )
		playerRow.headshots_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
		playerRow:addElement( playerRow.headshots_text )
		
		-- Downs (dynamic via GetScoreboardColumnForClient)
		playerRow.downs_text = TodLabel()
		playerRow.downs_text:setLeftRight( true, false, 769, 890 )
		playerRow.downs_text:setTopBottom( true, false, 10, 23 )
		playerRow.downs_text:setText( Engine.Localize( "0" ) )
		playerRow.downs_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.downs_text:setRGB( 0.941, 0.941, 0.941 )
		playerRow.downs_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
		playerRow:addElement( playerRow.downs_text )
		
		-- Revives (dynamic via GetScoreboardColumnForClient)
		playerRow.revives_text = TodLabel()
		playerRow.revives_text:setLeftRight( true, false, 897, 1018 )
		playerRow.revives_text:setTopBottom( true, false, 10, 23 )
		playerRow.revives_text:setText( Engine.Localize( "0" ) )
		playerRow.revives_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.revives_text:setRGB( 0.941, 0.941, 0.941 )
		playerRow.revives_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
		playerRow:addElement( playerRow.revives_text )
		
		-- Store clientNum for this player and subscribe to updates
		playerRow.clientNum = nil
		playerRow:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "PlayerList." .. playerIndex .. ".clientNum" ), function ( model )
			local clientNum = Engine.GetModelValue( model )
			playerRow.clientNum = clientNum
			UpdatePlayerStats( playerIndex, clientNum )
		end )
		
		-- Add player row to scoreboard
		self:addElement( playerRow )
		self.playerRows[playerIndex] = playerRow
	end
	
	-- Subscribe to global scoreboard update model to refresh all stats
	self:subscribeToModel( Engine.CreateModel( Engine.GetModelForController( controller ), "updateScoreboard" ), function ( model )
		for i = 0, 3 do
			if self.playerRows[i] and self.playerRows[i].clientNum then
				UpdatePlayerStats( i, self.playerRows[i].clientNum )
			end
		end
	end )

	-- ========================================
	-- VISIBILITY SYSTEM (Hidden by default, shown on TAB)
	-- ========================================
	
	-- Helper function to check if player exists
	local function IsPlayerActive( playerIndex )
		local playerModel = Engine.GetModel( Engine.GetModelForController( controller ), "PlayerList." .. playerIndex )
		if playerModel then
			local nameModel = Engine.GetModel( playerModel, "playerName" )
			if nameModel then
				local name = Engine.GetModelValue( nameModel )
				return name ~= nil and name ~= ""
			end
		end
		return false
	end
	
	self.clipsPerState = {
		DefaultState = {
			DefaultClip = function ()
				self:setupElementClipCounter( 0 )
				
				-- Hide all scoreboard elements
				self.bg_overlay_1:setAlpha( 0 )
				self.bg_particles:setAlpha( 0 )
				self.bg_overlay_2:setAlpha( 0 )
				if self.questWidget then
					self.questWidget:setAlpha(0)
				end
				
				self.player_4_outline:setAlpha( 0 )
				self.player_4_outline_bg:setAlpha( 0 )
				self.player_3_outline:setAlpha( 0 )
				self.player_3_outline_bg:setAlpha( 0 )
				self.player_2_outline:setAlpha( 0 )
				self.player_2_outline_bg:setAlpha( 0 )
				self.player_1_outline:setAlpha( 0 )
				self.player_1_outline_bg:setAlpha( 0 )
				self.player_hover_element:setAlpha( 0 )
				self.points_icon:setAlpha( 0 )
				self.points_label:setAlpha( 0 )
				self.points_value:setAlpha( 0 )
				self.salvage_icon:setAlpha( 0 )
				self.salvage_label:setAlpha( 0 )
				self.salvage_value:setAlpha( 0 )
				self.map_info_bg:setAlpha( 0 )
				self.game_mode_text:setAlpha( 0 )
				self.map_name_text:setAlpha( 0 )
				self.round_label:setAlpha( 0 )
				self.round_number:setAlpha( 0 )
				self.scoreboard_header:setAlpha( 0 )
				self.header_id:setAlpha( 0 )
				self.header_level:setAlpha( 0 )
				self.header_name:setAlpha( 0 )
				self.header_points:setAlpha( 0 )
				self.header_kills:setAlpha( 0 )
				self.header_headshots:setAlpha( 0 )
				self.header_downs:setAlpha( 0 )
				self.header_revives:setAlpha( 0 )
				
				-- Hide all player rows
				for i = 0, 3 do
					if self.playerRows[i] then
						self.playerRows[i]:setAlpha( 0 )
					end
				end

				-- [tod v15 item 13] and the owned-upgrades list. CLOSED, not just
				-- alpha'd: these are rebuilt from scratch on every open, so leaving
				-- them parented would grow the element pool once per scoreboard
				-- press for the whole match.
				if self.todUpgHeader then
					self.todUpgHeader:setAlpha( 0 )
				end
				if self.todUpgLegend then
					self.todUpgLegend:setAlpha( 0 )
				end
				if self.todUpgRows then
					for i = 1, #self.todUpgRows do
						if self.todUpgRows[ i ] then
							self.todUpgRows[ i ]:close()
						end
					end
					self.todUpgRows = {}
				end
			end
		},
		Visible = {
			DefaultClip = function ()
				self:setupElementClipCounter( 0 )
				
				-- Show all scoreboard elements
				self.bg_overlay_1:setAlpha( 1 )
				self.bg_particles:setAlpha( 1 )
				self.bg_overlay_2:setAlpha( 1 )
				if self.questWidget then
					self.questWidget:setAlpha(0)   -- no quest system on this map
				end
				
				-- Count active players
				local activePlayers = {}
				for i = 0, 3 do
					if IsPlayerActive( i ) then
						table.insert( activePlayers, i )
					end
				end
				local playerCount = #activePlayers
				
				-- Position players from bottom (fill slots 4, 3, 2, 1 based on count)
				local playerYPositions = { 430, 462, 494, 527 } -- Slots 1, 2, 3, 4
				local outlineElements = { self.player_1_outline, self.player_2_outline, self.player_3_outline, self.player_4_outline }
				local outlineBgElements = { self.player_1_outline_bg, self.player_2_outline_bg, self.player_3_outline_bg, self.player_4_outline_bg }
				
				-- Hide all outlines first
				for i = 1, 4 do
					outlineElements[i]:setAlpha( 0 )
					outlineBgElements[i]:setAlpha( 0 )
				end
				
				-- Show outlines for active slots (filling from bottom)
				for i = 1, playerCount do
					local slotIndex = 5 - i -- Start from slot 4 and go up (4, 3, 2, 1)
					outlineElements[slotIndex]:setAlpha( 1 )
					outlineBgElements[slotIndex]:setAlpha( 1 )
				end
				
				-- Position player rows to fill from bottom
				for i = 1, playerCount do
					local playerIndex = activePlayers[i]
					local slotIndex = 5 - i -- Slot position (4, 3, 2, 1)
					local yPos = playerYPositions[slotIndex]
					
					if self.playerRows[playerIndex] then
						self.playerRows[playerIndex]:setTopBottom( true, false, yPos, yPos + 32 )
						self.playerRows[playerIndex]:setAlpha( 1 )
					end
				end
				
				-- Hide inactive player rows
				for i = 0, 3 do
					local isActive = false
					for _, activeIdx in ipairs( activePlayers ) do
						if activeIdx == i then
							isActive = true
							break
						end
					end
					if not isActive and self.playerRows[i] then
						self.playerRows[i]:setAlpha( 0 )
					end
				end
				
				-- Position hover element on bottom-most active player
				if playerCount > 0 then
					local bottomSlot = 5 - 1 -- Slot 4
					local yPos = playerYPositions[bottomSlot]
					self.player_hover_element:setTopBottom( true, false, yPos, yPos + 32 )
					self.player_hover_element:setAlpha( 1 )
				else
					self.player_hover_element:setAlpha( 0 )
				end
				
				-- Position header directly above topmost active player
				if playerCount > 0 then
					local topSlot = 5 - playerCount -- Top-most slot being used
					local topPlayerY = playerYPositions[topSlot]
					local headerHeight = 33 -- Header is 33 pixels tall (430 - 397)
					local headerTop = topPlayerY - headerHeight
					local headerBottom = topPlayerY
					
					-- Reposition header
					if self.scoreboard_header then
						self.scoreboard_header:setTopBottom( true, false, headerTop, headerBottom )
					end
					
					-- Reposition all header text elements (they're offset from header position)
					local headerTextOffset = 10 -- Text starts 10px from header top
					local textY = headerTop + headerTextOffset
					
					if self.header_id then
						self.header_id:setTopBottom( true, false, textY, textY + 13 )
					end
					if self.header_level then
						self.header_level:setTopBottom( true, false, textY + 2, textY + 13 )
					end
					if self.header_name then
						self.header_name:setTopBottom( true, false, textY + 2, textY + 13 )
					end
					if self.header_points then
						self.header_points:setTopBottom( true, false, textY + 2, textY + 11 )
					end
					if self.header_kills then
						self.header_kills:setTopBottom( true, false, textY + 2, textY + 11 )
					end
					if self.header_headshots then
						self.header_headshots:setTopBottom( true, false, textY + 2, textY + 12 )
					end
					if self.header_downs then
						self.header_downs:setTopBottom( true, false, textY + 2, textY + 11 )
					end
					if self.header_revives then
						self.header_revives:setTopBottom( true, false, textY + 2, textY + 11 )
					end
				end
				
				self.points_icon:setAlpha( 1 )
				self.points_label:setAlpha( 1 )
				self.points_value:setAlpha( 1 )
				-- salvage disabled: no salvage economy on this map (audit 2026-08-19)
				self.salvage_icon:setAlpha( 0 )
				self.salvage_label:setAlpha( 0 )
				self.salvage_value:setAlpha( 0 )
				self.map_info_bg:setAlpha( 1 )
				self.game_mode_text:setAlpha( 1 )
				self.map_name_text:setAlpha( 1 )
				self.round_label:setAlpha( 1 )
				self.round_number:setAlpha( 1 )
				self.scoreboard_header:setAlpha( 1 )
				self.header_id:setAlpha( 1 )
				self.header_level:setAlpha( 0 )   -- no leveling system on this map
				self.header_name:setAlpha( 1 )
				self.header_points:setAlpha( 1 )
				self.header_kills:setAlpha( 1 )
				self.header_headshots:setAlpha( 1 )
				self.header_downs:setAlpha( 1 )
				self.header_revives:setAlpha( 1 )

				-- 2026-10-01 (docs/167 item 12): the floor line, current on every open.
				self.game_mode_text:setText( TodFloorLine( controller ) )

				-- [tod v15 item 13] YOUR UPGRADES, ON THE SCOREBOARD.
				-- User: "Can we put the upgrade menu in the scoreboard as well so
				-- players can move and read?" Built here in the Visible clip, which
				-- re-runs on every open, so the list is current without a poll.
				if TodForcedBoard( controller ) then
					TodHideUpgradeList( self )   -- the end screen (see TodForcedBoard)
				else
					TodBuildUpgradeList( self )
				end
			end
		}
	}
	
	-- [tod 2026-09-24] THE END-OF-GAME STATS (lead tester: "We cant see how many
	-- kills we got or end game stats kills, downs, points head shots"). Stock
	-- forces the scoreboard up at game end — _zm.gsc end_game sends
	-- LUINotifyEvent( &"force_scoreboard", 1, 1 ), and the root HUD turns that
	-- into the per-controller "forceScoreboard" model (ui_mp hud.lua) — and
	-- stock's own ScoreboardWidgetCP has a ForceVisible state for it. This kit
	-- board only ever read the button bit, so the forced board never drew and
	-- the stats were unreachable at the one moment everyone wants them.
	-- _tod_gameover.gsc holds its restart menu back while the board is up.
	local function todForced()
		return TodForcedBoard( controller )
	end

	-- State conditions: Check if scoreboard should be visible
	self:mergeStateConditions( {
		{
			stateName = "Visible",
			condition = function ( menu, element, event )
				return Engine.IsVisibilityBitSet( controller, Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN ) or todForced()
			end
		}
	} )

	-- Subscribe to scoreboard open/close model
	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN ), function ( model )
		menu:updateElementState( self, {
			name = "model_validation",
			menu = menu,
			modelValue = Engine.GetModelValue( model ),
			modelName = "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN
		} )
	end )
	-- CreateModel, not GetModel: the root HUD creates this node only when the
	-- first force_scoreboard arrives, and a subscription on a missing node is
	-- the dead-node trap (subscribeToModel( nil ) never fires).
	self:subscribeToModel( Engine.CreateModel( Engine.GetModelForController( controller ), "forceScoreboard" ), function ( model )
		menu:updateElementState( self, {
			name = "model_validation",
			menu = menu,
			modelValue = Engine.GetModelValue( model ),
			modelName = "forceScoreboard"
		} )
		-- A board the player already held open does not re-run its Visible
		-- clip when the force lands, so drop the panel here as well.
		if TodForcedBoard( controller ) then
			TodHideUpgradeList( self )
		end
		TodEndLines( self, controller )
	end )

	-- [tod v19.58] the end-screen lines (see TodEndLines).
	self.todEndTitle = TodLabel()
	self.todEndTitle:setLeftRight( true, false, 240, 1040 )
	self.todEndTitle:setTopBottom( true, false, 150, 184 )
	self.todEndTitle:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	self.todEndTitle:setAlpha( 0 )
	self:addElement( self.todEndTitle )
	self.todEndSurvived = TodLabel()
	self.todEndSurvived:setLeftRight( true, false, 240, 1040 )
	self.todEndSurvived:setTopBottom( true, false, 196, 220 )
	self.todEndSurvived:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	self.todEndSurvived:setAlpha( 0 )
	self:addElement( self.todEndSurvived )
	self:subscribeToGlobalModel( controller, "PerController", "scriptNotify", function ( model )
		local ev = Engine.GetModelValue( model )
		-- [tod v19.76] THE HEADER FOLLOWS THE HUD'S OWN ROUND, live (see
		-- TodEndLines): the same tod_round push AetheriumRoundCounter draws.
		if ev == "tod_round" then
			local rd = CoD.GetScriptNotifyData and CoD.GetScriptNotifyData( model )
			local r = rd and tonumber( rd[ 1 ] )
			-- not while the game-over board is forced: there the header holds the
			-- end number TodEndLines wrote (CoD.TodEndScreen itself is never
			-- cleared - the HUD survives a map_restart - so it cannot be the test)
			if r and r >= 1 and self.round_number and not TodForcedBoard( controller ) then
				self.round_number:setText( Engine.Localize( tostring( math.floor( r ) ) ) )
			end
			return
		end
		if ev ~= "tod_gameover" then
			return
		end
		local d = CoD.GetScriptNotifyData and CoD.GetScriptNotifyData( model )
		if not d then
			return
		end
		CoD.TodEndScreen = {
			kind = math.floor( tonumber( d[ 1 ] ) or 1 ),
			rounds = math.floor( tonumber( d[ 2 ] ) or 1 ),
			floor = math.floor( tonumber( d[ 3 ] ) or 0 ),
		}
		TodEndLines( self, controller )
	end )

	if PostLoadFunc then
		PostLoadFunc( self, controller )
	end


	-- =========================================================================
	return self
end

return CoD.AetheriumScoreboard
