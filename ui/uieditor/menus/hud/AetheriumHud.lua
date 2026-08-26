-- Aetherium HUD Main File
-- Custom themed HUD for zm_weapon_ports

-- Custom Pause Menu
require( "ui.uieditor.menus.StartMenu.AetheriumStartMenu" )

-- Aetherium Widgets
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPerksContainer" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumLoadout" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPlayerInfo" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPartyPlayers" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumCompass" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPlusPointsContainer" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPowerupsContainer" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPowerupNotification" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumRoundCounter" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumGobbleGum" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumScoreboard" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumKillFeed" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumSpecialWeapon" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumThirdPersonCrosshair" )

-- Include standard HUD components
require( "ui.uieditor.widgets.DynamicContainerWidget" )
require( "ui.uieditor.widgets.Notifications.Notification" )
require( "ui.uieditor.widgets.HUD.ZM_NotifFactory.ZmNotifBGB_ContainerFactory" )
require( "ui.uieditor.widgets.HUD.ZM_CursorHint.ZMCursorHintNew" )  -- Custom cursor hint widget (red tint test)
require( "ui.uieditor.widgets.HUD.CenterConsole.CenterConsole" )
require( "ui.uieditor.widgets.HUD.DeadSpectate.DeadSpectate" )
require( "ui.uieditor.widgets.MPHudWidgets.ScorePopup.MPScr" )
require( "ui.uieditor.widgets.HUD.ZM_PrematchCountdown.ZM_PrematchCountdown" )
require("ui.uieditor.widgets.HUD.ZM_TimeBar.ZM_BeastmodeTimeBarWidget")
require("ui.uieditor.widgets.ZMInventory.RocketShieldBluePrint.RocketShieldBlueprintWidget")
require( "ui.uieditor.widgets.Chat.inGame.IngameChatClientContainer" )
require( "ui.uieditor.widgets.BubbleGumBuffs.BubbleGumPackInGame" )

-- Call Common Zombie HUD functions (loads notification systems)
CoD.Zombie.CommonHudRequire()

-- ZMPlayerList DataSource for player visibility
DataSources.ZMPlayerList = {
	getModel = function ( controller )
		return Engine.CreateModel( Engine.GetModelForController( controller ), "PlayerList" )
	end
}

-- DON'T use CommonHudRequire or Common PreLoad/PostLoad functions
-- They add default widgets (ammo, perks, etc.) that we're replacing

local SetPlayerHealthModels = function ( self, controller )
	local controllerModel = Engine.GetModelForController( controller )
	
	-- Pre-create health models for all players
	for index = 0, 7 do
		local healthModel = Engine.CreateModel( controllerModel, "player_health_" .. index )
		Engine.SetModelValue( healthModel, 1 )
	end
end

local PreLoadFunc = function ( self, controller )
	-- Common Zombie HUD PreLoad (handles notifications, etc.)
	CoD.Zombie.CommonPreLoadHud( self, controller )
	
	-- Map info for start menu
	CoD.UsermapName = "Tower of Doom"
	CoD.UsermapDesc = "Tower of Doom: Cybercity"
	CoD.InventoryDisabled = true
	
	-- Pre-create health models
	SetPlayerHealthModels( self, controller )
end

local PostLoadFunc = function ( self, controller )
	-- Common Zombie HUD PostLoad (handles notifications, powerups, etc.)
	CoD.Zombie.CommonPostLoadHud( self, controller )
	
	-- Re-create models on fast restart ( GS immediately updates correct values)
	self:subscribeToModel( Engine.GetModel( Engine.GetGlobalModel(), "fastRestart" ), function ( model )
		SetPlayerHealthModels( self, controller )
	end )
end

LUI.createMenu.T7Hud_zm_factory = function ( controller )
	local self = CoD.Menu.NewForUIEditor( "T7Hud_zm_factory" )

	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end

	self.soundSet = "HUD"
	self:setOwner( controller )
	self:setLeftRight( true, true, 0, 0 )
	self:setTopBottom( true, true, 0, 0 )
	self:playSound( "menu_open", controller )
	self.buttonModel = Engine.CreateModel( Engine.GetModelForController( controller ), "T7Hud_zm_factory.buttonPrompts" )
	self.anyChildUsesUpdateState = true

	-- ========================================
	-- AETHERIUM CUSTOM WIDGETS
	-- ========================================

	-- Compass Widget — REMOVED (user 2026-08-24: "remove the compass at top of
	-- the map"). Left commented rather than deleted so it is a four-line
	-- uncomment to bring back.
	--
	-- NOTHING ELSE HAS TO CHANGE. The three places further down that drive the
	-- scoreboard fade (setAlpha 1 / targetAlpha) are each already wrapped in
	-- `if self.AetheriumCompass then`, so with the field never assigned they are
	-- no-ops. The require() at the top stays too: it only defines the class, and
	-- keeping it means the widget file and its zpkg rawfile line remain a
	-- consistent vendored kit instead of a half-removed one.
	--
	-- self.AetheriumCompass = CoD.AetheriumCompass.new( self, controller )
	-- self.AetheriumCompass:setLeftRight( true, false, 0, 1280 )
	-- self.AetheriumCompass:setTopBottom( true, false, 0, 720 )
	-- self:addElement( self.AetheriumCompass )

	-- Loadout Widget (Ammo)
	self.AetheriumLoadout = CoD.AetheriumLoadout.new( self, controller )
	self.AetheriumLoadout:setLeftRight( true, false, 0, 1280 )
	self.AetheriumLoadout:setTopBottom( true, false, 0, 720 )
	self:addElement( self.AetheriumLoadout )

	-- GobbleGum Inventory Widget
	self.AetheriumGobbleGum = CoD.AetheriumGobbleGum.new( self, controller )
	self.AetheriumGobbleGum.id = "AetheriumGobbleGum"
	self:addElement( self.AetheriumGobbleGum )

	-- Player Info Widget (Main Player) - Use UIList with PlayerListZM DataSource
	self.AetheriumPlayerInfo = LUI.UIList.new( self, controller, 2, 0, nil, false, false, 0, 0, false, false )
	self.AetheriumPlayerInfo:makeFocusable()
	self.AetheriumPlayerInfo:setLeftRight( true, false, 0, 1280 )
	self.AetheriumPlayerInfo:setTopBottom( true, false, 0, 720 )
	self.AetheriumPlayerInfo:setWidgetType( CoD.AetheriumPlayerInfo )
	self.AetheriumPlayerInfo:setDataSource( "PlayerListZM" )
	self:addElement( self.AetheriumPlayerInfo )

	-- Party Members (Players 1-3) - Dynamic widget with index-based positioning
	-- Official BO3 pattern: single widget file, multiple instances with different player indices
	self.PartyPlayers = {}
	for i = 1, 3 do
		local partyWidget = CoD.AetheriumPartyPlayers.new( self, controller, i )
		partyWidget:setLeftRight( true, false, 0, 1280 )
		partyWidget:setTopBottom( true, false, 0, 720 )
		partyWidget:subscribeToGlobalModel( controller, "ZMPlayerList", tostring(i), function ( model )
			partyWidget:setModel( model, controller )
		end )
		self:addElement( partyWidget )
		self.PartyPlayers[i] = partyWidget
	end

	-- Powerups Container
	self.AetheriumPowerupsContainer = CoD.AetheriumPowerupsContainer.new( self, controller )
	self.AetheriumPowerupsContainer:setLeftRight( true, false, 0, 1280 )
	self.AetheriumPowerupsContainer:setTopBottom( true, false, 0, 720 )
	self:addElement( self.AetheriumPowerupsContainer )
	
	self.AetheriumPowerupNotification = CoD.AetheriumPowerupNotification.new( self, controller )
	self.AetheriumPowerupNotification:setLeftRight( true, false, 0, 1280 )
	self.AetheriumPowerupNotification:setTopBottom( true, false, 0, 720 )
	self:addElement( self.AetheriumPowerupNotification )

	-- Round Counter (Top Right)
	self.AetheriumRoundCounter = CoD.AetheriumRoundCounter.new( self, controller )
	self.AetheriumRoundCounter:setLeftRight( true, false, 0, 1280 )
	self.AetheriumRoundCounter:setTopBottom( true, false, 0, 720 )
	self:addElement( self.AetheriumRoundCounter )
	
	-- ========================================
	-- STANDARD HUD COMPONENTS
	-- ========================================

	self.fullscreenContainer = CoD.DynamicContainerWidget.new( self, controller )
	self.fullscreenContainer:setLeftRight( false, false, -640, 640 )
	self.fullscreenContainer:setTopBottom( false, false, -360, 360 )
	self:addElement( self.fullscreenContainer )

	-- DISABLED: Default Notifications widget (includes kill feed at top center)
	-- Using custom AetheriumKillFeed widget instead
	-- self.Notifications = CoD.Notification.new( self, controller )
	-- self.Notifications:setLeftRight( true, true, 0, 0 )
	-- self.Notifications:setTopBottom( true, true, 0, 0 )
	-- self:addElement( self.Notifications )

	self.ZmNotifBGBContainerFactory = CoD.ZmNotifBGB_ContainerFactory.new( self, controller )
	self.ZmNotifBGBContainerFactory:setLeftRight( false, false, -156, 156 )
	self.ZmNotifBGBContainerFactory:setTopBottom( true, false, -6, 247 )
	self.ZmNotifBGBContainerFactory:setScale( 0.75 )
	self:addElement( self.ZmNotifBGBContainerFactory )

	self.ZmNotifBGBContainerFactory:subscribeToGlobalModel( controller, "PerController", "scriptNotify", function ( model )
		if IsParamModelEqualToString( model, "zombie_bgb_token_notification" ) then
			AddZombieBGBTokenNotification( self, self.ZmNotifBGBContainerFactory, controller, model )
		elseif IsParamModelEqualToString( model, "zombie_bgb_notification" ) then
			AddZombieBGBNotification( self, self.ZmNotifBGBContainerFactory, model )
		-- Disabled default zombie_notification (power-up pickups) - using AetheriumPowerupNotification instead
		-- elseif IsParamModelEqualToString( model, "zombie_notification" ) then
		-- 	AddZombieNotification( self, self.ZmNotifBGBContainerFactory, model )
		end
	end )

	self.ZMCursorHint = CoD.ZMCursorHintNew.new( self, controller )
	self.ZMCursorHint:setLeftRight( true, false, 0, 1280 )
	self.ZMCursorHint:setTopBottom( true, false, 0, 720 )
	self.ZMCursorHint:mergeStateConditions( {
		{
			stateName = "Active_1x1",
			condition = function ( menu, element, event )
				return IsCursorHintActive( controller ) and not Engine.IsVisibilityBitSet( controller, Enum.UIVisibilityBit.BIT_UI_ACTIVE )
			end
		}
	} )
	self.ZMCursorHint:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.showCursorHint" ), function ( model )
		self:updateElementState( self.ZMCursorHint, {
			name = "model_validation",
			menu = self,
			modelValue = Engine.GetModelValue( model ),
			modelName = "hudItems.showCursorHint"
		} )
	end )
	self:addElement( self.ZMCursorHint )

	self.CenterConsole = CoD.CenterConsole.new( self, controller )
	self.CenterConsole:setLeftRight( false, false, -370, 370 )
	self.CenterConsole:setTopBottom( true, false, 68.5, 166.5 )
	self:addElement( self.CenterConsole )

	self.DeadSpectate = CoD.DeadSpectate.new( self, controller )
	self.DeadSpectate:setLeftRight( true, true, 0, 0 )
	self.DeadSpectate:setTopBottom( true, true, 0, 0 )
	self:addElement( self.DeadSpectate )

	self.MPScr = CoD.MPScr.new( self, controller )
	self.MPScr:setLeftRight( true, true, 0, 0 )
	self.MPScr:setTopBottom( true, true, 0, 0 )
	self:addElement( self.MPScr )

	-- DISABLED: MPScr score_event subscription (causes duplicate kill feed at top center)
	-- Using custom AetheriumKillFeed widget instead
	-- self.MPScr:subscribeToGlobalModel( controller, "PerController", "scriptNotify", function ( ModelRef )
	-- 	if IsParamModelEqualToString( ModelRef, "score_event" ) and PropertyIsTrue( self, "menuLoaded" ) then
	-- 		PlayClipOnElement( self, {
	-- 			elementName = "MPScr",
	-- 			clipName = "NormalScore"
	-- 		}, controller )
	-- 		SetMPScoreText( self, self.MPScr, controller, ModelRef )
	-- 	end
	-- end )

	self.ZMPrematchCountdown = CoD.ZM_PrematchCountdown.new( self, controller )
	self.ZMPrematchCountdown:setLeftRight( false, false, -100, 100 )
	self.ZMPrematchCountdown:setTopBottom( false, false, -25, 25 )
	self:addElement( self.ZMPrematchCountdown )

	-- Custom Aetherium Scoreboard (replaces ScoreboardWidgetCP)
	self.AetheriumScoreboard = CoD.AetheriumScoreboard.new( self, controller )
	self.AetheriumScoreboard:setLeftRight( true, true, 0, 0 )
	self.AetheriumScoreboard:setTopBottom( true, true, 0, 0 )
	self:addElement( self.AetheriumScoreboard )

	-- Kill Feed Widget
	self.AetheriumKillFeed = CoD.AetheriumKillFeed.new( self, controller )
	self.AetheriumKillFeed:setLeftRight( true, true, 0, 0 )
	self.AetheriumKillFeed:setTopBottom( true, true, 0, 0 )
	self:addElement( self.AetheriumKillFeed )

	self.SpecialWeapon = CoD.AetheriumSpecialWeapon.new( self, controller )
	self:addElement( self.SpecialWeapon )

	-- Third Person Crosshair (shows when in third person mode)
	self.ThirdPersonCrosshair = CoD.AetheriumThirdPersonCrosshair.new( self, controller )
	self.ThirdPersonCrosshair:setLeftRight( true, true, 0, 0 )
	self.ThirdPersonCrosshair:setTopBottom( true, true, 0, 0 )
	self:addElement( self.ThirdPersonCrosshair )

	self.ZMBeastBar = CoD.ZM_BeastmodeTimeBarWidget.new( self, controller )
	self.ZMBeastBar:setLeftRight( false, false, -242.5, 321.5 )
	self.ZMBeastBar:setTopBottom( false, true, -174, -18 )
	self.ZMBeastBar:setScale( 0.7 )
	self:addElement( self.ZMBeastBar )

	self.RocketShieldBlueprintWidget = CoD.RocketShieldBlueprintWidget.new( self, controller )
	self.RocketShieldBlueprintWidget:setLeftRight( true, false, -36.5, 277.5 )
	self.RocketShieldBlueprintWidget:setTopBottom( true, false, 104, 233 )
	self.RocketShieldBlueprintWidget:setScale( 0.8 )
	self:addElement( self.RocketShieldBlueprintWidget )

	self.RocketShieldBlueprintWidget.StateTable = {
		{
			stateName = "Scoreboard",
			condition = function ( self, ItemRef, UpdateTable )
				local condition = Engine.IsVisibilityBitSet( controller, Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN )
				if condition then
					condition = AlwaysFalse()
				end
				return condition
			end
		}
	}
	self.RocketShieldBlueprintWidget:mergeStateConditions( self.RocketShieldBlueprintWidget.StateTable )

	self.IngameChatClientContainer = CoD.IngameChatClientContainer.new( self, controller )
	self.IngameChatClientContainer:setLeftRight( true, false, 0, 360 )
	self.IngameChatClientContainer:setTopBottom( true, false, -2.5, 717.5 )
	self:addElement( self.IngameChatClientContainer )

	self.IngameChatClientContainer0 = CoD.IngameChatClientContainer.new( self, controller )
	self.IngameChatClientContainer0:setLeftRight( true, false, 0, 360 )
	self.IngameChatClientContainer0:setTopBottom( true, false, -2.5, 717.5 )
	self:addElement( self.IngameChatClientContainer0 )

	self.BubbleGumPackInGame = CoD.BubbleGumPackInGame.new( self, controller )
	self.BubbleGumPackInGame:setLeftRight( true, false, 110, 170 )
	self.BubbleGumPackInGame:setTopBottom( false, true, -186, -126 )
	self.BubbleGumPackInGame:setAlpha( 0 ) -- Hidden
	self:addElement( self.BubbleGumPackInGame )

	-- Register menu_loaded event handler (REQUIRED for scriptNotify subscriptions)
	self:registerEventHandler( "menu_loaded", function ( element, event )
		SetProperty( self, "menuLoaded", true )
		return element:dispatchEventToChildren( event )
	end )

	-- Process menu_loaded event (triggers the handler above)
	self:processEvent( {
		name = "menu_loaded",
		controller = controller
	} )

	-- ========================================
	-- CLOSE FUNCTION (Memory Cleanup)
	-- ========================================
	LUI.OverrideFunction_CallOriginalSecond( self, "close", function ( element )
		element.fullscreenContainer:close()
		-- element.Notifications:close()  -- Disabled (using custom kill feed)
		element.ZmNotifBGBContainerFactory:close()
		element.ZMCursorHint:close()
		element.CenterConsole:close()
		element.DeadSpectate:close()
		element.MPScr:close()
		element.ZMPrematchCountdown:close()
		element.AetheriumScoreboard:close()
		element.AetheriumKillFeed:close()
		element.ZMBeastBar:close()
		element.RocketShieldBlueprintWidget:close()
		element.IngameChatClientContainer:close()
		element.IngameChatClientContainer0:close()
		element.BubbleGumPackInGame:close()
		if element.SpecialWeapon then
			element.SpecialWeapon:close()
		end
	if element.PartyPlayers then
		for i = 1, 3 do
			if element.PartyPlayers[i] then
				element.PartyPlayers[i]:close()
			end
		end
	end
	end )

	-- ========================================
	-- HIDE HUD WHEN SCOREBOARD IS OPEN
	-- ========================================
	
	-- Set initial visibility to all widgets (visible by default)
	if self.AetheriumCompass then
		self.AetheriumCompass:setAlpha( 1 )
	end
	if self.AetheriumLoadout then
		self.AetheriumLoadout:setAlpha( 1 )
	end
	if self.AetheriumGobbleGum then
		self.AetheriumGobbleGum:setAlpha( 1 )
	end
	if self.SpecialWeapon then
		self.SpecialWeapon:setAlpha( 1 )
	end
	if self.AetheriumPlayerInfo then
		self.AetheriumPlayerInfo:setAlpha( 1 )
	end
	if self.PartyPlayers then
		for i = 1, 3 do
			if self.PartyPlayers[i] then
				self.PartyPlayers[i]:setAlpha( 1 )
			end
		end
	end
	if self.AetheriumPowerupsContainer then
		self.AetheriumPowerupsContainer:setAlpha( 1 )
	end
	if self.AetheriumPowerupNotification then
		self.AetheriumPowerupNotification:setAlpha( 1 )
	end
	if self.AetheriumRoundCounter then
		self.AetheriumRoundCounter:setAlpha( 1 )
	end
	
	-- Subscribe to scoreboard visibility to toggle HUD
	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN ), function ( model )
		local modelValue = Engine.GetModelValue( model )
		
		-- Hide HUD when scoreboard is open (model value will be 1), show when closed (0 or nil)
		local targetAlpha = 1
		if modelValue and modelValue ~= 0 then
			targetAlpha = 0
		end
		
		if self.AetheriumCompass then
			self.AetheriumCompass:setAlpha( targetAlpha )
		end
		if self.AetheriumLoadout then
			self.AetheriumLoadout:setAlpha( targetAlpha )
		end
		if self.AetheriumGobbleGum then
			self.AetheriumGobbleGum:setAlpha( targetAlpha )
		end
		if self.SpecialWeapon then
			self.SpecialWeapon:setAlpha( targetAlpha )
		end
		if self.AetheriumPlayerInfo then
			self.AetheriumPlayerInfo:setAlpha( targetAlpha )
		end
		if self.PartyPlayers then
			for i = 1, 3 do
				if self.PartyPlayers[i] then
					self.PartyPlayers[i]:setAlpha( targetAlpha )
				end
			end
		end
		if self.AetheriumPowerupsContainer then
			self.AetheriumPowerupsContainer:setAlpha( targetAlpha )
		end
		if self.AetheriumPowerupNotification then
			self.AetheriumPowerupNotification:setAlpha( targetAlpha )
		end
		if self.AetheriumRoundCounter then
			self.AetheriumRoundCounter:setAlpha( targetAlpha )
		end
	end )

	-- Subscribe to UI active (pause menu, etc.) to toggle HUD
	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_UI_ACTIVE ), function ( model )
		local modelValue = Engine.GetModelValue( model )
		
		-- Hide HUD when UI is active (pause menu open)
		local targetAlpha = 1
		if modelValue and modelValue ~= 0 then
			targetAlpha = 0
		end
		
		if self.AetheriumCompass then
			self.AetheriumCompass:setAlpha( targetAlpha )
		end
		if self.AetheriumLoadout then
			self.AetheriumLoadout:setAlpha( targetAlpha )
		end
		if self.AetheriumGobbleGum then
			self.AetheriumGobbleGum:setAlpha( targetAlpha )
		end
		if self.SpecialWeapon then
			self.SpecialWeapon:setAlpha( targetAlpha )
		end
		if self.AetheriumPlayerInfo then
			self.AetheriumPlayerInfo:setAlpha( targetAlpha )
		end
		if self.PartyPlayers then
			for i = 1, 3 do
				if self.PartyPlayers[i] then
					self.PartyPlayers[i]:setAlpha( targetAlpha )
				end
			end
		end
		if self.AetheriumPowerupsContainer then
			self.AetheriumPowerupsContainer:setAlpha( targetAlpha )
		end
		if self.AetheriumPowerupNotification then
			self.AetheriumPowerupNotification:setAlpha( targetAlpha )
		end
		if self.AetheriumRoundCounter then
			self.AetheriumRoundCounter:setAlpha( targetAlpha )
		end
	end )

	if PostLoadFunc then
		PostLoadFunc( self, controller )
	end

	return self
end
