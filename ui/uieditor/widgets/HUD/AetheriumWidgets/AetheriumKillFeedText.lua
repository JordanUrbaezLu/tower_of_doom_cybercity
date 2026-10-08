-- Individual kill feed entry widget
-- Displays kill type name and points earned
--
-- v17.34 (user 2026-09-04): both halves are the map's baked typeface now, not
-- orbitron. CoD.TodGlyphText keeps the UIText surface -- setText / getText /
-- setRGB -- which matters here more than anywhere else in the pass, because
-- AetheriumKillFeed drives this widget ENTIRELY through getText/setText: it
-- shifts entries down the list by reading each row's text back out, and it
-- picks a row's colour by pattern-matching that string. getText returns the RAW
-- string that was set, so every one of those reads is untouched.
--
-- THE SCORE IS RIGHT-ALIGNED (it was left): a right-aligned column of "+50" /
-- "+120" / "+1000" keeps the gap to the name constant instead of letting a
-- longer number close it. See the box note on the element itself.

require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodGlyphText" )

CoD.AetheriumKillFeedText = InheritFrom( LUI.UIElement )
CoD.AetheriumKillFeedText.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumKillFeedText )
	self.id = "AetheriumKillFeedText"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 136 )
	self:setTopBottom( true, false, 0, 11 )
	self.anyChildUsesUpdateState = true

	-- Points scored (left column, right-aligned against the name)
	--
	-- 36 WIDE, not the 32 the UIText had, and the name starts at 40 rather than
	-- overlapping it at 29. A glyph row SHRINKS to fit its box instead of
	-- spilling out of it, so a five-character "+1000" in a 26px column would
	-- have drawn two thirds the size of a "+50" beside it. Total width is
	-- unchanged: the name simply starts 11px later.
	self.score = CoD.TodGlyphText.new( {
		left = 0, right = 36, top = 0, bottom = 11,
		align = "right", set = "digits", pool = 7,
		rgb = { 1, 1, 1 }, -- White
	} )
	self:addElement( self.score )

	-- Kill type name (right side, wide enough for long names like "Blast Furnace Kill")
	self.name = CoD.TodGlyphText.new( {
		left = 40, right = 200, top = 0, bottom = 11,
		align = "left", set = "name", pool = 22,
		rgb = { 1, 1, 1 }, -- White
	} )
	self:addElement( self.name )

	LUI.OverrideFunction_CallOriginalSecond( self, "close", function ( element )
		element.score:close()
		element.name:close()
	end )
	
	return self
end

return CoD.AetheriumKillFeedText
