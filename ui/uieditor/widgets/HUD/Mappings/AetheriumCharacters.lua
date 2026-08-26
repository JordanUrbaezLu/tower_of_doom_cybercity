-- Aetherium Character Portrait Mappings
-- Maps BO3 character IDs to custom portrait icons

CoD.AetheriumCharacters = {
	-- Primis Crew (Origins/Der Eisendrache/etc.)
	["uie_t7_zm_hud_score_char1"] = "i_mtl_ui_icon_operators_nikolai",     -- Nikolai
	["uie_t7_zm_hud_score_char2"] = "i_mtl_ui_icon_operators_takeo",       -- Takeo
	["uie_t7_zm_hud_score_char3"] = "i_mtl_ui_icon_operators_dempsey",     -- Dempsey
	["uie_t7_zm_hud_score_char4"] = "i_mtl_ui_icon_operators_richtofen",   -- Richtofen
	
	-- Fallback
	["default"] = "blacktransparent"
}

-- Helper function to get character portrait icon
function CoD.GetCharacterPortrait(characterID)
	if not characterID or characterID == "" then
		return CoD.AetheriumCharacters["default"]
	end
	
	-- Check if mapping exists
	if CoD.AetheriumCharacters[characterID] then
		return CoD.AetheriumCharacters[characterID]
	end
	
	-- Fallback to default
	return CoD.AetheriumCharacters["default"]
end
