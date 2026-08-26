-- Individual kill feed entry widget
-- Displays kill type name and points earned

CoD.AetheriumKillFeedText = InheritFrom( LUI.UIElement )
CoD.AetheriumKillFeedText.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumKillFeedText )
	self.id = "AetheriumKillFeedText"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 136 )
	self:setTopBottom( true, false, 0, 11 )
	self.anyChildUsesUpdateState = true

	-- Points scored (left side, starting at 0)
	self.score = LUI.UIText.new()
	self.score:setLeftRight( true, false, 0, 32 )
	self.score:setTopBottom( true, false, 0, 11 )
	self.score:setTTF( "fonts/orbitron.ttf" )
	self.score:setRGB( 1, 1, 1 ) -- White
	self.score:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.score )

	-- Kill type name (right side, wide enough for long names like "Blast Furnace Kill")
	self.name = LUI.UIText.new()
	self.name:setLeftRight( true, false, 29, 200 )
	self.name:setTopBottom( true, false, 0, 11 )
	self.name:setTTF( "fonts/orbitron.ttf" )
	self.name:setRGB( 1, 1, 1 ) -- White
	self.name:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.name )

	LUI.OverrideFunction_CallOriginalSecond( self, "close", function ( element )
		element.score:close()
		element.name:close()
	end )
	
	return self
end

return CoD.AetheriumKillFeedText
