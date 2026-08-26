-- Aetherium Party Players Widget NEW - State-based detection
-- Handles all 3 co-op party members (indices 1, 2, 3) with a single widget
-- Uses clientfield state detection (0=alive, 1=downed, 2=dead)

require("ui.uieditor.widgets.HUD.Mappings.AetheriumBBG")
require("ui.uieditor.widgets.HUD.Mappings.AetheriumCharacters")

local PostLoadFunc = function ( self, controller )
	-- Track current state
	self.currentPlayerState = 0  -- 0=alive, 1=downed, 2=dead
	self.currentGobbleGum = nil
	self.isPlayerSlotOccupied = false
	
	-- Subscribe to clientNum to get player entity number
	self:linkToElementModel( self, "clientNum", true, function ( clientModel )
		local clientNum = Engine.GetModelValue( clientModel )
		
		if clientNum ~= nil then
			self.currentClientNum = clientNum
			
			-- Remove old subscriptions if exist
			if self.healthSubscription ~= nil then
				self:removeSubscription( self.healthSubscription )
			end
			if self.stateSubscription ~= nil then
				self:removeSubscription( self.stateSubscription )
			end
			
			-- Subscribe to gobblegum for Coagulant detection
			-- [tod] RE-SUBSCRIPTION GUARD — map 1's 2026-07-04 fix, REGRESSED by the
			-- 2026-08-19 pristine vendor and found by diffing the two trees after the
			-- 2026-08-23 player leak reports. PARTY ROWS REBIND on roster change
			-- (setModel from the UIList), and each rebind previously ADDED another bgb
			-- handler with no removal, so handlers accumulated for the whole run.
			-- THIS ONE SCALES WITH PLAYER COUNT — more players means more roster
			-- churn means a faster leak, which is why it reads as a co-op-only decay
			-- while looking clean solo. Same state-pool exhaustion as the two UITimer
			-- leaks ("Failed to allocate from state pool"), different mechanism.
			-- Mirrors the handle+remove pattern the health/state subs below already use.
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
			
			-- Subscribe to health model (for health bar updates when alive)
			local healthModel = Engine.GetModel( Engine.GetModelForController( controller ), "player_health_" .. clientNum )
			if healthModel ~= nil then
				self.healthSubscription = self:subscribeToModel( healthModel, function ( model )
					local health = Engine.GetModelValue( model )
					if health ~= nil then
						-- Always store current health
						self.currentHealth = health
						
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
			end
			
			-- Subscribe to player state model (the key detection)
			local stateModel = Engine.GetModel( Engine.GetModelForController( controller ), "player_state_" .. clientNum )
			if stateModel then
				self.stateSubscription = self:subscribeToModel( stateModel, function ( model )
					local newState = Engine.GetModelValue( model )
					if newState ~= nil then
						self.currentPlayerState = newState
						
						-- Handle state changes
						if newState == 0 then
							-- ALIVE STATE
							self.health_fill:completeAnimation()
							self.downedIcon:setAlpha(0)
							self.portrait:setRGB(1, 1, 1)
							self.name:setRGB(1, 1, 1)
							self.health_fill:setRGB(1, 1, 1)
							if self.isPlayerSlotOccupied then
								self.health_fill:setAlpha(1)
								self.health_border:setAlpha(1)
								self.essence_icon:setAlpha(1)
								self.points:setAlpha(1)
							end
							
							-- Set initial health bar value when becoming alive
							if self.currentHealth then
								self.health_fill:setShaderVector( 0,
									CoD.GetVectorComponentFromString( self.currentHealth, 1 ),
									CoD.GetVectorComponentFromString( self.currentHealth, 2 ),
									CoD.GetVectorComponentFromString( self.currentHealth, 3 ),
									CoD.GetVectorComponentFromString( self.currentHealth, 4 ) )
							end
							
						elseif newState == 1 then
							-- DOWNED STATE
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
							-- Same dead-but-harmless Coagulant branch as PlayerInfo; see the note there.
							local bleedoutTime = 30000  -- stock bleedout (was kit-hardcoded 45000)
							if self.currentGobbleGum == 3 then
								bleedoutTime = 135000  -- Coagulant: 135 seconds (3x longer)
							end
							
							-- Show downed visuals
							self.health_fill:completeAnimation()
							if self.isPlayerSlotOccupied then
								self.downedIcon:setAlpha(1)
								self.health_fill:setAlpha(1)
								self.health_border:setAlpha(1)
								self.essence_icon:setAlpha(1)
								self.points:setAlpha(1)
							end
							self.downedIcon:setRGB(1, 0.2, 0.2)
							self.health_fill:setRGB(1, 0.2, 0.2)
							self.health_fill:setShaderVector( 0, 1, 0, 0, 0 )
							self.health_fill:beginAnimation("bleedout_timer", bleedoutTime, false, false, CoD.TweenType.Linear)
							self.health_fill:setShaderVector( 0, 0, 0, 0, 0 )
							self.portrait:setRGB(1, 1, 1)
							self.name:setRGB(1, 1, 1)
							
						elseif newState == 2 then
							-- DEAD STATE
							self.health_fill:completeAnimation()
							self.health_border:setAlpha(0)
							self.essence_icon:setAlpha(0)
							self.points:setAlpha(0)
							self.downedIcon:setAlpha(0)
							self.portrait:setRGB(0.3, 0.3, 0.3)
							self.name:setRGB(1, 0.2, 0.2)
						end
					end
				end )
			end
		end
	end )
end

CoD.AetheriumPartyPlayers = InheritFrom( LUI.UIElement )
CoD.AetheriumPartyPlayers.new = function ( menu, controller, playerIndex )
	local self = LUI.UIElement.new()

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumPartyPlayers )
	self.id = "AetheriumPartyPlayers"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self.anyChildUsesUpdateState = true

	-- DYNAMIC POSITIONING BASED ON PLAYER INDEX
	-- Player index 1 (bottom):  Y 524-611  (BG height: 87px)
	-- Player index 2 (middle):  Y 481-568  (offset: -43px from index 1)
	-- Player index 3 (top):     Y 439-526  (offset: -42px from index 2)
	local baseYTop = 524  -- Player 1 base position
	local yOffset = (playerIndex == 2 and -43) or (playerIndex == 3 and -85) or 0
	local bgTop = baseYTop + yOffset
	local bgBottom = bgTop + 87  -- Height is 87 pixels

	-- Background
	self.bg = LUI.UIImage.new()
	self.bg:setLeftRight( true, false, 43, 319 )
	self.bg:setTopBottom( true, false, bgTop, bgBottom )
	self.bg:setImage( RegisterImage( "i_mtl_ui_hud_party_member_theme_aetherium" ) )
	self.bg:setRGB( 1, 1, 1 )
	self.bg:setAlpha( 0 )
	self:addElement( self.bg )

	-- Player Portrait (offset from BG top)
	local portraitTop = bgTop + 19
	local portraitBottom = portraitTop + 40
	self.portrait = LUI.UIImage.new()
	self.portrait:setLeftRight( true, false, 64, 99 )
	self.portrait:setTopBottom( true, false, portraitTop, portraitBottom )
	self.portrait:setImage( RegisterImage( "blacktransparent" ) )
	self.portrait:setAlpha( 0 )
	self:addElement( self.portrait )

	-- Player Name (offset from BG top)
	local nameTop = bgTop + 34
	local nameBottom = nameTop + 9
	self.name = LUI.UIText.new()
	self.name:setLeftRight(true, false, 107, 199)
	self.name:setTopBottom(true, false, nameTop, nameBottom)
	self.name:setText( Engine.Localize( "Player" ) )
	self.name:setTTF( "fonts/orbitron.ttf" )
	self.name:setRGB( 1, 1, 1 )
	self.name:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self.name:setAlpha( 0 )
	self:addElement( self.name )

	-- Health Fill (offset from BG top) - 1px insets
	local healthFillTop = bgTop + 45
	local healthFillBottom = healthFillTop + 5
	self.health_fill = LUI.UIImage.new()
	self.health_fill:setLeftRight(true, false, 108, 221)
	self.health_fill:setTopBottom(true, false, healthFillTop, healthFillBottom)
	self.health_fill:setImage( RegisterImage( "i_mtl_ui_hud_party_health_bar_fill" ) )
	self.health_fill:setRGB( 1, 1, 1 )
	self.health_fill:setMaterial( LUI.UIImage.GetCachedMaterial( "uie_wipe_normal" ) )
	self.health_fill:setShaderVector( 0, 1, 0, 0, 0 )
	self.health_fill:setShaderVector( 1, 0, 0, 0, 0 )
	self.health_fill:setShaderVector( 2, 1, 0, 0, 0 )
	self.health_fill:setShaderVector( 3, 0, 0, 0, 0 )
	self.health_fill:setAlpha( 0 )
	self:addElement( self.health_fill )

	-- Health Border (offset from BG top)
	local healthBorderTop = bgTop + 44
	local healthBorderBottom = healthBorderTop + 7
	self.health_border = LUI.UIImage.new()
	self.health_border:setLeftRight(true, false, 107, 222)
	self.health_border:setTopBottom(true, false, healthBorderTop, healthBorderBottom)
	self.health_border:setImage( RegisterImage( "i_mtl_ui_hud_player_health_bar_border" ) )
	self.health_border:setRGB( 1, 1, 1 )
	self.health_border:setAlpha( 0 )
	self:addElement( self.health_border )

	-- Essence Icon (offset from BG top)
	local essenceTop = bgTop + 39
	local essenceBottom = essenceTop + 15
	self.essence_icon = LUI.UIImage.new()
	self.essence_icon:setLeftRight(true, false, 223, 240)
	self.essence_icon:setTopBottom(true, false, essenceTop, essenceBottom)
	self.essence_icon:setImage( RegisterImage( "i_mtl_ui_icons_zombie_essence" ) )
	self.essence_icon:setRGB( 1, 1, 1 )
	self.essence_icon:setAlpha( 0 )
	self:addElement( self.essence_icon )

	-- Points (offset from BG top)
	local pointsTop = bgTop + 41
	local pointsBottom = pointsTop + 11
	self.points = LUI.UIText.new()
	self.points:setLeftRight(true, false, 239, 325)
	self.points:setTopBottom(true, false, pointsTop, pointsBottom)
	self.points:setText( Engine.Localize( "0" ) )
	self.points:setTTF( "fonts/orbitron.ttf" )
	self.points:setRGB(0.9803921568627451, 0.9686274509803922, 0.4666666666666667)
	self.points:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self.points:setAlpha( 0 )
	self:addElement( self.points )

	-- Downed Icon (offset from BG top)
	local downedTop = bgTop + 15
	local downedBottom = downedTop + 24
	self.downedIcon = LUI.UIImage.new()
	self.downedIcon:setLeftRight(true, false, 173, 197)
	self.downedIcon:setTopBottom(true, false, downedTop, downedBottom)
	self.downedIcon:setImage(RegisterImage("i_mtl_icon_ping_downed"))
	self.downedIcon:setRGB(1, 1, 1)
	self.downedIcon:setAlpha(0)  -- Hidden by default
	self:addElement(self.downedIcon)
	
	-- Portrait - reactive subscription
	self.portrait:linkToElementModel( self, "zombiePlayerIcon", true, function ( model )
		local zombiePlayerIcon = Engine.GetModelValue( model )
		if zombiePlayerIcon then
			local portraitIcon = CoD.GetCharacterPortrait( zombiePlayerIcon )
			self.portrait:setImage( RegisterImage( portraitIcon ) )
		end
	end )

	-- Name - reactive subscription
	self.name:linkToElementModel( self, "playerName", true, function ( model )
		local name = Engine.GetModelValue( model )
		if name then
			self.name:setText( Engine.Localize( name ) )
		end
	end )

	-- Score - reactive subscription
	self.points:linkToElementModel( self, "playerScore", true, function ( model )
		local playerScore = Engine.GetModelValue( model )
		if playerScore then
			self.points:setText( Engine.Localize( playerScore ) )
		end
	end )

	-- Visibility - reactive subscription (controlled by BO3 engine - hides in solo)
	self:linkToElementModel( self, "playerScoreShown", true, function ( model )
		local playerScoreShown = Engine.GetModelValue( model )
		-- Track if player slot is occupied
		self.isPlayerSlotOccupied = (playerScoreShown and playerScoreShown ~= 0)
		local alpha = self.isPlayerSlotOccupied and 1 or 0
		self.bg:setAlpha( alpha )
		self.portrait:setAlpha( alpha )
		self.name:setAlpha( alpha )
		self.health_fill:setAlpha( alpha )
		self.health_border:setAlpha( alpha )
		self.essence_icon:setAlpha( alpha )
		self.points:setAlpha( alpha )
	end )

	LUI.OverrideFunction_CallOriginalSecond( self, "close", function ( element )
		if element.bg then element.bg:close() end
		if element.portrait then element.portrait:close() end
		if element.name then element.name:close() end
		if element.health_fill then element.health_fill:close() end
		if element.health_border then element.health_border:close() end
		if element.essence_icon then element.essence_icon:close() end
		if element.points then element.points:close() end
		if element.downedIcon then element.downedIcon:close() end
	end )
	
	if PostLoadFunc then
		PostLoadFunc( self, controller )
	end

	return self
end
