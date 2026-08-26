-- Aetherium Round Counter Widget
-- Uses vanilla BO3 image-based round display, positioned top right

require( "ui.uieditor.widgets.HUD.ZM_RoundWidget.ZmRndContainer" )

CoD.AetheriumRoundCounter = InheritFrom( LUI.UIElement )
CoD.AetheriumRoundCounter.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumRoundCounter )
	self.id = "AetheriumRoundCounter"
	self.soundSet = "HUD"
	self:setLeftRight(true, false, 0, 1280)
	self:setTopBottom(true, false, 0, 720)
	-- Positioning handled by parent HUD
	self.anyChildUsesUpdateState = true

	-- Vanilla BO3 round widget (image-based digits with effects)
	self.Rounds = CoD.ZmRndContainer.new( menu, controller )
	self.Rounds:setLeftRight(false, true, -160, -50)  -- Anchor from right: 100px wide container, 50px from right edge
	self.Rounds:setTopBottom(true, false, 35, 115)    -- Top: 80px tall, 35px from top
	self.Rounds:setScale(0.8)
	self.Rounds:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_RIGHT)  -- Right-align content within container
	self:addElement( self.Rounds )

	-- Close handler
	LUI.OverrideFunction_CallOriginalSecond( self, "close", function ( element )
		element.Rounds:close()
	end )

	return self
end
