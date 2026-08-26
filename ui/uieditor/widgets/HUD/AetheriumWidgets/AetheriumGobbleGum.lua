-- Aetherium GobbleGum Inventory Widget
-- Displays the player's active gobblegum in the HUD

require("ui.uieditor.widgets.HUD.Mappings.AetheriumBBG")

CoD.AetheriumGobbleGum = InheritFrom(LUI.UIElement)

function CoD.AetheriumGobbleGum.new(menu, controller)
	local self = LUI.UIElement.new()
	
	if PreLoadFunc then
		PreLoadFunc(self, controller)
	end
	
	self:setUseStencil(false)
	self:setClass(CoD.AetheriumGobbleGum)
	self.id = "AetheriumGobbleGum"
	self.soundSet = "default"
	self:setLeftRight(true, false, 1216, 1280)
	self:setTopBottom(true, false, 312, 376)
	
	-- BBG_BACKGROUND (starts as empty/inactive)
	self.bbgBackground = LUI.UIImage.new()
	self.bbgBackground:setLeftRight(true, false, 0, 64)
	self.bbgBackground:setTopBottom(true, false, 0, 64)
	self.bbgBackground:setImage(RegisterImage("i_mtl_image_765101dd64f26a2b"))
	self.bbgBackground:setRGB(1, 1, 1)
	self:addElement(self.bbgBackground)
	
	-- Timer Ring (circular progress around icon)
	self.timerRing = LUI.UIImage.new()
	self.timerRing:setLeftRight(true, false, 6, 58)
	self.timerRing:setTopBottom(true, false, 6, 58)
	self.timerRing:setImage(RegisterImage("blacktransparent"))
	self.timerRing:setMaterial(LUI.UIImage.GetCachedMaterial("uie_clock_normal"))
	self.timerRing:setRGB(0, 1, 0.5) -- Cyan color
	self.timerRing:setShaderVector(1, 0.5, 0, 0, 0)
	self.timerRing:setShaderVector(2, 0.5, 0, 0, 0)
	self.timerRing:setShaderVector(3, 0.08, 0, 0, 0)
	self:addElement(self.timerRing)
	
	-- BBG_icon
	self.bbgIcon = LUI.UIImage.new()
	self.bbgIcon:setLeftRight(true, false, 12, 52)
	self.bbgIcon:setTopBottom(true, false, 12, 52)
	self.bbgIcon:setImage(RegisterImage("blacktransparent"))
	self.bbgIcon:setRGB(1, 1, 1)
	self.bbgIcon:setAlpha(0) -- Hidden by default (no gobblegum)
	self:addElement(self.bbgIcon)
	
	-- Setup model subscriptions
	self:setupGobbleGumModel(controller)
	
	if PostLoadFunc then
		PostLoadFunc(self, controller)
	end
	
	return self
end

function CoD.AetheriumGobbleGum:setupGobbleGumModel(controller)
	-- Track if gobblegum is currently active
	self.bgbActive = false
	self.currentGobbleGum = nil
	
	-- Subscribe to bgb_current to track which gobblegum is equipped
	local currentModel = Engine.GetModel(Engine.GetModelForController(controller), "bgb_current")
	if currentModel then
		self:subscribeToModel(currentModel, function(model)
			local currentItemIndex = Engine.GetModelValue(model)
			
			-- Only update if the gobblegum changed
			if currentItemIndex and currentItemIndex > 0 and currentItemIndex ~= self.currentGobbleGum then
				self.currentGobbleGum = currentItemIndex
				
				-- Update icon
				local iconPath = Engine.GetItemImage(currentItemIndex)
				if iconPath and self.bbgIcon then
					self.bbgIcon:setImage(RegisterImage(iconPath))
					self.bbgIcon:setAlpha(1)
				end
				if self.bbgBackground then
					self.bbgBackground:setImage(RegisterImage("i_mtl_image_13a4ae7c5608c7a5"))
					self.bbgBackground:setRGB(1, 1, 1)
				end
			elseif not currentItemIndex or currentItemIndex == 0 then
				-- Gobblegum cleared
				self.currentGobbleGum = nil
			end
		end)
	end
	
	-- Subscribe to zombie_bgb_notification (when gobblegum is PICKED UP from machine)
	-- This is how official BO3 tracks gobblegum pickup
	
	self:subscribeToGlobalModel(controller, "PerController", "scriptNotify", function(model)
		if IsParamModelEqualToString(model, "zombie_bgb_notification") then
			-- Notification received - this is for popup only, icon is handled by bgb_current
		elseif IsParamModelEqualToString(model, "zombie_bgb_used") then
			-- When gobblegum is USED/ACTIVATED
			local notifyData = CoD.GetScriptNotifyData(model)
		end
	end)
	
	-- Subscribe to bgb_display to know when gobblegum is active/inactive
	local displayModel = Engine.GetModel(Engine.GetModelForController(controller), "bgb_display")
	if displayModel then
		self:subscribeToModel(displayModel, function(model)
			local displayValue = Engine.GetModelValue(model)
			
			if displayValue and displayValue == 1 then
				self.bgbActive = true
			else
				self.bgbActive = false
				-- Hide everything when gobblegum is not displayed
				if self.timerRing then
					self.timerRing:setImage(RegisterImage("blacktransparent"))
				end
				if self.bbgIcon then
					self.bbgIcon:setAlpha(0)
				end
				if self.bbgBackground then
					self.bbgBackground:setImage(RegisterImage("i_mtl_image_765101dd64f26a2b"))
				end
			end
		end)
	end
	
	-- Subscribe to bgb_timer clientfield (vector value for circular timer)
	local timerModel = Engine.GetModel(Engine.GetModelForController(controller), "bgb_timer")
	if timerModel then
		self.timerRing:subscribeToModel(timerModel, function(model)
			local timerValue = Engine.GetModelValue(model)
			
			-- Only show timer if gobblegum is active AND timer has a value > 0
			if self.bgbActive and timerValue and timerValue > 0 then
				-- Show timer ring with official meter image
				self.timerRing:setImage(RegisterImage("uie_t7_zm_hud_ammo_bbgummeterring"))
				
				-- Update shader vector for circular progress
				self.timerRing:setShaderVector(0,
					CoD.GetVectorComponentFromString(timerValue, 1),
					CoD.GetVectorComponentFromString(timerValue, 2),
					CoD.GetVectorComponentFromString(timerValue, 3),
					CoD.GetVectorComponentFromString(timerValue, 4))
			else
				-- Hide timer ring when not active or timer is 0/nil
				if self.timerRing then
					self.timerRing:setImage(RegisterImage("blacktransparent"))
				end
			end
		end)
	end

end

return CoD.AetheriumGobbleGum
