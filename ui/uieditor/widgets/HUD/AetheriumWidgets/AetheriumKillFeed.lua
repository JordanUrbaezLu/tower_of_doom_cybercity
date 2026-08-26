-- Kill Feed Widget
-- Shows recent kills with scrolling animation

require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumKillFeedText" )

local SetKillTypeColor = function ( element, killName )
	-- AAT Kill Colors (all use yellow like critical kills)
	if killName:find( "Electric Kill" ) then
		element:setRGB( 0.92, 0.94, 0.17 ) -- Yellow
	elseif killName:find( "Blast Furnace" ) then
		element:setRGB( 0.92, 0.94, 0.17 ) -- Yellow
	elseif killName:find( "Fireworks" ) then
		element:setRGB( 0.92, 0.94, 0.17 ) -- Yellow
	elseif killName:find( "Thunderwall" ) then
		element:setRGB( 0.92, 0.94, 0.17 ) -- Yellow
	elseif killName:find( "Turned" ) then
		element:setRGB( 0.92, 0.94, 0.17 ) -- Yellow
	-- Critical Kill Colors
	elseif killName:find( "Critical" ) then
		element:setRGB( 0.92, 0.94, 0.17 ) -- Yellow for crits
	else
		element:setRGB( 1, 1, 1 ) -- White for normal/melee/burned/elimination
	end
end

local PostLoadFunc = function ( self, controller, menu )
	-- Subscribe to score_event notifications from GSC
	self:subscribeToGlobalModel( controller, "PerController", "scriptNotify", function ( model )
		local event = Engine.GetModelValue( model )

		if event == "score_event" then
			local scriptNotifyData = CoD.GetScriptNotifyData( model )
			local name = Engine.Localize( Engine.GetIString( scriptNotifyData[1], "CS_LOCALIZED_STRINGS" ) )
			local score = scriptNotifyData[2]

			if name ~= nil and score ~= nil and type( score ) == "number" then
				-- Update running total
				local totalText = self.total:getText()
				if totalText == nil or totalText == "" then
					totalText = "0"
				end
				local total = tonumber( totalText ) or 0
				total = total + score
				self.total:setText( tostring( total ) )

				-- Shift down existing kill entries (5 slots)
				for index = 5, 2, -1 do
					local prevName = self["text" .. index - 1].name:getText() or ""
					local prevScore = self["text" .. index - 1].score:getText() or ""
					self["text" .. index].name:setText( tostring( prevName ) )
					self["text" .. index].score:setText( tostring( prevScore ) )
					SetKillTypeColor( self["text" .. index].name, tostring( prevName ) )
				end

				-- Set new kill at top position
				self.text1.name:setText( tostring( name ) )
				self.text1.score:setText( "+" .. tostring( score ) )
				SetKillTypeColor( self.text1.name, tostring( name ) )

				-- Count how many kills are currently displayed
				local killCount = 0
				for index = 1, 5 do
					if self["text" .. index].name:getText() ~= "" then
						killCount = killCount + 1
					end
				end

				-- Only show total if there are 2+ kills
				if killCount >= 2 then
					self.total:setAlpha( 1 )
				else
					self.total:setAlpha( 0 )
				end

				-- Play fade animation
				PlayClip( self, "FadeAnim", controller )

				-- Reset after animation completes
				self:registerEventHandler( "clip_over", function ( element, event )
					self.total:setText( "" )
					self.total:setAlpha( 0 )
					
					for index = 1, 5 do
						self["text" .. index].score:setText( "" )
						self["text" .. index].name:setText( "" )
					end
				end )
			end
		end
	end )
end

CoD.AetheriumKillFeed = InheritFrom( LUI.UIElement )
CoD.AetheriumKillFeed.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumKillFeed )
	self.id = "AetheriumKillFeed"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self.anyChildUsesUpdateState = true

	-- Running total (top position, yellowish color)
	self.total = LUI.UIText.new()
	self.total:setLeftRight( true, false, 721, 781 )
	self.total:setTopBottom( true, false, 317, 328 )
	self.total:setTTF( "fonts/orbitron.ttf" )
	self.total:setRGB( 0.933, 0.906, 0.522 ) -- Yellowish
	self.total:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self.total:setAlpha( 0 ) -- Start hidden
	self:addElement( self.total )

	-- Kill feed entries (5 slots, stacked vertically)
	self.text1 = CoD.AetheriumKillFeedText.new( menu, controller )
	self.text1:setLeftRight( true, false, 721, 857 )
	self.text1:setTopBottom( true, false, 335, 346 )
	self:addElement( self.text1 )

	self.text2 = CoD.AetheriumKillFeedText.new( menu, controller )
	self.text2:setLeftRight( true, false, 721, 857 )
	self.text2:setTopBottom( true, false, 350, 361 )
	self:addElement( self.text2 )
	
	self.text3 = CoD.AetheriumKillFeedText.new( menu, controller )
	self.text3:setLeftRight( true, false, 721, 857 )
	self.text3:setTopBottom( true, false, 365, 376 )
	self:addElement( self.text3 )
	
	self.text4 = CoD.AetheriumKillFeedText.new( menu, controller )
	self.text4:setLeftRight( true, false, 721, 857 )
	self.text4:setTopBottom( true, false, 380, 391 )
	self:addElement( self.text4 )
	
	self.text5 = CoD.AetheriumKillFeedText.new( menu, controller )
	self.text5:setLeftRight( true, false, 721, 857 )
	self.text5:setTopBottom( true, false, 395, 406 )
	self:addElement( self.text5 )

	-- Animation clips
	self.clipsPerState = {
		DefaultState = {
			DefaultClip = function ()
				self:setupElementClipCounter( 0 )
			end,
			FadeAnim = function ()
				-- Count visible kills to determine if we should animate the total
				local killCount = 0
				for index = 1, 5 do
					if self["text" .. index].name:getText() ~= "" then
						killCount = killCount + 1
					end
				end
				
				-- Only animate total if 2+ kills
				local animateTotal = (killCount >= 2)
				
				if animateTotal then
					self:setupElementClipCounter( 6 )
				else
					self:setupElementClipCounter( 5 )
				end

				-- Fade animation: visible for 1.5s, then fade out over 0.5s
				local FadeFrame2 = function ( element, event )
					if not event.interrupted then
						element:beginAnimation( "keyframe", 500, false, false, CoD.TweenType.Linear )
					end
	
					element:setAlpha( 0 )
	
					if event.interrupted then
						self.clipFinished( element, event )
					else
						element:registerEventHandler( "transition_complete_keyframe", self.clipFinished )
					end
				end

				local FadeFrame1 = function ( element, event )
					if event.interrupted then
						FadeFrame2( element, event )
						return 
					else
						element:beginAnimation( "keyframe", 1500, false, false, CoD.TweenType.Linear )
						element:setAlpha( 1 )
						element:registerEventHandler( "transition_complete_keyframe", FadeFrame2 )
					end
				end

				-- Animate total only if visible
				if animateTotal then
					self.total:completeAnimation()
					self.total:setAlpha( 1 )
					FadeFrame1( self.total, {} )
				end

				self.text1:completeAnimation()
				self.text1:setAlpha( 1 )
				FadeFrame1( self.text1, {} )
				
				self.text2:completeAnimation()
				self.text2:setAlpha( 1 )
				FadeFrame1( self.text2, {} )
				
				self.text3:completeAnimation()
				self.text3:setAlpha( 1 )
				FadeFrame1( self.text3, {} )
				
				self.text4:completeAnimation()
				self.text4:setAlpha( 1 )
				FadeFrame1( self.text4, {} )
				
				self.text5:completeAnimation()
				self.text5:setAlpha( 1 )
				FadeFrame1( self.text5, {} )
			end
		}
	}

	LUI.OverrideFunction_CallOriginalSecond( self, "close", function ( element )
		element.total:close()
		element.text1:close()
		element.text2:close()
		element.text3:close()
		element.text4:close()
		element.text5:close()
	end )
	
	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end
	
	return self
end

return CoD.AetheriumKillFeed
