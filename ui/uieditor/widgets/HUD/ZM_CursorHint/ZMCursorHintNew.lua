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
	
	-- [tod 2026-08-31] getCursorHintImage() and getCursorHintIconRatio() were
	-- deleted here. Their ONLY consumer was isWallBuyHint's image guard, and that
	-- guard is exactly the thing that did not work (see the classifier below).
	-- The model SUBSCRIPTIONS further down stay: they still force a state
	-- re-evaluation when the engine swaps hint art mid-look.

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

	-- =====================================================================
	-- [tod 2026-08-31] THE CLASSIFIER -- ONE function, ONE answer.
	--
	-- WHAT WAS WRONG. Routing used to be nine independent predicates spread
	-- across nine mergeStateConditions arms. Several matched the same hint at
	-- once, so the winner depended on arm order; and two of them could never
	-- be right on this map, yet were wrong constantly:
	--
	--   * isWallBuyHint() = "the text contains [Cost:" AND
	--     getCursorHintImage() ~= "". The image guard was believed to make it
	--     safe for our HINT_NOICON triggers -- _tod_ammo_crate.gsc:155 and
	--     _tod_upgrades.gsc::station_hint_loop both reason explicitly from
	--     that premise. THE PREMISE IS FALSE: hudItems.cursorHintImage does
	--     not read back as the empty string for an icon-less hint, so
	--     '~= ""' was effectively always true and the guard never fired.
	--     Every PRICED NON-DOOR interactable in the map therefore drew
	--     PromptWallBuy, whose hardcoded description is the literal text
	--     "Wall Weapon" -- exactly the user's report, at the ammo crates and
	--     at the Heavenly Gift Altar, and equally at CALL EXTRACTION and at
	--     every spire buy. THIS MAP HAS NO WALL WEAPONS (CLAUDE.md: "NO
	--     wallbuys -- user: I never asked for those"), so that route had
	--     nothing correct to detect and could only misfire.
	--   * isMysteryBoxHint / isMysteryBoxWeapon / isGobbleGumHint: same story
	--     -- no mystery box and no gobblegum machine exists here.
	--     isMysteryBoxWeapon was the worst of them, claiming ANY hint that
	--     contains "hold" and the substring "for" and no cost: a trap armed
	--     for whoever wrote the next hint string.
	--
	-- Those three cards are now UNREACHABLE. The widgets stay constructed so
	-- close() and clipsPerState keep working untouched, but no arm selects
	-- them. If this map ever grows a real wallbuy, give it its own noun test
	-- here -- do not restore a guard that was never load-bearing.
	--
	-- WHAT REPLACED IT: classifyHint() returns EXACTLY ONE state name, most
	-- specific test first. Every arm below is a single equality against it,
	-- so arm order stops mattering and a hint cannot be claimed twice.
	--
	-- TOD_NOUNS IS THE LOAD-BEARING PART. These are the nouns this map's own
	-- SetHintString literals lead with (grep SetHintString under
	-- scripts/zm/zm_tower_of_doom/). Claiming them BEFORE the generic keyword
	-- tests is what lets the ammo crate say "Pack a Punch $5000" without
	-- isPAPHint's "pack"+"punch" test dragging it onto the PaP card.
	-- ANY NEW INTERACTABLE WITH A CUSTOM PROMPT ADDS ITS NOUN HERE.
	-- Matching is PLAIN (the 4th arg to string.find), never pattern matching,
	-- so a noun containing a magic character can never misbehave.
	-- =====================================================================
	local TOD_NOUNS = {
		"ammo crate",
		"heavenly gift altar", "altar spent", "all upgrades maxed",
		"teleporter",
		"extract",                      -- covers CALL EXTRACTION / EXTRACTING / EXTRACTION INBOUND
		"rampage",
		"ascend", "endless spire",
		"sealed",
		"defend the crown", "run for the crown", "reach the crown",
		"uplink",
		"already packed",               -- the Pack-a-Punch's packed-state status line (zm_cwpap.gsc, v16.27)
		-- v17.33 — the spire's PACK II / PACK III re-packs (zm_cwpap.gsc
		-- tod_set_tier_hint). The copy already avoids the second half of the
		-- Pack-a-Punch keyword pair so isPAPHint cannot claim it, but these
		-- nouns are matched at step 3 and isPAPHint runs at step 5, so the
		-- routing holds even if the wording is later changed by someone who
		-- has not read that function.
		--
		-- NEVER PUT A QUOTED WORD IN A COMMENT INSIDE THIS TABLE. The first
		-- draft of this note quoted the keyword it was discussing, and
		-- tools/lint_tod_hints.js — which reads the nouns by scanning this
		-- block for quoted strings, as any reader would — took that word as a
		-- NOUN. It matches stock's own &ZOMBIE_PERK_PACKAPUNCH, so every
		-- Pack-a-Punch prompt in the map would have been dragged onto the
		-- DefaultHint card by a COMMENT. The lint caught it; nothing else
		-- would have until someone walked up to a machine.
		"pack ii", "pack iii",
	}

	local function classifyHint(hintText)
		if not hintText or hintText == "" then
			return nil
		end
		local h = string.lower(hintText)

		-- 1. POWER. The "you must" line is a strict subset of the switch line,
		-- so it has to be tested first.
		if string.find(h, "you must turn on the power first", 1, true) then
			return "PowerRequired"
		end
		if string.find(h, "turn on the power", 1, true)
			or string.find(h, "activate power", 1, true)
			or string.find(h, "activate the power", 1, true) then
			return "PowerSwitch"
		end

		-- 2. DOORS AND DEBRIS -- tested BEFORE TOD_NOUNS because a door hint
		-- carries an authored DESTINATION NAME ("Open Door to the Crown",
		-- "... to the Teleport Bay"), and a destination is free to contain any
		-- word at all. "open door" is the map's own literal in
		-- _tod_doors.gsc:183 and _tod_spire.gsc::spire_door_hint.
		if string.find(h, "open door", 1, true) or string.find(h, "debris", 1, true) then
			return "Doors"
		end

		-- 3. THE MAP'S OWN NOUNS -> the structured default card.
		for i = 1, #TOD_NOUNS do
			if string.find(h, TOD_NOUNS[i], 1, true) then
				return "DefaultHint"
			end
		end

		-- 4. PERK MACHINES (stock + vendored: "Hold [key] for <Perk> [Cost: N]").
		if getPerkFromHint(hintText) then
			return "Perks"
		end

		-- 5. PACK-A-PUNCH (zm_cwpap's &"ZOMBIE_PERK_PACKAPUNCH").
		if isPAPHint(hintText) then
			return "PAP"
		end

		return "DefaultHint"
	end

	-- OFFICIAL PATTERN: Use state conditions on PARENT widget.
	-- Every arm is now the same closure over one state name, so the arms
	-- cannot disagree and their evaluation order cannot decide the outcome.
	local function hintIs(stateName)
		return function ( menu, element, event )
			if not IsCursorHintActive() then
				return false
			end
			local model = Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" )
			if not model then
				return false
			end
			local hintText = Engine.GetModelValue( model )
			if classifyHint(hintText) ~= stateName then
				return false
			end
			-- Stash the perk row for the text subscription, as before.
			if stateName == "Perks" then
				element.currentPerkData = getPerkFromHint(hintText)
			end
			return true
		end
	end

	self:mergeStateConditions( {
		{ stateName = "PowerSwitch",   condition = hintIs( "PowerSwitch" ) },
		{ stateName = "PowerRequired", condition = hintIs( "PowerRequired" ) },
		{ stateName = "Doors",         condition = hintIs( "Doors" ) },
		{ stateName = "Perks",         condition = hintIs( "Perks" ) },
		{ stateName = "PAP",           condition = hintIs( "PAP" ) },
		{ stateName = "DefaultHint",   condition = hintIs( "DefaultHint" ) }
		-- WallBuy / MysteryBox / GobbleGum have NO arm: see the classifier's
		-- header. Their clipsPerState blocks below are left in place (dead but
		-- harmless) so nothing else in this file has to change.
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
	
	-- Also subscribe to cursorHintText to drive the per-card modes.
	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" ), function ( model )
		local cursorHintText = Engine.GetModelValue( model )

		if cursorHintText and cursorHintText ~= "" then
			local state = classifyHint( cursorHintText )

			-- Update perk prompt if it's a perk
			if state == "Perks" and self.promptPerks then
				CoD.PromptPerks.UpdatePerkInfo( self.promptPerks, getPerkFromHint( cursorHintText ), cursorHintText )
			end

			-- Update PAP prompt mode (pack vs re-pack)
			if state == "PAP" and self.promptPAP then
				CoD.PromptPAP.SetMode( self.promptPAP, isRepackHint( cursorHintText ) )
			end

			-- [tod 2026-08-31] NOTHING HERE WRITES promptDefault.hintText ANY
			-- MORE. The line that used to sit here was
			--     self.promptDefault.hintText:setText( Engine.Localize( cursorHintText ) )
			-- and it was the second of TWO writers on that field. PromptDefault
			-- subscribes to this same model inside its own constructor, which
			-- runs EARLIER (PromptDefault.new is called from this file, above,
			-- before this subscribe), so this one fired LAST and won -- and it
			-- wrote the RAW hint: colour codes, the [{+activate}] token and a
			-- 44-character price line, all poured into one 146px-wide box.
			-- That is the "HoldXAMMOCRATE / there is no spacing between things"
			-- report. PromptDefault now owns its text and parses the hint into
			-- title / detail / price / footer fields. DO NOT ADD A WRITER HERE.
		end

		-- Force state update to ensure correct prompt displays.
		--
		-- [tod v16.27] THIS RUNS FOR A BLANK HINT TOO. It used to sit inside the
		-- non-empty guard above, so when a trigger's hint went from real text
		-- to "" while the player stayed in range -- exactly what the
		-- Pack-a-Punch did the moment a purchase landed (the packed gun in hand
		-- set SetHintString( "" )) -- nothing re-evaluated the state and the
		-- LAST card stayed up: "Pack-a-Punch / 5000 / Hold F To Upgrade" over
		-- a machine that had nothing left to sell. Hold F again, deny sound, no
		-- explanation: the double-pack confusion. classifyHint( "" ) is nil, no
		-- arm matches, and DefaultState hides every card, which is the right
		-- picture for a blank hint.
		menu:updateElementState( self, {
			name = "cursorHintText_update",
			menu = menu,
			modelValue = cursorHintText,
			modelName = "hudItems.cursorHintText"
		} )
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
		-- [tod 2026-09-22, bug review F24] AetheriumHud.lua merges an
		-- "Active_1x1" condition (stock's cursor-hint-active bit) AFTER our
		-- six arms. A BLANK hint (zm_cwpap SetHintString("") for a weapon the
		-- machine will not pack) matches none of ours, so Active_1x1 won with
		-- no clip here and the last card stayed on screen. Same hide-all.
		Active_1x1 = {
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

