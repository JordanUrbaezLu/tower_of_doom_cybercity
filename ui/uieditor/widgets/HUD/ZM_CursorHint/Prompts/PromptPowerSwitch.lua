-- Power Switch Prompt Widget
CoD.PromptPowerSwitch = InheritFrom( LUI.UIElement )

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
	self:setAlpha( 0 )  -- Start hidden
	
	-- image_3a5dcba7b0d44850
	self.bgMain = LUI.UIImage.new()
	self.bgMain:setLeftRight(true, false, 616, 772)
	self.bgMain:setTopBottom(true, false, 460, 518)
	self.bgMain:setImage(RegisterImage("i_mtl_image_3a5dcba7b0d44850"))
	self.bgMain:setRGB(1, 1, 1)
	self:addElement(self.bgMain)
	
	-- image_4b19966fe6b8a3f4
	self.bgHeader = LUI.UIImage.new()
	self.bgHeader:setLeftRight(true, false, 615, 773)
	self.bgHeader:setTopBottom(true, false, 446, 461)
	self.bgHeader:setImage(RegisterImage("i_mtl_image_4b19966fe6b8a3f4"))
	self.bgHeader:setRGB(1, 1, 1)
	self:addElement(self.bgHeader)
	
	-- TITLE
	self.titleText = LUI.UIText.new()
	self.titleText:setLeftRight(true, false, 620, 754)
	self.titleText:setTopBottom(true, false, 449, 459)
	self.titleText:setText(Engine.Localize("Power Switch"))
	self.titleText:setTTF("fonts/orbitron.ttf")
	self.titleText:setRGB(1, 1, 1)
	self.titleText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.titleText)
	
	-- footer_text_1
	self.holdText = LUI.UIText.new()
	self.holdText:setLeftRight(true, false, 621, 646)
	self.holdText:setTopBottom(true, false, 507, 514)
	self.holdText:setText(Engine.Localize("Hold "))
	self.holdText:setTTF("fonts/ltromatic.ttf")
	self.holdText:setRGB(1, 1, 1)
	self.holdText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.holdText)
	
	-- image_6bac5ab6cef2cf7d
	self.bgFrame = LUI.UIImage.new()
	self.bgFrame:setLeftRight(true, false, 618, 775)
	self.bgFrame:setTopBottom(true, false, 449, 517)
	self.bgFrame:setImage(RegisterImage("i_mtl_image_6bac5ab6cef2cf7d"))
	self.bgFrame:setRGB(1, 1, 1)
	self:addElement(self.bgFrame)

	-- Description
	self.description = LUI.UIText.new()
	self.description:setLeftRight(true, false, 620, 766)
	self.description:setTopBottom(true, false, 467, 474)
	self.description:setText(Engine.Localize("Powers various things around the map"))
	self.description:setTTF("fonts/ltromatic.ttf")
	self.description:setRGB(1, 1, 1)
	self.description:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.description)
	
	-- image_7d9423641070f37e
	self.bgIcon = LUI.UIImage.new()
	self.bgIcon:setLeftRight(true, false, 546, 615)
	self.bgIcon:setTopBottom(true, false, 445, 518)
	self.bgIcon:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
	self.bgIcon:setRGB(1, 1, 1)
	self:addElement(self.bgIcon)
	
	-- image_8a21f7a0f930d3f
	self.bgBorder = LUI.UIImage.new()
	self.bgBorder:setLeftRight(true, false, 544, 775)
	self.bgBorder:setTopBottom(true, false, 444, 520)
	self.bgBorder:setImage(RegisterImage("i_mtl_image_8a21f7a0f930d3f"))
	self.bgBorder:setRGB(1, 1, 1)
	self:addElement(self.bgBorder)
	
	-- sat_ui_icon_perks_zm_juggernaut (icon)
	self.itemIcon = LUI.UIImage.new()
	self.itemIcon:setLeftRight(true, false, 562, 599)
	self.itemIcon:setTopBottom(true, false, 463, 500)
	self.itemIcon:setImage(RegisterImage("i_mtl_sat_ui_icon_zm_power"))
	self.itemIcon:setRGB(1, 1, 1)
	self:addElement(self.itemIcon)
	
	-- interact_button
	self.keyText = LUI.UIText.new()
	self.keyText:setLeftRight(true, false, 644, 651)
	self.keyText:setTopBottom(true, false, 507, 514)
	self.keyText:setText(Engine.Localize("F"))
	self.keyText:setTTF("fonts/ltromatic.ttf")
	self.keyText:setRGB(0.8, 0.792156862745098, 0.3803921568627451)
	self.keyText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.keyText)
	
	-- footer_text_2
	self.actionText = LUI.UIText.new()
	self.actionText:setLeftRight(true, false, 651, 705)
	self.actionText:setTopBottom(true, false, 507, 514)
	self.actionText:setText(Engine.Localize("To Activate"))
	self.actionText:setTTF("fonts/ltromatic.ttf")
	self.actionText:setRGB(1, 1, 1)
	self.actionText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.actionText)
	
	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end
	
	return self
end
