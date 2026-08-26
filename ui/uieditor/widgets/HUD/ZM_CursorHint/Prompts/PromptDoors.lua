-- Door/Debris Prompt Widget
-- Displays "Open Door" or "Clear Debris" prompts with cost

CoD.PromptDoors = InheritFrom( LUI.UIElement )

function CoD.PromptDoors.new( menu, controller )
	local self = LUI.UIElement.new()
	
	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end
	
	self:setUseStencil( false )
	self:setClass( CoD.PromptDoors )
	self.id = "PromptDoors"
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
	
	-- Title: "Locked Area"
	self.titleText = LUI.UIText.new()
	self.titleText:setLeftRight(true, false, 620, 754)
	self.titleText:setTopBottom(true, false, 449, 459)
	self.titleText:setText("Locked Area")
	self.titleText:setTTF("fonts/orbitron.ttf")
	self.titleText:setRGB(1, 1, 1)
	self.titleText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.titleText)
	
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
	
	-- Door Icon
	self.doorIcon = LUI.UIImage.new()
	self.doorIcon:setLeftRight(true, false, 559, 603)
	self.doorIcon:setTopBottom(true, false, 461, 505)
	self.doorIcon:setImage(RegisterImage("i_mtl_ui_icon_zm_ping_door_buy"))
	self.doorIcon:setRGB(1, 1, 1)
	self:addElement(self.doorIcon)
	
	-- Description: "Buy to unlock new areas" or "Clear debris to unlock new areas"
	self.descText = LUI.UIText.new()
	self.descText:setLeftRight(true, false, 620, 767)
	self.descText:setTopBottom(true, false, 467, 474)
	self.descText:setText("Buy to unlock new areas")
	self.descText:setTTF("fonts/ltromatic.ttf")
	self.descText:setRGB(1, 1, 1)
	self.descText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.descText)
	
	-- Price Text
	self.priceText = LUI.UIText.new()
	self.priceText:setLeftRight(true, false, 740, 773)
	self.priceText:setTopBottom(true, false, 506, 515)
	self.priceText:setText("5000")
	self.priceText:setTTF("fonts/ltromatic.ttf")
	self.priceText:setRGB(0.8941176470588236, 0.8823529411764706, 0.4235294117647059)
	self.priceText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.priceText)
	
	-- Footer Text 1: "Hold "
	self.footerText1 = LUI.UIText.new()
	self.footerText1:setLeftRight(true, false, 620, 640)
	self.footerText1:setTopBottom(true, false, 507, 514)
	self.footerText1:setText("Hold ")
	self.footerText1:setTTF("fonts/ltromatic.ttf")
	self.footerText1:setRGB(1, 1, 1)
	self.footerText1:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.footerText1)
	
	-- Essence Icon
	self.essenceIcon = LUI.UIImage.new()
	self.essenceIcon:setLeftRight(true, false, 727, 742)
	self.essenceIcon:setTopBottom(true, false, 503, 515)
	self.essenceIcon:setImage(RegisterImage("i_mtl_ui_icons_zombie_essence"))
	self.essenceIcon:setRGB(1, 1, 1)
	self:addElement(self.essenceIcon)
	
	-- Interact Button (reactive to button binding)
	self.interactButton = LUI.UIText.new()
	self.interactButton:setLeftRight(true, false, 643, 650)
	self.interactButton:setTopBottom(true, false, 507, 514)
	self.interactButton:setText("F")
	self.interactButton:setTTF("fonts/ltromatic.ttf")
	self.interactButton:setRGB(0.792156862745098, 0.7803921568627451, 0.3803921568627451)
	self.interactButton:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.interactButton)
	
	-- Footer Text 2: "To Buy" or "To Open"
	self.footerText2 = LUI.UIText.new()
	self.footerText2:setLeftRight(true, false, 650, 690)
	self.footerText2:setTopBottom(true, false, 507, 515)
	self.footerText2:setText("To Buy")
	self.footerText2:setTTF("fonts/ltromatic.ttf")
	self.footerText2:setRGB(1, 1, 1)
	self.footerText2:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.footerText2)
	
	-- REACTIVE BINDINGS - Update widget based on hint text
	
	-- Update text and price from cursorHintText model
	self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "hudItems.cursorHintText"), function(model)
		local hintText = Engine.GetModelValue(model)
		if hintText and hintText ~= "" then
			-- Determine if it's a door or debris
			local isDebris = string.find(string.lower(hintText), "debris") or string.find(string.lower(hintText), "clear")
			local isDoor = string.find(string.lower(hintText), "door") or string.find(string.lower(hintText), "open")
			
			-- Extract cost from hint text
			local cost = "0"
			local costMatch = string.match(hintText, "Cost:%s*(%d+)") or string.match(hintText, "%[Cost:%s*(%d+)%]")
			if costMatch then
				cost = costMatch
			end
			
			-- Update description and footer based on type
			if isDebris then
				self.descText:setText("Clear debris to unlock new areas")
				self.footerText2:setText("To Clear")
			elseif isDoor then
				self.descText:setText("Buy to unlock new areas")
				self.footerText2:setText("To Open")
			else
				-- Generic door/debris
				self.descText:setText("Buy to unlock new areas")
				self.footerText2:setText("To Buy")
			end
			
			-- Update price
			self.priceText:setText(cost)

			-- DESTINATION (audit 2026-08-25). Every one of this map's 53 doors
			-- rendered the hardcoded title "Locked Area", so the Floor 1 door and
			-- the Power Room door were byte-identical prompts. The destination is
			-- already in the hint -- _tod_doors.gsc builds "Open Door to <dest>
			-- [Cost: N]" and the generator authors a real name per door -- it was
			-- simply never read. Colour codes (^3, ^7...) are stripped first.
			local dest = string.match(hintText, "[Oo]pen [Dd]oor to%s+(.-)%s*%^%d*%[[Cc]ost")
			          or string.match(hintText, "[Oo]pen [Dd]oor to%s+(.-)%s*%[[Cc]ost")
			          or string.match(hintText, "[Oo]pen [Dd]oor to%s+(.+)")
			if dest then
				dest = string.gsub(dest, "%^%d", "")
				dest = string.gsub(dest, "^%s*(.-)%s*$", "%1")
				if dest ~= "" then
					self.titleText:setText(dest)
				end
			end
		end
	end)
	
	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end
	
	return self
end
