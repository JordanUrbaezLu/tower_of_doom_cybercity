-- Aetherium Menu Button Widget

CoD.AetheriumMenuButton = InheritFrom(LUI.UIElement)
CoD.AetheriumMenuButton.new = function(menu, controller)
	local self = LUI.UIElement.new()

	self:setClass(CoD.AetheriumMenuButton)
	self.id = "AetheriumMenuButton"
	self.soundSet = "default"
	self:setLeftRight(true, false, 0, 342)
	self:setTopBottom(true, false, 0, 38)
	self:makeFocusable()
	self:setHandleMouse(true)
	self.anyChildUsesUpdateState = true

	-- Button background image
	self.ButtonBG = LUI.UIImage.new()
	self.ButtonBG:setLeftRight(true, true, 0, 0)
	self.ButtonBG:setTopBottom(true, true, 0, 0)
	self.ButtonBG:setImage(RegisterImage("i_mtl_image_15f72351ec912f8b"))
	self:addElement(self.ButtonBG)

	-- Hover image (shown on focus)
	self.ButtonHover = LUI.UIImage.new()
	self.ButtonHover:setLeftRight(true, false, -23, 379)
	self.ButtonHover:setTopBottom(true, false, -20, 59)
	self.ButtonHover:setImage(RegisterImage("i_mtl_image_25c963d7d5adbec3"))
	self.ButtonHover:setAlpha(0)
	self:addElement(self.ButtonHover)

	-- Button text
	self.ButtonText = LUI.UIText.new()
	self.ButtonText:setLeftRight(true, false, 34, 300)
	self.ButtonText:setTopBottom(true, false, 14, 25)
	self.ButtonText:setTTF("fonts/orbitron.ttf")
	self.ButtonText:setLetterSpacing(1)
	self.ButtonText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self.ButtonText:setRGB(1, 1, 1)
	self.ButtonText:linkToElementModel(self, "displayText", true, function(model)
		local displayText = Engine.GetModelValue(model)
		if displayText then
			self.ButtonText:setText(Engine.Localize(displayText))
		end
	end)
	self:addElement(self.ButtonText)

	-- Hover animations
	self.clipsPerState = {
		DefaultState = {
			DefaultClip = function()
				self:setupElementClipCounter(2)

				self.ButtonHover:completeAnimation()
				self.ButtonHover:setAlpha(0)
				self.clipFinished(self.ButtonHover, {})

				self.ButtonText:completeAnimation()
				self.ButtonText:setRGB(1, 1, 1)
				self.clipFinished(self.ButtonText, {})
			end,
			Focus = function()
				self:setupElementClipCounter(2)

				self.ButtonHover:completeAnimation()
				self.ButtonHover:setAlpha(1)
				self.clipFinished(self.ButtonHover, {})

				self.ButtonText:completeAnimation()
				self.ButtonText:setRGB(0.9, 0.7, 0)
				self.clipFinished(self.ButtonText, {})
			end
		}
	}

	LUI.OverrideFunction_CallOriginalSecond(self, "close", function(element)
		element.ButtonBG:close()
		element.ButtonHover:close()
		element.ButtonText:close()
	end)

	return self
end
