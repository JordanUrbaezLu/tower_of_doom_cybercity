-- Aetherium Plus Points Container (Animates popup movement)
-- Based on ZMScr_PlusPointsContainer

require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPlusPoints" )

CoD.AetheriumPlusPointsContainer = InheritFrom( LUI.UIElement )
CoD.AetheriumPlusPointsContainer.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumPlusPointsContainer )
	self.id = "AetheriumPlusPointsContainer"
	self.soundSet = "HUD"
	self:setLeftRight( true, false, 0, 80 )
	self:setTopBottom( true, false, 0, 20 )

	self.AetheriumPlusPoints = CoD.AetheriumPlusPoints.new( menu, controller )
	self.AetheriumPlusPoints:setLeftRight( true, false, 0, 80 )
	self.AetheriumPlusPoints:setTopBottom( true, false, 0, 20 )
	self:addElement( self.AetheriumPlusPoints )

	-- Clip animations (moves up and fades out)
	self.clipsPerState = {
		DefaultState = {
			DefaultClip = function ()
				self:setupElementClipCounter( 0 )
			end,
			Anim1 = function ()
				self:setupElementClipCounter( 1 )

				local AnimFrame = function ( element, event )
					if not event.interrupted then
						element:beginAnimation( "keyframe", 1000, false, false, CoD.TweenType.Linear )
					end
					element:setLeftRight( true, false, 0, 80 )
					element:setTopBottom( true, false, -40, -20 )  -- Move up 40px
					element:setAlpha( 0 )
					if event.interrupted then
						self.clipFinished( element, event )
					else
						element:registerEventHandler( "transition_complete_keyframe", self.clipFinished )
					end
				end

				self.AetheriumPlusPoints:completeAnimation()
				self.AetheriumPlusPoints:setAlpha( 1 )
				self.AetheriumPlusPoints:setLeftRight( true, false, 0, 80 )
				self.AetheriumPlusPoints:setTopBottom( true, false, 0, 20 )
				AnimFrame( self.AetheriumPlusPoints, {} )
			end
		}
	}

	LUI.OverrideFunction_CallOriginalSecond( self, "close", function ( element )
		element.AetheriumPlusPoints:close()
	end )

	return self
end

-- A hit/kill burst must not allocate an unbounded number of ten-element
-- glyph popups. Keep the newest eight; also bound interrupted animations
-- whose clip_over never arrives. Score calculation stays with the caller.
CoD.AetheriumPlusPointsContainer.Show = function ( owner, menu, controller, points )
	if not owner.todPointPopups then
		owner.todPointPopups = {}
		LUI.OverrideFunction_CallOriginalSecond( owner, "close", function ( element )
			while #element.todPointPopups > 0 do
				element.todPointPopups[ 1 ]:close()
			end
		end )
	end
	local popups = owner.todPointPopups
	if #popups >= 8 then
		popups[ 1 ]:close()
	end
	local popup = CoD.AetheriumPlusPointsContainer.new( menu, controller )
	popups[ #popups + 1 ] = popup
	LUI.OverrideFunction_CallOriginalSecond( popup, "close", function ( element )
		for i = 1, #popups do
			if popups[ i ] == element then
				table.remove( popups, i )
				break
			end
		end
	end )
	local label = popup.AetheriumPlusPoints.Label
	if points > 0 then
		label:setText( "+" .. points )
		label:setRGB( 0.9725, 0.9607, 0.4706 )
	else
		label:setText( points )
		label:setRGB( 1, 0.3, 0.3 )
	end
	popup:setLeftRight( owner.pointsDeltaContainer:getLocalLeftRight() )
	popup:setTopBottom( owner.pointsDeltaContainer:getLocalTopBottom() )
	popup:registerEventHandler( "clip_over", function ( element ) element:close() end )
	owner:addElement( popup )
	popup:playClip( "Anim1" )
	popup.AetheriumPlusPoints:playClip( "FadeOut" )
end
