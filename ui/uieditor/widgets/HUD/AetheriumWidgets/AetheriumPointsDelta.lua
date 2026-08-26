-- Aetherium Points Delta Widget (Shows +50 or -150 when gaining/losing points)
-- Uses scriptNotify events (vanilla BO3 pattern - subscription in HUD file)

CoD.AetheriumPointsDelta = InheritFrom( LUI.UIElement )
CoD.AetheriumPointsDelta.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumPointsDelta )
	self.id = "AetheriumPointsDelta"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )

	-- Points Delta Text (hidden by default, shows on score_event)
	self.pointsText = LUI.UIText.new()
	self.pointsText:setLeftRight( true, false, 202, 282 )
	self.pointsText:setTopBottom( true, false, 677, 684 )
	self.pointsText:setText( Engine.Localize( "+50" ) )
	self.pointsText:setTTF( "fonts/ltromatic.ttf" )
	self.pointsText:setRGB( 0.9725, 0.9607, 0.4706 )  -- Yellow/gold for positive
	self.pointsText:setScale( 0.42 )
	self.pointsText:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self.pointsText:setAlpha( 0 )  -- Hidden by default
	self:addElement( self.pointsText )

	-- Function to show points popup (called from HUD file)
	self.ShowPointsPopup = function ( selfWidget, points )
		if points == 0 or points > 10000 then
			return
		end
		
		-- Set text with +/- prefix
		if points > 0 then
			selfWidget.pointsText:setText( "+" .. points )
			selfWidget.pointsText:setRGB( 0.9725, 0.9607, 0.4706 )  -- Yellow
		else
			selfWidget.pointsText:setText( tostring( points ) )
			selfWidget.pointsText:setRGB( 1, 0, 0 )  -- Red
		end
		
		-- Reset to start position
		selfWidget.pointsText:completeAnimation()
		selfWidget.pointsText:setLeftRight( true, false, 202, 282 )
		selfWidget.pointsText:setTopBottom( true, false, 677, 684 )
		selfWidget.pointsText:setAlpha( 0 )
		
		-- Animate: fade in + move up + fade out
		selfWidget.pointsText:beginAnimation( "fadeIn", 100, false, false, CoD.TweenType.Linear )
		selfWidget.pointsText:setAlpha( 1 )
		
		selfWidget.pointsText:beginAnimation( "moveUp", 750, false, true, CoD.TweenType.Linear )
		selfWidget.pointsText:setLeftRight( true, false, 202, 282 )
		selfWidget.pointsText:setTopBottom( true, false, 640, 648 )  -- Move up ~40px
		
		selfWidget.pointsText:beginAnimation( "fadeOut", 500, false, false, CoD.TweenType.Linear )
		selfWidget.pointsText:setAlpha( 0 )
	end

	LUI.OverrideFunction_CallOriginalSecond( self, "close", function ( element )
		element.pointsText:close()
	end )
	
	return self
end
