-- Perks Prompt Widget
-- Dynamically displays perk information based on cursor hint

-- Widget definition
CoD.PromptPerks = InheritFrom( LUI.UIElement )

function CoD.PromptPerks.new( menu, controller )
	local self = LUI.UIElement.new()
	
	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end
	
	self:setUseStencil( false )
	self:setClass( CoD.PromptPerks )
	self.id = "PromptPerks"
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
	
	-- Perk name text
	self.perkName = LUI.UIText.new()
	self.perkName:setLeftRight( true, false, 620, 754 )
	self.perkName:setTopBottom( true, false, 449, 459 )
	self.perkName:setText( Engine.Localize( "PERK NAME" ) )
	self.perkName:setTTF( "fonts/orbitron.ttf" )
	self.perkName:setRGB( 1, 1, 1 )
	self.perkName:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.perkName )
	
	-- Border/frame decoration 1
	self.border1 = LUI.UIImage.new()
	self.border1:setLeftRight( true, false, 618, 775 )
	self.border1:setTopBottom( true, false, 449, 517 )
	self.border1:setImage( RegisterImage( "i_mtl_image_6bac5ab6cef2cf7d" ) )
	self.border1:setRGB( 1, 1, 1 )
	self:addElement( self.border1 )

	-- Perk description text
	self.perkDesc = LUI.UIText.new()
	self.perkDesc:setLeftRight(true, false, 620, 766)
	self.perkDesc:setTopBottom(true, false, 467, 474)
	self.perkDesc:setText( Engine.Localize( "Perk description" ) )
	self.perkDesc:setTTF( "fonts/ltromatic.ttf" )
	self.perkDesc:setRGB( 1, 1, 1 )
	self.perkDesc:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.perkDesc )
	
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
	
	-- Perk cost text
	self.perkCost = LUI.UIText.new()
	self.perkCost:setLeftRight( true, false, 740, 773 )
	self.perkCost:setTopBottom( true, false, 506, 515 )
	self.perkCost:setText( Engine.Localize( "0" ) )
	self.perkCost:setTTF( "fonts/ltromatic.ttf" )
	self.perkCost:setRGB( 0.894, 0.882, 0.424 )  -- Gold/yellow color
	self.perkCost:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.perkCost )
	
	-- Footer text "Hold"
	self.footerText = LUI.UIText.new()
	self.footerText:setLeftRight( true, false, 620, 642 )
	self.footerText:setTopBottom( true, false, 507, 514 )
	self.footerText:setText( Engine.Localize( "Hold " ) )
	self.footerText:setTTF( "fonts/ltromatic.ttf" )
	self.footerText:setRGB( 1, 1, 1 )
	self.footerText:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.footerText )
	
	-- Interact button text (F key)
	self.interactButton = LUI.UIText.new()
	self.interactButton:setLeftRight( true, false, 643, 652 )
	self.interactButton:setTopBottom( true, false, 507, 514 )
	self.interactButton:setText( Engine.Localize( "F" ) )
	self.interactButton:setTTF( "fonts/ltromatic.ttf" )
	self.interactButton:setRGB( 0.792, 0.780, 0.380 )  -- Gold/yellow color
	self.interactButton:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.interactButton )
	
	-- Footer text 2 "to buy"
	self.footerText2 = LUI.UIText.new()
	self.footerText2:setLeftRight( true, false, 650, 704 )
	self.footerText2:setTopBottom( true, false, 507, 515 )
	self.footerText2:setText( Engine.Localize( "to buy" ) )
	self.footerText2:setTTF( "fonts/ltromatic.ttf" )
	self.footerText2:setRGB( 1, 1, 1 )
	self.footerText2:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.footerText2 )

	-- Points icon
	self.pointsIcon = LUI.UIImage.new()
	self.pointsIcon:setLeftRight( true, false, 727, 742 )
	self.pointsIcon:setTopBottom( true, false, 503, 515 )
	self.pointsIcon:setImage( RegisterImage( "i_mtl_ui_icons_zombie_essence" ) )
	self.pointsIcon:setRGB( 1, 1, 1 )
	self:addElement( self.pointsIcon )
	
	-- Perk icon
	self.perkIcon = LUI.UIImage.new()
	self.perkIcon:setLeftRight( true, false, 562, 599 )
	self.perkIcon:setTopBottom( true, false, 463, 500 )
	self.perkIcon:setImage( RegisterImage( "" ) )  -- Default icon
	self.perkIcon:setRGB( 1, 1, 1 )
	self:addElement( self.perkIcon )
	
	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end
	
	return self
end

-- Helper function to update perk info from CoD.AetheriumPerks table
-- This should be called from the parent widget when detecting a perk hint
function CoD.PromptPerks.UpdatePerkInfo( self, perkData )
	if not perkData then
		return
	end
	
	-- Update all perk fields
	if self.perkName and perkData.name then
		self.perkName:setText( Engine.Localize( perkData.name ) )
	end
	
	if self.perkDesc and perkData.description then
		self.perkDesc:setText( Engine.Localize( perkData.description ) )
	end
	
	-- [tod] SOLO PRICING (live test 2026-08-23: "solo quick revive should say 500
	-- not 1500"). Quick Revive is the one stock perk whose price depends on the
	-- party: 500 solo, 1500 in co-op. The table carried the co-op number only, so
	-- a solo player was quoted 3x what they were actually charged — the prompt and
	-- the till disagreed, which is the one thing a price display must never do.
	-- Any entry can now carry soloCost; only Quick Revive needs one today.
	-- Engine.GetPlayerCount() is the same call AetheriumStartMenu.lua:229 already
	-- uses for its solo check, so this adds no new engine surface.
	if self.perkCost and perkData.cost then
		local shownCost = perkData.cost
		if perkData.soloCost then
			local playerCount = Engine.GetPlayerCount()
			if playerCount and playerCount <= 1 then
				shownCost = perkData.soloCost
			end
		end
		self.perkCost:setText( Engine.Localize( tostring( shownCost ) ) )
	end
	
	if self.perkIcon and perkData.image then
		self.perkIcon:setImage( RegisterImage( perkData.image ) )
	end
end
