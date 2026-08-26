-- Wall Buy Prompt Widget
-- Displays weapon name, description, cost, and icon for wall weapon purchases

require( "ui.uieditor.widgets.HUD.Mappings.AetheriumWeapons" )  -- For weapon data lookup

CoD.PromptWallBuy = InheritFrom( LUI.UIElement )

function CoD.PromptWallBuy.new( menu, controller )
	local self = LUI.UIElement.new()
	
	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end
	
	self:setUseStencil( false )
	self:setClass( CoD.PromptWallBuy )
	self.id = "PromptWallBuy"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self:setAlpha( 0 )
	
	-- Background/Border Images
	
	-- image_3a5dcba7b0d44850 (top border)
	self.borderTop = LUI.UIImage.new()
	self.borderTop:setLeftRight(true, false, 616, 772)
	self.borderTop:setTopBottom(true, false, 460, 518)
	self.borderTop:setImage(RegisterImage("i_mtl_image_3a5dcba7b0d44850"))
	self.borderTop:setRGB(1, 1, 1)
	self:addElement(self.borderTop)
	
	-- image_4b19966fe6b8a3f4 (header border)
	self.borderHeader = LUI.UIImage.new()
	self.borderHeader:setLeftRight(true, false, 615, 773)
	self.borderHeader:setTopBottom(true, false, 446, 461)
	self.borderHeader:setImage(RegisterImage("i_mtl_image_4b19966fe6b8a3f4"))
	self.borderHeader:setRGB(1, 1, 1)
	self:addElement(self.borderHeader)
	
	-- image_6bac5ab6cef2cf7d (right border)
	self.borderRight = LUI.UIImage.new()
	self.borderRight:setLeftRight(true, false, 618, 775)
	self.borderRight:setTopBottom(true, false, 449, 517)
	self.borderRight:setImage(RegisterImage("i_mtl_image_6bac5ab6cef2cf7d"))
	self.borderRight:setRGB(1, 1, 1)
	self:addElement(self.borderRight)
	
	-- image_7d9423641070f37e (left border)
	self.borderLeft = LUI.UIImage.new()
	self.borderLeft:setLeftRight(true, false, 546, 615)
	self.borderLeft:setTopBottom(true, false, 445, 518)
	self.borderLeft:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
	self.borderLeft:setRGB(1, 1, 1)
	self:addElement(self.borderLeft)
	
	-- image_8a21f7a0f930d3f (outer border)
	self.borderOuter = LUI.UIImage.new()
	self.borderOuter:setLeftRight(true, false, 544, 775)
	self.borderOuter:setTopBottom(true, false, 444, 520)
	self.borderOuter:setImage(RegisterImage("i_mtl_image_8a21f7a0f930d3f"))
	self.borderOuter:setRGB(1, 1, 1)
	self:addElement(self.borderOuter)
	
	-- Weapon Icon (reactive to cursorHintImage)
	self.weaponIcon = LUI.UIImage.new()
	self.weaponIcon:setLeftRight(true, false, 550, 611)
	self.weaponIcon:setTopBottom(true, false, 464, 500)
	self.weaponIcon:setImage(RegisterImage("uie_t7_icon_inventory_blackcell_256"))  -- Fallback image
	self.weaponIcon:setRGB(1, 1, 1)
	self:addElement(self.weaponIcon)
	
	-- Weapon Name (reactive to cursorHintText)
	self.weaponName = LUI.UIText.new()
	self.weaponName:setLeftRight(true, false, 620, 754)
	self.weaponName:setTopBottom(true, false, 449, 459)
	self.weaponName:setText("Weapon Name")
	self.weaponName:setTTF("fonts/orbitron.ttf")
	self.weaponName:setRGB(1, 1, 1)
	self.weaponName:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.weaponName)
	
	-- Weapon Description (from AetheriumWeapons mapping)
	self.weaponDesc = LUI.UIText.new()
	self.weaponDesc:setLeftRight(true, false, 620, 767)
	self.weaponDesc:setTopBottom(true, false, 467, 474)
	self.weaponDesc:setText("Wall Weapon")
	self.weaponDesc:setTTF("fonts/ltromatic.ttf")
	self.weaponDesc:setRGB(1, 1, 1)
	self.weaponDesc:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self.weaponDesc:setScale(1)
	self:addElement(self.weaponDesc)
	
	-- Footer Text 1: "Hold "
	self.footerText1 = LUI.UIText.new()
	self.footerText1:setLeftRight(true, false, 620, 640)
	self.footerText1:setTopBottom(true, false, 507, 514)
	self.footerText1:setText("Hold ")
	self.footerText1:setTTF("fonts/ltromatic.ttf")
	self.footerText1:setRGB(1, 1, 1)
	self.footerText1:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.footerText1)
	
	-- Interact Button (reactive to button binding)
	self.interactButton = LUI.UIText.new()
	self.interactButton:setLeftRight(true, false, 643, 650)
	self.interactButton:setTopBottom(true, false, 507, 514)
	self.interactButton:setText("F")
	self.interactButton:setTTF("fonts/ltromatic.ttf")
	self.interactButton:setRGB(0.792156862745098, 0.7803921568627451, 0.3803921568627451)
	self.interactButton:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.interactButton)
	
	-- Footer Text 2: "To Buy"
	self.footerText2 = LUI.UIText.new()
	self.footerText2:setLeftRight(true, false, 650, 685)
	self.footerText2:setTopBottom(true, false, 507, 515)
	self.footerText2:setText("To Buy")
	self.footerText2:setTTF("fonts/ltromatic.ttf")
	self.footerText2:setRGB(1, 1, 1)
	self.footerText2:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.footerText2)
	
	-- Essence Icon
	self.essenceIcon = LUI.UIImage.new()
	self.essenceIcon:setLeftRight(true, false, 727, 742)
	self.essenceIcon:setTopBottom(true, false, 503, 515)
	self.essenceIcon:setImage(RegisterImage("i_mtl_ui_icons_zombie_essence"))
	self.essenceIcon:setRGB(1, 1, 1)
	self:addElement(self.essenceIcon)
	
	-- Weapon Price (reactive to cursorHintText)
	self.weaponPrice = LUI.UIText.new()
	self.weaponPrice:setLeftRight(true, false, 740, 773)
	self.weaponPrice:setTopBottom(true, false, 506, 515)
	self.weaponPrice:setText("5000")
	self.weaponPrice:setTTF("fonts/ltromatic.ttf")
	self.weaponPrice:setRGB(0.8941176470588236, 0.8823529411764706, 0.4235294117647059)
	self.weaponPrice:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.weaponPrice)
	
	-- REACTIVE BINDINGS - Update widget based on game state
	
	-- Update weapon name and price from cursorHintText model
	self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "hudItems.cursorHintText"), function(model)
		local hintText = Engine.GetModelValue(model)
		if hintText and hintText ~= "" then
			-- Extract weapon name (before "Cost:" or "[")
			local weaponName = hintText
			local costStart = string.find(hintText, "Cost:") or string.find(hintText, "%[")
			if costStart then
				weaponName = string.sub(hintText, 1, costStart - 1)
				-- Remove "Hold &&1 for " or "Hold F for " prefix
				weaponName = weaponName:gsub("Hold .+ for ", "")
				weaponName = weaponName:gsub("^%s*", ""):gsub("%s*$", "")  -- Trim whitespace
				weaponName = weaponName:gsub("%[", "")  -- Remove any [ character
			end
			
			self.weaponName:setText(weaponName)
			
			-- Extract cost
			local cost = "0"
			local costMatch = string.match(hintText, "Cost:%s*(%d+)") or 
			                  string.match(hintText, "%[Cost:%s*(%d+)%]") or
			                  string.match(hintText, "%[(%d+)%]")
			if costMatch then
				cost = costMatch
			end
			
			self.weaponPrice:setText(cost)
			
			-- Use weapon name to lookup weapon data (for icon and description)
			if CoD.GetWeaponDataByName then
				local weaponData = CoD.GetWeaponDataByName(weaponName)
				
				if weaponData then
					-- Update icon from weapon data
					if weaponData.icon and weaponData.icon ~= "" then
						self.weaponIcon:setImage(RegisterImage(weaponData.icon))
					end
					
					-- Update description from weapon data
					if weaponData.description and weaponData.description ~= "" then
						self.weaponDesc:setText(weaponData.description)
					end
				end
			end
		end
	end)
	
	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end
	
	return self
end
