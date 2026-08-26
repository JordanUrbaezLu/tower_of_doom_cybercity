-- Aetherium AAT (Alternate Ammo Type) Mappings
-- Maps BO3 AAT names to custom ammo mod icons

CoD.AetheriumAAT = {
	-- BO3 AATs
	["blast_furnace"] = "i_mtl_ui_icons_elementaldamage_fire",
	["dead_wire"] = "i_mtl_ui_icons_elementaldamage_electrical",
	["fire_works"] = "i_mtl_ui_icons_elementaldamage_pyro",
	["thunder_wall"] = "i_mtl_ui_icons_elementaldamage_storm",
	["turned"] = "i_mtl_ui_icons_elementaldamage_toxic",
	
	-- Fallback
	["default"] = "blacktransparent"
}

-- Helper function to get AAT icon from AAT name
function CoD.GetAATIcon(aatName)
	if not aatName or aatName == "" then
		return CoD.AetheriumAAT["default"]
	end
	
	-- Check each AAT key to see if it's in the aatName string
	for aatKey, iconPath in pairs(CoD.AetheriumAAT) do
		if aatKey ~= "default" and aatName:find(aatKey) then
			return iconPath
		end
	end
	
	-- Fallback to default
	return CoD.AetheriumAAT["default"]
end
