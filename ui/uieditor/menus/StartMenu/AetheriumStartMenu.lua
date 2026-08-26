-- Aetherium Pause Menu (Custom Design)

require("ui.uieditor.widgets.StartMenu.AetheriumMenuButton")
require("ui.uieditor.widgets.StartMenu.AetheriumSmallButton")

-- Configuration
local ShowSignatures = true  -- Set to false to hide signature images

-- Third Person Toggle Functions
local GetThirdPersonLabel = function(controller)
	local thirdPersonModel = Engine.GetModel(Engine.GetModelForController(controller), "ui_menu_option_third_person")
	local thirdPerson = Engine.GetModelValue(thirdPersonModel)
	
	if thirdPerson == nil then
		Engine.SetModelValue(thirdPersonModel, false)
		thirdPerson = false
	end
	
	return thirdPerson and "Switch To First Person" or "Switch To Third Person"
end

local ToggleThirdPerson = function(self, element, controller, actionParam, menu)
	local thirdPersonModel = Engine.CreateModel(Engine.GetModelForController(controller), "ui_menu_option_third_person")
	local newValue = not Engine.GetModelValue(thirdPersonModel)
	Engine.SetModelValue(thirdPersonModel, newValue)
	Engine.SendMenuResponse(controller, "StartMenu_Main", "ui_menu_option_third_person|" .. (newValue and "1" or "0"))
	
	-- Update button list to show new label
	if menu.ButtonList then
		menu.ButtonList:updateDataSource()
	end
end

-- [tod] GAME-OVER MODE (v9.24, port of map 1's retry-on-death v3): on a wipe (or
-- the finale's win), _tod_gameover.gsc re-enables the ingame menu (stock disables
-- it at end_game), force-opens THIS menu on every player and sets the host-side
-- dvar tod_go_active=1. In that mode the button list is exactly two entries —
-- Restart Map / End Game — navigated with the menu's own native up/down +
-- confirm. The dvar is host-machine-only, so co-op peers get the normal pause
-- list (Leave Game works there; restarting is the host's call). GSC scrubs the
-- dvar at init, so a mid-run pause menu is never in this mode. Every read is
-- pcall'd through a try-list (the dvar-read signature differs by build).
local TodGoActive = function(controller)
	local tries = {
		function() return Engine.DvarString(controller, "tod_go_active") end,
		function() return Engine.DvarString("tod_go_active") end,
		function() return Engine.GetDvarString("tod_go_active") end,
	}
	for i = 1, #tries do
		local ok, r = pcall(tries[i])
		if ok and r ~= nil and tostring(r) == "1" then
			return true
		end
	end
	return false
end

-- DataSource for small top buttons
DataSources.AetheriumSmallMenuButtons = ListHelper_SetupDataSource("AetheriumSmallMenuButtons", function(controller)
	local buttons = {}

	-- Graphics Settings
	table.insert(buttons, {
		models = {
			icon = "i_mtl_icon_ftueftus_audio_config_tv",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Graphics_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Graphics", controller, "", "")
				end
			end
		}
	})

	-- Sound/Audio Settings
	table.insert(buttons, {
		models = {
			icon = "i_mtl_image_2d767ba54c664e54",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Sound_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Sound", controller, "", "")
				end
			end
		}
	})

	-- Keybinds/Controls Settings
	table.insert(buttons, {
		models = {
			icon = "i_mtl_firing_range_input_settings_kbm",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Controls_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Controls", controller, "", "")
				end
			end
		}
	})

	-- All Options (Show inline options)
	table.insert(buttons, {
		models = {
			icon = "i_mtl_ui_menu_codhq_icon_settings",
			action = function(self, element, controller, actionParam, menu)
				-- Same action as Game Settings button
				menu.ButtonList:completeAnimation()
				menu.SmallButtonList:completeAnimation()
				menu.OptionsList:completeAnimation()
				menu.OptionsHeaderText:completeAnimation()
				menu.PauseMenuText:completeAnimation()
				
				menu.ButtonList:setAlpha(0)
				menu.SmallButtonList:setAlpha(0)
				menu.PauseMenuText:setAlpha(0)
				menu.OptionsList:setAlpha(1)
				menu.OptionsHeaderText:setAlpha(1)
				menu.OptionsList:processEvent({name = "gain_focus", controller = controller})
			end
		}
	})

	return buttons
end, true)

-- DataSource for menu buttons
DataSources.AetheriumStartMenuButtons = ListHelper_SetupDataSource("AetheriumStartMenuButtons", function(controller)
	local buttons = {}

	-- [tod] game-over mode: exactly two choices, both the existing proven
	-- pause-menu lanes verbatim (Restart Level's map_restart, Leave Game's
	-- disconnect). No "Return To Game" — there is no game to return to.
	if TodGoActive(controller) then
		table.insert(buttons, {
			models = {
				displayText = "Restart Map",
				action = function(self, element, controller, actionParam, menu)
					GoBack(menu, controller)
					Engine.Exec(controller, "map_restart")
				end
			}
		})
		table.insert(buttons, {
			models = {
				displayText = "End Game",
				action = function(self, element, controller, actionParam, menu)
					menu:processEvent({
						name = "close_all_ingame_menus",
						controller = controller
					})
					Engine.SendMenuResponse(controller, "popup_leavegame", "endround")
					Engine.SetDvar("cl_paused", 0)
					Engine.Exec(controller, "disconnect")
				end
			}
		})
		return buttons
	end

	table.insert(buttons, {
		models = {
			displayText = "Return To Game",
			action = function(self, element, controller, actionParam, menu)
				RefreshLobbyRoom(menu, controller)
				StartMenuGoBack(menu, controller)
			end
		}
	})

	table.insert(buttons, {
		models = {
			displayText = "Restart Level",
			action = function(self, element, controller, actionParam, menu)
				-- Close menu first
				GoBack(menu, controller)
				-- Restart the map
				Engine.Exec(controller, "map_restart")
			end
		}
	})

	table.insert(buttons, {
		models = {
			displayText = GetThirdPersonLabel(controller),
			action = ToggleThirdPerson
		}
	})

	table.insert(buttons, {
		models = {
			displayText = "Game Settings",
			action = function(self, element, controller, actionParam, menu)
				-- Instantly switch to options
				menu.ButtonList:completeAnimation()
				menu.SmallButtonList:completeAnimation()
				menu.OptionsList:completeAnimation()
				menu.OptionsHeaderText:completeAnimation()
				menu.PauseMenuText:completeAnimation()
				
				menu.ButtonList:setAlpha(0)
				menu.SmallButtonList:setAlpha(0)
				menu.PauseMenuText:setAlpha(0)
				menu.OptionsList:setAlpha(1)
				menu.OptionsHeaderText:setAlpha(1)
				menu.OptionsList:processEvent({name = "gain_focus", controller = controller})
			end
		}
	})

	-- HUD Settings and Social buttons removed

	table.insert(buttons, {
		models = {
			displayText = "Leave Game",
			action = function(self, element, controller, actionParam, menu)
				-- Close all menus first
				menu:processEvent({
					name = "close_all_ingame_menus",
					controller = controller
				})
				
				-- Send menu response for proper cleanup
				Engine.SendMenuResponse(controller, "popup_leavegame", "endround")
				
				-- Check if solo or multiplayer
				local playerCount = Engine.GetPlayerCount()
				
				if playerCount and playerCount <= 1 then
					-- Solo: End the game (disconnect)
					Engine.SetDvar("cl_paused", 0)
					Engine.Exec(controller, "disconnect")
				else
					-- Multiplayer: Just leave the game
					Engine.SetDvar("cl_paused", 0)
					Engine.Exec(controller, "disconnect")
				end
			end
		}
	})

	return buttons
end, true)

-- DataSource for options buttons (shown when Game Settings is clicked)
DataSources.AetheriumOptionsButtons = ListHelper_SetupDataSource("AetheriumOptionsButtons", function(controller)
	local options = {}
	
	table.insert(options, {
		models = {
			displayText = "Graphics",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Graphics_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Graphics", controller, "", "")
				end
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Audio",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Sound_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Sound", controller, "", "")
				end
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Controls",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Controls_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Controls", controller, "", "")
				end
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Voice & Muting",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Voice_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Voice", controller, "", "")
				end
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Network",
			action = function(self, element, controller, actionParam, menu)
				OpenPopup(menu, "StartMenu_Options_Network", controller, "", "")
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Safe Area",
			action = function(self, element, controller, actionParam, menu)
				OpenPopup(menu, "StartMenu_Options_Graphics_SafeArea", controller, "", "")
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Content Filter",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_GraphicContent_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_GraphicContent", controller, "", "")
				end
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Credits",
			action = function(self, element, controller, actionParam, menu)
				OpenPopup(menu, "Credit_Fullscreen", controller, "", "")
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Back",
			action = function(self, element, controller, actionParam, menu)
				-- Instantly hide options and show main menu
				menu.OptionsList:completeAnimation()
				menu.OptionsHeaderText:completeAnimation()
				menu.ButtonList:completeAnimation()
				menu.SmallButtonList:completeAnimation()
				menu.PauseMenuText:completeAnimation()
				
				menu.OptionsList:setAlpha(0)
				menu.OptionsHeaderText:setAlpha(0)
				menu.ButtonList:setAlpha(1)
				menu.SmallButtonList:setAlpha(1)
				menu.PauseMenuText:setAlpha(1)
				menu.ButtonList:processEvent({name = "gain_focus", controller = controller})
			end
		}
	})
	
	return options
end, true)

local PostLoadFunc = function(self, controller)
	self:registerEventHandler("menu_opened", function(element, event)
		Engine.SetUIActive(controller, true)
		
		-- Hide HUD when pause menu opens
		local controllerModel = Engine.GetModelForController(controller)
		local hudVisibilityModel = Engine.GetModel(controllerModel, "UIVisibility.Visibility")
		if hudVisibilityModel then
			Engine.SetModelValue(hudVisibilityModel, 0)
		end
		
		return true
	end)
	
	self:registerEventHandler("menu_closed", function(element, event)
		Engine.SetUIActive(controller, false)
		
		-- Show HUD when pause menu closes
		local controllerModel = Engine.GetModelForController(controller)
		local hudVisibilityModel = Engine.GetModel(controllerModel, "UIVisibility.Visibility")
		if hudVisibilityModel then
			Engine.SetModelValue(hudVisibilityModel, 1)
		end
		
		return true
	end)
	
	if CoD.isZombie then
		self.disableDarkenElement = true
		self.disablePopupOpenCloseAnim = false
	end
end

LUI.createMenu.StartMenu_Main = function(controller)
	local self = CoD.Menu.NewForUIEditor("StartMenu_Main")

	self.soundSet = "default"
	self:setOwner(controller)
	self:setLeftRight(true, true, 0, 0)
	self:setTopBottom(true, true, 0, 0)
	self:playSound("menu_open", controller)
	self.buttonModel = Engine.CreateModel(Engine.GetModelForController(controller), "StartMenu_Main.buttonPrompts")
	self.anyChildUsesUpdateState = true

	-- Dark Blur Overlay
	self.DarkOverlay = LUI.UIImage.new()
	self.DarkOverlay:setLeftRight(true, true, 0, 0)
	self.DarkOverlay:setTopBottom(true, true, 0, 0)
	self.DarkOverlay:setImage(RegisterImage("$white"))
	self.DarkOverlay:setRGB(0.05, 0.05, 0.05)
	self.DarkOverlay:setAlpha(0.8)
	self:addElement(self.DarkOverlay)

	-- pause_menu_bg
	self.BGMain = LUI.UIImage.new()
	self.BGMain:setLeftRight(true, false, 0, 1280)
	self.BGMain:setTopBottom(true, false, 0, 720)
	self.BGMain:setImage(RegisterImage("i_mtl_image_2c20915dba690ea5"))
	self:addElement(self.BGMain)

	-- sat_pause_menu_bg
	self.BGRight = LUI.UIImage.new()
	self.BGRight:setLeftRight(true, false, 823, 1252)
	self.BGRight:setTopBottom(true, false, 0, 720)
	self.BGRight:setImage(RegisterImage("i_mtl_sat_pause_menu_bg"))
	self:addElement(self.BGRight)

	-- bg_blood
	self.BGBlood = LUI.UIImage.new()
	self.BGBlood:setLeftRight(true, false, 814, 1338)
	self.BGBlood:setTopBottom(true, false, 390, 711)
	self.BGBlood:setImage(RegisterImage("i_mtl_image_273102a380412bec"))
	self:addElement(self.BGBlood)

	-- Game mode icon
	self.GameModeIcon = LUI.UIImage.new()
	self.GameModeIcon:setLeftRight(true, false, 5, 97)
	self.GameModeIcon:setTopBottom(true, false, 10, 102)
	self.GameModeIcon:setImage(RegisterImage("i_mtl_sat_ui_icon_gamemode_zm_standard"))
	self:addElement(self.GameModeIcon)

	-- Logo
	self.Logo = LUI.UIImage.new()
    self.Logo:setLeftRight(true, false, 79, 377)
    self.Logo:setTopBottom(true, false, 55, 102)
	self.Logo:setImage(RegisterImage("i_mtl_image_2fe6956607db6e68"))
	self:addElement(self.Logo)

	-- Map Name
	self.MapName = LUI.UIText.new()
    self.MapName:setLeftRight(true, false, 102, 192)
    self.MapName:setTopBottom(true, false, 37, 50)
	self.MapName:setText(Engine.Localize(CoD.UsermapName or "UNKNOWN MAP"))
	self.MapName:setTTF("fonts/orbitron.ttf")
	self.MapName:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.MapName)

	-- Round Label
	self.RoundLabel = LUI.UIText.new()
    self.RoundLabel:setLeftRight(true, false, 217, 281)
    self.RoundLabel:setTopBottom(true, false, 37, 50)
	self.RoundLabel:setText(Engine.Localize("ROUND"))
	self.RoundLabel:setTTF("fonts/orbitron.ttf")
	self:addElement(self.RoundLabel)

	-- Round Number
	self.RoundNumber = LUI.UIText.new()
    self.RoundNumber:setLeftRight(true, false, 293, 330)
    self.RoundNumber:setTopBottom(true, false, 37, 50)
	self.RoundNumber:setTTF("fonts/orbitron.ttf")
	self.RoundNumber:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "gameScore.roundsPlayed"), function(model)
		local roundsPlayed = Engine.GetModelValue(model)
		if roundsPlayed then
			self.RoundNumber:setText(Engine.Localize(tostring(math.max(1, roundsPlayed - 1))))
		end
	end)
	self:addElement(self.RoundNumber)

	-- Game Mode Text
	self.GameModeText = LUI.UIText.new()
    self.GameModeText:setLeftRight(true, false, 102, 357)
    self.GameModeText:setTopBottom(true, false, 57, 74)
	self.GameModeText:setText(Engine.Localize("Round Based Zombies"))
	self.GameModeText:setTTF("fonts/orbitron.ttf")
	self:addElement(self.GameModeText)

	-- [tod] YOUR UPGRADES — pause-menu-only readout (user 2026-08-20: the
	-- always-on HUD column cluttered play). Data = CoD.TodOwned, accumulated
	-- by tod_upgrade.lua (always-open HUD menu) from GSC tod_upg_sync
	-- LuiNotifyEvents; this menu is re-created on every pause, so a plain
	-- read here is always current. Names come from CoD.TodDomainInfo (the
	-- HUD's own DOMAIN table — one source of truth).
	--
	-- BAKED ART (user 2026-08-20, files (12).zip — the images-over-LUI rule):
	-- header plate (i_tod_pause_hdr, 500x70) + one name plate per domain
	-- (i_tod_pause_rNN, 300x44, NN = _tod_upgrade_ui::domain_id) + a level pip
	-- (i_tod_pause_pip, 24x24) repeated once per owned level. All drawn at TRUE
	-- ASPECT — the v6.6 stretched-plate lesson. Set USE_PAUSE_ART=false to fall
	-- back to the old text rows (kept intact below).
	--
	local USE_PAUSE_ART = true

	local todOwned = CoD.TodOwned or {}
	local todInfo = CoD.TodDomainInfo or {}
	local todRows = {}
	for id = 1, 63 do   -- the domain-id field is 6 bits (2026-08-22); ids above PAUSE_PLATE_MAX (below) render as TEXT rows; the body is nil-guarded so unused ids cost nothing
		local o = todOwned[ id ]
		if o and o.lvl and o.lvl > 0 then
			-- Detail lines come from tod_upgrade.lua's DETAIL table via
			-- CoD.TodDomainDesc — LEVEL-AWARE, so the number shown is the value
			-- at the level this player actually holds, not the per-level rule.
			-- Nil-guarded twice: the accessor may be absent (older HUD lua) and
			-- may return nil for an id with no detail row; DOMAIN.desc is the
			-- fallback so a new domain is never rendered blank.
			local eff, act = nil, nil
			if CoD.TodDomainDesc then
				eff, act = CoD.TodDomainDesc( id, o.lvl )
			end
			if not eff then
				eff = ( todInfo[ id ] and todInfo[ id ].desc ) or ""
			end
			todRows[ #todRows + 1 ] = {
				id = id,
				lvl = o.lvl,
				max = o.max or 10,
				name = ( todInfo[ id ] and todInfo[ id ].name ) or ( "UPGRADE " .. id ),
				eff = eff,
				act = act or "",
			}
		end
	end

	if #todRows > 0 and USE_PAUSE_ART then
		-- header: RE-CUT to 1000x70 for the two-column panel (files (36).zip,
		-- 2026-08-23) -> 700x49, aspect 14.286 held EXACTLY. The old art was
		-- 500x70 at 232x32 (aspect 7.14) and looked undersized once the panel
		-- grew to two columns. Right edge 802 stays clear of BGBlood at 814.
		self.TodUpgHeader = LUI.UIImage.new()
		self.TodUpgHeader:setLeftRight( true, false, 102, 802 )
		self.TodUpgHeader:setTopBottom( true, false, 119, 168 )
		self.TodUpgHeader:setImage( RegisterImage( "i_tod_pause_hdr" ) )
		self:addElement( self.TodUpgHeader )

		-- ------------------------------------------------------------------
		-- TWO-COLUMN DETAIL ROWS (v9.37, user 2026-08-23: "players forget or
		-- don't know exactly what each upgrade does"). Each row is the baked
		-- name plate + level pips, then TWO authored text lines: what it does
		-- at YOUR level (cyan) and how it activates (dim).
		--
		-- Geometry is bounded by real elements, not taste:
		--   * BGBlood's left edge is x=814 -> right bound 810.
		--   * The four signature images (x 0..508, y 637..720) are addElement'd
		--     AFTER this block, so they PAINT OVER anything below y=637.
		--   * Rows must therefore end above y=637. Two columns of 7 at 54px
		--     pitch end at y=546, with room to spare.
		-- The old single-column comment claimed "at most 8 domains" — stale by
		-- ~2x. The true ceiling is 14 rows: 4 always-available domains + the
		-- skirmisher's 11 (its largest reachable set at any one tier is 9,
		-- since gun-bound domains zero out on promotion) + the CLASS TIER row.
		-- 2 columns x 7 = 14 covers it exactly.
		--
		-- Highest domain id with a baked row plate. Domains ABOVE this render
		-- as text until their art lands — RegisterImage on a missing image is
		-- undefined behavior, so never reach for a plate that does not exist.
		local PAUSE_PLATE_MAX = 37   -- r24 CLASS TIER + r25..r31 gun-unique plates landed 2026-08-22 (files (31).zip); r32 SPRINT ARMOR 2026-08-23 (files (32).zip); r33 SECOND WIND + r34 MOMENTUM 2026-08-23 (files (35).zip); r35 GIANT SLAYER + r36 BACK ARMOR 2026-08-23 (files (38).zip); r37 FORCED MARCH 2026-08-24 (files (39).zip); 38+ would be text rows

		local COL_X    = { 102, 462 }   -- column left edges; col B ends at 810 (< BGBlood 814)
		local COL_W    = 348
		local ROW_Y0   = 176            -- 8px under the re-cut header (bottom 168)
		local ROW_H    = 54
		local ROWS_MAX = 7              -- per column; 2 x 7 = 14 = the real ceiling
		local PLATE_W  = 191            -- 300x44 art -> 191x28, aspect 6.82 held
		local PLATE_H  = 28
		local PIP_D    = 12
		local PIP_PITCH = 14

		-- Balance the columns: <=7 rows stay in one column (a short list reads
		-- worse split), 8..14 split evenly.
		local shown = #todRows
		local overflow = 0
		if shown > ROWS_MAX * 2 then
			overflow = shown - ROWS_MAX * 2
			shown = ROWS_MAX * 2
		end
		local perCol = shown
		if shown > ROWS_MAX then
			perCol = math.ceil( shown / 2 )
		end

		for i = 1, shown do
			local r = todRows[ i ]
			local col = 1
			local idx = i
			if i > perCol then
				col = 2
				idx = i - perCol
			end
			local cx = COL_X[ col ]
			local y = ROW_Y0 + ( idx - 1 ) * ROW_H

			if r.id <= PAUSE_PLATE_MAX then
				local plate = LUI.UIImage.new()
				plate:setLeftRight( true, false, cx, cx + PLATE_W )
				plate:setTopBottom( true, false, y, y + PLATE_H )
				plate:setImage( RegisterImage( string.format( "i_tod_pause_r%02d", r.id ) ) )
				self:addElement( plate )
			else
				local label = LUI.UIText.new()
				label:setLeftRight( true, false, cx + 4, cx + PLATE_W )
				label:setTopBottom( true, false, y + 4, y + 24 )
				label:setText( Engine.Localize( r.name ) )
				label:setTTF( "fonts/orbitron.ttf" )
				label:setRGB( 0.86, 0.9, 0.95 )
				label:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
				self:addElement( label )
			end

			-- Level pips: FILLED to the owned level, then the EMPTY pip out to the
			-- cap, so the panel shows how much room is left as well as what you
			-- hold. Capped at 10 (the highest domain max) to bound the row width.
			-- i_tod_pause_pip_empty is a real hollow unlit ring (files (36).zip,
			-- 2026-08-23); before it landed this drew the FILLED pip at alpha
			-- 0.22, which read as a ghost of a filled pip rather than an
			-- empty slot.
			local pipN = r.max
			if pipN > 10 then pipN = 10 end
			if pipN < r.lvl then pipN = r.lvl end
			for p = 1, pipN do
				local px = cx + PLATE_W + 7 + ( p - 1 ) * PIP_PITCH
				local pip = LUI.UIImage.new()
				pip:setLeftRight( true, false, px, px + PIP_D )
				pip:setTopBottom( true, false, y + 8, y + 8 + PIP_D )
				if p > r.lvl then
					pip:setImage( RegisterImage( "i_tod_pause_pip_empty" ) )
				else
					pip:setImage( RegisterImage( "i_tod_pause_pip" ) )
				end
				self:addElement( pip )
			end

			-- WHAT IT DOES, at this player's current level.
			local effLine = LUI.UIText.new()
			effLine:setLeftRight( true, false, cx + 2, cx + COL_W - 4 )
			effLine:setTopBottom( true, false, y + 29, y + 42 )
			effLine:setText( r.eff )
			effLine:setTTF( "fonts/orbitron.ttf" )
			effLine:setRGB( 0.42, 0.92, 1 )
			effLine:setScale( 0.82 )
			effLine:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
			self:addElement( effLine )

			-- HOW IT ACTIVATES — trigger, window, cooldown, stack cap.
			if r.act ~= "" then
				local actLine = LUI.UIText.new()
				actLine:setLeftRight( true, false, cx + 2, cx + COL_W - 4 )
				actLine:setTopBottom( true, false, y + 41, y + 54 )
				actLine:setText( r.act )
				actLine:setTTF( "fonts/orbitron.ttf" )
				actLine:setRGB( 0.6, 0.66, 0.74 )
				actLine:setScale( 0.72 )
				actLine:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
				self:addElement( actLine )
			end
		end

		-- Can only fire if a future GSC change pushes past 14 concurrent
		-- domains. Better a truthful count than silently dropped rows.
		if overflow > 0 then
			local more = LUI.UIText.new()
			more:setLeftRight( true, false, COL_X[ 1 ], COL_X[ 1 ] + COL_W )
			more:setTopBottom( true, false, ROW_Y0 + ROWS_MAX * ROW_H + 4, ROW_Y0 + ROWS_MAX * ROW_H + 20 )
			more:setText( "+" .. overflow .. " MORE" )
			more:setTTF( "fonts/orbitron.ttf" )
			more:setRGB( 0.6, 0.66, 0.74 )
			more:setScale( 0.8 )
			more:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
			self:addElement( more )
		end
	elseif #todRows > 0 then
		-- text fallback (pre-art path)
		self.TodUpgHeader = LUI.UIText.new()
		self.TodUpgHeader:setLeftRight( true, false, 102, 380 )
		self.TodUpgHeader:setTopBottom( true, false, 132, 149 )
		self.TodUpgHeader:setText( Engine.Localize( "YOUR UPGRADES" ) )
		self.TodUpgHeader:setTTF( "fonts/orbitron.ttf" )
		self.TodUpgHeader:setRGB( 0.35, 0.9, 1 )
		self.TodUpgHeader:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
		self:addElement( self.TodUpgHeader )

		local y = 158
		for i = 1, #todRows do
			local r = todRows[ i ]
			local t = LUI.UIText.new()
			t:setLeftRight( true, false, 102, 380 )
			t:setTopBottom( true, false, y, y + 14 )
			t:setText( Engine.Localize( r.name .. "  " .. r.lvl .. "/" .. r.max ) )
			t:setTTF( "fonts/orbitron.ttf" )
			t:setRGB( 0.86, 0.9, 0.95 )
			t:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
			self:addElement( t )

			local d = LUI.UIText.new()
			d:setLeftRight( true, false, 102, 500 )
			d:setTopBottom( true, false, y + 14, y + 26 )
			d:setText( r.eff )
			d:setTTF( "fonts/orbitron.ttf" )
			d:setRGB( 0.6, 0.66, 0.74 )
			d:setScale( 0.75 )
			d:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
			self:addElement( d )

			y = y + 30
		end
	end

	-- Game Time Label
	self.GameTimeLabel = LUI.UIText.new()
    self.GameTimeLabel:setLeftRight(true, false, 925, 1033)
    self.GameTimeLabel:setTopBottom(true, false, 173, 187)
	self.GameTimeLabel:setText(Engine.Localize("Game Time:"))
	self.GameTimeLabel:setTTF("fonts/orbitron.ttf")
	self.GameTimeLabel:setRGB(1, 1, 1)
	self.GameTimeLabel:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
	self:addElement(self.GameTimeLabel)

	-- Game Time Value (Official Method)
	self.GameTimeValue = LUI.UIText.new()
    self.GameTimeValue:setLeftRight(true, false, 1041, 1114)
    self.GameTimeValue:setTopBottom(true, false, 172, 188)
	self.GameTimeValue:setTTF("fonts/ltromatic.ttf")
	self.GameTimeValue:setRGB(0.878, 0, 0)
	self.GameTimeValue:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
	self.GameTimeValue:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "hudItems.time.game_start_time"), function(model)
		local time = Engine.GetModelValue(model)
		if time then
			self.GameTimeValue:setupServerTime(time)
		end
	end)
	self:addElement(self.GameTimeValue)

	-- Options Header Text (hidden by default, shown with options)
	self.OptionsHeaderText = LUI.UIText.new()
    self.OptionsHeaderText:setLeftRight(true, false, 907, 1168)
    self.OptionsHeaderText:setTopBottom(true, false, 108, 132)
	self.OptionsHeaderText:setText(Engine.Localize("Options & Controls"))
	self.OptionsHeaderText:setTTF("fonts/orbitron.ttf")
	self.OptionsHeaderText:setRGB(1, 1, 1)
	self.OptionsHeaderText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
	self.OptionsHeaderText:setAlpha(0)
	self:addElement(self.OptionsHeaderText)

	-- Pause Menu Text (hidden when options are shown)
	self.PauseMenuText = LUI.UIText.new()
	self.PauseMenuText:setLeftRight(true, false, 952, 1127)
	self.PauseMenuText:setTopBottom(true, false, 44, 68)
	self.PauseMenuText:setText(Engine.Localize("Pause Menu"))
	self.PauseMenuText:setTTF("fonts/orbitron.ttf")
	self.PauseMenuText:setRGB(1, 1, 1)
	self.PauseMenuText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.PauseMenuText)

	-- Small Top Buttons List
	self.SmallButtonList = LUI.UIList.new(self, controller, 2, 0, nil, true, false, 0, 0, false, false)
	self.SmallButtonList:makeFocusable()
	self.SmallButtonList:setLeftRight(true, false, 897, 1176)
	self.SmallButtonList:setTopBottom(true, false, 101, 142)
	self.SmallButtonList:setWidgetType(CoD.AetheriumSmallButton)
	self.SmallButtonList:setHorizontalCount(4)
	self.SmallButtonList:setSpacing(9)
	self.SmallButtonList:setDataSource("AetheriumSmallMenuButtons")
	self.SmallButtonList:registerEventHandler("gain_focus", function(element, event)
		local retVal = nil
		if element.gainFocus then
			retVal = element:gainFocus(event)
		elseif element.super.gainFocus then
			retVal = element.super:gainFocus(event)
		end
		CoD.Menu.UpdateButtonShownState(element, self, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS)
		return retVal
	end)
	self.SmallButtonList:registerEventHandler("lose_focus", function(element, event)
		local retVal = nil
		if element.loseFocus then
			retVal = element:loseFocus(event)
		elseif element.super.loseFocus then
			retVal = element.super:loseFocus(event)
		end
		return retVal
	end)
	self:AddButtonCallbackFunction(self.SmallButtonList, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "ENTER", function(element, menu, controller, model)
		ProcessListAction(self, element, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "MENU_SELECT")
		return true
	end, false)
	self:addElement(self.SmallButtonList)
	self.SmallButtonList.id = "SmallButtonList"

	-- Button List (replaces individual button images)
	self.ButtonList = LUI.UIList.new(self, controller, 5, 0, nil, false, false, 0, 0, false, false)
	self.ButtonList:makeFocusable()
	self.ButtonList:setLeftRight(true, false, 868, 1210)
	self.ButtonList:setTopBottom(true, false, 221, 560)
	self.ButtonList:setWidgetType(CoD.AetheriumMenuButton)
	self.ButtonList:setVerticalCount(7)
	self.ButtonList:setSpacing(10)
	self.ButtonList:setDataSource("AetheriumStartMenuButtons")
	self.ButtonList:registerEventHandler("gain_focus", function(element, event)
		local retVal = nil
		if element.gainFocus then
			retVal = element:gainFocus(event)
		elseif element.super.gainFocus then
			retVal = element.super:gainFocus(event)
		end
		CoD.Menu.UpdateButtonShownState(element, self, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS)
		return retVal
	end)
	self.ButtonList:registerEventHandler("lose_focus", function(element, event)
		local retVal = nil
		if element.loseFocus then
			retVal = element:loseFocus(event)
		elseif element.super.loseFocus then
			retVal = element.super:loseFocus(event)
		end
		return retVal
	end)
	self:AddButtonCallbackFunction(self.ButtonList, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "ENTER", function(element, menu, controller, model)
		ProcessListAction(self, element, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "MENU_SELECT")
		return true
	end, false)
	self:addElement(self.ButtonList)
	self.ButtonList.id = "ButtonList"
	
	-- Options List (hidden by default, shown when Game Settings is clicked)
	self.OptionsList = LUI.UIList.new(self, controller, 5, 0, nil, false, false, 0, 0, false, false)
	self.OptionsList:makeFocusable()
	self.OptionsList:setLeftRight(true, false, 868, 1210)
	self.OptionsList:setTopBottom(true, false, 221, 560)
	self.OptionsList:setWidgetType(CoD.AetheriumMenuButton)
	self.OptionsList:setVerticalCount(9)
	self.OptionsList:setSpacing(10)
	self.OptionsList:setDataSource("AetheriumOptionsButtons")
	self.OptionsList:setAlpha(0)
	self.OptionsList:registerEventHandler("gain_focus", function(element, event)
		local retVal = nil
		if element.gainFocus then
			retVal = element:gainFocus(event)
		elseif element.super.gainFocus then
			retVal = element.super:gainFocus(event)
		end
		CoD.Menu.UpdateButtonShownState(element, self, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS)
		return retVal
	end)
	self.OptionsList:registerEventHandler("lose_focus", function(element, event)
		local retVal = nil
		if element.loseFocus then
			retVal = element:loseFocus(event)
		elseif element.super.loseFocus then
			retVal = element.super:loseFocus(event)
		end
		return retVal
	end)
	self:AddButtonCallbackFunction(self.OptionsList, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "ENTER", function(element, menu, controller, model)
		ProcessListAction(self, element, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "MENU_SELECT")
		return true
	end, false)
	
	-- Add fade animations to OptionsList
	self.OptionsList.clipsPerState = {
		DefaultState = {
			FadeIn = function()
				self.OptionsList:completeAnimation()
				self.OptionsList:setAlpha(1, 150)
			end,
			FadeOut = function()
				self.OptionsList:completeAnimation()
				self.OptionsList:setAlpha(0, 150)
			end
		}
	}
	
	self:addElement(self.OptionsList)
	self.OptionsList.id = "OptionsList"
	
	-- Add fade animations to ButtonList and SmallButtonList
	self.ButtonList.clipsPerState = {
		DefaultState = {
			FadeIn = function()
				self.ButtonList:completeAnimation()
				self.ButtonList:setAlpha(1, 150)
			end,
			FadeOut = function()
				self.ButtonList:completeAnimation()
				self.ButtonList:setAlpha(0, 150)
			end
		}
	}
	
	self.SmallButtonList.clipsPerState = {
		DefaultState = {
			FadeIn = function()
				self.SmallButtonList:completeAnimation()
				self.SmallButtonList:setAlpha(1, 150)
			end,
			FadeOut = function()
				self.SmallButtonList:completeAnimation()
				self.SmallButtonList:setAlpha(0, 150)
			end
		}
	}
	
	-- Add fade animations to OptionsHeaderText
	self.OptionsHeaderText.clipsPerState = {
		DefaultState = {
			FadeIn = function()
				self.OptionsHeaderText:completeAnimation()
				self.OptionsHeaderText:setAlpha(1, 150)
			end,
			FadeOut = function()
				self.OptionsHeaderText:completeAnimation()
				self.OptionsHeaderText:setAlpha(0, 150)
			end
		}
	}

	-- Signature Images (optional)
	if ShowSignatures then
		self.KingsLayerKyleSignature = LUI.UIImage.new()
		self.KingsLayerKyleSignature:setLeftRight(true, false, 0, 125)
		self.KingsLayerKyleSignature:setTopBottom(true, false, 637, 720)
		self.KingsLayerKyleSignature:setImage(RegisterImage("i_mtl_ui_icon_kingslayer_kyle_signature"))
		self:addElement(self.KingsLayerKyleSignature)

		self.OwenC137Signature = LUI.UIImage.new()
		self.OwenC137Signature:setLeftRight(true, false, 128, 253)
		self.OwenC137Signature:setTopBottom(true, false, 637, 720)
		self.OwenC137Signature:setImage(RegisterImage("i_mtl_ui_icon_owenc137_signature"))
		self:addElement(self.OwenC137Signature)

		self.ShidouriSignature = LUI.UIImage.new()
		self.ShidouriSignature:setLeftRight(true, false, 255, 380)
		self.ShidouriSignature:setTopBottom(true, false, 637, 720)
		self.ShidouriSignature:setImage(RegisterImage("i_mtl_ui_icon_shidouri_signature"))
		self:addElement(self.ShidouriSignature)

		self.MadgazSignature = LUI.UIImage.new()
		self.MadgazSignature:setLeftRight(true, false, 383, 508)
		self.MadgazSignature:setTopBottom(true, false, 637, 720)
		self.MadgazSignature:setImage(RegisterImage("i_mtl_ui_icon_madgaz_signature"))
		self:addElement(self.MadgazSignature)
	end

	-- Button Callbacks
	self:AddButtonCallbackFunction(self, controller, Enum.LUIButton.LUI_KEY_XBB_PSCIRCLE, nil, function(element, menu, controller, model)
		RefreshLobbyRoom(menu, controller)
		StartMenuGoBack(menu, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_XBB_PSCIRCLE, "MENU_BACK")
		return true
	end, false)

	self:AddButtonCallbackFunction(self, controller, Enum.LUIButton.LUI_KEY_START, "M", function(element, menu, controller, model)
		RefreshLobbyRoom(menu, controller)
		StartMenuGoBack(menu, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_START, "MENU_DISMISS_MENU")
		return true
	end, false)

	self:AddButtonCallbackFunction(self, controller, Enum.LUIButton.LUI_KEY_NONE, "ESCAPE", function(element, menu, controller, model)
		RefreshLobbyRoom(menu, controller)
		StartMenuGoBack(menu, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_NONE, "")
		return true
	end, false, true)

	self:processEvent({
		name = "menu_loaded",
		controller = controller
	})

	self:processEvent({
		name = "update_state",
		menu = self
	})

	-- [tod] game-over mode visuals (see TodGoActive above): retitle, hide the
	-- pause-only top row of settings icons (and take it out of focus navigation
	-- so up/down can never land on an invisible list), and put initial focus
	-- straight on the two-entry button list. One guarded block — a failure here
	-- may cost polish but can never take down the menu.
	local todGo = TodGoActive(controller)
	if todGo then
		pcall(function()
			self.PauseMenuText:setText(Engine.Localize("Game Over"))
			self.SmallButtonList:setAlpha(0)
		end)
		pcall(function()
			self.SmallButtonList:makeNotFocusable()
		end)
	end

	if todGo then
		self.ButtonList:processEvent({
			name = "gain_focus",
			controller = controller
		})
	elseif not self:restoreState() then
		-- Give initial focus to small buttons
		self.SmallButtonList:processEvent({
			name = "gain_focus",
			controller = controller
		})
	end

	if PostLoadFunc then
		PostLoadFunc(self, controller)
	end

	LUI.OverrideFunction_CallOriginalSecond(self, "close", function(element)
		element.DarkOverlay:close()
		element.BGMain:close()
		element.BGRight:close()
		element.BGBlood:close()
		element.GameModeIcon:close()
		element.Logo:close()
		element.MapName:close()
		element.RoundLabel:close()
		element.RoundNumber:close()
		element.GameModeText:close()
		element.GameTimeLabel:close()
	    element.GameTimeValue:close()
	    element.SmallButtonList:close()
		element.ButtonList:close()
		if ShowSignatures then
			element.KingsLayerKyleSignature:close()
			element.OwenC137Signature:close()
			element.ShidouriSignature:close()
			element.MadgazSignature:close()
		end
		Engine.UnsubscribeAndFreeModel(Engine.GetModel(Engine.GetModelForController(controller), "StartMenu_Main.buttonPrompts"))
	end)

	return self
end