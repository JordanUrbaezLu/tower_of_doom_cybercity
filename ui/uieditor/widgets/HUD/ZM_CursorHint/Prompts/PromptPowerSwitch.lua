-- =============================================================================
-- PromptPowerSwitch.lua — the base power switch.
--
-- v19.3: REBUILT ON CoD.TodPromptCard. Everything this file used to draw by
-- hand — five chassis rects, the icon, the title, the description, the footer —
-- now comes from the one shared owner, so this card's LOOK is no longer this
-- card's business. See TodPromptCard.lua's header for why.
--
-- WHAT CHANGED FOR THE PLAYER, and both were real faults the user found in
-- two minutes of play:
--
--   1. THE TYPEFACE. The title was orbitron and the description ltromatic —
--      the vendored kit's two fonts. Three feet away the ammo crate was drawing
--      the map's own letters. Now both are the map's typeface, which is also
--      uppercase by construction, so the case is right without anyone policing
--      the source string.
--
--   2. THE COPY. The description read *"Powers various things around the map"*
--      — kit filler that was never written about this map and tells a player
--      nothing they can act on. It now names what power actually unlocks here.
-- =============================================================================

require( "ui.uieditor.widgets.HUD.ZM_CursorHint.Prompts.TodPromptCard" )

CoD.PromptPowerSwitch = InheritFrom( LUI.UIElement )

function CoD.PromptPowerSwitch.SetFooter( self, verb )
	CoD.TodPromptCard.SetFooter( self, verb )
end

function CoD.PromptPowerSwitch.new( menu, controller )
	local self = LUI.UIElement.new()

	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end

	self:setUseStencil( false )
	self:setClass( CoD.PromptPowerSwitch )
	self.id = "PromptPowerSwitch"
	self.soundSet = "HUD"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self:setAlpha( 0 )  -- start hidden

	CoD.TodPromptCard.Build( self, {
		icon   = "i_tod_prompt_icon_power",
		footer = "ACTIVATE",
	} )

	CoD.TodPromptCard.SetTitle( self, "POWER SWITCH" )

	-- Two lines instead of one sentence: the first says what the switch does,
	-- the second says what that BUYS, which is the part a player is actually
	-- deciding about. Both sit inside the 34-glyph detail pool.
	-- Written WITHOUT commas on purpose. The typeface has 42 glyphs and no
	-- comma; TodPromptCard.Sanitize would turn one into a space, which is
	-- correct but leaves the list reading oddly. A dash is a glyph we own.
	CoD.TodPromptCard.SetDetail( self,
		"TURNS ON POWER FOR THE TOWER",
		"PERKS - PACK-A-PUNCH - PADS" )

	-- The switch is free; no coin, no digits.
	CoD.TodPromptCard.SetPrice( self, nil )

	-- Re-resolve the bind on every hint update. The token expands for the
	-- device and the binds in force AT THE MOMENT THE LINE IS SET, so a card
	-- built once at HUD load would otherwise show its boot-time key all match.
	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" ), function ( model )
		local hintText = Engine.GetModelValue( model )
		if hintText and hintText ~= "" then
			CoD.TodPromptCard.SetFooter( self, "ACTIVATE" )
		end
	end )

	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end

	return self
end
