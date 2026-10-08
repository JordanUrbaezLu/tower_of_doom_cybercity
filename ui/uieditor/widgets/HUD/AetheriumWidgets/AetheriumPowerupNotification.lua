require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodUIOwnership" )
-- Aetherium Power-up Notification Widget
-- Displays notification when power-ups are picked up

require("ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPowerupsContainer")

local PreLoadFunc = function(self, controller)
	-- Initialize notification queue
	self.notificationQueue = {}
	self.isShowingNotification = false
end

local PostLoadFunc = function(self, controller)
	-- Subscribe to zombie_notification for power-up pickup events
	self:subscribeToGlobalModel(controller, "PerController", "scriptNotify", function(model)
		if IsParamModelEqualToString(model, "zombie_notification") then
			local notifyData = CoD.GetScriptNotifyData(model)
			if notifyData and notifyData[1] then
				local notificationText = Engine.Localize(Engine.GetIString(notifyData[1], "CS_LOCALIZED_STRINGS"))
				
				-- Check if this is a power-up notification using CoD.PowerUps.ClientFieldNames
				for index = 1, #CoD.PowerUps.ClientFieldNames do
					local powerupData = CoD.PowerUps.ClientFieldNames[index]
					if notificationText:find(powerupData.name) then
						self:showPowerupNotification(powerupData.name:upper(), powerupData.image)
						break
					end
				end
			end
		end
	end)
end

CoD.AetheriumPowerupNotification = InheritFrom(LUI.UIElement)
CoD.AetheriumPowerupNotification.new = function(menu, controller)
	local self = LUI.UIElement.new()
    CoD.TodUIOwnership.Attach( self )
	
	if PreLoadFunc then
		PreLoadFunc(self, controller)
	end
	
	self:setUseStencil(false)
	self:setClass(CoD.AetheriumPowerupNotification)
	self.id = "AetheriumPowerupNotification"
	self.soundSet = "HUD"
	self:setLeftRight(true, false, 0, 1280)
	self:setTopBottom(true, false, 0, 720)
	
	-- Power-up background
	self.powerupBackground = LUI.UIImage.new()
	self.powerupBackground:setLeftRight(true, false, 555, 767)
	self.powerupBackground:setTopBottom(true, false, 512, 561)
	self.powerupBackground:setImage(RegisterImage("i_mtl_image_2ebe2f5764449435"))
	self.powerupBackground:setRGB(1, 1, 1)
	self.powerupBackground:setAlpha(0)  -- Hidden by default
	self:addElement(self.powerupBackground)
	
	-- Power-up icon
	self.powerupIcon = LUI.UIImage.new()
	self.powerupIcon:setLeftRight(true, false, 509, 575)
	self.powerupIcon:setTopBottom(true, false, 503, 570)
	self.powerupIcon:setImage(RegisterImage("blacktransparent"))
	self.powerupIcon:setRGB(1, 1, 1)
	self.powerupIcon:setAlpha(0)  -- Hidden by default
	self:addElement(self.powerupIcon)
	
	-- Power-up text. [tod v19.58] the map's typeface (drop-in for UIText; engine
	-- text only if the glyph widget is unavailable).
	local okLabel, label = false, nil
	if CoD.TodGlyphText and CoD.TodGlyphText.Label then
		okLabel, label = pcall(CoD.TodGlyphText.Label)
	end
	self.powerupText = (okLabel and label) or LUI.UIText.new()
	self.powerupText:setLeftRight(true, false, 574, 748)
	self.powerupText:setTopBottom(true, false, 525, 541)
	self.powerupText:setText(Engine.Localize(""))
	self.powerupText:setTTF("fonts/orbitron.ttf")
	self.powerupText:setRGB(1, 1, 1)
	self.powerupText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
	self.powerupText:setAlpha(0)  -- Hidden by default
	self:addElement(self.powerupText)
	
	-- Animation clips
	self.clipsPerState = {
		DefaultState = {
			DefaultClip = function()
				self:setupElementClipCounter(3)
				
				self.powerupBackground:completeAnimation()
				self.powerupBackground:setAlpha(0)
				self.powerupBackground:setLeftRight(true, false, 509, 575)  -- Start at icon position
				self.clipFinished(self.powerupBackground, {})
				
				self.powerupIcon:completeAnimation()
				self.powerupIcon:setAlpha(0)
				self.clipFinished(self.powerupIcon, {})
				
				self.powerupText:completeAnimation()
				self.powerupText:setAlpha(0)
				self.clipFinished(self.powerupText, {})
			end,
			ShowNotification = function()
				self:setupElementClipCounter(3)
				
				-- Icon animation (fade in first - 400ms, increased from 200ms)
				local iconFadeIn = function(element, event)
					if not event.interrupted then
						element:beginAnimation("fade_in", 400, false, false, CoD.TweenType.Linear)
					end
					element:setAlpha(1)
					if event.interrupted then
						self.clipFinished(element, event)
					else
						element:registerEventHandler("transition_complete_fade_in", self.clipFinished)
					end
				end
				
				-- Background animation (slide out from icon position - 700ms)
				local bgSlideOut = function(element, event)
					if not event.interrupted then
						element:beginAnimation("slide_out", 700, false, false, CoD.TweenType.Bounce)
					end
					element:setAlpha(1)
					element:setLeftRight(true, false, 555, 767)  -- Expand to full width
					if event.interrupted then
						self.clipFinished(element, event)
					else
						element:registerEventHandler("transition_complete_slide_out", self.clipFinished)
					end
				end
				
				-- Text animation (fade in after background - 400ms, increased from 200ms)
				local textFadeIn = function(element, event)
					if not event.interrupted then
						element:beginAnimation("fade_in", 400, false, false, CoD.TweenType.Linear)
					end
					element:setAlpha(1)
					if event.interrupted then
						self.clipFinished(element, event)
					else
						element:registerEventHandler("transition_complete_fade_in", self.clipFinished)
					end
				end
				
				-- Execute animations
				self.powerupIcon:completeAnimation()
				self.powerupIcon:setAlpha(0)
				iconFadeIn(self.powerupIcon, {})
				
				self.powerupBackground:completeAnimation()
				self.powerupBackground:setAlpha(0)
				self.powerupBackground:setLeftRight(true, false, 509, 575)  -- Start at icon
				bgSlideOut(self.powerupBackground, {})
				
				self.powerupText:completeAnimation()
				self.powerupText:setAlpha(0)
				textFadeIn(self.powerupText, {})
			end,
			HideNotification = function()
				self:setupElementClipCounter(3)
				
				-- Fade out all elements (300ms)
				local fadeOut = function(element, event)
					if not event.interrupted then
						element:beginAnimation("fade_out", 300, false, false, CoD.TweenType.Linear)
					end
					element:setAlpha(0)
					if event.interrupted then
						self.clipFinished(element, event)
					else
						element:registerEventHandler("transition_complete_fade_out", self.clipFinished)
					end
				end
				
				self.powerupBackground:completeAnimation()
				fadeOut(self.powerupBackground, {})
				
				self.powerupIcon:completeAnimation()
				fadeOut(self.powerupIcon, {})
				
				self.powerupText:completeAnimation()
				fadeOut(self.powerupText, {})
			end
		}
	}
	
	if PostLoadFunc then
		PostLoadFunc(self, controller)
	end
	

	-- =========================================================================
	return self
end

-- Show power-up notification with animation
function CoD.AetheriumPowerupNotification:showPowerupNotification(powerupName, powerupImage)
	if self.isShowingNotification then
		-- Queue notification if one is already showing
		table.insert(self.notificationQueue, {name = powerupName, image = powerupImage})
		return
	end
	
	self.isShowingNotification = true
	
	-- Set power-up data
	self.powerupText:setText(Engine.Localize(powerupName))
	self.powerupIcon:setImage(RegisterImage(powerupImage))
	
	-- Play show animation
	self:playClip("ShowNotification")
	
	-- Hold for 3 seconds (decreased from 5 seconds), then fade out
	-- [tod] STATE-POOL LEAK FIX (ported from map 1's 2026-07-04 fix; the tower
	-- vendored the pristine kit 2026-08-19 and REGRESSED it — leak-hunt audit
	-- 2026-08-23, confirmed critical). The kit created a NEW UITimer per pickup
	-- and NEVER closed it; LUI timers repeat until closed, so every Max Ammo
	-- left a live 3s timer whose handler re-played HideNotification AND minted
	-- another never-closed 300ms timer on every 3s fire — a COMPOUNDING cascade
	-- (map 1: "gradual frame decay" + a round-26 4p state-pool crash). Fix: one
	-- handle per timer role, close-before-create, close-inside-handler.
	if self.todHoldTimer then self.todHoldTimer:close() end
	self.todHoldTimer = LUI.UITimer.new(3000, "notification_hold", false)
	self:addElement(self.todHoldTimer)
	self:registerEventHandler("notification_hold", function()
		if self.todHoldTimer then self.todHoldTimer:close(); self.todHoldTimer = nil end
		-- Play hide animation
		self:playClip("HideNotification")
		
		-- Wait for animation to complete, then check queue
		if self.todCompleteTimer then self.todCompleteTimer:close() end
		self.todCompleteTimer = LUI.UITimer.new(300, "notification_complete", false)
		self:addElement(self.todCompleteTimer)
		self:registerEventHandler("notification_complete", function()
			if self.todCompleteTimer then self.todCompleteTimer:close(); self.todCompleteTimer = nil end
			self.isShowingNotification = false
			
			-- Show next notification if queued
			if #self.notificationQueue > 0 then
				local nextNotification = table.remove(self.notificationQueue, 1)
				self:showPowerupNotification(nextNotification.name, nextNotification.image)
			end
		end)
	end)
end

return CoD.AetheriumPowerupNotification
