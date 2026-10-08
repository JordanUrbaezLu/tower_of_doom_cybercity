-- Aetherium Party Players Widget NEW - State-based detection
-- Handles all 3 co-op party members (indices 1, 2, 3) with a single widget
-- Uses clientfield state detection (0=alive, 1=downed, 2=dead)

require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodGlyphText" )
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
							CoD.TodHealthTint.Paint( self )
							if self.isPlayerSlotOccupied then
								self.health_track:setAlpha(1)
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
								self.health_track:setAlpha(1)
								self.health_fill:setAlpha(1)
								self.health_border:setAlpha(1)
								self.essence_icon:setAlpha(1)
								self.points:setAlpha(1)
							end
							self.downedIcon:setRGB(1, 0.2, 0.2)
							CoD.TodHealthTint.Paint( self )
							self.health_fill:setShaderVector( 0, 1, 0, 0, 0 )
							self.health_fill:beginAnimation("bleedout_timer", bleedoutTime, false, false, CoD.TweenType.Linear)
							self.health_fill:setShaderVector( 0, 0, 0, 0, 0 )
							self.portrait:setRGB(1, 1, 1)
							self.name:setRGB(1, 1, 1)
							
						elseif newState == 2 then
							-- DEAD STATE
							self.health_fill:completeAnimation()
							-- health_fill and health_track were BOTH missing here: the
							-- frame, essence and points hid on death but the FILL stayed
							-- drawn, so a dead teammate kept a floating bar with no
							-- border round it. Invisible while a plate sat behind the
							-- row; obvious the moment v17.4 removed it and added a track.
							-- The local panel's dead branch has always hidden its fill.
							self.health_track:setAlpha(0)
							self.health_fill:setAlpha(0)
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

-- [tod v19.63] THE SLOT OFFSETS, one table (they were an inline expression).
-- Slot 1 sits just above the local row; 2 and 3 stack up on the 43/42 pitch.
local TOD_ROW_OFFSET = { [1] = 0, [2] = -43, [3] = -85 }

-- [tod v19.63] Move this row to rank `rank` (1 = nearest the local row) by
-- shifting the whole widget by the difference from its own slot. Called by the
-- HUD's TodPartyRelayout whenever any row's occupancy changes, so two teammates
-- always read as two adjacent rows (Nikolai's "spaces in between the names").
CoD.AetheriumPartyPlayers.TodSetRank = function ( self, rank )
	local want = TOD_ROW_OFFSET[ rank ] or 0
	local dy = want - ( self.todOwnOffset or 0 )
	if self.todRankDy == dy then
		return
	end
	self.todRankDy = dy
	self:setTopBottom( true, false, dy, 720 + dy )
end

-- [tod 2026-09-30] TEAMMATE SHIELD BAR (user: "add ... other players shield bar
-- above their health bar ... I dont want the icon as well. Just the bar so other
-- players know"). The local panel's riot-shield bar reads zmInventory.shield_health,
-- a per-player clientuimodel no other client receives, so these rows read the
-- four-slot broadcast _zm_aetherium_hud::party_shield_watch sends to everyone:
-- scriptNotify "tod_party_shield", one int, SHIELD_BASE per slot holding the
-- percent (0 = no shield). LOCKSTEP: SHIELD_BASE == TOD_SHIELD_BITS there
-- (tools/test_party_shield.js). Same strip, wipe and blue / orange / red bands as
-- the local bar (AetheriumPlayerInfo.lua); no icon, by request.
local SHIELD_BASE = 128

local function TodPaintShield( self )
	if self.todShieldClosed or not self.shield_fill then
		return
	end
	local id = self.todShieldId
	local pct = 0
	if id ~= nil and id >= 0 and id <= 3 and self.isPlayerSlotOccupied then
		pct = math.floor( ( self.todShieldPacked or 0 ) / ( SHIELD_BASE ^ id ) ) % SHIELD_BASE
	end
	if pct <= 0 then
		self.shield_track:setAlpha( 0 )
		self.shield_fill:setAlpha( 0 )
		return
	end
	local f = math.min( pct, 100 ) / 100
	self.shield_fill:setShaderVector( 0, f, 0, 0, 0 )
	if f <= 0.33 then
		self.shield_fill:setRGB( 1, 0.4, 0.4 )      -- red when low (the local bar's bands)
	elseif f <= 0.66 then
		self.shield_fill:setRGB( 1, 0.8, 0.4 )      -- orange in the middle
	else
		self.shield_fill:setRGB( 0.4, 0.7, 1 )      -- blue when high
	end
	self.shield_track:setAlpha( 1 )
	self.shield_fill:setAlpha( 1 )
end

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
	-- Player index 1 (bottom):  Y 570.5-657.5  (BG height: 87px)
	-- Player index 2 (middle):  Y 527.5-614.5  (offset: -43px from index 1)
	-- Player index 3 (top):     Y 485.5-572.5  (offset: -42px from index 2)
	--
	-- [tod 2026-10-01] 524 -> 570.5, THE ONE-ROW GAP ABOVE THE LOCAL ROW (docs/167
	-- item 11; Nikolai's screenshots, "the name glitch spacing is still here").
	-- 524 is the kit's number from when every party row drew an 87-tall PLATE and
	-- the content sat in its LOWER half. v17.4 removed the plate and repacked the
	-- content into the TOP of the band (bgTop + 4.5 .. bgTop + 43), so slot 1's
	-- content stopped at 567 while the local row starts at 618 (its name, top
	-- 618, AetheriumPlayerInfo.lua): a 51-unit hole, one whole row pitch, under
	-- the nearest teammate in EVERY party size. v19.63's TodSetRank closed the
	-- holes BETWEEN party rows but stacks onto this same slot-1 base, so it could
	-- not close this one. Now slot 1's content ends at 613.5 = 618 - 4.5, the
	-- same 4.5 gap the party rows keep between themselves, and the name-to-name
	-- pitch to the local row is 43 like every other step. The (45, 678) scale
	-- anchor (AetheriumHud TodScalePlayerHud) is untouched; everything moves
	-- DOWN, so nothing new can reach the top of the screen.
	local baseYTop = 570.5  -- Player 1 base position
	local yOffset = TOD_ROW_OFFSET[ playerIndex ] or 0
	self.todOwnOffset = yOffset   -- v19.63: TodSetRank shifts relative to this
	local bgTop = baseYTop + yOffset
	local bgBottom = bgTop + 87  -- Height is 87 pixels

	-- Background
	-- ==========================================================================
	-- NO PLATE (v17.4, 2026-09-03 — user: "other players still have that
	-- aetherium HUD blue aura. Im trying to get all of that removed").
	--
	-- v17.0 stripped the shell off the LOCAL panel and deliberately left these
	-- teammate rows on the kit's `i_mtl_ui_hud_party_member_theme_aetherium`
	-- wisp so the two would still read as one family. With the local panel now
	-- judged in game, the wisp is the odd one out instead — so it goes, and the
	-- rows become a smaller echo of the local readout.
	--
	-- THE ROWS NOW SHARE THE LOCAL PANEL'S TEXT COLUMN AT x=90, which is the
	-- whole reason they read as one HUD without a plate to group them: four
	-- rows, one vertical spine for every name, bar and score. The portrait
	-- right-aligns to x=80, the same edge the local medallion ends on.
	-- ==========================================================================

	-- Player Portrait (offset from BG top)
	-- SQUARE, 35x35 (v16.21, 2026-09-02). This box used to be 35 wide x 40 tall,
	-- and LUI STRETCHES an image to fill it — so a 1:1 source was pulled ~14%
	-- vertically. That was invisible with the stock face portraits but glaring
	-- with the i_tod_class_medallion_* discs, because a stretched circle reads
	-- as an obvious ellipse. Width is pinned by the background art (the name and
	-- health column start at x=107, so the box cannot grow right), so the height
	-- comes down to match instead, re-centred in the original 40px band
	-- (19 + (40-35)/2 = 21). Any image put here must be SQUARE.
	local portraitTop = bgTop + 8
	local portraitBottom = portraitTop + 35
	self.portrait = LUI.UIImage.new()
	self.portrait:setLeftRight( true, false, 45, 80 )
	self.portrait:setTopBottom( true, false, portraitTop, portraitBottom )
	self.portrait:setImage( RegisterImage( "blacktransparent" ) )
	self.portrait:setAlpha( 0 )
	self:addElement( self.portrait )

	-- Player Name (offset from BG top)
	-- [tod 2026-09-30] lifted 2.5 (was bgTop + 7) to make the shield bar's slot
	-- between the name and the health bar: name ink ends 2 above the shield
	-- trough, which ends 1.5 above the health trough.
	local nameTop = bgTop + 4.5
	local nameBottom = nameTop + 12
	-- v17.34: the baked typeface, same element the local panel's name uses. The
	-- box is unchanged and still derived from the row index, because the glyph
	-- element takes the box and derives cap/baseline/fit from it rather than
	-- carrying coordinates of its own. Fallback armed -- a teammate's Steam
	-- name is arbitrary user data.
	self.name = CoD.TodGlyphText.new( {
		left = 90, right = 200, top = nameTop, bottom = nameBottom,
		-- v17.36: pool 14 -> 20 is the "+6 chars" ask (pool IS the character
		-- limit), capFrac 0.80 -> 0.96 the "+20% bigger". LOCKSTEP with the local
		-- panel's name in AetheriumPlayerInfo.lua — read the note there for why a
		-- LONG name still will not grow (these rows have a 110px box, 24 more
		-- than the local panel's, so they hit the width wall later).
		align = "left", set = "name", pool = 20,
		capFrac = 0.96,
		fallbackTTF = "fonts/orbitron.ttf",
		rgb = { 1, 1, 1 }, text = "PLAYER",
	} )
	self.name:setAlpha( 0 )
	self:addElement( self.name )

	-- [tod 2026-09-30] Shield trough + fill (see TodPaintShield above). A PERMANENT
	-- slot above the health bar, the local panel's layout rule: the bar only fades
	-- in and out, nothing else moves. Same width as the health fill; the fill is a
	-- thin 2-unit strip in a 4-unit dark trough (the local bar is 4 in 6).
	local shieldTop = bgTop + 18.5
	self.shield_track = LUI.UIImage.new()
	self.shield_track:setLeftRight( true, false, 90, 198 )
	self.shield_track:setTopBottom( true, false, shieldTop, shieldTop + 4 )
	self.shield_track:setImage( RegisterImage( "i_tod_hud_health_fill" ) )
	self.shield_track:setRGB( 0.05, 0.07, 0.11 )
	self.shield_track:setAlpha( 0 )
	self:addElement( self.shield_track )
	self.shield_fill = LUI.UIImage.new()
	self.shield_fill:setLeftRight( true, false, 91, 197 )
	self.shield_fill:setTopBottom( true, false, shieldTop + 1, shieldTop + 3 )
	self.shield_fill:setImage( RegisterImage( "i_tod_hud_health_fill" ) )
	self.shield_fill:setRGB( 0.4, 0.7, 1 )
	self.shield_fill:setMaterial( LUI.UIImage.GetCachedMaterial( "uie_wipe_normal" ) )
	self.shield_fill:setShaderVector( 0, 0, 0, 0, 0 )
	self.shield_fill:setShaderVector( 1, 0, 0, 0, 0 )
	self.shield_fill:setShaderVector( 2, 1, 0, 0, 0 )
	self.shield_fill:setShaderVector( 3, 0, 0, 0, 0 )
	self.shield_fill:setAlpha( 0 )
	self:addElement( self.shield_fill )
	-- The slot this row shows (a roster rebind or the HUD mock can change it).
	self.shield_fill:linkToElementModel( self, "clientNum", true, function ( model )
		self.todShieldId = Engine.GetModelValue( model )
		TodPaintShield( self )
	end )
	-- One subscription for the widget's lifetime, on the fill so it dies with it.
	self.shield_fill:subscribeToGlobalModel( controller, "PerController", "scriptNotify", function ( model )
		if Engine.GetModelValue( model ) ~= "tod_party_shield" then
			return
		end
		local data = CoD.GetScriptNotifyData( model )
		local value = data and data[1]
		if type( value ) ~= "number" then
			return
		end
		self.todShieldPacked = value
		TodPaintShield( self )
	end )

	-- Health track (v17.4) — the dark trough, same technique as the local panel:
	-- i_tod_hud_health_fill at a near-black tint, no wipe material, full width.
	-- With no plate behind the row an empty cell would otherwise show the game
	-- world through it. Added BEFORE the fill so it renders underneath.
	self.health_track = LUI.UIImage.new()
	self.health_track:setLeftRight(true, false, 90, 198)
	self.health_track:setTopBottom(true, false, bgTop + 24, bgTop + 34)
	self.health_track:setImage( RegisterImage( "i_tod_hud_health_fill" ) )
	self.health_track:setRGB( 0.05, 0.07, 0.11 )
	self.health_track:setAlpha( 0 )
	self:addElement( self.health_track )

	-- Health Fill (offset from BG top) - 1px insets
	local healthFillTop = bgTop + 25
	local healthFillBottom = healthFillTop + 8
	self.health_fill = LUI.UIImage.new()
	self.health_fill:setLeftRight(true, false, 91, 197)
	self.health_fill:setTopBottom(true, false, healthFillTop, healthFillBottom)
	self.health_fill:setImage( RegisterImage( "i_tod_hud_health_fill" ) )
	self.health_fill:setRGB( 1, 1, 1 )
	self.health_fill:setMaterial( LUI.UIImage.GetCachedMaterial( "uie_wipe_normal" ) )
	self.health_fill:setShaderVector( 0, 1, 0, 0, 0 )
	self.health_fill:setShaderVector( 1, 0, 0, 0, 0 )
	self.health_fill:setShaderVector( 2, 1, 0, 0, 0 )
	self.health_fill:setShaderVector( 3, 0, 0, 0, 0 )
	self.health_fill:setAlpha( 0 )
	CoD.TodHealthTint.Attach( self, controller, false )

	-- Health Border (offset from BG top)
	local healthBorderTop = bgTop + 24
	local healthBorderBottom = healthBorderTop + 10
	self.health_border = LUI.UIImage.new()
	self.health_border:setLeftRight(true, false, 90, 198)
	self.health_border:setTopBottom(true, false, healthBorderTop, healthBorderBottom)
	self.health_border:setImage( RegisterImage( "i_tod_hud_health_frame" ) )
	self.health_border:setRGB( 1, 1, 1 )
	self.health_border:setAlpha( 0 )
	self:addElement( self.health_border )

	-- Essence Icon (offset from BG top)
	local essenceTop = bgTop + 22
	local essenceBottom = essenceTop + 16
	self.essence_icon = LUI.UIImage.new()
	self.essence_icon:setLeftRight(true, false, 204, 220)
	self.essence_icon:setTopBottom(true, false, essenceTop, essenceBottom)
	self.essence_icon:setImage( RegisterImage( "i_tod_hud_points_icon" ) )
	self.essence_icon:setRGB( 1, 1, 1 )
	self.essence_icon:setAlpha( 0 )
	self:addElement( self.essence_icon )

	-- Points (offset from BG top)
	local pointsTop = bgTop + 24
	local pointsBottom = pointsTop + 12
	self.points = CoD.TodGlyphText.new( {
		left = 224, right = 310, top = pointsTop, bottom = pointsBottom,
		align = "left", set = "digits", pool = 8,
		rgb = { 0.9803921568627451, 0.9686274509803922, 0.4666666666666667 },
		text = "0",
	} )
	self.points:setAlpha( 0 )
	self:addElement( self.points )

	-- Downed Icon (offset from BG top)
	local downedTop = bgTop + 13
	local downedBottom = downedTop + 20
	self.downedIcon = LUI.UIImage.new()
	self.downedIcon:setLeftRight(true, false, 22, 42)
	self.downedIcon:setTopBottom(true, false, downedTop, downedBottom)
	self.downedIcon:setImage(RegisterImage("i_mtl_icon_ping_downed"))
	self.downedIcon:setRGB(1, 1, 1)
	self.downedIcon:setAlpha(0)  -- Hidden by default
	self:addElement(self.downedIcon)
	
	-- Portrait - reactive subscription
	self.portrait:linkToElementModel( self, "zombiePlayerIcon", true, function ( model )
		local zombiePlayerIcon = Engine.GetModelValue( model )
		if zombiePlayerIcon then
			local portraitIcon = CoD.GetClassPortrait( zombiePlayerIcon )
			-- v17.3: blank until the player HAS a class - see GetClassPortrait.
			-- Image, not alpha: the playerScoreShown handler below owns this
			-- element's alpha and would overwrite it on the next slot update.
			self.portrait:setImage( RegisterImage( portraitIcon or "blacktransparent" ) )
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
		-- v19.63: the rows close ranks around the empty slot (see TodSetRank)
		if menu and menu.TodPartyRelayout then
			menu.TodPartyRelayout()
		end
		local alpha = self.isPlayerSlotOccupied and 1 or 0
		self.health_track:setAlpha( alpha )
		self.portrait:setAlpha( alpha )
		self.name:setAlpha( alpha )
		self.health_fill:setAlpha( alpha )
		self.health_border:setAlpha( alpha )
		self.essence_icon:setAlpha( alpha )
		self.points:setAlpha( alpha )
		TodPaintShield( self )   -- an empty row never shows a shield bar
	end )

	LUI.OverrideFunction_CallOriginalSecond( self, "close", function ( element )
		element.todShieldClosed = true
		if element.shield_fill then element.shield_fill:close() end
		if element.shield_track then element.shield_track:close() end
		if element.bg then element.bg:close() end
		if element.portrait then element.portrait:close() end
		if element.name then element.name:close() end
		if element.health_fill then element.health_fill:close() end
		if element.health_border then element.health_border:close() end
		if element.health_track then element.health_track:close() end
		if element.essence_icon then element.essence_icon:close() end
		if element.points then element.points:close() end
		if element.downedIcon then element.downedIcon:close() end
	end )
	
	if PostLoadFunc then
		PostLoadFunc( self, controller )
	end

	return self
end
