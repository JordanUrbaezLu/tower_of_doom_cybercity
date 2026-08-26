-- Aetherium Loadout Widget (Bottom Right - Weapon/Ammo Display)
-- Uses: i_mtl_ui_hud_loadout_theme_aetherium

require( "ui.uieditor.widgets.HUD.Mappings.AetheriumWeapons" )  -- For CoD.AetheriumWeaponData table
require( "ui.uieditor.widgets.HUD.Mappings.AetheriumAAT" )  -- For CoD.AetheriumAAT mappings
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPerksContainer" )  -- Perks widget

-- Helper function to get weapon data by display name OR codename
function CoD.GetWeaponDataByName(weaponName)
	if not weaponName or weaponName == "" then
		return CoD.AetheriumWeaponData["default"] or {
			icon = "i_mtl_ui_icon_zm_ping_mystery_box",
			description = ""
		}
	end
	
	-- Safety check: ensure CoD.AetheriumWeaponData exists
	if not CoD.AetheriumWeaponData then
		return {
			icon = "i_mtl_ui_icon_zm_ping_mystery_box",
			description = ""
		}
	end
	
	local lowerName = string.lower(weaponName)
	local normalizedName = lowerName:gsub("%s+", "")  -- Remove all spaces for comparison
	
	-- Try exact codename match first
	if CoD.AetheriumWeaponData[weaponName] then
		return CoD.AetheriumWeaponData[weaponName]
	end
	
	-- Try matching against ingame_name field (case-insensitive search with space normalization)
	for weaponKey, weaponInfo in pairs(CoD.AetheriumWeaponData) do
		if weaponInfo.ingame_name then
			local lowerIngameName = string.lower(weaponInfo.ingame_name)
			local normalizedIngameName = lowerIngameName:gsub("%s+", "")  -- Remove spaces for comparison
			
			-- Check if normalized names match
			if normalizedName == normalizedIngameName then
				return weaponInfo
			end
			
			-- Also check if the hint text contains the ingame name (original behavior)
			if string.find(lowerName, lowerIngameName, 1, true) then
				return weaponInfo
			end
		end
	end
	
	-- Try partial codename match (for cases like "sat_ar_hawk_zm" finding "sat_ar_hawk")
	for weaponKey, weaponInfo in pairs(CoD.AetheriumWeaponData) do
		local lowerKey = string.lower(weaponKey)
		if string.find(lowerName, lowerKey, 1, true) then
			return weaponInfo
		end
	end
	
	-- Fallback to default
	return CoD.AetheriumWeaponData["default"] or {
		icon = "i_mtl_ui_icon_zm_ping_mystery_box",
		description = ""
	}
end

-- Weapon icon helper function (for loadout display)
local function GetWeaponIcon( weaponName )
	if not weaponName or weaponName == "" then
		return "blacktransparent"
	end
	
	-- Safety check: ensure CoD.AetheriumWeaponData exists
	if not CoD.AetheriumWeaponData then
		return "blacktransparent"
	end
	
	-- Remove common prefixes/suffixes for cleaner lookup
	local cleanWeapon = weaponName:gsub("_upgraded", ""):gsub("_upg", ""):gsub("_zm", "")
	
	-- Check for exact match first
	if CoD.AetheriumWeaponData[cleanWeapon] and CoD.AetheriumWeaponData[cleanWeapon].icon then
		return CoD.AetheriumWeaponData[cleanWeapon].icon
	end
	
	-- Try stripping _up suffix as fallback
	local baseWeapon = cleanWeapon:gsub("_up", "")
	if CoD.AetheriumWeaponData[baseWeapon] and CoD.AetheriumWeaponData[baseWeapon].icon then
		return CoD.AetheriumWeaponData[baseWeapon].icon
	end
	
	-- Final fallback: return default icon or blacktransparent
	if CoD.AetheriumWeaponData["default"] and CoD.AetheriumWeaponData["default"].icon then
		return CoD.AetheriumWeaponData["default"].icon
	end
	
	return "blacktransparent"
end

CoD.AetheriumLoadout = InheritFrom( LUI.UIElement )
CoD.AetheriumLoadout.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumLoadout )
	self.id = "AetheriumLoadout"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self.anyChildUsesUpdateState = true

	-- Loadout Background (elem10)
	self.loadout = LUI.UIImage.new()
	self.loadout:setLeftRight(true, false, 885, 1312)
	self.loadout:setTopBottom(true, false, 512, 720)
	self.loadout:setImage( RegisterImage( "i_mtl_ui_hud_loadout_theme_aetherium" ) )
	self.loadout:setRGB( 1.000, 1.000, 1.000 )
	self.loadout:setAlpha( 1.0 )
	self:addElement( self.loadout )

	-- Weapon Icon (elem17)
	self.weapon_icon = LUI.UIImage.new()
	self.weapon_icon:setLeftRight(true, false, 1055, 1165)
	self.weapon_icon:setTopBottom(true, false, 599, 664)
	self.weapon_icon:setImage( RegisterImage( "blacktransparent" ) )
	self.weapon_icon:setRGB( 1.000, 1.000, 1.000 )
	self.weapon_icon:setAlpha( 1.0 )
	self:addElement( self.weapon_icon )
	
	-- Track previous weapon for swap detection
	local previousWeaponName = ""
	
	-- Weapon swap animation clips
	self.weapon_icon.clipsPerState = {
		DefaultState = {
			DefaultClip = function()
				self.weapon_icon:completeAnimation()
				self.weapon_icon:setAlpha( 1 )
			end,
			WeaponSwap = function()
				self.weapon_icon:completeAnimation()
				
				-- Fade out + slide right
				self.weapon_icon:beginAnimation( "keyframe", 120, false, false, CoD.TweenType.Linear )
				self.weapon_icon:setAlpha( 0 )
				self.weapon_icon:setLeftRight( true, false, 1085, 1195 )  -- Shift right 30px
				
				self.weapon_icon:registerEventHandler( "transition_complete_keyframe", function()
					-- Fade in + slide from left
					self.weapon_icon:setLeftRight( true, false, 1025, 1135 )  -- Start left 30px
					self.weapon_icon:beginAnimation( "keyframe", 120, false, false, CoD.TweenType.Linear )
					self.weapon_icon:setAlpha( 1 )
					self.weapon_icon:setLeftRight( true, false, 1055, 1165 )  -- Back to center
				end )
			end
		}
	}
	
	-- Subscribe to weapon changes using viewmodelWeaponName
	self.weapon_icon:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "currentWeapon.viewmodelWeaponName" ), function ( model )
		local weaponName = Engine.GetModelValue( model )
		if weaponName then
			local weaponIcon = GetWeaponIcon( weaponName )
			
			-- Trigger swap animation if weapon changed (not initial load)
			if previousWeaponName ~= "" and previousWeaponName ~= weaponName then
				-- Play swap animation BEFORE changing icon
				self.weapon_icon:animateToState( "WeaponSwap" )
				
				-- Delay icon change to middle of animation (after fade out)
				-- [tod] STATE-POOL LEAK FIX (map 1's 2026-07-04 fix, regressed by the
				-- 2026-08-19 vendor; leak-hunt audit 2026-08-23, confirmed critical):
				-- never-closed repeating 130ms UITimer + a re-registered handler PER
				-- WEAPON-NAME CHANGE (grenade throws toggle the weapon twice; this map's
				-- give-before-take PaP makes one ceremony several changes). One handle,
				-- close-old-before-create, close-inside-handler so it fires exactly once.
				if self.todIconSwapTimer then self.todIconSwapTimer:close() end
				self.todIconSwapTimer = LUI.UITimer.new( 130, "weapon_swap_icon_change" )
				self.weapon_icon:addElement( self.todIconSwapTimer )
				self.weapon_icon:registerEventHandler( "weapon_swap_icon_change", function()
					if self.todIconSwapTimer then self.todIconSwapTimer:close(); self.todIconSwapTimer = nil end
					self.weapon_icon:setImage( RegisterImage( weaponIcon ) )
				end )
			else
				-- Initial load - no animation
				self.weapon_icon:setImage( RegisterImage( weaponIcon ) )
			end
			
			-- Update previous weapon
			previousWeaponName = weaponName
			
			-- Check if it's equipment (grenade, cymbal_monkey, etc.)
			local isEquipment = weaponName:find("frag_grenade") or 
								weaponName:find("octobomb") or 
			                    weaponName:find("cymbal_monkey") or
			                    weaponName:find("sticky_grenade") or
			                    weaponName:find("_grenade") or
			                    weaponName:find("knife_") or
			                    weaponName:find("_knife")
			
			if isEquipment then
				-- Equipment position (centered, smaller)
				self.weapon_icon:setLeftRight(true, false, 1093, 1149)
				self.weapon_icon:setTopBottom(true, false, 601, 657)
			else
				-- Regular weapon position (larger)
				self.weapon_icon:setLeftRight(true, false, 1055, 1165)
				self.weapon_icon:setTopBottom(true, false, 599, 664)
			end
		end
	end )

	-- Weapon Name (elem31) - TEXT
	self.weapon_name = LUI.UIText.new()
	self.weapon_name:setLeftRight(true, false, 847, 1106)
	self.weapon_name:setTopBottom(true, false, 568, 585)
	self.weapon_name:setText( Engine.Localize( "" ) )
	self.weapon_name:setTTF( "fonts/orbitron.ttf" )
	self.weapon_name:setRGB( 1.0, 1.0, 1.0 )
	self.weapon_name:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
	self:addElement( self.weapon_name )
	
	-- Track previous weapon name
	local previousWeaponTextName = ""
	
	-- Weapon name swap animation
	self.weapon_name.clipsPerState = {
		DefaultState = {
			DefaultClip = function()
				self.weapon_name:completeAnimation()
				self.weapon_name:setAlpha( 1 )
			end,
			WeaponSwap = function()
				self.weapon_name:completeAnimation()
				
				-- Fade out
				self.weapon_name:beginAnimation( "keyframe", 100, false, false, CoD.TweenType.Linear )
				self.weapon_name:setAlpha( 0 )
				
				self.weapon_name:registerEventHandler( "transition_complete_keyframe", function()
					-- Fade in
					self.weapon_name:beginAnimation( "keyframe", 100, false, false, CoD.TweenType.Linear )
					self.weapon_name:setAlpha( 1 )
				end )
			end
		}
	}
	
	self.weapon_name:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "currentWeapon.weaponName" ), function ( model )
		local weaponName = Engine.GetModelValue( model )
		if weaponName then
			-- Trigger animation if name changed
			if previousWeaponTextName ~= "" and previousWeaponTextName ~= weaponName then
				self.weapon_name:animateToState( "WeaponSwap" )
				
				-- Change text in middle of animation
				-- [tod] STATE-POOL LEAK FIX — same never-closed per-change UITimer as the
				-- icon above; same one-handle close-old/close-inside shape.
				if self.todNameSwapTimer then self.todNameSwapTimer:close() end
				self.todNameSwapTimer = LUI.UITimer.new( 100, "weapon_name_text_change" )
				self.weapon_name:addElement( self.todNameSwapTimer )
				self.weapon_name:registerEventHandler( "weapon_name_text_change", function()
					if self.todNameSwapTimer then self.todNameSwapTimer:close(); self.todNameSwapTimer = nil end
					self.weapon_name:setText( Engine.Localize( weaponName ) )
				end )
			else
				-- Initial load
				self.weapon_name:setText( Engine.Localize( weaponName ) )
			end
			
			previousWeaponTextName = weaponName
		end
	end )

	-- Ammo Clip (elem24) - TEXT
	self.ammo_clip = LUI.UIText.new()
	self.ammo_clip:setLeftRight(true, false, 948, 1061)
	self.ammo_clip:setTopBottom(true, false, 605, 624)
	self.ammo_clip:setText( Engine.Localize( "0" ) )
	self.ammo_clip:setTTF( "fonts/ltromatic.ttf" )
	self.ammo_clip:setRGB( 1.0, 1.0, 1.0 )
	self.ammo_clip:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	self:addElement( self.ammo_clip )
	
	-- Low ammo warning animation timer
	local lowAmmoFlashing = false
	local lowAmmoTimer = nil
	
	self.ammo_clip:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "currentWeapon.ammoInClip" ), function ( model )
		local ammoInClip = Engine.GetModelValue( model )
		if ammoInClip then
			self.ammo_clip:setText( Engine.Localize( ammoInClip ) )
			
			-- Get max ammo in clip for percentage calculation
			local maxAmmoModel = Engine.GetModel( Engine.GetModelForController( controller ), "currentWeapon.maxAmmoInClip" )
			local maxAmmo = maxAmmoModel and Engine.GetModelValue( maxAmmoModel ) or 30
			
			-- Low ammo threshold: 25% of magazine or less
			local lowAmmoThreshold = math.max( 3, math.floor( maxAmmo * 0.25 ) )
			
			-- Check if ammo is low
			if ammoInClip > 0 and ammoInClip <= lowAmmoThreshold then
				-- Start low ammo flash if not already flashing
				if not lowAmmoFlashing then
					lowAmmoFlashing = true
					
					-- Pulsing red flash animation (official BO3 pattern)
					local function flashLowAmmo()
						self.ammo_clip:completeAnimation()
						self.ammo_clip:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
						self.ammo_clip:setRGB( 1, 0, 0 )  -- Red
						self.ammo_clip:setAlpha( 1 )
						self.ammo_clip:registerEventHandler( "transition_complete_keyframe", function()
							if lowAmmoFlashing then
								self.ammo_clip:completeAnimation()
								self.ammo_clip:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
								self.ammo_clip:setRGB( 1, 1, 1 )  -- White
								self.ammo_clip:setAlpha( 0.6 )
								self.ammo_clip:registerEventHandler( "transition_complete_keyframe", function()
									if lowAmmoFlashing then
										flashLowAmmo()  -- Loop
									end
								end )
							end
						end )
					end
					
					flashLowAmmo()
				end
			else
				-- Stop flashing
				if lowAmmoFlashing then
					lowAmmoFlashing = false
					self.ammo_clip:completeAnimation()
					self.ammo_clip:setRGB( 1, 1, 1 )  -- Reset to white
					self.ammo_clip:setAlpha( 1 )
				end
			end
		end
	end )

	-- Ammo Stock (elem30) - TEXT
	self.ammo_stock = LUI.UIText.new()
	self.ammo_stock:setLeftRight(true, false, 968, 1057)
	self.ammo_stock:setTopBottom(true, false, 629, 638)
	self.ammo_stock:setText( Engine.Localize( "0" ) )
	self.ammo_stock:setTTF( "fonts/ltromatic.ttf" )
	self.ammo_stock:setRGB( 1.0, 1.0, 1.0 )
	self.ammo_stock:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	self:addElement( self.ammo_stock )
	self.ammo_stock:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "currentWeapon.ammoStock" ), function ( model )
		local ammoStock = Engine.GetModelValue( model )
		if ammoStock then
			self.ammo_stock:setText( Engine.Localize( ammoStock ) )
		end
	end )

	-- Perks Container (Dynamic - now centered at bottom)
	self.PerksContainer = CoD.AetheriumPerksContainer.new( menu, controller )
	self.PerksContainer:setLeftRight( true, true, 0, 0 )
	self.PerksContainer:setTopBottom( true, true, 0, 0 )
	self:addElement( self.PerksContainer )

	-- Lethal Equipment Background Container
	self.lethal_bg = LUI.UIImage.new()
	self.lethal_bg:setLeftRight( true, false, 1117, 1184 )
	self.lethal_bg:setTopBottom( true, false, 541, 600 )
	self.lethal_bg:setImage( RegisterImage( "i_mtl_ui_hud_leathal" ) )
	self.lethal_bg:setRGB( 1, 1, 1 )
	self:addElement( self.lethal_bg )

	-- Lethal Grenade Icon
	self.lethal_icon = LUI.UIImage.new()
	self.lethal_icon:setLeftRight( true, false, 1126, 1153 )
	self.lethal_icon:setTopBottom( true, false, 554, 577 )
	self.lethal_icon:setImage( RegisterImage( "i_mtl_sat_ui_icon_lethal_grenade_frag" ) )
	self.lethal_icon:setRGB( 1, 1, 1 )
	self:addElement( self.lethal_icon )

	-- Lethal Grenade Count
	self.lethal_count = LUI.UIText.new()
	self.lethal_count:setLeftRight( true, false, 1153, 1180 )
	self.lethal_count:setTopBottom( true, false, 567, 579 )
	self.lethal_count:setText( Engine.Localize( "+4" ) )
	self.lethal_count:setTTF( "fonts/orbitron.ttf" )
	self.lethal_count:setRGB( 1, 1, 1 )
	self.lethal_count:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.lethal_count )

	-- Subscribe to lethal equipment count
	self.lethal_count:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "currentPrimaryOffhand.primaryOffhandCount" ), function ( model )
		local count = Engine.GetModelValue( model )
		if count and count > 0 then
			-- Has grenades - show filled state
			self.lethal_bg:setImage( RegisterImage( "i_mtl_ui_hud_leathal" ) )
			self.lethal_icon:setLeftRight( true, false, 1126, 1153 )
			self.lethal_icon:setTopBottom( true, false, 554, 577 )
			self.lethal_icon:setImage( RegisterImage( "i_mtl_sat_ui_icon_lethal_grenade_frag" ) )
			self.lethal_count:setText( Engine.Localize( "+" .. count ) )
			self.lethal_count:setAlpha( 1 )
		else
			-- No grenades - show empty state with custom positioning
			self.lethal_bg:setImage( RegisterImage( "i_mtl_ui_hud_leathal_empty" ) )
			self.lethal_icon:setLeftRight( true, false, 1136, 1163 )
			self.lethal_icon:setTopBottom( true, false, 555, 578 )
			self.lethal_icon:setImage( RegisterImage( "i_mtl_sat_ui_icon_lethal_grenade_frag_empty" ) )
			self.lethal_count:setAlpha( 0 )
		end
	end )

	-- Tactical Equipment Background Container
	self.tactical_bg = LUI.UIImage.new()
	self.tactical_bg:setLeftRight( true, false, 1057, 1124 )
	self.tactical_bg:setTopBottom( true, false, 541, 600 )
	self.tactical_bg:setImage( RegisterImage( "i_mtl_ui_hud_tactical_empty" ) )
	self.tactical_bg:setRGB( 1, 1, 1 )
	self:addElement( self.tactical_bg )

	-- Tactical Equipment Icon (Dynamic based on equipment type)
	self.tactical_icon = LUI.UIImage.new()
	self.tactical_icon:setLeftRight( true, false, 1065, 1099 )
	self.tactical_icon:setTopBottom( true, false, 556, 585 )
	self.tactical_icon:setImage( RegisterImage( "blacktransparent" ) )
	self.tactical_icon:setRGB( 1, 1, 1 )
	self.tactical_icon:setAlpha( 0 )
	self:addElement( self.tactical_icon )

	-- Tactical Equipment Count
	self.tactical_count = LUI.UIText.new()
	self.tactical_count:setLeftRight( true, false, 1099, 1124 )
	self.tactical_count:setTopBottom( true, false, 565, 577 )
	self.tactical_count:setText( Engine.Localize( "+4" ) )
	self.tactical_count:setTTF( "fonts/orbitron.ttf" )
	self.tactical_count:setRGB( 1, 1, 1 )
	self.tactical_count:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self.tactical_count:setAlpha( 0 )
	self:addElement( self.tactical_count )

	-- Track tactical equipment state
	local hasEverHadTactical = false
	local currentTacticalIcon = ""
	local currentTacticalIconEmpty = ""
	
	-- Subscribe to tactical icon changes (official BO3 pattern)
	self.tactical_icon:subscribeToGlobalModel( controller, "CurrentSecondaryOffhand", "secondaryOffhand", function ( model )
		local iconPath = Engine.GetModelValue( model )
		if iconPath then
			-- Map vanilla icons to custom icons
			if iconPath == "uie_t7_zm_hud_inv_icntactlilarnie" then
				-- Li'l Arnie (Octobomb)
				currentTacticalIcon = "i_mtl_hud_octobomb"
				currentTacticalIconEmpty = "i_mtl_hud_octobomb_empty"
			else
				-- Cymbal Monkey or other
				currentTacticalIcon = "i_mtl_sat_ui_icon_zm_support_cymball_monkey"
				currentTacticalIconEmpty = "i_mtl_sat_ui_icon_zm_support_cymball_monkey_empty"
			end
			
			-- Update display with mapped icon
			local countModel = Engine.GetModel( Engine.GetModelForController( controller ), "currentSecondaryOffhand.secondaryOffhandCount" )
			local count = countModel and Engine.GetModelValue( countModel ) or 0
			
			if count and count > 0 then
				self.tactical_icon:setImage( RegisterImage( currentTacticalIcon ) )
			elseif hasEverHadTactical then
				self.tactical_icon:setImage( RegisterImage( currentTacticalIconEmpty ) )
			end
		end
	end )

	-- Subscribe to count changes
	self.tactical_count:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "currentSecondaryOffhand.secondaryOffhandCount" ), function ( model )
		local count = Engine.GetModelValue( model )
		
		if count and count > 0 then
			hasEverHadTactical = true
			self.tactical_bg:setImage( RegisterImage( "i_mtl_ui_hud_tactical" ) )
			self.tactical_icon:setLeftRight( true, false, 1065, 1099 )
			self.tactical_icon:setTopBottom( true, false, 556, 585 )
			-- Use stored mapped icon
			if currentTacticalIcon ~= "" then
				self.tactical_icon:setImage( RegisterImage( currentTacticalIcon ) )
			end
			self.tactical_icon:setAlpha( 1 )
			self.tactical_count:setText( Engine.Localize( "+" .. count ) )
			self.tactical_count:setAlpha( 1 )
		else
			self.tactical_bg:setImage( RegisterImage( "i_mtl_ui_hud_tactical_empty" ) )
			self.tactical_count:setAlpha( 0 )
			
			if hasEverHadTactical then
				self.tactical_icon:setLeftRight( true, false, 1077, 1111 )
				self.tactical_icon:setTopBottom( true, false, 549, 578 )
				-- Use stored empty icon
				if currentTacticalIconEmpty ~= "" then
					self.tactical_icon:setImage( RegisterImage( currentTacticalIconEmpty ) )
				end
				self.tactical_icon:setAlpha( 1 )
			else
				self.tactical_icon:setAlpha( 0 )
			end
		end
	end )

	-- Ammo Mod Icon (AAT - Alternate Ammo Type)
	self.ammo_mod_icon = LUI.UIImage.new()
	self.ammo_mod_icon:setLeftRight(true, false, 1037, 1061)
	self.ammo_mod_icon:setTopBottom(true, false, 641, 665)
	self.ammo_mod_icon:setImage(RegisterImage("blacktransparent"))
	self.ammo_mod_icon:setRGB(1, 1, 1)
	self.ammo_mod_icon:setAlpha(0)
	self:addElement(self.ammo_mod_icon)
	
	-- Subscribe to AAT changes (Ammo Mod system)
	-- Use currentWeapon.aatIcon model (no CSC needed!)
	self.ammo_mod_icon:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "currentWeapon.aatIcon"), function(model)
		local aatIcon = Engine.GetModelValue(model)
		
		if aatIcon and aatIcon ~= "" then
			local iconPath = CoD.GetAATIcon(aatIcon)
			self.ammo_mod_icon:setImage(RegisterImage(iconPath))
			self.ammo_mod_icon:setAlpha(1)
		else
			self.ammo_mod_icon:setAlpha(0)
		end
	end)

	-- Note: Hero weapon display now handled by official ZmAmmo_DpadMeterSword and ZmAmmo_DpadIconPistolFactory widgets
	-- These are added directly in AetheriumHud.lua for better compatibility and full feature support

	return self
end
