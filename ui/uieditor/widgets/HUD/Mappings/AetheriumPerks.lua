-- NOTE: The last entry should NOT have a comma ","
CoD.AetheriumPerks = {
	-- [tod 2026-08-23] ALL NINE ICONS ARE OURS NOW — the Grunge BO2-Style set the
	-- user supplied, installed through the i_tod_perk_* lane (PNG in
	-- source_data/tod_ui_images/_images/, block in tod_ui_images.gdt, image, line
	-- in zm_tower_of_doom.zone). One pack, one style, nine icons, which is what
	-- the user asked for after two earlier attempts each covered only part of the
	-- roster (the West pack is for CUSTOM perks and overlapped ours on one entry;
	-- the Aetherium kit ships no Double Tap 2, Widow's Wine or Electric Cherry).
	--
	-- WHY WE STOPPED USING THE STOCK specialty_*_zombies NAMES: seven of them
	-- resolve on a usermap and one does not. specialty_extraprimaryweapon_zombies
	-- (Mule Kick) is ABSENT from <TOOLS>/zone_source/all/assetlist/zm_levelcommon.csv
	-- — the common list every map inherits — so it drew a WHITE SQUARE in the
	-- shipped build, and it cannot be zoned because the asset does not exist to
	-- pack. Shipping our own art was the only fix for that one, and once one icon
	-- had to be custom, a full consistent set beat a 7+1+1 patchwork.
	--
	-- THE DIAGNOSTIC, if an icon ever goes white again: grep that assetlist for
	-- the name. In it -> renders. Absent -> white square. Do NOT guess which perks
	-- are "DLC"; two sessions guessed and both guessed wrong (the real radius was
	-- ONE, not four). Every name below is one of ours and every one is zoned.
	{
		-- PhD FLOPPER — replaced MULE KICK on the crown, 2026-08-25.
		--
		-- `specialty` IS THE STOCK CHERRY ONE ON PURPOSE. PhD is registered over
		-- the stock specialty_electriccherry pipeline (see _tod_perk_phd.gsc),
		-- which is free on this map because our Electric Cherry lives on
		-- specialty_combat_efficiency instead. Do NOT "correct" this to
		-- specialty_phdflopper — that is a zero-init stub in BO3 and the card
		-- would never light up.
		--
		-- clientFieldName follows the specialty, not the name: it must be the
		-- cherry pipeline's field, since that is the one the perk actually sets.
		name = "PhD FLOPPER",
		cost = 2000,
		description = "No fall or self-explosive damage; explode when downed",
		image = "i_tod_perk_phd",
		specialty = "specialty_electriccherry",
		clientFieldName = "electric_cherry"
	},
	{
		-- WISP TEA — replaced DEADSHOT, v14.16 (2026-08-30). BO7 perk from the
		-- same SATPerks pack as the machines + this crest set; rides the free
		-- engine specialty_nomotionsensor (the DP-on-combat_efficiency
		-- pattern). clientFieldName matches WISP_TEA_CLIENTFIELD
		-- ("hudItems.perks.wisp_tea") in scripts/zm/_zm_perk_wisp_tea.gsh.
		name = "WISP TEA",
		cost = 300,   -- user 2026-08-30; LOCKSTEP with WISP_TEA_PERK_COST in _zm_perk_wisp_tea.gsh
		description = "Chance on hitting zombies to summon a lethal wisp",
		image = "i_tod_perk_wisptea",
		specialty = "specialty_nomotionsensor",
		clientFieldName = "wisp_tea"
	},
	{
		name = "DOUBLE TAP",
		cost = 3000,
		description = "Bullets deal double damage",
		image = "i_tod_perk_doubletap",
		specialty = "specialty_doubletap2",
		clientFieldName = "doubletap2"
	},
	{
		name = "JUGGER-NOG",
		cost = 2500,
		description = "Raises maximum health to withstand more damage",
		image = "i_tod_perk_jugg",
		specialty = "specialty_armorvest",
		clientFieldName = "juggernaut"
	},
	{
		name = "STAMIN-UP",
		cost = 2000,
		description = "Sprint faster and for a longer duration",
		image = "i_tod_perk_staminup",
		specialty = "specialty_staminup",
		clientFieldName = "marathon"
	},
	{
		name = "QUICK REVIVE",
		cost = 1500,
		-- [tod] The only party-dependent stock price: 500 solo, 1500 co-op.
		-- PromptPerks.UpdatePerkInfo picks this when Engine.GetPlayerCount() <= 1.
		soloCost = 500,
		description = "Faster revives in co-op / Self-revive up to 3 times in solo",
		image = "i_tod_perk_revive",
		specialty = "specialty_quickrevive",
		clientFieldName = "quick_revive"
	},
	{
		name = "SPEED COLA",
		cost = 3000,
		description = "Reload weapons significantly faster",
		image = "i_tod_perk_speed",
		specialty = "specialty_fastreload",
		clientFieldName = "sleight_of_hand"
	},
	{
		name = "WIDOW'S WINE",
		cost = 4000,
		description = "Melee and grenade hits slow and web zombies",
		image = "i_tod_perk_widows",
		specialty = "specialty_widowswine",
		clientFieldName = "widows_wine"
	},
	{
		-- v13.19: ELEMENTAL POP became DEATH PERCEPTION (user 2026-08-29) —
		-- the see-the-horde-through-walls awareness perk (hellbound's proven
		-- keyline module, ported). Same specialty, same clientfield; cost
		-- 2000 -> 1500; machine/effect/name/icon all swapped
		-- (_tod_perk_electric_cherry.gsc/.csc carry the implementation).
		-- (v13.4 history: Electric Cherry had become Elemental Pop.)
		name = "DEATH PERCEPTION",
		cost = 1500,
		description = "Sense the horde through walls",
		-- FIXED 2026-08-25 (user: "electric cherry icon doesnt show up in HUD when
		-- you get it"). This row was inert for two reasons and both are gone:
		--
		--   1. NOTHING SET IT. _tod_perk_electric_cherry.gsc skipped
		--      register_perk_clientfields on the belief that the HUD reads the
		--      specialty natively. It does not — zm_perks::set_perk_clientfield
		--      (_zm_perks.gsc:968) is a NO-OP without a registered clientfield_set,
		--      and this container reads hudItems.perks.<clientFieldName> and never
		--      looks at `specialty` at all. The perk now registers a set func.
		--   2. "combat_efficiency" IS NOT A REGISTERED UIMODEL. It matched the
		--      perk's specialty, which reads well, but no clientuimodel field of
		--      that name exists in either VM, so writing it would have gone
		--      nowhere even once something tried.
		--
		-- clientFieldName is now MULE KICK's field. That looks wrong and is not:
		-- registering a new clientuimodel needs a matched append in BOTH VMs and
		-- this map has a documented boot ceiling on that pool (61 bits proven;
		-- we are at 58). additional_primary_weapon is already registered in both
		-- VMs by _zm_perk_additionalprimaryweapon, and Mule Kick was RETIRED from
		-- this map on 2026-08-25 when PhD replaced it — so the field is allocated,
		-- matched, free, and written by nothing else. Zero new bits.
		-- IT MUST STAY IN LOCKSTEP WITH EC_HUD_CLIENTFIELD in
		-- _tod_perk_electric_cherry.gsc. Change one, change the other.
		image = "i_tod_perk_deathperception",   -- v13.19: the pack's official Death Perception icon (same set as the rest)
		specialty = "specialty_combat_efficiency",
		clientFieldName = "additional_primary_weapon"
	}
	-- NOTE: Make sure to add the perk images to your zone file (aetherium_hud.zpkg):
	-- image,i_mtl_sat_ui_icon_perks_zm_doubletap
	-- image,i_mtl_sat_ui_icon_perks_zm_widowswine
	-- image,i_mtl_sat_ui_icon_perks_zm_electriccherry
}