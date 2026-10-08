-- =============================================================================
-- TodPromptCard.lua — THE ONE OWNER OF EVERY CURSOR-HINT PROMPT CARD.
--
-- USER, 2026-09-14, after two minutes of play: *"the teleport bay, the power
-- switch — these don't even use the correct typography ... we should only have
-- to do this in one area in the HUD, and it applies to all prompts. It
-- shouldn't be a situation where we need to switch each one one by one."*
-- And then: *"there shouldn't be situations where we see half work and half
-- life ... You should completely take that out and implement the new way."*
--
-- Both are answered here. Before this file the map had SIX prompt cards, each
-- an independent copy of the same chassis, the same five background rects, the
-- same title/detail/price boxes and the same footer — six places to fix a font,
-- six places to fix a colour, six places to fix a word. v19.1 reskinned the
-- art in all six and v19.2 converted the typeface in ONE, which is exactly the
-- half-and-half state the user is objecting to: the ammo crate drew the map's
-- letters and the power switch three feet away drew the kit's.
--
-- ---------------------------------------------------------------------------
-- WHAT THIS FILE OWNS, AND THEREFORE WHAT A CARD NO LONGER DECIDES
--
--   * the chassis        — all five nested rects and the one art image
--   * the icon well      — and the hint -> icon table, which used to be local
--                          to PromptDefault, so five cards could not use it
--   * the typeface       — every letter on every card, via CoD.TodGlyphText
--   * the boxes          — title / detail 1 / detail 2 / price / footer
--   * the footer         — "HOLD <key> TO <verb>" including the device split
--   * the price lockup   — the coin and the digits beside it
--
-- A card file is now a THIN SHELL: it calls Build() once and then pushes
-- strings in through SetTitle / SetDetail / SetPrice / SetIcon / SetFooter.
-- It owns only its own parsing — which is the one thing that genuinely differs
-- between a door, a perk machine and a Pack-a-Punch.
--
-- ⚠️ THE RULE FROM HERE: NO PROMPT CARD MAY CALL setTTF, LUI.UIText.new OR
-- setImage FOR CHASSIS ART. If a card needs something this file cannot give it,
-- ADD IT HERE. tools/lint_tod_lua.js gates the setTTF half of that.
--
-- ---------------------------------------------------------------------------
-- THE TYPEFACE IS UPPERCASE BY CONSTRUCTION, AND THAT IS A FEATURE HERE.
--
-- CoD.TodGlyphText's cleaner runs string.upper() on everything (tgClean in
-- TodGlyphText.lua) because the baked sheets have no lowercase. So the whole
-- class of complaint the user opened with — *"it's the teleport bay without
-- capital t"*, *"the Spiral Tower 41 is not capitalized"* — cannot survive this
-- conversion regardless of how the source string was written. The GSC strings
-- are still being corrected at source (a hint is also read by the hint lint and
-- by anyone maintaining it), but the SCREEN is fixed by construction the moment
-- a card routes through here.
--
-- ---------------------------------------------------------------------------
-- THE FOOTER IS THE ONE PLACE AN ENGINE-DRAWN THING SURVIVES, ON PURPOSE.
--
-- The footer reads "HOLD <key> TO USE". HOLD and TO USE are ours. The <key> is
-- NOT typography — it is whatever the player's device is bound to, and on a pad
-- the engine substitutes a CONTROLLER BUTTON PICTURE. We do not draw that
-- ourselves for the same reason we do not draw the player's keyboard layout:
-- it has to match the controller actually in their hands.
--
-- ONE element carries the token and the ENGINE substitutes it: a key name on a
-- keyboard, a button PICTURE on a pad. There is no device branch here, because
-- the engine has already made that decision by the time the line is set. It is
-- the only non-TodGlyphText text on any prompt card, and it never draws copy we
-- wrote — only the player's own bind.
--
-- See memory `bind-token-is-never-a-string`: the engine has ALREADY resolved
-- [{+activate}] before hudItems.cursorHintText reaches Lua, so nothing here may
-- test for the literal token.
-- =============================================================================

require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodGlyphText" )

CoD.TodPromptCard = {}

-- ---------------------------------------------------------------------------
-- GEOMETRY. Measured off i_tod_prompt_chassis and identical in all six cards —
-- the outer rect CONTAINS the other four in every one of them, which is why the
-- reskin could collapse five images into one. Canvas units (1280x720 space).
-- ---------------------------------------------------------------------------
local BOX = {
	frameL = 544, frameR = 775, frameT = 444, frameB = 520,

	iconWellL = 546, iconWellR = 615, iconWellT = 445, iconWellB = 518,
	iconL     = 559, iconR     = 603, iconT     = 461, iconB     = 505,

	-- The title band runs to canvas x773 on the art; 770 leaves a hair of
	-- margin. HEAVENLY GIFT ALTAR (19 chars) is the longest noun in TOD_NOUNS
	-- and it wrapped at 754 — there is no wrap or measure API in this LUI, so
	-- headroom is the only defence.
	titleL = 620, titleR = 770, titleT = 448.3, titleB = 459.7,

	-- THE BODY BAND, measured off the chassis art like the footer's: the cyan
	-- underline ends at 462.1 and the divider rule starts at 500.6. The rows are
	-- CENTRED in it by LayoutDetail rather than pinned near the top — one line or
	-- two — which is what closes the void the user kept seeing under the
	-- description. Size (8.4) and pitch (12.05) are the v19.7 values untouched.
	descL = 620, descR = 767, descH = 8.4, descPitch = 12.05,
	bodyT = 462.1, bodyB = 500.6,

	-- THE FOOTER SECTION, MEASURED OFF THE CHASSIS ART (v19.8). The divider
	-- rule in i_tod_prompt_chassis.png lands at canvas 500.6..501.1 and the
	-- inner bottom frame at 516.6, so the band the footer belongs in is
	-- 501.1..516.6. This box is centred in it: baseline 512.6, caps from 505.1.
	-- WARNING: footR is the PRICED right edge; with no price the verb may run
	-- on to footRWide, and LayoutFooter is the only thing that picks between them.
	footL  = 620, footR  = 723, footT  = 503.8, footB  = 513.2,
	footRWide = 771,

	-- Right-aligned to the same inner edge, on the footer's own baseline.
	-- 44 units holds "$12000" (41.5 measured) at this cap without clamping.
	priceL = 727, priceR = 771, priceT = 502.86, priceB = 513.26,
}

-- ---------------------------------------------------------------------------
-- WHY THESE NUMBERS ARE WHAT THEY ARE (v19.7 — user, after seeing v19.5 in
-- game: *"lets cut the size increase we did on everything by 65%. I think it's
-- too big."*  v19.5 had answered the opposite complaint: *"there's always a ton
-- of empty space under the description, and the text is very small ... maybe
-- twenty five percent bigger."*)
--
-- A glyph row's size comes from its BOX HEIGHT (`cap = h * capFrac`, capFrac
-- 0.80), so the box IS the type size and there is no separate font number to
-- chase. Every height here is `v19.3 + 0.35 * (v19.5 - v19.3)` — exactly 35% of
-- the growth that shipped, kept as fractions because this is the 1280x720
-- virtual canvas and rounding 448.3 to 448 would have made the cut 75% on that
-- row instead of 65%.
--
--     row      v19.3  v19.5  v19.7   |  drawn cap
--     title      10     14    11.4   |  8.00 -> 11.20 -> 9.12
--     detail      7     11     8.4   |  5.60 ->  8.80 -> 6.72
--     footer      8     12     9.4   |  6.40 ->  9.60 -> 7.52
--     price       9     13    10.4   |  7.20 -> 10.40 -> 8.32
--
-- ⚠️ THE DEAD BAND IS THE ONE THING NOT INTERPOLATED BACK, ON PURPOSE. The
-- "ton of empty space under the description" is a complaint that still stands;
-- interpolating the footer's POSITION would have returned 8 of those 22 units
-- to the screen while nobody asked for them. So the footer keeps the v19.5 lift
-- and takes only the size cut, and the 6.5 units the shrink frees are split
-- evenly above and below it — dead band 9 -> 12.25, bottom margin 6 -> 9.25.
-- Against v19.3's 22-unit hole that is still less than half.
--
-- ⚠️ THE FOOTER VERB IS WIDTH-BOUND AND BARELY MOVES — EXPECTED, NOT A MISS.
-- The whole bottom row is 620..773 = 153 units and must hold "HOLD <key> TO
-- UPGRADE" AND a price, so TodGlyphText's own fit already clamps a long verb on
-- WIDTH (~cap 4.7) and a height change cannot reach it. "HOLD" is the piece that
-- is height-bound, which is why FOOT_HOLD_W comes down with it.
-- ---------------------------------------------------------------------------

local INK      = { 1, 1, 1 }
local INK_GOLD = { 0.894, 0.882, 0.424 }

-- Pools are the MAXIMUM glyph count each row can draw. A glyph row pre-creates
-- its cells, so this is an allocation, not a limit to tune per string.
-- v19.14 — POOL_DESC 34 -> 40. ⚠️ A GLYPH POOL IS A HARD CHARACTER LIMIT, AND
-- IT CLIPS SILENTLY: TodGlyphText draws until the pool runs out and simply stops.
-- Quick Revive's two lines are 35 and 37 characters and BOTH came back cut at
-- exactly 34 ("...YOURSELF 3 TIME", "...TEAMMATES FAS"), which reads as a card
-- too narrow for its copy and is nothing of the kind — rendering those exact
-- strings through tmp/render_card.py over the real chassis shows them fitting
-- the 147-unit box with room to spare, because the row SHRINKS ITS CAP to fit
-- the width. Width was never the constraint. THE COUNT WAS.
--
-- SO: WHEN COPY TRUNCATES ON A CARD, COUNT THE CHARACTERS BEFORE RESIZING
-- ANYTHING. A clip at a round number is a pool, not a box.
--
-- 40 rather than 50: each row costs one LUI element per slot and every card
-- carries two of them, so this is ~120 elements across the prompt set. That is
-- paid once at construction and released by TodUIOwnership, but it is not free,
-- and the element pool is the very thing tonight's crash work was about.
local POOL_TITLE, POOL_DESC, POOL_PRICE = 24, 40, 10

-- ---------------------------------------------------------------------------
-- THE ICON TABLE — MOVED HERE FROM PromptDefault SO ALL SIX CARDS SHARE IT.
--
-- Matched against the WHOLE lowercased hint line, not just the title, and the
-- FIRST MATCH WINS — so a longer phrase must sit above any shorter phrase it
-- contains. The summit pad is why the whole line is read: two different objects
-- both title themselves "SEALED" (a spire door, and the summit extraction pad),
-- and only the detail separates them.
--
-- A line with no row keeps the stock glyph rather than drawing nothing.
-- ---------------------------------------------------------------------------
CoD.TodPromptCard.ICON_FALLBACK = "i_mtl_ui_icon_zm_ping_documents"

CoD.TodPromptCard.ICONS = {
	{ "warden king",         "i_tod_prompt_icon_extract" },   -- summit pad, before "sealed"
	{ "ammo crate",          "i_tod_prompt_icon_crate" },
	{ "already packed",      "i_tod_prompt_icon_pap" },      -- ABOVE the altar row: the line names the altar, but the OBJECT is the machine
	{ "pack iii",            "i_tod_prompt_icon_pap" },      -- spire hub re-packs; "pack ii" is a prefix of this, so the longer one leads
	{ "pack ii",             "i_tod_prompt_icon_pap" },
	{ "heavenly gift altar", "i_tod_prompt_icon_altar" },
	{ "altar spent",         "i_tod_prompt_icon_altar" },
	{ "all upgrades maxed",  "i_tod_prompt_icon_altar" },
	{ "upgrade station",     "i_tod_prompt_icon_altar" },
	{ "teleporter",          "i_tod_prompt_icon_teleporter" },
	{ "teleport bay",        "i_tod_prompt_icon_teleporter" },
	{ "ascend",              "i_tod_prompt_icon_teleporter" },
	{ "defend the crown",    "i_tod_prompt_icon_crown" },
	{ "run for the crown",   "i_tod_prompt_icon_crown" },
	{ "reach the crown",     "i_tod_prompt_icon_crown" },
	{ "call extraction",     "i_tod_prompt_icon_extract" },
	{ "extracting",          "i_tod_prompt_icon_extract" },
	{ "extract",             "i_tod_prompt_icon_extract" },   -- after the two above
	{ "uplink",              "i_tod_prompt_icon_extract" },
	{ "rampage",            "i_tod_prompt_icon_rampage" },
	{ "power switch",        "i_tod_prompt_icon_power" },
	{ "power required",      "i_tod_prompt_icon_power" },
	{ "open door",           "i_tod_prompt_icon_door" },
	{ "sealed",              "i_tod_prompt_icon_door" },      -- a sealed spire door
}

-- ---------------------------------------------------------------------------
-- ROUND 2 LANDED 2026-09-14 (docs/136). rampage / crown / pap / perk are on
-- disk, in the GDT and zoned, and their rows are live above.
--
-- ⚠️ THE LESSON FROM INSTALLING THEM, worth keeping: while they were still
-- undelivered, a first pass put their rows in a LIVE table gated on a
-- `ICONS_ROUND2_INSTALLED = false` flag. lint_tod_assets GATE A failed the
-- build on the spot, correctly — the gate reads NAMES out of the source and
-- cannot evaluate a Lua flag, and an image named in a live path with no zone
-- line draws a WHITE SQUARE. Never name an unshipped asset in live code, and
-- never dodge that by building the name at runtime from a prefix
-- (memory `constructed-names-evade-inventory`).
-- ---------------------------------------------------------------------------

function CoD.TodPromptCard.IconFor( line )
	if not line or line == "" then
		return CoD.TodPromptCard.ICON_FALLBACK
	end
	local h = string.lower( line )
	for i = 1, #CoD.TodPromptCard.ICONS do
		local row = CoD.TodPromptCard.ICONS[ i ]
		if string.find( h, row[ 1 ], 1, true ) then
			return row[ 2 ]
		end
	end
	return CoD.TodPromptCard.ICON_FALLBACK
end

-- ---------------------------------------------------------------------------
-- BUILD — every visual element of a prompt card, in z-order.
--
-- ⚠️ Z-ORDER IS LOAD-BEARING AND IT REGRESSED ONCE ALREADY (v19.1): the kit's
-- outer layer was a FRAME with a hollow centre, so five of the six cards got
-- away with adding their title BEFORE it. The reskin made that layer an OPAQUE
-- plate and it painted every one of those titles out. Chassis first, always.
-- ---------------------------------------------------------------------------
function CoD.TodPromptCard.Build( self, opts )
	opts = opts or {}
	-- Each shell owns its children, including glyph rows and any feedback
	-- attached later. Closing the shell alone does not call their close hooks.
	LUI.OverrideFunction_CallOriginalSecond( self, "close", function( element )
		local child = element:getFirstChild()
		while child do
			local nextChild = child:getNextSibling()
			child:close()
			child = nextChild
		end
	end )

	local function img( l, r, t, b, name, alpha )
		local e = LUI.UIImage.new()
		e:setLeftRight( true, false, l, r )
		e:setTopBottom( true, false, t, b )
		e:setImage( RegisterImage( name ) )
		e:setRGB( 1, 1, 1 )
		if alpha then
			e:setAlpha( alpha )
		end
		self:addElement( e )
		return e
	end

	local function glyph( l, r, t, b, set, pool, rgb, align )
		local e = CoD.TodGlyphText.new( {
			left = l, right = r, top = t, bottom = b,
			align = align or "left", set = set, pool = pool,
			rgb = rgb,
		} )
		self:addElement( e )
		return e
	end

	-- 1. THE CHASSIS. The four inner rects are the kit's nested slots; the outer
	-- one carries our art and CONTAINS them, so they are pointed at the kit's
	-- own $blacktransparent instead of shipping four empty PNGs.
	self.todBgMain   = img( 616, 772, 460, 518, "blacktransparent" )
	self.todBgHeader = img( 615, 773, 446, 461, "blacktransparent" )
	self.todBgFrame  = img( 618, 775, 449, 517, "blacktransparent" )
	self.todBgIcon   = img( BOX.iconWellL, BOX.iconWellR, BOX.iconWellT, BOX.iconWellB, "blacktransparent" )
	self.todChassis  = img( BOX.frameL, BOX.frameR, BOX.frameT, BOX.frameB, "i_tod_prompt_chassis" )

	-- 2. THE OBJECT ICON, in the well on the left.
	self.todIcon = img( BOX.iconL, BOX.iconR, BOX.iconT, BOX.iconB,
	                    opts.icon or CoD.TodPromptCard.ICON_FALLBACK )
	self.todIconName = opts.icon or CoD.TodPromptCard.ICON_FALLBACK

	-- 3. THE LETTERS. All of them, in the map's own typeface.
	self.todTitle = glyph( BOX.titleL, BOX.titleR, BOX.titleT, BOX.titleB, "name",   POOL_TITLE, INK )
	-- Created at the two-line position; LayoutDetail re-places both on every
	-- SetDetail, because whether there is a second line changes where the first
	-- one belongs.
	self.todDesc1 = glyph( BOX.descL, BOX.descR, 471.13, 479.53, "name",   POOL_DESC,  INK )
	self.todDesc2 = glyph( BOX.descL, BOX.descR, 483.18, 491.58, "name",   POOL_DESC,  INK )

	-- 4. THE FOOTER. See the header: HOLD and the verb are ours, the key is the
	-- device's. Built as one row so the pieces cannot overlap each other.
	--
	-- opts.footer == false builds NO footer. That is for a REFUSAL card — the
	-- "POWER REQUIRED" state is telling the player why nothing happened, and
	-- there is no button to hold. Telling them to hold one would be a lie.
	if opts.footer ~= false then
		CoD.TodPromptCard.BuildFooter( self )
		CoD.TodPromptCard.SetFooter( self, opts.footer )
	end

	-- 5. THE PRICE — ONE GLYPH ROW, "$" AND THE DIGITS TOGETHER.
	--
	-- USER, 2026-09-14: *"the money icon on the ammo prompt is tiny and not
	-- aligned with the cost. Symbol is a bit down."* Both symptoms had one
	-- cause: the coin was a SEPARATE UIImage in its own 15x12 box beside a text
	-- box, so its size and its baseline were hand-numbers that had to be kept
	-- agreeing with a font. They were not agreeing. And it looked tiny because
	-- i_tod_hud_points_icon.png carries transparent padding — the 15x12 box was
	-- mostly empty, so the visible coin was far smaller than the digits.
	--
	-- THE FIX IS NOT A NUDGE. v19.2 put the HUD's own money symbol into the
	-- typeface as "$" (the dead ampersand cell), so the price can be ONE STRING
	-- in ONE row: "$2500". The symbol now takes the digits' exact cap height and
	-- sits on the digits' exact baseline BY CONSTRUCTION — there is no second
	-- number left to drift, at any resolution.
	--
	-- RIGHT-ALIGNED to the card edge so the price always ends in the same place
	-- whether it is $500 or $12000, and the row shrinks to fit rather than
	-- running left into the footer verb sharing this line.
	self.todPrice = glyph( BOX.priceL, BOX.priceR, BOX.priceT, BOX.priceB, "name", POOL_PRICE, INK_GOLD, "right" )
	self.todPrice:setText( "" )

	return self
end

-- ---------------------------------------------------------------------------
-- THE FOOTER, and the device split.
--
-- Layout: [HOLD] [key] [TO <VERB>]. The key's width is not ours to know — a pad
-- picture, "F", "MOUSE3" and "SPACE" all differ — so the verb is placed AFTER a
-- fixed key slot rather than flowed, which is the only arrangement that can
-- never overlap in a LUI with no measure API for engine text.
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- THE FOOTER, AND THE KEY THAT WENT MISSING.
--
-- ⚠️ v19.5 REGRESSION FIX, AND THE REGRESSION WAS MINE. v19.3 drew the key
-- through `CoD.TodKeycap` — the widget that renders a bind inside the pale
-- keycap art for the class draft and the pause legend. On a prompt card it drew
-- NOTHING, so every prompt in the map read "HOLD      TO BUY" with a hole where
-- the key belongs. The user, correctly: *"this should already be taken care of.
-- The other had this figured out ... We shouldn't be messing up something like
-- this."* They are right: v14.58 through v19.2 had it working.
--
-- WHY IT DREW NOTHING: `kc.paint` falls back to a LUI text whenever the
-- measured string will not fit its pool or has no cell, and `make( owner,
-- fallbackText )` was handed a NIL fallback here — so every failure path drew
-- silently empty. That widget also expects the cap ART drawn behind it by the
-- caller, which a prompt footer has no room for. It was the wrong component.
--
-- WHAT IT IS NOW, and what already worked before v19.3: ONE element holding the
-- `[{+activate}]` token, which the ENGINE expands into whatever this player's
-- device is bound to — a key name on a keyboard, a button PICTURE on a pad. It
-- cannot come back blank, it needs no device branch, and it is correct again
-- after a rebind. It is not typography, so it is not in our 42-glyph set; the
-- HOLD and the verb around it are.
--
-- DO NOT rebuild a device branch here. The engine has already made that call by
-- the time we set the line (memory `bind-token-is-never-a-string`).
-- ---------------------------------------------------------------------------
-- WIDTHS (v19.8). MEASURED against the generated metrics at the footer cap
-- (7.52), not guessed: "HOLD" comes to 23.2, so 24 is the smallest box that
-- never clamps it. The key slot was 30 for a button PICTURE that draws about
-- 13 wide beside a default keyboard bind of one character — eight of those
-- units were being taken off the verb, which is the row that ran out of room.
local FOOT_HOLD_W = 24     -- "HOLD" measures 23.2 at cap 7.52
local FOOT_KEY_W  = 22     -- the key slot, engine-drawn — sized for the glyph
local FOOT_GAP    = 3

function CoD.TodPromptCard.BuildFooter( self )
	local l = BOX.footL

	self.todFootHold = CoD.TodGlyphText.new( {
		left = l, right = l + FOOT_HOLD_W, top = BOX.footT, bottom = BOX.footB,
		align = "left", set = "name", pool = 4, rgb = INK,
	} )
	self:addElement( self.todFootHold )
	self.todFootHold:setText( "HOLD" )

	local keyL = l + FOOT_HOLD_W + FOOT_GAP

	self.todFootKey = LUI.UIText.new()
	self.todFootKey:setLeftRight( true, false, keyL, keyL + FOOT_KEY_W )
	-- 12.4 tall as before, but centred on the footer's CAP BOX instead of hung
	-- off the text box's top edge, so the button picture and the letters beside
	-- it share a middle rather than a top.
	self.todFootKey:setTopBottom( true, false, 502.7, 515.1 )
	self.todFootKey:setTTF( "fonts/ltromatic.ttf" )
	self.todFootKey:setRGB( 1, 0.82, 0.25 )
	self.todFootKey:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	self:addElement( self.todFootKey )

	local verbL = keyL + FOOT_KEY_W + FOOT_GAP
	self.todFootVerb = CoD.TodGlyphText.new( {
		left = verbL, right = BOX.footR, top = BOX.footT, bottom = BOX.footB,
		align = "left", set = "name", pool = 14, rgb = INK,
	} )
	self:addElement( self.todFootVerb )
end

-- ---------------------------------------------------------------------------
-- LAYOUT THE FOOTER LINE — the ONE place its widths and its cap are decided.
--
-- WHY THIS EXISTS (v19.8, user: *"your footer is the main issue"*). The footer
-- is THREE elements on one line, and TodGlyphText fits each row to its OWN box.
-- "TO ACTIVATE" wants 60.7 units and had 40.6, so it clamped to cap 4.56 —
-- while "HOLD" next to it, which fits its box easily, drew at 7.52. One line,
-- two type sizes, and the bigger word was the throwaway one.
--
-- So the verb is MEASURED here, before anything draws, and whatever cap it can
-- actually have is pushed into BOTH rows. They already shared a baseline (same
-- box top and bottom); now they share a size, and the line shrinks as a unit or
-- not at all.
--
-- THE RIGHT EDGE IS CONDITIONAL because the price shares this row. With a price
-- the verb must stop at footR; without one it runs to the card's inner edge,
-- and "TO ACTIVATE" — the longest verb in the map, on the power switch, which
-- has no price — then fits at full size with room to spare.
-- ---------------------------------------------------------------------------
-- v19.18 — re-place the three footer rows against the card's own left column.
-- Called by LayoutFooter, so a widened card moves HOLD / key / verb with it.
function CoD.TodPromptCard.PlaceFooterRows( self )
	if not self.todFootHold then
		return
	end
	local l    = self.colFootL or BOX.footL
	local keyL = l + FOOT_HOLD_W + FOOT_GAP
	self.todFootHold:setBox( l, l + FOOT_HOLD_W, BOX.footT, BOX.footB )
	self.todFootKey:setLeftRight( true, false, keyL, keyL + FOOT_KEY_W )
end

function CoD.TodPromptCard.LayoutFooter( self )
	CoD.TodPromptCard.PlaceFooterRows( self )
	if not self.todFootVerb then
		return
	end

	local right = self.todHasPrice and BOX.footR or BOX.footRWide
	local footL = self.colFootL or BOX.footL
	local left  = footL + FOOT_HOLD_W + FOOT_GAP + FOOT_KEY_W + FOOT_GAP
	local capBase = ( BOX.footB - BOX.footT ) * 0.80

	self.todFootVerb:setBox( left, right, BOX.footT, BOX.footB )

	local cap = capBase
	local w = self.todFootVerb:measure( self.todFootVerb:getText(), capBase )
	if w > 0 and w > ( right - left ) then
		cap = capBase * ( right - left ) / w
	end
	self.todFootVerb:setCap( cap )
	self.todFootHold:setCap( cap )
end

-- SetFooter( verb ) — verb is the ACTION WORD ONLY ("USE", "BUY", "OPEN").
-- This file adds the "TO". Callers must not pass "To Use".
function CoD.TodPromptCard.SetFooter( self, verb )
	if not self.todFootVerb then
		return
	end

	verb = verb or "USE"
	self.todFootVerbText = verb
	self.todFootVerb:setText( "TO " .. verb )
	self.todFootVerb:setAlpha( 1 )
	self.todFootHold:setAlpha( 1 )

	-- Re-resolved on EVERY hint, so a player who swaps device or rebinds
	-- mid-match is correct at the very next prompt.
	self.todFootKey:setText( Engine.Localize( "[{+activate}]" ) )
	self.todFootKey:setAlpha( 1 )

	CoD.TodPromptCard.LayoutFooter( self )
end

-- SetFooterVisible( on ) — hide the WHOLE footer row for a STATUS line.
--
-- A hint with no key in it is not an instruction: "TELEPORTER - recharging..."
-- and "ALTAR SPENT" are the map telling the player why nothing is happening.
-- Advertising a button there is worse than saying nothing, because they will
-- hold it and conclude the prompt is broken.
function CoD.TodPromptCard.SetFooterVisible( self, on )
	if not self.todFootVerb then
		return          -- this card was built with footer = false
	end
	if on then
		-- Re-run the whole footer: the key half has to be re-resolved anyway,
		-- and the verb is remembered from the last SetFooter.
		CoD.TodPromptCard.SetFooter( self, self.todFootVerbText )
		return
	end
	self.todFootHold:setAlpha( 0 )
	self.todFootVerb:setAlpha( 0 )
	self.todFootKey:setAlpha( 0 )
end

-- ---------------------------------------------------------------------------
-- SANITIZE — THE SAFETY NET FOR A 42-GLYPH TYPEFACE.
--
-- ⚠️ THE RISK THIS EXISTS TO CATCH. CoD.TodGlyphText's cleaner DROPS any
-- character with no cell, silently. The set is A-Z, 0-9, space, hyphen,
-- apostrophe, full stop, the money symbol, + and /, and (v19.58) % and : as
-- composites — and nothing else. TodGlyphText now runs its own copy of this
-- net (TG_SANITIZE) for every screen; this one stays because a prompt reads a
-- spaced OR unspaced "/" as a clause divider, which is prompt grammar. So a string
-- written for a TTF degrades in the worst possible way: it does not error, it
-- does not show a box, it just fuses the words either side of the missing mark.
--
-- Measured on the live perk table before this was written, `( ) , / : ;` all
-- appear in strings that now route through the typeface, e.g.
--   "Faster revives in co-op / Self-revive up to 3 times in solo"
-- would have drawn as "...IN CO-OP SELF-REVIVE UP TO..." with the divider gone
-- and the two clauses run together.
--
-- So every mark we know how to say WITHOUT a glyph is converted to one we have,
-- here, in the one place every card's text passes through. Anything still
-- unmapped is left to the cleaner — this is a net, not a licence to write copy
-- that needs punctuation we do not own.
-- ---------------------------------------------------------------------------
local SANITIZE = {
	{ "%s*/%s*",  " - " },    -- an either/or divider becomes a dash
	{ "%s*;%s*",  " - " },    -- a clause break becomes a dash
	{ "%s*:%s*",  " " },      -- a label colon just goes
	{ "%s*,%s*",  " " },      -- a list comma becomes the space it already implied
	{ "[%(%)%[%]]", "" },     -- brackets drop; what is inside them survives
	{ "%s+",      " " },      -- collapse whatever the above left behind
}

function CoD.TodPromptCard.Sanitize( s )
	if s == nil then
		return ""
	end
	s = CoD.TodPromptCard.StripColour( tostring( s ) )
	for i = 1, #SANITIZE do
		s = string.gsub( s, SANITIZE[ i ][ 1 ], SANITIZE[ i ][ 2 ] )
	end
	return ( string.gsub( s, "^%s*(.-)%s*$", "%1" ) )
end

-- ---------------------------------------------------------------------------
-- THE SETTERS. A card file should never touch an element directly, and every
-- one of these sanitizes — so a card cannot bypass the net by accident.
-- ---------------------------------------------------------------------------
function CoD.TodPromptCard.SetTitle( self, s )
	if self.todTitle then
		self.todTitle:setText( CoD.TodPromptCard.Sanitize( s ) )
	end
end

-- ---------------------------------------------------------------------------
-- PLACE THE DESCRIPTION ROWS IN THE BODY BAND.
--
-- The band is the art's, 462.1..500.6. A PAIR of rows is centred in it as one
-- block; a SINGLE row is centred on its own, which is the case that was worst
-- before — every door and Pack-a-Punch write one line and it sat at the top of
-- the band with 25 units of nothing beneath it.
--
-- Called from SetDetail, because the number of lines is a property of the copy
-- and can change between one hint and the next on the SAME card.
-- ---------------------------------------------------------------------------
function CoD.TodPromptCard.LayoutDetail( self, twoLines )
	if not self.todDesc1 then
		return
	end
	self.todTwoLines = twoLines   -- v19.18: SetWide re-runs this and needs the count
	local band  = BOX.bodyB - BOX.bodyT
	local block = twoLines and ( BOX.descPitch + BOX.descH ) or BOX.descH
	local t = BOX.bodyT + ( band - block ) / 2
	local dl = self.colDescL or BOX.descL
	self.todDesc1:setBox( dl, BOX.descR, t, t + BOX.descH )
	if self.todDesc2 then
		local t2 = t + BOX.descPitch
		self.todDesc2:setBox( dl, BOX.descR, t2, t2 + BOX.descH )
	end
end

function CoD.TodPromptCard.SetDetail( self, line1, line2 )
	local a = CoD.TodPromptCard.Sanitize( line1 )
	local b = CoD.TodPromptCard.Sanitize( line2 )
	-- Place BEFORE setting the text: setBox repaints, so doing it after would
	-- lay the string out once for the old box and again for the new one.
	CoD.TodPromptCard.LayoutDetail( self, b ~= "" )
	if self.todDesc1 then
		self.todDesc1:setText( a )
	end
	if self.todDesc2 then
		self.todDesc2:setText( b )
	end
end

-- SetPrice( n ) — the money symbol is part of the string, not a second element,
-- so "no price" is simply an empty row. Nothing can be left behind.
function CoD.TodPromptCard.SetPrice( self, n )
	if not self.todPrice then
		return
	end
	local s = ( n == nil ) and "" or tostring( n )
	-- Strip anything that is not a digit: callers hand us whatever their hint
	-- parse produced, and a stray bracket or caret would eat a glyph slot.
	s = string.gsub( s, "%D", "" )
	if s == "" or tonumber( s ) == 0 then
		self.todPrice:setText( "" )
		-- The price shares the footer's row, so its ABSENCE is what hands the
		-- verb the rest of the line. Re-lay out whenever that changes: a card may
		-- set the price before or after the verb, and both orders occur live.
		self.todHasPrice = false
		CoD.TodPromptCard.LayoutFooter( self )
		return
	end
	self.todPrice:setText( "$" .. s )
	self.todHasPrice = true
	CoD.TodPromptCard.LayoutFooter( self )
end

-- ---------------------------------------------------------------------------
-- SetWide( on ) — THE WIDER CARD, for copy that needs the room (user
-- 2026-09-15, twice: *"QR needs a larger prompt to fit everything"*, then
-- *"I had asked you earlier if we could make the card bigger. You didn't do
-- that"*). Quick Revive states a solo price, a co-op price and what each does,
-- which is more than any other prompt carries.
--
-- ⚠️ THE ART IS 9-SLICED, NOT STRETCHED. `i_tod_prompt_chassis_wide` is the
-- same PNG with only its MIDDLE columns resampled (left 300 px and right 44 px
-- copied verbatim), so the rounded corners, the border and the icon well keep
-- their exact shape and the card simply grows a wider body. Stretching the
-- whole image to 1.3x would have flattened every corner into an ellipse, which
-- is the kind of "fix" that produces the next screenshot.
--
-- BOTH PNGs ARE 4 px PER CANVAS UNIT, so the widened art is 277 px = 69.25
-- units broader and the card's LEFT EDGE moves out by exactly that. Everything
-- anchored to the left edge (the well, the icon, every text column) moves with
-- it; everything anchored right (the price, the row right edges) does not.
-- ---------------------------------------------------------------------------
-- 69 exactly, not 69.25: the widened PNG must have a width that is a MULTIPLE
-- OF 4 or the linker refuses it for the compressed format ("must be a multiple
-- of 4 for compressed formats"), so the art is 1200 px = 276 px added = 69.0
-- canvas units at this card's 4 px per unit.
local WIDE_DX = 69

local function box( e, l, r, t, b )
	if not e then return end
	e:setLeftRight( true, false, l, r )
	e:setTopBottom( true, false, t, b )
end

function CoD.TodPromptCard.SetWide( self, on )
	on = on and true or false
	if self.todWide == on or not self.todChassis then
		return
	end
	self.todWide = on
	local dx = on and WIDE_DX or 0

	self.todChassis:setImage( RegisterImage( on and "i_tod_prompt_chassis_wide"
	                                            or  "i_tod_prompt_chassis" ) )
	box( self.todChassis,  BOX.frameL - dx, BOX.frameR, BOX.frameT, BOX.frameB )
	box( self.todBgMain,   616 - dx, 772, 460, 518 )
	box( self.todBgHeader, 615 - dx, 773, 446, 461 )
	box( self.todBgFrame,  618 - dx, 775, 449, 517 )
	box( self.todBgIcon,   BOX.iconWellL - dx, BOX.iconWellR - dx, BOX.iconWellT, BOX.iconWellB )
	box( self.todIcon,     BOX.iconL - dx, BOX.iconR - dx, BOX.iconT, BOX.iconB )

	self.colDescL = BOX.descL - dx
	self.colFootL = BOX.footL - dx
	if self.todTitle then
		self.todTitle:setBox( BOX.titleL - dx, BOX.titleR, BOX.titleT, BOX.titleB )
	end
	-- Re-run both layouts: they read the columns above and re-fit their rows.
	CoD.TodPromptCard.LayoutDetail( self, self.todTwoLines )
	CoD.TodPromptCard.LayoutFooter( self )
end

-- SetIcon( hintLine ) — pass the WHOLE hint line; the table reads all of it.
function CoD.TodPromptCard.SetIcon( self, hintLine )
	if not self.todIcon then
		return
	end
	local want = CoD.TodPromptCard.IconFor( hintLine )
	if want ~= self.todIconName then
		self.todIcon:setImage( RegisterImage( want ) )
		self.todIconName = want
	end
end

-- SetIconImage( name ) — for a card that knows its object without a hint
-- (PromptPerks picks a different image per perk).
function CoD.TodPromptCard.SetIconImage( self, name )
	if not self.todIcon or not name or name == "" then
		return
	end
	if name ~= self.todIconName then
		self.todIcon:setImage( RegisterImage( name ) )
		self.todIconName = name
	end
end

-- ---------------------------------------------------------------------------
-- STRIP THE ENGINE'S BIND OUT OF A HINT LINE.
--
-- Every pressable hint this map writes is:
--     Hold ^3[{+activate}]^7 <TITLE> - <detail> ^2[Cost: N]
-- By the time Lua reads it the token is already the device's key, so the ONLY
-- stable anchors are the pieces THE MAP wrote: the word "Hold" and the ^3/^7
-- pair around the key. Swallow whatever sits between them, whatever it became.
--
-- ⚠️ DO NOT replace this with a byte-range test on the expansion. v18.47
-- shipped exactly that next door in TodKeycap and turned every keyboard player
-- into a controller player.
-- ---------------------------------------------------------------------------
function CoD.TodPromptCard.StripBind( t )
	if not t or t == "" then
		return "", false
	end
	local had = string.find( t, "^%s*[Hh][Oo][Ll][Dd]%s+%^3" ) ~= nil
	if had then
		t = string.gsub( t, "^%s*[Hh][Oo][Ll][Dd]%s+%^3.-%^7%s*", "", 1 )
	end
	return t, had
end

-- Strip every ^N colour code. The glyph sheet has no caret glyph, so a stray
-- code would be silently dropped mid-word and shift the letters after it.
function CoD.TodPromptCard.StripColour( t )
	if not t then
		return ""
	end
	return ( string.gsub( t, "%^%d", "" ) )
end
