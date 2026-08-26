-- Aetherium Small Menu Button Widget (for top buttons)

CoD.AetheriumSmallButton = InheritFrom(LUI.UIElement)
CoD.AetheriumSmallButton.new = function(menu, controller)
	local self = LUI.UIElement.new()

	self:setClass(CoD.AetheriumSmallButton)
	self.id = "AetheriumSmallButton"
	self.soundSet = "default"
	self:setLeftRight(true, false, 0, 63)
	self:setTopBottom(true, false, 0, 41)
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
	self.ButtonHover:setLeftRight(true, false, -6, 68)
	self.ButtonHover:setTopBottom(true, false, -21, 63)
	self.ButtonHover:setImage(RegisterImage("i_mtl_image_25c963d7d5adbec3"))
	self.ButtonHover:setAlpha(0)
	self:addElement(self.ButtonHover)

	-- Button icon
	self.ButtonIcon = LUI.UIImage.new()
	self.ButtonIcon:setLeftRight(true, false, 19, 45)
	self.ButtonIcon:setTopBottom(true, false, 7, 34)
	self.ButtonIcon:linkToElementModel(self, "icon", true, function(model)
		local iconPath = Engine.GetModelValue(model)
		if iconPath then
			self.ButtonIcon:setImage(RegisterImage(iconPath))
		end
	end)
	self:addElement(self.ButtonIcon)

	-- Hover animations
	self.clipsPerState = {
		DefaultState = {
			DefaultClip = function()
				self:setupElementClipCounter(1)

				self.ButtonHover:completeAnimation()
				self.ButtonHover:setAlpha(0)
				self.clipFinished(self.ButtonHover, {})
			end,
			Focus = function()
				self:setupElementClipCounter(1)

				self.ButtonHover:completeAnimation()
				self.ButtonHover:setAlpha(1)
				self.clipFinished(self.ButtonHover, {})
			end
		}
	}

	-- Mouse hover handlers
	self:registerEventHandler("mouseenter", function(element, event)
		element:processEvent({name = "gain_focus"})
		return false
	end)

	self:registerEventHandler("mouseleave", function(element, event)
		element:processEvent({name = "lose_focus"})
		return false
	end)

	LUI.OverrideFunction_CallOriginalSecond(self, "close", function(element)
		element.ButtonBG:close()
		element.ButtonHover:close()
		element.ButtonIcon:close()
	end)

	return self
end
