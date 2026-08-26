-- Aetherium Custom Scoreboard Widget
-- BO6-style scoreboard with custom design

CoD.AetheriumScoreboard = InheritFrom( LUI.UIElement )

local PreLoadFunc = function ( self, controller )
	-- Set scoreboard UI models (BO6 pattern)
	if CoD.ScoreboardUtility and CoD.ScoreboardUtility.SetScoreboardUIModels then
		CoD.ScoreboardUtility.SetScoreboardUIModels( controller )
	end
end

local PostLoadFunc = function ( self, controller )
	-- Subscribe to scoreboard open/close events
	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN ), function ( model )
		local isOpen = Engine.GetModelValue( model )
		self.m_inputDisabled = not isOpen
	end )
end

CoD.AetheriumScoreboard.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumScoreboard )
	self.id = "AetheriumScoreboard"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self:makeFocusable()
	self.onlyChildrenFocusable = true
	self.anyChildUsesUpdateState = true

	-- ========================================
	-- BACKGROUND LAYERS
	-- ========================================

	-- Main background overlay
	self.bg_overlay_1 = LUI.UIImage.new()
	self.bg_overlay_1:setLeftRight( true, false, 1, 1281 )
	self.bg_overlay_1:setTopBottom( true, false, 0, 720 )
	self.bg_overlay_1:setImage( RegisterImage( "i_mtl_image_67c0e1be4519503c" ) )
	self.bg_overlay_1:setRGB( 1, 1, 1 )
	self:addElement( self.bg_overlay_1 )

	-- Background particles
	self.bg_particles = LUI.UIImage.new()
	self.bg_particles:setLeftRight(true, false, 1, 1281)
	self.bg_particles:setTopBottom(true, false, 0, 720)
	self.bg_particles:setImage( RegisterImage( "i_mtl_image_2a0561747aef24aa" ) )
	self.bg_particles:setRGB( 1, 1, 1 )
	self:addElement( self.bg_particles )

	-- Secondary overlay
	self.bg_overlay_2 = LUI.UIImage.new()
	self.bg_overlay_2:setLeftRight(true, false, 1, 1281)
	self.bg_overlay_2:setTopBottom(true, false, 0, 720)
	self.bg_overlay_2:setImage( RegisterImage( "i_mtl_image_40d71e2f7898114c" ) )
	self.bg_overlay_2:setRGB( 1, 1, 1 )
	self:addElement( self.bg_overlay_2 )

	-- Quest color header

		-- Require and add the new quest widget
		local AetheriumQuestsCustom = require("ui.uieditor.widgets.HUD.AetheriumWidgets.Scoreboard.AetheriumQuestsCustom")
		self.questWidget = AetheriumQuestsCustom.new(menu, controller)
		self:addElement(self.questWidget)


	-- ========================================
	-- PLAYER ROW BACKGROUNDS
	-- ========================================

	-- Player 4 outline
	self.player_4_outline = LUI.UIImage.new()
	self.player_4_outline:setLeftRight(true, false, 124, 1158)
	self.player_4_outline:setTopBottom(true, false, 526, 558)
	self.player_4_outline:setImage( RegisterImage( "i_mtl_image_6d18dfae10338ee0" ) )
	self.player_4_outline:setRGB( 1, 1, 1 )
	self:addElement( self.player_4_outline )

	-- Player 4 outline background
	self.player_4_outline_bg = LUI.UIImage.new()
    self.player_4_outline_bg:setLeftRight(true, false, 124, 1157)
    self.player_4_outline_bg:setTopBottom(true, false, 526, 557)
	self.player_4_outline_bg:setImage( RegisterImage( "i_mtl_image_67118f82e09c58d9_light" ) )
	self.player_4_outline_bg:setRGB( 1, 1, 1 )
	self:addElement( self.player_4_outline_bg )

	-- Player 3 outline
	self.player_3_outline = LUI.UIImage.new()
	self.player_3_outline:setLeftRight( true, false, 124, 1158 )
	self.player_3_outline:setTopBottom( true, false, 494, 526 )
	self.player_3_outline:setImage( RegisterImage( "i_mtl_image_6d18dfae10338ee0" ) )
	self.player_3_outline:setRGB( 1, 1, 1 )
	self:addElement( self.player_3_outline )

	-- Player 3 outline background
	self.player_3_outline_bg = LUI.UIImage.new()
    self.player_3_outline_bg:setLeftRight(true, false, 124, 1157)
    self.player_3_outline_bg:setTopBottom(true, false, 493, 526)
	self.player_3_outline_bg:setImage( RegisterImage( "i_mtl_image_67118f82e09c58d9_light" ) )
	self.player_3_outline_bg:setRGB( 1, 1, 1 )
	self:addElement( self.player_3_outline_bg )

	-- Player 2 outline
	self.player_2_outline = LUI.UIImage.new()
	self.player_2_outline:setLeftRight( true, false, 124, 1158 )
	self.player_2_outline:setTopBottom( true, false, 462, 494 )
	self.player_2_outline:setImage( RegisterImage( "i_mtl_image_6d18dfae10338ee0" ) )
	self.player_2_outline:setRGB( 1, 1, 1 )
	self:addElement( self.player_2_outline )

	-- Player 2 outline background
	self.player_2_outline_bg = LUI.UIImage.new()
    self.player_2_outline_bg:setLeftRight(true, false, 124, 1157)
    self.player_2_outline_bg:setTopBottom(true, false, 462, 493)
	self.player_2_outline_bg:setImage( RegisterImage( "i_mtl_image_67118f82e09c58d9_light" ) )
	self.player_2_outline_bg:setRGB( 1, 1, 1 )
	self:addElement( self.player_2_outline_bg )

	-- Player 1 outline
	self.player_1_outline = LUI.UIImage.new()
	self.player_1_outline:setLeftRight( true, false, 124, 1158 )
	self.player_1_outline:setTopBottom( true, false, 430, 462 )
	self.player_1_outline:setImage( RegisterImage( "i_mtl_image_6d18dfae10338ee0" ) )
	self.player_1_outline:setRGB( 1, 1, 1 )
	self:addElement( self.player_1_outline )

	-- Player 1 outline background
	self.player_1_outline_bg = LUI.UIImage.new()
    self.player_1_outline_bg:setLeftRight(true, false, 124, 1157)
    self.player_1_outline_bg:setTopBottom(true, false, 431, 462)
	self.player_1_outline_bg:setImage( RegisterImage( "i_mtl_image_67118f82e09c58d9_light" ) )
	self.player_1_outline_bg:setRGB( 1, 1, 1 )
	self:addElement( self.player_1_outline_bg )

	-- Player hover element (currently not visible - can be enabled for focused player)
	self.player_hover_element = LUI.UIImage.new()
    self.player_hover_element:setLeftRight(true, false, 124, 1156)
    self.player_hover_element:setTopBottom(true, false, 430, 461)
	self.player_hover_element:setImage( RegisterImage( "i_mtl_image_31890d5179c65d58" ) )
	self.player_hover_element:setRGB( 1, 1, 1 )
	self.player_hover_element:setAlpha( 0 ) -- Hidden by default
	self:addElement( self.player_hover_element )

	-- ========================================
	-- BOTTOM INFO (Points & Salvage)
	-- ========================================

	-- Points icon
	self.points_icon = LUI.UIImage.new()
    self.points_icon:setLeftRight(true, false, 537, 556)
    self.points_icon:setTopBottom(true, false, 577, 597)
	self.points_icon:setImage( RegisterImage( "i_mtl_ui_icons_zombie_essence" ) )
	self.points_icon:setRGB( 1, 1, 1 )
	self:addElement( self.points_icon )

	-- Points label
	self.points_label = LUI.UIText.new()
	self.points_label:setLeftRight(true, false, 556, 649)
	self.points_label:setTopBottom(true, false, 586, 594)
	self.points_label:setText( Engine.Localize( "Points" ) )
	self.points_label:setTTF( "fonts/ltromatic.ttf" )
	self.points_label:setRGB( 0.941, 0.941, 0.941 )
	self.points_label:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.points_label )

	-- Points value (dynamic - subscribed to player score model)
	self.points_value = LUI.UIText.new()
	self.points_value:setLeftRight(true, false, 503, 650)
	self.points_value:setTopBottom(true, false, 600, 625)
	self.points_value:setText( Engine.Localize( "0" ) )
	self.points_value:setTTF( "fonts/ltromatic.ttf" )
	self.points_value:setRGB(0.996078431372549, 0.9921568627450981, 0.4980392156862745)
	self.points_value:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	-- Subscribe to local player score
	self.points_value:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "PlayerList." .. Engine.GetClientNum( controller ) .. ".playerScore" ), function ( model )
		local score = Engine.GetModelValue( model )
		if score then
			self.points_value:setText( Engine.Localize( score ) )
		end
	end )
	self:addElement( self.points_value )

	-- Salvage icon
	self.salvage_icon = LUI.UIImage.new()
	self.salvage_icon:setLeftRight(true, false, 701, 720)
	self.salvage_icon:setTopBottom(true, false, 576, 596)
	self.salvage_icon:setImage( RegisterImage( "i_mtl_ui_icons_zombie_squad_info_salvage" ) )
	self.salvage_icon:setRGB( 1, 1, 1 )
	self:addElement( self.salvage_icon )

	-- Salvage label
	self.salvage_label = LUI.UIText.new()
	self.salvage_label:setLeftRight(true, false, 721, 814)
	self.salvage_label:setTopBottom(true, false, 585, 593)
	self.salvage_label:setText( Engine.Localize( "Salvage" ) )
	self.salvage_label:setTTF( "fonts/ltromatic.ttf" )
	self.salvage_label:setRGB( 0.941, 0.941, 0.941 )
	self.salvage_label:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.salvage_label )

	-- Salvage value (dynamic - would need custom clientfield for salvage system)
	self.salvage_value = LUI.UIText.new()
	self.salvage_value:setLeftRight(true, false, 667, 814)
	self.salvage_value:setTopBottom(true, false, 600, 625)
	self.salvage_value:setText( Engine.Localize( "0" ) )
	self.salvage_value:setTTF( "fonts/ltromatic.ttf" )
	self.salvage_value:setRGB( 0.941, 0.941, 0.941 )
	self.salvage_value:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	-- TODO: Subscribe to salvage model when implemented
	self:addElement( self.salvage_value )

	-- ========================================
	-- TOP LEFT MAP INFO
	-- ========================================

	-- Map info background
	self.map_info_bg = LUI.UIImage.new()
    self.map_info_bg:setLeftRight(true, false, 15, 323)
    self.map_info_bg:setTopBottom(true, false, 48, 86)
	self.map_info_bg:setImage( RegisterImage( "i_mtl_image_6f2d9c8089a2153e" ) )
	self.map_info_bg:setRGB( 1, 1, 1 )
	self:addElement( self.map_info_bg )

	-- Game mode text
	self.game_mode_text = LUI.UIText.new()
	self.game_mode_text:setLeftRight(true, false, 39, 311)
	self.game_mode_text:setTopBottom(true, false, 38, 57)
	self.game_mode_text:setText( Engine.Localize( "ROUNDBASED ZOMBIES" ) )
	self.game_mode_text:setTTF( "fonts/orbitron.ttf" )
	self.game_mode_text:setRGB( 0.941, 0.941, 0.941 )
	self.game_mode_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.game_mode_text )

	-- Map name (dynamic from CoD.UsermapName)
	self.map_name_text = LUI.UIText.new()
	self.map_name_text:setLeftRight(true, false, 50, 241)
	self.map_name_text:setTopBottom(true, false, 20, 31)
	self.map_name_text:setText( Engine.Localize( CoD.UsermapName or "MAP_NAME" ) )
	self.map_name_text:setTTF( "fonts/orbitron.ttf" )
	self.map_name_text:setRGB( 0.941, 0.941, 0.941 )
	self.map_name_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.map_name_text )

	-- Round label
	self.round_label = LUI.UIText.new()
	self.round_label:setLeftRight(true, false, 158, 211)
	self.round_label:setTopBottom(true, false, 20, 31)
	self.round_label:setText( Engine.Localize( "ROUND" ) )
	self.round_label:setTTF( "fonts/orbitron.ttf" )
	self.round_label:setRGB( 0.941, 0.941, 0.941 )
	self.round_label:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.round_label )

	-- Round number (dynamic from round model)
	self.round_number = LUI.UIText.new()
	self.round_number:setLeftRight(true, false, 210, 263)
	self.round_number:setTopBottom(true, false, 20, 31)
	self.round_number:setText( Engine.Localize( "1" ) )
	self.round_number:setTTF( "fonts/orbitron.ttf" )
	self.round_number:setRGB( 0.941, 0.941, 0.941 )
	self.round_number:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	-- Subscribe to round number
	self.round_number:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "gameScore.roundsPlayed" ), function ( model )
		local roundsPlayed = Engine.GetModelValue( model )
		if roundsPlayed then
			-- BO3 counts rounds starting at 1, but display shows current round (roundsPlayed - 1)
			local currentRound = math.max( 1, roundsPlayed - 1 )
			self.round_number:setText( Engine.Localize( currentRound ) )
		end
	end )
	self:addElement( self.round_number )

	-- ========================================
	-- SCOREBOARD HEADER
	-- ========================================

	-- Header background
	self.scoreboard_header = LUI.UIImage.new()
	self.scoreboard_header:setLeftRight( true, false, 124, 1158 )
	self.scoreboard_header:setTopBottom( true, false, 397, 430 )
	self.scoreboard_header:setImage( RegisterImage( "i_mtl_image_67118f82e09c58d9" ) )
	self.scoreboard_header:setRGB( 1, 1, 1 )
	self:addElement( self.scoreboard_header )

	-- Header Column: # (Player ID)
	self.header_id = LUI.UIText.new()
	self.header_id:setLeftRight( true, false, 152, 165 )
	self.header_id:setTopBottom( true, false, 407, 420 )
	self.header_id:setText( Engine.Localize( "#" ) )
	self.header_id:setTTF( "fonts/ltromatic.ttf" )
	self.header_id:setRGB( 0.047, 0.776, 0.913 ) -- BO6 cyan
	self.header_id:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_id )

	-- Header Column: Level
	self.header_level = LUI.UIText.new()
    self.header_level:setLeftRight(true, false, 200, 243)
    self.header_level:setTopBottom(true, false, 409, 420)
	self.header_level:setText( Engine.Localize( "Level" ) )
	self.header_level:setTTF( "fonts/ltromatic.ttf" )
	self.header_level:setRGB( 0.047, 0.776, 0.913 )
	self.header_level:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_level )

	-- Header Column: Name
	self.header_name = LUI.UIText.new()
    self.header_name:setLeftRight(true, false, 346, 382)
    self.header_name:setTopBottom(true, false, 409, 420)
	self.header_name:setText( Engine.Localize( "Name" ) )
	self.header_name:setTTF( "fonts/ltromatic.ttf" )
	self.header_name:setRGB( 0.047, 0.776, 0.913 )
	self.header_name:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_name )

	-- Header Column: Total Points
	self.header_points = LUI.UIText.new()
	self.header_points:setLeftRight(true, false, 526, 672)
	self.header_points:setTopBottom(true, false, 409, 418)
	self.header_points:setText( Engine.Localize( "Total Points" ) )
	self.header_points:setTTF( "fonts/ltromatic.ttf" )
	self.header_points:setRGB( 0.047, 0.776, 0.913 )
	self.header_points:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_points )

	-- Header Column: Eliminations
	self.header_kills = LUI.UIText.new()
	self.header_kills:setLeftRight(true, false, 661, 749)
	self.header_kills:setTopBottom(true, false, 409, 418)
	self.header_kills:setText( Engine.Localize( "Eliminations" ) )
	self.header_kills:setTTF( "fonts/ltromatic.ttf" )
	self.header_kills:setRGB( 0.047, 0.776, 0.913 )
	self.header_kills:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_kills )

	-- Header Column: Critical Kills
	self.header_headshots = LUI.UIText.new()
    self.header_headshots:setLeftRight(true, false, 788, 885)
    self.header_headshots:setTopBottom(true, false, 409, 419)
	self.header_headshots:setText( Engine.Localize( "Critical Kills" ) )
	self.header_headshots:setTTF( "fonts/ltromatic.ttf" )
	self.header_headshots:setRGB( 0.047, 0.776, 0.913 )
	self.header_headshots:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_headshots )

	-- Header Column: Downs
	self.header_downs = LUI.UIText.new()
    self.header_downs:setLeftRight(true, false, 934, 981)
    self.header_downs:setTopBottom(true, false, 409, 418)
	self.header_downs:setText( Engine.Localize( "Downs" ) )
	self.header_downs:setTTF( "fonts/ltromatic.ttf" )
	self.header_downs:setRGB( 0.047, 0.776, 0.913 )
	self.header_downs:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_downs )

	-- Header Column: Revives
	self.header_revives = LUI.UIText.new()
    self.header_revives:setLeftRight(true, false, 1062, 1118)
    self.header_revives:setTopBottom(true, false, 409, 418)
	self.header_revives:setText( Engine.Localize( "Revives" ) )
	self.header_revives:setTTF( "fonts/ltromatic.ttf" )
	self.header_revives:setRGB( 0.047, 0.776, 0.913 )
	self.header_revives:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self:addElement( self.header_revives )

	-- ========================================
	-- PLAYER DATA ROWS
	-- ========================================

	-- Create player data rows dynamically
	self.playerRows = {}
	
	local playerYPositions = { 430, 462, 494, 527 } -- Y positions for players 1-4
	
	-- Function to update a player's stats
	local function UpdatePlayerStats( playerIndex, clientNum )
		if not self.playerRows[playerIndex] then
			return
		end
		
		local playerRow = self.playerRows[playerIndex]
		
		if clientNum and clientNum >= 0 then
			-- Update kills
			local kills = Engine.GetScoreboardColumnForClient( clientNum, 1 )
			if playerRow.kills_text then
				playerRow.kills_text:setText( Engine.Localize( kills ) )
			end
			
			-- Update headshots
			local headshots = Engine.GetScoreboardColumnForClient( clientNum, 4 )
			if playerRow.headshots_text then
				playerRow.headshots_text:setText( Engine.Localize( headshots ) )
			end
			
			-- Update downs
			local downs = Engine.GetScoreboardColumnForClient( clientNum, 2 )
			if playerRow.downs_text then
				playerRow.downs_text:setText( Engine.Localize( downs ) )
			end
			
			-- Update revives
			local revives = Engine.GetScoreboardColumnForClient( clientNum, 3 )
			if playerRow.revives_text then
				playerRow.revives_text:setText( Engine.Localize( revives ) )
			end
		end
	end
	
	for playerIndex = 0, 3 do
		local yPos = playerYPositions[playerIndex + 1]
		local playerNum = playerIndex + 1
		
		-- Create player row container
		local playerRow = LUI.UIElement.new()
		playerRow:setLeftRight( true, false, 124, 1158 )
		playerRow:setTopBottom( true, false, yPos, yPos + 32 )
		
		-- Set the model for this player row (required for linkToElementModel to work)
		playerRow:subscribeToGlobalModel( controller, "PlayerList", tostring(playerIndex), function ( model )
			playerRow:setModel( model, controller )
		end )
		
		-- Player ID number
		playerRow.id_text = LUI.UIText.new()
		playerRow.id_text:setLeftRight( true, false, 28, 41 )
		playerRow.id_text:setTopBottom( true, false, 10, 23 )
		playerRow.id_text:setText( Engine.Localize( playerNum ) )
		playerRow.id_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.id_text:setRGB( 0.941, 0.941, 0.941 )
		playerRow.id_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
		playerRow:addElement( playerRow.id_text )
		
		-- Prestige icon (placeholder - would need prestige system)
		playerRow.prestige_icon = LUI.UIImage.new()
		playerRow.prestige_icon:setLeftRight( true, false, 71, 95 )
		playerRow.prestige_icon:setTopBottom( true, false, 5, 28 )
		playerRow.prestige_icon:setImage( RegisterImage( "i_mtl_sat_ui_icon_rank_prestige_04" ) ) -- Placeholder
		playerRow.prestige_icon:setRGB( 1, 1, 1 )
		playerRow:addElement( playerRow.prestige_icon )
		playerRow.prestige_icon:setAlpha( 0 )   -- no leveling system on this map
		
		-- Level (placeholder - would need level system)
		playerRow.level_text = LUI.UIText.new()
		playerRow.level_text:setLeftRight( true, false, 76, 130 )
		playerRow.level_text:setTopBottom( true, false, 10, 23 )
		playerRow.level_text:setText( Engine.Localize( "1" ) )
		playerRow.level_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.level_text:setRGB( 0.941, 0.941, 0.941 )
		playerRow.level_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
		playerRow:addElement( playerRow.level_text )
		playerRow.level_text:setAlpha( 0 )   -- no leveling system on this map
		
		-- Player Name (dynamic from PlayerList model)
		playerRow.name_text = LUI.UIText.new()
		playerRow.name_text:setLeftRight( true, false, 212, 380 )
		playerRow.name_text:setTopBottom( true, false, 10, 23 )
		playerRow.name_text:setText( Engine.Localize( "Player " .. playerNum ) )
		playerRow.name_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.name_text:setRGB( 0.941, 0.941, 0.941 )
		playerRow.name_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
		-- Subscribe to player name
		playerRow.name_text:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "PlayerList." .. playerIndex .. ".playerName" ), function ( model )
			local name = Engine.GetModelValue( model )
			if name then
				playerRow.name_text:setText( Engine.Localize( name ) )
			end
		end )
		playerRow:addElement( playerRow.name_text )
		
		-- Total Points (dynamic from playerScore model)
		playerRow.points_text = LUI.UIText.new()
		playerRow.points_text:setLeftRight( true, false, 367, 503 )
		playerRow.points_text:setTopBottom( true, false, 10, 23 )
		playerRow.points_text:setText( Engine.Localize( "0" ) )
		playerRow.points_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.points_text:setRGB(0.996078431372549, 0.9921568627450981, 0.4980392156862745)
		playerRow.points_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
		-- Subscribe to player score
		playerRow.points_text:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "PlayerList." .. playerIndex .. ".playerScore" ), function ( model )
			local score = Engine.GetModelValue( model )
			if score then
				playerRow.points_text:setText( Engine.Localize( score ) )
			end
		end )
		playerRow:addElement( playerRow.points_text )
		
		-- Eliminations (dynamic via GetScoreboardColumnForClient)
		playerRow.kills_text = LUI.UIText.new()
		playerRow.kills_text:setLeftRight( true, false, 506, 627 )
		playerRow.kills_text:setTopBottom( true, false, 10, 23 )
		playerRow.kills_text:setText( Engine.Localize( "0" ) )
		playerRow.kills_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.kills_text:setRGB( 0.941, 0.941, 0.941 )
		playerRow.kills_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
		playerRow:addElement( playerRow.kills_text )
		
		-- Critical Kills / Headshots (dynamic via GetScoreboardColumnForClient)
		playerRow.headshots_text = LUI.UIText.new()
		playerRow.headshots_text:setLeftRight( true, false, 641, 762 )
		playerRow.headshots_text:setTopBottom( true, false, 10, 23 )
		playerRow.headshots_text:setText( Engine.Localize( "0" ) )
		playerRow.headshots_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.headshots_text:setRGB( 0.941, 0.941, 0.941 )
		playerRow.headshots_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
		playerRow:addElement( playerRow.headshots_text )
		
		-- Downs (dynamic via GetScoreboardColumnForClient)
		playerRow.downs_text = LUI.UIText.new()
		playerRow.downs_text:setLeftRight( true, false, 769, 890 )
		playerRow.downs_text:setTopBottom( true, false, 10, 23 )
		playerRow.downs_text:setText( Engine.Localize( "0" ) )
		playerRow.downs_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.downs_text:setRGB( 0.941, 0.941, 0.941 )
		playerRow.downs_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
		playerRow:addElement( playerRow.downs_text )
		
		-- Revives (dynamic via GetScoreboardColumnForClient)
		playerRow.revives_text = LUI.UIText.new()
		playerRow.revives_text:setLeftRight( true, false, 897, 1018 )
		playerRow.revives_text:setTopBottom( true, false, 10, 23 )
		playerRow.revives_text:setText( Engine.Localize( "0" ) )
		playerRow.revives_text:setTTF( "fonts/orbitron.ttf" )
		playerRow.revives_text:setRGB( 0.941, 0.941, 0.941 )
		playerRow.revives_text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
		playerRow:addElement( playerRow.revives_text )
		
		-- Store clientNum for this player and subscribe to updates
		playerRow.clientNum = nil
		playerRow:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "PlayerList." .. playerIndex .. ".clientNum" ), function ( model )
			local clientNum = Engine.GetModelValue( model )
			playerRow.clientNum = clientNum
			UpdatePlayerStats( playerIndex, clientNum )
		end )
		
		-- Add player row to scoreboard
		self:addElement( playerRow )
		self.playerRows[playerIndex] = playerRow
	end
	
	-- Subscribe to global scoreboard update model to refresh all stats
	self:subscribeToModel( Engine.CreateModel( Engine.GetModelForController( controller ), "updateScoreboard" ), function ( model )
		for i = 0, 3 do
			if self.playerRows[i] and self.playerRows[i].clientNum then
				UpdatePlayerStats( i, self.playerRows[i].clientNum )
			end
		end
	end )

	-- ========================================
	-- VISIBILITY SYSTEM (Hidden by default, shown on TAB)
	-- ========================================
	
	-- Helper function to check if player exists
	local function IsPlayerActive( playerIndex )
		local playerModel = Engine.GetModel( Engine.GetModelForController( controller ), "PlayerList." .. playerIndex )
		if playerModel then
			local nameModel = Engine.GetModel( playerModel, "playerName" )
			if nameModel then
				local name = Engine.GetModelValue( nameModel )
				return name ~= nil and name ~= ""
			end
		end
		return false
	end
	
	self.clipsPerState = {
		DefaultState = {
			DefaultClip = function ()
				self:setupElementClipCounter( 0 )
				
				-- Hide all scoreboard elements
				self.bg_overlay_1:setAlpha( 0 )
				self.bg_particles:setAlpha( 0 )
				self.bg_overlay_2:setAlpha( 0 )
				if self.questWidget then
					self.questWidget:setAlpha(0)
				end
				
				self.player_4_outline:setAlpha( 0 )
				self.player_4_outline_bg:setAlpha( 0 )
				self.player_3_outline:setAlpha( 0 )
				self.player_3_outline_bg:setAlpha( 0 )
				self.player_2_outline:setAlpha( 0 )
				self.player_2_outline_bg:setAlpha( 0 )
				self.player_1_outline:setAlpha( 0 )
				self.player_1_outline_bg:setAlpha( 0 )
				self.player_hover_element:setAlpha( 0 )
				self.points_icon:setAlpha( 0 )
				self.points_label:setAlpha( 0 )
				self.points_value:setAlpha( 0 )
				self.salvage_icon:setAlpha( 0 )
				self.salvage_label:setAlpha( 0 )
				self.salvage_value:setAlpha( 0 )
				self.map_info_bg:setAlpha( 0 )
				self.game_mode_text:setAlpha( 0 )
				self.map_name_text:setAlpha( 0 )
				self.round_label:setAlpha( 0 )
				self.round_number:setAlpha( 0 )
				self.scoreboard_header:setAlpha( 0 )
				self.header_id:setAlpha( 0 )
				self.header_level:setAlpha( 0 )
				self.header_name:setAlpha( 0 )
				self.header_points:setAlpha( 0 )
				self.header_kills:setAlpha( 0 )
				self.header_headshots:setAlpha( 0 )
				self.header_downs:setAlpha( 0 )
				self.header_revives:setAlpha( 0 )
				
				-- Hide all player rows
				for i = 0, 3 do
					if self.playerRows[i] then
						self.playerRows[i]:setAlpha( 0 )
					end
				end
			end
		},
		Visible = {
			DefaultClip = function ()
				self:setupElementClipCounter( 0 )
				
				-- Show all scoreboard elements
				self.bg_overlay_1:setAlpha( 1 )
				self.bg_particles:setAlpha( 1 )
				self.bg_overlay_2:setAlpha( 1 )
				if self.questWidget then
					self.questWidget:setAlpha(0)   -- no quest system on this map
				end
				
				-- Count active players
				local activePlayers = {}
				for i = 0, 3 do
					if IsPlayerActive( i ) then
						table.insert( activePlayers, i )
					end
				end
				local playerCount = #activePlayers
				
				-- Position players from bottom (fill slots 4, 3, 2, 1 based on count)
				local playerYPositions = { 430, 462, 494, 527 } -- Slots 1, 2, 3, 4
				local outlineElements = { self.player_1_outline, self.player_2_outline, self.player_3_outline, self.player_4_outline }
				local outlineBgElements = { self.player_1_outline_bg, self.player_2_outline_bg, self.player_3_outline_bg, self.player_4_outline_bg }
				
				-- Hide all outlines first
				for i = 1, 4 do
					outlineElements[i]:setAlpha( 0 )
					outlineBgElements[i]:setAlpha( 0 )
				end
				
				-- Show outlines for active slots (filling from bottom)
				for i = 1, playerCount do
					local slotIndex = 5 - i -- Start from slot 4 and go up (4, 3, 2, 1)
					outlineElements[slotIndex]:setAlpha( 1 )
					outlineBgElements[slotIndex]:setAlpha( 1 )
				end
				
				-- Position player rows to fill from bottom
				for i = 1, playerCount do
					local playerIndex = activePlayers[i]
					local slotIndex = 5 - i -- Slot position (4, 3, 2, 1)
					local yPos = playerYPositions[slotIndex]
					
					if self.playerRows[playerIndex] then
						self.playerRows[playerIndex]:setTopBottom( true, false, yPos, yPos + 32 )
						self.playerRows[playerIndex]:setAlpha( 1 )
					end
				end
				
				-- Hide inactive player rows
				for i = 0, 3 do
					local isActive = false
					for _, activeIdx in ipairs( activePlayers ) do
						if activeIdx == i then
							isActive = true
							break
						end
					end
					if not isActive and self.playerRows[i] then
						self.playerRows[i]:setAlpha( 0 )
					end
				end
				
				-- Position hover element on bottom-most active player
				if playerCount > 0 then
					local bottomSlot = 5 - 1 -- Slot 4
					local yPos = playerYPositions[bottomSlot]
					self.player_hover_element:setTopBottom( true, false, yPos, yPos + 32 )
					self.player_hover_element:setAlpha( 1 )
				else
					self.player_hover_element:setAlpha( 0 )
				end
				
				-- Position header directly above topmost active player
				if playerCount > 0 then
					local topSlot = 5 - playerCount -- Top-most slot being used
					local topPlayerY = playerYPositions[topSlot]
					local headerHeight = 33 -- Header is 33 pixels tall (430 - 397)
					local headerTop = topPlayerY - headerHeight
					local headerBottom = topPlayerY
					
					-- Reposition header
					if self.scoreboard_header then
						self.scoreboard_header:setTopBottom( true, false, headerTop, headerBottom )
					end
					
					-- Reposition all header text elements (they're offset from header position)
					local headerTextOffset = 10 -- Text starts 10px from header top
					local textY = headerTop + headerTextOffset
					
					if self.header_id then
						self.header_id:setTopBottom( true, false, textY, textY + 13 )
					end
					if self.header_level then
						self.header_level:setTopBottom( true, false, textY + 2, textY + 13 )
					end
					if self.header_name then
						self.header_name:setTopBottom( true, false, textY + 2, textY + 13 )
					end
					if self.header_points then
						self.header_points:setTopBottom( true, false, textY + 2, textY + 11 )
					end
					if self.header_kills then
						self.header_kills:setTopBottom( true, false, textY + 2, textY + 11 )
					end
					if self.header_headshots then
						self.header_headshots:setTopBottom( true, false, textY + 2, textY + 12 )
					end
					if self.header_downs then
						self.header_downs:setTopBottom( true, false, textY + 2, textY + 11 )
					end
					if self.header_revives then
						self.header_revives:setTopBottom( true, false, textY + 2, textY + 11 )
					end
				end
				
				self.points_icon:setAlpha( 1 )
				self.points_label:setAlpha( 1 )
				self.points_value:setAlpha( 1 )
				-- salvage disabled: no salvage economy on this map (audit 2026-08-19)
				self.salvage_icon:setAlpha( 0 )
				self.salvage_label:setAlpha( 0 )
				self.salvage_value:setAlpha( 0 )
				self.map_info_bg:setAlpha( 1 )
				self.game_mode_text:setAlpha( 1 )
				self.map_name_text:setAlpha( 1 )
				self.round_label:setAlpha( 1 )
				self.round_number:setAlpha( 1 )
				self.scoreboard_header:setAlpha( 1 )
				self.header_id:setAlpha( 1 )
				self.header_level:setAlpha( 0 )   -- no leveling system on this map
				self.header_name:setAlpha( 1 )
				self.header_points:setAlpha( 1 )
				self.header_kills:setAlpha( 1 )
				self.header_headshots:setAlpha( 1 )
				self.header_downs:setAlpha( 1 )
				self.header_revives:setAlpha( 1 )
			end
		}
	}
	
	-- State conditions: Check if scoreboard should be visible
	self:mergeStateConditions( {
		{
			stateName = "Visible",
			condition = function ( menu, element, event )
				return Engine.IsVisibilityBitSet( controller, Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN )
			end
		}
	} )
	
	-- Subscribe to scoreboard open/close model
	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN ), function ( model )
		menu:updateElementState( self, {
			name = "model_validation",
			menu = menu,
			modelValue = Engine.GetModelValue( model ),
			modelName = "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN
		} )
	end )

	if PostLoadFunc then
		PostLoadFunc( self, controller )
	end

	return self
end

return CoD.AetheriumScoreboard
