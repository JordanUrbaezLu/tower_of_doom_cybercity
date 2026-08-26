-- Aetherium Perks Container Widget
-- Dynamically displays perks as player acquires them

require( "ui.uieditor.widgets.HUD.Mappings.AetheriumPerks" )  -- For CoD.AetheriumPerks table
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPerkItem" )

-- Get perk index in the list
local GetPerkIndex = function ( perksList, perkCF )
	if perksList ~= nil then
		for index = 1, #perksList do
			if perksList[index].properties.key == perkCF then
				return index
			end
		end
	end
	return nil
end

-- Check if perk needs status update
local CheckPerkIndexForUpdate = function ( perksList, perkCF, perkStatus )
	if perksList ~= nil then
		for index = 1, #perksList do
			if perksList[index].properties.key == perkCF and perksList[index].models.status ~= perkStatus then
				return index
			end
		end
	end
	return -1
end

-- Handle perks list updates
local HandlePerksList = function ( element, controller )
	if not element.perksList then
		element.perksList = {}
	end

	local tableUpdated = false
	local perksParentModel = Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.perks" )

	-- Loop through each perk in CoD.AetheriumPerks
	for index = 1, #CoD.AetheriumPerks do
		local perkStatus = Engine.GetModelValue( Engine.GetModel( perksParentModel, CoD.AetheriumPerks[index].clientFieldName ) )

		if perkStatus ~= nil and perkStatus > 0 then
			-- Perk is active - add if not in list
			if not GetPerkIndex( element.perksList, CoD.AetheriumPerks[index].clientFieldName ) then
				table.insert( element.perksList, {
					models = {
						image = CoD.AetheriumPerks[index].image,
						status = perkStatus,
						newPerk = false
					},
					properties = {
						key = CoD.AetheriumPerks[index].clientFieldName
					}
				} )
				tableUpdated = true
			end

			-- Check for status update
			local perkIndexToCheck = CheckPerkIndexForUpdate( element.perksList, CoD.AetheriumPerks[index].clientFieldName, perkStatus )
			if perkIndexToCheck > 0 then
				element.perksList[perkIndexToCheck].models.status = perkStatus
			end

		else
			-- Perk is not active - remove if in list
			local perkIndexToCheck = GetPerkIndex( element.perksList, CoD.AetheriumPerks[index].clientFieldName )
			if perkIndexToCheck then
				table.remove( element.perksList, perkIndexToCheck )
				tableUpdated = true
			end
		end
	end

	if tableUpdated then
		-- Set newPerk flag for the last perk in the list (newest one)
		for index = 1, #element.perksList do
			element.perksList[index].models.newPerk = index == #element.perksList
		end
	end

	return tableUpdated
end

-- DataSource for perks list
DataSources.AetheriumPerks = DataSourceHelpers.ListSetup( "AetheriumPerks", function ( controller, element )
	-- This function handles element.perksList
	HandlePerksList( element, controller )
	-- After it's been handled, let's pass it to the datasource so that it updates the UIList
	return element.perksList
end, true )

local PreLoadFunc = function ( self, controller )
	-- Create the parent model, that each of the perks' sub-models will be stored on
	local perksParentModel = Engine.CreateModel( Engine.GetModelForController( controller ), "hudItems.perks" )

	-- Creates and subscribes to each of the sub-models of the perks
	for index = 1, #CoD.AetheriumPerks do
		self:subscribeToModel( Engine.CreateModel( perksParentModel, CoD.AetheriumPerks[index].clientFieldName ), function ( model )
			-- If HandlePerksList returns true, let's update the datasource
			if HandlePerksList( self.PerkList, controller ) then
				self.PerkList:updateDataSource()
			end
		end, false )
	end
end

-- Main widget
CoD.AetheriumPerksContainer = InheritFrom( LUI.UIElement )
CoD.AetheriumPerksContainer.new = function ( menu, controller )
	local self = LUI.UIElement.new()

	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumPerksContainer )
	self.id = "AetheriumPerksContainer"
	self.soundSet = "default"
	self:setLeftRight( true, true, 0, 0 )
	self:setTopBottom( true, true, 0, 0 )
	self.anyChildUsesUpdateState = true

	-- Perk list (horizontal layout, centered at bottom)
	self.PerkList = LUI.UIList.new( menu, controller, 2, 0, nil, false, false, 0, 0, false, false )
	self.PerkList:makeFocusable()
	self.PerkList:setLeftRight( false, false, -180, 180 )  -- Center horizontally (360px total for 20 perks)
	self.PerkList:setTopBottom( true, false, 666, 694 )  -- Position at 666px from top (28px tall)
	self.PerkList:setWidgetType( CoD.AetheriumPerkItem )
	self.PerkList:setHorizontalCount( 20 )  -- Max 20 perks displayed horizontally
	self.PerkList:setSpacing( 2 )  -- 2px spacing between perks
	self.PerkList:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
	self.PerkList:setDataSource( "AetheriumPerks" )
	self:addElement( self.PerkList )

	return self
end
