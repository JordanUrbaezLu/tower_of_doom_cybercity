-- Compiled using luac for Black Ops III

CoD.PromptPAP = InheritFrom( LUI.UIElement )

function CoD.PromptPAP.new( menu, controller )
	local self = LUI.UIElement.new()
	
	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end
	
	self:setUseStencil( false )
	self:setClass( CoD.PromptPAP )
	self.id = "PromptPAP"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	
	-- image_3a5dcba7b0d44850 (decorative border top)
	self.borderTop = LUI.UIImage.new()
	self.borderTop:setLeftRight(true, false, 616, 772)
	self.borderTop:setTopBottom(true, false, 460, 518)
	self.borderTop:setImage(RegisterImage("i_mtl_image_3a5dcba7b0d44850"))
	self.borderTop:setRGB(1, 1, 1)
	self:addElement(self.borderTop)
	
	-- image_4b19966fe6b8a3f4 (decorative border header)
	self.borderHeader = LUI.UIImage.new()
	self.borderHeader:setLeftRight(true, false, 615, 773)
	self.borderHeader:setTopBottom(true, false, 446, 461)
	self.borderHeader:setImage(RegisterImage("i_mtl_image_4b19966fe6b8a3f4"))
	self.borderHeader:setRGB(1, 1, 1)
	self:addElement(self.borderHeader)
	
	-- packapunch_text (title)
	self.titleText = LUI.UIText.new()
	self.titleText:setLeftRight(true, false, 620, 754)
	self.titleText:setTopBottom(true, false, 449, 459)
	self.titleText:setText("Pack-a-Punch")
	self.titleText:setTTF("fonts/orbitron.ttf")
	self.titleText:setRGB(1, 1, 1)
	self.titleText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.titleText)
	
	-- image_6bac5ab6cef2cf7d (decorative border right)
	self.borderRight = LUI.UIImage.new()
	self.borderRight:setLeftRight(true, false, 618, 775)
	self.borderRight:setTopBottom(true, false, 449, 517)
	self.borderRight:setImage(RegisterImage("i_mtl_image_6bac5ab6cef2cf7d"))
	self.borderRight:setRGB(1, 1, 1)
	self:addElement(self.borderRight)

	-- pap_description (dynamic - weapon upgrade info)
	self.papDescription = LUI.UIText.new()
	self.papDescription:setLeftRight(true, false, 620, 766)
	self.papDescription:setTopBottom(true, false, 467, 474)
	self.papDescription:setText("Upgrade your weapon")
	self.papDescription:setTTF("fonts/ltromatic.ttf")
	self.papDescription:setRGB(1, 1, 1)
	self.papDescription:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.papDescription)
	
	-- image_7d9423641070f37e (decorative border left)
	self.borderLeft = LUI.UIImage.new()
	self.borderLeft:setLeftRight(true, false, 546, 615)
	self.borderLeft:setTopBottom(true, false, 445, 518)
	self.borderLeft:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
	self.borderLeft:setRGB(1, 1, 1)
	self:addElement(self.borderLeft)
	
	-- image_8a21f7a0f930d3f (decorative border outer)
	self.borderOuter = LUI.UIImage.new()
	self.borderOuter:setLeftRight(true, false, 544, 775)
	self.borderOuter:setTopBottom(true, false, 444, 520)
	self.borderOuter:setImage(RegisterImage("i_mtl_image_8a21f7a0f930d3f"))
	self.borderOuter:setRGB(1, 1, 1)
	self:addElement(self.borderOuter)
	
	-- pap_cost (dynamic - upgrade cost)
	self.papCost = LUI.UIText.new()
	self.papCost:setLeftRight(true, false, 740, 773)
	self.papCost:setTopBottom(true, false, 506, 515)
	self.papCost:setText("5000")
	self.papCost:setTTF("fonts/ltromatic.ttf")
	self.papCost:setRGB(0.8941176470588236, 0.8823529411764706, 0.4235294117647059)
	self.papCost:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.papCost)
	
	-- footer_text_1
	self.footerText = LUI.UIText.new()
	self.footerText:setLeftRight(true, false, 620, 642)
	self.footerText:setTopBottom(true, false, 507, 514)
	self.footerText:setText("Hold ")
	self.footerText:setTTF("fonts/ltromatic.ttf")
	self.footerText:setRGB(1, 1, 1)
	self.footerText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.footerText)
	
	-- ui_icons_zombie_essence (points icon)
	self.pointsIcon = LUI.UIImage.new()
	self.pointsIcon:setLeftRight(true, false, 727, 742)
	self.pointsIcon:setTopBottom(true, false, 503, 515)
	self.pointsIcon:setImage(RegisterImage("i_mtl_ui_icons_zombie_essence"))
	self.pointsIcon:setRGB(1, 1, 1)
	self:addElement(self.pointsIcon)
	
	-- pap_icon_image (PAP or weapon icon)
	self.papIcon = LUI.UIImage.new()
	self.papIcon:setLeftRight(true, false, 562, 599)
	self.papIcon:setTopBottom(true, false, 463, 500)
	self.papIcon:setImage(RegisterImage("i_mtl_ui_icon_zm_ping_pack_a_punch"))
	self.papIcon:setRGB(1, 1, 1)
	self:addElement(self.papIcon)
	
	-- interact_text_button
	self.interactButton = LUI.UIText.new()
	self.interactButton:setLeftRight(true, false, 643, 652)
	self.interactButton:setTopBottom(true, false, 507, 514)
	self.interactButton:setText("F")
	self.interactButton:setTTF("fonts/ltromatic.ttf")
	self.interactButton:setRGB(0.792156862745098, 0.7803921568627451, 0.3803921568627451)
	self.interactButton:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.interactButton)
	
	-- footer_text_2
	self.footerText2 = LUI.UIText.new()
	self.footerText2:setLeftRight(true, false, 650, 704)
	self.footerText2:setTopBottom(true, false, 507, 515)
	self.footerText2:setText("To Upgrade")
	self.footerText2:setTTF("fonts/ltromatic.ttf")
	self.footerText2:setRGB(1, 1, 1)
	self.footerText2:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.footerText2)
	
	-- Start hidden
	self:setAlpha(0)
	
	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end
	
	return self
end

-- Helper function to set pack vs re-pack mode
function CoD.PromptPAP.SetMode( self, isRepack )
	if isRepack then
		-- Re-pack mode
		if self.titleText then
			self.titleText:setText( "Re-Pack" )
		end
		if self.papDescription then
			self.papDescription:setText( "Add Alternate Ammo Type" )
		end
		if self.papCost then
			self.papCost:setText( "2500" )
		end
		if self.footerText2 then
			self.footerText2:setText( "to re-pack" )
		end
	else
		-- Pack-a-Punch mode
		if self.titleText then
			self.titleText:setText( "Pack-a-Punch" )
		end
		if self.papDescription then
			self.papDescription:setText( "Upgrade your weapon" )
		end
		if self.papCost then
			self.papCost:setText( "5000" )
		end
		if self.footerText2 then
			self.footerText2:setText( "To Upgrade" )
		end
	end
end

return CoD.PromptPAP
