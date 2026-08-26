-- =============================================================================
-- tod_upgrade.lua — the upgrade-choice panel (standalone additive overlay).
--
-- Opened per-player from GSC (`player OpenLUIMenu("tod_upgrade")`) — the SAFE
-- overlay path (cannot break the stock HUD; map 1 docs/19). Data arrives on
-- all-INT clientuimodel clientfields (zero string-cache / istring cost;
-- every visible string lives HERE, client-side):
--   todUpgShow  0 hidden | 1 choosing | 2 left picked | 3 right picked
--   todUpgAD/BD domain id  0 none | 1..18 = the DOMAIN table below
--   todUpgAR/BR rarity     1 regular | 2 SUPER | 3 ULTIMATE
--   todUpgHold  hold-to-lock progress 0..15 (the fill bar)
--   todUpgAL/BL current level 0..10
--   todUpgLuck  luck spent on these rolls 0..15
--   todUpgFocus hover state, SERVER-driven blink (no UITimers client-side):
--               0 none | 1 left bright | 2 left dim | 3 right bright | 4 right dim
--               (the GSC hold-to-confirm loop toggles bright/dim at ~7 Hz while
--               the player holds AIM/FIRE; release cancels, 0.5s hold locks in)
--   todUpgTime  seconds until auto-select 15..0 (red at <= 5)
--
-- ART (all LIVE): USE_CARD_SET_ART is the primary switch — the 54 baked
-- cartoon cards (18 domains x 3 rarities, i_tod_card_<slug>_<rarity>, slugs
-- in CARD_SLUG below, rarities regular/super/ultimate) replace the composite
-- frame+base+icon path and force USE_FRAME/BASE/ICON_ART off (USE_TITLE_ART
-- stays). The per-piece composite flags remain the no-card-set fallback
-- (i_tod_frame_*, i_tod_card_base, icons, i_tod_title_plate), with the flat
-- TextWithBg panels as the final no-art fallback. A flag may only be true
-- once its images are installed as image assets WITH zone lines —
-- RegisterImage of a missing image is undefined behavior.
-- Server stays the state machine (_tod_upgrade_ui.gsc); this file is a dumb
-- renderer (the AccAreaBanner doctrine). Idioms copied from map 1's
-- shipped-ACTIVE acc_hud.lua ONLY (CoD.TextWithBg panels — never Hud.Bg;
-- Engine.CreateModel subscribe — never a bare GetModel that can hand nil;
-- keyframe tweens — never UITimers). L3akMod global whitelist honored.
-- =============================================================================

local PAL = {
    glass = { 0, 0.035, 0.085 },      -- dark navy panel base
    line  = { 0.2, 0.75, 1.0 },       -- neutral cyan frame
    text  = { 0.86, 0.9, 0.95 },      -- body text
    dim   = { 0.55, 0.62, 0.7 },      -- de-emphasized
    pick  = { 0.2, 0.95, 0.85 },      -- chosen-card teal flash
    luck  = { 1.0, 0.88, 0.25 },      -- luck amber
}

-- rarity id -> presentation (accent strip + tag)
local RARITY = {
    [1] = { tag = "",         col = { 0.75, 0.8, 0.85 } },
    [2] = { tag = "SUPER",    col = { 0.2, 0.75, 1.0 } },
    [3] = { tag = "ULTIMATE", col = { 1.0, 0.7, 0.2 } },
}

-- domain id -> display (MUST mirror _tod_upgrades.gsc register_domains order/ids
-- AND _tod_upgrade_ui.gsc domain_id). max = that domain's level cap. v4 matrix.
local DOMAIN = {
    [1]  = { name = "DAMAGE",      desc = "+12% damage per level",               max = 10 },
    [2]  = { name = "DMG REDUCTION", desc = "-5% damage taken per level",        max = 10 },
    [3]  = { name = "BOUNTY",      desc = "+5% money per kill per level",        max = 10 },
    [4]  = { name = "LUCK",        desc = "+10% luck gain rate per level",       max = 5 },
    [5]  = { name = "SPRINT",      desc = "+5% speed/Lv - Lv 5: tireless",       max = 10 },
    [6]  = { name = "HEADSHOT",    desc = "+4% headshot damage per level",       max = 10 },
    [7]  = { name = "MAG SIZE",    desc = "real mag +30/+60/+90%",               max = 3 },
    -- max 6 = the ASSAULT cap (all other gun classes stop at 5; the server
    -- sends the real per-player cap, this is the display ceiling). [tod v9.2]
    -- renamed RESERVE -> SCAVENGER (user 2026-08-22); internal key + card slug
    -- stay "reserve", so the art FILENAMES are unchanged. The art itself was
    -- re-baked and does say SCAVENGER (verified 2026-08-23) — do not rename the
    -- files to match the label; the slug is the contract with the zone list.
    [8]  = { name = "SCAVENGER",   desc = "1 round per 7 kills, 1 kill fewer/Lv", max = 6 },
    [9]  = { name = "MOBILITY",    desc = "+5% move speed per level",            max = 10 },
    [10] = { name = "BULLET FEED", desc = "reserve trickles in: 2.0s to 0.4s",  max = 10 },
    [11] = { name = "ECHO ROUNDS", desc = "+10%/Lv chance to strike twice",      max = 10 },
    [12] = { name = "REGEN",       desc = "+0.5%/s self-heal per level",         max = 10 },
    [13] = { name = "LEECH",       desc = "blade kills heal you (+1 stage)",     max = 5 },
    [14] = { name = "CLEAVE",      desc = "+33%/Lv chance for an extra zombie",  max = 6 },
    [15] = { name = "FIRE RATE",   desc = "truly fires faster per level",        max = 3 },
    [16] = { name = "HANDLING",    desc = "faster reload, swap and ADS",         max = 3 },
    -- 17 v9.45: TWO levels now (-10/-20% since the 2026-08-26 assault buff). max here is the display ceiling for
    -- the pips/level line; the real cap is add_domain's, and the generator's
    -- AXIS.r decides which weapon forms exist. All three say 2.
    [17] = { name = "RECOIL",      desc = "kick reduced -10/-20%",              max = 2 },
    [18] = { name = "KNIFE SPEED", desc = "faster blade swing (+1 stage)",       max = 5 },
    [19] = { name = "PENETRATION", desc = "shoot through more: small > medium > large", max = 2 },
    [20] = { name = "THOR'S THUNDER", desc = "melee hits call lightning on the 2-6 nearest zombies, bigger and more often per level", max = 5 },
    -- 21 SPRINT FIRE: card art installed + zoned 2026-08-22 (files (26).zip),
    -- CARD_SLUG[21] = "sprint_fire". This row is the no-art fallback text.
    [21] = { name = "SPRINT FIRE", desc = "fire your weapon while sprinting", max = 1 },
    -- 22 CHAIN LUNGE: DOMAIN REMOVED 2026-08-24 (user: "it doesnt work"). The
    -- row stays for the same reason 11 and 30 do — this table is keyed by id,
    -- the server can no longer send 22, and deleting it would gain nothing.
    -- CARD_SLUG[22] and the three i_tod_card_chain_lunge_* zone lines ARE gone:
    -- an unreachable art slug is dead weight in the .ff, unlike a Lua row.
    [22] = { name = "CHAIN LUNGE", desc = "REMOVED 2026-08-24", max = 5 },
    -- 23 RUN AND GUN (2026-08-22, skirmisher): baked art installed + zoned
    -- (files (28).zip) -> CARD_SLUG[23] = "run_and_gun"; this row is the
    -- no-art fallback text.
    [23] = { name = "RUN AND GUN", desc = "shots fired on the move cost no ammo: 20 / 35 / 50%", max = 3 },
    -- CLASS TIERS (docs/25, 2026-08-22). The domain-id fields are 6 bits now.
    -- 24 is the TIER card: its "level" field carries (class-1)*2 + (tier-2),
    -- and PaintCard rewrites name/desc from TIER_LADDER below. 25..31 are the
    -- per-gun uniques — baked art landed 2026-08-22 (CARD_SLUG[25..31]); these
    -- rows are the no-art fallback text + the pause-menu names.
    [24] = { name = "CLASS TIER",       desc = "promote your class: a new weapon, gun upgrades reset", max = 3 },
    [25] = { name = "ADRENALINE",       desc = "kills grant a burst of speed: +4 / +6 / +8% per stack", max = 3 },
    [26] = { name = "OVERDRIVE",        desc = "sustained fire hits harder: +5 / +8 / +12% per 10 rounds", max = 3 },
    -- 27 v9.43: the ladder is FREQUENCY now, not size. Every 10th/7th/5th kill
    -- tops the mag back to full from reserve; it was 25/50/75% per kill.
    [27] = { name = "KILL RELOAD",      desc = "every 100th / 75th / 50th kill refills your mag from reserve", max = 3 },
    -- 28 v9.45: TEN levels at 3% each (was 3 levels at 10%) — same 30% ceiling,
    -- a much longer climb to it.
    [28] = { name = "IMPACT ROUNDS",    desc = "3% of hits burst nearby zombies per level", max = 10 },
    [29] = { name = "SUPPRESSING FIRE", desc = "hits slow the horde 12 / 24 / 36% for 1.5s", max = 3 },
    [30] = { name = "MEAT GRINDER",     desc = "keep firing, hit harder: up to +50 / +75 / +100%", max = 3 },
    [31] = { name = "DRAW CUT",         desc = "swings out of a sprint deal +50 / +100 / +150%", max = 3 },
    -- 32 SPRINT ARMOR (2026-08-23, skirmisher + slasher): baked art installed
    -- + zoned the same day (files (32).zip, docs/29) -> CARD_SLUG[32] =
    -- "sprint_armor", pause plate r32; this row is the no-art fallback text.
    [32] = { name = "SPRINT ARMOR",     desc = "-5% damage taken while sprinting per level", max = 5 },
    -- 33 SECOND WIND / 34 MOMENTUM (2026-08-23): the MP7's replacement unique
    -- and a new skirmisher class domain. Card art AND pause plates are both
    -- installed + zoned (i_tod_card_second_wind_*, i_tod_card_momentum_*,
    -- i_tod_pause_r33/r34), CARD_SLUG[33]/[34] are set, and PAUSE_PLATE_MAX is
    -- 34 — so these render as full art rows, not text. These rows are the
    -- no-art fallback text.
    [33] = { name = "SECOND WIND",      desc = "sprint to heal: 1% of your health per second per level", max = 5 },
    [34] = { name = "MOMENTUM",         desc = "damage scales with your speed: up to +5% per level while moving", max = 5 },
    -- 35 GIANT SLAYER / 36 BACK ARMOR (2026-08-23, v9.45). Card art AND pause
    -- plates installed + zoned the same day (files (38).zip, docs/31) ->
    -- CARD_SLUG[35]/[36] set, PAUSE_PLATE_MAX 36. These rows are the no-art
    -- fallback text and the pause-menu names.
    [35] = { name = "GIANT SLAYER",     desc = "+4% damage to bosses and elites per level", max = 5 },
    [36] = { name = "BACK ARMOR",       desc = "-10% damage taken from behind per level", max = 3 },
    -- 37 FORCED MARCH (2026-08-24, assault / AK-47 only). Card art + pause
    -- plate installed + zoned the same day (files (39).zip, docs/33) ->
    -- CARD_SLUG[37] = "march", PAUSE_PLATE_MAX = 37. This row is the no-art
    -- fallback text.
    [37] = { name = "FORCED MARCH",     desc = "+5% move speed per level", max = 3 },
    -- 11 ECHO ROUNDS and 30 MEAT GRINDER were REMOVED 2026-08-23. Their rows
    -- stay because this table is keyed by id, not ordered — a stale row is
    -- never reachable (the server can no longer send those ids) and deleting
    -- one would gain nothing while risking the ids around it.
}

-- The TIER card (id 24): class id -> the gun each promotion hands out. Class
-- ids mirror tod_class_select.lua / _tod_class_select.gsc::class_key. Pure
-- client-side strings (zero config-string cost); the baked tier-card art
-- replaces this text once USE_TIER_CARD_ART flips.
local TIER_DOMAIN = 24
local TIER_LADDER = {
    [1] = { class = "SKIRMISHER", [2] = "MP5",    [3] = "MP7" },
    [2] = { class = "ASSAULT",    [2] = "KRIG 6", [3] = "AK-47" },
    [3] = { class = "HEAVY",      [2] = "HK21",   [3] = "DEATH MACHINE" },
    [4] = { class = "SLASHER",    [2] = "KATANA", [3] = "STORMBREAKER" },
}

local MAX_LEVEL = 10

-- ---------------------------------------------------------------------------
-- [tod] UPGRADE DETAIL — what each upgrade does, and how it activates.
-- (user 2026-08-23: players forget or never learn what a domain actually does,
-- so the pause menu's YOUR UPGRADES panel now prints these two lines under
-- every owned row.)
--
-- Every entry below was read back off the ACTUAL apply hook in
-- scripts/zm/zm_tower_of_doom/*.gsc, NOT off the add_domain() desc string and
-- NOT off DOMAIN.desc above — several of those are stale or imprecise. Each
-- was then adversarially re-verified against the code a second time. If you
-- change a domain's numbers in GSC, change `val` here in the SAME commit: the
-- panel prints the value at the player's CURRENT level, so a drifted formula
-- lies to the player instead of merely reading oddly.
--
--   eff  effect line. "{V}" is replaced by val( lvl ), formatted to `dec`
--        decimal places. Omit val for a domain that has no number.
--   act  activation line — the TRIGGER, plus any window / cooldown / chance /
--        stack cap. "always on" for a pure passive.
--   dec  decimal places for the substituted value (default 0).
--
-- HARD LIMITS. There is NO text-measurement and NO wrap API in this LUI build
-- (verified repo-wide: zero uses of setFontSize/setWrap/getTextWidth) — a long
-- line cannot be measured or broken at runtime, it just overflows the column
-- into the next one. Keep eff <= 40 chars WITH the value substituted and
-- act <= 44 chars. The column is 344px; orbitron at these scales runs about
-- 6.8px/char, so 44 chars is ~300px and leaves margin.
-- ---------------------------------------------------------------------------
local DETAIL = {
    [1]  = { eff = "+{V}% damage, any weapon or melee",   act = "always on",                                  val = function( l ) return 12 * l end },
    [2]  = { eff = "-{V}% damage taken",                  act = "always on, survives a tier promotion",       val = function( l ) return 5 * l end },
    -- 3, 6, 8, 25, 27, 29, 35: the "class gun only" wording is GONE from all
    -- seven (audit 2026-08-24). The 2026-08-23 widening put every weapon on one
    -- damage lane and un-gated on_class_gun_kill, so these lines had been
    -- describing a restriction the code stopped enforcing. LEECH (13) keeps its
    -- gate and its wording; the TWIN domains (15/16/17/19) really are class-gun
    -- only, because the variant forms only exist for that gun.
    [3]  = { eff = "+{V}% points on every kill",          act = "on each kill, banked, paid out in 10s",      val = function( l ) return 5 * l end },
    [4]  = { eff = "+{V}% luck bar gain",                 act = "on every luck gain, never on losses",        val = function( l ) return 10 * l end },
    [5]  = { eff = "+{V}% move speed",                    act = "always on; lv5+ tireless (skirmisher)",      val = function( l ) return 5 * l end },
    [6]  = { eff = "+{V}% headshot damage",               act = "on a head hit, any weapon",                  val = function( l ) return 4 * l end },
    [7]  = { eff = "+{V}% magazine size",                 act = "always on, swaps in a bigger-mag gun",       val = function( l ) return 30 * l end },
    [8]  = { eff = "1 reserve round back per {V} kills",  act = "on any kill, 1 round per frame",             val = function( l ) return math.max( 2, 8 - l ) end },
    [9]  = { eff = "+{V}% move speed",                    act = "always on",                                  val = function( l ) return 5 * l end },
    [10] = { eff = "1 round into the mag every {V}s",     act = "always on, even with the gun stowed",        val = function( l ) return math.max( 0.4, 2.0 - 0.1778 * ( l - 1 ) ) end, dec = 1 },
    -- 11 ECHO ROUNDS: domain REMOVED 2026-08-23. No detail row — unreachable.
    [12] = { eff = "heal {V}% of max health per second",  act = "always on, 1/s tick, not while downed",      val = function( l ) return 0.5 * l end, dec = 1 },
    [13] = { eff = "heal +{V} hp per blade kill",         act = "on a direct kill with your blade",           val = function( l ) return ({0,4,6,8,9,10})[ math.min(l,5) + 1 ] or 10 end },
    -- CLEAVE is NOT a chance: the ladder passes 100% at Lv3 (one guaranteed
    -- extra target) and caps at 200% = +2. The wording must never say "chance".
    [14] = { eff = "+{V}% extra targets per swing",       act = "on a melee hit, 60u, caps at +2",            val = function( l ) local v = math.floor( 100 * l / 3 + 0.5 ) if v > 200 then v = 200 end return v end },
    [15] = { eff = "-{V}% time between shots",            act = "always on, class gun only",                  val = function( l ) return ( { 8, 16, 24 } )[ l ] end },
    [16] = { eff = "-{V}% reload, swap and ADS time",     act = "always on, class gun only",                  val = function( l ) return ( { 15, 25, 35 } )[ l ] end },
    [17] = { eff = "-{V}% weapon kick, hip and ads",      act = "always on, class gun only",                  val = function( l ) return ( { 10, 20 } )[ l ] end },
    [18] = { eff = "-{V}% blade swing time",              act = "always on while the blade is held",          val = function( l ) return ({0,10,16,20,23,26})[ math.min(l,5) + 1 ] or 26 end },
    -- PENETRATION is a penetrateType TIER, not a number. Lv0 = small (BELOW
    -- stock) but a row only renders at lvl > 0, so index straight by level.
    [19] = { eff = "shoots through {V} cover",            act = "always on, class gun only",                  val = function( l ) return ( { "medium", "large" } )[ l ] end },
    [20] = { eff = "lightning for {V}% of enemy max hp",  act = "on a melee hit, 3.8s to 1.3s cooldown",      val = function( l ) return 5 + 15 * l end },
    [21] = { eff = "shoot while sprinting, no sprint-out", act = "always on" },
    -- 22 CHAIN LUNGE: domain REMOVED 2026-08-24. No detail row — unreachable.
    [23] = { eff = "{V}% of shots on the move are free",  act = "per bullet while running or sprinting",      val = function( l ) return 20 + 15 * ( l - 1 ) end },
    -- 24 CLASS TIER: `lvl` is the plain tier number (2 or 3) — refresh_upgrade_list
    -- sends it raw. The pause lane does not carry the CLASS, so this line stays
    -- class-agnostic on purpose; naming the gun here would require a new channel.
    [24] = { eff = "your class gun is tier {V} of 3",     act = "gun upgrades reset on promotion",            val = function( l ) return l end },
    [25] = { eff = "+{V}% move speed per stack",          act = "on any kill, 4s, stacks x3",                 val = function( l ) return 2 * l + 2 end },
    [26] = { eff = "+{V}% bullet damage per 10 shots",    act = "firing nonstop, 0.5s gap resets, x5",        val = function( l ) return ( { 5, 8, 12 } )[ l ] end },
    -- 27 v9.43: value is KILLS-PER-PROC and DESCENDS with level (10/7/5) — the
    -- only row where a bigger level shows a smaller number. Verified against
    -- killreload_kills_needed + unique_on_kill: the proc sets clip to full
    -- (want = cap - clip), so it tops up rather than adding a magazine, and it
    -- is capped by what the reserve actually holds.
    [27] = { eff = "mag back to full every {V} kills",    act = "on any kill; drawn from reserve",            val = function( l ) return ( { 100, 75, 50 } )[ l ] end },
    [28] = { eff = "{V}% of hits splash 40% dmg nearby",  act = "per bullet hit, up to 6 within 64u",         val = function( l ) return 3 * l end },
    -- 29 SUPPRESSING FIRE nerfed 2026-08-24: 25/40/55 -> 12/24/36, so the val
    -- is a flat 12 per level now (it was 15*l + 10). The CARD ART carries these
    -- numbers baked in and is stale until re-baked — see the art work list.
    [29] = { eff = "the zombie you hit moves {V}% slower", act = "per bullet hit, 1.5s, refreshes",           val = function( l ) return 12 * l end },
    -- 30 MEAT GRINDER: domain REMOVED 2026-08-23. No detail row — unreachable.
    [31] = { eff = "+{V}% melee damage",                  act = "swing while sprinting or within 0.4s",       val = function( l ) return 50 * l end },
    [32] = { eff = "-{V}% damage taken",                  act = "while sprinting, checked on each hit",       val = function( l ) return 5 * l end },
    [33] = { eff = "heal {V}% of max hp per second",      act = "while sprinting, ticks once a second",       val = function( l ) return 1 * l end },
    [34] = { eff = "up to +{V}% bullet damage",           act = "while moving; full at a normal run",         val = function( l ) return 5 * l end },
    -- 35 GIANT SLAYER: the multiplier is ADDITIVE with DAMAGE and HEADSHOT, and
    -- pays out only against the boss/elite triad (Panzer, Rogue Protector,
    -- Reaver) — never on the horde. Both boss-damage lanes call
    -- tod_upgrades::boss_damage_bonus, so there is one number, not two.
    [35] = { eff = "+{V}% damage to bosses and elites",   act = "on a boss or elite hit, any weapon",         val = function( l ) return 4 * l end },
    -- 36 BACK ARMOR: multiplies AFTER DMG REDUCTION and SPRINT ARMOR (all three
    -- stack multiplicatively). The arc is 140 degrees measured off the player's
    -- VIEW forward, flattened to 2D — 70 degrees either side of due back.
    [36] = { eff = "-{V}% damage taken from behind",      act = "hits from a 140 arc behind your view",       val = function( l ) return 10 * l end },
    -- 37 FORCED MARCH (2026-08-24): the assault's only speed domain, and it
    -- rides the same +5%/Lv lane as SPRINT (5) and MOBILITY (9) in
    -- _tod_upgrades::apply_move_speed — one owner, three doors.
    [37] = { eff = "+{V}% move speed",                    act = "always on, AK-47 only",                      val = function( l ) return 5 * l end },
}

-- PUBLIC — read by AetheriumStartMenu.lua (same client Lua VM, the same way it
-- already reads CoD.TodDomainInfo). Returns the effect line and the activation
-- line for one owned upgrade, or nil,nil when the id has no detail row (a
-- removed domain, or an id added in GSC but not here yet) — the caller then
-- falls back to DOMAIN.desc so a new domain is never rendered blank.
CoD.TodDomainDesc = function( id, lvl )
    local d = DETAIL[ id ]
    if not d then
        return nil, nil
    end
    local eff = d.eff
    if d.val then
        -- pcall: a level outside a fixed ladder (e.g. a GSC cap raised without
        -- this table) indexes nil rather than erroring the whole pause menu.
        local ok, v = pcall( d.val, lvl )
        if not ok or v == nil then
            return nil, nil
        end
        if type( v ) == "number" then
            v = string.format( "%." .. ( d.dec or 0 ) .. "f", v )
        else
            v = tostring( v )
        end
        eff = string.gsub( eff, "{V}", v )
    end
    return eff, d.act
end

-- [tod] shared with AetheriumStartMenu.lua (same client Lua VM): the pause
-- menu's "YOUR UPGRADES" panel renders CoD.TodOwned (accumulated below from
-- the GSC tod_upg_sync LuiNotifyEvents) using these names.
CoD.TodDomainInfo = DOMAIN
CoD.TodOwned = CoD.TodOwned or {}

-- Per-piece art flags — flip a flag ONLY once its i_tod_* image assets are
-- installed + zoned. 2026-08-18 drop 2: COMPLETE set live
-- (source_data/tod_ui_images.gdt — frames, base plate, icons, title plate).
local USE_FRAME_ART = true
local USE_BASE_ART  = true
local USE_ICON_ART  = true
local USE_TITLE_ART = true
-- FULL-CARD SET ART (user drop files (10).zip 2026-08-20): 54 baked cartoon
-- cards (18 domains x 3 rarities, PORTRAIT 2:3, all text in the art) REPLACE
-- the composite frame+base+icon+text. Images-over-LUI doctrine: LUI keeps
-- only layout, the focus/hold/timer overlays and the live "Lv X > Y" line.
-- The composite path below survives as the no-art fallback.
local USE_CARD_SET_ART = true
if USE_CARD_SET_ART then
    USE_FRAME_ART = false
    USE_BASE_ART  = false
    USE_ICON_ART  = false
end
-- CLASS TIER card art (docs/25 §10): all 8
-- i_tod_card_tier_<skirmisher|assault|heavy|slasher>_<2|3> images installed +
-- zoned 2026-08-22 (user art drop files (31).zip, docs/26 build-out). The
-- composite text stack (PaintCard's no-art branch, name/desc from
-- TIER_LADDER) stays as the fallback if this is ever flipped back.
local USE_TIER_CARD_ART = true
-- portrait card rect (1280-canvas), side by side.
--
-- REVERTED 2026-08-24 to the pre-v10.3 size (user, after playing it: "I think we
-- reduced the size of the upgrade menu by 15%. Whatever we did lets revert that.
-- Its too small now and it was actually in a good spot"). v10.3 had taken
-- 213x320 -> 181x272 on an earlier playtest note ("takes up so much of the
-- screen"); this puts all four numbers back exactly, re-expanded about each
-- card's own centre so the pair keeps its layout.
--
-- These FOUR numbers are the whole knob: every overlay (icon inset, hint
-- plates, hold bar, fallback text stack) is keyed off them, so nothing else
-- needed touching in either direction. The card ART is unaffected too — the
-- PNGs are 768x1152 and the engine scales them into this rect, so no re-bake.
local CARD_Y0, CARD_Y1 = 230, 550
local CARD_AX0, CARD_AX1 = 390, 603
local CARD_BX0, CARD_BX1 = 677, 890

local MAX_LEVEL_TIME_DANGER = 5   -- countdown turns red at this many seconds

-- Per-input wording (user 2026-08-20): controller vs KBM, detected
-- CLIENT-SIDE per player. Nil-guarded — if the engine hook is absent this
-- build, fall back to controller wording. (PS-vs-Xbox glyphs are not
-- distinguishable on PC BO3 — the engine only knows gamepad vs KBM.)
local function UsingController()
    if Engine.IsGamepadEnabled ~= nil then
        local ok = Engine.IsGamepadEnabled( 0 )
        if ok ~= nil then
            return ( ok == true or ok == 1 )
        end
    end
    return true
end
local function LockHint()
    if UsingController() then
        return "HOLD [ A ] TO LOCK"
    end
    return "HOLD [ SPACE ] TO LOCK"
end
local function SwitchHint()
    if UsingController() then
        return "SWITCH: D-PAD / STICK   LOCK: HOLD [ A ]"
    end
    -- v10.19: mouse + F joined (user retest: "keyboard still does nothing" —
    -- the movement/jump reads were never live-verified on KBM; mouse1/mouse2
    -- and USE ride reads the engine core exercises constantly). Arrows work
    -- when bound to movement; the engine exposes no raw-key read.
    -- v10.20: advertise the PROVEN lane only. WASD/arrows reach the server via
    -- GetNormalizedMovement, which reads ~0 under the menu freeze's 0.001
    -- move-speed pin, so they are a bonus and must never be the headline.
    -- Mouse/V/R are action buttons every keyboard binds by default.
    return "SWITCH: [MOUSE1] [MOUSE2] or [V]   LOCK: HOLD [ SPACE / F ]"
end

CoD.TodUpgradePanel = InheritFrom( LUI.UIElement )

function CoD.TodUpgradePanel.new( HudRef, InstanceRef )
    local self = LUI.UIElement.new()
    self:setClass( CoD.TodUpgradePanel )
    self.id = "TodUpgradePanel"
    self.soundSet = "HUD"
    self:setLeftRight( true, true, 0, 0 )
    self:setTopBottom( true, true, 0, 0 )
    self:setAlpha( 0 )

    -- Art handles, registered once (each block only when its assets exist).
    local art = {}
    if USE_BASE_ART then
        art.base = RegisterImage( "i_tod_card_base" )
    end
    if USE_TITLE_ART then
        art.title = RegisterImage( "i_tod_title_plate" )
    end
    if USE_FRAME_ART then
        art.frames = {
            [1] = RegisterImage( "i_tod_frame_regular" ),
            [2] = RegisterImage( "i_tod_frame_super" ),
            [3] = RegisterImage( "i_tod_frame_ultimate" ),
        }
    end
    if USE_CARD_SET_ART then
        -- UI-family art (files (11).zip): banners, luck badges, input hints
        -- (the PANZER/PROTECTORS spawn banners that used to live in createMenu
        -- were deleted 2026-08-22 — see the note there.)
        art.bannerUpgrade = RegisterImage( "i_tod_banner_upgrade" )
        art.badges = {}
        for i = 1, 10 do
            art.badges[ i ] = RegisterImage( "i_tod_badge_luck_" .. ( i * 10 ) )
        end
        art.hintLockPad = RegisterImage( "i_tod_hint_lock_pad" )
        art.hintLockKbm = RegisterImage( "i_tod_hint_lock_kbm" )
        art.hintSwitchPad = RegisterImage( "i_tod_hint_switch_pad" )
        art.hintSwitchKbm = RegisterImage( "i_tod_hint_switch_kbm" )
        art.hintLocked = RegisterImage( "i_tod_hint_locked" )
        -- the 54-card baked set, keyed [domain id][rarity 1..3]
        local RNAME = { [1] = "regular", [2] = "super", [3] = "ultimate" }
        local CARD_SLUG = {
            [1]  = "damage",      [2]  = "dmg_reduction", [3]  = "bounty",
            [4]  = "luck",        [5]  = "sprint",        [6]  = "headshot",
            [7]  = "mag_size",    [8]  = "reserve",       [9]  = "mobility",
            [10] = "bullet_feed", [11] = "echo_rounds",   [12] = "regen",
            [13] = "leech",       [14] = "cleave",        [15] = "fire_rate",
            [16] = "handling",    [17] = "recoil",        [18] = "knife_speed",
            [19] = "penetration",   -- art installed + zoned 2026-08-21
            [20] = "thors_thunder", -- art installed + zoned 2026-08-21
            [21] = "sprint_fire",   -- art installed + zoned 2026-08-22 (files (26).zip)
            -- 22 chain_lunge: slug + zone lines REMOVED 2026-08-24 with the domain.
            [23] = "run_and_gun",   -- art installed + zoned 2026-08-22 (files (28).zip)
            -- CLASS TIER uniques 25..31 — art installed + zoned 2026-08-22
            -- (files (31).zip, docs/26 build-out). 24 (the TIER card) is keyed
            -- by class+tier in art.tier below, not here.
            [25] = "adrenaline",
            [26] = "overdrive",
            [27] = "kill_reload",
            [28] = "impact_rounds",
            [29] = "suppressing_fire",
            [30] = "meat_grinder",
            [31] = "draw_cut",
            [32] = "sprint_armor",  -- art installed + zoned 2026-08-23 (files (32).zip, docs/29)
            [33] = "second_wind",   -- art installed 2026-08-23
            [34] = "momentum",
            [35] = "giant_slayer",  -- art installed + zoned 2026-08-23 (files (38).zip, docs/31)
            [36] = "back_armor",    -- art installed + zoned 2026-08-23 (files (38).zip, docs/31)
            [37] = "march",         -- FORCED MARCH — art installed + zoned 2026-08-24 (files (39).zip, docs/33)
        }
        art.cards = {}
        for id, slug in pairs( CARD_SLUG ) do
            art.cards[ id ] = {}
            for r = 1, 3 do
                art.cards[ id ][ r ] = RegisterImage( "i_tod_card_" .. slug .. "_" .. RNAME[ r ] )
            end
        end
        -- the 8 TIER cards, keyed [class id][tier 2|3]
        if USE_TIER_CARD_ART then
            local TCLS = { "skirmisher", "assault", "heavy", "slasher" }
            art.tier = {}
            for c = 1, 4 do
                art.tier[ c ] = {}
                for t = 2, 3 do
                    art.tier[ c ][ t ] = RegisterImage( "i_tod_card_tier_" .. TCLS[ c ] .. "_" .. t )
                end
            end
        end
    end
    if USE_ICON_ART then
        -- keyed by v4 domain id. 1/7/11 keep the ORIGINAL drop-2 art
        -- (11 ECHO ROUNDS wears the old bullets/firerate icon); the rest are
        -- the art8 sheet glyphs (i_tod_up_*).
        art.icons = {
            [1]  = RegisterImage( "i_tod_icon_damage" ),
            [2]  = RegisterImage( "i_tod_up_dr" ),
            [3]  = RegisterImage( "i_tod_up_bounty" ),
            [4]  = RegisterImage( "i_tod_up_luck" ),
            [5]  = RegisterImage( "i_tod_up_sprint" ),
            [6]  = RegisterImage( "i_tod_up_headshot" ),
            [7]  = RegisterImage( "i_tod_icon_magsize" ),
            [8]  = RegisterImage( "i_tod_up_reserve" ),
            [9]  = RegisterImage( "i_tod_up_mobility" ),
            [10] = RegisterImage( "i_tod_up_bulletfeed" ),
            [11] = RegisterImage( "i_tod_icon_firerate" ),
            [12] = RegisterImage( "i_tod_up_regen" ),
            [13] = RegisterImage( "i_tod_up_leech" ),
            [14] = RegisterImage( "i_tod_up_cleave" ),
            [15] = RegisterImage( "i_tod_up_firerate" ),
            [16] = RegisterImage( "i_tod_up_handling" ),
            [17] = RegisterImage( "i_tod_up_recoil" ),
            [18] = RegisterImage( "i_tod_up_knifespeed" ),
        }
    end

    -- ---- title plate --------------------------------------------------------
    local TitleBg = CoD.TextWithBg.new( HudRef, InstanceRef )
    TitleBg:setLeftRight( false, false, -300, 300 )
    TitleBg:setTopBottom( true, false, 148, 186 )
    TitleBg.Text:setText( "" )
    TitleBg.Bg:setRGB( PAL.glass[ 1 ], PAL.glass[ 2 ], PAL.glass[ 3 ] )
    TitleBg.Bg:setAlpha( 0.85 )
    self:addElement( TitleBg )

    if art.title then
        local TitleArt = LUI.UIImage.new()
        TitleArt:setLeftRight( false, false, -300, 300 )
        TitleArt:setTopBottom( true, false, 144, 190 )
        TitleArt:setImage( art.title )
        self:addElement( TitleArt )
        TitleBg.Bg:setAlpha( 0 )   -- the plate art replaces the flat panel
    end

    local Title = LUI.UIText.new()
    Title:setLeftRight( false, false, -300, 300 )
    Title:setTopBottom( true, false, 154, 180 )
    Title:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
    Title:setRGB( PAL.line[ 1 ], PAL.line[ 2 ], PAL.line[ 3 ] )
    self:addElement( Title )
    if art.bannerUpgrade then
        -- baked banner (900x140 art at 600x93) replaces the plate + text
        local BannerImg = LUI.UIImage.new()
        BannerImg:setLeftRight( false, false, -300, 300 )
        BannerImg:setTopBottom( true, false, 122, 215 )
        BannerImg:setImage( art.bannerUpgrade )
        self:addElement( BannerImg )
    else
        Title:setText( "UPGRADE AVAILABLE - CHOOSE ONE" )
    end

    -- LUCK BOOST: a baked badge per 10% (top-right, clear of the banner);
    -- replaces the old "LUCK N0% BOOSTED THESE ROLLS" LUI text.
    local LuckLine = LUI.UIText.new()
    LuckLine:setLeftRight( false, false, -300, 300 )
    LuckLine:setTopBottom( true, false, 192, 212 )
    LuckLine:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
    LuckLine:setRGB( PAL.luck[ 1 ], PAL.luck[ 2 ], PAL.luck[ 3 ] )
    LuckLine:setScale( 0.85 )
    LuckLine:setText( "" )
    self:addElement( LuckLine )
    local LuckBadge = nil
    if art.badges then
        LuckBadge = LUI.UIImage.new()
        LuckBadge:setLeftRight( true, false, 950, 1230 )
        LuckBadge:setTopBottom( true, false, 150, 210 )
        LuckBadge:setAlpha( 0 )
        self:addElement( LuckBadge )
    end

    -- SWITCH-HINT plate (controller/KBM baked; the countdown stays live text)
    -- 280x43 = the art's true 460x70 aspect (was 320x32 — visibly stretched,
    -- user 2026-08-20); below the powerup tray band, countdown text BELOW it
    -- (they overlapped before).
    local SwitchHintImg = nil
    if art.hintSwitchPad then
        SwitchHintImg = LUI.UIImage.new()
        SwitchHintImg:setLeftRight( false, false, -140, 140 )
        SwitchHintImg:setTopBottom( true, false, 650, 693 )
        SwitchHintImg:setAlpha( 0 )
        self:addElement( SwitchHintImg )
    end

    -- (BOSS BANNERS lived here until 2026-08-20, when they moved to
    -- LUI.createMenu.tod_upgrade — this panel's root alpha is 0 outside upgrade
    -- events, which swallowed the banner in the ONLY scenario it fired: round
    -- start. They were then DELETED outright 2026-08-22, user: unnecessary.
    -- Kept as a warning: anything that must render outside an upgrade event
    -- belongs at the MENU root, not in this panel.)

    -- countdown to auto-select (below the cards; red when nearly out)
    local TimeLine = LUI.UIText.new()
    TimeLine:setLeftRight( false, false, -300, 300 )
    TimeLine:setTopBottom( true, false, 697, 717 )
    TimeLine:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
    TimeLine:setScale( 0.9 )
    TimeLine:setText( "" )
    self:addElement( TimeLine )

    -- ---- one card (built twice) --------------------------------------------
    -- xLo..xHi on the 1280 canvas; bind = the input label on the footer.
    -- PORTRAIT layout (2:3 card-set art). The composite elements survive as
    -- the no-art fallback, restacked portrait; with the card set on, the
    -- single CardImg carries frame+icon+title+desc+rarity and the composite
    -- texts are blanked in PaintCard. Lv + Bind + hold bar stay LUI (live).
    local function BuildCard( xLo, xHi, bind )
        local card = {}

        local Bg = CoD.TextWithBg.new( HudRef, InstanceRef )
        Bg:setLeftRight( true, false, xLo, xHi )
        Bg:setTopBottom( true, false, CARD_Y0, CARD_Y1 )
        Bg.Text:setText( "" )
        Bg.Bg:setRGB( PAL.glass[ 1 ], PAL.glass[ 2 ], PAL.glass[ 3 ] )
        Bg.Bg:setAlpha( 0.85 )
        self:addElement( Bg )
        card.Bg = Bg

        if art.base then
            local BaseArt = LUI.UIImage.new()
            BaseArt:setLeftRight( true, false, xLo, xHi )
            BaseArt:setTopBottom( true, false, CARD_Y0, CARD_Y1 )
            BaseArt:setImage( art.base )
            self:addElement( BaseArt )
            card.BaseArt = BaseArt
            Bg.Bg:setAlpha( 0 )   -- base art replaces the flat panel
        end

        if art.cards then
            -- THE card: one baked image per (domain, rarity)
            local CardImg = LUI.UIImage.new()
            CardImg:setLeftRight( true, false, xLo, xHi )
            CardImg:setTopBottom( true, false, CARD_Y0, CARD_Y1 )
            self:addElement( CardImg )
            card.CardImg = CardImg
            Bg.Bg:setAlpha( 0 )   -- the art IS the card
        end

        if art.frames then
            local FrameArt = LUI.UIImage.new()
            FrameArt:setLeftRight( true, false, xLo, xHi )
            FrameArt:setTopBottom( true, false, CARD_Y0, CARD_Y1 )
            FrameArt:setImage( art.frames[ 1 ] )
            self:addElement( FrameArt )
            card.FrameArt = FrameArt
        end

        if art.icons then
            local IconArt = LUI.UIImage.new()
            IconArt:setLeftRight( true, false, xLo + 12, xLo + 60 )
            IconArt:setTopBottom( true, false, CARD_Y0 + 10, CARD_Y0 + 58 )
            IconArt:setImage( art.icons[ 1 ] )
            self:addElement( IconArt )
            card.IconArt = IconArt
        end

        local Top = CoD.TextWithBg.new( HudRef, InstanceRef )
        Top:setLeftRight( true, false, xLo, xHi )
        Top:setTopBottom( true, false, CARD_Y0, CARD_Y0 + 4 )
        Top.Text:setText( "" )
        Top.Bg:setAlpha( 0.95 )
        self:addElement( Top )
        card.Top = Top

        local Bot = CoD.TextWithBg.new( HudRef, InstanceRef )
        Bot:setLeftRight( true, false, xLo, xHi )
        Bot:setTopBottom( true, false, CARD_Y1 - 4, CARD_Y1 )
        Bot.Text:setText( "" )
        Bot.Bg:setAlpha( 0.95 )
        self:addElement( Bot )
        card.Bot = Bot

        local function Line( topPx, botPx, scale )
            local t = LUI.UIText.new()
            t:setLeftRight( true, false, xLo + 14, xHi - 14 )
            t:setTopBottom( true, false, topPx, botPx )
            t:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
            t:setScale( scale )
            self:addElement( t )
            return t
        end

        -- fallback composite stack (blanked when the card set is on)
        card.Tag   = Line( CARD_Y0 + 12, CARD_Y0 + 34, 0.8 )     -- SUPER / ULTIMATE
        card.Name  = Line( CARD_Y0 + 36, CARD_Y0 + 68, 1.15 )    -- domain name
        card.Desc  = Line( CARD_Y0 + 72, CARD_Y0 + 92, 0.75 )    -- effect line
        card.Desc:setRGB( PAL.dim[ 1 ], PAL.dim[ 2 ], PAL.dim[ 3 ] )
        -- (the "Lv X > Y" overlay was REMOVED 2026-08-20 — no LUI text on the
        -- cards, the doctrine; the baked rarity gem "+N" carries the gain)
        card.Bind  = Line( CARD_Y1 + 6, CARD_Y1 + 30, 0.9 )      -- fallback text (blank w/ hint art)
        if art.hintLockPad then
            -- baked input-hint plate under the card (460x70 art at 200x30)
            local HintImg = LUI.UIImage.new()
            HintImg:setLeftRight( true, false, xLo + 6, xHi - 6 )
            -- ASPECT, and it must be RECOMPUTED whenever the card rect moves.
            -- v10.4 set 26px for the SHRUNKEN 181px card. v10.16 reverted the
            -- card to 213x320 (drawn width 201) but left this literal alone —
            -- and the revert's own comment claiming "every overlay is keyed off
            -- these four numbers, so nothing else needed touching" was wrong
            -- about exactly this one. 201/26 = 7.73 against the art's 460/70 =
            -- 6.571, i.e. ~18% horizontally stretched. 31px restores it.
            -- THE RULE: height = drawn_width / (460/70). Drawn width is
            -- (xHi-6) - (xLo+6) = CARD_AX1 - CARD_AX0 - 12.
            HintImg:setTopBottom( true, false, CARD_Y1 + 4, CARD_Y1 + 35 )
            HintImg:setAlpha( 0 )
            self:addElement( HintImg )
            card.HintImg = HintImg
        end
        card.Bind:setText( bind )
        card.Bind:setRGB( PAL.line[ 1 ], PAL.line[ 2 ], PAL.line[ 3 ] )

        -- Hold-to-lock progress bar (under the card, below the bind line;
        -- driven by todUpgHold 0..15). Track + fill.
        local HoldTrack = CoD.TextWithBg.new( HudRef, InstanceRef )
        HoldTrack:setLeftRight( true, false, xLo + 14, xHi - 14 )
        -- pushed +34 -> +39 to clear the un-squashed hint plate above (it now
        -- ends at CARD_Y1 + 35)
        HoldTrack:setTopBottom( true, false, CARD_Y1 + 39, CARD_Y1 + 43 )
        HoldTrack.Text:setText( "" )
        HoldTrack.Bg:setRGB( PAL.dim[ 1 ], PAL.dim[ 2 ], PAL.dim[ 3 ] )
        HoldTrack.Bg:setAlpha( 0 )
        self:addElement( HoldTrack )
        card.HoldTrack = HoldTrack

        local HoldFill = CoD.TextWithBg.new( HudRef, InstanceRef )
        HoldFill:setLeftRight( true, false, xLo + 14, xLo + 14 )
        HoldFill:setTopBottom( true, false, CARD_Y1 + 39, CARD_Y1 + 43 )
        HoldFill.Text:setText( "" )
        HoldFill.Bg:setRGB( PAL.pick[ 1 ], PAL.pick[ 2 ], PAL.pick[ 3 ] )
        HoldFill.Bg:setAlpha( 0 )
        self:addElement( HoldFill )
        card.HoldFill = HoldFill
        card.holdLo = xLo + 14
        card.holdHi = xHi - 14

        card.group = { Bg, Top, Bot, card.Tag, card.Name, card.Desc, card.Bind }
        if card.BaseArt then
            card.group[ #card.group + 1 ] = card.BaseArt
        end
        if card.CardImg then
            card.group[ #card.group + 1 ] = card.CardImg
        end
        if card.FrameArt then
            card.group[ #card.group + 1 ] = card.FrameArt
        end
        if card.IconArt then
            card.group[ #card.group + 1 ] = card.IconArt
        end
        return card
    end

    local function SetCardAlpha( card, a )
        for i = 1, #card.group do
            card.group[ i ]:setAlpha( a )
        end
    end

    local CardA = BuildCard( CARD_AX0, CARD_AX1, "" )
    local CardB = BuildCard( CARD_BX0, CARD_BX1, "" )

    -- ---- state + render -----------------------------------------------------
    local st = { show = 0, ad = 0, ar = 1, al = 0, bd = 0, br = 1, bl = 0, luck = 0, focus = 0, time = 0, hold = 0 }
    -- LUCK AT DEAL TIME, latched on the show 0->1 edge (audit 2026-08-25).
    -- todUpgLuck is the LIVE luck bar and it keeps moving while the cards are
    -- up — which is fine for LuckSegs, but the badge claims to describe THESE
    -- rolls. At a HEAVENLY GIFT ALTAR the world is NOT paused, so a player who
    -- keeps killing watched the badge climb under a deal it had nothing to do
    -- with. Latched client-side because a second clientfield is not affordable
    -- (the pool is at 58 of the proven 61 bits).
    local dealLuck = 0
    local wasShown = 0

    local function PaintCard( card, dom, rar, cur )
        local d = DOMAIN[ dom ]
        -- TIER card: decode (class-1)*2 + (tier-2) from the level field and
        -- name the actual promotion ("TIER 2: MP5"). A fresh table each paint —
        -- never mutate the shared DOMAIN row.
        local tierCls, tierN = nil, nil
        if dom == TIER_DOMAIN and d ~= nil then
            tierCls = math.floor( cur / 2 ) + 1
            tierN = ( cur % 2 ) + 2
            local lad = TIER_LADDER[ tierCls ]
            local gun = ( lad and lad[ tierN ] ) or "NEW WEAPON"
            local cls = ( lad and lad.class ) or "CLASS"
            d = { name = "TIER " .. tierN .. ": " .. gun,
                  desc = cls .. " - new weapon. Gun upgrades reset; DMG REDUCTION + LUCK kept",
                  max = 3 }
        end
        local r = RARITY[ rar ] or RARITY[ 1 ]
        local visible = ( d ~= nil )

        for i = 1, #card.group do
            card.group[ i ]:setAlpha( visible and 1 or 0 )
        end
        if not visible then
            return
        end

        -- FULL-CARD SET: one baked image carries everything; blank the
        -- composite texts (setText "" — never alpha-juggle, the group loop
        -- owns alpha) and skip the composite branches below.
        if card.CardImg then
            local set = art.cards[ dom ]
            -- TIER card art is keyed by class/tier, not rarity: present it as a
            -- 3-slot set of the same image so the branch below needs no change.
            if tierCls and art.tier then
                local img = art.tier[ tierCls ] and art.tier[ tierCls ][ tierN ]
                set = img and { img, img, img } or nil
            end
            if set and set[ rar ] then
                card.CardImg:setImage( set[ rar ] )
                card.CardImg:setAlpha( 1 )
            elseif set then
                card.CardImg:setImage( set[ 1 ] )
                card.CardImg:setAlpha( 1 )
            else
                -- NO baked art for this domain (a new domain shipped before
                -- its cards). Without this branch the image element kept the
                -- PREVIOUS card's art and silently showed the wrong upgrade.
                -- Hide it and render the composite text stack instead.
                card.CardImg:setAlpha( 0 )
                card.Bg.Bg:setAlpha( 0.85 )
                card.Top.Bg:setRGB( r.col[ 1 ], r.col[ 2 ], r.col[ 3 ] )
                card.Top.Bg:setAlpha( 0.95 )
                card.Bot.Bg:setRGB( r.col[ 1 ], r.col[ 2 ], r.col[ 3 ] )
                card.Bot.Bg:setAlpha( 0.95 )
                card.Tag:setText( r.tag )
                card.Tag:setRGB( r.col[ 1 ], r.col[ 2 ], r.col[ 3 ] )
                card.Name:setText( d.name )
                card.Name:setRGB( PAL.text[ 1 ], PAL.text[ 2 ], PAL.text[ 3 ] )
                card.Desc:setText( d.desc )
                return
            end
            card.Bg.Bg:setAlpha( 0 )
            -- re-baseline strip alpha EVERY render (FocusCards only writes the
            -- focused card; without this the unfocused card's accent froze at
            -- whatever blink phase last touched it — verify 2026-08-20)
            card.Top.Bg:setRGB( r.col[ 1 ], r.col[ 2 ], r.col[ 3 ] )
            card.Top.Bg:setAlpha( 0.95 )
            card.Bot.Bg:setRGB( r.col[ 1 ], r.col[ 2 ], r.col[ 3 ] )
            card.Bot.Bg:setAlpha( 0.95 )
            card.Tag:setText( "" )
            card.Name:setText( "" )
            card.Desc:setText( "" )
            return
        end

        -- Backdrop: base art if present, else the flat glass panel.
        if card.BaseArt then
            card.Bg.Bg:setAlpha( 0 )
        else
            card.Bg.Bg:setAlpha( 0.85 )
        end
        -- Rarity: the PNG frame if present (transparent center, draws over the
        -- backdrop and replaces the flat accent strips), else the flat strips.
        if card.FrameArt then
            card.FrameArt:setImage( art.frames[ rar ] or art.frames[ 1 ] )
            card.Top.Bg:setAlpha( 0 )
            card.Bot.Bg:setAlpha( 0 )
        else
            card.Top.Bg:setRGB( r.col[ 1 ], r.col[ 2 ], r.col[ 3 ] )
            card.Bot.Bg:setRGB( r.col[ 1 ], r.col[ 2 ], r.col[ 3 ] )
        end
        if card.IconArt then
            -- full domain icon set (art8) — nil-guard kept for unknown ids
            if art.icons[ dom ] then
                card.IconArt:setImage( art.icons[ dom ] )
                card.IconArt:setAlpha( 1 )
            else
                card.IconArt:setAlpha( 0 )
            end
        end
        card.Tag:setText( r.tag )
        card.Tag:setRGB( r.col[ 1 ], r.col[ 2 ], r.col[ 3 ] )
        card.Name:setText( d.name )
        card.Name:setRGB( PAL.text[ 1 ], PAL.text[ 2 ], PAL.text[ 3 ] )
        card.Desc:setText( d.desc )
    end

    -- Dim the passed-over card, teal-flash the chosen one (show = 2 / 3).
    -- The accent strips are re-raised EXPLICITLY (alpha 0.95): with frame art
    -- on, PaintCard zeroes them every render — without the raise the flash
    -- was invisible (verify pass 2026-08-19).
    local function FlashPick( chosen, other )
        chosen.Top.Bg:setRGB( PAL.pick[ 1 ], PAL.pick[ 2 ], PAL.pick[ 3 ] )
        chosen.Top.Bg:setAlpha( 0.95 )
        chosen.Bot.Bg:setRGB( PAL.pick[ 1 ], PAL.pick[ 2 ], PAL.pick[ 3 ] )
        chosen.Bot.Bg:setAlpha( 0.95 )
        if chosen.HintImg then
            chosen.HintImg:setImage( art.hintLocked )
            chosen.HintImg:setAlpha( 1 )
            chosen.Bind:setText( "" )
        else
            chosen.Bind:setText( "LOCKED IN" )
            chosen.Bind:setRGB( PAL.pick[ 1 ], PAL.pick[ 2 ], PAL.pick[ 3 ] )
            chosen.Bind:setAlpha( 1 )
        end
        if other.HintImg then
            other.HintImg:setAlpha( 0 )
        end
        for i = 1, #other.group do
            other.group[ i ]:setAlpha( 0.2 )
        end
    end

    local function Render()
        if st.show == 0 then
            self:completeAnimation()
            self:beginAnimation( "keyframe", 250, false, false, CoD.TweenType.Linear )
            self:setAlpha( 0 )
            return
        end

        if st.show ~= 0 and wasShown == 0 then
            dealLuck = st.luck            -- freeze the luck this deal was rolled at
        end
        wasShown = st.show

        PaintCard( CardA, st.ad, st.ar, st.al )
        PaintCard( CardB, st.bd, st.br, st.bl )

        -- LUCK BOOST badge (baked per 10%); LuckLine text is the no-art fallback
        if LuckBadge then
            local li = dealLuck            -- the deal's luck, not the live bar
            if li > 10 then li = 10 end
            if li > 0 and art.badges[ li ] then
                LuckBadge:setImage( art.badges[ li ] )
                LuckBadge:setAlpha( 1 )
            else
                LuckBadge:setAlpha( 0 )
            end
            LuckLine:setText( "" )
        elseif dealLuck > 0 then
            LuckLine:setText( "LUCK " .. ( dealLuck * 10 ) .. "% BOOSTED THESE ROLLS" )
        else
            LuckLine:setText( "" )
        end

        if st.show == 1 and st.time > 0 then
            if SwitchHintImg then
                SwitchHintImg:setImage( UsingController() and art.hintSwitchPad or art.hintSwitchKbm )
                SwitchHintImg:setAlpha( 0.9 )
                TimeLine:setText( "AUTO IN " .. st.time .. "s" )
            else
                TimeLine:setText( SwitchHint() .. "   AUTO IN " .. st.time .. "s" )
            end
            if st.time <= MAX_LEVEL_TIME_DANGER then
                TimeLine:setRGB( 1.0, 0.25, 0.3 )
            else
                TimeLine:setRGB( PAL.dim[ 1 ], PAL.dim[ 2 ], PAL.dim[ 3 ] )
            end
        else
            if SwitchHintImg then
                SwitchHintImg:setAlpha( 0 )
            end
            TimeLine:setText( "" )
        end

        -- Focus (server-blinked; a card is ALWAYS focused while choosing).
        -- v4.4 polish: the focused card stays at FULL presence — the blink
        -- phase pulses only the ACCENT (rarity frame / strips + bind line),
        -- so focus reads as a glow, not a flicker. The hold-to-lock bar
        -- fills under the focused card (todUpgHold 0..15).
        local function FocusCards( focused, other, bright, hold )
            SetCardAlpha( focused, 1 )
            SetCardAlpha( other, 0.4 )
            if focused.FrameArt then
                focused.FrameArt:setAlpha( bright and 1.0 or 0.72 )
            else
                focused.Top.Bg:setAlpha( bright and 0.95 or 0.5 )
                focused.Bot.Bg:setAlpha( bright and 0.95 or 0.5 )
            end
            if focused.HintImg then
                focused.HintImg:setImage( UsingController() and art.hintLockPad or art.hintLockKbm )
                focused.HintImg:setAlpha( bright and 1 or 0.75 )
                other.HintImg:setAlpha( 0 )
                focused.Bind:setText( "" )
            else
                focused.Bind:setText( LockHint() )
                focused.Bind:setRGB( PAL.pick[ 1 ], PAL.pick[ 2 ], PAL.pick[ 3 ] )
                focused.Bind:setAlpha( bright and 1 or 0.75 )
            end
            other.Bind:setText( "" )
            focused.HoldTrack.Bg:setAlpha( 0.3 )
            local w = ( focused.holdHi - focused.holdLo ) * ( hold / 15 )
            focused.HoldFill:setLeftRight( true, false, focused.holdLo, focused.holdLo + w )
            focused.HoldFill.Bg:setAlpha( ( hold > 0 ) and 0.95 or 0 )
            other.HoldTrack.Bg:setAlpha( 0 )
            other.HoldFill.Bg:setAlpha( 0 )
        end
        -- single-option events (todUpgBD == 0): CardB was hidden by PaintCard
        -- with STALE text still set — never re-raise it (the ghost-card bug,
        -- verify pass 2026-08-19).
        local two = ( DOMAIN[ st.bd ] ~= nil )
        if st.show == 1 then
            if two and ( st.focus == 3 or st.focus == 4 ) then
                FocusCards( CardB, CardA, st.focus == 3, st.hold )
            else
                FocusCards( CardA, CardB, st.focus ~= 2, st.hold )
                if not two then
                    SetCardAlpha( CardB, 0 )
                    CardB.HoldTrack.Bg:setAlpha( 0 )
                    CardB.HoldFill.Bg:setAlpha( 0 )
                end
            end
        else
            CardA.HoldTrack.Bg:setAlpha( 0 )
            CardA.HoldFill.Bg:setAlpha( 0 )
            CardB.HoldTrack.Bg:setAlpha( 0 )
            CardB.HoldFill.Bg:setAlpha( 0 )
        end

        if st.show == 2 then
            FlashPick( CardA, CardB )
            if not two then
                SetCardAlpha( CardB, 0 )
            end
        elseif st.show == 3 then
            FlashPick( CardB, CardA )
        end

        self:completeAnimation()
        self:beginAnimation( "keyframe", 250, false, false, CoD.TweenType.Linear )
        self:setAlpha( 1 )
    end

    -- ---- model subscriptions (CreateModel = idempotent, never nil) ----------
    local ctrl = Engine.GetModelForController( InstanceRef )
    local function Watch( name, key )
        local m = Engine.CreateModel( ctrl, name )
        if m then
            self:subscribeToModel( m, function ( ModelRef )
                st[ key ] = tonumber( Engine.GetModelValue( ModelRef ) ) or 0
                Render()
            end )
        end
    end
    Watch( "todUpgAD", "ad" )
    Watch( "todUpgAR", "ar" )
    Watch( "todUpgAL", "al" )
    Watch( "todUpgBD", "bd" )
    Watch( "todUpgBR", "br" )
    Watch( "todUpgBL", "bl" )
    Watch( "todUpgLuck", "luck" )
    Watch( "todUpgFocus", "focus" )
    Watch( "todUpgTime", "time" )
    Watch( "todUpgHold", "hold" )
    Watch( "todUpgShow", "show" )   -- last: paints with the full state on arrival

    return self
end

-- ---------------------------------------------------------------------------
-- Crosshair damage numbers (map 1's proven CoD.AccDmgNum design, ported):
-- each todDmgNum push (dmg*4 + headshot*2 + parity) spawns a number from a
-- pool at a scattered point near the crosshair; it rises and fades over 0.5s.
-- Headshots render teal and 25% larger; normal hits amber.
-- ---------------------------------------------------------------------------
local DMG_COLOR    = { 1.0, 0.88, 0.25 }
local DMG_COLOR_HS = { 0.20, 0.95, 0.85 }
local DMG_POOL   = 12
local DMG_LIFE   = 500
local DMG_RISE   = 36
local DMG_SCALE    = 0.4
local DMG_SCALE_HS = 0.5
local DMG_SPREAD = 0.4
local DMG_BOXW   = 80
local DMG_SCATTER = {
    { 0, 0 }, { 30, -16 }, { -26, -22 }, { 10, 28 }, { -36, 6 }, { 38, 12 },
    { -12, -34 }, { 22, 34 }, { -38, -10 }, { 6, -26 }, { 34, -30 }, { -24, 26 },
}

CoD.TodDmgNum = InheritFrom( LUI.UIElement )

function CoD.TodDmgNum.new( HudRef, InstanceRef )
    local self = LUI.UIElement.new()
    self:setClass( CoD.TodDmgNum )
    self.id = "TodDmgNum"
    self:setLeftRight( true, true, 0, 0 )
    self:setTopBottom( true, true, 0, 0 )

    local pool = {}
    for i = 1, DMG_POOL do
        local t = LUI.UIText.new()
        t:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
        t:setScale( DMG_SCALE )
        t:setRGB( DMG_COLOR[ 1 ], DMG_COLOR[ 2 ], DMG_COLOR[ 3 ] )
        t:setLeftRight( false, false, -DMG_BOXW, DMG_BOXW )
        t:setTopBottom( false, false, -17, 17 )
        t:setAlpha( 0 )
        self:addElement( t )
        pool[ i ] = t
    end
    local nextIdx = 1

    local function spawnNum( dmg, hs )
        local t = pool[ nextIdx ]
        local p = DMG_SCATTER[ nextIdx ]
        nextIdx = ( nextIdx % DMG_POOL ) + 1
        local c  = hs and DMG_COLOR_HS or DMG_COLOR
        local sc = hs and DMG_SCALE_HS or DMG_SCALE
        local cx = p[ 1 ] * DMG_SPREAD
        local cy = p[ 2 ] * DMG_SPREAD
        t:completeAnimation()
        t:setRGB( c[ 1 ], c[ 2 ], c[ 3 ] )
        t:setText( tostring( dmg ) )
        t:setScale( sc )
        t:setLeftRight( false, false, cx - DMG_BOXW, cx + DMG_BOXW )
        t:setTopBottom( false, false, cy - 17, cy + 17 )
        t:setAlpha( 1.0 )
        t:beginAnimation( "keyframe", DMG_LIFE, false, false, CoD.TweenType.Linear )
        t:setTopBottom( false, false, cy - 17 - DMG_RISE, cy + 17 - DMG_RISE )
        t:setAlpha( 0 )
    end

    local dmgModel = Engine.CreateModel( Engine.GetModelForController( InstanceRef ), "todDmgNum" )
    if dmgModel then
        self:subscribeToModel( dmgModel, function ( ModelRef )
            local v = tonumber( Engine.GetModelValue( ModelRef ) ) or 0
            if v == 0 then return end
            local dmg = math.floor( v / 4 ) * 10   -- TENS encoding (server sends dmg/10; cap 20,470)
            if dmg <= 0 then return end
            local hs = math.floor( v / 2 ) % 2 >= 1
            spawnNum( dmg, hs )
        end )
    end

    return self
end

-- ---------------------------------------------------------------------------
-- THE FINALE ROAD BANNER (v10.26). One blinking plate across the top of the
-- screen for the 90-second road phase, and nothing else -- no timer, by
-- explicit instruction.
--
-- THE BLINK IS NOT DONE HERE. _tod_finale::warn_banner_loop toggles the single
-- todFinaleWarn bit every 0.4s and this element just follows it, which is the
-- rule stated at the top of this file ("SERVER-driven blink (no UITimers
-- client-side)") and the same way the upgrade panel's focus blink works.
--
-- Art is OPTIONAL and drops straight in: register i_tod_banner_finale and it
-- replaces the plate + text wholesale, exactly like bannerUpgrade does.
-- ---------------------------------------------------------------------------
-- FLIP THIS THE DAY THE ART SHIPS, and not before: line 28 of this file --
-- "RegisterImage of a missing image is undefined behavior" -- so the call is
-- guarded rather than optional-at-runtime. With it false the banner draws a
-- plate and the words, which is a complete, shippable ending on its own.
-- Asset: i_tod_banner_finale, 1024x128 canvas (drawn at 680x46 + 12 bleed).
local USE_FINALE_BANNER_ART = true

local WARN_COLOR = { 1.0, 0.24, 0.20 }   -- alarm red, not the amber used for info
local WARN_TOP, WARN_BOT = 58, 104
local WARN_HALF = 340

CoD.TodFinaleWarn = InheritFrom( LUI.UIElement )

function CoD.TodFinaleWarn.new( HudRef, InstanceRef )
    local self = LUI.UIElement.new()
    self:setClass( CoD.TodFinaleWarn )
    self.id = "TodFinaleWarn"
    self:setLeftRight( true, true, 0, 0 )
    self:setTopBottom( true, true, 0, 0 )
    self:setAlpha( 0 )

    local Plate = LUI.UIImage.new()
    Plate:setLeftRight( false, false, -WARN_HALF, WARN_HALF )
    Plate:setTopBottom( true, false, WARN_TOP, WARN_BOT )
    Plate:setRGB( 0.06, 0.02, 0.02 )
    Plate:setAlpha( 0.72 )
    self:addElement( Plate )

    local Text = LUI.UIText.new()
    Text:setLeftRight( false, false, -WARN_HALF, WARN_HALF )
    Text:setTopBottom( true, false, WARN_TOP + 10, WARN_BOT - 8 )
    Text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
    Text:setRGB( WARN_COLOR[ 1 ], WARN_COLOR[ 2 ], WARN_COLOR[ 3 ] )
    self:addElement( Text )

    if USE_FINALE_BANNER_ART then
        local Img = LUI.UIImage.new()
        Img:setLeftRight( false, false, -WARN_HALF, WARN_HALF )
        -- 1024x128 art drawn 680 wide must be 85 tall, or it renders squashed
        -- (peer review 2026-08-25: the old 70px box squashed it ~18%).
        Img:setTopBottom( true, false, WARN_TOP - 12, WARN_TOP + 73 )
        Img:setImage( RegisterImage( "i_tod_banner_finale" ) )
        self:addElement( Img )
        Plate:setAlpha( 0 )   -- the baked plate replaces the flat panel + text
        Text:setText( "" )
    else
        Text:setText( "RUN FOR THE CROWN" )
    end

    local warnModel = Engine.CreateModel( Engine.GetModelForController( InstanceRef ), "todFinaleWarn" )
    if warnModel then
        self:subscribeToModel( warnModel, function ( ModelRef )
            local v = tonumber( Engine.GetModelValue( ModelRef ) ) or 0
            self:setAlpha( ( v >= 1 ) and 1 or 0 )
        end )
    end

    return self
end

function LUI.createMenu.tod_upgrade( Instance )
    local Hud = CoD.Menu.NewForUIEditor( "tod_upgrade" )

    Hud.soundSet = "HUD"
    Hud:setOwner( Instance )
    Hud:setLeftRight( true, true, 0, 0 )
    Hud:setTopBottom( true, true, 0, 0 )

    local Panel = CoD.TodUpgradePanel.new( Hud, Instance )
    Hud:addElement( Panel )
    Hud.todUpgradePanel = Panel

    local DmgNum = CoD.TodDmgNum.new( Hud, Instance )
    Hud:addElement( DmgNum )
    Hud.todDmgNum = DmgNum

    -- THE FINALE ROAD BANNER. Added after the damage numbers so it draws over
    -- them: for 90 seconds it is the single most important thing on screen.
    local FinaleWarn = CoD.TodFinaleWarn.new( Hud, Instance )
    Hud:addElement( FinaleWarn )
    Hud.todFinaleWarn = FinaleWarn

    -- HIDE THE WHOLE MAP HUD FOR THE PAUSE MENU AND THE SCOREBOARD
    -- (audit 2026-08-25). Every widget on this menu -- the tower gauge, the
    -- luck bar, the crosshair damage numbers, the upgrade card panel, the
    -- class draft and the finale banner -- was painting straight over both,
    -- including over the post-loss Restart Map / End Game menu, which is the
    -- one screen a player is trying to read at that moment.
    --
    -- Gated on the ROOT rather than per widget, so anything added to this
    -- menu later is covered without a second thought. This is the vendored
    -- kit's own pattern, copied from AetheriumHud.lua:399 and :442 -- same
    -- model path, same "nil or 0 means visible" test.
    local function todGateHud( bit )
        local m = Engine.GetModel( Engine.GetModelForController( Instance ), "UIVisibilityBit." .. bit )
        if not m then
            return
        end
        Hud:subscribeToModel( m, function ( model )
            local v = Engine.GetModelValue( model )
            Hud:setAlpha( ( v and v ~= 0 ) and 0 or 1 )
        end )
    end
    todGateHud( Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN )
    todGateHud( Enum.UIVisibilityBit.BIT_UI_ACTIVE )

    -- LUCK BAR (user art drop 2026-08-20; all-LUI 2026-08-20 — the server
    -- hudelem fill never sat cleanly in the frame window). 10 segments inside
    -- the frame art's transparent window (x 9.8..88.4%, y 22..78% of the
    -- frame rect), lit 1-per-10% by the live todUpgLuck field (_tod_luck
    -- pushes bar/10 on every change). Hot (80%+) = gold. "%" readout right
    -- of the frame. Segments added BEFORE the frame so the art overlays them.
    -- v2 frame art (user drop 2026-08-20, files (9).zip): "LUCK" label on top
    -- + dice icon + angled bar; measured window (alpha-0 verified) =
    -- x 103..920, y 64..105 of the 1024x128 canvas.
    local LUCK_X, LUCK_Y, LUCK_W, LUCK_H = 24, 56, 304, 38
    local winL = LUCK_X + LUCK_W * 0.1006
    local winR = LUCK_X + LUCK_W * 0.8994
    local winT = LUCK_Y + LUCK_H * 0.50
    local winB = LUCK_Y + LUCK_H * 0.828
    local SEG_GAP = 3
    local segW = ( ( winR - winL ) - SEG_GAP * 9 ) / 10

    local LuckSegs = {}
    for i = 1, 10 do
        local s = LUI.UIImage.new()
        local x0 = winL + ( i - 1 ) * ( segW + SEG_GAP )
        s:setLeftRight( true, false, x0, x0 + segW )
        s:setTopBottom( true, false, winT + 2, winB - 2 )
        s:setRGB( 0.2, 0.95, 0.85 )
        s:setAlpha( 0.12 )
        Hud:addElement( s )
        LuckSegs[ i ] = s
    end

    local LuckFrame = LUI.UIImage.new()
    LuckFrame:setLeftRight( true, false, LUCK_X, LUCK_X + LUCK_W )
    LuckFrame:setTopBottom( true, false, LUCK_Y, LUCK_Y + LUCK_H )
    LuckFrame:setImage( RegisterImage( "i_tod_luck_frame" ) )
    Hud:addElement( LuckFrame )

    -- (the "%" readout was REMOVED 2026-08-20 — no LUI text, the doctrine;
    -- the segment fill + gold-at-hot IS the readout. Subscription rides
    -- LuckSegs[1], any always-alive element works.)
    local luckModel = Engine.CreateModel( Engine.GetModelForController( Instance ), "todUpgLuck" )
    if luckModel then
        LuckSegs[ 1 ]:subscribeToModel( luckModel, function ( ModelRef )
            local v = tonumber( Engine.GetModelValue( ModelRef ) ) or 0
            if v > 10 then v = 10 end
            local hot = v >= 8
            for i = 1, 10 do
                local on = i <= v
                LuckSegs[ i ]:setAlpha( on and 0.9 or 0.12 )
                if on and hot then
                    LuckSegs[ i ]:setRGB( 1.0, 0.85, 0.25 )
                else
                    LuckSegs[ i ]:setRGB( 0.2, 0.95, 0.85 )
                end
            end
        end )
    end

    -- BOSS/ELITE SPAWN BANNERS — REMOVED 2026-08-22 (user: "remove all the
    -- announcement banners for the enemies spawning in. Its unnecessary").
    -- Gone from here: the UIImage + UIText elements, the id->art tables, and
    -- the "tod_boss_banner" scriptNotify subscription. Gone from the server
    -- side: _tod_bosses::banner/banner_notify_all/boss_banner_show/
    -- boss_banner_show_seq and the eventstring precache. Gone from the zone:
    -- the i_tod_banner_panzer / i_tod_banner_protectors image lines.
    -- (i_tod_banner_choose_class and i_tod_banner_upgrade are NOT spawn
    -- banners and stay.)
    -- Enemies now announce themselves diegetically — Panzer music, the Reaver's
    -- meteor, the Protector slam, and the floor gauge's boss pip. Same doctrine
    -- as the removed floaty kill text: no on-screen gameplay captions.

    -- ======================================================================
    -- TOWER GAUGE (user 2026-08-20) — the floor indicator, right screen edge.
    --
    -- Assembled, not a single picture: the DARK gauge is the always-on
    -- backing, then one lit cell is stamped onto every floor at or below the
    -- player (cyan rung, or the amber breather tile on floors 5/10/15/20),
    -- the crown lights on the roof, a marker frames the player's floor and a
    -- red pip marks the lowest live boss. LUI has no UV/crop, so per-cell
    -- stamping is the only way to show a variable-height lit trail — the
    -- tiles were sliced out of the lit artwork at build time.
    --
    -- Fed by the GSC tod_floor LuiNotifyEvent (floor, bossFloor), which costs
    -- ZERO clientuimodel bits (the 61-bit budget is full). At MENU ROOT so it
    -- is never alpha-gated by the upgrade panel.
    --
    -- Art grid (canvas 180x1440): crown y0..140, 25 cells y160..1360 pitch
    -- 48 with art 120x36 at x30..150, base cap y1360..1440. Floor 25 is the
    -- TOP cell. Everything below scales that grid by GA_S.
    -- ======================================================================
    if USE_CARD_SET_ART then
        local GA_X, GA_Y = 1216, 150          -- top-left on the 1280x720 canvas
        local GA_W, GA_H = 52, 416            -- 180x1440 at true aspect (1:8)
        local GA_S = GA_H / 1440              -- art px -> screen px
        local GA_CELLS = 25

        -- art-space -> screen-space helpers
        local function ax( v ) return GA_X + v * GA_S end
        local function ay( v ) return GA_Y + v * GA_S end
        -- top edge of a floor's cell, floor 1 at the BOTTOM
        local function cellTop( f ) return 160 + ( GA_CELLS - f ) * 48 end
        local function isBreather( f )
            return f == 5 or f == 10 or f == 15 or f == 20
        end

        local GaugeDark = LUI.UIImage.new()
        GaugeDark:setLeftRight( true, false, GA_X, GA_X + GA_W )
        GaugeDark:setTopBottom( true, false, GA_Y, GA_Y + GA_H )
        GaugeDark:setImage( RegisterImage( "i_tod_gauge_dark" ) )
        Hud:addElement( GaugeDark )

        -- lit roof crown (hidden until the player is actually on the roof)
        local GaugeCrown = LUI.UIImage.new()
        GaugeCrown:setLeftRight( true, false, GA_X, GA_X + GA_W )
        GaugeCrown:setTopBottom( true, false, ay( 0 ), ay( 140 ) )
        GaugeCrown:setImage( RegisterImage( "i_tod_gauge_crown" ) )
        GaugeCrown:setAlpha( 0 )
        Hud:addElement( GaugeCrown )

        -- one lit cell per floor, pre-built and toggled by alpha (no
        -- create/destroy churn on a widget that updates every few seconds)
        local rungImg = RegisterImage( "i_tod_gauge_rung" )
        local breatherImg = RegisterImage( "i_tod_gauge_breather" )
        local GaugeCells = {}
        for f = 1, GA_CELLS do
            local c = LUI.UIImage.new()
            c:setLeftRight( true, false, ax( 30 ), ax( 150 ) )
            c:setTopBottom( true, false, ay( cellTop( f ) ), ay( cellTop( f ) + 36 ) )
            c:setImage( isBreather( f ) and breatherImg or rungImg )
            c:setAlpha( 0 )
            Hud:addElement( c )
            GaugeCells[ f ] = c
        end

        -- PLAYER MARKER REMOVED (user 2026-08-21: "remove that focus state").
        -- The top of the lit trail already reads as your altitude.

        -- boss pip: a small red block on the boss's floor, left of the gauge
        local GaugeBoss = LUI.UIImage.new()
        GaugeBoss:setLeftRight( true, false, GA_X - 9, GA_X - 2 )
        GaugeBoss:setTopBottom( true, false, ay( cellTop( 1 ) + 6 ), ay( cellTop( 1 ) + 30 ) )
        -- no setImage: an image-less UIImage is a solid fill that setRGB
        -- tints (the LuckSegs pattern, proven on this HUD)
        GaugeBoss:setRGB( 1.0, 0.25, 0.22 )
        GaugeBoss:setAlpha( 0 )
        Hud:addElement( GaugeBoss )

        GaugeDark:subscribeToGlobalModel( Instance, "PerController", "scriptNotify", function ( model )
            if Engine.GetModelValue( model ) ~= "tod_floor" then
                return
            end
            local d = CoD.GetScriptNotifyData( model )
            if not d then
                return
            end
            local f = ( type( d[ 1 ] ) == "number" ) and d[ 1 ] or 0
            local bf = ( type( d[ 2 ] ) == "number" ) and d[ 2 ] or 0

            -- roof (26) counts as "all floors climbed" and lights the crown
            local climbed = ( f >= 26 ) and GA_CELLS or f
            for i = 1, GA_CELLS do
                GaugeCells[ i ]:setAlpha( ( i <= climbed ) and 1 or 0 )
            end
            GaugeCrown:setAlpha( ( f >= 26 ) and 1 or 0 )


            if bf >= 1 and bf <= GA_CELLS then
                GaugeBoss:setTopBottom( true, false, ay( cellTop( bf ) + 6 ), ay( cellTop( bf ) + 30 ) )
                GaugeBoss:setAlpha( 1 )
            else
                GaugeBoss:setAlpha( 0 )
            end
        end )
    end

    -- [tod] OWNED-UPGRADES SYNC (pause-menu list): GSC's refresh_upgrade_list
    -- sends one int-only LuiNotifyEvent per owned domain (id, level, max) —
    -- map 1's kill-feed lane (scriptNotify PerController model +
    -- CoD.GetScriptNotifyData). Accumulated here because THIS menu is always
    -- open; AetheriumStartMenu.lua reads CoD.TodOwned on every pause open.
    CoD.TodOwned = CoD.TodOwned or {}
    LuckSegs[ 1 ]:subscribeToGlobalModel( Instance, "PerController", "scriptNotify", function ( model )
        if Engine.GetModelValue( model ) == "tod_upg_sync" then
            local d = CoD.GetScriptNotifyData( model )
            if d and type( d[ 1 ] ) == "number" and type( d[ 2 ] ) == "number" then
                CoD.TodOwned[ d[ 1 ] ] = { lvl = d[ 2 ], max = ( type( d[ 3 ] ) == "number" and d[ 3 ] ) or 10 }
            end
        end
    end )

    -- MAG +N chip (independent of the choice panel — always on while the
    -- virtual bottomless-mag pool has rounds; sits left of the stock ammo
    -- counter, bottom-right). Driven by todMagBonus.
    local MagChip = LUI.UIText.new()
    MagChip:setLeftRight( false, true, -330, -180 )
    MagChip:setTopBottom( false, true, -52, -30 )
    MagChip:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_RIGHT )
    MagChip:setScale( 0.9 )
    MagChip:setRGB( 0.35, 0.9, 1 )
    MagChip:setText( "" )
    Hud:addElement( MagChip )
    local magModel = Engine.CreateModel( Engine.GetModelForController( Instance ), "todMagBonus" )
    if magModel then
        MagChip:subscribeToModel( magModel, function ( ModelRef )
            local n = tonumber( Engine.GetModelValue( ModelRef ) ) or 0
            if n > 0 then
                MagChip:setText( "MAG +" .. n )
            else
                MagChip:setText( "" )
            end
        end )
    end

    return Hud
end
