-- =============================================================================
-- PromptPowerRequired.lua — the refusal shown on a machine that has no power.
--
-- v19.3: REBUILT ON CoD.TodPromptCard, same as every other prompt card.
--
-- THIS CARD HAS NO FOOTER, DELIBERATELY. It is a refusal: there is nothing to
-- hold and nothing will happen. The kit's other cards all advertise a button,
-- and copying that here would tell the player to press something that does not
-- work. Build( { footer = false } ) is the one place that choice is expressed.
--
-- THE COPY WAS KIT FILLER. It read *"You must find and activate the power
-- first"* — grammatically fine, but it withholds the only thing the player
-- needs, which is WHERE. In this map the switch is at the bottom of the tower,
-- so the second line says so. (Read `Power switch at the BOTTOM` in CLAUDE.md;
-- if the switch ever moves, this line moves with it.)
-- =============================================================================

require( "ui.uieditor.widgets.HUD.ZM_CursorHint.Prompts.TodPromptCard" )

CoD.PromptPowerRequired = InheritFrom( LUI.UIElement )

function CoD.PromptPowerRequired.new( menu, controller )
	local self = LUI.UIElement.new()

	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end

	self:setUseStencil( false )
	self:setClass( CoD.PromptPowerRequired )
	self.id = "PromptPowerRequired"
	self.soundSet = "HUD"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self:setAlpha( 0 )  -- start hidden

	CoD.TodPromptCard.Build( self, {
		icon   = "i_tod_prompt_icon_power",
		footer = false,
	} )

	CoD.TodPromptCard.SetTitle( self, "POWER REQUIRED" )
	CoD.TodPromptCard.SetDetail( self,
		"TURN ON THE POWER FIRST",
		"THE SWITCH IS AT THE TOWER BASE" )
	CoD.TodPromptCard.SetPrice( self, nil )

	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end

	return self
end
