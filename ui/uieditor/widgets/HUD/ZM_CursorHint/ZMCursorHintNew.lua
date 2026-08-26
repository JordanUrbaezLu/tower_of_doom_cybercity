-- Import prompt widgets
require( "ui.uieditor.widgets.HUD.ZM_CursorHint.Prompts.PromptPowerSwitch" )
require( "ui.uieditor.widgets.HUD.ZM_CursorHint.Prompts.PromptDefault" )
require( "ui.uieditor.widgets.HUD.ZM_CursorHint.Prompts.PromptPowerRequired" )
require( "ui.uieditor.widgets.HUD.ZM_CursorHint.Prompts.PromptPerks" )
require( "ui.uieditor.widgets.HUD.ZM_CursorHint.Prompts.PromptPAP" )
require( "ui.uieditor.widgets.HUD.ZM_CursorHint.Prompts.PromptMysteryBox" )
require( "ui.uieditor.widgets.HUD.ZM_CursorHint.Prompts.PromptBBG" )
require( "ui.uieditor.widgets.HUD.ZM_CursorHint.Prompts.PromptWallBuy" )
require( "ui.uieditor.widgets.HUD.ZM_CursorHint.Prompts.PromptDoors" )
require( "ui.uieditor.widgets.HUD.Mappings.AetheriumPerks" )  -- For CoD.AetheriumPerks table
require( "ui.uieditor.widgets.HUD.Mappings.AetheriumBBG" )  -- For CoD.AetheriumBBGData and helpers
require( "ui.uieditor.widgets.HUD.Mappings.AetheriumWeapons" )  -- For CoD.AetheriumWeaponData table

CoD.ZMCursorHintNew = InheritFrom( LUI.UIElement )

CoD.ZMCursorHintNew.new = function ( menu, controller )
	local self = LUI.UIElement.new()
	
	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end
	
	self:setUseStencil( false )
	self:setClass( CoD.ZMCursorHintNew )
	self.id = "ZMCursorHintNew"
	self.soundSet = "HUD"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self.anyChildUsesUpdateState = true
	
	-- Create Power Switch Prompt (custom)
	self.PromptPowerSwitch = CoD.PromptPowerSwitch.new( menu, controller )
	self.PromptPowerSwitch:setLeftRight( true, false, 0, 1280 )
	self.PromptPowerSwitch:setTopBottom( true, false, 0, 720 )
	self:addElement( self.PromptPowerSwitch )
	
	-- Create Default Prompt (fallback for everything else)
	self.promptDefault = CoD.PromptDefault.new( menu, controller )
	self.promptDefault:setLeftRight( true, false, 0, 1280 )
	self.promptDefault:setTopBottom( true, false, 0, 720 )
	self:addElement( self.promptDefault )
	
	-- Create Power Required Prompt (no power warning)
	self.PromptPowerRequired = CoD.PromptPowerRequired.new( menu, controller )
	self.PromptPowerRequired:setLeftRight( true, false, 0, 1280 )
	self.PromptPowerRequired:setTopBottom( true, false, 0, 720 )
	self:addElement( self.PromptPowerRequired )
	
	-- Create Perks Prompt (perk machines)
	self.promptPerks = CoD.PromptPerks.new( menu, controller )
	self.promptPerks:setLeftRight( true, false, 0, 1280 )
	self.promptPerks:setTopBottom( true, false, 0, 720 )
	self:addElement( self.promptPerks )
	
	-- Create PAP Prompt (Pack-a-Punch machine)
	self.promptPAP = CoD.PromptPAP.new( menu, controller )
	self.promptPAP:setLeftRight( true, false, 0, 1280 )
	self.promptPAP:setTopBottom( true, false, 0, 720 )
	self:addElement( self.promptPAP )
	
	-- Create Mystery Box Prompt (mystery box / weapon pickup)
	self.promptMysteryBox = CoD.PromptMysteryBox.new( menu, controller )
	self.promptMysteryBox:setLeftRight( true, false, 0, 1280 )
	self.promptMysteryBox:setTopBottom( true, false, 0, 720 )
	self:addElement( self.promptMysteryBox )
	
	-- Create GobbleGum Prompt (gobblegum machine)
	self.promptBBG = CoD.PromptBBG.new( menu, controller )
	self.promptBBG:setLeftRight( true, false, 0, 1280 )
	self.promptBBG:setTopBottom( true, false, 0, 720 )
	self:addElement( self.promptBBG )
	
	-- Create Wall Buy Prompt (wall weapon purchases)
	self.promptWallBuy = CoD.PromptWallBuy.new( menu, controller )
	self.promptWallBuy:setLeftRight( true, false, 0, 1280 )
	self.promptWallBuy:setTopBottom( true, false, 0, 720 )
	self:addElement( self.promptWallBuy )
	
	-- Create Doors Prompt (doors and debris)
	self.promptDoors = CoD.PromptDoors.new( menu, controller )
	self.promptDoors:setLeftRight( true, false, 0, 1280 )
	self.promptDoors:setTopBottom( true, false, 0, 720 )
	self:addElement( self.promptDoors )
	
	-- Helper function to check if cursor hint should be shown (official pattern)
	local function IsCursorHintActive()
		local showModel = Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.showCursorHint" )
		if showModel then
			local modelValue = Engine.GetModelValue( showModel )
			return modelValue == true
		end
		return false
	end
	
	-- Helper function to get cursorHintImage model value
	local function getCursorHintImage()
		local imageModel = Engine.GetModel(Engine.GetModelForController(controller), "hudItems.cursorHintImage")
		if imageModel then
			return Engine.GetModelValue(imageModel) or ""
		end
		return ""
	end
	
	-- Helper function to get cursorHintIconRatio model value
	local function getCursorHintIconRatio()
		local ratioModel = Engine.GetModel(Engine.GetModelForController(controller), "hudItems.cursorHintIconRatio")
		if ratioModel then
			return Engine.GetModelValue(ratioModel) or 0
		end
		return 0
	end
	
	-- Helper function to detect WALL BUY hints
	-- Actual format: "Hold F for weapon_name [Cost: 1400]"
	local function isWallBuyHint(hintText)
		if not hintText or hintText == "" then
			return false
		end
		
		local lowerHint = string.lower(hintText)
		local hasImage = getCursorHintImage() ~= ""
		
		-- Wall buy pattern: has "[Cost: number]" in the text
		local hasCostBracket = string.find(lowerHint, "%[cost:")
		
		-- Exclude mystery box (cost 950)
		-- 2026-08-25: the "950" arm was removed here too. It matched any cost
		-- CONTAINING 950 — the lap-21 door costs 1950 — and this map has no
		-- mystery box for it to ever match correctly.
		local isMysteryBox = string.find(lowerHint, "mystery")
		
		-- Exclude doors and debris (CRITICAL FIX)
		local isDoor = string.find(lowerHint, "door") or string.find(lowerHint, "open")
		local isDebris = string.find(lowerHint, "debris") or string.find(lowerHint, "clear") or string.find(lowerHint, "remove")
		
		local result = hasCostBracket and not isMysteryBox and not isDoor and not isDebris
		
		-- FIXED: Don't check iconRatio > 0, just check if image exists
		return hasImage and result
	end
	
	-- Helper function to check if hint is power switch
	local function isPowerSwitchHint(hintText)
		if not hintText or hintText == "" then
			return false
		end
		local lowerHint = string.lower(hintText)
		-- Exclude "you must turn on the power first" (that's PowerRequired)
		if string.find(lowerHint, "you must") then
			return false
		end
		return string.find(lowerHint, "turn on the power") or 
		       string.find(lowerHint, "activate power") or 
		       string.find(lowerHint, "activate the power")
	end
	
	-- Helper function to check if hint is power required warning
	local function isPowerRequiredHint(hintText)
		if not hintText or hintText == "" then
			return false
		end
		local lowerHint = string.lower(hintText)
		return string.find(lowerHint, "you must turn on the power first")
	end
	
	-- Helper function to detect and return perk data from hint
	local function getPerkFromHint(hintText)
		if not hintText or hintText == "" then
			return nil
		end
		
		local lowerHint = string.lower(hintText)
		
		-- Check if it's a perk prompt (Hold F for...)
		if not string.find(lowerHint, "hold") or not string.find(lowerHint, "for") then
			return nil
		end
		
		-- Loop through perks table and check for perk name matches
		for i = 1, #CoD.AetheriumPerks do
			local perkName = string.lower(CoD.AetheriumPerks[i].name)
			
			-- Check if hint contains any part of the perk name
			-- Split perk name by spaces/dashes and check each part
			if string.find(lowerHint, perkName) then
				return CoD.AetheriumPerks[i]
			end
			
			-- Also check for partial matches (e.g., "revive" in "QUICK REVIVE")
			for word in string.gmatch(perkName, "[^%s%-]+") do
				if string.len(word) > 3 and string.find(lowerHint, word) then
					return CoD.AetheriumPerks[i]
				end
			end
		end
		
		return nil
	end
	
	-- Helper function to detect Pack-a-Punch hints
	local function isPAPHint(hintText)
		if not hintText or hintText == "" then
			return false
		end
		
		local lowerHint = string.lower(hintText)
		
		-- Check for PAP-specific keywords (explicit boolean conversion)
		local hasPack = string.find(lowerHint, "pack") ~= nil
		local hasPunch = string.find(lowerHint, "punch") ~= nil
		local hasWeapon = string.find(lowerHint, "weapon") ~= nil
		local hasUpgrade = string.find(lowerHint, "upgrade") ~= nil
		
		-- Pack-a-Punch: "pack" + "punch"
		if hasPack and hasPunch then
			return true
		end
		
		-- Re-pack weapon: "pack" + "weapon"
		if hasPack and hasWeapon then
			return true
		end
		
		-- Upgrade weapon: "upgrade" + "weapon"
		if hasUpgrade and hasWeapon then
			return true
		end
		
		return false
	end
	
	-- Helper function to detect if it's re-pack (vs regular pack)
	local function isRepackHint(hintText)
		if not hintText or hintText == "" then
			return false
		end
		
		local lowerHint = string.lower(hintText)
		
		-- Check for re-pack specific text (multiple patterns)
		if string.find(lowerHint, "re%-pack") then
			return true
		end
		if string.find(lowerHint, "repack") then
			return true
		end
		-- Check for "2500" cost (re-pack cost)
		if string.find(lowerHint, "2500") then
			return true
		end
		
		return false
	end
	
	-- Helper function to detect Mystery Box hints
	local function isMysteryBoxHint(hintText)
		if not hintText or hintText == "" then
			return false
		end
		
		local lowerHint = string.lower(hintText)
		
		-- Check for mystery box keywords
		local hasMystery = string.find(lowerHint, "mystery") ~= nil
		local hasBox = string.find(lowerHint, "box") ~= nil
		
		if hasMystery and hasBox then
			return true
		end
		
		-- FALLBACK REMOVED (audit 2026-08-25). It was:
		--     if string.find(lowerHint, "950") then return true end
		-- a substring match for the stock mystery box 950 spin price, which also
		-- matches ANY hint whose cost merely CONTAINS "950". The lap-21 buyable
		-- door costs exactly 1950, so standing at it rendered the MYSTERY BOX card
		-- instead of a door card. This map ships NO mystery box (deliberately, see
		-- CLAUDE.md), so the heuristic had nothing correct to detect and could only
		-- misfire. The "mystery" + "box" keyword test above is the real check.
		
		return false
	end
	
	-- Helper function to detect GobbleGum machine hints
	-- Uses CoD.IsGobbleGumHint from AetheriumBBG mapping
	local function isGobbleGumHint(hintText)
		return CoD.IsGobbleGumHint(hintText)
	end
	
	-- Helper function to detect Door/Debris hints
	local function isDoorDebrisHint(hintText)
		if not hintText or hintText == "" then
			return false
		end
		
		local lowerHint = string.lower(hintText)
		
		-- Check for door keywords
		local hasDoor = string.find(lowerHint, "door") ~= nil
		local hasOpen = string.find(lowerHint, "open") ~= nil
		
		-- Check for debris keywords
		local hasDebris = string.find(lowerHint, "debris") ~= nil
		local hasClear = string.find(lowerHint, "clear") ~= nil
		local hasRemove = string.find(lowerHint, "remove") ~= nil
		
		-- Door: "door" OR "open" (but not wall buy)
		-- Debris: "debris" OR ("clear"/"remove")
		if hasDoor or hasDebris then
			return true
		end
		
		-- Also check for "open" or "clear" with cost (buyable doors/debris)
		if (hasOpen or hasClear or hasRemove) and string.find(lowerHint, "cost") then
			return true
		end
		
		return false
	end
	
	-- Helper function to detect Mystery Box weapon pickup hints
	local function isMysteryBoxWeapon(hintText)
		if not hintText or hintText == "" then
			return false
		end
		
		local lowerHint = string.lower(hintText)
		
		-- Check for "hold f for" pattern (weapon pickup from mystery box)
		-- Mystery box weapons don't have "buy" or "cost" keywords
		if string.find(lowerHint, "hold") and string.find(lowerHint, "for") and not string.find(lowerHint, "mystery") then
			-- Exclude if it has buy/purchase/cost keywords (those are wall buys)
			if not string.find(lowerHint, "buy") and not string.find(lowerHint, "purchase") and not string.find(lowerHint, "cost") then
				return true
			end
		end
		
		return false
	end
	
	-- Helper function to extract weapon name from hint
	local function getWeaponFromHint(hintText)
		if not hintText or hintText == "" then
			return nil
		end
		
		-- Try different patterns (case-insensitive)
		local lowerHint = string.lower(hintText)
		
		-- Pattern 1: "Hold F For weapon_name" or "Hold &&1 For weapon_name"
		local forPos = string.find(lowerHint, " for ")
		if forPos then
			local weaponName = string.sub(hintText, forPos + 5) -- Skip " for "
			return weaponName
		end
		
		-- Pattern 2: Try without space "For weapon_name"
		forPos = string.find(lowerHint, "for ")
		if forPos then
			local weaponName = string.sub(hintText, forPos + 4) -- Skip "for "
			return weaponName
		end
		
		-- Pattern 3: "Hold &&1 weapon_name" (no "for")
		local holdPos = string.find(lowerHint, "hold ")
		if holdPos then
			-- Extract everything after "hold &&1 " or "hold f "
			local afterHold = string.sub(hintText, holdPos + 5)
			-- Skip button text (F or &&1)
			local spacePos = string.find(afterHold, " ")
			if spacePos then
				local weaponName = string.sub(afterHold, spacePos + 1)
				return weaponName
			end
		end
		
		return nil
	end
	
	-- OFFICIAL PATTERN: Use state conditions on PARENT widget
	self:mergeStateConditions( {
		{
			stateName = "PowerSwitch",
			condition = function ( menu, element, event )
				if not IsCursorHintActive() then
					return false
				end
				
				local cursorHintTextModel = Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" )
				if cursorHintTextModel then
					local cursorHintText = Engine.GetModelValue( cursorHintTextModel )
					return isPowerSwitchHint(cursorHintText)
				end
				return false
			end
		},
		{
			stateName = "Perks",
			condition = function ( menu, element, event )
				if not IsCursorHintActive() then
					return false
				end
				
				local cursorHintTextModel = Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" )
				if cursorHintTextModel then
					local cursorHintText = Engine.GetModelValue( cursorHintTextModel )
					local perkData = getPerkFromHint(cursorHintText)
					
					-- Store perk data for use in text update subscription
					if perkData then
						element.currentPerkData = perkData
						return true
					end
				end
				return false
			end
		},
		{
			stateName = "PAP",
			condition = function ( menu, element, event )
				if not IsCursorHintActive() then
					return false
				end
				
				local cursorHintTextModel = Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" )
				if cursorHintTextModel then
					local cursorHintText = Engine.GetModelValue( cursorHintTextModel )
					return isPAPHint(cursorHintText)
				end
				
				return false
			end
		},
		{
			stateName = "GobbleGum",
			condition = function ( menu, element, event )
				if not IsCursorHintActive() then
					return false
				end
				
				local cursorHintTextModel = Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" )
				if cursorHintTextModel then
					local cursorHintText = Engine.GetModelValue( cursorHintTextModel )
					local isGGHint = isGobbleGumHint(cursorHintText)
					
					if isGGHint then
						-- Update the prompt mode based on whether it's machine or pickup
						if element.promptBBG and CoD.PromptBBG.SetMode then
							local ggData = CoD.GetGobbleGumFromHint(cursorHintText)
							if ggData then
								-- Pickup mode - specific gobblegum
								CoD.PromptBBG.SetMode( element.promptBBG, "pickup", ggData )
							else
								-- Machine mode - dispense prompt
								CoD.PromptBBG.SetMode( element.promptBBG, "machine" )
							end
						end
						return true
					end
				end
				
				return false
			end
		},
		{
			stateName = "WallBuy",
			condition = function ( menu, element, event )
				if not IsCursorHintActive() then
					return false
				end
				
				local cursorHintTextModel = Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" )
				if cursorHintTextModel then
					local cursorHintText = Engine.GetModelValue( cursorHintTextModel )
					return isWallBuyHint(cursorHintText)
				end
				
				return false
			end
		},
		{
			stateName = "MysteryBox",
			condition = function ( menu, element, event )
				if not IsCursorHintActive() then
					return false
				end
				
				local cursorHintTextModel = Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" )
				if cursorHintTextModel then
					local cursorHintText = Engine.GetModelValue( cursorHintTextModel )
					local isBoxHint = isMysteryBoxHint(cursorHintText)
					local isWeaponHint = isMysteryBoxWeapon(cursorHintText)
					
					if isBoxHint or isWeaponHint then
						-- Update the prompt mode INSIDE state condition
						if element.promptMysteryBox and CoD.PromptMysteryBox.SetMode then
							if isWeaponHint then
								-- Weapon mode
								local weaponName = getWeaponFromHint(cursorHintText)
								CoD.PromptMysteryBox.SetMode( element.promptMysteryBox, "weapon", weaponName )
							else
								-- Spin mode
								CoD.PromptMysteryBox.SetMode( element.promptMysteryBox, "spin" )
							end
						end
						return true
					end
				end
				
				return false
			end
		},
		{
			stateName = "Doors",
			condition = function ( menu, element, event )
				if not IsCursorHintActive() then
					return false
				end
				
				local cursorHintTextModel = Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" )
				if cursorHintTextModel then
					local cursorHintText = Engine.GetModelValue( cursorHintTextModel )
					return isDoorDebrisHint(cursorHintText)
				end
				
				return false
			end
		},
		{
			stateName = "PowerRequired",
			condition = function ( menu, element, event )
				if not IsCursorHintActive() then
					return false
				end
				
				local cursorHintTextModel = Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" )
				if cursorHintTextModel then
					local cursorHintText = Engine.GetModelValue( cursorHintTextModel )
					return isPowerRequiredHint(cursorHintText)
				end
				return false
			end
		},
		{
			stateName = "DefaultHint",
			condition = function ( menu, element, event )
				if not IsCursorHintActive() then
					return false
				end
				
				local cursorHintTextModel = Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" )
				if cursorHintTextModel then
					local cursorHintText = Engine.GetModelValue( cursorHintTextModel )
				-- Has a hint but not power switch, power required, perks, PAP, gobblegum, mystery box, wall buy, or doors
				if cursorHintText and cursorHintText ~= "" then
					return not isPowerSwitchHint(cursorHintText) and 
					       not isPowerRequiredHint(cursorHintText) and 
				       not getPerkFromHint(cursorHintText) and
				       not isPAPHint(cursorHintText) and
				       not isGobbleGumHint(cursorHintText) and
			       not isMysteryBoxHint(cursorHintText) and
			       not isMysteryBoxWeapon(cursorHintText) and
			       not isWallBuyHint(cursorHintText) and
			       not isDoorDebrisHint(cursorHintText)
					end
				end
				return false
			end
		}
	} )
	
	-- Subscribe to showCursorHint model to trigger state updates (official pattern)
	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.showCursorHint" ), function ( model )
		menu:updateElementState( self, {
			name = "model_validation",
			menu = menu,
			modelValue = Engine.GetModelValue( model ),
			modelName = "hudItems.showCursorHint"
		} )
	end )
	
	-- Also subscribe to cursorHintText to update the default prompt text
	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" ), function ( model )
		local cursorHintText = Engine.GetModelValue( model )
		
		if cursorHintText and cursorHintText ~= "" then
			local isPower = isPowerSwitchHint(cursorHintText)
			local perkData = getPerkFromHint(cursorHintText)
			local isPAP = isPAPHint(cursorHintText)
			local isRepack = isRepackHint(cursorHintText)
			local isMystBox = isMysteryBoxHint(cursorHintText)
			local isMystWeapon = isMysteryBoxWeapon(cursorHintText)
			local isGum = isGobbleGumHint(cursorHintText)
			
			-- Update perk prompt if it's a perk
			if perkData and self.promptPerks then
				CoD.PromptPerks.UpdatePerkInfo( self.promptPerks, perkData )
			end
			
			-- Update PAP prompt mode (pack vs re-pack)
			if isPAP and self.promptPAP then
				CoD.PromptPAP.SetMode( self.promptPAP, isRepack )
			end
			
			-- Update Mystery Box prompt mode (spin vs weapon pickup)
			if (isMystBox or isMystWeapon) and self.promptMysteryBox then
				if CoD.PromptMysteryBox.SetMode then
					if isMystWeapon then
						-- Weapon mode - extract weapon name
						local weaponName = getWeaponFromHint(cursorHintText)
						CoD.PromptMysteryBox.SetMode( self.promptMysteryBox, "weapon", weaponName )
					else
						-- Spin mode
						CoD.PromptMysteryBox.SetMode( self.promptMysteryBox, "spin" )
					end
				end
			end
			
			-- Update default prompt text if needed (with safety check)
			if not isPower and not perkData and not isPAP and not isGum and not isMystBox and not isMystWeapon and self.promptDefault and self.promptDefault.hintText then
				self.promptDefault.hintText:setText( Engine.Localize( cursorHintText ) )
			end
			
			-- Force state update to ensure correct prompt displays
			menu:updateElementState( self, {
				name = "cursorHintText_update",
				menu = menu,
				modelValue = cursorHintText,
				modelName = "hudItems.cursorHintText"
			} )
		end
	end )
	
	-- CLIPS PER STATE - Control visibility (simplified)
	self.clipsPerState = {
		DefaultState = {
			DefaultClip = function ()
				self.PromptPowerSwitch:setAlpha( 0 )
				self.promptDefault:setAlpha( 0 )
				self.PromptPowerRequired:setAlpha( 0 )
				self.promptPerks:setAlpha( 0 )
				self.promptPAP:setAlpha( 0 )
				self.promptBBG:setAlpha( 0 )
				self.promptMysteryBox:setAlpha( 0 )
				self.promptWallBuy:setAlpha( 0 )
				self.promptDoors:setAlpha( 0 )
			end
		},
		PowerSwitch = {
			DefaultClip = function ()
				self.PromptPowerSwitch:setAlpha( 1 )
				self.promptDefault:setAlpha( 0 )
				self.PromptPowerRequired:setAlpha( 0 )
				self.promptPerks:setAlpha( 0 )
				self.promptPAP:setAlpha( 0 )
				self.promptBBG:setAlpha( 0 )
				self.promptMysteryBox:setAlpha( 0 )
				self.promptWallBuy:setAlpha( 0 )
				self.promptDoors:setAlpha( 0 )
			end
		},
		Perks = {
			DefaultClip = function ()
				self.PromptPowerSwitch:setAlpha( 0 )
				self.promptDefault:setAlpha( 0 )
				self.PromptPowerRequired:setAlpha( 0 )
				self.promptPerks:setAlpha( 1 )
				self.promptPAP:setAlpha( 0 )
				self.promptBBG:setAlpha( 0 )
				self.promptMysteryBox:setAlpha( 0 )
				self.promptWallBuy:setAlpha( 0 )
				self.promptDoors:setAlpha( 0 )
			end
		},
		Doors = {
			DefaultClip = function ()
				self.PromptPowerSwitch:setAlpha( 0 )
				self.promptDefault:setAlpha( 0 )
				self.PromptPowerRequired:setAlpha( 0 )
				self.promptPerks:setAlpha( 0 )
				self.promptPAP:setAlpha( 0 )
				self.promptBBG:setAlpha( 0 )
				self.promptMysteryBox:setAlpha( 0 )
				self.promptWallBuy:setAlpha( 0 )
				self.promptDoors:setAlpha( 1 )
			end
		},
		PAP = {
			DefaultClip = function ()
				self.PromptPowerSwitch:setAlpha( 0 )
				self.promptDefault:setAlpha( 0 )
				self.PromptPowerRequired:setAlpha( 0 )
				self.promptPerks:setAlpha( 0 )
				self.promptPAP:setAlpha( 1 )
				self.promptBBG:setAlpha( 0 )
				self.promptMysteryBox:setAlpha( 0 )
				self.promptWallBuy:setAlpha( 0 )
				self.promptDoors:setAlpha( 0 )
			end
		},
		GobbleGum = {
			DefaultClip = function ()
				self.PromptPowerSwitch:setAlpha( 0 )
				self.promptDefault:setAlpha( 0 )
				self.PromptPowerRequired:setAlpha( 0 )
				self.promptPerks:setAlpha( 0 )
				self.promptPAP:setAlpha( 0 )
				self.promptBBG:setAlpha( 1 )
				self.promptMysteryBox:setAlpha( 0 )
				self.promptWallBuy:setAlpha( 0 )
				self.promptDoors:setAlpha( 0 )
			end
		},
		MysteryBox = {
			DefaultClip = function ()
				self.PromptPowerSwitch:setAlpha( 0 )
				self.promptDefault:setAlpha( 0 )
				self.PromptPowerRequired:setAlpha( 0 )
				self.promptPerks:setAlpha( 0 )
				self.promptPAP:setAlpha( 0 )
				self.promptBBG:setAlpha( 0 )
				self.promptMysteryBox:setAlpha( 1 )
				self.promptWallBuy:setAlpha( 0 )
				self.promptDoors:setAlpha( 0 )
			end
		},
		PowerRequired = {
			DefaultClip = function ()
				self.PromptPowerSwitch:setAlpha( 0 )
				self.promptDefault:setAlpha( 0 )
				self.PromptPowerRequired:setAlpha( 1 )
				self.promptPerks:setAlpha( 0 )
				self.promptPAP:setAlpha( 0 )
				self.promptBBG:setAlpha( 0 )
				self.promptMysteryBox:setAlpha( 0 )
				self.promptWallBuy:setAlpha( 0 )
				self.promptDoors:setAlpha( 0 )
			end
		},
		WallBuy = {
			DefaultClip = function ()
				self.PromptPowerSwitch:setAlpha( 0 )
				self.promptDefault:setAlpha( 0 )
				self.PromptPowerRequired:setAlpha( 0 )
				self.promptPerks:setAlpha( 0 )
				self.promptPAP:setAlpha( 0 )
				self.promptBBG:setAlpha( 0 )
				self.promptMysteryBox:setAlpha( 0 )
				self.promptWallBuy:setAlpha( 1 )
				self.promptDoors:setAlpha( 0 )
			end
		},
		DefaultHint = {
			DefaultClip = function ()
				self.PromptPowerSwitch:setAlpha( 0 )
				self.promptDefault:setAlpha( 1 )
				self.PromptPowerRequired:setAlpha( 0 )
				self.promptPerks:setAlpha( 0 )
				self.promptPAP:setAlpha( 0 )
				self.promptBBG:setAlpha( 0 )
				self.promptMysteryBox:setAlpha( 0 )
				self.promptWallBuy:setAlpha( 0 )
				self.promptDoors:setAlpha( 0 )
			end
		}
	}
	
	LUI.OverrideFunction_CallOriginalSecond( self, "close", function ( element )
		element.PromptPowerSwitch:close()
		element.promptDefault:close()
		element.PromptPowerRequired:close()
		element.promptPerks:close()
		element.promptPAP:close()
		element.promptBBG:close()
		element.promptMysteryBox:close()
		element.promptWallBuy:close()
		element.promptDoors:close()
	end )
	
	-- Subscribe to cursorHintImage for dynamic updates (wall buy detection)
	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintImage" ), function ( model )
		-- Force state re-evaluation when weapon icon changes
		menu:updateElementState( self, {
			name = "cursorHintImage_update",
			menu = menu,
			modelValue = Engine.GetModelValue( model ),
			modelName = "hudItems.cursorHintImage"
		} )
	end )
	
	-- Subscribe to cursorHintIconRatio for dynamic updates
	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintIconRatio" ), function ( model )
		-- Force state re-evaluation when icon ratio changes
		menu:updateElementState( self, {
			name = "cursorHintIconRatio_update",
			menu = menu,
			modelValue = Engine.GetModelValue( model ),
			modelName = "hudItems.cursorHintIconRatio"
		} )
	end )
	
	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end

	-- Force initial state evaluation to hide both prompts on load
	self:processEvent( {
		name = "menu_loaded",
		controller = controller
	} )
	
	return self
end

