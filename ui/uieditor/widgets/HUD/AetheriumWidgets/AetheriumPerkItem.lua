-- Aetherium Perk Item Widget (Individual Perk Icon)

CoD.AetheriumPerkItem = InheritFrom( LUI.UIElement )
CoD.AetheriumPerkItem.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumPerkItem )
	self.id = "AetheriumPerkItem"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 28 )
	self:setTopBottom( true, false, 0, 28 )

	-- Perk Icon
	self.PerkIcon = LUI.UIImage.new()
	self.PerkIcon:setLeftRight( true, false, 0, 28 )
	self.PerkIcon:setTopBottom( true, false, 0, 28 )
	self.PerkIcon:linkToElementModel( self, "image", true, function ( model )
		local image = Engine.GetModelValue( model )
		if image then
			self.PerkIcon:setImage( RegisterImage( image ) )
		end
	end )
	self:addElement( self.PerkIcon )

	-- Animate new perks sliding in
	self:linkToElementModel( self, "newPerk", true, function ( model )
		local isNewPerk = Engine.GetModelValue( model )
		if isNewPerk then
			-- Slide in animation for new perk
			self.PerkIcon:completeAnimation()
			self.PerkIcon:setAlpha( 0 )
			self.PerkIcon:setScale( 0.5 )
			self.PerkIcon:beginAnimation( "newperk_slidein", 250, false, false, CoD.TweenType.Linear )
			self.PerkIcon:setAlpha( 1 )
			self.PerkIcon:setScale( 1 )
		end
	end )

	return self
end
