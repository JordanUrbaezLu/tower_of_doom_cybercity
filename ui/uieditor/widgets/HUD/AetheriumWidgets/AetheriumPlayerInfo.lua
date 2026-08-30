-- Aetherium Player Info Widget (Bottom Left - Main Player)
-- Uses: i_mtl_ui_hud_player_info_theme_aetherium
-- BO6 Pattern: Uses linkToElementModel for dynamic clientNum subscription

require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPlusPointsContainer" )
require("ui.uieditor.widgets.HUD.Mappings.AetheriumBBG")
require("ui.uieditor.widgets.HUD.Mappings.AetheriumCharacters")

CoD.AetheriumPlayerInfo = InheritFrom( LUI.UIElement )
CoD.AetheriumPlayerInfo.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumPlayerInfo )
	self.id = "AetheriumPlayerInfo"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self.anyChildUsesUpdateState = true

	-- Main Player Info Background (elem7)
	self.player = LUI.UIImage.new()
	self.player:setLeftRight(true, false, 16, 360)
	self.player:setTopBottom(true, false, 595, 710)
	self.player:setImage( RegisterImage( "i_mtl_ui_hud_player_info_theme_aetherium" ) )
	self.player:setRGB( 1.000, 1.000, 1.000 )
	self.player:setAlpha( 1.0 )
	self:addElement( self.player )

	-- Salvage Icon (elem6)
	-- self.salvage_icon = LUI.UIImage.new()
	-- self.salvage_icon:setLeftRight(true, false, 89, 105)
	-- self.salvage_icon:setTopBottom(true, false, 662, 677)
	-- self.salvage_icon:setImage( RegisterImage( "i_mtl_ui_icons_zombie_squad_info_salvage" ) )
	-- self.salvage_icon:setRGB( 1.000, 1.000, 1.000 )
	-- self.salvage_icon:setAlpha( 1.0 )
	-- self:addElement( self.salvage_icon )

	-- Salvage Amount (elem3) - TEXT
	-- self.salvage_amount = LUI.UIText.new()
	-- self.salvage_amount:setLeftRight(true, false, 105, 178)
	-- self.salvage_amount:setTopBottom(true, false, 665, 676)
	-- self.salvage_amount:setTTF( "fonts/orbitron.ttf" )
	-- self.salvage_amount:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	-- self.salvage_amount:setRGB( 1.000, 1.000, 1.000 )
	-- self.salvage_amount:setText( Engine.Localize( "500000" ) )
	-- self.salvage_amount:setAlpha( 1.0 )
	-- self:addElement( self.salvage_amount )

	-- Points Icon (elem5)
	self.points_icon = LUI.UIImage.new()
	self.points_icon:setLeftRight(true, false, 89, 105)
	self.points_icon:setTopBottom(true, false, 662, 677)
	self.points_icon:setImage( RegisterImage( "i_mtl_ui_icons_zombie_essence" ) )
	self.points_icon:setRGB( 1.000, 1.000, 1.000 )
	self.points_icon:setAlpha( 1.0 )
	self:addElement( self.points_icon )

	-- Points Amount (elem4) - TEXT (reactive to playerScore)
	self.points_amount = LUI.UIText.new()
	self.points_amount:setLeftRight(true, false, 105, 178)
	self.points_amount:setTopBottom(true, false, 665, 676)
	self.points_amount:setTTF( "fonts/ltromatic.ttf" )
	self.points_amount:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self.points_amount:setRGB(0.984313725490196, 0.9725490196078431, 0.4745098039215686)
	self.points_amount:linkToElementModel( self, "playerScore", true, function ( model )
		local playerScore = Engine.GetModelValue( model )
		if playerScore then
			self.points_amount:setText( Engine.Localize( playerScore ) )
		end
	end )
	self.points_amount:setAlpha( 1.0 )
	self:addElement( self.points_amount )

	-- Player Name (elem28) - TEXT (reactive to playerName)
	self.player_name = LUI.UIText.new()
	self.player_name:setLeftRight(true, false, 98, 199)
	self.player_name:setTopBottom(true, false, 636, 647)
	self.player_name:setTTF( "fonts/orbitron.ttf" )
	self.player_name:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self.player_name:setRGB( 1.000, 1.000, 1.000 )
	self.player_name:linkToElementModel( self, "playerName", true, function ( model )
		local playerName = Engine.GetModelValue( model )
		if playerName then
			self.player_name:setText( Engine.Localize( playerName ) )
		end
	end )
	self.player_name:setAlpha( 1.0 )
	self:addElement( self.player_name )

	-- Shield Health Bar (Blue bar above normal health bar)
	self.shield_health_fill = LUI.UIImage.new()
	self.shield_health_fill:setLeftRight(true, false, 92, 223)
	self.shield_health_fill:setTopBottom(true, false, 641, 648)
	self.shield_health_fill:setImage( RegisterImage( "i_mtl_ui_hud_party_health_bar_fill" ) )
	self.shield_health_fill:setRGB( 0.4, 0.7, 1 )  -- Blue color for shield
	self.shield_health_fill:setMaterial( LUI.UIImage.GetCachedMaterial( "uie_wipe_normal" ) )
	self.shield_health_fill:setShaderVector( 0, 0, 0, 0, 0 )  -- Start at 0 (hidden)
	self.shield_health_fill:setShaderVector( 1, 0, 0, 0, 0 )
	self.shield_health_fill:setShaderVector( 2, 1, 0, 0, 0 )
	self.shield_health_fill:setShaderVector( 3, 0, 0, 0, 0 )
	self.shield_health_fill:setAlpha( 0 )  -- Hidden by default (no shield)
	self:addElement( self.shield_health_fill )

	-- Health Fill (added BEFORE border so border renders on top)
	self.health_fill = LUI.UIImage.new()
	self.health_fill:setLeftRight(true, false, 94, 221)
	self.health_fill:setTopBottom(true, false, 649, 656)
	self.health_fill:setImage( RegisterImage( "i_mtl_ui_hud_player_health_bar_fill" ) )
	self.health_fill:setRGB( 1, 1, 1 )
	self.health_fill:setMaterial( LUI.UIImage.GetCachedMaterial( "uie_wipe_normal" ) )
	self.health_fill:setShaderVector( 0, 1, 0, 0, 0 )
	self.health_fill:setShaderVector( 1, 0, 0, 0, 0 )
	self.health_fill:setShaderVector( 2, 1, 0, 0, 0 )
	self.health_fill:setShaderVector( 3, 0, 0, 0, 0 )
	self:addElement( self.health_fill )

	-- Health Border (added AFTER fill - renders on top)
	self.health_border = LUI.UIImage.new()
	self.health_border:setLeftRight(true, false, 93, 222)
	self.health_border:setTopBottom(true, false, 648, 657)
	self.health_border:setImage( RegisterImage( "i_mtl_ui_hud_player_health_bar_border" ) )
	self.health_border:setRGB( 1, 1, 1 )
	self:addElement( self.health_border )

	-- Downed Indicator (Player 1 - Local Player)
	self.downedIcon = LUI.UIImage.new()
	self.downedIcon:setLeftRight(true, false, 223, 253)
	self.downedIcon:setTopBottom(true, false, 638, 668)
	self.downedIcon:setImage(RegisterImage("i_mtl_icon_ping_downed"))
	self.downedIcon:setRGB(1, 1, 1)
	self.downedIcon:setAlpha(0)  -- Hidden by default
	self:addElement(self.downedIcon)

	-- Player HP (elem29) - TEXT (reactive to player_health_X)
	self.player_hp = LUI.UIText.new()
	self.player_hp:setLeftRight(true, false, 189, 228)
	self.player_hp:setTopBottom(true, false, 631, 639)
	self.player_hp:setText( Engine.Localize( "" ) )
	self.player_hp:setTTF( "fonts/orbitron.ttf" )
	self.player_hp:setRGB( 1.0, 1.0, 1.0 )
	self.player_hp:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
	self:addElement( self.player_hp )
	
	-- Player Character Portrait (elem32) - IMAGE (reactive to zombiePlayerIcon)
	self.player_portrait = LUI.UIImage.new()
	self.player_portrait:setLeftRight(true, false, 36, 87)
	self.player_portrait:setTopBottom(true, false, 625, 684)
	self.player_portrait:setImage( RegisterImage( "blacktransparent" ) )
	self.player_portrait:linkToElementModel( self, "zombiePlayerIcon", true, function ( model )
		local zombiePlayerIcon = Engine.GetModelValue( model )
		if zombiePlayerIcon then
			local portraitIcon = CoD.GetCharacterPortrait( zombiePlayerIcon )
			self.player_portrait:setImage( RegisterImage( portraitIcon ) )
		end
	end )
	self:addElement( self.player_portrait )

	-- Shield Icon (shows when shield is equipped)
	self.shield_icon = LUI.UIImage.new()
	self.shield_icon:setLeftRight(true, false, 230, 253)
	self.shield_icon:setTopBottom(true, false, 635, 658)
	self.shield_icon:setImage(RegisterImage("riotshield_zm_icon"))
	self.shield_icon:setRGB(1, 1, 1)
	self.shield_icon:setAlpha(0)  -- Hidden by default
	self:addElement(self.shield_icon)
	
	-- BO6 PATTERN: Dynamic health subscription based on clientNum
	-- This ensures each player viewing the HUD sees THEIR OWN health
	self:linkToElementModel( self, "clientNum", true, function ( clientModel )
		local clientNum = Engine.GetModelValue( clientModel )
		
		if clientNum then
			self.currentClientNum = clientNum
			
			-- Track current state
			self.currentPlayerState = 0  -- 0=alive, 1=downed, 2=dead
			self.currentGobbleGum = nil
			self.currentHealth = nil
			
			-- Subscribe to gobblegum for Coagulant detection
			-- [tod] RE-SUBSCRIPTION GUARD — map 1's 2026-07-04 fix, REGRESSED by the
			-- 2026-08-19 pristine vendor. This sub previously leaked one handler per
			-- clientNum re-fire, so it grows with the number of clients AND with how
			-- often they change — the co-op twin of the PartyPlayers leak.
			-- The handle+remove pattern is already used correctly four times in this
			-- very file (health, maxHp, state, shield), so this was an oversight in
			-- the kit rather than a design choice.
			local bgbModel = Engine.GetModel( Engine.GetModelForController( controller ), "bgb_current" )
			if bgbModel then
				if self.bgbSubscription ~= nil then
					self:removeSubscription( self.bgbSubscription )
				end
				self.bgbSubscription = self:subscribeToModel( bgbModel, function( model )
					local bgbIndex = Engine.GetModelValue( model )
					self.currentGobbleGum = bgbIndex  -- Coagulant is index 3
				end )
			end
			
			local controllerModel = Engine.GetModelForController( controller )
			local healthModel = Engine.GetModel( controllerModel, "player_health_" .. clientNum )
			
			-- Remove old subscription if it exists
			if self.healthSubscription ~= nil then
				self:removeSubscription( self.healthSubscription )
			end
			
			-- [tod 2026-08-21] REAL MAX HP. The kit's player_health_X field is a
			-- 0..1 FRACTION (health/maxhealth, _zm_aetherium_hud.gsc:105), and
			-- the text used to multiply it by a hardcoded 100 — so a 150-HP
			-- player read "100 HP" (user: "players start with 150 HP but the HUD
			-- says 100"). The server now pushes each player's true maxhealth on
			-- change over the int-only LuiNotifyEvent lane (_tod_gauge.gsc,
			-- "tod_maxhp" — zero clientuimodel bits); 150 is only the pre-event
			-- default, the map's TOD_UPG_BASE_HP.
			self.maxHealth = self.maxHealth or 150
			if self.maxHpSubscription ~= nil then
				self:removeSubscription( self.maxHpSubscription )
			end
			self.maxHpSubscription = self:subscribeToGlobalModel( controller, "PerController", "scriptNotify", function ( model )
				if Engine.GetModelValue( model ) ~= "tod_maxhp" then
					return
				end
				local d = CoD.GetScriptNotifyData( model )
				local v = ( d and type( d[ 1 ] ) == "number" ) and d[ 1 ] or nil
				if v and v > 0 then
					self.maxHealth = v
					if self.currentHealth then
						self.player_hp:setText( Engine.Localize( math.ceil( self.currentHealth * self.maxHealth ) .. " HP" ) )
					end
				end
			end )

			-- Subscribe to the correct health model for this player
			self.healthSubscription = self:subscribeToModel( healthModel, function ( model )
				local health = Engine.GetModelValue( model )
				if health then
					-- Always store current health
					self.currentHealth = health

					-- Update HP text: fraction x the player's REAL max (see above)
					local maxHealth = self.maxHealth or 150
					local currentHealth = math.ceil( health * maxHealth )
					self.player_hp:setText( Engine.Localize( currentHealth .. " HP" ) )
					
					-- Only update visual if alive
					if self.currentPlayerState == 0 then
						-- Update health bar fill
						self.health_fill:completeAnimation()
						self.health_fill:beginAnimation( "keyframe", 400, false, false, CoD.TweenType.Linear )
						self.health_fill:setShaderVector( 0,
							CoD.GetVectorComponentFromString( health, 1 ),
							CoD.GetVectorComponentFromString( health, 2 ),
							CoD.GetVectorComponentFromString( health, 3 ),
							CoD.GetVectorComponentFromString( health, 4 ) )
					end
				end
			end )
			
			-- Remove old state subscription if it exists
			if self.stateSubscription ~= nil then
				self:removeSubscription( self.stateSubscription )
			end
			
			-- Subscribe to THIS player's state model.
			--
			-- [tod 2026-08-26] WAS HARDCODED "player_state_0", with the comment
			-- "local player is always index 0". That premise is false in co-op:
			-- player_state_N is packed two bits per PLAYER INDEX by
			-- _zm_aetherium_hud.csc::player_states_callback (:57-81), so index 0 is
			-- the HOST, not "whoever is looking". Every client therefore subscribed
			-- to the host's state, and the whole party's own PlayerInfo panel went
			-- red / showed the downed icon / ran the bleedout animation whenever
			-- player 0 went down -- while players 1-3 going down updated nobody's
			-- panel at all. (User 2026-08-26: "when you go down or someone on the
			-- team goes down it impacts all players in the player HUD".)
			--
			-- clientNum is already in scope from the linkToElementModel callback at
			-- :170, and the health subscription 60 lines up (:201) has always used
			-- it correctly -- so this was an inconsistency inside a single function,
			-- not a missing capability. AetheriumPartyPlayers.lua:76 also indexes by
			-- clientNum; this file was the lone offender.
			if controllerModel then
				local stateModel = Engine.GetModel( controllerModel, "player_state_" .. clientNum )
				if stateModel then
					self.stateSubscription = self:subscribeToModel( stateModel, function ( model )
					local newState = Engine.GetModelValue( model )
					if newState ~= nil then
						self.currentPlayerState = newState
						
						-- Handle state changes
						if newState == 0 then
							-- ====================================
							-- ALIVE STATE
							-- ====================================
							self.health_fill:completeAnimation()
							self.downedIcon:setAlpha(0)
							self.player_portrait:setRGB(1, 1, 1)
							self.player_name:setRGB(1, 1, 1)
							self.health_fill:setRGB(1, 1, 1)
							self.health_fill:setAlpha(1)
							self.health_border:setAlpha(1)
							self.points_icon:setAlpha(1)
							self.points_amount:setAlpha(1)
							self.player_hp:setAlpha(1)
							
							-- Set initial health bar value when becoming alive
							if self.currentHealth then
								self.health_fill:setShaderVector( 0,
									CoD.GetVectorComponentFromString( self.currentHealth, 1 ),
									CoD.GetVectorComponentFromString( self.currentHealth, 2 ),
									CoD.GetVectorComponentFromString( self.currentHealth, 3 ),
									CoD.GetVectorComponentFromString( self.currentHealth, 4 ) )
							end
							
						elseif newState == 1 then
							-- ====================================
							-- DOWNED STATE
							-- ====================================
							-- Check if player has Coagulant gobblegum (index 3)
							-- [tod 2026-08-26] WAS THE KIT'S HARDCODED 45000, which is the Aetherium
							-- demo map's tuning, not ours. This map never sets a bleedout, so a down
							-- runs the stock engine default player_lastStandBleedoutTime = 30s
							-- (_zm_laststand.gsc:256 reads that dvar; nothing in scripts/ overrides it
							-- and nothing sets n_bleedout_time_multiplier). The bar therefore emptied
							-- over 45s while the player actually bled out at 30 -- it was still a third
							-- full at the moment they died, which reads as the HUD lying about how long
							-- a teammate has left. Map 1 fixed this same kit bug the same way
							-- (abandoned_cyber_city_zombies AetheriumPlayerInfo.lua:374 /
							-- AetheriumPartyPlayers.lua:186); this map never inherited it.
							-- The Coagulant branch below is DEAD here (no BGB machine, no bgb assets in the .zone) but kept for kit fidelity.
							local bleedoutTime = 30000  -- stock bleedout (was kit-hardcoded 45000)
							if self.currentGobbleGum == 3 then
								bleedoutTime = 135000  -- Coagulant: 135 seconds (3x longer)
							end
							
							-- Show downed visuals
							self.health_fill:completeAnimation()
							self.downedIcon:setAlpha(1)
							self.downedIcon:setRGB(1, 0.2, 0.2)
							self.health_fill:setRGB(1, 0.2, 0.2)
							self.health_fill:setAlpha(1)
							self.health_border:setAlpha(1)
							self.health_fill:setShaderVector( 0, 1, 0, 0, 0 )
							self.health_fill:beginAnimation("bleedout_timer", bleedoutTime, false, false, CoD.TweenType.Linear)
							self.health_fill:setShaderVector( 0, 0, 0, 0, 0 )
							self.player_portrait:setRGB(1, 1, 1)
							self.player_name:setRGB(1, 1, 1)
							self.points_icon:setAlpha(1)
							self.points_amount:setAlpha(1)
							self.player_hp:setAlpha(1)
							
						elseif newState == 2 then
							-- ====================================
							-- DEAD STATE
							-- ====================================
							self.health_fill:completeAnimation()
							self.health_fill:setAlpha(0)
							self.health_border:setAlpha(0)
							self.points_icon:setAlpha(0)
							self.points_amount:setAlpha(0)
							self.player_hp:setAlpha(0)
							self.downedIcon:setAlpha(0)
							self.player_portrait:setRGB(0.3, 0.3, 0.3)
							self.player_name:setRGB(1, 0.2, 0.2)
						end
					end
				end )
				end
			end
			
			-- Subscribe to shield health (riot shield)
			if controllerModel then
				-- [tod 2026-08-26] CreateModel, NOT GetModel — ported from map 1
				-- (abandoned_cyber_city_zombies AetheriumPlayerInfo.lua:423-434). GetModel on
				-- zmInventory.shield_health is the DEAD-NODE TRAP: the node does not exist
				-- until the server bridge first writes it, so a HUD-build subscription binds
				-- to nothing and only comes alive if a clientNum rebind happens to re-fire
				-- AFTER the shield exists — i.e. on a first down/revive. CreateModel
				-- pre-creates the node the bridge later writes, and is idempotent when one
				-- already exists.
				--
				-- It also removed a live hazard here: GetModel returns nil when the node is
				-- absent, and this code passed the result straight to subscribeToModel with
				-- no guard. THIS MAP HAS NO RIOT SHIELD (the only mention in scripts/ is a
				-- comment in _tod_reaver.gsc), so that node is never written and the nil path
				-- was the ONLY path — with everything later in this clientNum closure riding
				-- on it not throwing.
				local shieldHealthModel = Engine.CreateModel( controllerModel, "zmInventory.shield_health" )
			
			-- Remove old shield subscription if it exists
			if self.shieldSubscription ~= nil then
				self:removeSubscription( self.shieldSubscription )
			end
			
			-- Subscribe to shield health model
			self.shieldSubscription = self:subscribeToModel( shieldHealthModel, function ( model )
				local shieldHealth = Engine.GetModelValue( model )
				if shieldHealth then
					-- Check if shield is actually equipped (showDpadDown > 0 means shield is held)
					local showDpadDown = Engine.GetModelValue( Engine.CreateModel( controllerModel, "hudItems.showDpadDown" ) )
					
					-- Shield health is 0-1 range (0 = no shield, 1 = full shield)
					-- Only show if shield is equipped AND has health
					if showDpadDown ~= nil and showDpadDown > 0 and shieldHealth > 0 then
					-- Has shield equipped - show shield bar and icon
					self.shield_health_fill:setAlpha( 1 )
					self.shield_icon:setAlpha( 1 )
				
				-- Move player name UP to sit above shield bar (smooth animation)
				self.player_name:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
					self.player_name:setTopBottom(true, false, 630, 641)
				self.player_hp:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
				self.player_hp:setTopBottom(true, false, 632, 639)				
				-- Move downed icon to RIGHT of shield icon to prevent overlap (smooth animation)
				self.downedIcon:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
				self.downedIcon:setLeftRight(true, false, 257, 292)		
				self.downedIcon:setTopBottom(true, false, 628, 663)		
				-- Update shield bar fill immediately (no animation - shows every damage hit)
				self.shield_health_fill:setShaderVector( 0,
						CoD.GetVectorComponentFromString( shieldHealth, 1 ),
						CoD.GetVectorComponentFromString( shieldHealth, 2 ),
						CoD.GetVectorComponentFromString( shieldHealth, 3 ),
						CoD.GetVectorComponentFromString( shieldHealth, 4 ) )
					
					-- Color based on shield health (blue at full, red when low)
					if shieldHealth <= 0.33 then
						self.shield_health_fill:setRGB( 1, 0.4, 0.4 )  -- Red when low
					elseif shieldHealth <= 0.66 then
						self.shield_health_fill:setRGB( 1, 0.8, 0.4 )  -- Orange/Yellow when medium
					else
						self.shield_health_fill:setRGB( 0.4, 0.7, 1 )  -- Blue when high
					end
				else
					-- No shield equipped or no health - hide shield bar and icon
					self.shield_health_fill:setAlpha( 0 )
					self.shield_icon:setAlpha( 0 )
				
				-- Move player name back DOWN to original position
				self.player_name:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
				self.player_name:setTopBottom(true, false, 636, 647)
				
				-- Move HP text back DOWN to original position
				self.player_hp:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
				self.player_hp:setTopBottom(true, false, 640, 647)
				
				-- Move downed icon back to original position (smooth animation)
				self.downedIcon:beginAnimation( "keyframe", 200, false, false, CoD.TweenType.Linear )
				self.downedIcon:setLeftRight(true, false, 223, 253)
				end
				end
			end )
			end
		end
	end )
	
	-- Points Delta Container (holds dynamically created popups - vanilla BO3 pattern)
	self.pointsDeltaContainer = LUI.UIElement.new()
	self.pointsDeltaContainer:setLeftRight( true, false, 223, 273 )  -- Match reference position
	self.pointsDeltaContainer:setTopBottom( true, false, 664, 671 )
	self.pointsDeltaContainer.lastAnim = 0
	self:addElement( self.pointsDeltaContainer )

	-- Subscribe to score_cf models (vanilla BO3 pattern - damage, death, etc.)
	-- This triggers the points popups
	self:linkToElementModel( self, "clientNum", true, function ( clientModel )
		local clientNum = Engine.GetModelValue( clientModel )
		
		if clientNum then
			-- [tod] SUBSCRIBE-ONCE GUARD (verification pass 2026-08-23, correcting a
			-- CHECKED-AND-LEFT call). map 1 leaves this subscribeToModel bare ONLY
			-- because it guards the whole block with this early return; the tower had
			-- the bare call WITHOUT the guard. The clientNum link re-fires on every
			-- rebind (roster change, and Engine.Exec map_restart from our own game-over
			-- RESTART MAP button), and each re-fire re-added all 7 score subscriptions
			-- with no unsubscribe -> N duplicate "+10" popups per score event after N-1
			-- rebinds, plus the per-rebind subscription leak the other kit fixes address.
			-- Nothing follows the score block in this callback, so returning drops nothing.
			if self.todScoreSubbedFor == clientNum then
				return
			end
			self.todScoreSubbedFor = clientNum
			
			local controllerModel = Engine.GetModelForController( controller )
			local clientScoreModel = Engine.GetModel( controllerModel, "PlayerList.client" .. clientNum )
			
			if clientScoreModel then
				-- Score types from vanilla ZMScr (damage, death_normal, etc.)
				local scoreTypes = {
					damage = 10,
					death_normal = 50,
					-- [tod] 130 -> 120 (2026-08-26). Mirrors the nerfed
					-- zombie_score_bonus_melee (70) set in zm_tower_of_doom.gsc
					-- ::main(); this table is what the popup DRAWS, so it lies
					-- the moment the two disagree.
					death_melee = 120,
					death_torso = 60,
					death_neck = 100,
					death_head = 100,
					reward = 50
				}
				
				-- Subscribe to each score_cf model
				for scoreType, scoreValue in pairs( scoreTypes ) do
					local scoreModel = Engine.CreateModel( clientScoreModel, "score_cf_" .. scoreType )
					if scoreModel then
						self:subscribeToModel( scoreModel, function ( model )
							local modelValue = Engine.GetModelValue( model )
							if modelValue ~= nil and modelValue ~= 0 then
								-- Calculate points (with double points check)
								local points = scoreValue
								local doublePointsModel = Engine.GetModel( controllerModel, "hudItems.doublePointsActive" )
								if doublePointsModel and Engine.GetModelValue( doublePointsModel ) == 1 then
									points = points * 2
								end
								
								-- Create popup (vanilla BO3 pattern)
								if points ~= 0 and points >= -10000 and points <= 10000 then
									local popup = CoD.AetheriumPlusPointsContainer.new( menu, controller )
									
									-- Set text and color
									if points > 0 then
										popup.AetheriumPlusPoints.Label:setText( "+" .. points )
										popup.AetheriumPlusPoints.Label:setRGB( 0.9725, 0.9607, 0.4706 )  -- Yellow
									else
										popup.AetheriumPlusPoints.Label:setText( points )
										popup.AetheriumPlusPoints.Label:setRGB( 1, 0.3, 0.3 )  -- Red
									end
									
									-- Position popup at container location
									popup:setLeftRight( self.pointsDeltaContainer:getLocalLeftRight() )
									popup:setTopBottom( self.pointsDeltaContainer:getLocalTopBottom() )
									
									-- Close on animation complete
									popup:registerEventHandler( "clip_over", function ( element, event )
										element:close()
									end )
									
									-- Add to player widget (not container)
									self:addElement( popup )
									
									-- Play animation
									self.pointsDeltaContainer.lastAnim = self.pointsDeltaContainer.lastAnim + 1
									if self.pointsDeltaContainer.lastAnim > 1 then
										self.pointsDeltaContainer.lastAnim = 1
									end
									popup:playClip( "Anim1" )
									popup.AetheriumPlusPoints:playClip( "FadeOut" )
								end
							end
						end )
					end
				end
			end
		end
	end )

	return self
end
