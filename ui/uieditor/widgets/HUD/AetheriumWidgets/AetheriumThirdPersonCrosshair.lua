-- Aetherium Third Person Crosshair

CoD.AetheriumThirdPersonCrosshair = InheritFrom(LUI.UIElement)
CoD.AetheriumThirdPersonCrosshair.new = function(menu, controller)
	local self = LUI.UIElement.new()
	
	self:setClass(CoD.AetheriumThirdPersonCrosshair)
	self.id = "AetheriumThirdPersonCrosshair"
	self:setLeftRight(true, true, 0, 0)
	self:setTopBottom(true, true, 0, 0)
	
	-- Crosshair image (centered)
	self.CrosshairImage = LUI.UIImage.new()
    self.CrosshairImage:setLeftRight(true, false, 608, 672)
    self.CrosshairImage:setTopBottom(true, false, 447, 515)
	self.CrosshairImage:setImage(RegisterImage("i_mtl_hud_reticle_06_h"))
	self.CrosshairImage:setAlpha(0)  -- Hidden by default
	self:addElement(self.CrosshairImage)
	
	-- Subscribe to third person model changes
	local thirdPersonModel = Engine.CreateModel(Engine.GetModelForController(controller), "ui_menu_option_third_person")
	self:subscribeToModel(thirdPersonModel, function(model)
		local isThirdPerson = Engine.GetModelValue(model)
		if isThirdPerson then
			self.CrosshairImage:setAlpha(1)  -- Show crosshair
		else
			self.CrosshairImage:setAlpha(0)  -- Hide crosshair
		end
	end)
	
	LUI.OverrideFunction_CallOriginalSecond(self, "close", function(element)
		element.CrosshairImage:close()
	end)
	
	return self
end
