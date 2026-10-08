require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodUIOwnership" )
-- =============================================================================
-- AetheriumLoadout — THE GUN HUD (bottom right)
--
-- v17.9 REBUILD (user 2026-09-03): "we want to move over to the Gun HUD at
-- bottom right. We would need a component for clip, reserve, gun, name, lethal
-- and tacticals ... It would be nice to have each piece custom made so we can be
-- consistent."  Design + measurements: docs/95_gun_hud_art_prompt.md.
--
-- WHAT THIS FILE USED TO BE, AND THE EIGHT THINGS THAT WERE WRONG WITH IT.
-- Kept as a record because several of them looked fine and were not.
--
--  1. THE WEAPON ICON DREW NOTHING, FOR EVERY WEAPON IN THIS MAP. GetWeaponIcon
--     looked the gun up in CoD.AetheriumWeaponData (Mappings/AetheriumWeapons.lua)
--     whose gun entries are sat_ar_hawk / sat_ar_condor / sat_ar_macaw. Those
--     are the VENDORED KIT's entries, not map 1's roster as this comment used
--     to claim (corrected 2026-09-04): map 1 DELETED them — "that art isn't
--     shipped in the Aetherium asset pack, so the entries could only ever
--     render blank" — and replaced the table with its own 263-line roster.
--     This map kept the kit's copy untouched, so not one of its 24 ladder
--     weapons was in it, and every one
--     fell to ["default"] = { icon = "blacktransparent" }: a 190x112 physical-
--     pixel hole in the middle of the panel, shipped since the kit was vendored.
--     Now: TOD_GUN_CAT below, keyed on the weapon STEM, twelve categories.
--  2. THE LETHAL GLYPH WAS HARDCODED TO A FRAG, three times, and never read what
--     the player held. Widow's Wine is in this map's perk roster and it REPLACES
--     the lethal with a web grenade. The engine already publishes the answer —
--     the CurrentPrimaryOffhand/primaryOffhand global model carries a
--     ready-to-register image name (the old dead branch below tested one of
--     them, "uie_t7_zm_hud_inv_icntactlilarnie") — and map 1 ships the lane:
--     acc_hud.lua:1584-1592 does RegisterImage(v) on the engine's own value.
--     v17.10 went further, because matching that value turned out to be
--     impossible: see the note on the offhand lane below. Selection is now made
--     from PERK STATE, and the engine value is only the last-resort fallback.
--  3. A MELEE CLASS READ "0" AND "0" FOREVER. All 36 knife/wakizashi/leviathan
--     variants carry clipSize 0 and maxAmmo 0, and the SLASHER holds a blade at
--     all three tiers — a quarter of the roster, whole run. In Lua 0 is truthy,
--     so `if ammoInClip then` passed and a literal zero was drawn as the biggest
--     element on the panel. The riot shield lands in the same case. Map 1 hit
--     this and fixed it (acc_hud.lua:1484-1494). Now: TOD_NO_MAG_TEXT.
--  4. THE PLATE RAN OFF THE SCREEN — right edge x=2037 on a 1920-wide screen,
--     bottom y=1102 on a 1080-tall one. The fifth that got cut was the calm dark
--     tail; what stayed was the bright core, under the numbers. Plate deleted.
--  5. THE RESERVE WAS 15 PHYSICAL PIXELS TALL, under half the clip above it, and
--     it is the number you check before committing to a fight. Now 36.
--  6. THE OFFHAND TILES WERE ORANGE MIRRORED COPIES of one swoosh (-12.6% aspect)
--     with +17% stretched grey glyphs on them, in an otherwise all-cyan HUD.
--  7. THE WEAPON NAME RAN UNDER THE TACTICAL TILE — a 447px centred box whose
--     right 85px sat on the plate.
--  8. DEAD LANES, all deleted: the AAT/ammo-mod icon (subscribes to
--     currentWeapon.aatIcon; this map ships no alternate ammo types), the
--     octobomb branch (Li'l Arnie was retired from DISTRACTION in v16.49), and
--     the `isEquipment` substring test, which routed "knife_" to a 56x56 box and
--     therefore caught all 12 t9_me_baseballbat_* forms — the slasher's T1
--     PRIMARY — while setting setLeftRight three times and setTopBottom zero.
--
-- TodScaleHud IS GONE FROM THIS WIDGET (AetheriumHud.lua). The 1.15 scale about
-- (1005,620) existed to make the kit's small text readable; this file authors
-- bigger boxes instead, so canvas x 1.5 = 1080p exactly, there is no post-scale
-- arithmetic, and no box can walk off the screen.
--   *** THE PERKS CONTAINER STAYS A CHILD OF THIS WIDGET (see the bottom). ***
-- That is deliberate and it is the opposite of what the old ONE-ANCHOR LIMIT
-- comment in AetheriumHud.lua suggested. Dropping the scale puts PerkList's
-- ±180 box back on centre 640 — matching the powerup row — with ZERO
-- visibility-lane work, because a child keeps inheriting both alpha
-- subscriptions. Splitting it out means hand-adding both lanes, and
-- AetheriumHud.lua's two alpha writers are independent and already disagree.
--
-- ⚠️ THE TOWER GAUGE IS THE ONE NEIGHBOUR WITH NO CLEARANCE. tod_upgrade.lua's
-- GA_X/GA_Y put it at canvas x1216..1268, y150..566, UNSCALED, in an always-open
-- additive overlay that draws ON TOP of AetheriumHud. The offhand row starts at
-- y568. Two canvas pixels. Nothing here may grow upward.
--
-- THE ART IS ALL IN. docs/95 delivered the panel, the tile, 12 weapon
-- silhouettes, 3 offhand glyphs and a custom typeface (13 numerals, 29 letters);
-- docs/96 redrew the weapons with interior detail and gave the offhand glyphs the
-- dark outline they were missing; docs/97 added the KATANA and the GIFT LAUNCHER
-- and replaced the web grenade with a SPIDER pair. Every number and the weapon
-- name in this widget are assembled from baked glyph art — there is no system
-- font left in this corner. TOD_GLYPHS is the one switch, and the TTF weapon
-- name below is now only the auto-fit fallback for a name too long to set.
-- =============================================================================

require( "ui.uieditor.widgets.HUD.Mappings.AetheriumWeapons" )  -- CoD.GetWeaponDataByName, used by the cursor hint
require( "ui.uieditor.widgets.HUD.Mappings.AetheriumAAT" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodAbilityFeedback" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.AetheriumPerksContainer" )
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodGlyphRow" )      -- the baked typeface (pulls TodGlyphMetrics in)

-- Helper kept for the CURSOR HINT, which is this table's only remaining reader.
-- (ZMCursorHintNew.lua calls CoD.GetWeaponDataByName for its description text.)
function CoD.GetWeaponDataByName( weaponName )
	if not weaponName or weaponName == "" or not CoD.AetheriumWeaponData then
		return { icon = "blacktransparent", description = "" }
	end
	if CoD.AetheriumWeaponData[ weaponName ] then
		return CoD.AetheriumWeaponData[ weaponName ]
	end
	local lowerName = string.lower( weaponName )
	for _, info in pairs( CoD.AetheriumWeaponData ) do
		if info.ingame_name and string.find( lowerName, string.lower( info.ingame_name ), 1, true ) then
			return info
		end
	end
	return CoD.AetheriumWeaponData[ "default" ] or { icon = "blacktransparent", description = "" }
end

-- ---------------------------------------------------------------------------
-- THE WEAPON CATEGORY TABLE — the fix for defect 1, and the ONE place a new gun
-- is registered on the HUD side.
--
-- ONE PICTURE PER GUN since v17.40 (docs/98). v17.9..v17.39 shipped a CATEGORY
-- set — 14 cells for 26 weapons, on the argument that the name above the bay
-- says which gun and the silhouette only has to say what kind. The user
-- rejected that on 2026-09-04 ("the RPK and the Stoner have the same image" —
-- the HK21 and the Stoner 63, both on the lmg cell): twenty weapons shared six
-- pictures, and every class promotion except the slasher's drew the same gun
-- before and after. The VALUES below are now per-gun image slugs; the eight
-- weapons that were already one-to-one (minigun, launcher, nailgun, blade,
-- katana, axe, shield, gift) keep their cells. Both PaP names of a gun map to
-- its slug; the two dual-wield PaP forms get their own. The value is still
-- called a "category" in the code below because it also keys TOD_NO_MAG and
-- TOD_AKIMBO — it is "which picture", and those two sets read it.
--
-- Keys are STEMS. The runtime name carries an axis suffix (_a0b0c0), a _zm tail,
-- a PaP _up, and for two guns a dual-wield _rdw/_ldw, so the match is a
-- substring test in TOD_CAT_ORDER order — LONGEST FIRST, so t9_me_baseballbat
-- cannot be shadowed by a shorter key and t6_executioner_rdw cannot fall through
-- to t6_executioner.
-- ---------------------------------------------------------------------------
local TOD_GUN_CAT = {
	-- akimbo first: these are PaP forms of guns that also appear below, and the
	-- player is visibly holding two of them.
	[ "t9_amp63_rdw" ]        = "amp63_akimbo",
	[ "t9_amp63_ldw" ]        = "amp63_akimbo",
	[ "t6_executioner_rdw" ]  = "executioner_akimbo",
	[ "t6_executioner_ldw" ]  = "executioner_akimbo",

	[ "t6_msmc" ]            = "mac10",
	[ "t9_mp5" ]              = "mp5",
	[ "t6_mp7" ]              = "mp7",

	[ "t5_enfield" ]          = "enfield",
	[ "t9_krig6" ]            = "krig6",
	[ "t9_ak47" ]             = "ak47",

	[ "t6_mk48" ]         = "stoner63",
	[ "t5_hk21" ]             = "hk21",

	[ "t6_death_machine" ]    = "minigun",

	-- THE GIFT OF DEATH IS NOT A MINIGUN, and it used to be drawn as one.
	-- _tod_powerups.gsc redirects the Death Machine powerup to xmas_gun, whose
	-- model is a wrapped PRESENT — its bones are named for box-lid flaps as the
	-- magazine, ribbon bows, a gift tag and eight jingle bells — and it fires
	-- exploding ornaments (weaponClass "rocketlauncher", weaponType
	-- "projectile", Full Auto). Every player who grabs that powerup was seeing
	-- the wrong picture. Its own cell since v17.12.
	[ "xmas_gun" ]            = "gift",

	[ "s1_bulldog" ]          = "bulldog",
	[ "t8_sg12" ]             = "sg12",
	[ "t6_spas12" ]           = "spas12",
	[ "t8_mog12" ]            = "mog12",

	[ "pistol_standard" ]     = "mr6",       -- start weapon, heavy T1 sidearm, last stand
	[ "t9_magnum" ]           = "magnum",
	[ "t6_executioner" ]      = "executioner",
	[ "iw7_udm" ]             = "udm",
	[ "t8_rk7" ]              = "rk7",
	[ "t9_amp63" ]            = "amp63",

	[ "t6_rpg" ]              = "launcher",
	[ "t9_nail_gun" ]         = "nailgun",

	-- [tod v19.9] THE BAT HAS ITS OWN CELL. It shared "blade" with the bowie,
	-- the three Widow's Wine knives and zombie_fists, so drawing a bat there
	-- would have put a bat in a downed player's hands. Art i_tod_hud_gun_bat,
	-- zoned; "blade" keeps the knife it always drew.
	[ "t9_me_baseballbat" ] = "bat",
	-- THE WAKIZASHI IS A SHORT SWORD, not a knife, and it has its own cell since
	-- v17.12. Sharing the knife's cell made the SLASHER's TIER-2 PROMOTION
	-- invisible on the HUD — that class's ladder is knife -> wakizashi -> axe, so
	-- two of its three rungs drew the same picture while the third did not.
	[ "t9_me_wakizashi" ]     = "katana",
	[ "bowie_knife" ]         = "blade",
	[ "leviathan" ]           = "axe",

	-- THE WIDOW'S WINE KNIFE. Buying Widow's Wine swaps the player's MELEE for a
	-- widow variant, and without a key here that lands on the pistol cold-start
	-- default — a melee weapon drawing a handgun. Which variant you get depends
	-- on your base melee, and on this map that is plain "knife": nothing in
	-- scripts/ ever calls set_player_melee_weapon, so stock's generic branch runs
	-- and every buyer gets knife_widows_wine. The other two are keyed anyway
	-- because they cost nothing and the branch that picks them is stock's, not
	-- ours. (Note the SLASHER's alt bowie is raw-GiveWeapon'd, which does NOT
	-- change current_melee_weapon — the comment in _tod_classes.gsc saying it
	-- "replaces the base knife everywhere" is about inventory, not the melee
	-- slot.)
	[ "knife_widows_wine" ]        = "blade",
	[ "bowie_knife_widows_wine" ]  = "blade",
	[ "sickle_knife_widows_wine" ] = "blade",

	-- BARE FISTS. Two stock paths switch a player to zombie_fists: the riot
	-- shield being destroyed while held (_zm_weap_riotshield.gsc) and going down
	-- holding it with no other primary (_zm_laststand.gsc). Both take the "has a
	-- primary" arm here, because a player always carries a class gun plus a
	-- sidearm — so this is unreachable TODAY rather than absent. Keyed as
	-- insurance because the class-gun watchdog in _tod_upgrades.gsc exists
	-- precisely because inventory has been emptied before.
	[ "zombie_fists" ]        = "blade",
	[ "zombie_fists_bowie" ]  = "blade",

	[ "zod_riotshield" ]      = "shield",
	[ "log_riotshield" ]      = "shield",
}

-- longest key first, so a stem can never be shadowed by a prefix of itself
local TOD_CAT_ORDER = {}
-- [tod docs/116] THE THREE STAFF ROWS, live since the art landed 2026-09-07.
TOD_GUN_CAT[ "tod_staff_lightning" ] = "staff1"   -- v18.30: stems are the ELEMENT now
TOD_GUN_CAT[ "tod_staff_fire" ]      = "staff2"
TOD_GUN_CAT[ "tod_staff_ice" ]       = "staff3"
-- Held staff ID from _tod_classes::pap_staff_id; base and PaP names.
-- The server sends identity and tier together. No engine-name matching needed.
local TOD_STAFF_NAME = {
	[ 1 ] = { "LIGHTNING STAFF", "KIMAT'S BITE" },
	[ 2 ] = { "FIRE STAFF", "KAGUTSUCHI'S BLOOD" },
	[ 3 ] = { "ICE STAFF", "ULL'S ARROW" },
}

-- [tod docs/114] NO MAGE FLAG IN THIS FILE, DELIBERATELY (2026-09-07).
-- A TOD_MAGE_ART local guarded three staff rows here for one afternoon and
-- has been removed -- user: *"behind a singular flag ... we don't want those
-- to intersect at all."* The rows cannot be switched on until the three
-- staff HUD icons are baked and zoned, so the flag bought nothing today.
--
-- WHEN THAT ART LANDS, add beside the table above (docs/116):
--   [ "tod_staff_t1" ] = "staff1",  [ "tod_staff_t2" ] = "staff2",
--   [ "tod_staff_t3" ] = "staff3",
-- and zone i_tod_hud_gun_staff1/2/3. These are CONSTRUCTED names
-- ("i_tod_hud_gun_" .. cat), so no lint can warn if the art is missing --
-- an unzoned one draws a WHITE SQUARE in the gun bay.

for k in pairs( TOD_GUN_CAT ) do TOD_CAT_ORDER[ #TOD_CAT_ORDER + 1 ] = k end
table.sort( TOD_CAT_ORDER, function ( a, b ) return #a > #b end )

local function TodWeaponCategory( weaponName )
	if not weaponName or weaponName == "" then return nil end
	local n = string.lower( weaponName )
	for i = 1, #TOD_CAT_ORDER do
		local k = TOD_CAT_ORDER[ i ]
		if string.find( n, k, 1, true ) then return TOD_GUN_CAT[ k ] end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- THE SAME TABLE, KEYED ON THE DISPLAY NAME — and this is the lane that works.
--
-- v17.13 (user, after playing v17.12): "my gun icon in gun HUD on bottom right
-- doesnt swap. I swapped to mac and bulldog and it only showed a pistol the
-- whole time. Gun ammo swapped correctly. But gun icons didnt."
--
-- The icon rode `currentWeapon.viewmodelWeaponName` alone. That model was the
-- ONE fact an adversarial pass had flagged as UNPROVEN before v17.9 shipped —
-- nobody can prove what it returns from source, `share/raw` ships no Lua, and
-- map 1's HUD subscribes `currentWeapon.weapon` and then DISCARDS the value,
-- using it only as a "something changed" pulse. That was the strongest possible
-- tell that its payload is not to be trusted, and it was in the notes. Shipping
-- on it anyway is how the icon sat on its cold-start default all match.
--
-- The fix does not try to find out what that model contains. It drives the icon
-- from the lane this map DEMONSTRABLY has: the weapon NAME, which swaps
-- correctly in game because the name text is right there next to the icon doing
-- it.
--
-- v17.19 (user, after playing v17.14: the icon STILL only showed the pistol).
-- v17.13 was right about which model to trust and wrong about how to attach to
-- it. It kept the old viewmodelWeaponName subscription and added a second one
-- for weaponName ON THE SAME ELEMENT, and the symptom did not move by a pixel
-- even though the two builds resolve the category from completely different
-- tables — which is the signature of a change that never executed at all, not
-- of a lookup that missed. self.gun_icon was the ONLY element on this panel
-- carrying two subscriptions; every single-subscription readout here works.
-- So the icon now rides the weapon-name handler itself: same callback, same
-- element, same model, and viewmodelWeaponName is gone. See the gun-bay block.
--
-- The keys are every `displayName` in source_data/tod_weapon_twins.gdt, base and
-- PaP, uppercased — GENERATED from the GDT rather than typed, so a name cannot
-- be misspelled here, plus the four weapons that GDT does not generate (the
-- AMP63 pair, the Gift of Death pair and the riot shield).
-- ---------------------------------------------------------------------------
local TOD_NAME_CAT = {
	-- THE START PISTOL AND ITS PaP FORM, ADDED v17.19. Neither is in the twins
	-- GDT -- pistol_standard is stock -- so the generated block below never had
	-- them, and the one weapon every player holds at spawn, every HEAVY carries
	-- as a T1 sidearm and every downed player crawls with could not be resolved
	-- at all. It only ever looked right because "pistol" is also the cold-start
	-- default, which is precisely the invisible-failure shape this lane keeps
	-- getting caught by.
	-- NOTE THE LITERAL "&": todApplyWeapon does NOT do setWeaponName's
	-- "&" -> " AND " expansion (that exists only because the delivered ampersand
	-- glyph reads as an 8), so the key must be spelled as the value ARRIVES.
	-- PaP names were paired to their guns from the GDTs on 2026-09-04, NOT from
	-- memory: FACE HAMMER is the BULLDOG's PaP form and BRECCIUS REBORNUS is the
	-- SG12's (both were "shotgun" before, so the pairing never mattered).
	[ "DEATH & TAXES" ] = "mr6",
	[ "MR6" ] = "mr6",

	-- THE THREE STAFFS (2026-09-09). The resolver takes the DISPLAY name and
	-- this table is its only lookup that fires; the tod_staff_* stem rows in
	-- TOD_GUN_CAT never see an asset name. Without these three, every staff
	-- resolved to nil and "keep the last good icon" kept the spawn MR6 (user:
	-- "Im using lightning staff and see the mr6 icon"). The "GENERATED from the
	-- GDT" claim above did not cover source_data/tod_staff.gdt. Same names on
	-- q0 / q1 and on every script-paid PaP tier, so three rows cover all six.
	[ "LIGHTNING STAFF" ] = "staff1",
	[ "FIRE STAFF" ] = "staff2",
	[ "ICE STAFF" ] = "staff3",
	-- packed staff names from the server's held-weapon update
	[ "KIMAT'S BITE" ] = "staff1",
	[ "KAGUTSUCHI'S BLOOD" ] = "staff2",
	[ "ULL'S ARROW" ] = "staff3",

	[ "VOICE OF JUSTICE & RAGING JUDGE" ] = "executioner_akimbo",   -- PaP Executioner: dualWield 1
	[ "UNIVERSAL DEMOLISHING MECHANISM" ] = "udm",
	[ "ROCKET PROPELLED GRIEVANCE" ] = "launcher",
	[ "RASPUTIN'S RETRIBUTION" ] = "ak47",
	[ "MAGNA IMPETU" ] = "stoner63",
	[ "MYSTIC PONY EXPRESS" ] = "mp5",
	[ "PNEUMATIC IRRUPTOR" ] = "nailgun",
	[ "BRECCIUS REBORNUS" ] = "sg12",
	[ "BASEBALL BAT" ] = "bat",
	[ "GRAND SLAMMER" ] = "bat",
	[ "H115 OSCILLATOR" ] = "hk21",
	[ "STORMBREAKER EX" ] = "axe",
	[ "MP117 REDACTOR" ] = "mp7",
	[ "OMG RIGHT HOOK" ] = "mog12",
	[ "RAPSKALLION 3D" ] = "rk7",
	[ "DEATH MACHINE" ] = "minigun",
	[ "RK 7 GARRISON" ] = "rk7",
	[ "GIFT OF DEATH" ] = "gift",
	[ "X-MASS MURDER" ] = "gift",
	[ "BLITZKRIG 99" ] = "krig6",
	[ "MEAT GRINDER" ] = "minigun",
	[ "YAMIKIRIMARU" ] = "katana",
	[ "STORMBREAKER" ] = "axe",
	[ "TOKYO & ROSE" ] = "amp63_akimbo",                            -- PaP AMP63: dualWield 1
	[ "FACE HAMMER" ] = "bulldog",
	[ "PRIVATE EYE" ] = "magnum",
	[ "EXECUTIONER" ] = "executioner",
	[ "RIOT SHIELD" ] = "shield",
	[ "MK 48" ] = "stoner63",
	[ "E2N-F13LD" ] = "enfield",
	[ "WAKIZASHI" ] = "katana",
	[ "MINIATURE SINISTER MISCHIEVOUS CATALYST" ] = "mac10",
	[ "NAIL GUN" ] = "nailgun",
	[ "BULLDOG" ] = "bulldog",
	[ "SPAS-12" ] = "spas12",
	[ "SPAZ-36" ] = "spas12",
	[ "ENFIELD" ] = "enfield",
	[ "KRIG 6" ] = "krig6",
	[ "MSMC" ] = "mac10",
	[ "MAGNUM" ] = "magnum",
	[ "MOG 12" ] = "mog12",
	[ "KNIFE" ] = "blade",
	[ "AK-47" ] = "ak47",
	[ "AMP63" ] = "amp63",
	[ "SG12" ] = "sg12",
	[ "HK21" ] = "hk21",
	[ "MP5" ] = "mp5",
	[ "MP7" ] = "mp7",
	[ "RPG" ] = "launcher",
	[ "UDM" ] = "udm",
}

local TOD_NAME_ORDER = {}
for k in pairs( TOD_NAME_CAT ) do TOD_NAME_ORDER[ #TOD_NAME_ORDER + 1 ] = k end
table.sort( TOD_NAME_ORDER, function ( a, b ) return #a > #b end )

-- THE SAME KEYS WITH EVERY SEPARATOR REMOVED (v17.21). "MAC-10" and "MAC10" and
-- "MAC 10" all normalise to MAC10, so a display string that differs from the GDT
-- by punctuation, spacing or a non-ASCII dash still resolves.
--
-- WHY THIS EXISTS. Two builds have now failed to move this icon off its default,
-- and every OTHER link in the chain has been ruled out with evidence: the
-- subscription (the icon shares the weapon-name callback, and the name swaps),
-- the image write (the pistol on screen is drawn by the same line), the art (14
-- zone lines, 14 converted .iwi), and the table itself -- a script checked all 44
-- displayName values in tod_weapon_twins.gdt and every one of them resolves.
-- The one link never checked is whether Engine.Localize hands back a string that
-- is CHARACTER-FOR-CHARACTER the GDT's displayName. This is the cheap insurance
-- against it not doing so, and it costs one extra table probe on a weapon switch.
local function todNorm( str )
	if str == nil then return "" end
	return ( string.gsub( string.upper( str ), "[^A-Z0-9]", "" ) )
end

local TOD_NAME_NORM = {}
for k, v in pairs( TOD_NAME_CAT ) do TOD_NAME_NORM[ todNorm( k ) ] = v end
local TOD_NORM_ORDER = {}
for k in pairs( TOD_NAME_NORM ) do TOD_NORM_ORDER[ #TOD_NORM_ORDER + 1 ] = k end
table.sort( TOD_NORM_ORDER, function ( a, b ) return #a > #b end )

-- Four stages, cheapest and most exact first. Longest-first on both substring
-- passes, so "MP117 REDACTOR" cannot be claimed by a shorter key and "SPAS-12"
-- cannot be claimed by "12".
local function TodCategoryFromName( disp )
	if not disp or disp == "" then return nil end
	if TOD_NAME_CAT[ disp ] then return TOD_NAME_CAT[ disp ] end

	local nd = todNorm( disp )
	if TOD_NAME_NORM[ nd ] then return TOD_NAME_NORM[ nd ] end

	for i = 1, #TOD_NAME_ORDER do
		local k = TOD_NAME_ORDER[ i ]
		if string.find( disp, k, 1, true ) then return TOD_NAME_CAT[ k ] end
	end

	-- Normalised substring last. The 3-character floor keeps a very short key from
	-- claiming a long name once the separators are gone; the shortest keys here
	-- (MR6, MP5, MP7, RPG, UDM) are all exactly 3.
	for i = 1, #TOD_NORM_ORDER do
		local k = TOD_NORM_ORDER[ i ]
		if #k >= 3 and string.find( nd, k, 1, true ) then return TOD_NAME_NORM[ k ] end
	end
	return nil
end

-- A blade, a katana, an axe or a shield has NO magazine and NO reserve
-- (clipSize 0 / maxAmmo 0 on all 36 melee variants). Those weapons show a dash,
-- not a zero.
--   *** KATANA WAS MISSING UNTIL v17.19. *** v17.12 split the wakizashi out of
-- the blade cell so the SLASHER's tier-2 promotion would be visible on the HUD,
-- and split it out of this set at the same time without meaning to. The exact
-- defect item 3 of the v17.9 rebuild was written to kill -- a melee weapon
-- reading a literal "0 / 0" as the biggest element on the panel -- was therefore
-- live again for the wakizashi and Yamikirimaru. A category added to one table
-- owes an answer in every table keyed on categories.
--   *** AND THE BAT WAS MISSING UNTIL v19.38, FOR THE SAME REASON. *** v19.9
-- gave the bat its own "bat" cell and never added it here, so the SLASHER's
-- starting weapon read "0 / 0" for its whole first tier.
local TOD_NO_MAG = { blade = true, katana = true, axe = true, shield = true, bat = true }
local TOD_NO_MAG_TEXT = "-"
-- [tod v19.63] A staff has no ammunition for ANYONE holding it (see paintClip).
local TOD_STAFF_CAT = { staff1 = true, staff2 = true, staff3 = true }

-- The two dual-wield pictures. The clip readout doubles the single-hand count
-- for these (the engine reports one hand). Was `cat == "akimbo"` while both
-- pairs shared one cell; a set since v17.40 gave each pair its own.
local TOD_AKIMBO = { executioner_akimbo = true, amp63_akimbo = true }

-- The bespoke art landed 2026-09-03 (drop 22:56). Six delivered files became 59
-- shipped images: the weapon panel and the offhand tile whole, plus 57 cells cut
-- by tools/slice_hud_sheets.js from four SHEETS.
local TOD_GLYPHS = true

-- ============================================================================
-- TOD_HUD_DEBUG — A ONE-BUILD PROBE, GATED IN build_map.ps1 (v17.21).
--
-- Armed, the weapon-name band renders "<NAME> <CATEGORY>" — "MAC-10 SMG",
-- "MAC-10 NIL". That is the reading two builds of guessing have been missing,
-- and it separates the three states that ALL look like "the icon is a pistol":
--
--   name + a category   -> the resolver works; the fault is the image write
--   name + NIL          -> the lookup fails on a string that LOOKS right, so
--                          Engine.Localize is not handing back the displayName
--   no suffix at all    -> this .ff is not the one running. That matters right
--                          now: the account is SUBSCRIBED to the published
--                          Workshop copy of this map, and a subscribed copy can
--                          load instead of the usermaps build.
--
-- Lua cannot read level.tod_dev, so this cannot gate itself — build_map.ps1
-- greps for it, warns on every build and DIES on -Publish, exactly as it does
-- for TOD_MOCK_PARTY. Set it back to false once the answer is in.
-- ============================================================================
local TOD_HUD_DEBUG = false

-- ============================================================================
-- HUD_DX — THE WHOLE GUN HUD SLIDES AS ONE (v17.22, user: "push the gun HUD
-- like 10 units to the right so its aligned with the tower image on the right
-- of screen ... Ill analyze after and we can adjust").
--
-- Canvas units on the 1280x720 canvas, so 10 here is 15 physical px at 1080p.
-- Every x anchor below is written as its DESIGN coordinate + HUD_DX, which is
-- the point: the design numbers in the comments stay TRUE and the offset stays
-- ONE number to tune. Never bake the offset into the coordinates.
--
-- WHY 4. The tower gauge is x1216..1268 (tod_upgrade.lua, GA_X 1216 + GA_W
-- 52) and this panel is x1000..1256, so at HUD_DX 12 the two right edges were
-- FLUSH at 1268. v18.x (user 2026-09-07: "move it a little bit to the left,
-- maybe eight points ... it won't align, but it's more towards the center of
-- the screen so people can see it") gives back 8 of those 12: the panel is
-- deliberately NO LONGER flush with the gauge, it is more readable.
-- Widths (NAME_MAXW, CLIP_MAXW) are NOT offsets and do not move.
--
-- CEILING: the rightmost thing here is the lethal tile at 1210+46 = 1256, so
-- HUD_DX can go to 24 before anything touches the 1280 canvas edge.
--
-- NOT APPLIED TO THE WIDGET ROOT, deliberately. self is 0..1280 and the perks
-- container is a CHILD of it (see the header) — shifting the root would drag
-- PerkList off its centre-640 alignment with the powerup row, which is the one
-- thing keeping that lane free of extra wiring.
-- ============================================================================
local HUD_DX = 4

-- The flat dark stand-in, kept for the two thin rules the panel art does not
-- provide. i_tod_hud_health_fill is opaque edge to edge and identical in every
-- column BY CONTRACT (it is wipe-clipped and runtime-tinted in the player
-- readout), which is exactly what makes it usable as a solid.
local TOD_SLAB = "i_tod_hud_health_fill"
local SLAB_R, SLAB_G, SLAB_B = 0.055, 0.075, 0.13

-- =============================================================================
-- THE CUSTOM TYPEFACE — now LIVES IN TodGlyphRow.lua (v17.25).
--
-- The ~150 lines that used to sit here (the pooled glyph row, the two image
-- mappers, the set pickers and the derived-metrics layout maths) moved out
-- VERBATIM when the top-right ROUND readout became the second widget to set
-- text in the baked typeface. Read TodGlyphRow.lua's header for the whole
-- story; nothing about how this file uses it changed, and the three names
-- below are the same functions under the same names.
--
-- DO NOT re-inline any of it. The layout maths is the CONSUMER of the GENERATED
-- CoD.TodGlyphMetrics table, so a second copy would drift silently the next
-- time tools/slice_hud_sheets.js re-measures a redrawn glyph.
-- =============================================================================
local todMakeGlyphRow = CoD.TodGlyphRow.make
local todNameSet      = CoD.TodGlyphRow.nameSet
local todSetDigits    = CoD.TodGlyphRow.digitSet

-- SPLIT A NAME INTO TWO LINES AT THE SPACE NEAREST THE MIDDLE. Balanced, not
-- greedy: "UNIVERSAL DEMOLISHING MECHANISM" wants UNIVERSAL / DEMOLISHING
-- MECHANISM, not UNIVERSAL DEMOLISHING / MECHANISM, because the widest line is
-- what sets the type size for both. Returns nil for a single-word name, which
-- is the caller's signal that wrapping is not available and it must shrink.
local function todSplitTwo( str )
	local best, bestd = nil, nil
	local mid, i = #str / 2, 1
	while true do
		local a = string.find( str, " ", i, true )
		if not a then break end
		local d = a - mid
		if d < 0 then d = -d end
		if bestd == nil or d < bestd then best, bestd = a, d end
		i = a + 1
	end
	if best == nil then return nil end
	return string.sub( str, 1, best - 1 ), string.sub( str, best + 1 )
end

CoD.AetheriumLoadout = InheritFrom( LUI.UIElement )
CoD.AetheriumLoadout.new = function ( menu, controller )
	local self = LUI.UIElement.new()
    CoD.TodUIOwnership.Attach( self )

	self:setUseStencil( false )
	self:setClass( CoD.AetheriumLoadout )
	self.id = "AetheriumLoadout"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self.anyChildUsesUpdateState = true

	local model = function ( name )
		return Engine.GetModel( Engine.GetModelForController( controller ), name )
	end

	-- =========================================================================
	-- THE WEAPON PANEL — canvas x1000..1256, y604..678 (384 x 111 physical px).
	-- The delivered art carries the gun bay's keyline, the clip/reserve divider,
	-- the name-band hairline and the cyan baseline rule, so nothing below draws
	-- furniture. 1024x296 into 256x74 canvas is aspect 3.4595 on BOTH sides:
	-- zero stretch, which is the defect docs/89 was written to kill.
	-- =========================================================================
	self.panel = LUI.UIImage.new()
	self.panel:setLeftRight( true, false, 1000 + HUD_DX, 1256 + HUD_DX )
	self.panel:setTopBottom( true, false, 604, 678 )
	self.panel:setImage( RegisterImage( TOD_GLYPHS and "i_tod_hud_weapon_panel" or TOD_SLAB ) )
	self.panel:setRGB( 1, 1, 1 )
	self.panel:setAlpha( 1 )
	if not TOD_GLYPHS then self.panel:setRGB( SLAB_R, SLAB_G, SLAB_B ); self.panel:setAlpha( 0.86 ) end
	self:addElement( self.panel )

	-- =========================================================================
	-- GUN BAY — canvas x1004..1100, y632..676 (144 x 66 px, aspect 2.1818,
	-- exactly the gun sheet's 288x132 cell).
	-- =========================================================================
	self.gun_icon = LUI.UIImage.new()
	self.gun_icon:setLeftRight( true, false, 1004 + HUD_DX, 1100 + HUD_DX )
	self.gun_icon:setTopBottom( true, false, 632, 676 )
	self.gun_icon:setImage( RegisterImage( "blacktransparent" ) )
	self.gun_icon:setRGB( 1, 1, 1 )
	self.gun_icon:setAlpha( 1.0 )
	self:addElement( self.gun_icon )

	-- =========================================================================
	-- THE GLYPH ROWS. Right edges and baselines, in canvas coords; each row's
	-- pool is sized for the longest string it can ever be asked to draw.
	--   name     x1004..1252, cap 17, baseline 629   (32 glyphs: the longest
	--            display name is 31 characters, and "&" expands to " AND ")
	--   clip     right 1186,  cap 27, baseline 671   (4: roster max is 188, and
	--            the Death Machine powerup gift may be four)
	--   reserve  right 1250,  cap 17, baseline 670   (4: roster max is 752)
	--   counts   2 each
	-- =========================================================================
	-- TWO ROWS FOR THE NAME (v17.24). A pooled row draws ONE string, so a second
	-- line needs a second row. 26 covers the longest half a balanced split can
	-- produce from the 33-character worst case ("VOICE OF JUSTICE AND RAGING
	-- JUDGE", after the & expansion); row 1 stays 32 because it still carries the
	-- whole name in the single-line cases.
	self.name_row  = todMakeGlyphRow( self, 32 )
	self.name_row2 = todMakeGlyphRow( self, 26 )
	-- 7, not 4 (v17.21). NOT for the reverted "8/8" — this stands on its own.
	-- row.set() TRUNCATES a string longer than its pool and says nothing: it draws
	-- the leftmost n cells of a RIGHT-ALIGNED layout and silently drops the tail,
	-- so an overlong value does not look overlong, it looks like a different
	-- number. 4 was already exactly the documented worst case ("the Death Machine
	-- powerup gift may be four") with zero margin, and the doubled dual-wield
	-- figure shares that cell. Pool entries are one hidden UIImage each, so the
	-- headroom costs nothing and removes a whole class of silent wrongness.
	self.clip_row  = todMakeGlyphRow( self, 7 )
	self.stock_row = todMakeGlyphRow( self, 4 )

	local NAME_R, NAME_CAP, NAME_BASE = 1252 + HUD_DX, 17, 629
	local NAME_MAXW = 248                      -- x1004..1252
	local CLIP_R, CLIP_CAP, CLIP_BASE = 1186 + HUD_DX, 27, 671
	local STOCK_R, STOCK_CAP, STOCK_BASE = 1250 + HUD_DX, 17, 670

	-- THE CLIP CELL IS 85 CANVAS PX WIDE and the row does not know that. The gun
	-- bay's keyline ends at x1101 and the panel art's clip/reserve divider is at
	-- x1190, with the number right-aligned at CLIP_R 1186. Measured against the
	-- generated metrics at CLIP_CAP: "8/8" is 63px and fits, "188" is 63px and
	-- fits, but "15/15" is 98px and a four-digit count is 87px — both walk left
	-- over the gun icon. So measure, and shrink the cap to fit when it does not.
	-- Same shape as the weapon name's auto-fit above, minus the TTF fallback: a
	-- number always has a glyph, so measure can only fail if the metrics table is
	-- missing entirely, and then set() draws nothing either way.
	local CLIP_MAXW = 84
	local function setClipText( str )
		local cap = CLIP_CAP
		local w = self.clip_row.measure( str, CLIP_CAP, todSetDigits )
		if w > CLIP_MAXW then cap = CLIP_CAP * ( CLIP_MAXW / w ) end
		self.clip_row.set( str, cap, CLIP_R, CLIP_BASE, todSetDigits )
	end

	-- THE FALLBACK. Kept as a real element, not as a comment: if a name cannot
	-- be set from the glyph sheets — a character with no cell, or a string still
	-- too wide at the auto-fit floor — this draws it instead. A missing glyph
	-- must degrade to readable text, never to a gap.
	self.weapon_name = LUI.UIText.new()
	self.weapon_name:setLeftRight( true, false, 1004 + HUD_DX, 1252 + HUD_DX )
	self.weapon_name:setTopBottom( true, false, 606, 630 )
	self.weapon_name:setText( Engine.Localize( "" ) )
	self.weapon_name:setTTF( "fonts/orbitron.ttf" )
	self.weapon_name:setRGB( 0.874, 0.949, 1.0 )
	self.weapon_name:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_RIGHT )
	self.weapon_name:setAlpha( 0 )
	self:addElement( self.weapon_name )

	-- =========================================================================
	-- STATE
	-- Every one of these resets on respawn: the engine re-runs this menu's
	-- lifecycle on the death -> spectate transition (see the note in
	-- _tod_upgrade_ui.gsc), so there is no such thing as a value that survives a
	-- life. Cold starts below are therefore DEFINED, not incidental.
	-- =========================================================================
	local curWeapon  = ""      -- the raw value of whichever model last resolved
	local curSrc     = "-"     -- which one that was: N = weaponName, V = viewmodel
	local curCat     = nil     -- its category, or nil
	local noMag      = false   -- blade / axe / shield: show a dash, not a zero
	local clipMax    = 0       -- largest clip seen for curWeapon
	local clipWeapon = ""
	local clipPair   = false   -- [tod v19.76] the pair state clipMax was learned in
	-- [tod v18.42] THE MAGE'S MANA BAR owns the clip/reserve cells while it is
	-- up, so the two ammo subscriptions below check this and draw nothing. It
	-- is an upvalue rather than a field because those callbacks are closures
	-- created before the bar exists. False at every cold start, which is right:
	-- the widget's whole lifecycle re-runs on a death and the server re-pushes.
	local manaOn     = false
	-- [2026-09-24] A DOWNED MAGE (mana state 4) holds a real pistol with real
	-- ammunition, so the clip/reserve rows come back while the ability tiles
	-- stay the mage's (manaOn stays true for them). Declared HERE, above the two
	-- ammo painters that read it: a closure above a `local` binds a nil global.
	local manaDowned = false

	-- ---- gun bay --------------------------------------------------------
	-- COLD START IS DEFINED, not incidental. Every upvalue here resets on
	-- respawn, so "no category yet" happens at the top of every life and during
	-- the 30 s class-select draft, when the player holds the start pistol and
	-- weapons are disabled. An unknown weapon draws the MR6 rather than a
	-- hole: the start weapon and the last-stand weapon really are the MR6, so it
	-- is right far more often than it is wrong, and a hole is never right.
	-- (v17.40: "pistol" -> "mr6" with the per-gun set. Note the default is now
	-- ONE handgun of six, so a resolver failure is at least visible whenever the
	-- player holds any of the other five.)
	local function refreshGunIcon()
		if not TOD_GLYPHS then self.gun_icon:setAlpha( 0 ); return end
		self.gun_icon:setImage( RegisterImage( "i_tod_hud_gun_" .. ( curCat or "mr6" ) ) )
		self.gun_icon:setAlpha( 1 )
	end

	-- ONE RESOLVER, ONE INPUT (v17.19; it had two until viewmodelWeaponName was
	-- retired). The value is the DISPLAY name, the lane proven to work in this map
	-- — the name text beside the icon swaps correctly in game, so that model fires
	-- and its payload is real.
	--   The asset-STEM table is still consulted second, and it is honest to say
	-- that it can no longer fire in any case we have observed: nothing feeds this
	-- an asset name any more. It is kept as a nil-safe second chance for a weapon
	-- whose weaponName is not a display name, costs one call on a weapon switch,
	-- and carries the roster documentation. It is NOT load-bearing and no claim
	-- below should be read as saying it is.
	-- [tod v19.63] Assigned below, once paintClip / paintStock exist: repaints
	-- both ammo cells from the live models after the category resolves.
	local repaintAmmo = nil

	local function todApplyWeapon( raw, src )
		if raw == nil or raw == "" then return nil end
		local cat

		-- THE WEAPON'S IDENTITY IS RECORDED EVEN WHEN ITS CATEGORY IS NOT (v17.21).
		-- curWeapon is what the clip lane keys its learned magazine on, and it used
		-- to be written only on the success path below. That made the LOW-AMMO
		-- FLASH read as an absolute round count instead of a fraction of the
		-- magazine (user 2026-09-04: "i thnk the trigger is volume and not
		-- percentage of clip left"), because clipMax never reset between weapons:
		-- it climbed to the largest magazine held all run and stayed there. Hold an
		-- HK21 once and the threshold is 25% of ITS clip forever, so every pistol,
		-- shotgun and blade after it sits permanently under the threshold and
		-- flashes red on a full magazine. Before v17.19 this was total — curWeapon
		-- was never written at all, so the whole run shared one magazine figure.
		-- The icon still needs a resolved category; the clip only needs to know
		-- that the weapon CHANGED, so that is tracked separately and unconditionally.
		curWeapon = raw

		local disp = Engine.Localize( raw )
		if type( disp ) ~= "string" then disp = tostring( disp ) end
		disp = string.upper( string.gsub( disp, "%^%d", "" ) )
		cat = TodCategoryFromName( disp )

		if cat == nil then cat = TodWeaponCategory( raw ) end
		if cat == nil then return nil end     -- keep the last good icon, not a wrong one

		curCat    = cat
		curSrc    = src or "?"
		noMag     = TOD_NO_MAG[ cat ] == true
		refreshGunIcon()
		-- [tod v19.63] THE BAT READ "0 / 0" AFTER A SIDEARM SWAP (lead tester
		-- Nikolai, screenshot). The clip and reserve models publish BEFORE the
		-- weapon name on a switch, so both cells painted the new weapon's zero
		-- while noMag still described the sidearm, and nothing repainted them
		-- once the category said "bat". Repaint now that it does.
		if repaintAmmo then repaintAmmo() end
		return cat
	end

	-- ONE SUBSCRIPTION, ON THE ELEMENT THAT PROVABLY GETS ONE (v17.19).
	--
	-- v17.13 hung TWO subscriptions on self.gun_icon -- weaponName first,
	-- viewmodelWeaponName second -- and changed nothing the player could see.
	-- User, after playing v17.14: the icon still sat on the pistol through a
	-- MAC-10 and a Bulldog while the NAME beside it swapped correctly. That the
	-- symptom did not move AT ALL is the tell, because the two builds resolve the
	-- category from completely different tables.
	--
	-- WHAT IS RULED OUT, and by what: RegisterImage is not the suspect -- the
	-- pistol the player is looking at is registered by the very same line in
	-- refreshGunIcon() that would register i_tod_hud_gun_smg, and all 14 glyphs
	-- have a zone line and a converted .iwi. TOD_NAME_CAT is not the suspect --
	-- "MAC-10" and "BULLDOG" are both in it. The weaponName model is not the
	-- suspect -- the name text renders from it and swaps. The only thing left
	-- between a live model and a working readout is the DELIVERY, and the icon's
	-- delivery is the one thing in this file that is shaped differently from
	-- every lane that works: it was the only element carrying two subscriptions.
	--
	-- So this stops adding subscriptions. The weapon-name handler below now sets
	-- the name AND the icon from the SAME callback, on the SAME element, from the
	-- SAME model -- the exact shape of every readout on this panel that works.
	-- The icon can no longer be more broken than the name: if the name moves, the
	-- icon moved with it, by construction rather than by argument.
	--
	-- viewmodelWeaponName IS RETIRED, WHOLE (subscription, feed helper and the
	-- claims made for it). It never produced a match here across v17.9 -> v17.14,
	-- it is the one model an adversarial pass flagged as unproven before any of
	-- this shipped, and a second writer to one readout can only ever take the
	-- icon somewhere the proven lane did not.
	refreshGunIcon()

	-- ---- weapon name ----------------------------------------------------
	-- NO SWAP ANIMATION. The old fade/slide fired on every weapon-name change,
	-- and this map changes weapons far more than the kit assumed: a grenade
	-- throw toggles it twice, a perk drink twice per buy (this map sells nine),
	-- and the give-before-take PaP makes ONE ceremony several changes — a tier
	-- promotion flickered the panel four times. It also cost two never-closed
	-- repeating UITimers, which were a documented state-pool leak here.
	--
	-- THE NAME IS SET IN THE CUSTOM TYPEFACE, with two rules the display names
	-- in source_data/tod_weapon_twins.gdt actually require:
	--
	--   ^n COLOUR CODES ARE STRIPPED. One name ships as "^3Face Hammer^7". Those
	--   are engine colour escapes; passed through they would be laid out as the
	--   literal glyphs 3 and 7.
	--
	--   "&" EXPANDS TO " AND ". The delivered ampersand cell reads as an "8" at
	--   every size it is drawn — "DEATH & TAXES" came out "DEATH 8 TAXES" — so
	--   it was left out of the slice entirely and the two names that use one
	--   (that, and "Voice of Justice & Raging Judge") spell the word instead.
	--   Remove this when a corrected letters sheet lands; the skip note in
	--   tools/slice_hud_sheets.js is the other half.
	--
	-- AUTO-FIT. Names run from "MP5" to 31 characters, and 31 glyphs in a 248
	-- canvas-px band is a size where a scaled bitmap loses to a hinted TTF. So
	-- measure, shrink to fit down to a floor, and hand anything still too wide
	-- to the TTF element. Short names — most of them, and every base-tier one —
	-- get the full-size custom face.
	-- THE FITTING LADDER (v17.24 — user: "many guns dont fit. We should think
	-- about the naming ... Long names we can make smaller and wrap").
	--
	-- Names run from "MP5" to 33 characters. The old code had ONE lever, shrink,
	-- and it took a 31-character name down to cap ~9 in a band designed for 17 —
	-- half size, on one line, which is the least readable arrangement of both
	-- dimensions. Wrapping buys back most of it: split in half and each line is
	-- ~17 characters, which fits the 248px width with room to spare, so the only
	-- binding constraint becomes HEIGHT, and two lines fit the band at cap 11.
	-- Net for the worst name: cap 9 x 31 chars -> cap 11 x ~17 chars per line.
	--
	-- The ladder prefers ONE line while it stays readable, because a single line
	-- at cap 14 beats two at cap 11. NAME_SINGLE_MIN is where that flips.
	--   1. one line at full size            (w fits)
	--   2. one line shrunk                  (needed cap >= NAME_SINGLE_MIN)
	--   3. TWO lines at NAME_TWO_CAP        (shrunk further only if a half is wide)
	--   4. one line shrunk to the floor     (single-word name: nothing to split)
	--   5. the TTF element                  (a glyph we do not have)
	--
	-- GEOMETRY. The band is y604..630, 26 canvas px. At cap 11 a cell is 13.8px
	-- tall (ch 112 x cap/89), so two stacked at baselines 615 and 629 is 27.6px
	-- of CELL — the 2px over the top is the transparent padding above the cap
	-- line, not ink. Raising NAME_TWO_CAP puts real glyph into the panel edge.
	local NAME_MIN_SCALE  = 0.45   -- single-line floor before the TTF fallback
	local NAME_SINGLE_MIN = 13     -- below this, wrapping beats shrinking
	local NAME_TWO_CAP    = 11
	local NAME_TWO_BASE1  = 615
	local NAME_TWO_BASE2  = 629

	local function todNameOneLine( str, cap )
		self.name_row2.hide()
		self.name_row.set( str, cap, NAME_R, NAME_BASE, todNameSet )
		self.weapon_name:setAlpha( 0 )
	end

	local function setWeaponName( raw )
		if raw ~= nil then self.todWeaponName = raw end
		local s = self.todStaffName or Engine.Localize( self.todWeaponName or "" )
		if type( s ) ~= "string" then s = tostring( s ) end
		s = string.gsub( s, "%^%d", "" )        -- engine colour escapes
		s = string.gsub( s, "%s*&%s*", " AND " )
		s = string.upper( s )
		-- SANITISE TO THE SET WE CAN DRAW (v17.25). Anything outside the glyph
		-- sheets is dropped here so the BOUNDED lane can always take the string.
		--
		-- WHY THIS IS NOT COSMETIC. A Workshop player's photo (2026-09-04) shows
		-- "PSYCHOTROPIC THUNDER" broken across two lines with "THUNDER" sitting ON
		-- TOP of the clip and reserve numerals. That is NOT the glyph rows — those
		-- place every character at a computed position and cannot wrap. It is the
		-- self.weapon_name TTF element below, a real LUI.UIText that re-flows its
		-- own text and spills BELOW its box, and the root sets useStencil false so
		-- nothing clips it. That element is the only unbounded thing on this panel.
		--
		-- Today no name can reach it: all 82 display names (the twins GDT plus the
		-- TOD_NAME_CAT extras) use only A-Z 0-9 space ' . + - /, every one of which
		-- has a cell, so measure() never fails. But "no CURRENT name reaches it" is
		-- a fact about today's roster, not a guarantee — one new gun with a "(" or
		-- a "!" in its displayName would put the overflow straight back on screen.
		-- Stripping to the drawable set makes the glyph lane always succeed, which
		-- is what actually closes the hole.
		s = string.gsub( s, "[^A-Z0-9 '%.%+%-/]", "" )
		s = string.gsub( s, "%s+", " " )
		s = string.gsub( s, "^%s+", "" )
		s = string.gsub( s, "%s+$", "" )

		-- THE PROBE. See TOD_HUD_DEBUG at the top of this file. Off, this is one
		-- comparison per weapon switch and the band reads exactly as it shipped.
		-- Reports the LIVE icon state, not this lane's return value — the OTHER
		-- model may be the one that resolved. "SMG V" = the viewmodel lane won,
		-- "SMG N" = the name lane, "NIL -" = neither ever has.
		if TOD_HUD_DEBUG then s = s .. " " .. string.upper( curCat or "NIL" ) .. " " .. curSrc end

		if TOD_GLYPHS then
			local w = self.name_row.measure( s, NAME_CAP, todNameSet )
			if w >= 0 then
				-- 1. one line, full size
				if w <= NAME_MAXW then
					todNameOneLine( s, NAME_CAP )
					return
				end

				local cap = NAME_CAP * ( NAME_MAXW / w )

				-- 2. one line, shrunk, while it is still comfortably readable
				if cap >= NAME_SINGLE_MIN then
					todNameOneLine( s, cap )
					return
				end

				-- 3. two lines. Both halves take the SAME cap — a split name with one
				-- line larger than the other reads as two unrelated labels — so the
				-- WIDER half sets the size for both.
				local l1, l2 = todSplitTwo( s )
				if l1 ~= nil then
					local w1 = self.name_row.measure( l1, NAME_TWO_CAP, todNameSet )
					local w2 = self.name_row2.measure( l2, NAME_TWO_CAP, todNameSet )
					if w1 >= 0 and w2 >= 0 then
						local wide = ( w1 > w2 ) and w1 or w2
						local c2 = NAME_TWO_CAP
						if wide > NAME_MAXW then c2 = NAME_TWO_CAP * ( NAME_MAXW / wide ) end
						self.name_row.set( l1, c2, NAME_R, NAME_TWO_BASE1, todNameSet )
						self.name_row2.set( l2, c2, NAME_R, NAME_TWO_BASE2, todNameSet )
						self.weapon_name:setAlpha( 0 )
						return
					end
				end

				-- 4. nothing to split on: shrink to the floor rather than drop to TTF
				if cap >= NAME_CAP * NAME_MIN_SCALE then
					todNameOneLine( s, cap )
					return
				end
			end
		end
		-- 5. THE UNBOUNDED LAST RESORT, now unreachable by construction: the
		-- sanitise above guarantees every character has a cell, so measure() cannot
		-- fail, and steps 3 and 4 shrink to fit rather than give up. Kept because a
		-- blank readout is worse than an ugly one if some path ever gets here —
		-- but NEVER promote this above the glyph rows: it re-flows its own text and
		-- spills out of the band onto the numerals (see the note in setWeaponName).
		self.name_row.hide()
		self.name_row2.hide()
		self.weapon_name:setText( s )
		self.weapon_name:setAlpha( 1 )
	end

	-- BOTH MODELS FEED THE ICON — viewmodelWeaponName RESTORED (v17.23).
	--
	-- v17.19 retired it on two arguments and BOTH were wrong. Map 1 was read
	-- properly this time (fresh-eyes pass, 2026-09-04) and it says the opposite:
	--
	--  1. "an element can only carry one subscription" — REFUTED. Map 1's own
	--     AetheriumLoadout hangs THREE on its root (the shield slot,
	--     :664-666) and AetheriumPlayerInfo hangs SEVEN, all shipped and working.
	--     The double subscription here was never the fault.
	--  2. "map 1 subscribes currentWeapon.weapon and DISCARDS the value, so the
	--     payload is not to be trusted" — that CONFLATES THREE MODELS. The line
	--     cited (acc_hud.lua:1515) is currentWeapon.WEAPON, in a different
	--     widget, used as a weapon-changed pulse to reset an ammo baseline. Map
	--     1's ICON rides currentWeapon.VIEWMODELWEAPONNAME and USES the value.
	--
	-- And that value is the best-evidenced fact in this whole saga. Map 1's
	-- GetWeaponIcon does an EXACT key match on lowercase asset codenames with no
	-- lowercasing and no display-name path at all, so anything it renders proves
	-- the payload. Two live in-game observations recorded in map 1's CHANGELOG:
	-- the Grav drew a WHITE BOX (an image registered but not packed — a table
	-- MISS would have drawn blacktransparent, i.e. nothing), and the icon "went
	-- blank mid-run even for mapped guns" until strips were added for the
	-- _acc_*/_rdw/_fast%d suffixes, which exist only in ASSET names.
	--
	-- So: viewmodelWeaponName carries a lowercase ASSET CODENAME, and this map
	-- threw away the one input anybody has evidence for. It is back, as a SECOND
	-- feed, and the asset-stem table it needs (TOD_GUN_CAT) is live again rather
	-- than the dead second chance the v17.21 comment admitted it had become.
	-- Neither lane can clobber the other into a WRONG icon: an unresolvable
	-- value returns nil and keeps the last good state.
	local function todOnWeapon( raw )
		todApplyWeapon( raw, "N" )
		setWeaponName( raw )
	end

	local weaponNameModel = model( "currentWeapon.weaponName" )
	self.weapon_name:subscribeToModel( weaponNameModel, function ( m )
		todOnWeapon( Engine.GetModelValue( m ) )
	end )

	-- AND PAINT IT ONCE, NOW. Map 1 paid for this line and the v17.9 rewrite
	-- dropped it for the name: "the model is often set BEFORE this menu exists
	-- (the STARTING weapon), and the subscription alone never re-fires for a
	-- pre-existing value." The HUD menu is rebuilt on every death->spectate
	-- transition, so "before this menu exists" is every single life, not just the
	-- first -- and the weapon it misses is the spawn MR6, which is exactly the
	-- weapon whose category was missing from TOD_NAME_CAT until v17.19.
	if weaponNameModel ~= nil then
		todOnWeapon( Engine.GetModelValue( weaponNameModel ) )
	end

	-- THE ICON'S SECOND FEED. Its own element and its own model, subscribed and
	-- painted once, exactly the shape map 1 ships. It never touches the NAME:
	-- Engine.Localize of an asset codename is the codename, so routing this into
	-- setWeaponName would put "T9_MAC10_ZM" on screen where "MAC-10" belongs.
	local viewModel = model( "currentWeapon.viewmodelWeaponName" )
	if viewModel ~= nil then
		self.gun_icon:subscribeToModel( viewModel, function ( m )
			todApplyWeapon( Engine.GetModelValue( m ), "V" )
		end )
		todApplyWeapon( Engine.GetModelValue( viewModel ), "V" )
	end

	-- ---- clip -----------------------------------------------------------
	local lowAmmoFlashing = false

	-- [tod v19.76] THE OFF HAND'S CLIP (see paintClip's dual-wield note). Declared
	-- ABOVE paintClip on purpose: a closure written before its `local` binds a nil
	-- global (the v19.46 pip lesson). nil = not dual-wield (-1) or no such model.
	local dwModel = model( "currentWeapon.ammoInDWClip" )
	local function todDwClip()
		if dwModel == nil then return nil end
		local v = tonumber( Engine.GetModelValue( dwModel ) )
		if v == nil or v < 0 then return nil end
		return math.floor( v )
	end

	-- CLIP SIZE IS LEARNED, NOT ASKED FOR (v15 item 6). "currentWeapon.maxAmmoInClip"
	-- does not answer here, and the old `or 30` fallback made EVERY weapon's
	-- threshold max(3,7)=7 — so any gun with a magazine of 7 or fewer flashed red
	-- while completely full ("Death & Taxes", the PaP'd MR6, is exactly that).
	-- Track the largest clip ever seen for the CURRENT weapon instead. Every way
	-- that can be wrong is wrong in the SAFE direction: an under-estimate yields
	-- a lower threshold and therefore fewer false reds, never more. Deliberately
	-- NOT max(engineValue, runningMax) — taking the larger reinstates the bug.
	-- THE LOW-AMMO PULSE IS ONE TIMER, CREATED ONCE. The old code built a fresh
	-- repeating UITimer and re-registered a handler on every weapon-name change,
	-- and that was a documented state-pool leak in this very file. A single
	-- always-on 200 ms tick that does nothing unless `lowAmmoFlashing` costs five
	-- no-op calls a second and cannot leak. It also tints a ROW of four glyph
	-- images rather than one text element, which an element animation cannot do.
	local pulseOn = false
	self.clipPulse = LUI.UITimer.new( 200, "tod_clip_pulse" )
	self:addElement( self.clipPulse )
	self:registerEventHandler( "tod_clip_pulse", function ()
		if not lowAmmoFlashing then return end
		pulseOn = not pulseOn
		if pulseOn then self.clip_row.setRGB( 1, 0.16, 0.16 )
		else self.clip_row.setRGB( 1, 1, 1 ) end
	end )

	local function stopPulse()
		if lowAmmoFlashing then
			lowAmmoFlashing = false
			pulseOn = false
			self.clip_row.setRGB( 1, 1, 1 )
		end
	end

	-- A NAMED PAINTER (2026-09-24) so the downed-mage state can repaint it on
	-- entry: while the mana bar owned the cells this returned early, so the down
	-- pistol's clip was never drawn, and nothing re-fires it until the next shot.
	local function paintClip( m )
		-- [tod v18.42] THE MAGE HAS NO AMMUNITION. Its staffs still publish a
		-- clip, so without this the count would draw straight over the mana bar.
		-- stopPulse as well: a low-ammo flash left running would strobe a hidden
		-- row for the rest of the life.
		if manaOn and not manaDowned then
			stopPulse()
			self.clip_row.hide()
			return
		end
		-- [tod v19.63] A STAFF IN SOMEONE ELSE'S HANDS (lead tester Nikolai:
		-- "when spectating the mage it shows 999 ammo, instead of the bar"). A
		-- spectator's HUD follows the watched player's weapon models, but the
		-- mana state is the spectator's OWN class - so a non-mage watching a
		-- mage saw the staff's 999-round clip. A staff has no ammunition for
		-- anyone: both cells go dark whenever the held weapon is a staff.
		if TOD_STAFF_CAT[ curCat ] == true then
			stopPulse()
			self.clip_row.hide()
			return
		end
		local ammoInClip = Engine.GetModelValue( m )
		if ammoInClip == nil then return end

		-- A weapon with no magazine at all shows a dash. In Lua 0 is truthy, so
		-- without this a SLASHER — a blade at all three tiers, a quarter of the
		-- roster — reads a literal "0" as the biggest element on the panel for
		-- the whole run. Map 1 shipped the same fix (acc_hud.lua:1484-1494).
		if noMag then
			stopPulse()
			setClipText( TOD_NO_MAG_TEXT )
			return
		end

		-- [tod v19.76] DUAL WIELD: ONE NUMBER, BOTH HANDS (lead tester Nikolai,
		-- Oct 2026: "it only decreases the ammo in the mag for the right gun but
		-- when you shoot the left gun it does not decrease the ammo in current mag
		-- only for the right side ... happens to death and taxes ... Tokyo and
		-- Rose"). THE COSTING BELOW WAS WRONG ABOUT ONE THING: the engine DOES
		-- publish the off hand. currentWeapon.ammoInDWClip carries the left
		-- hand's clip, -1 when the held weapon is not dual-wield - the community
		-- T7 HUDs read it straight off this controller model (tmp/mage_key_overlay/
		-- T7LuaRepo .../T6AmmoInfo.lua: `ammoInDWClip .. " | " .. ammoInClip`). So
		-- no wire is needed, and the number is now the REAL total: right + left,
		-- falling as either gun fires. Still ONE number, the user's call (v17.21).
		-- ammoInClip is the RIGHT hand (the tester's report: left shots never moved
		-- it), so the old `* 2` was frozen on every left-hand shot, and Death and
		-- Taxes - the map's down pistol, a pair it never listed in TOD_AKIMBO - read
		-- one hand's clip and stopped counting on the other.
		-- The `* 2` stays as the FALLBACK, for the two listed pairs only, if this
		-- engine build has no such model (dwModel nil) - never a third behaviour.
		-- With the model, it alone decides: -1 is a single gun, whatever curCat says
		-- (curCat keeps the LAST resolved category when a name does not resolve,
		-- so it can still say "akimbo" for a pistol). Without it, the old doubling.
		local shown = ammoInClip
		local pair = false
		if dwModel ~= nil then
			local dw = todDwClip()
			if dw ~= nil then
				shown = ammoInClip + dw
				pair = true
			end
		elseif TOD_AKIMBO[ curCat ] == true then
			shown = ammoInClip * 2
			pair = true
		end

		-- Re-learn the magazine on a weapon change AND when the pair state flips
		-- (review, v19.76): the models of a switch land in no promised order, so a
		-- single gun's first paint can still see the pair's old left hand - and
		-- that sum, learned here, would hold the low-ammo threshold too high for
		-- as long as the single gun is held (it would flash red early).
		if curWeapon ~= clipWeapon or pair ~= clipPair then
			clipWeapon = curWeapon
			clipPair = pair
			clipMax = 0
		end
		-- learned in the SAME units the number is drawn in (the shown total)
		if shown > clipMax then clipMax = shown end

		-- HISTORY (v17.21 - v19.75): "ONE NUMBER, DOUBLED". SUPERSEDED in v19.76 by
		-- the off-hand model above; the ONE-NUMBER half of it still stands. The
		-- "8/8" split was built in v17.21 and
		-- REVERTED THE SAME BUILD, by the user, on the correct grounds — "there is no
		-- poimt if they are not indpeendent guns".
		--
		-- THE OLD COSTING (its premise, "the left hand ... no subscription", was
		-- wrong - ammoInDWClip is that subscription). The engine
		-- publishes ONE clip on currentWeapon.ammoInClip: the hand the player fires.
		-- The left hand is a separate weapon object with no subscription here, so a
		-- split display would have drawn the SAME number twice — two 8s that are one
		-- reading wearing a disguise, and worse than the honest 16 because it would
		-- keep reading 8/8 if the hands ever did diverge.
		--
		-- Carrying a real second value would need a wire, and there is none spare.
		-- _tod_upgrade_ui.gsc's own count (from the tree, 2026-08-30): 16 fields /
		-- 60 bits against the PROVEN-BOOTED ceiling of 18 / 61 — ONE bit left, and a
		-- clip needs five to eight. The only dead field, todMagBonus, is 1 bit. So
		-- the bits would have to come out of a SHIPPED feature (todDmgNum is 14 —
		-- the damage numbers), to buy a cosmetic. Overflowing it is not a degraded
		-- readout, it is Com_ERROR "clientuimodel is out of space" and a map load
		-- that aborts to the lobby. The LuiNotifyEvent lane is the documented
		-- alternative, and a per-shot notify for a HUD number is not what it is for.
		-- A second unknown sits behind the first: whether the SERVER can even read
		-- the off-hand's clip is itself unproven, and this file has twice shipped on
		-- an unproven lane.
		--
		-- The _rdw/_ldw substring tests are still GONE, and that part stands: they
		-- read curWeapon, which has carried the DISPLAY name since v17.13, so an
		-- asset-suffix test against "Tokyo & Rose" could never match — an off switch,
		-- not a fallback. The category is the live test, reached from the two PaP
		-- display names, both of which carry "dualWield" "1".
		setClipText( tostring( shown ) )

		-- Low-ammo threshold: 25% of the LEARNED magazine, no floor. v19.76: the
		-- shown total against the learned shown total - one unit on both sides,
		-- so a pair reads low when the PAIR is low, not when one hand is.
		local lowAmmoThreshold = math.floor( clipMax * 0.25 )

		if shown > 0 and shown <= lowAmmoThreshold then
			lowAmmoFlashing = true          -- the pulse timer does the rest
		else
			stopPulse()
		end
	end
	self.clip_row.img[ 1 ]:subscribeToModel( model( "currentWeapon.ammoInClip" ), paintClip )
	-- [tod v19.76] the off hand repaints the same number. Its own element (img 2
	-- of the clip row), so no element carries two subscriptions (the v17.19 rule).
	-- A build without the model subscribes nothing and keeps the fallback.
	if dwModel ~= nil then
		self.clip_row.img[ 2 ]:subscribeToModel( dwModel, function ()
			local cm = model( "currentWeapon.ammoInClip" )
			if cm ~= nil then paintClip( cm ) end
		end )
	end

	-- ---- reserve --------------------------------------------------------
	local function paintStock( m )   -- named for the same repaint as paintClip
		if manaOn and not manaDowned then self.stock_row.hide(); return end
		if TOD_STAFF_CAT[ curCat ] == true then self.stock_row.hide(); return end   -- v19.63, see paintClip
		local ammoStock = Engine.GetModelValue( m )
		if ammoStock == nil then return end
		self.stock_row.set( noMag and TOD_NO_MAG_TEXT or tostring( ammoStock ),
			STOCK_CAP, STOCK_R, STOCK_BASE, todSetDigits )
	end
	self.stock_row.img[ 1 ]:subscribeToModel( model( "currentWeapon.ammoStock" ), paintStock )

	-- [tod v19.63] the category resolver's repaint (see todApplyWeapon).
	repaintAmmo = function ()
		local cm = model( "currentWeapon.ammoInClip" )
		if cm ~= nil then paintClip( cm ) end
		local sm = model( "currentWeapon.ammoStock" )
		if sm ~= nil then paintStock( sm ) end
	end

	-- =========================================================================
	-- THE MANA BAR (v18.42, user 2026-09-08: "a mana bar that is used in place
	-- of the ammo section").
	--
	-- The MAGE class has no ammunition — its three staffs never run out — so the
	-- clip and reserve cells are dead space for that one class. They become one
	-- horizontal bar: mint while mana FILLS (one point a second, one a kill, to
	-- a hundred), gold and DRAINING while the ARCHMAGE form it buys is running.
	--
	-- THE VALUE ARRIVES ON scriptNotify, not on a clientfield: the clientuimodel
	-- pool is at its proven 61-bit ceiling with a single bit spare, and 0..100
	-- needs seven. Overflowing it is a load that aborts to the lobby, not a
	-- degraded readout. Same lane as the tower gauge and the owned-upgrade sync.
	--
	-- THE ART LANDED v18.43 (docs/120's drop). i_tod_hud_mage_panel is the shipped
	-- weapon panel with the clip/reserve divider removed and a recessed mint-keyed
	-- trough at x416..1008, y152..264 of its 1024x296 — MEASURED off the delivered
	-- file, not taken on trust, because the fill below is positioned against those
	-- exact numbers and a trough 8 pixels out would read as a bar floating beside
	-- its own well. The MASK and RULE that made a trough out of a panel with none
	-- are now dead weight and draw at alpha 0; they are kept, not deleted, because
	-- they are the fallback if the panel art ever has to be pulled.
	-- =========================================================================

	local MANA_L, MANA_R = 1104 + HUD_DX, 1250 + HUD_DX
	local MANA_T, MANA_B = 644, 668

	-- 1. THE MASK — covers the shipped panel's clip/reserve divider, which would
	--    otherwise stand in the middle of the bar. Hidden once the art lands.
	self.mana_mask = LUI.UIImage.new()
	self.mana_mask:setLeftRight( true, false, 1102 + HUD_DX, 1254 + HUD_DX )
	self.mana_mask:setTopBottom( true, false, 636, 676 )
	self.mana_mask:setImage( RegisterImage( TOD_SLAB ) )
	self.mana_mask:setRGB( SLAB_R, SLAB_G, SLAB_B )
	self.mana_mask:setAlpha( 0 )
	self:addElement( self.mana_mask )

	-- 2. THE TRACK — the empty well, so a bar at zero still reads as a bar.
	self.mana_track = LUI.UIImage.new()
	self.mana_track:setLeftRight( true, false, MANA_L, MANA_R )
	self.mana_track:setTopBottom( true, false, MANA_T, MANA_B )
	self.mana_track:setImage( RegisterImage( TOD_SLAB ) )
	self.mana_track:setRGB( 0.03, 0.05, 0.09 )
	self.mana_track:setAlpha( 0 )
	self:addElement( self.mana_track )

	-- 3. THE FILL — wipe-clipped left to right on uie_wipe_normal, the same
	--    material and the same four shader vectors the player health bar uses.
	--    Vector 0's x IS the fraction; nothing else moves.
	self.mana_fill = LUI.UIImage.new()
	self.mana_fill:setLeftRight( true, false, MANA_L, MANA_R )
	self.mana_fill:setTopBottom( true, false, MANA_T, MANA_B )
	self.mana_fill:setImage( RegisterImage( TOD_SLAB ) )
	self.mana_fill:setRGB( 0.35, 1.0, 0.80 )
	self.mana_fill:setMaterial( LUI.UIImage.GetCachedMaterial( "uie_wipe_normal" ) )
	self.mana_fill:setShaderVector( 0, 0, 0, 0, 0 )
	self.mana_fill:setShaderVector( 1, 0, 0, 0, 0 )
	self.mana_fill:setShaderVector( 2, 1, 0, 0, 0 )
	self.mana_fill:setShaderVector( 3, 0, 0, 0, 0 )
	self.mana_fill:setAlpha( 0 )
	self:addElement( self.mana_fill )

	-- 4. THE RULE — a bright hairline under the bar in the bar's own colour, so
	--    the state reads even at zero. Drops out with the mask.
	self.mana_rule = LUI.UIImage.new()
	self.mana_rule:setLeftRight( true, false, MANA_L, MANA_R )
	self.mana_rule:setTopBottom( true, false, MANA_B + 1, MANA_B + 3 )
	self.mana_rule:setImage( RegisterImage( TOD_SLAB ) )
	self.mana_rule:setRGB( 0.35, 1.0, 0.80 )
	self.mana_rule:setAlpha( 0 )
	self:addElement( self.mana_rule )

	-- REGISTERED ONCE, UP FRONT — the same rule the PaP badge's three glyphs
	-- follow. RegisterImage inside setMana would re-register on every push, and
	-- this one is called four times a second.
	local PANEL_STOCK = RegisterImage( TOD_GLYPHS and "i_tod_hud_weapon_panel" or TOD_SLAB )
	local PANEL_MAGE  = RegisterImage( "i_tod_hud_mage_panel" )
	local FILL_MANA   = RegisterImage( "i_tod_hud_mana_fill" )
	local FILL_ARCH   = RegisterImage( "i_tod_hud_mana_arch" )
	local OFF_HEAL    = RegisterImage( "i_tod_hud_off_heal" )
	local OFF_BLINK   = RegisterImage( "i_tod_hud_off_blink" )
	local OFF_FRAG    = RegisterImage( TOD_GLYPHS and "i_tod_hud_off_frag" or "i_mtl_sat_ui_icon_lethal_grenade_frag" )
	local OFF_MONKEY  = RegisterImage( TOD_GLYPHS and "i_tod_hud_off_monkey" or "i_mtl_sat_ui_icon_zm_support_cymball_monkey" )

	-- THE TWO ABILITY TILES (v18.43). The mage has no grenades at all — the
	-- server calls DisableOffhandWeapons on it — so both slots would sit empty
	-- for the one class that has the most to put in them. They become HEALING
	-- AURA (lethal) and BLINK (tactical), which is exactly what those two
	-- buttons do for a mage.
	--
	-- EDGE-TRIGGERED on mageIcons, not set every push: setImage is not free and
	-- the mana bar pushes four times a second.
	-- =========================================================================
	-- Tutorial key, retired independently after three successful casts. It sat
	-- OVER the whole tile from v19.15 (user: "The key should overlay the ENTIRE
	-- ability"); v19.76 moved it to a plate ABOVE the tile on the lead tester's
	-- report that it hid which ability each button was, and the user's review
	-- the same day put it back over the tile with a see-through plate (see THE
	-- BADGE SITS ABOVE THE TILE below - superseded there).
	-- Native probe 2026-09-16: Localize("[{+frag}]") returns bytes 21 + the
	-- UNEXPANDED token + 20. Expansion happens when UIText renders. Never trim
	-- that value: the previous first-byte renderer displayed invisible byte 21.
	local TUT_USES = 3   -- LOCKSTEP with TOD_MAGE_TUT_USES in _tod_mage_elements.gsc
	local tutUses  = { heal = 0, blink = 0 }

	-- Keyboard: resolve the binding before glyph layout, then keep one key.
	-- Controller: pass the whole token to UIText for the engine's button art.
	-- LastInput_Gamepad is the stock live-device reader, not the d-pad latch.
	local function TutKey( token )
		if Engine.LastInput_Gamepad( controller ) then
			return Engine.Localize( token ), true
		end
		local command = string.match( token, "%[%{(.-)%}%]" )
		local raw = Engine.GetKeyBindingLocalizedString( controller, command, 0, false, false ) or ""
		-- Some engine paths still return a deferred token. Preserve it whole;
		-- uppercasing or trimming its command prevents native expansion.
		if string.find( raw, "[{", 1, true ) then
			return Engine.Localize( token ), true
		end
		raw = string.gsub( raw, "%^%d", "" )
		raw = string.gsub( raw, "[%c]", "" )
		local separator = string.find( raw, "%s+[Oo][Rr]%s+" )
		if separator then raw = string.sub( raw, 1, separator - 1 ) end
		raw = string.gsub( raw, "^%s+", "" )
		raw = string.gsub( raw, "%s+$", "" )
		return string.upper( raw ), false
	end

	-- THE BADGE SITS ABOVE THE TILE (v19.76; it WAS the whole tile, x0..x0+46,
	-- y568..600). Lead tester Nikolai, Oct 2026: "once fully charged, the
	-- controller button prompts (LB and RB) completely cover the icons. This
	-- leaves players with no visual cue for what button does what" - the plate
	-- (0.8 black) and the key were drawn OVER the ability icon, so a new Mage saw
	-- "LB" and "RB" and never which ability each one was. The key now sits on its
	-- own small plate directly above its tile (y549..566, the band is empty on
	-- this canvas: the powerup tray and banner are centre-screen), and the icon
	-- underneath stays lit: the pair reads "this button -> this ability".
	-- SUPERSEDED THE SAME DAY (user, on the review: the v19.15 order stands - "keep
	-- it over the whole tile, but make the backing see-through so the ability
	-- icon still shows underneath" -> "Yes"). The key is back OVER THE WHOLE TILE
	-- at its v19.15 size, and the plate behind it is a 35% wash instead of 80%
	-- black (BADGE_PLATE_ALPHA), so the ability icon reads through it: the
	-- tester's complaint was the icon VANISHING under the plate, not the key's
	-- position.
	local BADGE_CAP = 20         -- one character on the 32-unit tile (v19.15)
	local BADGE_MID = 584        -- the tile's vertical centre (568..600)
	local BADGE_PLATE_ALPHA = 0.35

	local function paintBadge( slot, token, show )
		if not slot.keyRow then
			return
		end
		local function blank()
			slot.keyPlate:setAlpha( 0 )
			slot.keyText:setAlpha( 0 )
			slot.keyRow.hide()
		end
		if not show then
			if slot.keySignature == false then return end
			slot.keySignature = false
			blank()
			return
		end
		local s, pad = TutKey( token )
		if s == "" then s = "?" end
		-- Replayed mana/charge updates must not repaint an unchanged badge.
		local signature = tostring( pad ) .. ":" .. s
		if slot.keySignature == signature then return end
		slot.keySignature = signature
		local cap = BADGE_CAP
		local w = not pad and slot.keyRow.measure( s, cap, todNameSet ) or -1
		if w > 40 then
			cap = cap * 40 / w
			w = slot.keyRow.measure( s, cap, todNameSet )
		end
		if w > 0 and #s <= slot.keyRow.n then
			slot.keyRow.set( s, cap, slot.keyMidX + w / 2, BADGE_MID + cap / 2, todNameSet )
			slot.keyText:setAlpha( 0 )
		else
			slot.keyRow.hide()
			slot.keyText:setText( s )
			slot.keyText:setAlpha( 1 )
		end

		slot.keyPlate:setAlpha( BADGE_PLATE_ALPHA )
	end

	-- The server sends usable charges (zero during Healing Aura's active lock).
	-- Positive charges also prove ownership; a locked Mage tile sends zero.
	local function ready( slot )
		return slot.everHad == true and ( slot.charges or 0 ) > 0
	end

	-- v19.16 — WHY A BADGE IS NOT ON SCREEN, answerable from a log instead of from
	-- a screenshot. A hidden badge has FOUR possible reasons and they look
	-- identical on screen: not a mage, the card not taken, no charge left, or the
	-- ability already learned. This prints the state ONLY when it changes, on the
	-- stock LUI developer channel (the lane [TOD_PERK_PRICE] already uses).
	local smashState, smashUses, smashMode = 0, 0, false
	local paintSmash
	local tutLog = nil
	local function refreshTut()
		local on = manaOn
		local bShow = ( on and ready( self.tactical ) and tutUses.blink < TUT_USES )
			or ( smashMode and smashState == 2 and smashUses < TUT_USES )
		local hShow = on and ready( self.lethal )   and tutUses.heal  < TUT_USES
		paintBadge( self.tactical, "[{+smoke}]", bShow )
		paintBadge( self.lethal,   "[{+frag}]",  hShow )

		local sig = tostring( on ) .. ":" .. tostring( bShow ) .. tostring( hShow )
			.. " blink=" .. tostring( self.tactical.everHad ) .. "/" .. tostring( self.tactical.charges )
			.. "/" .. tostring( tutUses.blink )
			.. " heal=" .. tostring( self.lethal.everHad ) .. "/" .. tostring( self.lethal.charges )
			.. "/" .. tostring( tutUses.heal )
		if tutLog ~= sig then
			tutLog = sig
			if DebugPrint then
				DebugPrint( "[TOD_MAGE_TUT] rev=resolved_bind mage=" .. tostring( on )
					.. " show(blink,heal)=" .. tostring( bShow ) .. "," .. tostring( hShow )
					.. " owned/charges/uses blink=" .. tostring( self.tactical.everHad )
					.. "/" .. tostring( self.tactical.charges ) .. "/" .. tostring( tutUses.blink )
					.. " heal=" .. tostring( self.lethal.everHad )
					.. "/" .. tostring( self.lethal.charges ) .. "/" .. tostring( tutUses.heal ) )
			end
		end
	end

	local mageIcons = nil
	local refreshLethalIcon -- also restore the live perk icon when leaving mage
	local refreshWeb        -- 2026-10-01: the Mage's Widow's Wine tile (assigned below hasPerk)
	local function setAbilityIcons( on )
		if mageIcons == on then return end
		mageIcons = on
		-- Class changes cannot inherit the previous class's ever-owned flags.
		self.lethal.everHad = false
		self.tactical.everHad = false
		self.lethal.setCount( 0 )
		self.tactical.setCount( 0 )
		if on then
			self.lethal.icon:setImage( OFF_HEAL )
			self.tactical.icon:setImage( OFF_BLINK )
		else
			self.lethal.icon:setImage( OFF_FRAG )
			self.tactical.icon:setImage( OFF_MONKEY )
		end
	end

	-- [tod 2026-09-09] THE FULL-BAR CUE (user: "When the bar is full we can flash
	-- text in our typography saying 'Press Aim Button'. Subtle pulse inside the
	-- full mana bar"). It REPLACES two IPrintLnBold lines the server used to
	-- throw on screen: the "ARCHMAGE" banner on activation and the "MANA n / 100"
	-- refusal. The class now says less and shows more.
	--
	-- "AIM BUTTON" is deliberately the ACTION's name and not a key name. The map's
	-- standing rule is never to write a key into a prompt (v16.29) -- but unlike
	-- LT / RMB, the word "aim" is already correct on every device, so this needs
	-- no bind lookup and cannot go stale when someone rebinds.
	--
	-- IT PULSES WITH setRGB, NOT setAlpha. TodGlyphRow has no per-row alpha, and
	-- reaching into row.img[i] would light the pool slots this string does not
	-- use -- they keep whatever glyph they last drew. Brightness reads the same
	-- and touches only the colour of what is already visible.
	local MANA_CUE = "PRESS AIM BUTTON"
	local manaCue  = todMakeGlyphRow and todMakeGlyphRow( self, 16 ) or nil

	-- ONE always-on timer, created once -- the clipPulse rule above, and for the
	-- same reason: a timer rebuilt on each state change is the state-pool leak
	-- this file already carries a scar from.
	local manaFull, cuePhase = false, 0
	self.manaPulse = LUI.UITimer.new( 120, "tod_mana_pulse" )
	self:addElement( self.manaPulse )
	self:registerEventHandler( "tod_mana_pulse", function ()
		if not manaFull then return end
		cuePhase = ( cuePhase + 1 ) % 16
		local t = cuePhase
		if t > 8 then t = 16 - t end          -- a triangle, so it BREATHES not blinks
		local k = 0.45 + ( t / 8 ) * 0.55
		if manaCue then manaCue.setRGB( 0.35 * k, 1.0 * k, 0.80 * k ) end
		-- "subtle": the bar itself only moves across the top seventh of the range
		self.mana_fill:setAlpha( 0.86 + ( t / 8 ) * 0.14 )
	end )

	local function setManaCue( on )
		if on == manaFull then return end
		manaFull = on
		if on then
			if manaCue then manaCue.set( MANA_CUE, 12, MANA_R, 694, todNameSet ) end
		else
			if manaCue then manaCue.hide() end
			self.mana_fill:setAlpha( 1 )
		end
	end

	-- ONE WRITER for every one of those four elements and for manaOn.
	-- state 0 = filling, 1 = Archmage, 2 = other class, 3 = locked empty bar,
	-- 4 = downed mage (the pistol's ammo readout; the ability tiles stay).
	local function setMana( value, state )
		-- [2026-09-24] STATE 4 — A DOWNED MAGE (lead tester: the downed pistol
		-- showed no ammo, because the bar owned these cells for ANY held weapon).
		-- The stock panel and both numbers come back; manaOn stays true so the
		-- ability tiles keep the mage's icons and never read stock grenade
		-- counts. On ENTRY the two painters run once: each returned early while
		-- the bar was up, and the down pistol's numbers may already be published.
		if state == 4 then
			local was = manaDowned
			manaOn = true
			manaDowned = true
			CoD.TodAbilityFeedback.Mode( self, true )
			setManaCue( false )
			self.panel:setImage( PANEL_STOCK )
			self.mana_mask:setAlpha( 0 )
			self.mana_track:setAlpha( 0 )
			self.mana_fill:setAlpha( 0 )
			self.mana_rule:setAlpha( 0 )
			setAbilityIcons( true )
			if not was then
				local cm = model( "currentWeapon.ammoInClip" )
				if cm ~= nil then paintClip( cm ) end
				local sm = model( "currentWeapon.ammoStock" )
				if sm ~= nil then paintStock( sm ) end
			end
			refreshTut()
			if refreshWeb then refreshWeb() end
			return
		end
		manaDowned = false
		if state == 2 then
			manaOn = false
			refreshTut()   -- v19.11: no mage, no hints
			CoD.TodAbilityFeedback.Mode( self, false )
			setManaCue( false )
			self.panel:setImage( PANEL_STOCK )
			self.mana_mask:setAlpha( 0 )
			self.mana_track:setAlpha( 0 )
			self.mana_fill:setAlpha( 0 )
			self.mana_rule:setAlpha( 0 )
			setAbilityIcons( false )
			if refreshLethalIcon then refreshLethalIcon() end
			self.lethal.setCount( Engine.GetModelValue( model( "currentPrimaryOffhand.primaryOffhandCount" ) ) )
			if not smashMode then self.tactical.setCount( Engine.GetModelValue( model( "currentSecondaryOffhand.secondaryOffhandCount" ) ) ) end
			if refreshWeb then refreshWeb() end   -- not a mage: the web tile hides (the lethal tile shows the webs)
			return
		end

		if paintSmash and smashMode then paintSmash( 0, 0, 0 ) end
		manaOn = true
		CoD.TodAbilityFeedback.Mode( self, true )
		if state == 3 then value = 0 end
		-- Hide the two numbers HERE as well as in their callbacks: a player who
		-- drafts the mage after their ammo last changed would otherwise keep the
		-- last count on screen until the next reload that never comes. stopPulse
		-- too: a revive out of state 4 can leave the down pistol's low-ammo
		-- flash running on a row that is now hidden.
		stopPulse()
		self.clip_row.hide()
		self.stock_row.hide()

		-- The panel art carries the trough, so the slab mask, track and rule all
		-- stand down. The FILL is the drawn strip, untinted: MINT while the bar
		-- climbs, GOLD while ARCHMAGE burns it back down.
		self.panel:setImage( PANEL_MAGE )
		self.mana_mask:setAlpha( 0 )
		self.mana_track:setAlpha( 0 )
		self.mana_rule:setAlpha( 0 )
		self.mana_fill:setRGB( 1, 1, 1 )
		if state == 1 then
			self.mana_fill:setImage( FILL_ARCH )
		else
			self.mana_fill:setImage( FILL_MANA )
		end

		self.mana_fill:setAlpha( 1 )
		self.mana_fill:setShaderVector( 0, value / 100, 0, 0, 0 )

		-- FULL AND NOT ALREADY SPENT: state 1 is the form running, where a full
		-- bar means "27 seconds left", not "ready".
		setManaCue( state == 0 and value >= 100 )

		-- The two ability tiles belong to the mage for as long as the bar does.
		setAbilityIcons( true )
		refreshTut()   -- v19.12: the two ability badges (ARCHMAGE keeps the mana bar's own PRESS AIM BUTTON cue)
		if refreshWeb then refreshWeb() end
	end

	-- Locked (-1) is hidden; unlocked with zero charges stays dimmed.
	local function setAbilities( charges, blinkCharges )
		if not manaOn then return end
		self.lethal.everHad = charges >= 0
		self.lethal.setCount( charges )
		self.tactical.everHad = blinkCharges >= 0
		self.tactical.setCount( blinkCharges )
		refreshTut()   -- v19.11: a tile that just unlocked gets its line
	end

	-- ONE subscription for both mage notifies. A scriptNotify subscription sees
	-- EVERY notify on this controller, so the name test comes first and costs
	-- nothing on the ones meant for someone else.

	-- =========================================================================
	-- THE TWO OFFHAND SLOTS — canvas y568..600, tiles 46 wide.
	--
	-- ⚠️ y568 is TWO canvas pixels below the tower gauge's foot (tod_upgrade.lua
	-- puts it at x1216..1268, y150..566, unscaled, in an overlay that draws ON
	-- TOP of this HUD). Nothing here may grow upward.
	--
	-- BOTH SLOTS ARE LIVE. An earlier draft of the design doc claimed the lethal
	-- could never fill, because this map has no wall buys and nothing in
	-- scripts/zm/zm_tower_of_doom/ grants a frag. That was read off the map's own
	-- scripts and it was WRONG: stock _zm.gsc:4564 award_grenades_for_survivors()
	-- GIVES the lethal and sets its clip to 2/3/4, called from round_think at
	-- _zm.gsc:4408 — outside all three round pointers _tod_endless_rounds.gsc
	-- overrides, with headshots_only set nowhere. Every survivor gets 2-4 free
	-- frags at the start of every round.
	-- =========================================================================
	local function makeOffhandSlot( x0, glyphImage )
		local slot = {}

		-- 276x192 into 46x32 canvas = aspect 1.4375 on both sides. Zero stretch.
		slot.tile = LUI.UIImage.new()
		slot.tile:setLeftRight( true, false, x0, x0 + 46 )
		slot.tile:setTopBottom( true, false, 568, 600 )
		slot.tile:setImage( RegisterImage( TOD_GLYPHS and "i_tod_hud_offhand_tile" or TOD_SLAB ) )
		slot.tile:setRGB( 1, 1, 1 )
		if not TOD_GLYPHS then slot.tile:setRGB( SLAB_R, SLAB_G, SLAB_B ) end
		self:addElement( slot.tile )

		slot.icon = LUI.UIImage.new()
		slot.icon:setLeftRight( true, false, x0 + 5, x0 + 29 )
		slot.icon:setTopBottom( true, false, 572, 596 )
		slot.icon:setImage( RegisterImage( glyphImage ) )
		slot.icon:setRGB( 1, 1, 1 )
		self:addElement( slot.icon )

		slot.count = todMakeGlyphRow( self, 2 )
		local COUNT_R, COUNT_CAP, COUNT_BASE = x0 + 43, 12, 592

		-- ONE writer for the whole slot's visibility. "count is zero" and "the
		-- player has never had one" are different states: never-had draws
		-- nothing at all, zero draws the slot at 40% so it keeps its place. That
		-- 40% is what the tile art was authored to survive — it is a real dark
		-- body and a real bright keyline for exactly this reason.
		slot.everHad = false
		slot.setCount = function ( n )
			-- v19.13 — REMEMBER THE LIVE COUNT. The key badge needs "ready", not
			-- merely "owned", and this is the only place the number is seen. Note
			-- slot.count is the GLYPH ROW, not the value, so it cannot answer this.
			slot.charges = n or 0
			if n and n > 0 then
				slot.everHad = true
				slot.tile:setAlpha( 1 )
				slot.icon:setAlpha( 1 )
				slot.count.set( tostring( n ), COUNT_CAP, COUNT_R, COUNT_BASE, todSetDigits )
			elseif slot.everHad then
				slot.tile:setAlpha( 0.40 )
				slot.icon:setAlpha( 0.40 )
				slot.count.hide()
			else
				slot.tile:setAlpha( 0 )
				slot.icon:setAlpha( 0 )
				slot.count.hide()
			end
		end
		-- Temporary glyph fallback until the requested icon is installed. Pooled.
		slot.smashMark = todMakeGlyphRow( self, 2 )
		-- The key's plate covers the whole tile (v19.15; back after the v19.76
		-- review), at BADGE_PLATE_ALPHA so the ability icon shows through it.
		slot.keyPlate = LUI.UIImage.new()
		slot.keyPlate:setLeftRight( true, false, x0, x0 + 46 )
		slot.keyPlate:setTopBottom( true, false, 568, 600 )
		slot.keyPlate:setImage( RegisterImage( TOD_SLAB ) )
		slot.keyPlate:setRGB( 0.02, 0.03, 0.05 )
		slot.keyPlate:setAlpha( 0 )
		self:addElement( slot.keyPlate )

		-- Fit a single resolved keyboard binding in the map's typeface.
		slot.keyRow  = todMakeGlyphRow( self, 12 )
		slot.keyMidX = x0 + 23
		-- Controller tokens stay whole and are expanded only by native UIText.
		slot.keyText = LUI.UIText.new()
		-- The pad-picture fallback spans the tile's full width, so a button icon
		-- has room to draw and can never wrap; 20 tall, centred on the tile (the
		-- keyboard key's size), so the icon's edges still show round it.
		slot.keyText:setLeftRight( true, false, x0, x0 + 46 )
		slot.keyText:setTopBottom( true, false, 574, 594 )
		slot.keyText:setTTF( "fonts/ltromatic.ttf" )
		slot.keyText:setScale( 1.0 )
		slot.keyText:setRGB( 1, 0.82, 0.25 )
		slot.keyText:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
		slot.keyText:setText( "" )
		slot.keyText:setAlpha( 0 )
		self:addElement( slot.keyText )

		slot.setCount( 0 )
		return slot
	end

	-- TACTICAL (left) — the cymbal monkey, DISTRACTION's carry cap 1..3.
	self.tactical = makeOffhandSlot( 1160 + HUD_DX,
		TOD_GLYPHS and "i_tod_hud_off_monkey" or "i_mtl_sat_ui_icon_zm_support_cymball_monkey" )
	-- LETHAL (right) — a frag, or Widow's Wine's web grenade.
	self.lethal   = makeOffhandSlot( 1210 + HUD_DX,
		TOD_GLYPHS and "i_tod_hud_off_frag" or "i_mtl_sat_ui_icon_lethal_grenade_frag" )
	CoD.TodAbilityFeedback.Attach( self, HUD_DX )
	-- Same tile, border and binding-aware tutorial as Mage. The number is the
	-- server's remaining seconds (not a client timer, so card pauses stay exact).
	paintSmash = function( code, percent, seconds )
		local state = ( tonumber( code ) or 0 ) % 8
		if manaOn then state = 0 end
		local was = smashMode
		if DebugPrint and state ~= smashState then
			DebugPrint( "[TOD_THUNDER_SMASH_HUD] packet=" .. tostring( code )
				.. " state=" .. tostring( state ) .. " mage=" .. tostring( manaOn )
				.. " seconds=" .. tostring( seconds ) )
		end
		smashState, smashUses = state, math.floor( ( tonumber( code ) or 0 ) / 8 )
		smashMode = state > 0
		if not smashMode then
			self.tactical.smashMark.hide()
			CoD.TodAbilityFeedback.Smash( self, -1 )
			if was and not manaOn then
				self.tactical.icon:setImage( OFF_MONKEY )
				self.tactical.everHad = false
				self.tactical.setCount( Engine.GetModelValue( model( "currentSecondaryOffhand.secondaryOffhandCount" ) ) )
			end
		else
			self.tactical.everHad = true
			local count = state == 2 and 1 or ( state == 3 and seconds or 0 )
			self.tactical.setCount( count )
			self.tactical.icon:setAlpha( 0 )
			self.tactical.smashMark.set( "SM", 11, 1189 + HUD_DX, 590, todNameSet )
			local k = ( state == 1 or state == 4 ) and 0.4 or 1
			self.tactical.smashMark.setRGB( 0.35 * k, 0.8 * k, k )
			CoD.TodAbilityFeedback.Smash( self, ( state == 3 or state == 4 ) and percent or -1 )
		end
		refreshTut()
	end

	-- =========================================================================
	-- THE PACK-A-PUNCH TIER BADGE (v17.33, user 2026-09-04: "we need to update
	-- the HUD to add some section that tells your pap level. So this includes
	-- pap I").
	--
	-- WHY IT SITS AT x1000 AND NOT BESIDE THE OFFHAND PAIR. It is a property of
	-- the GUN, and the gun bay is directly below it at x1004..1100. Butting it
	-- against the tactical tile would have grouped it with the two INVENTORY
	-- slots, which is the one thing it must not read as — three identical tiles
	-- in a row is a count, not a badge. The 114-unit gap is the separation.
	--
	-- SAME BOX AS AN OFFHAND SLOT ON PURPOSE (46x32 canvas, tile aspect
	-- 276/192 = 1.4375): the corner is one
	-- component set, and a badge that invented its own proportions would be the
	-- defect docs/95 was written to kill. It gets its own TILE art rather than
	-- reusing i_tod_hud_offhand_tile so the artist can mark it as a status
	-- plate, but the plate geometry is identical. The PaP glyph uses 26x26
	-- inside it so the delivered art reads clearly; the level lane stays clear.
	--
	-- y568 IS THE CEILING. The tower gauge's foot is at y566 (tod_upgrade.lua,
	-- an overlay that draws ON TOP of this HUD) — nothing here may grow upward.
	--
	-- TIER 0 DRAWS NOTHING AT ALL, not a dimmed plate. An unpacked gun has no
	-- pack level to report, and the offhand slots' "dim at zero" idiom means
	-- "you had these and spent them", which is a different statement.
	-- =========================================================================
	-- TOD_PAP_ART — the four i_tod_hud_pap_* images are ZONED AND PACKED, so
	-- this is on. i_tod_hud_pap_1..3 use docs/125's round-3 delivered set;
	-- i_tod_hud_pap_tile is the COMMISSIONED plate since v17.68
	-- (docs/103's drop, 2026-09-05: the offhand tile's chassis with a bold cyan
	-- rule along the top as its one difference). Nothing here is placeholder
	-- art any more; tools/gen_pap_badge_placeholder.js writes nothing without
	-- an explicit flag, so it cannot clobber these names by accident.
	--
	-- IT EXISTS AT ALL because RegisterImage on an unzoned name does not fail —
	-- it draws a WHITE SQUARE, which is the whole reason lint_tod_assets.js has
	-- a GATE A. Set it false and the badge falls back to the roman numeral in
	-- the map's own baked typeface on the flat slab, which needs no new art at
	-- all. Keep that path working; it is the escape hatch if a drop ever has to
	-- be pulled.
	local TOD_PAP_ART = true

	local PAP_X = 1000 + HUD_DX

	self.pap_tile = LUI.UIImage.new()
	self.pap_tile:setLeftRight( true, false, PAP_X, PAP_X + 46 )
	self.pap_tile:setTopBottom( true, false, 568, 600 )
	self.pap_tile:setImage( RegisterImage( ( TOD_GLYPHS and TOD_PAP_ART ) and "i_tod_hud_pap_tile" or TOD_SLAB ) )
	self.pap_tile:setRGB( 1, 1, 1 )
	if not ( TOD_GLYPHS and TOD_PAP_ART ) then self.pap_tile:setRGB( SLAB_R, SLAB_G, SLAB_B ) end
	self.pap_tile:setAlpha( 0 )
	self:addElement( self.pap_tile )

	self.pap_glyph = LUI.UIImage.new()
	self.pap_glyph:setLeftRight( true, false, PAP_X + 4, PAP_X + 30 )
	self.pap_glyph:setTopBottom( true, false, 571, 597 )
	self.pap_glyph:setRGB( 1, 1, 1 )
	self.pap_glyph:setAlpha( 0 )
	self:addElement( self.pap_glyph )

	-- REGISTERED ONCE, UP FRONT. RegisterImage inside the setter would
	-- re-register on every weapon switch; three names is a table.
	local PAP_IMG = ( TOD_GLYPHS and TOD_PAP_ART ) and {
		RegisterImage( "i_tod_hud_pap_1" ),
		RegisterImage( "i_tod_hud_pap_2" ),
		RegisterImage( "i_tod_hud_pap_3" ),
	} or nil

	-- THE LEVEL NUMBER (v17.60, docs/102 drop 2026-09-04). The art that came
	-- back is a Pack-a-Punch MACHINE glyph with 1 / 2 / 3 bolts per level — a
	-- picture, like the monkey and the grenade — so the badge now draws the way
	-- those two tiles do: picture left, count right. The count rides the
	-- offhand slot's OWN metrics (digit set, cap 12, right edge x0+43, baseline
	-- 592 — makeOffhandSlot's values, so the three numbers on the row line up).
	-- A single digit is all the 14-unit lane right of the glyph can hold;
	-- "III" in the letter set does not fit there, which is why the level is
	-- 1 / 2 / 3 beside the picture and not the roman numeral of the buy prompt.
	--
	-- With no art (TOD_PAP_ART false) the same row draws the roman numeral
	-- centred on the slab instead: "I" / "II" / "III" are LETTERS, so that lane
	-- rides the letter sheet (nameSet). Cap 3 is the widest string it holds.
	local pap_row = todMakeGlyphRow( self, 3 )
	local PAP_TXT = { "I", "II", "III" }

	local papTier = -1
	local function setPapTier( t )
		if t == papTier then return end
		papTier = t
		if t < 1 or t > 3 then
			self.pap_tile:setAlpha( 0 )
			self.pap_glyph:setAlpha( 0 )
			if pap_row then pap_row.hide() end
			return
		end
		self.pap_tile:setAlpha( 1 )
		if PAP_IMG then
			self.pap_glyph:setImage( PAP_IMG[ t ] )
			self.pap_glyph:setAlpha( 1 )
			pap_row.set( tostring( t ), 12, PAP_X + 43, 592, todSetDigits )
		else
			-- right edge PAP_X+40, baseline y592, cap 14 — the offhand count's
			-- own metrics one row over, so the two read as the same size.
			pap_row.set( PAP_TXT[ t ], 14, PAP_X + 40, 592, todNameSet )
		end
	end
	setPapTier( 0 )

	-- THE GSC FEED — _tod_gauge.gsc's 0.35s heartbeat, the same PerController
	-- scriptNotify lane the round readout and the max-HP number ride, and for
	-- the same reason: the clientuimodel pool is at 60 of its PROVEN 61 bits
	-- and a 0..3 value wants two. Change-gated at the server, re-armed per life
	-- by _tod_upgrade_ui::player_lui_life clearing tod_pap_tier_shown — this
	-- widget is rebuilt by the engine on every spawn, so without that re-arm a
	-- respawned player's badge would stay blank until they switched weapons.
	self:subscribeToGlobalModel( controller, "PerController", "scriptNotify", function ( model )
		if Engine.GetModelValue( model ) ~= "tod_pap_tier" then
			return
		end
		local d = CoD.GetScriptNotifyData( model )
		local t = d and tonumber( d[ 1 ] )
		if t == nil then
			return
		end
		setPapTier( math.floor( t ) )
		local staff = TOD_STAFF_NAME[ tonumber( d[ 2 ] ) or 0 ]
		self.todStaffName = staff and staff[ t > 0 and 2 or 1 ] or nil
		setWeaponName( self.todWeaponName )
	end )

	-- THE ICON FOLLOWS THE WEAPON, IT IS NOT HARDCODED (defect 2). The engine
	-- publishes a ready-to-register image NAME on these global models, and map 1
	-- ships exactly this lane (acc_hud.lua:1584-1592).
	--
	-- ⚠️ THE FIRST VERSION OF THIS LANE WAS DEAD CODE, and the way it was dead is
	-- worth keeping. It picked a glyph by substring-matching the value the engine
	-- publishes on these models, guessing at the patterns "frag", "grenade",
	-- "cymbal", "monkey", "widow", "web". The engine's ACTUAL vocabulary is four
	-- names, and they are in the base ZM asset list —
	-- <modtools>/zone_source/all/assetlist/zm_levelcommon.csv:6088-6091:
	--     uie_t7_zm_hud_inv_icnlthl          the lethal
	--     uie_t7_zm_hud_inv_icntact          the tactical
	--     uie_t7_zm_hud_inv_icntactlilarnie
	--     uie_t7_zm_hud_inv_widowswine
	-- Only "widow" could ever match. So the bespoke frag and monkey were set once
	-- at construction and then PERMANENTLY OVERWRITTEN by the first model
	-- callback — two commissioned images dead on arrival, and what the player saw
	-- was the kit's own icon. A guess that cannot match is not a fallback, it is
	-- an off switch.
	--
	-- THE SELECTION IS NOW STATE, NOT STRING MATCHING.
	--   tactical: always the cymbal monkey. This map has exactly ONE tactical —
	--     DISTRACTION's monkey (the octobomb was retired in v16.49) — so there is
	--     nothing to choose between.
	--   lethal:   chosen from PERK STATE, which is authoritative. Widow's Wine
	--     replaces the player's lethal with its web grenade, and PhD Flopper then
	--     makes that grenade split (_tod_perk_phd.gsc) WITHOUT changing the held
	--     weapon — so the weapon alone cannot tell the two apart, but the perks
	--     can. AetheriumPerksContainer.lua proves the read works: one model per
	--     perk under "hudItems.perks", keyed by clientFieldName.
	-- The engine value is kept as a last-resort fallback for an offhand we never
	-- anticipated. That is safe: those four names live in zm_levelcommon, the
	-- zone every ZM map loads — NOT in the DLC specialty_* family that
	-- white-squares on a published usermap.
	local perksModel = model( "hudItems.perks" )
	local function hasPerk( field )
		if perksModel == nil then return false end
		local m = Engine.GetModel( perksModel, field )
		if m == nil then return false end
		local v = Engine.GetModelValue( m )
		return v ~= nil and v > 0
	end

	-- clientFieldName, not perk name. PhD Flopper is hung on the ELECTRIC CHERRY
	-- specialty slot in this map — the specialty is not the perk, which is a
	-- documented trap here — so its field really is "electric_cherry".
	local TOD_PERK_WIDOWS = "widows_wine"
	local TOD_PERK_PHD    = "electric_cherry"

	-- The two SPIDERS landed v17.12 (docs/97). They replaced a grenade with a web
	-- drawn on it, which could not read at the 36x36 these are shown at — a
	-- spider silhouette can. The two are pixel-identical in shape and differ only
	-- in colour, verified by an alpha diff at install (0.00% of pixels), because
	-- the same player watches one become the other when they buy PhD and a
	-- shape change there would read as a glitch rather than as a state change.
	local TOD_OFF_WIDOW     = "i_tod_hud_off_spider"
	local TOD_OFF_WIDOW_PHD = "i_tod_hud_off_spider_phd"

	refreshLethalIcon = function ()
		if manaOn then return end
		if not TOD_GLYPHS then return end
		local img = "i_tod_hud_off_frag"
		if hasPerk( TOD_PERK_WIDOWS ) then
			img = hasPerk( TOD_PERK_PHD ) and TOD_OFF_WIDOW_PHD or TOD_OFF_WIDOW
		end
		self.lethal.icon:setImage( RegisterImage( img ) )
	end

	-- Re-check on every offhand publish. The perk models change independently of
	-- the offhand, but buying Widow's Wine re-publishes the lethal, and buying
	-- PhD while already holding one is caught by the perk subscriptions below.
	self.lethal.icon:subscribeToGlobalModel( controller, "CurrentPrimaryOffhand", "primaryOffhand", function ( m )
		if manaOn then return end
		local v = Engine.GetModelValue( m )
		if v == nil or v == "" then return end
		if TOD_GLYPHS then refreshLethalIcon() else self.lethal.icon:setImage( RegisterImage( v ) ) end
	end )
	self.tactical.icon:subscribeToGlobalModel( controller, "CurrentSecondaryOffhand", "secondaryOffhand", function ( m )
		if manaOn or smashMode then return end
		local v = Engine.GetModelValue( m )
		if v == nil or v == "" then return end
		if not TOD_GLYPHS then self.tactical.icon:setImage( RegisterImage( v ) ) end
		-- with glyphs on, the monkey set at construction is already correct
	end )
	-- ONE SUBSCRIPTION PER ELEMENT, PRECAUTIONARY (v17.19). self.lethal.icon
	-- already carries the offhand publish above, and after the gun-bay rewrite it
	-- was the LAST element on this panel holding more than one subscription --
	-- the shape the icon bug is being pinned on. Nothing here is reported broken
	-- and nothing about the READING changes: refreshLethalIcon() is idempotent
	-- and reads perk state fresh, so parking the two perk watches on the slot
	-- TILES (which carry none) is a no-op if a multi-subscription element is
	-- fine, and a fix if it is not. If the gun bay comes back working, come back
	-- and say so here -- that is what turns this from a hunch into a rule.
	if perksModel ~= nil then
		local perkHosts = { self.lethal.tile, self.tactical.tile }
		local perkFields = { TOD_PERK_WIDOWS, TOD_PERK_PHD }
		for i = 1, #perkFields do
			local pm = Engine.GetModel( perksModel, perkFields[ i ] )
			if pm ~= nil then
				perkHosts[ i ]:subscribeToModel( pm, function () refreshLethalIcon() end )
			end
		end
	end
	refreshLethalIcon()

	-- The counts are pooled GLYPH ROWS now, not text elements, so the
	-- subscription hangs off a pooled image rather than the row table.
	self.lethal.count.img[ 1 ]:subscribeToModel( model( "currentPrimaryOffhand.primaryOffhandCount" ), function ( m )
		if manaOn then return end -- mage charges own the tile, never stock grenade ammo
		self.lethal.setCount( Engine.GetModelValue( m ) )
	end )
	self.tactical.count.img[ 1 ]:subscribeToModel( model( "currentSecondaryOffhand.secondaryOffhandCount" ), function ( m )
		if manaOn or smashMode then return end -- the server owns ability cooldowns
		self.tactical.setCount( Engine.GetModelValue( m ) )
	end )

	-- =========================================================================
	-- WIDOW'S WINE FOR THE MAGE (2026-10-01, docs/167 item 3; lead tester: "Mage
	-- needs a UI indicator or recharge effect to show when Widow's Wine
	-- protection is active or when you can be hit next, especially since the
	-- class has no grenades").
	--
	-- WHAT A MAGE'S WIDOW'S WINE IS. Buying the perk swaps the player's lethal
	-- for the web grenade (stock widows_wine_perk_activate), and the Mage keeps
	-- that grenade in its inventory - DisableOffhandWeapons only stops the THROW.
	-- Every web it holds is one CONTACT WEB: a zombie's melee detonates one
	-- (_tod_perk_widows.gsc, 75% of hits) and the charges refill with the round's
	-- grenades and Max Ammo. Any other class reads that count on its lethal tile;
	-- the Mage's lethal tile is HEALING AURA, so the count had nowhere to show.
	--
	-- So a THIRD TILE, the offhand slot's own factory and its own rules, left of
	-- Blink, only for a Mage who owns the perk: the spider (PhD's purple spider
	-- with PhD, the lethal tile's pair) and the engine's live lethal count. Webs
	-- left = BRIGHT, protection armed; zero = DIM at 40%, the slot's "you had
	-- these and spent them" state, so the next hit lands. Nothing new on the
	-- server: the count is the engine's own currentPrimaryOffhand model.
	-- x1110: the y568..600 band is free between the PaP badge (ends x1046) and
	-- Blink (starts x1160); the gauge foot rule above y568 still holds.
	-- =========================================================================
	self.web = makeOffhandSlot( 1110 + HUD_DX, TOD_GLYPHS and TOD_OFF_WIDOW or "i_mtl_sat_ui_icon_lethal_grenade_frag" )
	local webLog = nil
	refreshWeb = function ()
		local owned = manaOn and hasPerk( TOD_PERK_WIDOWS )
		local n = 0
		if owned then
			n = tonumber( Engine.GetModelValue( model( "currentPrimaryOffhand.primaryOffhandCount" ) ) ) or 0
			if TOD_GLYPHS then
				self.web.icon:setImage( RegisterImage( hasPerk( TOD_PERK_PHD ) and TOD_OFF_WIDOW_PHD or TOD_OFF_WIDOW ) )
			end
		end
		-- everHad IS "the Mage owns Widow's Wine": owned + 0 webs = dim, not
		-- owned = fully hidden (the factory's never-had state).
		self.web.everHad = owned
		self.web.setCount( owned and n or 0 )
		local sig = tostring( owned ) .. ":" .. tostring( n )
		if webLog ~= sig then
			webLog = sig
			if DebugPrint then
				DebugPrint( "[TOD_MAGE_WEB] mage=" .. tostring( manaOn ) .. " widows=" .. tostring( hasPerk( TOD_PERK_WIDOWS ) )
					.. " webs=" .. tostring( n ) .. " shown=" .. tostring( owned ) )
			end
		end
	end
	-- ONE SUBSCRIPTION PER ELEMENT (the v17.19 precaution above): the count on
	-- the tile's own glyph image, the two perks on its tile and icon.
	self.web.count.img[ 1 ]:subscribeToModel( model( "currentPrimaryOffhand.primaryOffhandCount" ), function ()
		refreshWeb()
	end )
	if perksModel ~= nil then
		local wm = Engine.GetModel( perksModel, TOD_PERK_WIDOWS )
		if wm ~= nil then
			self.web.tile:subscribeToModel( wm, function () refreshWeb() end )
		end
		local pm = Engine.GetModel( perksModel, TOD_PERK_PHD )
		if pm ~= nil then
			self.web.icon:subscribeToModel( pm, function () refreshWeb() end )
		end
	end
	refreshWeb()

	-- =========================================================================
	-- PERKS — a CHILD of this widget, deliberately. See the header: keeping it a
	-- child is what makes dropping TodScaleHud free, because a child inherits
	-- both of AetheriumHud's alpha subscriptions with no extra wiring.
	-- =========================================================================
	self.PerksContainer = CoD.AetheriumPerksContainer.new( menu, controller )
	self.PerksContainer:setLeftRight( true, true, 0, 0 )
	self.PerksContainer:setTopBottom( true, true, 0, 0 )
	self:addElement( self.PerksContainer )

	-- [tod v15] Corrected note kept because somebody may come looking. This file
	-- used to claim hero-weapon display was "handled by ZmAmmo_DpadMeterSword and
	-- ZmAmmo_DpadIconPistolFactory added in AetheriumHud.lua". Neither name
	-- appears anywhere in ui/. There is NO hero-weapon display in this map, and
	-- that is fine: the map ships no hero weapon.

	-- A subscription immediately delivers the current model value. Install it
	-- only after the slots, feedback frames and stock count writers exist.
	self:subscribeToGlobalModel( controller, "PerController", "scriptNotify", function ( notifyModel )
		local name = Engine.GetModelValue( notifyModel )
		if name == "tod_thunder_smash" then
			local d = CoD.GetScriptNotifyData( notifyModel )
			if d then paintSmash( d[1], d[2], d[3] ) end
		elseif name == "tod_mage_mana" then
			local d = CoD.GetScriptNotifyData( notifyModel )
			if d == nil then return end
			local v = ( type( d[ 1 ] ) == "number" and d[ 1 ] ) or 0
			local s = ( type( d[ 2 ] ) == "number" and d[ 2 ] ) or 0
			setMana( v, s )
		elseif name == "tod_mage_abil" then
			local d = CoD.GetScriptNotifyData( notifyModel )
			if d == nil then return end
			local c = ( type( d[ 1 ] ) == "number" and d[ 1 ] ) or 0
			local b = ( type( d[ 2 ] ) == "number" and d[ 2 ] ) or 0
			setAbilities( c, b )
		elseif name == "tod_mage_recharge" then
			local d = CoD.GetScriptNotifyData( notifyModel )
			CoD.TodAbilityFeedback.Progress( self, d and d[1], d and d[2] )
		elseif name == "tod_mage_blink_blocked" then
			CoD.TodAbilityFeedback.Blocked( self )
		elseif name == "tod_mage_tut" then   -- v19.11: heal / blink / archmage cast counts
			local d = CoD.GetScriptNotifyData( notifyModel )
			if d == nil then return end
			tutUses.heal  = ( type( d[ 1 ] ) == "number" and d[ 1 ] ) or 0
			tutUses.blink = ( type( d[ 2 ] ) == "number" and d[ 2 ] ) or 0
			-- d[ 3 ] is the ARCHMAGE count; it has no badge (no tile to sit on).
			refreshTut()
		end
	end )


	-- =========================================================================
	self:subscribeToModel( model( "LastInput" ), function () refreshTut() end )

	return self
end
