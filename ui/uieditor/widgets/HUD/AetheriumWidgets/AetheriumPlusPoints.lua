-- Aetherium Plus Points Widget (Individual popup text)
-- Based on ZMScr_PlusPoints

CoD.AetheriumPlusPoints = InheritFrom( LUI.UIElement )
CoD.AetheriumPlusPoints.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumPlusPoints )
	self.id = "AetheriumPlusPoints"
	self.soundSet = "HUD"
	self:setLeftRight( true, false, 0, 80 )
	self:setTopBottom( true, false, 0, 20 )

	-- Main text label
	self.Label = LUI.UIText.new()
	self.Label:setLeftRight( true, false, 0, 80 )
	self.Label:setTopBottom( true, false, 0, 20 )
	self.Label:setText( Engine.Localize( "+50" ) )
	self.Label:setTTF( "fonts/ltromatic.ttf" )
	self.Label:setRGB( 0.9725, 0.9607, 0.4706 )  -- Yellow for positive
	self.Label:setScale( 0.42 )
	self.Label:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
	self.Label:setAlpha( 1 )
	self:addElement( self.Label )

	-- Clip animations (fade in + move up + fade out)
	self.clipsPerState = {
		DefaultState = {
			DefaultClip = function ()
				self:setupElementClipCounter( 0 )
			end,
			FadeOut = function ()
				self:setupElementClipCounter( 1 )

				local FadeOutFrame = function ( element, event )
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

				self.Label:completeAnimation()
				self.Label:setAlpha( 1 )
				FadeOutFrame( self.Label, {} )
			end
		}
	}

	LUI.OverrideFunction_CallOriginalSecond( self, "close", function ( element )
		element.Label:close()
	end )

	return self
end
