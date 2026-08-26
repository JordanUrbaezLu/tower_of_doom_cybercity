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
