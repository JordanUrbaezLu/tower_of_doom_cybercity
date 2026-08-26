-- AetheriumSpecialWeapon.lua
-- Hero weapon meter (Keeper Sword, Gauntlets, etc.)

CoD.AetheriumSpecialWeapon = InheritFrom(LUI.UIElement)

-- Helper function for circular meter shader adjustment
function AdjustStartEnd(newMin, newMax, vectorReturn1, vectorReturn2, vectorReturn3, vectorReturn4)
	return vectorReturn1 * (newMax - newMin) + newMin, vectorReturn2, vectorReturn3, vectorReturn4
end

CoD.AetheriumSpecialWeapon.new = function(menu, controller)
	local self = LUI.UIElement.new()
	
	self:setUseStencil(false)
	self:setClass(CoD.AetheriumSpecialWeapon)
	self.id = "AetheriumSpecialWeapon"
	self.soundSet = "HUD"
	self:setLeftRight(true, false, 0, 1280)
	self:setTopBottom(true, false, 0, 720)
	
	-- Background layer 1 (outer - darkest blue)
	self.element83 = LUI.UIImage.new()
	self.element83:setLeftRight(true, false, 1175, 1234)
	self.element83:setTopBottom(true, false, 594, 653)
	self.element83:setImage(RegisterImage("i_mtl_ximage_89bc9beef04fb63"))
	self.element83:setRGB(0.05, 0.04, 0.38)  -- #0d0b62
	self.element83:setAlpha(0)  -- Hidden by default
	self:addElement(self.element83)

	-- Background layer 2 (middle - medium blue)
	self.element84 = LUI.UIImage.new()
	self.element84:setLeftRight(true, false, 1175, 1234)
	self.element84:setTopBottom(true, false, 594, 653)
	self.element84:setImage(RegisterImage("i_mtl_ximage_89bc9beef04fb63"))
	self.element84:setRGB(0.09, 0.06, 0.61)  -- #17109b
	self.element84:setAlpha(0)  -- Hidden by default
	self:addElement(self.element84)

	-- Background layer 3 (inner - purple)
	self.element85 = LUI.UIImage.new()
	self.element85:setLeftRight(true, false, 1178, 1230)
	self.element85:setTopBottom(true, false, 599, 651)
	self.element85:setImage(RegisterImage("i_mtl_ximage_89bc9beef04fb63"))
	self.element85:setRGB(0.61, 0.18, 0.83)  -- #9b2ed4
	self.element85:setAlpha(0)  -- Hidden by default
	self:addElement(self.element85)

	-- Active/inactive icon
	self.element86 = LUI.UIImage.new()
	self.element86:setLeftRight(true, false, 1183, 1226)
	self.element86:setTopBottom(true, false, 602, 645)
	self.element86:setImage(RegisterImage("i_mtl_ragnarok_active"))
	self.element86:setRGB(1, 1, 1)
	self.element86:setAlpha(0)  -- Hidden by default
	-- Note: Added to widget after WaveEffect for proper layering

	-- Fill empty ring
	self.element87 = LUI.UIImage.new()
	self.element87:setLeftRight(true, false, 1175, 1234)
	self.element87:setTopBottom(true, false, 594, 653)
	self.element87:setImage(RegisterImage("i_mtl_ximage_c800fc9cce96f23"))
	self.element87:setRGB(1, 1, 1)
	self.element87:setAlpha(0)  -- Hidden by default
	self:addElement(self.element87)

	-- Fill progress (circular meter)
	self.element88 = LUI.UIImage.new()
	self.element88:setLeftRight(true, false, 1175, 1234)
	self.element88:setTopBottom(true, false, 594, 653)
	self.element88:setImage(RegisterImage("i_mtl_ximage_836c48038391c06"))
	self.element88:setMaterial(LUI.UIImage.GetCachedMaterial("uie_clock_normal"))
	self.element88:setRGB(0.35, 0.35, 0.75)  -- Lighter blue for better visibility
	self.element88:setAlpha(0)  -- Hidden by default
	self.element88:setZRot(180)
	self.element88:setShaderVector(0, 1, 0, 0, 0)  -- Start full
	self.element88:setShaderVector(1, 0.59, 0, 0, 0)  -- Center X
	self.element88:setShaderVector(2, 0.49, 0, 0, 0)  -- Center Y
	self.element88:setShaderVector(3, 0, 0, 0, 0)
	self:addElement(self.element88)

	-- Active background glow (when fully charged)
	self.element89 = LUI.UIImage.new()
	self.element89:setLeftRight(true, false, 1175, 1234)
	self.element89:setTopBottom(true, false, 594, 653)
	self.element89:setImage(RegisterImage(""))
	self.element89:setRGB(1, 1, 1)
	self.element89:setAlpha(0)  -- Hidden by default
	self:addElement(self.element89)

	-- Sparkle flipbook animation (plays when fully charged)
	self.WaveEffect = LUI.UIImage.new()
	self.WaveEffect:setLeftRight(true, false, 1175, 1234)
	self.WaveEffect:setTopBottom(true, false, 594, 653)
	self.WaveEffect:setImage(RegisterImage("i_vfx_dist_blast_wave_loop_1_c"))
	self.WaveEffect:setMaterial(LUI.UIImage.GetCachedMaterial("uie_flipbook_add"))
	self.WaveEffect:setShaderVector(0, 8, 8, 0, 0)  -- 8x8 grid
	self.WaveEffect:setShaderVector(1, 30, 0, 0, 0)  -- Start at frame 30
	self.WaveEffect:setRGB(1, 0.5, 1)  -- Brighter purple for better visibility
	self.WaveEffect:setAlpha(0)  -- Hidden by default
	self.WaveEffect:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "zmhud.swordState"), function(model)
		local swordState = Engine.GetModelValue(model)
		
		-- Show sparkle when weapon is active/being used (swordState > 1)
		-- Hide when inactive or just equipped
		if swordState and swordState > 1 then
			self.WaveEffect:setAlpha(1)  -- Show during active use
		else
			self.WaveEffect:setAlpha(0)  -- Hide when inactive
		end
	end)
	self:addElement(self.WaveEffect)
	
	-- Add icon after sparkle effect so it renders on top
	self:addElement(self.element86)
	
	-- Subscribe to swordState for visibility (0 = no weapon, 1+ = weapon equipped)
	self.element88:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "zmhud.swordState"), function(model)
		local swordState = Engine.GetModelValue(model)
		
		-- Only show widget when swordState > 0 (weapon is equipped)
		if swordState and swordState > 0 then
			-- Show all background layers and rings
			self.element83:setAlpha(1)
			self.element84:setAlpha(1)
			self.element85:setAlpha(1)
			self.element87:setAlpha(1)  -- Empty ring
			self.element88:setAlpha(1)  -- Progress meter
			self.element86:setAlpha(1)  -- Icon
			self.element89:setAlpha(1)  -- Active background glow
			
			-- Set icon based on active use state
			if swordState > 1 then
				-- Actively using weapon - show active icon
				self.element86:setImage(RegisterImage("t7_hud_mp_weapon_hero_gravityspikes_available"))
			else
				-- Weapon equipped but charging - show inactive icon
				self.element86:setImage(RegisterImage("t7_hud_mp_weapon_hero_gravityspikes_unavailable"))
			end
		else
			-- Hide everything - no weapon equipped (swordState = 0 or nil)
			self.element83:setAlpha(0)
			self.element84:setAlpha(0)
			self.element85:setAlpha(0)
			self.element86:setAlpha(0)
			self.element87:setAlpha(0)
			self.element88:setAlpha(0)
			self.element89:setAlpha(0)
			
			-- Set icon to inactive when weapon not equipped
			self.element86:setImage(RegisterImage("t7_hud_mp_weapon_hero_gravityspikes_unavailable"))
		end
	end)
	
	-- Subscribe to swordEnergy for progress updates and ready state
	self.element88:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "zmhud.swordEnergy"), function(model)
		local swordEnergy = Engine.GetModelValue(model)
		
		if swordEnergy then
			-- Extract vector components (value stored as vector4)
			local progress = CoD.GetVectorComponentFromString(swordEnergy, 1)
			local comp2 = CoD.GetVectorComponentFromString(swordEnergy, 2)
			local comp3 = CoD.GetVectorComponentFromString(swordEnergy, 3)
			local comp4 = CoD.GetVectorComponentFromString(swordEnergy, 4)
			
			if progress then
				-- Update circular progress (0 to 0.93 range like BO6)
				self.element88:setShaderVector(0, AdjustStartEnd(0, 0.93, progress, comp2, comp3, comp4))
			end
		end
	end)

	-- (duplicate addElement removed — element88 is already added above; audit 2026-08-19)

	LUI.OverrideFunction_CallOriginalSecond(self, "close", function(element)
		element.element83:close()
		element.element84:close()
		element.element85:close()
		element.element86:close()
		element.element87:close()
		element.element88:close()
		element.element89:close()
		element.WaveEffect:close()
	end)
	
	return self
end
