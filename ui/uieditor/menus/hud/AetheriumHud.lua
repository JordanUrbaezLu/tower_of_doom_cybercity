require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodUIOwnership" )
-- [tod 2026-10-02] the shared HUD veil (the rocket rides, TodRocketCine.lua); pcall: a missing
-- rawfile means the HUD never hides, never an error
pcall( require, "ui.uieditor.widgets.HUD.AetheriumWidgets.TodHudVeil" )
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

-- [tod 2026-10-01] THE FLOOR LABEL (docs/167 item 12; lead tester: "Remove the
-- redundant 'round based zombies' text right below the round counter, replacing
-- it with the map name or floor"). The scoreboard's and the pause menu's header
-- already lead with the map name, so the line under it now says WHERE YOU ARE.
-- The code is _tod_gauge::floor_label_code's (LOCKSTEP), cached per controller
-- by the tod_party subscription below; nil until the first push, and the
-- readers fall back to the map name.
CoD.TodFloorLabelText = function ( controller )
	local by = CoD.TodFloorLabelBy
	local c = nil
	if type( by ) == "table" and controller ~= nil then
		c = by[ controller ]
	end
	if type( c ) ~= "number" or c <= 0 then
		return nil
	end
	if c >= 1100 then
		return "THE SUMMIT"
	elseif c > 1000 then
		return "SPIRE FLOOR " .. tostring( c - 1000 )
	elseif c == 100 then
		return "THE CROWN"
	end
	return "FLOOR " .. tostring( c )
end

-- DON'T use CommonHudRequire or Common PreLoad/PostLoad functions
-- They add default widgets (ammo, perks, etc.) that we're replacing

-- ===========================================================================
-- [tod v15 item 12] HUD SIZE +15%
-- ===========================================================================
-- User: "LUI aetherium HUD is too small. Can we do an all around 15% size
-- increase. Ammo crate trigger UI, alter trigger UI, etc."
--
-- WHY THIS NEEDS A HELPER AND NOT JUST setScale. Every Aetherium widget is a
-- FULL-SCREEN container (0..1280 x 0..720) holding absolutely-positioned
-- children — there is no docking or anchoring scheme and no scale factor
-- anywhere in the kit. setScale on a full-screen container scales about its
-- CENTRE, so a child sitting near a screen edge is pushed further out: the ammo
-- counter at x≈1005 lands at 640 + 365*1.15 = 1060, i.e. 55px right of where it
-- was, and anything already near the edge walks off it.
--
-- THE FIX IS ONE LINE OF ARITHMETIC. After scaling by s about the centre, a
-- point at xa maps to 640 + (xa-640)*s. Translating the container by
-- -(xa-640)*(s-1) puts that point back exactly where it started, so the widget
-- grows AROUND its own content instead of drifting. Each call therefore names
-- the anchor its content actually sits on.
--
-- setScale ON A CONTAINER IS PROVEN IN THIS FILE, not assumed: the stock kit
-- already does it to ZmNotifBGBContainerFactory (0.75), ZMBeastBar (0.7) and
-- RocketShieldBlueprintWidget (0.8), all of which are widgets with children.
--
-- ⚠️ ONE-ANCHOR LIMIT, stated because it is visible in play: a widget whose
-- content spans two anchors can only be pinned to one. AetheriumLoadout was the
-- case — its ammo block is bottom-RIGHT while its perks row is bottom-CENTRE.
-- It was pinned to the ammo block, so the perks row shifted outward.
--
-- ⚠️ THIS PARAGRAPH USED TO END "split the perks container out of Loadout and
-- scale it separately against a (640, 620) anchor." **DO NOT DO THAT.** v17.9
-- resolved it the other way and the reasoning matters, because the split looks
-- like the tidier fix and is not:
--   * The loadout is NO LONGER SCALED AT ALL (see its instantiation below). Its
--     boxes are authored at final size, so there is no anchor to be wrong about
--     and the perks row is back on centre 640 for free.
--   * The perks container therefore STAYS A CHILD of the loadout. A child
--     inherits both alpha subscriptions further down this file; a split-out
--     sibling would need both hand-added, and those two lanes
--     (BIT_SCOREBOARD_OPEN and BIT_UI_ACTIVE) are independent absolute writers
--     that already disagree with each other — closing the scoreboard with the
--     pause menu up un-hides the HUD under the menu. Adding a third subscriber
--     to that pair is not a tidy-up.
-- The remaining live users of TodScaleHud are the powerups row and the cursor
-- hint, each of which really is single-anchor. THE ROUND COUNTER LEFT THE LIST
-- IN v17.25, following the loadout: it authors its own final sizes now, and the
-- 1.15 was pushing its right edge two canvas pixels off the screen.
--
-- NOT SCALED, deliberately: the SCOREBOARD (a full-screen 1280x720 board —
-- scaling pushes its own edges off), the third-person crosshair, and the
-- upgrade/class-select menus (their own layout, already sized to taste).
local TOD_HUD_SCALE = 1.15

-- [tod v19.6/v19.7] THE LEFT PLAYER HUD, 3.5% LARGER (user: *"the player HUD on the
-- left can be increased by 10% all around. The health bar, player names, shield
-- bar, all of it"*).
--
-- ⚠️ THIS IS NOT THE SCALE v17.9 REVERTED. That one put 1.15 on the LOADOUT,
-- about a bottom-RIGHT anchor — and the loadout parents the perks row, which is
-- bottom-CENTRE, so a single anchor could not serve both and the plate ran 117px
-- off the right edge. The left HUD is single-anchor by construction: the local
-- row and all three party rows hang off one bottom-left corner and share one
-- text column at x=90. That is the case the ONE-ANCHOR LIMIT note below says an
-- anchored scale is FOR.
--
-- THE ANCHOR IS MEASURED FROM THE WIDGETS' OWN BOXES, not guessed:
--     local row    x  90..250   y 636..678
--     party rows   x  45..198   y 439..611  (87 tall on a 43 pitch)
-- so the cluster is x 45..250 / y 439..678 and its bottom-left is (45, 678).
-- (2026-10-01: the party rows moved DOWN 46.5 - AetheriumPartyPlayers baseYTop
-- 524 -> 570.5, closing the one-row gap above the local row - so the cluster
-- now starts lower, y 485.5; the anchor and every number below still hold.)
-- At 1.035 that becomes x 45..257 and a top of 431 — clear of every screen edge,
-- so no box can walk off. The rows' backgrounds already overlap by design and a
-- uniform scale preserves that ratio exactly; it cannot make them overlap more.
-- v19.7: 1.10 -> 1.035. Same 65% cut as the prompt card — the increase was
-- +0.10 and 35% of it is +0.035. The anchor does not move; a smaller factor
-- about the same measured corner keeps all four widgets in register exactly as
-- 1.10 did, and the overlap arithmetic below only gets safer as the factor falls.
local TOD_PLAYER_HUD_SCALE = 1.035
local TOD_PLAYER_HUD_AX, TOD_PLAYER_HUD_AY = 45, 678

-- Scale about an arbitrary anchor. The element keeps its full-screen box and is
-- offset so (ax,ay) lands back where it started, which is what makes the four
-- widgets of the left HUD stay in register with each other.
local function TodScaleAt( el, ax, ay, scale )
	if el == nil then
		return
	end
	el:setScale( scale )
	local dx = -( ax - 640 ) * ( scale - 1 )
	local dy = -( ay - 360 ) * ( scale - 1 )
	el:setLeftRight( true, false, dx, dx + 1280 )
	el:setTopBottom( true, false, dy, dy + 720 )
end

-- The left HUD's four widgets all take the SAME anchor and the SAME factor, or
-- they drift apart. One helper, one call site shape, no per-widget numbers.
local function TodScalePlayerHud( el )
	TodScaleAt( el, TOD_PLAYER_HUD_AX, TOD_PLAYER_HUD_AY, TOD_PLAYER_HUD_SCALE )
end

local function TodScaleHud( el, ax, ay )
	TodScaleAt( el, ax, ay, TOD_HUD_SCALE )
end

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
	CoD.TodUIOwnership.Attach( self )
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
	-- [tod v17.9] NOT SCALED, AND THAT IS THE FIX — not an omission.
	--
	-- v15 item 12 scaled this widget 1.15 about (1005,620) to make the kit's
	-- small ammo text readable. The v17.9 gun-HUD rebuild authors bigger boxes
	-- directly instead (docs/91), which buys three things at once: canvas x 1.5
	-- is 1080p exactly so there is no post-scale arithmetic to get wrong; no box
	-- can walk off the screen (the old plate ran 117 px past the right edge and
	-- 22 px below the bottom); and PerkList's ±180 box goes back onto centre 640.
	--
	-- THAT LAST ONE IS WHY THE PERKS CONTAINER STAYS A CHILD of the loadout
	-- rather than being split out, which is what the ONE-ANCHOR LIMIT note above
	-- used to recommend. Scaling about a bottom-RIGHT anchor was displacing a
	-- bottom-CENTRE row; removing the scale re-centres it for free, and a child
	-- keeps inheriting BOTH alpha subscriptions below. Splitting it out would
	-- mean hand-adding both lanes to a second widget — and those two lanes are
	-- independent absolute writers that already disagree with each other.
	--
	-- The one thing the scale WAS buying the perks row is its size: perk icons
	-- were drawn at 28 x 1.15 = 32.2 canvas px. That is bought back in
	-- AetheriumPerkItem.lua (28 -> 32), not by keeping the scale.
	self:addElement( self.AetheriumLoadout )

	-- GobbleGum Inventory Widget — REMOVED (2026-09-01, same pass as the
	-- scoreboard quest band). THIS MAP HAS NO GOBBLEGUMS: no bgb system in any
	-- tod script, and ZMCursorHintNew has no GobbleGum arm at all for the same
	-- reason. Verified before cutting rather than assumed — the only `bgb` hits
	-- under scripts/ are stock/shared files and commented-out lines.
	--
	-- IT WAS NOT INERT, WHICH IS WHY IT WENT. Only `bbgIcon` carries
	-- setAlpha(0); `bbgBackground` has none, so the widget drew a permanent
	-- EMPTY 64x64 gobblegum slot plate at x1216-1280, y312-376 — screen right,
	-- mid-height — for a mechanic the map does not have. That is the difference
	-- between this and the quest band: that one was at least alpha'd, this one
	-- was simply on screen.
	--
	-- Same removal shape as the compass above: instantiation commented, require
	-- at the top KEPT (it only defines the class, and keeping it leaves the
	-- vendored kit consistent rather than half-removed). The three
	-- `if self.AetheriumGobbleGum then` scoreboard-fade sites further down are
	-- already nil-guarded and become no-ops.
	--
	-- self.AetheriumGobbleGum = CoD.AetheriumGobbleGum.new( self, controller )
	-- self.AetheriumGobbleGum.id = "AetheriumGobbleGum"
	-- self:addElement( self.AetheriumGobbleGum )

	-- Player Info Widget (Main Player) - Use UIList with PlayerListZM DataSource
	self.AetheriumPlayerInfo = LUI.UIList.new( self, controller, 2, 0, nil, false, false, 0, 0, false, false )
	self.AetheriumPlayerInfo:makeFocusable()
	self.AetheriumPlayerInfo:setLeftRight( true, false, 0, 1280 )
	self.AetheriumPlayerInfo:setTopBottom( true, false, 0, 720 )
	self.AetheriumPlayerInfo:setWidgetType( CoD.AetheriumPlayerInfo )
	self.AetheriumPlayerInfo:setDataSource( "PlayerListZM" )
	self:addElement( self.AetheriumPlayerInfo )
	-- v19.6/v19.7: +3.5%, anchored bottom-left with the party rows below.
	TodScalePlayerHud( self.AetheriumPlayerInfo )

	-- Party Members (Players 1-3) - Dynamic widget with index-based positioning
	-- Official BO3 pattern: single widget file, multiple instances with different player indices
	-- =======================================================================
	-- [tod] 4-PLAYER HUD MOCK (v17.3, 2026-09-03 — user: "in dev mode can you
	-- mock a 4 player game. Abandoned cyber city did this. So i can see what it
	-- looks like with other players and classes"). Ported from map 1.
	--
	-- When TOD_MOCK_PARTY is true the three party slots are fed LOCAL fake
	-- models (clientNum / playerName / playerScore / playerScoreShown /
	-- zombiePlayerIcon) instead of the engine's ZMPlayerList, so the co-op HUD
	-- is testable solo. The bars only MOVE if the GSC half is also live:
	-- _zm_aetherium_hud.gsc::mock_party_feed, which is gated on level.tod_dev
	-- and only ever writes UNOCCUPIED slots.
	--
	-- ⚠️ THIS FLAG IS NOT DEV-GATED AND CANNOT BE — Lua has no level.tod_dev.
	-- While true it MASKS REAL TEAMMATES: every party row shows a mock instead
	-- of the actual player. Map 1 carried the identical flag and its comment
	-- says to "manage it manually", which is precisely the kind of thing that
	-- ships armed. So here it is a BUILD GATE instead: build_map.ps1 -Publish
	-- greps this assignment and refuses to build while it is true. Ordinary
	-- test builds only WARN, the same shape as level.tod_dev.
	--
	-- The three char ids pick SKIRMISHER / ASSAULT / SLASHER (see
	-- AetheriumCharacters.lua), so drafting HEAVY yourself puts all four class
	-- medallions on screen at once.
	-- =======================================================================
	local TOD_MOCK_PARTY = false   -- 2026-10-01: OFF for the co-op restart test - the fake rows hide the real stand-in teammate (tod_dev_coop_mock). Was ARMED 2026-09-30 for the 4-player look.
	                               -- SHIP STATE IS false; build_map.ps1 REFUSES -Publish while
	                               -- this is armed, so it cannot reach players by accident.
	-- v17.36: the third name is EXACTLY 20 CHARACTERS, the new limit, so this
	-- preview shows the cut-off boundary rather than three names that clear it
	-- comfortably. Slot 2 is short on purpose — a short name is cap-limited and
	-- shows the +20%, a 20-char one is width-limited and shows the trade.
	local TOD_MOCK_NAMES = { "GhostByte_99", "NeonNomad", "ZombieJugglerPrime99" }
	local TOD_MOCK_ICONS = { "uie_t7_zm_hud_score_char5", "uie_t7_zm_hud_score_char6", "uie_t7_zm_hud_score_char7" }

	-- [tod v19.63] THE ROWS CLOSE RANKS (lead tester Nikolai, screenshot: "when
	-- you load in with either 2 or 3 players, it will not condense the names so
	-- sometimes there are spaces in between the names"). The engine fills the
	-- three roster slots by client number and hides the empty one, so with two
	-- teammates the gap could sit BETWEEN the rows. TodPartyRelayout re-stacks
	-- the OCCUPIED rows bottom-up in slot order; each widget keeps its own slot
	-- offset and is shifted by the difference (AetheriumPartyPlayers.TodSetRank).
	-- The anchored HUD scale lives on a WRAPPER per row, so the row's own
	-- top/bottom is free for that shift and the shift scales with the HUD.
	self.PartyPlayers = {}
	self.PartyHosts = {}
	self.TodPartyRelayout = function ()
		local rank = 0
		for j = 1, 3 do
			local w = self.PartyPlayers and self.PartyPlayers[ j ]
			if w and w.TodSetRank then
				if w.isPlayerSlotOccupied then
					rank = rank + 1
					w:TodSetRank( rank )
				else
					w:TodSetRank( j )   -- an empty row parks at its own slot
				end
			end
		end
	end
	for i = 1, 3 do
		local partyHost = LUI.UIElement.new()
		partyHost:setLeftRight( true, false, 0, 1280 )
		partyHost:setTopBottom( true, false, 0, 720 )
		local partyWidget = CoD.AetheriumPartyPlayers.new( self, controller, i )
		partyWidget:setLeftRight( true, false, 0, 1280 )
		partyWidget:setTopBottom( true, false, 0, 720 )
		if TOD_MOCK_PARTY then
			-- A local model tree carrying the exact child names the widget links.
			local controllerModel = Engine.GetModelForController( controller )
			local mockRoot = Engine.CreateModel( controllerModel, "todMockParty" .. i )
			Engine.SetModelValue( Engine.CreateModel( mockRoot, "clientNum" ), i )
			Engine.SetModelValue( Engine.CreateModel( mockRoot, "playerName" ), TOD_MOCK_NAMES[i] )
			Engine.SetModelValue( Engine.CreateModel( mockRoot, "playerScore" ), 5000 + i * 2500 )
			Engine.SetModelValue( Engine.CreateModel( mockRoot, "playerScoreShown" ), 1 )
			Engine.SetModelValue( Engine.CreateModel( mockRoot, "zombiePlayerIcon" ), TOD_MOCK_ICONS[i] )
			partyWidget:setModel( mockRoot, controller )
		else
			partyWidget:subscribeToGlobalModel( controller, "ZMPlayerList", tostring(i), function ( model )
				partyWidget:setModel( model, controller )
			end )
		end
		-- v19.6: the SAME anchor and factor as the local row above — these four
		-- share a column and a row pitch, so they scale together or not at all.
		-- v19.63: on the wrapper (see TodPartyRelayout above).
		TodScalePlayerHud( partyHost )
		partyHost:addElement( partyWidget )
		self:addElement( partyHost )
		self.PartyPlayers[i] = partyWidget
		self.PartyHosts[i] = partyHost
	end
	self.TodPartyRelayout()

	-- Powerups Container
	self.AetheriumPowerupsContainer = CoD.AetheriumPowerupsContainer.new( self, controller )
	self.AetheriumPowerupsContainer:setLeftRight( true, false, 0, 1280 )
	self.AetheriumPowerupsContainer:setTopBottom( true, false, 0, 720 )
	-- content is horizontally CENTRED (PowerupList -132..132), so x needs no
	-- correction and the anchor is screen centre at the list's own y.
	TodScaleHud( self.AetheriumPowerupsContainer, 640, 621 )
	self:addElement( self.AetheriumPowerupsContainer )
	
	self.AetheriumPowerupNotification = CoD.AetheriumPowerupNotification.new( self, controller )
	self.AetheriumPowerupNotification:setLeftRight( true, false, 0, 1280 )
	self.AetheriumPowerupNotification:setTopBottom( true, false, 0, 720 )
	self:addElement( self.AetheriumPowerupNotification )

	-- Round Counter (Top Right)
	self.AetheriumRoundCounter = CoD.AetheriumRoundCounter.new( self, controller )
	self.AetheriumRoundCounter:setLeftRight( true, false, 0, 1280 )
	self.AetheriumRoundCounter:setTopBottom( true, false, 0, 720 )
	-- NOT SCALED since v17.25, and that is deliberate — the same call
	-- AetheriumLoadout dropped, for the same reason. TodScaleHud's 1.15 about
	-- (1175,75) pushes a right edge of 1268 out to 1282, two canvas pixels past
	-- the screen. The widget now authors its own final sizes (RC_NUM_CAP and
	-- friends at the top of AetheriumRoundCounter.lua) and lands flush with the
	-- tower gauge and the gun HUD at x1268. The old call existed to enlarge the
	-- stock ZmRndContainer, which is gone.
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
	-- [tod v15 item 12] THE TRIGGER PROMPTS the user named by name (ammo crate,
	-- altar, every buy). All nine prompt cards are children of this one
	-- container and they draw near screen CENTRE, so scaling about the centre
	-- moves them almost not at all — this is the one genuinely safe scale in
	-- the kit and it needs no anchor correction.
	TodScaleHud( self.ZMCursorHint, 640, 360 )
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

	-- [tod v19.63] THE PARTY FACTS (_tod_gameover.gsc::party_push): humans in the
	-- party, whether THIS client is the host, and whether the game-over menu is
	-- up. AetheriumStartMenu reads CoD.TodParty to decide who gets Restart - the
	-- old dvar channel was host-machine only, so a co-op peer could never tell
	-- it was a peer. A field on CoD, not a new global (the HUD loads under the
	-- no-new-globals guard); the server refreshes it every 5 s, so nothing stale
	-- outlives the first heartbeat of a level.
	-- [tod 2026-10-01] EXCEPT THE GAME-OVER FLAG: this Lua VM outlives a restart,
	-- so a cache left at go=true by the last game's game-over menu would turn the
	-- NEXT game's pause menu into Restart Map / End Game until a heartbeat
	-- landed. A HUD being built means a new level: no game-over menu is up.
	if type( CoD.TodPartyBy ) == "table" and type( CoD.TodPartyBy[ controller ] ) == "table" then
		CoD.TodPartyBy[ controller ].go = false
	end
	if type( CoD.TodParty ) == "table" then
		CoD.TodParty.go = false
	end
	self:subscribeToGlobalModel( controller, "PerController", "scriptNotify", function ( model )
		local ev = Engine.GetModelValue( model )
		-- [tod 2026-10-01] THE FLOOR LABEL rides this same subscription (docs/167
		-- item 12): _tod_gauge::floor_label_code's int, filed per controller for
		-- the scoreboard and pause-menu header line (CoD.TodFloorLabelText below).
		if ev == "tod_floor_label" then
			local fd = CoD.GetScriptNotifyData and CoD.GetScriptNotifyData( model )
			if fd then
				CoD.TodFloorLabelBy = CoD.TodFloorLabelBy or {}
				CoD.TodFloorLabelBy[ controller ] = math.floor( tonumber( fd[ 1 ] ) or 0 )
			end
			return
		end
		if ev ~= "tod_party" then
			return
		end
		local d = CoD.GetScriptNotifyData and CoD.GetScriptNotifyData( model )
		if not d then
			return
		end
		-- host: 0 = not at the host's machine, 1 = host machine with a teammate on
		-- another machine, 2 = host machine and every human on it (LOCKSTEP
		-- _tod_gameover::party_push). localOnly picks the restart lane.
		local hv = math.floor( tonumber( d[ 2 ] ) or 2 )
		CoD.TodParty = {
			n = math.floor( tonumber( d[ 1 ] ) or 1 ),
			host = ( hv >= 1 ),
			localOnly = ( hv == 2 ),
			go = ( math.floor( tonumber( d[ 3 ] ) or 0 ) == 1 ),
		}
		-- [tod 2026-10-01] AND PER CONTROLLER (docs/167 item 10). Split-screen runs
		-- one HUD per local player in this same Lua VM, so the single table above
		-- is last-write-wins across them: the guest's host=0 hid Restart on BOTH
		-- screens. AetheriumStartMenu reads this copy for its own controller.
		CoD.TodPartyBy = CoD.TodPartyBy or {}
		CoD.TodPartyBy[ controller ] = CoD.TodParty
	end )

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
	if element.PartyHosts then
		for i = 1, 3 do
			if element.PartyHosts[i] then
				element.PartyHosts[i]:close()
			end
		end
	end
	end )

	-- ========================================
	-- HIDE THE HUD - ONE RULE (2026-10-02)
	-- ========================================
	-- Was two absolute writers (one per visibility bit) plus a third for stock's
	-- end-of-game forced board, and they disagreed: closing the scoreboard with
	-- the pause menu up un-hid the HUD under the menu (Tower II found and fixed the
	-- same pair, 2026-09-29; this is its rule). Now every reason is tracked and ONE
	-- function applies the result:
	--   scoreboard  the board is open (its button bit)
	--   force       stock's end-of-game board (forceScoreboard) - LATCHED: the game
	--               is over, and un-hiding when it is released would fight the
	--               game-over menu (_tod_gameover opens it at the same moment)
	--   ui          the pause menu / any UI is active
	--   veil        a full-screen moment owns the screen (CoD.TodHudVeil: the
	--               rocket rides, key "rocket", TodRocketCine.lua)
	-- The stock chat follows the board and the veil, never the UI bit (as before:
	-- docs/167 item 15). The veil also hides the button prompt, the kill feed and
	-- the third-person crosshair.
	local todHide = { scoreboard = false, force = false, ui = false, veil = false }
	local function TodHudApply()
		local base = ( todHide.scoreboard or todHide.force or todHide.ui or todHide.veil ) and 0 or 1
		local chat = ( todHide.scoreboard or todHide.force or todHide.veil ) and 0 or 1
		local extra = todHide.veil and 0 or 1
		local list = { self.AetheriumCompass, self.AetheriumLoadout, self.AetheriumGobbleGum, self.SpecialWeapon,
			self.AetheriumPlayerInfo, self.AetheriumPowerupsContainer, self.AetheriumPowerupNotification,
			self.AetheriumRoundCounter }
		for _, el in pairs( list ) do
			if el then
				el:setAlpha( base )
			end
		end
		if self.PartyPlayers then
			for i = 1, 3 do
				if self.PartyPlayers[i] then
					self.PartyPlayers[i]:setAlpha( base )
				end
			end
		end
		-- [tod 2026-10-01] THE STOCK CHAT (docs/167 item 15; lead tester: "Prevent Xbox
		-- controller icons from bleeding into the chat on the select/tab screen"). Stock's
		-- IngameChatClientContainer moves its chat INTO the board's bottom-left on
		-- BIT_SCOREBOARD_OPEN / forceScoreboard; the CONTAINER's alpha is ours to write.
		for _, el in pairs( { self.IngameChatClientContainer, self.IngameChatClientContainer0 } ) do
			if el then
				el:setAlpha( chat )
			end
		end
		-- the veil-only set (their own visibility rules stay in charge otherwise)
		for _, el in pairs( { self.ZMCursorHint, self.AetheriumKillFeed, self.ThirdPersonCrosshair } ) do
			if el then
				el:setAlpha( extra )
			end
		end
	end
	TodHudApply()

	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN ), function ( model )
		local v = Engine.GetModelValue( model )
		todHide.scoreboard = ( v ~= nil and v ~= 0 )
		TodHudApply()
	end )

	-- [tod 2026-09-24] STOCK'S END-OF-GAME BOARD (AetheriumScoreboard shows it - the
	-- lead tester's "end game stats"). CreateModel, not GetModel: the node exists only
	-- after the first force.
	self:subscribeToModel( Engine.CreateModel( Engine.GetModelForController( controller ), "forceScoreboard" ), function ( model )
		if Engine.GetModelValue( model ) == 1 then
			todHide.force = true
			TodHudApply()
		elseif todHide.force then
			-- [tod 2026-10-02] RELEASED: _tod_gameover sends force_scoreboard 0 as it opens
			-- the game-over menu (the menu's own UI bit keeps the HUD hidden from there),
			-- host_restart sends it again, and a restart's first snapshot zeroes the model.
			-- THIS MENU SURVIVES A RESTART (stock reuses it - see the fastRestart
			-- subscription in PostLoadFunc), so a latch that never released left every
			-- game after a Restart Map with no HUD. Same timing as the v19.68g writers.
			todHide.force = false
			TodHudApply()
		end
	end )

	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_UI_ACTIVE ), function ( model )
		local v = Engine.GetModelValue( model )
		todHide.ui = ( v ~= nil and v ~= 0 )
		TodHudApply()
	end )

	if CoD.TodHudVeil then
		CoD.TodHudVeil.Listen( self, function ( hidden )
			todHide.veil = hidden
			TodHudApply()
		end )
	end

	-- [tod 2026-10-02] THE ROCKET RIDES' LETTERBOX (docs/170, _tod_rocket.gsc). Built
	-- LAST so its bars draw over every HUD piece; it holds the veil key "rocket" itself
	-- and is not in TodHudApply's lists, so the veil never hides it. pcall'd like every
	-- optional require: a missing rawfile means no bars, never an error.
	pcall( require, "ui.uieditor.widgets.HUD.AetheriumWidgets.TodRocketCine" )
	if CoD.TodRocketCine then
		self.TodRocketCine = CoD.TodRocketCine.new( self, controller )
		self:addElement( self.TodRocketCine )
	end

	if PostLoadFunc then
		PostLoadFunc( self, controller )
	end

	return self
end
