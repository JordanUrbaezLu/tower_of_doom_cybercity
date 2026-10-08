require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodUIOwnership" )
-- Aetherium Player Info Widget (Bottom Left - Main Player)
-- Uses: i_tod_hud_health_frame / _health_fill / _points_icon + the class medallions (docs/89, docs/90)
-- BO6 Pattern: Uses linkToElementModel for dynamic clientNum subscription

require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPlusPointsContainer" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodGlyphText" )
require("ui.uieditor.widgets.HUD.Mappings.AetheriumBBG")
require("ui.uieditor.widgets.HUD.Mappings.AetheriumCharacters")

-- =============================================================================
-- THE TYPEFACE (v17.34, user 2026-09-04: "changing all the text on screen to
-- use our alphabet ... the text on Left that shows players name and HP").
--
-- The three readouts on this panel -- NAME, HP and POINTS -- were UIText in
-- orbitron/ltromatic. They are now CoD.TodGlyphText, which draws the same
-- strings out of the baked glyph sheets the gun HUD and the ROUND counter use.
-- The constructor takes the SAME box the UIText had, and every existing
-- setText / setRGB / setAlpha call site below is unchanged: that is the whole
-- reason the element mimics the UIText surface.
--
-- ONE BOX DID MOVE. The name was 90..200 and the HP readout is 168..220, i.e.
-- they overlapped by 32px and only stayed apart because a short name in a
-- left-aligned UIText never reached that far. The glyph row FITS its string to
-- its box, so a long name would have grown into the HP text instead of
-- shrinking. The name box now ends at 164, four pixels clear of the HP box.
-- =============================================================================


-- TEMPORARY (v17.5, 2026-09-03): replaces the player NAME with the raw numbers
-- behind the HP readout, to settle a reported "3 HP" beside a ~60%-full bar.
-- Set false / delete this and its one use below once the cause is known.
local TOD_HP_DEBUG = false

CoD.AetheriumPlayerInfo = InheritFrom( LUI.UIElement )
CoD.AetheriumPlayerInfo.new = function ( menu, controller )
	local self = LUI.UIElement.new()
    CoD.TodUIOwnership.Attach( self )

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumPlayerInfo )
	self.id = "AetheriumPlayerInfo"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self.anyChildUsesUpdateState = true

	-- ==========================================================================
	-- THE SHELL IS GONE (v17.0, 2026-09-03 — user: "i do want to make it
	-- minimal and remove that whole shell part just the icon no square, name,
	-- money, health, and maybe something for shield health").
	--
	-- The v16.98 plate (i_tod_hud_player_plate, one build old) drew the frame,
	-- the square portrait bay and the dark readout slab. All three go. What is
	-- left is five free-floating readouts anchored bottom-left, in a 226 x 60
	-- canvas box (x 24..250, y 618..678) — about a THIRD the area the panel
	-- used, and the square around the class disc disappears with the plate
	-- because the square WAS the plate.
	--
	-- The image is retired from the .zone but its file and gdt block stay:
	-- bringing the shell back is one `image,` line plus this element. Leaving
	-- it zoned-but-undrawn would be 3 MB of load RAM for nothing AND would trip
	-- the asset lint's dead-art bucket.
	--
	-- WHAT THE PLATE WAS ACTUALLY DOING, so it is not re-learned the hard way:
	-- it supplied CONTRAST. Its dark slab is why white text and a white health
	-- bar read. Floating, the bar's empty cells show the world through them and
	-- its steel border vanishes against anything pale. `health_track` below is
	-- the replacement for that job, and docs/90 asks for art that does it
	-- properly.
	-- ==========================================================================

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
	--
	-- SQUARE, 16x16 (v16.97, 2026-09-03) - was 16 wide x 15 tall, i.e. a
	-- 256x256 glyph squeezed 6.7% horizontally. Small next to the portrait's
	-- 13.6%, but the same defect: re-centred on the original band
	-- (669.5 +/- 8 = 661..677).
	--
	-- IT WAS NEVER A RESOLUTION PROBLEM, which is worth writing down because it
	-- looked like one and the natural fix ("get 4K icons") could not have
	-- worked. This box is 24x24 PHYSICAL pixels on a 1080p screen against a
	-- 256x256 source — the glyph was already drawn at ~10x the pixels it is
	-- ever shown at, using 9% of its source width. What was actually lost was
	-- (a) DXT5 block compression on the kit's image and (b) a lit, beveled 3D
	-- render whose gradients cannot survive a 10x downsample.
	--
	-- OURS SINCE v16.97: i_tod_hud_points_icon, 256x256, uncompressed (docs/89).
	-- Same Z-with-two-bars symbol, redrawn FLAT for the 24 px read — thick
	-- strokes, a hard 6px dark outline, a visible gap where the Z crosses the
	-- bars, and no bevel, gloss or gradient ramp at all.
	self.points_icon = LUI.UIImage.new()
	self.points_icon:setLeftRight(true, false, 90, 106)
	self.points_icon:setTopBottom(true, false, 662, 678)
	self.points_icon:setImage( RegisterImage( "i_tod_hud_points_icon" ) )
	self.points_icon:setRGB( 1.000, 1.000, 1.000 )
	self.points_icon:setAlpha( 1.0 )
	self:addElement( self.points_icon )

	-- Points Amount (elem4) - TEXT (reactive to playerScore)
	-- DIGIT SET. A score is only ever digits, so there is no letter sheet in
	-- play and no fallback lane: every character it can carry has a glyph.
	self.points_amount = CoD.TodGlyphText.new( {
		left = 110, right = 200, top = 664, bottom = 677,
		align = "left", set = "digits", pool = 8,
		rgb = { 0.984313725490196, 0.9725490196078431, 0.4745098039215686 },
	} )
	self.points_amount:linkToElementModel( self, "playerScore", true, function ( model )
		local playerScore = Engine.GetModelValue( model )
		if playerScore then
			self.points_amount:setText( Engine.Localize( playerScore ) )
		end
	end )
	self.points_amount:setAlpha( 1.0 )
	self:addElement( self.points_amount )

	-- Player Name (elem28) - TEXT (reactive to playerName)
	-- NAME SET, with the TTF fallback armed: this is arbitrary user data (a
	-- Steam name), and a name with no A-Z or 0-9 in it at all -- all-Cyrillic,
	-- all-emoji -- must still appear on its owner's own HUD.
	-- v17.36 (user 2026-09-04, after playing v17.34: "The names in the left for
	-- players needs to be like 20% bigger" + "increase the possible limit of
	-- characters in a name ... by like 6 chars").
	--
	-- ⚠️ THE TWO ASKS PULL AGAINST EACH OTHER, and the screenshot is what proved
	-- which one was binding. "GLIDE GLADIATO" filled the box edge to edge, so
	-- that name was WIDTH-limited, not cap-limited: the fit had already pulled it
	-- down to cap ~7.0 and raising capFrac alone would have done NOTHING for it.
	--   * A SHORT name (<= ~10 chars) is cap-limited, and capFrac 0.80 -> 0.96
	--     is the +20% asked for, exactly.
	--   * A LONG name is width-limited, and only a wider BOX moves it: 74 -> 86
	--     px here, +16%, taken from the HP readout's slack (see below).
	--   * A 20-character name will still be smaller than a 14-character one.
	--     That is arithmetic, not a bug. Making long names big too means moving
	--     the HP readout out of this row entirely and giving the name all of
	--     90..220 — a bigger layout change than was asked for, and the next step
	--     if these two are still not enough.
	-- LOCKSTEP with the teammate rows in AetheriumPartyPlayers.lua — the two name
	-- readouts are one family and were judged in the same glance.
	self.player_name = CoD.TodGlyphText.new( {
		left = 90, right = 176, top = 618, bottom = 630,
		-- pool IS the character limit (a too-long string is cut here so measure
		-- and draw agree). 14 -> 20 is the "+6 chars" ask.
		align = "left", set = "name", pool = 20,
		capFrac = 0.96,
		fallbackTTF = "fonts/orbitron.ttf",
		rgb = { 1.000, 1.000, 1.000 },
	} )
	self.player_name:linkToElementModel( self, "playerName", true, function ( model )
		local playerName = Engine.GetModelValue( model )
		if playerName then
			self.player_name:setText( Engine.Localize( playerName ) )
		end
	end )
	self.player_name:setAlpha( 1.0 )
	self:addElement( self.player_name )

	-- ==========================================================================
	-- THE TRACKS (v17.0) — the dark backing each bar drains against.
	--
	-- With the shell gone there is nothing behind the bars, so an empty cell
	-- showed the world through it and a half-empty bar had no visible length.
	-- These two elements are the plate's contrast job, kept and nothing else.
	--
	-- THEY REUSE i_tod_hud_health_fill AT A NEAR-BLACK TINT rather than adding
	-- an asset. That works because of what that image already had to be: opaque
	-- edge-to-edge, and identical in every column (the wipe contract). Tinted
	-- to 0.06 it is exactly a flat dark strip. No new image, no new zone line,
	-- no new GDT block — and it ships in this build instead of waiting on art.
	-- docs/90 asks for a purpose-built track with a soft outer shadow, which is
	-- the part a tint genuinely cannot fake against a bright background.
	--
	-- NO WIPE MATERIAL AND NO SHADER VECTORS here: a track is always full
	-- width. Added BEFORE its fill so it renders underneath.
	-- ==========================================================================
	self.shield_track = LUI.UIImage.new()
	self.shield_track:setLeftRight(true, false, 90, 220)
	self.shield_track:setTopBottom(true, false, 636, 642)
	self.shield_track:setImage( RegisterImage( "i_tod_hud_health_fill" ) )
	self.shield_track:setRGB( 0.05, 0.07, 0.11 )
	self.shield_track:setAlpha( 0 )   -- follows the shield bar's own visibility
	self:addElement( self.shield_track )

	-- Shield Health Bar (Blue bar above normal health bar)
	--
	-- v16.97: moved onto OUR i_tod_hud_health_fill, the same strip the health
	-- bar uses. Strictly better on all three counts — uncompressed instead of
	-- DXT5, near-neutral so the blue tint below stays clean, and column-uniform
	-- so this wipe cannot slice a feature either. It also retires the +67%
	-- aspect stretch the kit's 448x40 party strip had in this 131x7 box (that
	-- was invisible on flat art, but it was still wrong).
	-- This lane only draws now that v16.63 made the riot shield live.
	self.shield_health_fill = LUI.UIImage.new()
	self.shield_health_fill:setLeftRight(true, false, 91, 219)
	self.shield_health_fill:setTopBottom(true, false, 637, 641)
	self.shield_health_fill:setImage( RegisterImage( "i_tod_hud_health_fill" ) )
	self.shield_health_fill:setRGB( 0.4, 0.7, 1 )  -- Blue color for shield
	self.shield_health_fill:setMaterial( LUI.UIImage.GetCachedMaterial( "uie_wipe_normal" ) )
	self.shield_health_fill:setShaderVector( 0, 0, 0, 0, 0 )  -- Start at 0 (hidden)
	self.shield_health_fill:setShaderVector( 1, 0, 0, 0, 0 )
	self.shield_health_fill:setShaderVector( 2, 1, 0, 0, 0 )
	self.shield_health_fill:setShaderVector( 3, 0, 0, 0, 0 )
	self.shield_health_fill:setAlpha( 0 )  -- Hidden by default (no shield)
	self:addElement( self.shield_health_fill )

	-- Health track (see THE TRACKS above) — always visible, always full width.
	self.health_track = LUI.UIImage.new()
	self.health_track:setLeftRight(true, false, 90, 220)
	self.health_track:setTopBottom(true, false, 645, 657)
	self.health_track:setImage( RegisterImage( "i_tod_hud_health_fill" ) )
	self.health_track:setRGB( 0.05, 0.07, 0.11 )
	self.health_track:setAlpha( 1 )
	self:addElement( self.health_track )

	-- Health Fill (added BEFORE border so border renders on top)
	--
	-- OURS SINCE v16.97: i_tod_hud_health_fill, 1016x80, uncompressed. It is
	-- authored COLUMN-UNIFORM on purpose and that is a hard contract, not a
	-- style choice — `uie_wipe_normal` below cuts this image at an arbitrary x
	-- every frame as health drains, so any horizontal feature would be sliced
	-- mid-shape. It is also near-neutral white (max saturation 16/255) because
	-- the state machine TINTS it: setRGB(1,1,1) alive, setRGB(1,0.2,0.2) downed.
	-- Baked-in colour would multiply into mud on the down.
	-- Verified on install: every column identical, alpha 255 everywhere.
	self.health_fill = LUI.UIImage.new()
	self.health_fill:setLeftRight(true, false, 91, 219)
	self.health_fill:setTopBottom(true, false, 646, 656)
	self.health_fill:setImage( RegisterImage( "i_tod_hud_health_fill" ) )
	self.health_fill:setRGB( 1, 1, 1 )
	self.health_fill:setMaterial( LUI.UIImage.GetCachedMaterial( "uie_wipe_normal" ) )
	self.health_fill:setShaderVector( 0, 1, 0, 0, 0 )
	self.health_fill:setShaderVector( 1, 0, 0, 0, 0 )
	self.health_fill:setShaderVector( 2, 1, 0, 0, 0 )
	self.health_fill:setShaderVector( 3, 0, 0, 0, 0 )
	CoD.TodHealthTint.Attach( self, controller, true )

	-- Health Border (added AFTER fill - renders on top)
	--
	-- OURS SINCE v16.97: i_tod_hud_health_frame, 1032x96, uncompressed —
	-- **15 CELLS, NOT THE KIT'S ~48**. That count is the whole fix. The bar is
	-- 194 physical pixels wide on a 1080p screen, so 48 segments left under 4
	-- px each including their gaps and the bar resolved to a grey smear; no
	-- amount of source resolution helps that, only fewer and fatter segments.
	-- The cell interiors are FULLY transparent (verified alpha 0 on install) so
	-- the tinted fill underneath shows through clean.
	--
	-- The box grows 9 -> 12 canvas px. 648..660 is the whole free band: the
	-- shield bar ends at 648 and the points icon starts at 661.
	self.health_border = LUI.UIImage.new()
	self.health_border:setLeftRight(true, false, 90, 220)
	self.health_border:setTopBottom(true, false, 645, 657)
	self.health_border:setImage( RegisterImage( "i_tod_hud_health_frame" ) )
	self.health_border:setRGB( 1, 1, 1 )
	self:addElement( self.health_border )

	-- Downed Indicator (Player 1 - Local Player)
	self.downedIcon = LUI.UIImage.new()
	self.downedIcon:setLeftRight(true, false, 226, 250)
	self.downedIcon:setTopBottom(true, false, 644, 668)
	self.downedIcon:setImage(RegisterImage("i_mtl_icon_ping_downed"))
	self.downedIcon:setRGB(1, 1, 1)
	self.downedIcon:setAlpha(0)  -- Hidden by default
	self:addElement(self.downedIcon)

	-- Player HP (elem29) - TEXT (reactive to player_health_X)
	-- NAME SET, because "150 HP" mixes both sheets -- the row cap-normalizes
	-- them onto one baseline, exactly as "ROUND 12" and "AK-47" do.
	-- v17.36: 168..220 -> 180..226, which is where the 12px the name gained came
	-- from. The box is 6px WIDER than before, not narrower, so nothing about the
	-- HP readout shrinks: "150 HP" measures ~41px at this cap and had 52px, now
	-- has 46. 226 is the shield icon's left edge — they touch, they do not
	-- overlap, and that is the hard right stop for anything on this row.
	self.player_hp = CoD.TodGlyphText.new( {
		left = 180, right = 226, top = 619, bottom = 631,
		align = "center", set = "name", pool = 8,
		rgb = { 1.0, 1.0, 1.0 },
	} )
	self:addElement( self.player_hp )
	
	-- Player Character Portrait (elem32) - IMAGE (reactive to zombiePlayerIcon)
	--
	-- SQUARE, 51x51 (v16.97, 2026-09-03). This is THE SAME BUG v16.21 fixed in
	-- AetheriumPartyPlayers.lua:191-195 for the TEAMMATE rows, on the same day,
	-- in the same pass -- and the local player's own panel was missed. The box
	-- was 51 wide x 59 tall and LUI STRETCHES an image to fill its box, so the
	-- 256x256 i_tod_class_medallion_* discs were pulled 13.6% vertically: a
	-- circle drawn as an obvious ellipse, bottom-left, where the player looks
	-- most. (User 2026-09-03: "the icons ... kinda squished".)
	--
	-- Width is pinned by the plate art, exactly as it is on the party rows: the
	-- portrait bay painted into ui_hud_player_info_theme_aetherium is about
	-- x32..88 on this canvas and the name text starts at x=98, so the box cannot
	-- grow right. The height comes down to match instead, re-centred in the
	-- original 59px band (625 + (59-51)/2 = 629).
	--
	-- ANY IMAGE PUT HERE MUST BE SQUARE. The four medallions are 256x256; the
	-- operator-face fallbacks (i_mtl_ui_icon_operators_*) are 232x252, which is
	-- a 8% squeeze the other way -- acceptable on a face, and that path only
	-- runs if a character id is unmapped, which is itself the bug to fix.
	self.player_portrait = LUI.UIImage.new()
	self.player_portrait:setLeftRight(true, false, 24, 80)
	self.player_portrait:setTopBottom(true, false, 620, 676)
	self.player_portrait:setImage( RegisterImage( "blacktransparent" ) )
	self.player_portrait:linkToElementModel( self, "zombiePlayerIcon", true, function ( model )
		local zombiePlayerIcon = Engine.GetModelValue( model )
		if zombiePlayerIcon then
			local portraitIcon = CoD.GetClassPortrait( zombiePlayerIcon )
			-- v17.3: blank until the player HAS a class - see GetClassPortrait.
			self.player_portrait:setImage( RegisterImage( portraitIcon or "blacktransparent" ) )
		end
	end )
	self:addElement( self.player_portrait )

	-- Shield Icon (shows when shield is equipped)
	self.shield_icon = LUI.UIImage.new()
	self.shield_icon:setLeftRight(true, false, 226, 246)
	self.shield_icon:setTopBottom(true, false, 620, 640)
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
						self.player_hp:setText( CoD.TodAuraTint( self, math.ceil( self.currentHealth * self.maxHealth ) ) )
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

					-- ==========================================================
					-- TEMPORARY DIAGNOSTIC (v17.5, 2026-09-03) — REMOVE ONCE
					-- SOLVED. User reported "3 HP" beside a ~60%-full bar; the
					-- two disagree and static reading did not explain it.
					--
					-- RULED OUT ON PAPER, so do not re-check these: the d[1]
					-- notify index matches every other reader in the tree and
					-- the kit; ints below 2^24 survive the lane intact so 150
					-- is safe; nothing in scripts/ sets .maxhealth below 150
					-- (max_hp_floor is 150 + vitality); and god mode floors
					-- health at 1 without touching maxhealth.
					--
					-- WHAT IS LEFT is a disagreement between the two consumers
					-- of the SAME model value: the text uses `health` as a
					-- NUMBER, while the bar feeds it through
					-- GetVectorComponentFromString as a VECTOR STRING. If the
					-- model carries "0.62 0 0 0" the bar is right and the text
					-- is arithmetic on a coerced string; if it carries a plain
					-- float they should agree and something else is wrong.
					-- This prints both interpretations plus maxHealth so the
					-- next run says which, instead of another round of theory.
					-- ⚠️ v17.34: this lane now draws through the GLYPH cleaner,
					-- which keeps only A-Z 0-9 and - ' . — so every "=" below is
					-- silently dropped and the readout comes out as
					-- "RAW0.62 VEC10.62 MAX150". Legible, but if this is ever
					-- re-armed, either read it that way or point it at a plain
					-- LUI.UIText of its own.
					if TOD_HP_DEBUG then
						-- the name box is 110 wide and this string is not; widen
						-- it here rather than in the constructor so removing this
						-- whole block restores the shipping layout exactly.
						-- setBox, not setLeftRight: the glyph readout derives its
						-- cap and its fit from the box, so it has to be told
						-- through the one call that repaints (v17.34).
						self.player_name:setBox( 90, 760, 618, 630 )
						self.player_name:setText( Engine.Localize(
							"raw=" .. tostring( health )
							.. "  vec1=" .. tostring( CoD.GetVectorComponentFromString( health, 1 ) )
							.. "  max=" .. tostring( maxHealth )
							.. "  txt=" .. tostring( currentHealth )
							.. "  state=" .. tostring( self.currentPlayerState ) ) )
					end
					-- ==========================================================
					
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
							CoD.TodHealthTint.Paint( self )
							self.health_fill:setAlpha(1)
							self.health_border:setAlpha(1)
							self.health_track:setAlpha(1)
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
							CoD.TodHealthTint.Paint( self )
							self.health_fill:setAlpha(1)
							self.health_border:setAlpha(1)
							self.health_track:setAlpha(1)
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
							self.health_track:setAlpha(0)
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
					self.shield_track:setAlpha( 1 )
					self.shield_icon:setAlpha( 1 )

				-- NOTHING MOVES ANY MORE (v17.0). This used to slide the name, the
				-- HP text and the downed icon to a second set of coordinates while
				-- a shield was up, and slide them "back to the original position"
				-- when it dropped — six hardcoded pairs, in a second place, that
				-- had to track the constructor by hand. They did not: the "original"
				-- HP position here was 640..647 against a constructor that has said
				-- 631..639 since the kit was vendored, so dropping a shield left the
				-- HP text somewhere it had never spawned. A layout written twice is
				-- a layout that drifts.
				--
				-- The minimal layout reserves the shield bar a PERMANENT slot
				-- (y 637..641) whether or not a shield is held, so the bar simply
				-- fades in and out of a gap that is always there. Alpha is the only
				-- thing this handler touches now.
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
					-- (nothing else moves; see the note in the branch above)
					self.shield_health_fill:setAlpha( 0 )
					self.shield_track:setAlpha( 0 )
					self.shield_icon:setAlpha( 0 )
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
								
								-- Bound concurrent glyph popups, including interrupted clips.
								if points ~= 0 and points >= -10000 and points <= 10000 then
									CoD.AetheriumPlusPointsContainer.Show( self, menu, controller, points )
								end
							end
						end )
					end
				end
			end
		end
	end )


	-- v19.11 — NO GENERIC CHILD-WALK CLOSE HERE, DELIBERATELY. This widget
	-- already has one: CoD.TodHealthTint.Attach( self, ... ) installs a close
	-- override that walks and closes its own wrapper's children and then the
	-- wrapper. Adding a second walk over this widget's children closed that
	-- wrapper TWICE and tools/test_ui_lifetimes.lua caught it ("element closed
	-- twice"). ⚠️ SO THIS WIDGET'S OTHER ELEMENTS (the name, HP, borders, the
	-- downed icon) ARE STILL NOT CLOSED — covering them needs the two overrides
	-- reconciled into one owner, not a second walk bolted on.

	return self
end
