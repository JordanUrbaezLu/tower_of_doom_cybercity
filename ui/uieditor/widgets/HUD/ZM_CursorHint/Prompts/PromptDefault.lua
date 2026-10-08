-- =============================================================================
-- PromptDefault.lua — the card every custom prompt in this map lands on.
--
-- Ammo crates, the Heavenly Gift Altar, the upgrade stations, teleporters, the
-- rampage inducer, CALL EXTRACTION, the spire doors and every sealed/spent/
-- recharging status line: all of them route here, because classifyHint claims
-- anything leading with a noun in TOD_NOUNS before the kit's own arms can.
--
-- v19.3: REBUILT ON CoD.TodPromptCard like every other card. The chassis, the
-- icon table, the typeface, the footer and the price are no longer this file's
-- business — it owns THE PARSE, which is the only thing here that is special.
--
-- ---------------------------------------------------------------------------
-- THE HINT GRAMMAR THIS PARSES
--
--     Hold ^3[{+activate}]^7 ^5<TITLE>^7 - <detail> / <detail 2> ^2[Cost: N]
--
-- title  <- everything before the FIRST " - "
-- detail <- split again on the FIRST " / " into two rows
-- price  <- the bracketed cost, if any
--
-- ⚠️ NO HYPHEN OR SLASH MAY APPEAR INSIDE A TITLE OR A DETAIL or it reads as
-- the separator. tools/lint_tod_hints.js checks every hint against that.
--
-- ---------------------------------------------------------------------------
-- ⚠️ THE BIND TOKEN IS ALREADY GONE BEFORE LUA EVER SEES IT (v19.2).
--
-- The engine resolves the cursor hint — localize, substitute args, expand
-- [{+bind}] — and publishes the RESULT to hudItems.cursorHintText. So the
-- literal token is never present, and the old string.find( t, "%[{%+[%w_]+}%]" )
-- gate NEVER FIRED: "Hold <key>" rode into every title and the footer, gated on
-- the same flag, was permanently hidden. Both symptoms, one dead test.
--
-- The strip now lives in CoD.TodPromptCard.StripBind and anchors on text THE
-- MAP authored at both ends — the word "Hold" and the ^3/^7 pair around the key
-- — swallowing whatever the engine put between them. Device-independent by
-- construction. Do NOT replace it with a byte-range test on the expansion:
-- v18.47 shipped exactly that in TodKeycap and turned every keyboard player
-- into a controller player.
-- =============================================================================

require( "ui.uieditor.widgets.HUD.ZM_CursorHint.Prompts.TodPromptCard" )
require( "ui.uieditor.widgets.HUD.ZM_CursorHint.Prompts.TodTeleportFeedback" )

CoD.PromptDefault = InheritFrom( LUI.UIElement )

function CoD.PromptDefault.SetFooter( self, verb )
	CoD.TodPromptCard.SetFooter( self, verb )
end

function CoD.PromptDefault.new( menu, controller )
	local self = LUI.UIElement.new()

	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end

	self:setUseStencil( false )
	self:setClass( CoD.PromptDefault )
	self.id = "PromptDefault"
	self.soundSet = "HUD"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self:setAlpha( 0 )  -- start hidden

	CoD.TodPromptCard.Build( self, {
		icon   = CoD.TodPromptCard.ICON_FALLBACK,
		footer = "USE",
	} )

	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" ), function ( model )
		local hintText = Engine.GetModelValue( model )
		if not hintText or hintText == "" then
			return
		end

		local t, hasButton = CoD.TodPromptCard.StripBind( hintText )

		-- Belt and braces: if the token ever DOES arrive unexpanded (a future
		-- engine path, or a hint set before binds resolve), drop it and the
		-- leading Hold rather than drawing it as text.
		if string.find( t, "%[{%+[%w_]+}%]" ) then
			hasButton = true
			t = string.gsub( t, "%[{%+[%w_]+}%]", "" )
			t = string.gsub( t, "^%s*[Hh][Oo][Ll][Dd]%s+", "" )
		end

		t = CoD.TodPromptCard.StripColour( t )

		-- Price, then take the bracket out of the flowing text.
		local cost = string.match( t, "%[[Cc]ost:%s*(%d+)%s*%]" )
		t = string.gsub( t, "%s*%[[Cc]ost:[^%]]*%]", "" )

		t = string.gsub( t, "^%s+", "" )
		t = string.gsub( t, "%s+$", "" )
		t = string.gsub( t, "%s%s+", " " )

		-- THE SURROUNDING SPACES ARE OPTIONAL, DELIBERATELY. If whitespace is
		-- ever eaten upstream this degrades to cramped text rather than
		-- collapsing the whole line into one title-shaped blob.
		local title, detail = string.match( t, "^(.-)%s*%-%s*(.*)$" )
		if not title then
			title = t
			detail = ""
		end

		local d1, d2 = string.match( detail, "^(.-)%s*/%s*(.*)$" )
		if not d1 then
			d1 = detail
			d2 = ""
		end

		CoD.TodPromptCard.SetTitle( self, title )
		CoD.TodPromptCard.SetDetail( self, d1, d2 )

		-- THE OBJECT ICON. Keyed on the WHOLE line, not just the title: two
		-- different objects both title themselves "SEALED" and only the detail
		-- separates them. The table lives in TodPromptCard so all six cards
		-- share one copy.
		CoD.TodPromptCard.SetIcon( self, ( title or "" ) .. " " .. ( detail or "" ) )

		CoD.TodPromptCard.SetPrice( self, cost )

		-- FOOTER VERB. A price row is the usual tell, but the ammo crate has
		-- TWO prices and one row, so it spells them out in the detail lines
		-- ("REGULAR $2500" / "PACK A PUNCH $5000") and carries no [Cost:]
		-- bracket at all. A "$" anywhere in the line is therefore just as good
		-- a signal that this costs money; without it the crate's footer would
		-- read "TO USE" at a 2500-point purchase.
		if cost or string.find( t, "%$" ) then
			CoD.TodPromptCard.SetFooter( self, "BUY" )
		else
			CoD.TodPromptCard.SetFooter( self, "USE" )
		end

		-- No key in the hint means nothing to hold — hide the whole footer
		-- rather than instruct the player to press something at a status line
		-- ("TELEPORTER - recharging...", "ALTAR SPENT").
		CoD.TodPromptCard.SetFooterVisible( self, hasButton )
	end )

	CoD.TodTeleportFeedback.Attach( self, controller )

	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end

	return self
end
