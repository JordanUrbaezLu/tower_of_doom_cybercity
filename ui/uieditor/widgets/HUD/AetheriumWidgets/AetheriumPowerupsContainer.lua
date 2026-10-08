require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodUIOwnership" )
-- Aetherium Powerups Container Widget
-- Dynamically displays active powerups with timers

require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPowerupItem" )

-- Powerup Table (BO6 Overhaul Pattern)
CoD.PowerUps.ClientFieldNames = {
	{
		clientFieldName = "powerup_instant_kill",
		name = "Insta Kill",
		image = "i_tod_pu2_insta"
	},
	{
		clientFieldName = "powerup_double_points",
		name = "Double Points",
		image = "i_tod_pu2_double_points"
	},
	{
		clientFieldName = "powerup_fire_sale",
		name = "Fire Sale",
		image = "i_tod_pu2_fire_sale"
	},
	{
		clientFieldName = "powerup_mini_gun",
		name = "Gift of Death",
		image = "i_tod_pu2_gift_of_death"
	},
	{
		clientFieldName = "powerup_full_ammo",
		name = "Max Ammo",
		image = "i_tod_pu2_max_ammo"
	},
	{
		clientFieldName = "powerup_carpenter",
		name = "Carpenter",
		image = "i_tod_pu2_carpenter"
	},
	{
		clientFieldName = "powerup_nuke",
		name = "Nuke",
		image = "i_tod_pu2_nuke"
	},
	-- [tod] Logical's Powerups (vendored 2026-08-20) — clientFieldName matches
	-- the pack's gsh CLIENTFIELD defines; icons = Robit's CW/BO4 shaders
	-- wrapped as tod images (source_data/tod_ui_images.gdt).
	{
		clientFieldName = "timewarp",
		name = "Time Warp",
		image = "i_tod_pu2_timewarp"
	},
	{
		clientFieldName = "infiniteammo",
		name = "Infinite Ammo",
		image = "i_tod_pu2_infinite_ammo"
	},
	-- Free PaP is INSTANT (no timed clientfield) — this entry never renders in
	-- the timed tray; it's the icon the grab notifier would draw once a
	-- localized hint is wired (deferred). Harmless as-is.
	{
		clientFieldName = "tod_free_pap",
		name = "Free PaP",
		image = "i_tod_pu2_free_pap"
	},
	-- Zombie Blood — a REAL timed-tray row since 2026-08-26 ("zombie blood
	-- doesn't show in the bar"): the gsc/csc add_zombie_powerup pair now
	-- carries the "tod_zombie_blood" clientfield + per-player on/time vars,
	-- so the 15s window renders and flash-expires here like any stock timer.
	{
		clientFieldName = "tod_zombie_blood",
		name = "Zombie Blood",
		image = "i_tod_pu2_zombie_blood"
	}
}

CoD.PowerUps.Update = function ( self, event )
	local powerupStateModel = Engine.GetModel( Engine.GetModelForController( event.controller ), event.name .. ".state" )

	if powerupStateModel ~= nil then
		Engine.SetModelValue( powerupStateModel, event.newValue )
	end
end

local PreLoadFunc = function ( self, controller )
	for index = 1, #CoD.PowerUps.ClientFieldNames do
		Engine.CreateModel( Engine.GetModelForController( controller ), CoD.PowerUps.ClientFieldNames[index].clientFieldName .. ".state" )
		Engine.CreateModel( Engine.GetModelForController( controller ), CoD.PowerUps.ClientFieldNames[index].clientFieldName .. ".time" )
	end
end

local PostLoadFunc = function ( self, controller, menu )
	for index = 1, #CoD.PowerUps.ClientFieldNames do
		local powerupStateModel = Engine.GetModel( Engine.GetModelForController( controller ), CoD.PowerUps.ClientFieldNames[index].clientFieldName .. ".state" )
		local powerupTimeModel = Engine.GetModel( Engine.GetModelForController( controller ), CoD.PowerUps.ClientFieldNames[index].clientFieldName .. ".time" )
		
		if powerupStateModel ~= nil then
			self.PowerupList:subscribeToModel( powerupStateModel, function ( model )
				self.PowerupList:updateDataSource()
			end )
		end

		if powerupTimeModel ~= nil then
			self.PowerupList:subscribeToModel( powerupTimeModel, function ( model )
				self.PowerupList:updateDataSource()
			end )
		end
	end
end

DataSources.AetheriumPowerups = DataSourceHelpers.ListSetup( "AetheriumPowerups", function ( controller, element )	
	local powerups = {}

	local powerupState = nil
	local powerupTime = nil

	for index = 1, #CoD.PowerUps.ClientFieldNames do
		powerupState = Engine.GetModelValue( Engine.GetModel( Engine.GetModelForController( controller ), CoD.PowerUps.ClientFieldNames[index].clientFieldName .. ".state" ) )
		powerupTime = Engine.GetModelValue( Engine.GetModel( Engine.GetModelForController( controller ), CoD.PowerUps.ClientFieldNames[index].clientFieldName .. ".time" ) )

		if powerupState then
			if powerupState > 0 then
				table.insert( powerups, {
					models = {
						image = CoD.PowerUps.ClientFieldNames[index].image,
						state = powerupState,
						time = powerupTime
					}
				} )
			end
		end
	end

	return powerups
end, true )

-- Main widget
CoD.AetheriumPowerupsContainer = InheritFrom( LUI.UIElement )
CoD.AetheriumPowerupsContainer.new = function ( menu, controller )
	local self = LUI.UIElement.new()
    CoD.TodUIOwnership.Attach( self )

	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumPowerupsContainer )
	self.id = "AetheriumPowerupsContainer"
	self.soundSet = "HUD"
	self:setLeftRight( true, true, 0, 0 )
	self:setTopBottom( true, true, 0, 0 )
	self.anyChildUsesUpdateState = true

	-- Powerup list (horizontal layout, centered at position)
	self.PowerupList = LUI.UIList.new( menu, controller, 17, 0, nil, false, false, 0, 0, false, false )
	self.PowerupList:makeFocusable()
	self.PowerupList:setLeftRight( false, false, -132, 132 )  -- Centered (4 * 49px + 3 * 17px spacing = 264px total width)
	self.PowerupList:setTopBottom( true, false, 597, 646 )    -- Position at 597-646 (49px tall)
	self.PowerupList:setWidgetType( CoD.AetheriumPowerupItem )
	self.PowerupList:setHorizontalCount( 4 )  -- Max 4 powerups displayed horizontally
	self.PowerupList:setSpacing( 17 )  -- 17px spacing between powerups
	self.PowerupList:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	self.PowerupList:setDataSource( "AetheriumPowerups" )
	self:addElement( self.PowerupList )

	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end


	-- =========================================================================
	return self
end
