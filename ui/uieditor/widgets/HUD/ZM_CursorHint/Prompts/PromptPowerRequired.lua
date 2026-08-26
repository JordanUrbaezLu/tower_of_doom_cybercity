-- Power Required Prompt Widget
-- Displayed when player tries to interact with something that requires power

-- Widget definition
CoD.PromptPowerRequired = InheritFrom( LUI.UIElement )

function CoD.PromptPowerRequired.new( menu, controller )
	local self = LUI.UIElement.new()
	
	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end
	
	self:setUseStencil( false )
	self:setClass( CoD.PromptPowerRequired )
	self.id = "PromptPowerRequired"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self:setAlpha( 0 )  -- Start hidden, parent controls visibility
	
	-- Main background
	self.mainBG = LUI.UIImage.new()
	self.mainBG:setLeftRight( true, false, 616, 772 )
	self.mainBG:setTopBottom( true, false, 460, 518 )
	self.mainBG:setImage( RegisterImage( "i_mtl_image_3a5dcba7b0d44850" ) )
	self.mainBG:setRGB( 1, 1, 1 )
	self:addElement( self.mainBG )
	
	-- Header background
	self.headerBG = LUI.UIImage.new()
	self.headerBG:setLeftRight( true, false, 615, 773 )
	self.headerBG:setTopBottom( true, false, 446, 461 )
	self.headerBG:setImage( RegisterImage( "i_mtl_image_4b19966fe6b8a3f4" ) )
	self.headerBG:setRGB( 1, 1, 1 )
	self:addElement( self.headerBG )
	
	-- Title text
	self.titleText = LUI.UIText.new()
	self.titleText:setLeftRight( true, false, 620, 754 )
	self.titleText:setTopBottom( true, false, 449, 459 )
	self.titleText:setText( Engine.Localize( "Power Required" ) )
	self.titleText:setTTF( "fonts/orbitron.ttf" )
	self.titleText:setRGB( 1, 1, 1 )
	self.titleText:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.titleText )
	
	-- Border/frame decoration 1
	self.border1 = LUI.UIImage.new()
	self.border1:setLeftRight( true, false, 618, 775 )
	self.border1:setTopBottom( true, false, 449, 517 )
	self.border1:setImage( RegisterImage( "i_mtl_image_6bac5ab6cef2cf7d" ) )
	self.border1:setRGB( 1, 1, 1 )
	self:addElement( self.border1 )

	-- Description text
	self.descText = LUI.UIText.new()
	self.descText:setLeftRight(true, false, 620, 766)
	self.descText:setTopBottom(true, false, 467, 474)
	self.descText:setText( Engine.Localize( "You must find and activate the power first" ) )
	self.descText:setTTF( "fonts/ltromatic.ttf" )
	self.descText:setRGB( 1, 1, 1 )
	self.descText:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.descText )
	
	-- Border/frame decoration 2
	self.border2 = LUI.UIImage.new()
	self.border2:setLeftRight( true, false, 546, 615 )
	self.border2:setTopBottom( true, false, 445, 518 )
	self.border2:setImage( RegisterImage( "i_mtl_image_7d9423641070f37e" ) )
	self.border2:setRGB( 1, 1, 1 )
	self:addElement( self.border2 )
	
	-- Border/frame decoration 3
	self.border3 = LUI.UIImage.new()
	self.border3:setLeftRight( true, false, 544, 775 )
	self.border3:setTopBottom( true, false, 444, 520 )
	self.border3:setImage( RegisterImage( "i_mtl_image_8a21f7a0f930d3f" ) )
	self.border3:setRGB( 1, 1, 1 )
	self:addElement( self.border3 )
	
	-- Icon - Juggernaut (warning/power symbol)
	self.icon = LUI.UIImage.new()
	self.icon:setLeftRight( true, false, 562, 599 )
	self.icon:setTopBottom( true, false, 463, 500 )
	self.icon:setImage( RegisterImage( "i_mtl_sat_ui_icon_zm_power" ) )
	self.icon:setRGB( 1, 1, 1 )
	self:addElement( self.icon )
	
	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end
	
	return self
end
