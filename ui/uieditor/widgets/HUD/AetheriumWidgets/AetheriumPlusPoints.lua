-- Aetherium Plus Points Widget (Individual popup text)
-- Based on ZMScr_PlusPoints
--
-- v17.34 (user 2026-09-04): the floating "+50" / "-150" is the baked typeface
-- now. Constructor swap only -- AetheriumPlayerInfo still drives it through
-- Label:setText / Label:setRGB, the FadeOut clip below still animates
-- Label's alpha (LUI multiplies it onto the glyph images), and the close
-- override still closes Label, which now takes its glyph pool with it.
--
-- THE CAP IS EXPLICIT, not derived from this 20px-tall box. The box is the
-- ANIMATION's travel frame, not a type slot -- the container slides it 40px up
-- and the popup should read at the same size as the points readout it flies out
-- of (that one is a 13px box at the default 0.80 fraction, so 10.4).

require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodGlyphText" )

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
	self.Label = CoD.TodGlyphText.new( {
		left = 0, right = 80, top = 0, bottom = 20,
		align = "left", set = "digits", pool = 7, cap = 10.4,
		baseFrac = 0.70,   -- the string sits in the TOP of the travel frame
		rgb = { 0.9725, 0.9607, 0.4706 },  -- Yellow for positive
		text = "+50",
	} )
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
