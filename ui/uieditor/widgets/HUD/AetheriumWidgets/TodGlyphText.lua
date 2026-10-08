-- =============================================================================
-- TodGlyphText — a UIText-shaped element that draws in the map's own typeface.
--
-- v17.34 (user 2026-09-04): "Can you look into changing all the text on screen
-- to use our alphabet? Mainly looking at the text on Left that shows players
-- name and HP and the our damage numbers and points gain that show up and
-- displayed at center of screen. Can we change all of that to use the alphabet
-- we created and numbers. Our typography."
--
-- WHY A SECOND LAYER OVER TodGlyphRow. The row factory is the right primitive
-- for the two readouts that already used it (the gun HUD, the ROUND counter):
-- both are ONE string, authored at an exact cap, right-aligned to an exact
-- edge, and they hand-place it. The readouts this file exists for are not like
-- that. There are ELEVEN of them, they were UIText elements living inside boxes
-- other code positions (the party rows compute their y from a row index), some
-- are LEFT aligned and one is CENTRED, they carry live values of unknown width,
-- and three of them carry a PLAYER NAME, which is arbitrary user data.
--
-- Hand-placing eleven caps and eleven baselines would have been eleven pairs of
-- numbers to keep in step with boxes that already exist and already move. So
-- this element takes THE BOX -- the same four numbers the UIText it replaces
-- was given -- and derives the cap, the baseline and the alignment from it.
-- Move the box and the text follows; there is no second set of coordinates.
--
-- WHAT A CALLER GETS -- deliberately the UIText surface, so a conversion is a
-- constructor swap and nothing else:
--   :setText( s )      any type; numbers are fine (Engine.Localize returns them)
--   :getText()         the RAW string last set, not the cleaned one
--   :setRGB( r,g,b )
--   :setAlpha( a )     inherited; LUI multiplies it down onto the glyphs, which
--                      is what lets the kill feed keep fading its rows
--   :setBox( l,r,t,b ) move/resize later
--   and since v19.58 the UIText calls themselves - setLeftRight / setTopBottom
--   (any anchors; only the box SIZE matters), setAlignment, and setTTF /
--   setLetterSpacing as no-ops - so CoD.TodGlyphText.Label() is a drop-in.
--
-- THE TYPEFACE IS CAPS-ONLY. The sheets carry A-Z, 0-9 and - ' . $ + / ; "+"
-- and "/" live ONLY on the digit sheet and ' . $ only on the letter sheet, so
-- the cleaner is SET-AWARE. Since v19.58 the name picker routes + and / to
-- the digit sheet (they used to blank the string), and "%" and ":" are drawn
-- as COMPOSITES of existing cells (TodGlyphRow). Everything else goes through
-- the copy net (TG_SANITIZE below) and is then dropped.
--
-- A PLAYER NAME IS NOT OUR TEXT. Steam names carry emoji, Cyrillic, CJK and
-- symbols we will never bake. Unrenderable characters are dropped, and if that
-- leaves NOTHING the element falls back to a real TTF UIText with the original
-- string in it -- visible and in the wrong typeface, rather than invisible.
-- Only the three name readouts ask for that lane; every number readout has full
-- glyph coverage by construction and carries no fallback element at all.
-- =============================================================================

require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodGlyphRow" )

-- Cap height as a fraction of the box height, and the baseline as a fraction of
-- it. A 12px box therefore draws a 9.6px cap sitting on y11.3, which leaves the
-- descender room the sheets expect (both cells carry 5-8% below the baseline).
-- Per-instance overrides exist (opts.capFrac / opts.cap / opts.baseFrac); these
-- are what a readout gets unless it says otherwise.
local TG_CAP_FRAC  = 0.80
local TG_BASE_FRAC = 0.94

-- The glyphs that exist, per sheet. NOT a style choice -- this is the inventory
-- in TodGlyphMetrics, and asking for anything outside it blanks the string.
-- v19.2: "$" joins the renderable set -- it is the points icon in cell 28.
-- WITHOUT THIS LINE the cleaner would silently DROP every "$" and a price
-- would read "2500" with no symbol at all.
local TG_NAME_OK  = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -'.$+/%:"   -- v19.58: + / from the digit sheet, % : composite (TodGlyphRow)
local TG_DIGIT_OK = "0123456789+-/"

-- Uppercase, drop what we cannot draw, collapse the whitespace that dropping
-- leaves behind. `_` becomes `-` because it is the one substitution that is
-- obviously right in a player name; everything else is simply gone.
--
-- BUILT WITH `..`, NOT table.concat, and that is not a style preference: this
-- file loads inside AetheriumHud, which is NOT fail-safed (only tod_upgrade.lua
-- pcalls its requires), so an unavailable global here takes the WHOLE HUD down
-- at load. `string.upper/find/gsub/sub` are all proven in AetheriumLoadout.lua
-- in this same menu; `table.concat` is used nowhere in ui/, and a 32-character
-- string is not worth spending an unproven global on.
-- THE MAP-WIDE COPY NET (v19.58, the typography pass; lifted from
-- TodPromptCard's SANITIZE, which proved it on every prompt). Marks we cannot
-- draw become marks we can, BEFORE the cleaner drops what is left - otherwise
-- "16% OF SHOTS FREE, +16% DAMAGE" fuses into "...FREE +16...". Order matters:
-- colour codes first, then the spaced either/or slash (an unspaced one, as in
-- "HP/S" or "1/3", is a real glyph now and stays).
local TG_SANITIZE = {
	{ "%^%d",        "" },      -- ^1..^9 colour codes (a glyph row is one colour)
	{ "%s+/%s+",     " - " },   -- "A / B" either/or divider
	{ "%s*;%s*",     " - " },   -- clause break
	{ "%s*,%s*",     " " },     -- list comma
	{ "%s*&%s*",     " AND " },
	{ "%s*>%s*",     " - " },   -- "MSMC > MP5" ladders
	{ "[%(%)%[%]!?#\"]", "" },  -- brackets, bangs, quotes: the words survive
	{ "%s+",         " " },
}
local function tgSanitize( s )
	for i = 1, #TG_SANITIZE do
		s = string.gsub( s, TG_SANITIZE[ i ][ 1 ], TG_SANITIZE[ i ][ 2 ] )
	end
	return s
end

local function tgClean( s, digits )
	s = string.upper( tostring( s ) )
	if not digits then
		s = tgSanitize( s )
	end
	local ok, r = ( digits and TG_DIGIT_OK or TG_NAME_OK ), ""
	for i = 1, #s do
		local c = string.sub( s, i, i )
		if c == "_" and not digits then
			c = "-"
		end
		if string.find( ok, c, 1, true ) then
			r = r .. c
		end
	end
	r = string.gsub( r, "  +", " " )
	r = string.gsub( r, "^ +", "" )
	r = string.gsub( r, " +$", "" )
	return r
end

CoD.TodGlyphText = InheritFrom( LUI.UIElement )

-- opts: left/right/top/bottom (the box, required), align "left"|"center"|
-- "right", set "name"|"digits", pool (glyph slots), cap or capFrac, baseFrac,
-- rgb {r,g,b}, fallbackTTF (names only), text (initial value), centered (anchor
-- the box to the SCREEN CENTRE on both axes instead of the top-left, which is
-- what the crosshair damage numbers need).
CoD.TodGlyphText.new = function ( opts )
	local self = LUI.UIElement.new()
	self:setUseStencil( false )
	self:setClass( CoD.TodGlyphText )
	self.id = "TodGlyphText"

	local digits   = ( opts.set == "digits" )
	local picker   = digits and CoD.TodGlyphRow.digitSet or CoD.TodGlyphRow.nameSet
	local grow     = ( opts.grow == true )
	local pool     = opts.pool or ( grow and 4 or 12 )
	local align    = opts.align or "left"
	local capFrac  = opts.capFrac or TG_CAP_FRAC
	local baseFrac = opts.baseFrac or TG_BASE_FRAC

	-- ANCHORS. `true, false` pins the box to the parent's top-left, which is
	-- what every readout in the left column and the kill feed wants. `false,
	-- false` pins it to the parent's CENTRE on that axis -- the crosshair
	-- damage numbers are authored as offsets from the middle of the screen and
	-- must stay there at any aspect ratio.
	local anchor = not opts.centered
	local box = { l = opts.left or 0, r = opts.right or 0, t = opts.top or 0, b = opts.bottom or 0 }
	self:setLeftRight( anchor, false, box.l, box.r )
	self:setTopBottom( anchor, false, box.t, box.b )

	-- The fallback lives BEHIND the row (added first) and spans the whole box in
	-- element-local coordinates, so it lands exactly where the glyphs would.
	local fallback = nil
	if opts.fallbackTTF then
		fallback = LUI.UIText.new()
		fallback:setLeftRight( true, false, 0, box.r - box.l )
		fallback:setTopBottom( true, false, 0, box.b - box.t )
		fallback:setTTF( opts.fallbackTTF )
		fallback:setAlignment( ( align == "center" and Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
			or ( align == "right" and Enum.LUIAlignment.LUI_ALIGNMENT_RIGHT )
			or Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
		fallback:setAlpha( 0 )
		self:addElement( fallback )
	end

	local row = CoD.TodGlyphRow.make( self, pool )
	local raw, clean = "", ""
	local capSet = opts.cap          -- explicit cap, overriding the box fraction
	local typeScale = 1              -- v19.58: setScale scales the TYPE, not the box (see below)

	local function paint()
		local w = box.r - box.l
		local h = box.b - box.t
		if fallback then
			fallback:setAlpha( 0 )
		end
		if clean == "" then
			row.hide()
			-- Nothing renderable, but the caller DID give us text: show it in a
			-- real font rather than dropping a player off their own HUD.
			if fallback and raw ~= "" then
				fallback:setText( raw )
				fallback:setAlpha( 1 )
			end
			return
		end

		local cap = ( capSet or ( h * capFrac ) ) * typeScale
		local wid = row.measure( clean, cap, picker )
		if wid < 0 then
			row.hide()
			return
		end
		-- FIT. Every term in measure() is linear in cap, so one multiply is an
		-- exact fit, not an iteration. A long name shrinks instead of running
		-- out of its box and under the health bar next to it.
		if wid > w and w > 0 then
			cap = cap * ( w / wid )
			wid = w
		end

		local rightX = wid                              -- left aligned
		if align == "right" then
			rightX = w
		elseif align == "center" then
			rightX = ( w + wid ) / 2
		end
		row.set( clean, cap, rightX, h * baseFrac, picker )
	end

	self.setText = function ( _, s )
		raw = ( s == nil ) and "" or tostring( s )
		clean = tgClean( raw, digits )
		-- GROW (v19.58, opts.grow): a label sized by its text adds the images it
		-- is short, once, and keeps them. Otherwise the pool is the hard ceiling
		-- on length: row.set stops drawing at slot n while measure() has already
		-- counted the whole string, so an over-long string would be laid out
		-- for a width it never draws. Cut it here, where both calls see it.
		local need = CoD.TodGlyphRow.imageCount( clean )
		if grow and need > pool then
			row.grow( need )
			pool = need
		end
		while CoD.TodGlyphRow.imageCount( clean ) > pool do
			clean = string.sub( clean, 1, #clean - 1 )
		end
		paint()
	end

	self.getText = function ()
		return raw
	end

	self.setRGB = function ( _, r, g, b )
		row.setRGB( r, g, b )
		if fallback then
			fallback:setRGB( r, g, b )
		end
	end

	-- Resize the type itself. The crosshair pool is one element re-used for
	-- every hit and a headshot draws 25% larger, so the cap is per-DRAW there,
	-- not per-element. Pass nil to go back to the box fraction.
	self.setCap = function ( _, c )
		capSet = c
		paint()
	end

	-- MEASURE WITHOUT DRAWING. The prompt footer is two glyph rows on ONE line
	-- ("HOLD" and "TO UPGRADE") that must end up the same size, so the caller
	-- has to know what the longer one will clamp to before it sets either. The
	-- walk is the row's own, over the generated metrics -- a re-sliced sheet
	-- re-spaces every caller for free, which a copied constant would not.
	self.measure = function ( _, str, cap )
		local c = tgClean( str, digits )
		if c == "" then
			return 0
		end
		if not grow and #c > pool then
			c = string.sub( c, 1, pool )
		end
		local wid = row.measure( c, cap, picker )
		return ( wid < 0 ) and 0 or wid
	end

	self.setBox = function ( _, l, r, t, b )
		box.l, box.r, box.t, box.b = l, r, t, b
		self:setLeftRight( anchor, false, l, r )
		self:setTopBottom( anchor, false, t, b )
		if fallback then
			fallback:setLeftRight( true, false, 0, r - l )
			fallback:setTopBottom( true, false, 0, b - t )
		end
		paint()
	end

	-- DROP-IN UIText SURFACE (v19.58). A converted screen swaps its
	-- LUI.UIText.new() for CoD.TodGlyphText.Label() and keeps every other line:
	-- setLeftRight / setTopBottom move the box (only its SIZE matters to the
	-- layout, so any anchor works), setAlignment picks the side, setTTF is a
	-- no-op (the typeface IS the font), setScale is the element's own.
	local origLR, origTB = self.setLeftRight, self.setTopBottom
	self.setLeftRight = function ( _, a, b, l, r )
		origLR( self, a, b, l, r )
		box.l, box.r = l, r
		if fallback then fallback:setLeftRight( true, false, 0, r - l ) end
		paint()
	end
	self.setTopBottom = function ( _, a, b, t, bt )
		origTB( self, a, b, t, bt )
		box.t, box.b = t, bt
		if fallback then fallback:setTopBottom( true, false, 0, bt - t ) end
		paint()
	end
	self.setTTF = function () end
	-- setScale SCALES THE TYPE, NOT THE ELEMENT (v19.58, user screenshot: the
	-- pause menu's grey lines sat indented). On a UIText, setScale shrinks the
	-- glyphs inside a fixed box; on a UIElement it shrinks the whole box about
	-- its CENTRE, which walked a left-aligned 0.79 line ~38 units to the right.
	-- The drop-in keeps the UIText meaning: the box stays put, the cap shrinks,
	-- and alignment holds to the box edge.
	self.setScale = function ( _, sc )
		typeScale = tonumber( sc ) or 1
		paint()
	end
	self.setLetterSpacing = function () end   -- the typeface carries its own tracking
	self.setAlignment = function ( _, e )
		local A = Enum.LUIAlignment
		if e == A.LUI_ALIGNMENT_CENTER then align = "center"
		elseif e == A.LUI_ALIGNMENT_RIGHT then align = "right"
		else align = "left" end
		paint()
	end

	if opts.rgb then
		self:setRGB( opts.rgb[ 1 ], opts.rgb[ 2 ], opts.rgb[ 3 ] )
	end
	self:setText( opts.text or "" )

	LUI.OverrideFunction_CallOriginalSecond( self, "close", function ( element )
		row.close()
		if fallback then
			fallback:close()
		end
	end )

	return self
end

-- THE LABEL FACTORY (v19.58): an engine-text-shaped glyph label with a growing
-- pool. Default box is empty; the caller's setLeftRight / setTopBottom place it,
-- exactly as they placed the UIText it replaces. Default alignment is LEFT,
-- the same default UIText has.
CoD.TodGlyphText.Label = function ( opts )
	opts = opts or {}
	opts.left = opts.left or 0
	opts.right = opts.right or 0
	opts.top = opts.top or 0
	opts.bottom = opts.bottom or 0
	opts.grow = true
	return CoD.TodGlyphText.new( opts )
end

-- The shared copy net, for callers that measure or split text themselves.
CoD.TodGlyphText.Sanitize = function ( s )
	return tgSanitize( string.upper( tostring( s or "" ) ) )
end

return CoD.TodGlyphText
