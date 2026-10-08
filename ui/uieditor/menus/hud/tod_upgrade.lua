require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodUIOwnership" )
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
--   todUpgLuck  0..10 = luck bar in tens (the top-left bar AND the deal
--               badge); 11..14 = OVERCHARGE zap frames (v14.9 — the bar
--               secretly tracks to 150 server-side; at the ceiling
--               _tod_luck's overcharge_driver cycles these four values at
--               ~7 Hz, server-driven like every blink in this file)
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

-- [tod v17.24] the ONE writer for a bind name inside the pale keycap — the fit
-- rule, the multi-bind trim and the cap's measured face geometry all live there,
-- shared with tod_class_select.lua and the pause legend. See its header.
--
-- [tod v17.30] AND IT IS FAIL-SAFED, because THIS is the file the lint header
-- above calls the highest-blast-radius in the tree. A require that throws — the
-- rawfile missing from the .ff, a Lua error inside the widget or inside
-- TodGlyphRow beneath it — aborts this ENTIRE file, silently, and takes the
-- upgrade panel, the crosshair damage numbers, the tower gauge, the luck bar,
-- the finale banner, the rampage seal AND the `tod_input_pad` receiver with it.
-- That is far too much to hang on one unguarded require for a decoration.
--
-- So: pcall the require, and route every call site through TodKeycapMake, which
-- degrades to the plain LUI text this menu already builds. THE STUB IS
-- DELIBERATELY LOCAL AND TWINNED across the three menus that use the widget — a
-- fail-safe that lives inside the thing it guards against is not a fail-safe,
-- and that is the one case where a twin beats a shared file.
pcall( require, "ui.uieditor.widgets.HUD.AetheriumWidgets.TodKeycap" )

-- [tod v17.34] THE TYPEFACE, for the crosshair damage numbers. Same pcall for
-- the same reason as the line above, and the same shape of fallback: the damage
-- numbers degrade to the UIText they were until v17.34 rather than taking the
-- whole file down. CoD.TodGlyphText being nil is the ONE test — it is checked
-- where the pool is built and again where a number is drawn.
pcall( require, "ui.uieditor.widgets.HUD.AetheriumWidgets.TodGlyphText" )

-- [tod v18.32] IS THIS EXPANSION A BUTTON PICTURE? Declared HERE, above the
-- keycap stub, because the stub's own fallback needs it: with the widget
-- absent that fallback would set the engine's LT / RT / A icon as text inside a
-- pale keycap, which is the exact failure in the user's 2026-09-08 screenshot.
-- Twin of CoD.TodKeycap.IsPadGlyph, which is the canonical copy and carries the
-- whole argument; keep the two in step.
--
-- [tod v18.48] HIGH BYTES ONLY, AND THIS IS NOT A DEVICE TEST.
--
-- ⚠️ v18.47 scanned for `b < 32 or b > 126` AND USED IT TO PICK THE DEVICE.
-- Both halves were wrong. Something in the KEYBOARD expansion carries a low
-- control byte (a trailing NUL off the engine's C string is the obvious
-- candidate), so the test fired on every device and every keyboard player lost
-- their control set — user: *"Where is the KBM controls. All i see are
-- controller controls"*. Control characters prove nothing; only the HIGH range
-- can carry a button picture, since a keyboard key display name (SPACE, F,
-- MOUSE3, MIDDLE MOUSE) is printable ASCII.
--
-- It now answers ONE question — "may this string be drawn inside a keycap?" —
-- and is consulted only AFTER the baked typeface has failed to draw it. A key
-- name our own sheets can render never reaches it, which is what makes it
-- unable to turn a working keyboard into a controller whatever bytes come back.
-- The DEVICE is decided by UsingController below, on positive proof only.
local function TodPadGlyph( tok )
    local s = Engine.Localize( tok ) or ""
    s = s:gsub( "%^%d", "" )
    if s == "" then
        return false
    end
    for i = 1, #s do
        if string.byte( s, i ) > 126 then
            return true
        end
    end
    return false
end

local function TodKeycapMake( owner, text )
    if CoD.TodKeycap then
        return CoD.TodKeycap.make( owner, text )
    end
    return {
        hide = function ()
            if text then
                text:setAlpha( 0 )
            end
        end,
        paint = function ( capL, capT, capW, capH, token, alpha )
            if not text then
                return ""
            end
            -- [tod v18.32] never a button picture inside a keycap; the caller
            -- has already chosen the device, this is the backstop.
            if TodPadGlyph( token ) then
                text:setAlpha( 0 )
                return nil
            end
            local cy = capT + capH * 0.435
            text:setLeftRight( true, false, capL + 6, capL + capW - 6 )
            text:setTopBottom( true, false, cy - 8, cy + 8 )
            text:setScale( 1 )
            text:setText( Engine.Localize( token ) )
            text:setAlpha( ( alpha == nil ) and 1 or alpha )
            return ""
        end,
    }
end

local PAL = {
    glass = { 0, 0.035, 0.085 },      -- dark navy panel base
    line  = { 0.2, 0.75, 1.0 },       -- neutral cyan frame
    text  = { 0.86, 0.9, 0.95 },      -- body text
    dim   = { 0.55, 0.62, 0.7 },      -- de-emphasized
    pick  = { 0.2, 0.95, 0.85 },      -- chosen-card teal flash
    luck  = { 1.0, 0.88, 0.25 },      -- luck amber
}

-- DARK UPGRADES (v17.10): the sentinel the SERVER writes into the 4-bit level
-- field to mark a dealt card as DARK. LOCKSTEP with TOD_UPG_DARK_L in
-- _tod_upgrades.gsc and _tod_upgrade_ui.gsc -- all three are the literal 15.
-- Domain levels top out at 10, so 15 is unreachable as a real level; this is why
-- the feature spends no clientfield bits, and it is the TIER card's own idiom
-- (id 24 packs class+tier into this same field).
local DARK_L = 15

-- rarity id -> presentation (accent strip + tag)
local RARITY = {
    [1] = { tag = "",         col = { 0.75, 0.8, 0.85 } },
    [2] = { tag = "SUPER",    col = { 0.2, 0.75, 1.0 } },
    [3] = { tag = "ULTIMATE", col = { 1.0, 0.7, 0.2 } },
}

-- MOVE SPEED LADDER (v15 item 25). Cumulative PERCENTAGE POINTS for l levels
-- of any speed domain. Increments 5, 4, 3, 3, 3... so:
--   Lv1 5 · Lv2 9 · Lv3 12 · Lv4 15 · Lv5 18 · ... · Lv10 33
-- LOCKSTEP with speed_pct_for_level() in _tod_upgrades.gsc — same three
-- constants (0.05 / 0.04 / 0.03), expressed here in points rather than scale.
-- The GSC is the authority; if they ever disagree the PLAYER sees this one,
-- which is exactly why item 25 moved the number OFF the card art and onto the
-- pause menu: there is now one printed number and it is served from here.
-- THE SHARED 5-TIER LADDER (v16). Cumulative value at level l:
--   Lv1 10 · Lv2 18 · Lv3 24 · Lv4 28 · Lv5 32
-- LOCKSTEP with ladder5() in _tod_upgrades.gsc (TOD_LADDER5_L1..L5).
-- Unit-agnostic on purpose: RECOVERY and BACK ARMOR read it as a PERCENT,
-- VITALITY reads it as FLAT HP. The card art for all three is generic, so this
-- pause row is the ONLY place a player ever sees the real number.
local function ladder5( l )
    if not l or l <= 0 then return 0 end
    local T = { 10, 18, 24, 28, 32 }
    return T[ math.min( l, 5 ) ]
end

-- DMG REDUCTION's v16 ladder: cumulative 6/11/15/18/20 from increments
-- 6/5/4/3/2. MIRRORS dr_pct_for_level() in _tod_upgrades.gsc -- a lockstep pair
-- that nothing checks, so change both or neither. Deliberately NOT ladder5():
-- that table is 10/18/24/28/32 and belongs to RECOVERY/BACK ARMOR/VITALITY.
-- v17.3: the clamp at 5 is GONE, because the cap is per-class now (3/5/9/10
-- since v19.52 - 3/5/7/10 before it) and the heavy really does reach 10.
-- Mirrors dr_pct_for_level exactly:
-- diminishing 6/5/4/3 to level 4, then a FLAT +2 per level on
-- TOD_UPG_DR_LN. Clamping here would have silently frozen the pause readout at
-- -20% for the two classes that now go past it, while the game applied more.
local function drPct( l )
    if not l or l <= 0 then return 0 end
    local T = { 6, 11, 15, 18 }
    if l <= 4 then return T[ l ] end
    return 18 + ( l - 4 ) * 2
end

local function speedPct( l )
    if not l or l <= 0 then return 0 end
    if l == 1 then return 5 end
    return 9 + ( l - 2 ) * 3
end

-- FULL STEAM (42) pays the shared ladder x1.2 (v16.8, user 2026-09-01: "improve
-- the full steam upgrade by 20%"): 6 / 10.8 / 14.4 / 18 / 21.6 points on the
-- scale, LOCKSTEP with TOD_LMGS_MULT in _tod_upgrades.gsc (lmg_sprint_bonus).
-- DISPLAYED ROUNDED TO THE NEAREST WHOLE PERCENT (v16.8a, user: "round to
-- nearest whole number for pause description"): 6 / 11 / 14 / 18 / 22. The GSC
-- still pays the exact value; only this row rounds. SPRINT (5) and FORCED
-- MARCH (37) stay on speedPct raw.
local FULL_STEAM_MULT = 1.2
local function fullSteamPct( l )
    return math.floor( speedPct( l ) * FULL_STEAM_MULT + 0.5 )
end

-- RIOT SHIELD (45, v16.63): the user's ladder verbatim. LOCKSTEP with
-- TOD_SHIELD_HP_L1..L5 and TOD_SHIELD_RECHARGE_L1..L5 in _tod_riotshield.gsc
-- (seconds there; printed m:ss here). Index = level, clamped 1..5 so a level
-- outside the table can never index nil into a setText.
local SHIELD_HP       = { 200, 300, 370, 450, 500 }
local SHIELD_RECHARGE = { "4:00", "3:30", "3:00", "2:30", "2:00" }
local function shieldLv( l )
    if l < 1 then return 1 end
    if l > #SHIELD_HP then return #SHIELD_HP end
    return l
end
local function shieldHp( l )
    return SHIELD_HP[ shieldLv( l ) ]
end
local function shieldRecharge( l )
    return SHIELD_RECHARGE[ shieldLv( l ) ]
end
-- A percentage that may carry a half step (TRAILBLAZER's slow ladder since
-- v18.6 is 3 + 4.5*L). Whole values print as integers so the common rows do not
-- grow a pointless ".0"; halves print one decimal rather than being rounded,
-- because this row is the only place the player ever reads the figure.
local function pctStr( x )
    if x == math.floor( x ) then
        return string.format( "%d", x )
    end
    return string.format( "%.1f", x )
end

-- domain id -> display (MUST mirror _tod_upgrades.gsc register_domains order/ids
-- AND _tod_upgrade_ui.gsc domain_id). max = that domain's level cap. v4 matrix.
local DOMAIN = {
    [1]  = { name = "DAMAGE",      desc = "+10% damage per level",               max = 10 },
    -- v17.3 max 5 -> 10: 10 is the CEILING (heavy). The per-class caps are
    -- 3 skirmisher / 5 slasher / 9 assault (7 until v19.52) / 10 heavy /
    -- 3 mage, declared by
    -- set_class_max in _tod_upgrades.gsc, and the pause row's own max arrives
    -- per-player through tod_upg_sync, so this number is only the fallback.
    -- Desc carries no ladder now because the ladder ends somewhere different
    -- for every class.
    [2]  = { name = "DMG REDUCTION", desc = "take less damage, always on",  max = 10 },
    [3]  = { name = "BOUNTY",      desc = "+5% money per kill per level",        max = 10 },
    [4]  = { name = "LUCK",        desc = "+10% luck gain rate per level",       max = 5 },
    [5]  = { name = "SPRINT",      desc = "move faster on foot",                 max = 10 },
    [6]  = { name = "HEADSHOT",    desc = "+12% headshot damage per level",      max = 5 },
    [7]  = { name = "MAG SIZE",    desc = "real mag +20/+40/+60%",               max = 3 },   -- +30 -> +20%/Lv 2026-09-01 (MAG_STEP nerf; card art bakes the OLD numbers until docs/65 lands)
    -- max 6 = the ASSAULT cap (all other gun classes stop at 5; the server
    -- sends the real per-player cap, this is the display ceiling). [tod v9.2]
    -- renamed RESERVE -> SCAVENGER (user 2026-08-22); internal key + card slug
    -- stay "reserve", so the art FILENAMES are unchanged. The art itself was
    -- re-baked and does say SCAVENGER (verified 2026-08-23) — do not rename the
    -- files to match the label; the slug is the contract with the zone list.
    [8]  = { name = "SCAVENGER",   desc = "primary kills bank ammo: a round per 2.8 / 2.3 / 2 / 1.8 / 1.6 kills; Lv6 1.4", max = 6 },   -- v18.88 the whole ladder shifted another -0.2 kills (v18.86 3/2.5/2.2/2/1.8, Lv6 1.6; v16.42 4/3/2.4/2/1.8, Lv6 1.6) (v16.41 4/2.9/2.3/2.0/1.9, Lv6 1.8; v16.40 5/3.3/2.6/2.3/2.1, Lv6 1.9; before that 1 per 5, 1 fewer/Lv, Lv6 3 per 2)
    -- 9 MOBILITY: max 10 -> 5 (v14.11, user 2026-08-30). Display ceiling only;
    -- the server sends the real cap in every sync/deal.
    -- 9 MOBILITY: domain RETIRED v15 (2026-08-31) — the heavy trades it for a
    -- higher base speed (0.75 -> 0.80) plus FULL STEAM (42). Row KEPT, like the
    -- 11/12/22/30/34 pattern: these tables are id-keyed and a fresh run can
    -- never own it, so the entry is inert.
    [9]  = { name = "MOBILITY",    desc = "+5% move speed per level",            max = 5 },
    [10] = { name = "BULLET FEED", desc = "reserve trickles in: 1.0s to 0.2s",  max = 10 },
    [11] = { name = "ECHO ROUNDS", desc = "+10%/Lv chance to strike twice",      max = 10 },
    -- 12 REGEN: DOMAIN REMOVED v14.11 (2026-08-30, with 22/30/34). The row
    -- stays because this table is keyed by id — the server can no longer send
    -- 12. The heavy's sustain is VITALITY (38) + RECOVERY (39) now.
    -- ⚠️ THIS LINE SAID "with 11/22/30/34" UNTIL 2026-09-11 AND IT COST A
    -- SESSION. Id 11 is ECHO ROUNDS and it was REMOVED 2026-08-23 (v9.35), a
    -- week before v14.11 — see :558 below, which has always had it right, and
    -- the `// Was:` block in _tod_upgrades.gsc. A v18.85 copy fix read THIS
    -- line, believed it, and wrote "retired in v14.11" into five places
    -- including the CHANGELOG and a shipped art brief. Two lines in one file
    -- disagreeing is worse than neither being here: when a retirement date
    -- matters, read the domain's OWN `// Was:` block in the GSC.
    [12] = { name = "REGEN",       desc = "REMOVED 2026-08-30",                  max = 10 },
    [13] = { name = "LEECH",       desc = "melee kills heal you (+1 stage)",     max = 5 },
    -- 14 CLEAVE: max 6 -> 3 (v14.11 — "too OP"; one banked extra now).
    [14] = { name = "CLEAVE",      desc = "+33%/Lv chance for an extra zombie",  max = 3 },
    -- 15 v18.85 (2026-09-11): "truly fires faster per level" lost the word
    -- TRULY. It was contrasting this domain with ECHO ROUNDS (11), REMOVED
    -- 2026-08-23 (v9.35) — see :558 in this file, and the `// Was:` block in
    -- _tod_upgrades.gsc — so it had been contrasting nothing for 19 days and
    -- players read it as filler. LOCKSTEP with the add_domain string and the
    -- baked i_tod_card_fire_rate_* value plates (docs/134).
    -- ⚠️ This comment first shipped saying "retired in v14.11, for a month",
    -- copied from :272 below, which is the one line in this file that gets
    -- that date wrong. Read :558, not :272.
    [15] = { name = "FIRE RATE",   desc = "fires faster per level",              max = 3 },
    [16] = { name = "HANDLING",    desc = "faster reload, swap and ADS",         max = 3 },
    -- 17 v9.45: TWO levels now (-10/-20% since the 2026-08-26 assault buff). max here is the display ceiling for
    -- the pips/level line; the real cap is add_domain's, and the generator's
    -- AXIS.r decides which weapon forms exist. All three say 2.
    [17] = { name = "RECOIL",      desc = "kick reduced -15/-30%",              max = 2 },   -- -10/-20 -> -15/-30 v16.50 (user 2026-09-02); LOCKSTEP RECOIL_STEP in gen_tod_twins.js
    [18] = { name = "KNIFE SPEED", desc = "faster melee swing (+1 stage)",       max = 5 },
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
    -- 23 v14.11: gained the DAMAGE half (same ladder, same movement test).
    -- 23 v16.36: REQUIRES SPRINT FIRE (id 21) — server-side prerequisite in _tod_upgrades set_requires; the card never rolls before it is owned, so no text change here.
    -- 23 v16.50: FIVE levels on a stage table, 16 / 28 / 38 / 46 / 52% (was 20/35/50 over 3). LOCKSTEP: TOD_RNG_PCT_L* / TOD_UPG_RNG_DMG_L* / DETAIL[23].
    [23] = { name = "RUN AND GUN", desc = "moving: 16 / 28 / 38 / 46 / 52% of shots free, and that much more damage", max = 5 },
    -- CLASS TIERS (docs/25, 2026-08-22). The domain-id fields are 6 bits now.
    -- 24 is the TIER card: its "level" field carries (class-1)*2 + (tier-2),
    -- and PaintCard rewrites name/desc from TIER_LADDER below. 25..31 are the
    -- per-gun uniques — baked art landed 2026-08-22 (CARD_SLUG[25..31]); these
    -- rows are the no-art fallback text + the pause-menu names.
    [24] = { name = "CLASS TIER",       desc = "promote your class: a new UNPACKED weapon, gun upgrades reset", max = 3 },
    [25] = { name = "ADRENALINE",       desc = "multi-kills heal you and grant a 3s burst of speed and damage", max = 5 },
    [26] = { name = "OVERDRIVE",        desc = "hold the trigger: damage ramps up over 3.75s, 3s packed", max = 5 },
    -- 27 KILL RELOAD: DOMAIN REMOVED 2026-09-01 (user: "No one likes it").
    -- Row kept for the same reason 11/12/22/28/30/32/34 are: this table is keyed
    -- by id and the server can no longer send 27. CARD_SLUG[27] and its three
    -- zone lines ARE gone (the IMPACT ROUNDS form) — the PNGs stay in source_data.
    [27] = { name = "KILL RELOAD",      desc = "REMOVED 2026-09-01", max = 3 },
    -- 28 v9.45: TEN levels at 3% each (was 3 levels at 10%) — same 30% ceiling,
    -- a much longer climb to it.
    -- 28 IMPACT ROUNDS: DOMAIN REMOVED 2026-08-31 (user: "No one likes it").
    -- Row kept for the same reason 11/12/22/30/34 are: this table is keyed by
    -- id and the server can no longer send 28. CARD_SLUG[28] and its three
    -- zone lines ARE gone (the CHAIN LUNGE form) — unreachable art is dead
    -- weight in the .ff, a Lua row is not.
    [28] = { name = "IMPACT ROUNDS",    desc = "REMOVED 2026-08-31", max = 10 },
    [29] = { name = "SUPPRESSING FIRE", desc = "hits slow the horde 12 / 24 / 36% for 1.5s", max = 3 },
    [30] = { name = "MEAT GRINDER",     desc = "keep firing, hit harder: up to +50 / +75 / +100%", max = 3 },
    [31] = { name = "DRAW CUT",         desc = "swings out of a sprint deal +50 / +100 / +150%", max = 3 },
    -- 32 SPRINT ARMOR (2026-08-23, skirmisher + slasher): baked art installed
    -- + zoned the same day (files (32).zip, docs/29) -> CARD_SLUG[32] =
    -- "sprint_armor", pause plate r32; this row is the no-art fallback text.
    -- 32 SPRINT ARMOR: DOMAIN REMOVED 2026-08-31 (user: "Retire sprint armor
    -- entirely"). Row kept — id-keyed table, server can no longer send 32.
    -- CARD_SLUG[32] and its three zone lines ARE gone (CHAIN LUNGE form).
    [32] = { name = "SPRINT ARMOR",     desc = "REMOVED 2026-08-31", max = 5 },
    -- 33 SECOND WIND / 34 MOMENTUM (2026-08-23): the MP7's replacement unique
    -- and a new skirmisher class domain. Card art AND pause plates are both
    -- installed + zoned (i_tod_card_second_wind_*, i_tod_card_momentum_*,
    -- i_tod_pause_r33/r34), CARD_SLUG[33]/[34] are set, and PAUSE_PLATE_MAX is
    -- 34 — so these render as full art rows, not text. These rows are the
    -- no-art fallback text.
    -- 33 SECOND WIND is the MP5's unique since v14.11 (was the MP7's).
    [33] = { name = "SECOND WIND",      desc = "sprint to heal: 1% of your health per second per level", max = 5 },
    -- 34 MOMENTUM: DOMAIN REMOVED v14.11 (2026-08-30) — RUN AND GUN's damage
    -- half is the moving-damage card now. Row kept, id-keyed table.
    [34] = { name = "MOMENTUM",         desc = "REMOVED 2026-08-30", max = 5 },
    -- 35 GIANT SLAYER / 36 BACK ARMOR (2026-08-23, v9.45). Card art AND pause
    -- plates installed + zoned the same day (files (38).zip, docs/31) ->
    -- CARD_SLUG[35]/[36] set, PAUSE_PLATE_MAX 36. These rows are the no-art
    -- fallback text and the pause-menu names.
    [35] = { name = "GIANT SLAYER",     desc = "+12% damage to bosses and elites per level", max = 5 },   -- 15 -> 12%/Lv v16.50 (user 2026-09-02)
    [36] = { name = "BACK ARMOR",       desc = "take less damage from behind", max = 5 },
    -- 37 FORCED MARCH (2026-08-24, assault / AK-47 only). Card art + pause
    -- plate installed + zoned the same day (files (39).zip, docs/33) ->
    -- CARD_SLUG[37] = "march", PAUSE_PLATE_MAX = 37. This row is the no-art
    -- fallback text.
    [37] = { name = "FORCED MARCH",     desc = "move faster on foot", max = 5 },
    -- 38 VITALITY / 39 RECOVERY (v14.11, 2026-08-30 — the heavy's new sustain
    -- pair, replacing REGEN). NO card art or pause plates yet: these render
    -- through the no-art text fallback (PaintCard's nil-slug branch) and as
    -- text rows in the pause list (38 > PAUSE_PLATE_MAX). When the art drop
    -- lands: add CARD_SLUG[38]/[39], bump PAUSE_PLATE_MAX to 39, install +
    -- zone the images — the v14.11 art prompt doc carries the checklist.
    [38] = { name = "VITALITY",         desc = "more max health", max = 5 },
    [39] = { name = "RECOVERY",         desc = "health regen starts sooner", max = 5 },
    -- 40 PERK SLOTS: LIVE. v16.80 retired it with the perk cap (2026-09-03) and
    -- v17.3a RESTORED BOTH — CARD_SLUG[40] and the three card zone lines came
    -- back with it, and the r40 pause plate never left. This comment said
    -- "DOMAIN REMOVED" for five days after the restore and was still saying it
    -- on 2026-09-08; a retirement note outlives the retirement more often than
    -- anyone expects, so check add_domain before believing one.
    -- 40 v18.85 (2026-09-11): "+1 perk slot / Lv (base 4)" was read as "per
    -- FLOOR level" — this map has fifty of those and a floor gate on class
    -- tiers, so "level" was the one word this line could not afford. Says
    -- CARRY and counts perks now. LOCKSTEP with the add_domain string, DETAIL
    -- [40] below and the three baked i_tod_card_perkslots_* plates (docs/134).
    [40] = { name = "PERK SLOTS",       desc = "carry one more perk each time", max = 5 },
    -- 41 DISTRACTION (v14.59; reshaped v16.49) - the assault's Cymbal Monkey.
    -- The LEVEL IS THE CARRY CAP: Lv1 holds 1, Lv2 holds 2, Lv3 holds 3; MAX
    -- AMMO adds +1 at every level. (The Lv2 Li'l Arnies swap is gone.)
    -- Art landed 2026-09-01 (files (78).zip, docs/54) and is re-baked for 3
    -- pips under docs/75: CARD_SLUG[41] is set and i_tod_pause_r41 is
    -- installed + zoned, so this row is the desc fallback only, never what a
    -- player actually sees. LOCKSTEP max 3: add_domain / TOD_DISTRACT_MAX_CARRY.
    [41] = { name = "DISTRACTION",      desc = "hold one more Cymbal Monkey per level", max = 3 },
    -- FULL STEAM (v15 item 24) — the heavy's MOBILITY replacement. Art landed
    -- 2026-09-01 (files (78).zip, docs/56): CARD_SLUG[42] is set, so this row is
    -- the desc fallback only. The three cards were RE-BAKED 2026-09-01 (files
    -- (81).zip) and now read "KEEP SPRINTING FOR SPEED" — no number, so the
    -- 1.5s -> 1.0s retune that made the old art wrong cannot recur. This card
    -- set is the reason the no-numbers rule exists: it was the one card in the
    -- v15 pass that baked a value, and it went stale within hours.
    [42] = { name = "FULL STEAM",       desc = "sprint 0.8s unbroken for a burst of speed", max = 5 },
    -- ATHLETE (v16, 2026-09-01) — the slasher gets its mobility card back, in
    -- the hole the retired chain lunge (22) left. Art landed the SAME DAY
    -- (files (79).zip, docs/57): CARD_SLUG[43] is set and PAUSE_PLATE_MAX is 43,
    -- so this row is now the desc fallback only, never what a player sees.
    [43] = { name = "ATHLETE",          desc = "slide faster, jump higher, steer in the air, wall-run", max = 5 },   -- v16.23: air steering added; v16.34: wall-run (2026-09-02)
    -- 44 GUNSLINGER (v16.51, 2026-09-02) — the slasher's sidearm vs bosses and
    -- elites: +30%/Lv on top of the class's 2.25x baseline. Art landed the
    -- same day (v16.54, docs/79): CARD_SLUG[44] is set and i_tod_pause_r44 is
    -- installed + zoned, so this row is the desc fallback only. LOCKSTEP:
    -- TOD_UPG_GUNSLINGER_PER_LVL in _tod_upgrades.gsc.
    [44] = { name = "GUNSLINGER",       desc = "+30% sidearm damage to bosses and elites per level", max = 5 },
    -- 46 TRAILBLAZER (v16.62, docs/80): text fallback only until the art lands (45 went to RIOT SHIELD the same day).
    [46] = { name = "TRAILBLAZER",      desc = "sprinting leaves burning ground that slows everything on it and burns all but elites: longer, wider, hotter and slower per level", max = 5 },
    -- 45 RIOT SHIELD (v16.63, 2026-09-02) — UNIVERSAL: a riot shield every
    -- class carries; each level adds shield HP and shortens the recharge that
    -- hands it back after it breaks (200..500 HP, 4:00..2:00). Art PENDING
    -- (docs/82) LANDED 2026-09-03: CARD_SLUG[45] is set and i_tod_pause_r45 is
    -- installed + zoned, so this row is the desc fallback only. LOCKSTEP: SHIELD_HP /
    -- SHIELD_RECHARGE above, TOD_SHIELD_* in _tod_riotshield.gsc.
    [45] = { name = "RIOT SHIELD",      desc = "a riot shield that recharges after it breaks; tougher and faster each level", max = 5 },
    -- 47 DEADSHOT (v16.64, 2026-09-02) — ASSAULT, max 1, ALWAYS an ULTIMATE card
    -- (server-side rarity lock): permanent head-snap aim assist (controller),
    -- perk-bar crest, no perk slot. Art PENDING (docs/84, ONE card):
    -- CARD_SLUG[47] unset, so this row IS the card until the drop lands.
    -- 47 DEADSHOT RETIRED v19.25 (user: "not liked or helpful"). Row kept: this
    -- table is keyed, the server can no longer send the id, and the ids around
    -- it are load-bearing for the pause plates.
    [47] = { name = "DEADSHOT",         desc = "retired",                                  max = 1 },
    -- 48..51 THE MAGE (docs/114) -- SHIPPED DISABLED. The class cannot be
    -- drafted, so the server can never send these ids; the rows exist so the
    -- day it is enabled the panel already reads correctly. No CARD_SLUG for any
    -- of the four, so each row IS the card, and all four are above
    -- PAUSE_PLATE_MAX 47, so the pause list draws TEXT rows.
    -- `max` is the DISPLAY ceiling; the server sends the real per-player cap.
    -- NAMES ARE BAKED INTO THE CARD ART (docs/115 delivery, 2026-09-07):
    -- AIR BURST / FIRE BLAST / ICE SHATTER. The card is the only place a
    -- player reads a domain name outside this list, so these follow the art.
    -- 48 AIR BURST RETIRED v18.30 (no wind staff). Row kept: keyed table.
    [48] = { name = "AIR BURST",        desc = "retired",                                  max = 6 },
    [49] = { name = "FIRE BLAST",       desc = "+15% fire staff damage per level; burns elites",     max = 6 },
    [50] = { name = "ICE SHATTER",      desc = "+15% ice staff damage per level; slows elites more and longer",      max = 6 },
    -- 51 ATTUNEMENT RETIRED v18.41 (it duplicated HEALING AURA's charges).
    [51] = { name = "ATTUNEMENT",       desc = "retired",                                  max = 5 },
    [55] = { name = "BLINK",            desc = "teleport a short way, on tactical",        max = 5 },
    [53] = { name = "CHAIN LIGHTNING",  desc = "+1 arc every 2 levels; +5% arc damage per level", max = 10 },
    [54] = { name = "ARCHMAGE",         desc = "stronger, faster form with sprint fire", max = 6 },
    [56] = { name = "MYSTICAL HANDS",   desc = "all staff swaps and raises are 3x faster", max = 1 },
    [52] = { name = "HEALING AURA",     desc = "more healing and damage resistance per level",           max = 6 },
    -- RAPID FLAME (v19.25) -- the fire staff's cadence card. LOCKSTEP with
    -- _tod_mage_elements TOD_MAGE_FIRE_RATE_PER_LV 0.10 / _MAX_LV 5 and with
    -- add_domain( "mage_rate", ... 5 ). No CARD_SLUG and no pause plate (57 is
    -- past PAUSE_PLATE_MAX): this row IS the card until the art lands.
    [58] = { name = "THUNDER SMASH", desc = "leap into a thunder slam", max = 3 },
    [57] = { name = "RAPID FLAME",      desc = "fire staff shoots 10% faster per level",   max = 5 },
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
--        stack cap. LEAVE IT "" for a pure passive — a sub-line reading
--        "always on" was on 16 of 38 rows and taught nothing (user
--        2026-09-03: make it clear, cut unnecessary words). Only write an
--        act line when there IS a restriction or a trigger.
--   dec  decimal places for the substituted value (default 0).
--
-- HARD LIMITS. There is NO text-measurement and NO wrap API in this LUI build
-- (verified repo-wide: zero uses of setFontSize/setWrap/getTextWidth) — a long
-- line cannot be measured or broken at runtime, it just overflows the column
-- into the next one. Keep eff <= 40 chars WITH the value substituted and
-- act <= 44 chars. The column is 344px; orbitron at these scales runs about
-- 6.8px/char, so 44 chars is ~300px and leaves margin.
-- ---------------------------------------------------------------------------
local SPIRE_PERK_ROSTER = 9   -- LOCKSTEP: TOD_PERK_ROSTER in _tod_upgrades.gsc (DETAIL[40])

local DETAIL = {
    [1]  = { eff = "+{V}% damage, any weapon or melee",   act = ""          ,                                  val = function( l ) return 10 * l end },   -- 12 -> 10 (v15, 2026-08-31)
    [2]  = { eff = "-{V}% damage taken",                  act = ""          ,                                  val = function( l ) return drPct( l ) end },   -- v16: flat 5*l -> the 6/11/15/18/20 ladder
    -- 3, 6, 8, 25, 27, 29, 35: the "class gun only" wording is GONE from all
    -- seven (audit 2026-08-24). The 2026-08-23 widening put every weapon on one
    -- damage lane and un-gated on_class_gun_kill, so these lines had been
    -- describing a restriction the code stopped enforcing. LEECH (13) keeps its
    -- gate and its wording; the TWIN domains (15/16/17/19) really are class-gun
    -- only, because the variant forms only exist for that gun.
    -- v18.9: "paid out every 10s" read as a ten-second TIMER, next to seven rows
    -- where s means seconds. There is no timer - it banks and pays on the kill in
    -- whole tens of points. "whole 10s" was rejected for keeping the same
    -- ambiguous token.
    [3]  = { eff = "+{V}% points on every kill",          act = "banked, paid in 10-point steps",  val = function( l ) return 5 * l end },
    -- v18.9: the act line now says what the BAR IS FOR. Every in-game surface
    -- that named luck was circular - this row explained how to raise it, the HUD
    -- art says "LUCK", the deal badge says "LUCK 60% BOOSTED" and stops one noun
    -- short - so the only place the payoff was ever written was the Steam page.
    -- A player asked outright in the Workshop comments on 2026-09-06. The
    -- 100-150 overcharge band stays secret, deliberately.
    [4]  = { eff = "+{V}% luck bar gain",                 act = "a fuller bar deals rarer cards",   val = function( l ) return 10 * l end },
    -- [tod] 2026-08-26: the "lv5+ tireless (skirmisher)" rider is GONE — the
    -- unlimited-sprint grant was removed after three failed attempts to make the
    -- meter actually stop draining. SPRINT is move speed only, for both classes.
    [5]  = { eff = "+{V}% move speed",                    act = "both classes",                    val = function( l ) return speedPct( l ) end },
    [6]  = { eff = "+{V}% headshot damage",               act = "any weapon",                      val = function( l ) return 12 * l end },  -- scope class since v14.12; 4->5%/Lv 2026-08-30; 5->12%/Lv AND max 10->5 on 2026-09-08 (LOCKSTEP with TOD_UPG_HS_PER_LVL, the add_domain max, DOMAIN[6].max above and the dark row below)
    [7]  = { eff = "+{V}% magazine size",                 act = "class primary only",       val = function( l ) return 20 * l end },   -- 30 -> 20/Lv 2026-09-01, lockstep with MAG_STEP in gen_tod_twins.js
    -- [tod] v16.42 (2026-09-02) the user's KILLS-PER-ROUND ladder. Mirrors GSC
    -- scav_kills10 (TOD_SCAV_KILLS10_*, which holds these x10 as tenths):
    -- Lv1..Lv6 = 2.8 / 2.3 / 2 / 1.8 / 1.6 / 1.4 — LOCKSTEP with the GSC table,
    -- change both. (v16.41 4/2.9/2.3/2.0/1.9/1.8 and v16.40 5/3.3/2.6/2.3/2.1/
    -- 1.9 each lasted one build; 2026-08-26 → v16.39 was 1 per 5/4/3/2/1 and
    -- 3 per 2 at Lv6.)
    -- val returns a whole PHRASE rather than a number (the formatter above
    -- tostring()s any non-number, so this is supported): the kills-per-round
    -- reading is the one the user thinks in ("1 bullet every N kills").
    [8]  = { eff = "{V}",                                 act = "primary kills", val = function( l )   -- v15: EVERY class that rolls it keeps it. The v14.13 assault-only scope_class carve-out was deleted when the default flipped to class scope; the 3-arg lane still exists in set_scope/domain_survives_tier but has no user.
                local SCAV_KPR = { 2.8, 2.3, 2, 1.8, 1.6, 1.4 }
                local kills = SCAV_KPR[ math.min( math.max( l, 1 ), 6 ) ]
                local pct = math.floor( 100 / kills + 0.5 )   -- share of a round banked per kill
                return "1 reserve round per " .. kills .. " kills"
            end },
        -- =======================================================================
    -- ⚠️ KEEP THESE SHORT. THE PANEL DOES NOT WRAP, IT OVERLAPS.
    -- User 2026-09-03, with a screenshot: *"Looks how horrible it is. We need
    -- to remember that this has to be short and concise. This has happened
    -- multiple times where our description is super long and overlaps"* — and
    -- it HAD, repeatedly, because every new domain wrote its row without ever
    -- seeing the panel full.
    --
    -- THE BUDGET, measured off AetheriumStartMenu's real rows: the column is
    -- COL_W 369 with eff at scale 0.90 and act at 0.79, so roughly
    --     eff <= 40 characters, act <= 46
    -- with {V} counted at its widest substitution. Over that the line runs
    -- past the column and paints on top of the row below.
    --
    -- THE TRAP THAT MADE THIS RECUR: a row whose eff is literally "{V}" hides
    -- its real length inside the val FUNCTION, so eyeballing the table finds
    -- nothing. TRAILBLAZER read 4 characters here and rendered 76 on screen.
    -- tools/lint_tod_lua.js now measures BOTH the literals and the strings
    -- built inside val, and fails the build over budget.
    -- =======================================================================
    -- 9 MOBILITY: RETIRED v15 — unreachable, left inert (see the DOMAIN note).
    [9]  = { eff = "+{V}% move speed",                    act = ""          ,                                  val = function( l ) return 5 * l end },
    [10] = { eff = "1 round into the mag every {V}s",     act = "even with the gun stowed",        val = function( l ) return math.max( 0.2, 1.0 - 0.0889 * ( l - 1 ) ) end, dec = 1 },
    -- 11 ECHO ROUNDS: domain REMOVED 2026-08-23. No detail row — unreachable.
    -- 12 REGEN: domain REMOVED v14.11 (2026-08-30). No detail row — unreachable
    -- (the 11/22/30 pattern; a fresh run can never own it).
    -- v18.9: the eff still read "per blade kill" after 2026-09-05 made it ONE
    -- heal per swing however many bodies the swing killed, and the empty act line
    -- had nowhere to say so. (A THOR'S THUNDER proc can still take a swing's heal
    -- to zero by stamping tod_no_leech on the primary victim first - that is a
    -- design call, not a copy fix, and is left alone here.)
    [13] = { eff = "heal +{V} hp on a melee kill",        act = "once per swing, not once per body", val = function( l ) return ({0,4,6,8,9,10})[ math.min(l,5) + 1 ] or 10 end },
    -- CLEAVE is NOT a chance: the ladder passes 100% at Lv3 (one guaranteed
    -- extra target) and caps at 200% = +2. The wording must never say "chance".
    -- 14 v14.11: cap 3 — one banked extra at Lv3 (the 200% clamp is dead belt).
    [14] = { eff = "{V}% chance to hit 1 extra zombie",   act = "melee hits, within 60 units",            val = function( l ) local v = math.floor( 100 * l / 3 + 0.5 ) if v > 200 then v = 200 end return v end },
    [15] = { eff = "-{V}% time between shots",            act = "MSMC only",                       val = function( l ) return ( { 8, 16, 24 } )[ l ] end },
    [16] = { eff = "-{V}% reload, swap and ADS time",     act = "class primary only",              val = function( l ) return ( { 15, 25, 35 } )[ l ] end },
    [17] = { eff = "-{V}% recoil",      act = "class primary only",              val = function( l ) return ( { 15, 30 } )[ l ] end },   -- v16.50 RECOIL_STEP [1,0.85,0.70]
    [18] = { eff = "-{V}% time between swings",              act = "while your melee weapon is held",          val = function( l ) return ({0,10,16,20,23,26})[ math.min(l,5) + 1 ] or 26 end },
    -- PENETRATION is a penetrateType TIER, not a number. Lv0 = small (BELOW
    -- stock) but a row only renders at lvl > 0, so index straight by level.
    [19] = { eff = "bullets pierce {V} cover",            act = "not on the HK21",     val = function( l ) return ( { "medium", "large" } )[ l ] end },
    -- [tod v16.3] numbers re-read off _tod_upgrades.gsc TOD_THOR_DMG_BASE/PER_LV
    -- (0.04 + 0.12/Lv = 16..64%) and TOD_THOR_CD_MAX/STEP/MIN (4.5s -> 1.5s);
    -- this row had kept the pre-nerf 20-80% / 3.8-1.3s.
    -- v18.9: it never said the strike SKIPS bosses and elites (thor_strike
    -- excludes the boss triad outright - Panzer, Protector, Reaver, hound). The
    -- strike still visibly fires on them, because it is centred on the melee
    -- victim's own origin, so a slasher reading "64% of enemy max hp" reasonably
    -- concluded this was their boss answer. Same omission already fixed on
    -- TRAILBLAZER's row.
    [20] = { eff = "lightning for {V}% of enemy max hp",  act = "Stormbreaker; bosses immune; 4.5-1.5s cd",  val = function( l ) return 4 + 12 * l end },
    [21] = { eff = "shoot without breaking sprint", act = "" },
    -- 22 CHAIN LUNGE: domain REMOVED 2026-08-24. No detail row — unreachable.
    -- 23 v14.11: both halves share one number, so one {V} substitution covers
    -- them (string.gsub replaces every occurrence).
    -- 23 v16.50: stage table 16/28/38/46/52 — LOCKSTEP with TOD_RNG_PCT_L1..L5 (_tod_runandgun.gsc) and TOD_UPG_RNG_DMG_L1..L5 (_tod_upgrades.gsc).
    [23] = { eff = "{V}% of shots free, +{V}% damage",    act = "per bullet while running or sprinting",      val = function( l ) local t = { 16, 28, 38, 46, 52 } return t[ math.max( 1, math.min( 5, l ) ) ] end },
    -- 24 CLASS TIER: `lvl` is the plain tier number — refresh_upgrade_list
    -- sends it raw, and since v14.35 it sends it FROM TIER 1 (it used to start
    -- at 2), because this row is now where a player reads what the NEXT
    -- promotion costs. The pause lane does not carry the CLASS, so this line
    -- stays class-agnostic on purpose; naming the gun here would need a new
    -- channel.
    --
    -- `act` IS A FUNCTION HERE — the only row that does that. It states the
    -- requirement for the promotion you have not taken yet, so it has to change
    -- with the level the way `eff` does.
    --
    -- ⚠ LOCKSTEP with GSC TOD_TIER2_FLOOR / TOD_TIER3_FLOOR in
    -- _tod_upgrades.gsc. These floor numbers are the gate's, not this file's —
    -- the client cannot ask the server for them (the clientuimodel pool is at
    -- its 61-bit ceiling), so they are copied, and a change to the gate is not
    -- finished until this line changes with it. Same discipline as RUN AND
    -- GUN's constants across _tod_upgrades / _tod_runandgun.
    [24] = { eff = "your class gun is tier {V} of 3",
             -- v18.9: the act line stated the REQUIREMENT and never the COST.
             -- Three separate Workshop reports describe the same surprise - the
             -- promotion hands back the next weapon UNPACKED, and on the spire it
             -- silently resets the PACK II / PACK III stack as well (pap_tier is
             -- keyed on the gun's stem), up to 80,000 points. The card art carries
             -- no warning and the LUI fallback that once did is dead behind
             -- USE_TIER_CARD_ART, so this row and the promotion toast in
             -- _tod_upgrades.gsc are the whole notice.
             -- "PaP" not "Pack-a-Punch": the act line's budget is 46 characters
             -- and the long form does not fit with the cost appended. The FLOOR
             -- NUMBERS ARE LOCKSTEP with tier_floor_ok - do not edit them here.
             act = function( l )
                 if l >= 3 then
                     return "final tier"
                 elseif l == 2 then
                     return "tier 3: PaP + floor 30; new gun unpacked"
                 end
                 return "tier 2: PaP + floor 10; new gun unpacked"
             end,
             val = function( l ) return l end },
    -- 25 ADRENALINE: THREE effects off ONE number since v17.85 (speed, bullet
    -- damage, and a heal of DOUBLE that % of max health on trigger), so the row
    -- switched from a "+{V}%" template to the composed "{V}" form — the heal is
    -- instant and the other two last 3s, which no single template sentence can
    -- say. LOCKSTEP with adren_bonus() in _tod_upgrades.gsc (lvl *
    -- TOD_ADREN_PCT_PER_LV, +TOD_DARK_ADREN_ADD when dark) and with
    -- adren_cooldown_ms (MAX 20000 - 2000/lv, floor 12000). The heal prints
    -- 6*l because it is adren_bonus() x TOD_ADREN_HEAL_MULT (2.0) -- if that
    -- define moves, this 6 and the dark 50 below move with it.
    [25] = { eff = "{V}",  act = function( l ) return "3 kills in 1.5s; 3s burst, " .. math.max( 12, 20 - 2 * ( l - 1 ) ) .. "s cooldown" end,            val = function( l ) return "+" .. ( 3 * l ) .. "% speed and damage, heals " .. ( 6 * l ) .. "%" end },
    [26] = { eff = "up to +{V}% bullet damage",           act = "Death Machine only; 3.75s ramp, 3s packed", val = function( l ) return 5 * math.min( l, 5 ) end },
    -- 27 KILL RELOAD: REMOVED 2026-09-01. Kept as a nil-safe id-keyed row.
    [27] = { eff = "REMOVED", act = "retired 2026-09-01", val = function( l ) return 0 end },
    -- 28 IMPACT ROUNDS: REMOVED 2026-08-31. Kept as a nil-safe id-keyed row.
    [28] = { eff = "REMOVED", act = "retired 2026-08-31", val = function( l ) return 0 end },
    -- 29 SUPPRESSING FIRE nerfed 2026-08-24: 25/40/55 -> 12/24/36, so the val
    -- is a flat 12 per level now (it was 15*l + 10). The CARD ART carries these
    -- numbers baked in and is stale until re-baked — see the art work list.
    [29] = { eff = "the zombie you hit moves {V}% slower", act = "HK21 only; lasts 1.5s",           val = function( l ) return 12 * l end },
    -- 30 MEAT GRINDER: domain REMOVED 2026-08-23. No detail row — unreachable.
    [31] = { eff = "+{V}% melee damage",                  act = "Katana only; swing within 0.4s of sprinting",       val = function( l ) return 50 * l end },
    -- 32 SPRINT ARMOR: REMOVED 2026-08-31. Nil-safe id-keyed row.
    [32] = { eff = "REMOVED", act = "retired 2026-08-31", val = function( l ) return 0 end },
    [33] = { eff = "heal {V}% of max hp per second",      act = "MP5 only; while sprinting",       val = function( l ) return 1 * l end },   -- MP5 since v14.11 (was MP7)
    -- 34 MOMENTUM: domain REMOVED v14.11 (2026-08-30). No detail row — unreachable.
    -- 35 GIANT SLAYER: the multiplier is ADDITIVE with DAMAGE and HEADSHOT, and
    -- pays out only against the boss/elite triad (Panzer, Rogue Protector,
    -- Reaver) — never on the horde. Both boss-damage lanes call
    -- tod_upgrades::boss_damage_bonus, so there is one number, not two.
    [35] = { eff = "+{V}% damage to bosses and elites",   act = "any weapon",         val = function( l ) return 12 * l end },  -- 4->5%/Lv 2026-08-30; 5->8% then 8->15%/Lv 2026-08-31 (v15); 15->12%/Lv 2026-09-02 (v16.50). LOCKSTEP TOD_UPG_BOSSDMG_PER_LVL
    -- 36 BACK ARMOR: multiplies AFTER DMG REDUCTION and SPRINT ARMOR (all three
    -- stack multiplicatively). The arc is 140 degrees measured off the player's
    -- VIEW forward, flattened to 2D — 70 degrees either side of due back.
    [36] = { eff = "-{V}% damage taken from behind",      act = "",       val = function( l ) return ladder5( l ) end },
    -- 37 FORCED MARCH (2026-08-24): the assault's only speed domain, and it
    -- rides the same +5%/Lv lane as SPRINT (5) and MOBILITY (9) in
    -- _tod_upgrades::apply_move_speed — one owner, three doors.
    [37] = { eff = "+{V}% move speed",                    act = "AK-47 only",                      val = function( l ) return speedPct( l ) end },
    -- 38/39 (v14.11): read back off the apply sites — apply_upgrade +
    -- body_systems_loop's want-floor for 38, recovery_loop for 39.
    [38] = { eff = "+{V} max health",                     act = "",                                  val = function( l ) return ladder5( l ) end },
    [39] = { eff = "health regen starts {V}% sooner",            act = "after the last hit taken",        val = function( l ) return ladder5( l ) end },
    -- 40 PERK SLOTS: REMOVED 2026-09-03 (v16.80). Kept as a nil-safe id-keyed row.
    -- 40 PERK SLOTS (restored v17.3). Base 4 from TOD_PERK_SLOT_BASE; the
    -- value shown is the TOTAL cap, not the bonus, because that is the number
    -- a player checks against the perks they are carrying.
    -- The `act` line said "base 4, +1 per level" until 2026-09-11 and that was
    -- the exact phrase the user reported players mis-parsing as FLOOR level.
    -- The eff line above was never the problem — it already prints the live
    -- total, which is the number a player checks against the perks they are
    -- carrying — so act now just names the total WITHOUT this upgrade and no
    -- reading of it involves the tower at all.
    -- v19.38: IN THE SPIRE the server floors every player at the whole roster
    -- (perk_slot_limit, TOD_PERK_ROSTER 9 — LOCKSTEP with SPIRE_PERK_ROSTER
    -- below) and every perk is granted, so "carry up to 4+l" was wrong there.
    -- CoD.TodSpireMode is set by the gauge's mode handler in this file.
    [40] = { eff = "carry up to {V} perks",
             act = function( l ) if CoD.TodSpireMode then return "every perk is yours in the spire" end return "4 without this upgrade" end,
             val = function( l ) if CoD.TodSpireMode then return SPIRE_PERK_ROSTER end return 4 + l end },
    -- v16.49: the level IS the carry cap (1/2/3 Cymbal Monkeys); MAX AMMO gives
    -- +1 at every level, it does NOT refill (v14.61). val prints the CAP the
    -- player holds, the PERK SLOTS idiom — "carry up to 3" beats "+1".
    -- LOCKSTEP: TOD_DISTRACT_MAXAMMO_ADD / TOD_DISTRACT_MAX_CARRY / max = 3 above.
    [41] = { eff = "carry up to {V} Cymbal Monkeys",     act = "Press ^3[{+smoke}]^7 to throw - MAX AMMO gives +1", val = function( l ) return l end },   -- v19.60: the monkey is the tactical-slot throw (_tod_distraction)
    [42] = { eff = "+{V}% move speed",                   act = "after 0.8s sprinting; damage breaks it", val = function( l ) return fullSteamPct( l ) end },   -- v16.8: ladder x1.2 via fullSteamPct; the damage-break rule (v16) was missing from this sentence
    -- ATHLETE carries THREE numbers, so it uses the "{V}" string form (same shape
    -- as 41) rather than one interpolated percent, and the third rides the `act`
    -- line as a FUNCTION of the level (the CLASS TIER row's idiom — CoD.TodDomainDesc
    -- pcalls it). LOCKSTEP: the 10, the 25, the 20 + 8/Lv and the 90 + 30/Lv
    -- here are TOD_ATH_SLIDE_PER_LV, TOD_ATH_JUMP_PER_LV, TOD_ATH_AIR_STEER_MAX_BASE
    -- + _PER_LV and TOD_ATH_AIR_TURN_BASE + _PER_LV in _tod_athlete.gsc (v16.23
    -- air steering; v16.28 strafe-only; v16.33 the steer budget per jump and the
    -- eased 120..240 rate).
    -- 44 GUNSLINGER (v16.51): val prints the domain's own bonus; the class
    -- baseline (2.25x) is not the domain's and is not printed here.
    [44] = { eff = "+{V}% sidearm damage vs bosses", act = "class secondary only", val = function( l ) return 30 * l end },
    -- 46 TRAILBLAZER (v16.62): three numbers, so a composed string like ATHLETE.
    -- LOCKSTEP with _tod_upgrades.gsc, and this row is the ONLY place a player
    -- reads any of them (the baked card carries no figures, generic-card-text
    -- rule) — so a retune that skips it ships a lie:
    --     trail_pct()        = 1 + L                    -> (1 + L) %/s
    --     trail_slow_mult()  = 1 - (0.03 + 0.045*L)     -> (3 + 4.5*L) % slower
    --     trail_life_ms()    = 1500 + 500*L             -> (1.5 + 0.5*L) s
    -- v16.94 cut the burn hard so the trail cannot be farmed and added the slow
    -- in its place; v17.84 DOUBLED the slow (user: "double the slow rate") and
    -- made the base version SLOW ELITES WITHOUT BURNING THEM, which is what the
    -- act line now has to say. The old act read "bosses immune", which was true
    -- of the damage and is now false of the effect as a whole — the exact way a
    -- player ends up believing the trail does nothing to a Panzer.
    [46] = { eff = "{V}", act = "while sprinting; elites slowed, not burned", val = function( l ) local L = math.min( math.max( l, 1 ), 5 ) return "burns " .. ( 1 + L ) .. "%/s, slows " .. pctStr( 3 + 4.5 * L ) .. "%, lasts " .. string.format( "%.1f", 1.5 + 0.5 * L ) .. "s" end },
    [43] = { eff = "{V}",                                act = function( l ) return "steer " .. ( 20 + 8 * l ) .. " deg; wall-run improves per Lv" end,     val = function( l ) return "+" .. ( 10 * l ) .. "% slide speed, +" .. ( 25 * l ) .. "% jump height" end },
    -- 45 RIOT SHIELD (v16.63): two numbers, so the "{V}" string form like 41/43.
    [45] = { eff = "{V}",                                act = "hold or wear it; recharges when broken", val = function( l ) return shieldHp( l ) .. " HP shield, back in " .. shieldRecharge( l ) end },
    -- 47 DEADSHOT (v16.64): one level, no number — the whole value is the state.
    [47] = { eff = "{V}",                                act = "controller only",                      val = function( l ) return "aim locks onto zombie heads" end },
    -- 48..51 THE MAGE. MIRRORS the TOD_MAGE_* defines in the element module.
    -- The cards bake NO figures (generic-card-text rule) and 48..51 draw no
    -- plate, so these four rows are the ONLY place a player reads any of these
    -- numbers. A retune that skips them ships a lie.
    -- lint_tod_lua.js caps eff at 40 chars and act at 46 AND MEASURES THE
    -- STRING LITERALS INSIDE THESE val CLOSURES. Re-measure before rewording.
    [48] = { eff = "{V}", act = "wind blast; elites take a tenth",
             val = function( l ) local L = math.min( math.max( l, 1 ), 6 )
                 return ( { 160, 180, 200, 220, 250, 288 } )[ L ] .. "u blast, "
                     .. ( { 60, 54, 48, 42, 36, 30 } )[ L ] .. "s recharge" end },
    -- v19.26 LOCKSTEP with _tod_mage_elements: FIRE_DMG_PER_LV 0.15, the elite
    -- burn BURN_PCT_PER_LV 0.5 every BURN_TICK_MS 2 s; ice ICE_SLOW_MULT 0.45
    -- minus 0.03 per level, 1.0 s + 0.4 s per level, ELITES ONLY for both.
    [49] = { eff = "fire staff +{V}% damage", act = function( l ) local L = math.min( math.max( l, 1 ), 6 )
                 return "burns elites " .. ( 0.5 * L ) .. "% health per 2s" end,
             val = function( l ) return 15 * math.min( math.max( l, 1 ), 6 ) end },
    [50] = { eff = "ice staff +{V}% damage", act = function( l ) local L = math.min( math.max( l, 1 ), 6 )
                 return "slows elites " .. ( 20 + 2.5 * L ) .. "% for " .. ( 1.0 + 0.4 * L ) .. "s" end,
             val = function( l ) return 15 * math.min( math.max( l, 1 ), 6 ) end },
    -- RAPID FLAME reads as a SHOT TIME, not a percentage, because that is the
    -- number a player can feel: 1.57s between fire staff shots down to 0.79s.
    -- Linear on the cooldown, so {V} is 1.573 * (1 - 0.10 * level).
    [58] = { eff = "thunder slam recharges in {V}s", act = "Press ^3[{+smoke}]^7 to slam - leap in with Stormbreaker",
             val = function( l ) return 55 - 10 * math.min( math.max( l, 1 ), 3 ) end },
    [57] = { eff = "fire staff shoots every {V}s", act = "twice the shots at Lv5; stacks with FIRE BLAST",
             val = function( l ) local L = math.min( math.max( l, 0 ), 5 )
                 return string.format( "%.2f", 1.573 * ( 1 - 0.10 * L ) ) end },
    -- ABILITY LINES READ "Press <key> to <verb> - <what it does>" (v19.60, user
    -- 2026-09-27: "Abilities should say Press <key> to use - <Description> ...
    -- for mage ... Press E to Cast - Description"). ONE bind token per line; the
    -- pause menu (TodActLine) splits the line at it: the words either side are
    -- the map's typeface, the key is the live key name or button picture.
    -- Every pressed ability has one: BLINK, HEALING AURA, ARCHMAGE (and their
    -- Dark rows below), DISTRACTION, THUNDER SLAM. The tokens stay OUT of
    -- `eff`: the scoreboard prints eff through the same table.
    [55] = { eff = "blink {V} units forward", act = function( l ) local L = math.min( math.max( l, 1 ), 5 )
                 return "Press ^3[{+smoke}]^7 to cast - " .. ( ( 9 - L ) * 1.8 ) .. "s recharge; Lv3 stores 2" end,   -- x1.8 since 2026-09-09; the elite-kill refund is gone
             val = function( l ) local L = math.min( math.max( l, 0 ), 5 )
                 return 280 + 40 * L end },
    [53] = { eff = "bolt arcs to {V} more zombies",
             act = function( l ) local L = math.min( math.max( l, 1 ), 10 ) return pctStr( 50 * ( 1 + 0.05 * L ) ) .. "% hit damage per arc; never the Panzer" end,
             val = function( l ) return 1 + math.floor( math.min( math.max( l, 1 ), 10 ) / 2 ) end },
    -- v19.60: the speed moved up beside the damage so the key line fits as
    -- "Press <key> to activate - needs a full mana bar" with the engine's
    -- longest key name (test_pause_text_all).
    [54] = { eff = "{V}",
             act = "Press ^3[{+speed_throw}]^7 to activate - needs a full mana bar",
             -- LOCKSTEP with arch_damage_mult / arch_speed_scale in
             -- _tod_mage_elements.gsc (damage 1.25..1.85 - the 2026-09-09
             -- ceiling pass - and speed +15..+30). Move both or the menu lies.
             val = function( l ) local L = math.min( math.max( l, 1 ), 6 )
                 local M = { 1.25, 1.40, 1.55, 1.65, 1.75, 1.85 }
                 local S = { 15, 19, 23, 26, 28, 30 }
                 return "x" .. string.format( "%.2f", M[ L ] ) .. " damage, +" .. S[ L ] .. "% speed, sprint fire" end },
    [56] = { eff = "staff swaps and raises {V}x faster", act = "applies to every staff you hold",
             val = function( l ) return 3 end },
    -- Level 1 stays at 10 HP/s and 50% resistance; each further level adds
    -- 1 HP/s and 2 percentage points. Existing radius/charges/revive retained.
    [52] = { eff = "{V}",
             act = function( l ) local L = math.min( math.max( l, 1 ), 6 )
                 local n = ( { 1, 1, 2, 2, 3, 3 } )[ L ]
                 return "Press ^3[{+frag}]^7 to cast - " .. n .. ( ( n == 1 ) and " use" or " uses" ) .. "; Lv6 revives" end,
             val = function( l ) local L = math.min( math.max( l, 1 ), 6 )
                 -- 2026-09-09 x0.65: LOCKSTEP TOD_MAGE_HEAL_HP_PER_SEC 6.5 + 0.65/Lv, TOD_MAGE_AURA_DR 0.675 - 0.013/Lv
                 -- v19.60: the radius (256..416u) moved up from the key line
                 return string.format( "%.1f", 5.85 + 0.65 * L ) .. " HP/s, " .. math.floor( 31.2 + 1.3 * L + 0.5 ) .. "% resist, 5s, "
                     .. ( { 256, 288, 320, 352, 384, 416 } )[ L ] .. "u" end },
}

-- PUBLIC — read by AetheriumStartMenu.lua (same client Lua VM, the same way it
-- already reads CoD.TodDomainInfo). Returns the effect line and the activation
-- line for one owned upgrade, or nil,nil when the id has no detail row (a
-- removed domain, or an id added in GSC but not here yet) — the caller then
-- falls back to DOMAIN.desc so a new domain is never rendered blank.
-- [tod v16.57] THE ROUNDING GUARD (user 2026-09-02: "the pause menu was showing
-- something like 10.00000000001 ... All upgrades should round to nearest 10th
-- at max"). Every upgrade line that reaches a setText passes through this:
-- any number carrying TWO OR MORE decimals is rounded to ONE, and a trailing
-- ".0" is dropped. Numeric `val`s were already formatted with %.<dec>f below;
-- this covers string-built lines (SCAVENGER, ATHLETE), the DOMAIN.desc
-- fallbacks and any future row, whichever one produces the artifact.
CoD.TodRoundText = function( s )
    if type( s ) ~= "string" then
        return s
    end
    return ( string.gsub( s, "(%d+)%.(%d%d+)", function( whole, frac )
        local v = tonumber( whole .. "." .. frac )
        if not v then
            return whole .. "." .. frac
        end
        local r = math.floor( v * 10 + 0.5 ) / 10
        local out = string.format( "%.1f", r )
        return ( string.gsub( out, "%.0$", "" ) )
    end ) )
end

-- =============================================================================
-- DARK UPGRADE READOUTS (v17.10). One row per domain that can hold a dark
-- upgrade — 24 of them, the mirror of set_no_dark() in _tod_upgrades.gsc.
--
-- WHY A PARALLEL TABLE AND NOT A FLAG INSIDE DETAIL: every row above is a
-- FUNCTION of the level, and a dark upgrade is not a level. Threading a second
-- argument through 37 existing closures to serve 24 of them would touch every
-- row that does not need it, which is how the ATHLETE and TRAILBLAZER rows
-- picked up their lockstep bugs. These override; nothing above changes.
--
-- ⚠️ KEEP THEM SHORT. Same rule as DETAIL: the panel does NOT wrap, it
-- OVERLAPS (user 2026-09-03, with a screenshot). lint_tod_lua.js measures these.
--
-- LOCKSTEP with the TOD_DARK_* defines in _tod_upgrades.gsc. This table is the
-- ONLY place a player ever reads a dark number — the card art is generic by the
-- generic-card-text rule, so if these disagree with the GSC the player is told
-- the wrong thing and nothing catches it.
local DARK = {
    [53] = { val = function( l ) return 2 + math.floor( math.min( math.max( l, 1 ), 10 ) / 2 ) end }, -- Dark adds one arc (two until 2026-09-09)
    -- THE MAGE'S DARK RUNGS (2026-09-09). LOCKSTEP with _tod_mage_elements:
    -- TOD_MAGE_FIRE_DARK_ADD / _ICE_DARK_ADD 0.50, TOD_MAGE_HEAL_DARK_*,
    -- TOD_MAGE_ARCH_DARK_MULT/_SECS/_SPEED, blink_capacity's dark third charge.
    [49] = { val = function( l ) return 15 * math.min( math.max( l, 1 ), 6 ) + 50 end },   -- FIRE BLAST  +90 -> +140 (20/lv until v19.26)
    [50] = { val = function( l ) return 15 * math.min( math.max( l, 1 ), 6 ) + 50 end },   -- ICE SHATTER +90 -> +140
    [52] = { val = function( l ) return "13 HP/s, 42% resist, 5s, 416u" end },             -- HEALING AURA seventh rung (x0.65 pass); radius capped at Lv6 (dark keeps it)
    [54] = { val = function( l ) return "x" .. string.format( "%.2f", 1.85 + 0.50 ) .. " damage, +45% speed, 20s" end },   -- ARCHMAGE x1.85 -> x2.35, 16 -> 20 s; act = the plain row's
    [55] = { act = function( l ) local L = math.min( math.max( l, 1 ), 5 )
                 return "Press ^3[{+smoke}]^7 to cast - " .. ( ( 9 - L ) * 1.8 ) .. "s recharge; stores 3" end,
             val = function( l ) return 280 + 40 * math.min( math.max( l, 0 ), 5 ) end },          -- BLINK a third charge
    [1]  = { val = function( l ) return 10 * l + 50 end },                       -- DAMAGE      +100 -> +150
    [2]  = { val = function( l ) return drPct( l ) + 10 end },                   -- DMG REDUCTION +10 points on the class cap
    [3]  = { val = function( l ) return 5 * l + 50 end },                        -- BOUNTY      +50 -> +100
    -- [4] LUCK: no dark step since 2026-09-05 (set_no_dark in the GSC).
    [5]  = { val = function( l ) return speedPct( l ) + 15 end },                -- SPRINT      +33 -> +48
    [6]  = { val = function( l ) return 12 * l + 25 end },                       -- HEADSHOT    +60 -> +85  (was 5*l+25 = +50 -> +75 until the 2026-09-08 12%/Lv x 5 pass; the dark STEP is still +25)
    [8]  = { val = function( l )                                                 -- SCAVENGER   -40% of the kills you need
                local SCAV_KPR = { 2.8, 2.3, 2, 1.8, 1.6, 1.4 }
                -- the GSC holds these in TENTHS and int()s the product, so 2.8 -> 1.6,
                -- not 1.68. Match that truncation or the menu overstates what you need.
                local kills = math.floor( SCAV_KPR[ math.min( math.max( l, 1 ), 6 ) ] * 6 ) / 10
                return "1 reserve round per " .. string.format( "%.1f", kills ) .. " kills"
            end },
    [10] = { val = function( l ) return "0.14" end },                            -- BULLET FEED 5.0 -> 7.0 rounds/s
    [13] = { val = function( l ) return 25 end },                                -- LEECH       flat 25 HP (one heal per swing)
    [14] = { eff = "always hits 2 extra zombies",                                -- CLEAVE      a guaranteed 2nd extra
             val = nil },
    [20] = { act = "Stormbreaker only; 1.0s cooldown",                           -- THOR        +50% on every term
             val = function( l ) return math.floor( ( 4 + 12 * l ) * 1.5 + 0.5 ) end },
    [23] = { val = function( l ) local t = { 16, 28, 38, 46, 52 }                -- RUN AND GUN 52 -> 100
                return ( t[ math.min( math.max( l, 1 ), 5 ) ] or 52 ) + 48 end },
    -- ADRENALINE +15 -> +25, on all three lanes at once (v17.85).
    [25] = { val = function( l ) return "+25% speed and damage, heals 50%" end },
    [26] = { val = function( l ) return 5 * math.min( l, 5 ) + 40 end },         -- OVERDRIVE   +25 -> +65  (dark step 25 -> 40, user 2026-09-08)
    [35] = { val = function( l ) return 12 * l + 20 end },                       -- GIANT SLAYER +60 -> +80
    [36] = { val = function( l ) return ladder5( l ) + 13 end },                 -- BACK ARMOR  -32 -> -45
    [37] = { val = function( l ) return speedPct( l ) + 17 end },                -- FORCED MARCH +18 -> +35
    [38] = { val = function( l ) return ladder5( l ) + 18 end },                 -- VITALITY    +32 -> +50 HP
    [39] = { val = function( l ) return ladder5( l ) + 13 end },                 -- RECOVERY    32 -> 45% sooner
    [42] = { val = function( l ) return fullSteamPct( l ) + 20 end },            -- FULL STEAM  +21.6 -> +41.6
    [43] = { act = function( l ) return "steer " .. ( 20 + 8 * ( l + 2 ) ) .. " deg; wall-run improves per Lv" end,
             val = function( l ) local d = l + 2                                 -- ATHLETE     computes as level 7
                return "+" .. ( 10 * d ) .. "% slide speed, +" .. ( 25 * d ) .. "% jump height" end },
    [44] = { val = function( l ) return 30 * l + 30 end },                       -- GUNSLINGER  +150 -> +180
    -- THE FOUR WEAPON-VARIANT DOMAINS (v17.10). Unlike every row above, these
    -- are not a number in script -- they are a real weapon the player is holding
    -- (gen_tod_twins.js axisMaxUp), and they exist ONLY on the PACKED tier-3 gun
    -- of the class. LOCKSTEP with the step tables in that generator:
    --   MAG_STEP m4 1.9 / HANDLING_STEP h4 0.45 / RECOIL_STEP r3 0.40 / KNIFE_STEP k6 0.54
    [7]  = { act = "AK-47, Pack-a-Punched",       val = function( l ) return 90 end },   -- MAG SIZE   +60 -> +90
    [16] = { act = "MP7, Pack-a-Punched",         val = function( l ) return 55 end },   -- HANDLING   -35 -> -55
    [17] = { act = "AK-47, Pack-a-Punched",       val = function( l ) return 60 end },   -- RECOIL     -30 -> -60
    [18] = { act = "Stormbreaker, Pack-a-Punched", val = function( l ) return 46 end },  -- KNIFE SPEED -26 -> -46
    [45] = { act = "hold or wear it; elite kills -2s recharge",                  -- RIOT SHIELD
             val = function( l ) return "700 HP shield, back in 1:15" end },
    -- TRAILBLAZER — the dark card lifts the elite exemption, so its act line has
    -- to contradict the base row rather than inherit it (v17.84).
    [46] = { act = "while sprinting; elites burned too",
             val = function( l ) return "burns 10%/s, slows 37.5%, lasts 4.0s" end },
}

-- Enabled Dark cards awaiting baked art use the composite DARK text card.
-- 2026-09-09: the four mage rungs that went dark-capable without art join
-- CHAIN LIGHTNING here; HEALING AURA (52) has i_tod_card_mage_heal_dark.
-- When the docs/126 pack lands: zone the card, delete the id here.
local DARK_TEXT_ONLY = { }   -- 2026-09-10: the five Mage dark cards landed (docs/126, third request); HEALING AURA had art already

CoD.TodDomainDesc = function( id, lvl, dark )
    local d = DETAIL[ id ]
    if not d then
        return nil, nil
    end
    -- DARK UPGRADE (v17.10): swap in the dark readout. A SHALLOW COPY, never a
    -- mutation -- DETAIL rows are shared across every player row the pause menu
    -- draws, and writing through one would leak the dark value onto teammates
    -- who do not have it. [14] deliberately clears val by omitting it, so the
    -- copy must not carry the base val forward for that row.
    if dark and DARK[ id ] then
        local o = DARK[ id ]
        d = { eff = o.eff or d.eff,
              act = ( o.act ~= nil and o.act ) or d.act,
              val = o.val,
              dec = d.dec }
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
        -- ⚠️ FUNCTION REPLACEMENT, NEVER A STRING ONE (v17.86, user 2026-09-05:
        -- "I got a UI error when I paused").
        --
        -- In Lua, when gsub's third argument is a STRING, `%` is an ESCAPE: it
        -- must be followed by a digit (a capture) or another `%`. A `%` followed
        -- by anything else -- a space, a slash, a comma, or end-of-string --
        -- raises "invalid use of '%' in replacement string". Our value lines are
        -- FULL OF percent signs ("+15% speed and damage, heals 30%",
        -- "burns 6%/s, slows 34%", "+10% slide speed"), so every one of them was
        -- a live error waiting on the row being owned and the menu being opened.
        --
        -- THE pcall ABOVE DOES NOT COVER THIS. It wraps the val CALL only; the
        -- substitution happens out here, so the throw takes the whole pause menu
        -- with it rather than degrading one row to blank. That is why the symptom
        -- is "the pause menu errored", with nothing pointing at a domain.
        --
        -- A function replacement has NO escape processing: whatever it returns is
        -- inserted verbatim. CoD.TodRoundText below already used the function form
        -- (that is why it never hit this), so this line was the file's one
        -- remaining string-replacement gsub.
        --
        -- The bug is OLDER than the row that exposed it: ATHLETE (43) has returned
        -- a percent-bearing string here since v16.23 and TRAILBLAZER (46) since
        -- v16.94. v17.85 put ADRENALINE (25) -- a far more commonly owned domain --
        -- on the same lane, which is what made it show up. Do not "fix" this by
        -- rewording a row; any row may legitimately contain a percent sign.
        eff = string.gsub( eff, "{V}", function() return v end )
    end
    eff = CoD.TodRoundText( eff )
    -- `act` is normally a plain string; the CLASS TIER row (24) makes it a
    -- FUNCTION of the level, because what it states is the requirement for the
    -- promotion you have NOT taken yet. Same pcall guard as `val` for the same
    -- reason — a level outside the expected range must not error the whole
    -- pause menu — and a failed call degrades to no activation line rather than
    -- to a wrong one.
    local act = d.act
    if type( act ) == "function" then
        local okA, a = pcall( act, lvl )
        act = ( okA and type( a ) == "string" and a ) or nil
    end
    return eff, act
end

-- [tod] shared with AetheriumStartMenu.lua (same client Lua VM): the pause
-- menu's "YOUR UPGRADES" panel renders CoD.TodOwned (accumulated below from
-- the GSC tod_upg_sync LuiNotifyEvents) using these names.
CoD.TodDomainInfo = DOMAIN

-- ---------------------------------------------------------------------------
-- [tod v17.11, 2026-09-04] THE DARK ROW PLATE — ONE OWNER, TWO SCREENS.
--
-- The owned-upgrades list is drawn TWICE from the same CoD.TodOwned: the pause
-- menu (AetheriumStartMenu.lua) and the scoreboard
-- (AetheriumWidgets/AetheriumScoreboard.lua). v17.10 taught the pause menu to
-- draw a dark row and did not teach the scoreboard, so the scoreboard read
-- o.dark for the VALUE TEXT and then drew the ordinary blue plate over it —
-- the number changed, nothing said why. User 2026-09-04: "Also check the
-- scoreboard menu as well. Also not wired up correctly."
--
-- The rule lives here, in the menu both screens already depend on for
-- CoD.TodDomainDesc, so there is nothing to keep in lockstep. Returns:
--   image, false  -> draw this red plate as-is
--   image, true   -> draw this ordinary plate and TINT it red
-- setRGB is multiplicative, so the tint can only push toward red and darken —
-- which is the direction wanted, and a complete look rather than a placeholder.
--
-- A CALLER MUST NEVER REACH FOR i_tod_pause_rNN_dark ON ITS OWN: RegisterImage
-- on a missing image is undefined behavior, and the two conditions that decide
-- whether one exists (the flag and the not-baked list) are exactly what this
-- function exists to hold in one place.
--
-- LOCKSTEP: tools/lint_tod_assets.js parses DARK_PLATE_NONE out of THIS file
-- and skips the same ids, so it does not demand plates that were never ordered.
-- Delete an entry the same commit its plate is zoned.

-- OFF until the baked red plates land AND are zoned.
local USE_DARK_PLATE_ART = true
-- Ids with no baked red plate; they fall back to the runtime tint. EMPTY since
-- v17.49 (2026-09-04): the four weapon-variant domains (MAG SIZE 7, HANDLING
-- 16, RECOIL 17, KNIFE SPEED 18) went dark-capable in v17.10 AFTER docs/94
-- scoped the 24-plate batch, sat here on the tint for a day, and the user
-- caught it — "I think it's different from what's in pause menu for dark run
-- and gun" (the tint is multiplicative, so it reddened the WORD too). docs/101
-- delivered the four; every dark-capable row now has a baked plate. Keep the
-- table and the fallback: a future dark domain lands here until its plate is
-- zoned, and lint_tod_assets.js parses this table for GATE A.
local DARK_PLATE_NONE = { } -- EMPTY again since 2026-09-09 late: the six mage red plates landed (docs/126 drop); a future dark domain lands here until its plate is zoned

CoD.TodDarkPlate = function( id, plateMax )
    if not id then return nil, false end
    if plateMax and id > plateMax then return nil, false end   -- text row: no plate to paint at all
    if USE_DARK_PLATE_ART and not DARK_PLATE_NONE[ id ] then
        return string.format( "i_tod_pause_r%02d_dark", id ), false
    end
    -- NO TINT ANY MORE (2026-09-09, user: "Upgrade menu for chain lightning is
    -- wrong. Shows red text"): the runtime tint is multiplicative and reddened
    -- the WORD on the plate, which read as an error. A row with no red plate
    -- now draws its PLAIN plate and the caller prefixes the effect line with
    -- "DARK: " -- the third return value. tint is always false now; kept in
    -- the signature so older callers keep working.
    return string.format( "i_tod_pause_r%02d", id ), false, true
end
CoD.TodOwned = CoD.TodOwned or {}
-- [tod v14.35] The CLASS TIER floor requirement for the deal currently being
-- shown, or 0 when the floor is not what is blocking this player. Written by
-- the tod_upg_tier_need receiver below (the HUD menu, always open) and read by
-- the choice panel while it paints — the same shared-global pattern
-- CoD.TodOwned already uses to cross menus inside this one client VM.
CoD.TodTierNeed = CoD.TodTierNeed or 0

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
-- only layout and the focus/hold/timer overlays.
--
-- THERE IS NO "Lv X > Y" LINE. This header advertised one until 2026-08-30 and
-- it was WRONG — the overlay was removed 2026-08-20 (see the note at the
-- card.Desc construction below, which is authoritative). Two sessions read this
-- comment and concluded the deal screen shows a live value; it does not.
-- NO LUI TEXT IS DRAWN ON THE CARDS AT ALL — PaintCard blanks Tag/Name/Desc and
-- the baked art carries everything, with the rarity gem "+N" carrying the gain.
-- CONSEQUENCE FOR CARD ART: a number that is not baked into the card is not
-- visible at deal time anywhere. Level-aware values live ONLY in the pause menu
-- (CoD.TodDomainDesc -> DETAIL[id].val(lvl)). That is the deliberate trade for
-- level-agnostic art that never needs re-baking on a retune — see docs/47.
-- The composite path below survives as the no-art fallback.
local USE_CARD_SET_ART = true
-- DARK UPGRADES (v17.10) -- the fourth rarity, above ULTIMATE. 37 baked cards
-- (i_tod_card_<slug>_dark) are INSTALLED in source art and PROOFREAD, but they
-- are NOT ZONED, so this flag is OFF and must stay off until they are.
--
-- WHY IT IS A FLAG AND NOT JUST CODE: this file's own contract, at the top --
-- "RegisterImage of a missing image is undefined behavior". Registering 37
-- names with no zone line behind them is the WHITE SQUARE failure, and
-- tools/lint_tod_assets.js hard-codes [regular,super,ultimate] so it would not
-- catch it.
--
-- FLIPPING IT IS A THREE-PART COMMIT, none of which can be skipped:
--   1. zone lines + GDT blocks for the dark cards that can actually be DEALT
--      (27 of the 37 -- the other ten have no dark step, see set_no_dark),
--   2. teach lint_tod_assets.js the fourth rarity, and
--   3. accept the load-RAM bill: cards are uncompressed 768x1152 = 3.375 MiB
--      EACH, so 27 is ~91 MiB on a UI-art set already costing 536 MiB. The
--      cheaper route is ONE shared dark overlay frame (~3.4 MiB) -- that lane
--      is already built here (art.frames / FrameArt, composited ABOVE CardImg)
--      and force-disabled one screen below. docs/92 THE ART has the numbers.
--
-- WITH IT OFF the dark card still deals, still pays, and still sounds different
-- (tod_dark_aura); it simply wears the ULTIMATE artwork with a DARK UPGRADE tag.
local USE_DARK_CARD_ART = true
-- [tod v14.35] CLASS TIER GATE STRIP — the "why is there no tier card in this
-- deal" line under the cards. Images-over-LUI like everything else on this
-- panel: two baked strips (i_tod_tier_gate_2 / _3, one per requirement),
-- prompt + specs in docs/50. LIVE since 2026-08-31: both PNGs are installed in
-- source_data/tod_ui_images/_images, entered in tod_ui_images.gdt and carry
-- their two `image,` lines in the .zone. The user picked explore direction 3
-- (steel pill, amber stacked double chevron — "climb", not "refused"); 420x90,
-- RGBA, verified legible downscaled to its on-screen 280x60 before install.
-- The LUI text below survives as the no-art fallback.
-- [2026-09-02] THE FLOOR -> TIER TABLE. LOCKSTEP with GSC tier_floor_req
-- (TOD_TIER2_FLOOR / TOD_TIER3_FLOOR in _tod_upgrades.gsc). The badge block
-- used to derive the tier as math.floor( need / 10 ) + 1 -- the exact inverse
-- of a 10/20 ladder and nothing else. The day T3 moved to floor 30 (user,
-- docs/72) that arithmetic answered 4, found no strip and would have silently
-- dropped the badge art for every tier-2 player. A floor missing from this
-- table falls back to tier 2 (the text line still shows the real floor).
local TIER_FLOOR_TO_TIER = { [10] = 2, [30] = 3 }
local USE_TIER_GATE_ART = true
-- [tod v16] CLASS BADGE (docs/59, user: "players also want an update to the
-- upgrade menu that shows what class you are playing as"). Four baked plates,
-- 420x90, drawn 280x60 in the panel's left gutter -- the exact mirror of the
-- luck badge on the right, same chassis. Costs ZERO clientuimodel bits: the
-- class rides the int-only LuiNotifyEvent lane, same as tod_upg_tier_need.
-- [tod docs/114] THIS FILE CARRIES NO MAGE FLAG, DELIBERATELY (2026-09-07).
-- User: *"make sure that all the changes you're making are behind a singular
-- flag ... we don't want those to intersect at all."* A MAGE_ART local was
-- here for one afternoon and has been removed: it gated exactly one line
-- (TCLS[ 5 ] = "mage") that cannot be turned on until the mage tier-card art
-- is baked and zoned, so it bought nothing today and cost a fourth flag.
--
-- WHAT TO ADD WHEN THAT ART LANDS (docs/116 has the same list):
--   * TCLS[ 5 ] = "mage" beside the TCLS table below
--   * an art.classPlate[ 5 ] entry, IN THE SAME BUILD as its zone line --
--     lint_tod_assets GATE A strips comments and ignores flags, so a
--     literal "i_tod_*" name cannot sit in this file before its zone line
--     exists, guarded or not. Proven 2026-09-07.
local USE_CLASS_BADGE_ART = true
-- [tod v18.10] THE LUCK LEGEND -- 420x90 drawn 280x60, the luck badge's own
-- chassis, sitting immediately under it and captioning it in two words. The bar
-- was on screen with its payoff written nowhere in the game: this row's DETAIL
-- line explains how to RAISE luck, the HUD art says "LUCK", and the badge says
-- "LUCK 60% BOOSTED" and stops one noun short. A player asked outright in the
-- Workshop comments on 2026-09-06 and had to be answered on Steam.
--
-- THE NEUTRAL (steel) VARIANT WAS CHOSEN over the amber one on purpose: the
-- badge above it recolours with the fill (gold at 100%, green at 50%), so a gold
-- caption would only look right at full. Steel sits correctly at every value.
local USE_LUCK_LEGEND_ART = true
-- [tod v16.32, KBM audit — docs/69 §6] THE HINT PLATES DRAW THE LIVE BINDS.
-- The baked plates carry the DEFAULT keys (MOUSE1/MOUSE2/V/SPACE, an Xbox
-- "A"), so a rebinder, a PlayStation-layout pad and a pad player before the
-- first d-pad press all read the wrong thing. With this on, the plate is the
-- BLANK frame (i_tod_hint_frame, files (96).zip) and the key line is LUI text
-- carrying the engine's [{+bind}] tokens, which expand to the key or pad glyph
-- bound RIGHT NOW on THIS device — the mechanism every stock "Hold [X]" hint
-- rides and the one PromptDefault.lua's SetFooter uses. The baked keyed plates
-- (re-baked with F in the same drop) stay as the flag-off look; the LOCKED
-- plate stays baked under both (it names no key).
local USE_HINT_FRAME_ART = true
-- [tod v16.88] BAKED BUTTON GLYPHS (docs/88). User, after seeing the v16.83
-- text plates on a pad: *"Again this needs to show a dpad. Use the <dpad icon>
-- to switch ... the KBM UI is pretty bad"*. The premise the old design rested
-- on was false: the engine renders `[{+bind}]` as a TEXT NAME, never a picture,
-- so a controller player literally read "LT" and "RT". Nine baked images now
-- carry every fixed part; the ONLY engine-drawn thing left on the control UI is
-- the keyboard key NAME, and it sits inside a baked keycap.
--
-- DEVICE RULE — read this before "fixing" it. There is no reliable server-side
-- device read (`GetControllerType()` is documented but unexercised, see
-- docs/88), so the glyph set is chosen by `CoD.TodPad`, the one-way
-- action-slot latch. That latch is NOT a device proof (v16.81: a keyboard
-- binds 3/4 to action slots), so a keyboard player who taps 3 or 4 will see
-- pad glyphs. That is the known, accepted cost of showing a d-pad at all, and
-- it is strictly better than the status quo, where EVERY pad player read
-- letters. The fix is a real device read, not a different guess.
local USE_CARD_GLYPH_ART = true
-- [v17.27] `TOD_KEYCAP_TEXT_SCALE` (v17.4) IS GONE, in both this file and
-- tod_class_select.lua. Keycap text is no longer LUI text at all — it is set in
-- the map's baked typeface by `CoD.TodKeycap`, which MEASURES the string and
-- picks the size. Retired whole rather than left as an unread constant.
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
-- CARDS DRAWN BIGGER (user 2026-08-27: "Some have text that is so hard to
-- read"). The card art is 768x1152 and was being drawn at 213x320 — a 0.277
-- downscale, 2.3x harder than anything else in the UI (the pause header is
-- 0.70, the name plates 0.64, the switch hint 0.61). At that scale the card's
-- SUBLINE — the line carrying qualifiers like "CLASS PRIMARY ONLY" — lands at
-- about 7 virtual px, i.e. ~10px at 1080p and ~7px at 720p. Unreadable inside a
-- 15-second timed pick.
--
-- Now 234x351 — EXACTLY +10% linear (user 2026-08-27: "Only increase card size
-- by 10%. Thats all"). The layout had room for +19%, but 10% is the call; the
-- headroom is recorded here rather than taken.
--
-- 234/351 is EXACTLY 2:3, matching the art's 768/1152, so this is a pure
-- scale-up with no new stretch. Every child element positions off xLo/xHi/
-- CARD_Y0/CARD_Y1 and follows automatically. Nothing else on the menu moves:
--   * TOP  banner ends at y=215                     -> Y0 226 (11px clear)
--   * BOT  hold bar sits at CARD_Y1+39..+43 and must clear the switch-hint
--          plate at y=650                           -> Y1 577, bar ends 620 (30px clear)
--   * RIGHT luck badge starts at x=950              -> 911 (39px clear)
--   * the 74px gap between the two cards is unchanged and both stay centred on
--     x=640.
--
-- This alone takes the subline from ~6.7 to ~7.4 virtual px. It is the smaller
-- half of the fix: the other half is baking the subline larger in the art (see
-- the card-legibility prompt). The two compound, and this half re-bakes nothing.
local CARD_Y0, CARD_Y1 = 226, 577

-- ---------------------------------------------------------------------------
-- [tod v18.32] THE HOLD PLATE, MEASURED OFF ITS OWN PIXELS — twin of the block
-- in tod_class_select.lua, where the full argument and the two bugs it fixes
-- live. `i_tod_hold_plate` is 460x70: bright ink x96..401, the empty gap
-- between "HOLD" and "TO LOCK" at x169..286 (118 wide, centred at 227.5 — two
-- and a half pixels LEFT of the plate's own centre), lettering band y25..42.
--
-- THIS MENU ALREADY HAD THE ASPECT RULE (v16.4, see HintImg below) and its
-- plate is drawn true at 222x34. What it did NOT have is the gap: the keycap
-- was a typed 64 px against a 56 px gap, so it overhung the baked lettering by
-- 4 px each side, exactly as it did on the draft. Both glyph sizes are now
-- arithmetic off these numbers.
-- ---------------------------------------------------------------------------
local PLATE_ASPECT = 460 / 70      -- 6.571. A plate drawn off this is stretched.
local PLATE_GAP_CX = 227.5 / 460   -- 0.4946 — the GAP's centre, not the plate's
local PLATE_GAP_W  = 118 / 460     -- 0.2565 — the widest a glyph may be drawn
local PLATE_INK_CY = 33.5 / 70     -- 0.4786 — the lettering's optical centre
local CARD_AX0, CARD_AX1 = 369, 603
local CARD_BX0, CARD_BX1 = 677, 911

-- ===========================================================================
-- THE CARD REVEAL (v14.52, user 2026-08-31: "like when you pull a super cool
-- camo in csgo or ... apex legends crates ... if a slot is ultimate it can be
-- empty for 0.5s and then grow into its ultimate card and then make an epic
-- noise ... enhance the player experience when they pull upgrade cards").
--
-- IT COSTS ZERO CLIENTUIMODEL BITS. The pool sits at 60 of its PROVEN 61 (see
-- _tod_upgrade_ui.gsc __init__), so a new field was not affordable — and not
-- needed. The reveal is DERIVED from three facts the panel already carried:
--
--   show == 1 AND focus == 0   the reveal is running. This pair is a SERVER
--                              CONTRACT and is unreachable any other way:
--                              every path that raises show to 1 sets focus
--                              1..4 in the same breath, and wait_for_choice
--                              never writes 0. present_choice holds focus at 0
--                              for exactly the length of the reveal.
--   R >= 1 while D == 0        that slot is an EMPTY SOCKET, and R is what it
--                              is charging toward. R == 0 means no card is
--                              coming to that slot at all (a one-card deal).
--   D goes 0 -> N              that slot's card LANDS, now, at rarity R.
--
-- The server separates the R push and the D push by a real wait, so the two
-- can never arrive in one snapshot — which is what makes reading R on the D
-- edge safe. Model callbacks fire in clientfield REGISTRATION order (AD before
-- AR), so without that gap a card would land wearing the last deal's rarity.
--
-- ⚠️ REVEAL_HOLD_MS is LOCKSTEP with TOD_REVEAL_HOLD_* in _tod_upgrade_ui.gsc
-- (ms here, seconds there). The socket's rim ramps over the same span the
-- server waits, so the ramp completes exactly as the card arrives. Drift does
-- not BREAK anything — a short ramp holds its end state, a long one is cut off
-- by the card — it just stops looking deliberate.
-- HALVED in v14.53 with the server's TOD_REVEAL_HOLD_* — see the lockstep note.
local REVEAL_HOLD_MS = { [1] = 50, [2] = 200, [3] = 300 }
-- The flip. MUST stay under the server's SHORTEST gap between two pushes, or a
-- later push's Render lands mid-tween and snaps the card to its end rect. The
-- station runs the whole show at half speed (TOD_REVEAL_LIVE_SCALE), so the
-- real floor is min(GAP, TAIL) * 0.5.
--
-- ⚠️ v14.53 RECOMPUTED, and this is the non-obvious cost of halving the server
-- timings: that floor moved with them, from min(280,300)*0.5 = 140ms down to
-- min(140,150)*0.5 = **70ms**. The old 120ms flip would have been legal on a
-- round event (140ms gap) and SNAPPED AT THE STATION — an animation that
-- silently stops existing in one of the two places it runs, which is the
-- hardest kind of bug to notice. 60ms keeps 10ms of margin everywhere.
local REVEAL_FLIP_MS   = 60
local REVEAL_SOCKET_MS = 55    -- socket blowing apart as the face opens
-- The burst does NOT block anything and is not bound by that floor, so it is
-- cut LESS than half — the user's second note was that the ultimate should hit
-- HARDER, and shrinking its burst in proportion to the pacing would have pulled
-- against that. 380ms still finishes before slot B lands (GAP 140 + HOLD 300).
local REVEAL_FLARE_MS  = { [1] = 0, [2] = 200, [3] = 380 }
-- REGULAR GETS NOTHING ON PURPOSE. If every pull flashes, no pull is special —
-- the whole point is that SUPER and ULTIMATE feel different from the card you
-- see four times an hour. Flare = the one-shot burst; glow = the aura the card
-- keeps for the rest of the panel.
local REVEAL_FLARE_PEAK = { [1] = 0,  [2] = 0.55, [3] = 0.92 }
local REVEAL_FLARE_GROW = { [1] = 0,  [2] = 18,   [3] = 34 }
local REVEAL_GLOW       = { [1] = 0,  [2] = 0.22, [3] = 0.40 }
local REVEAL_GLOW_PAD   = 14   -- how far the aura stands proud of the card
local REVEAL_SOCKET_PAD = 3    -- socket rim thickness

local MAX_LEVEL_TIME_DANGER = 5   -- countdown turns red at this many seconds

-- Per-input wording (user 2026-08-20): controller vs KBM. (PS-vs-Xbox glyphs
-- are not distinguishable on PC BO3 — the engine only knows gamepad vs KBM.)
--
-- [tod v16.3] NO MORE GUESSING (repo review 2026-09-01). This used to ask
-- Engine.IsGamepadEnabled( 0 ) and fall back to CONTROLLER wording when the
-- hook was absent — and keyboard players kept reading "HOLD A" (four Workshop
-- reports, the last one AFTER the 08-24 keyboard fix), because a pad that is
-- merely plugged in answers true and the nil path said controller too. This is
-- a PC-only mod: default to the KEYBOARD plates, and flip to the pad plates the
-- moment the SERVER proves the device off this player's first d-pad press
-- (_tod_upgrade_ui::pad_latch -> "tod_input_pad" int-notify, received below
-- into CoD.TodPad, a client-VM global that outlives the per-life menu rebuild).
-- [tod v17.55] ... AND the bind expansion. The latch alone drew a THIRD control
-- set to every pad player before their first d-pad press: keycap art filled by
-- the engine with "LT" / "RT" / "A". CoD.TodKeycap.PadDevice() reads the pad off
-- the offhand pair's expansion, so a pad now gets pad glyphs from the first
-- frame. ONE reader for all three surfaces; the argument lives in TodKeycap.lua.
-- [tod v18.16] THE THIRD CONTROL SET, FOR THE THIRD TIME. User 2026-09-07:
-- *"all I want is a KBM set and then a D pad and A set ... there's a third one
-- that comes up for left trigger, right trigger, and the a button. I want that
-- completely removed"* — and, decisively: *"It's not that I don't want right
-- trigger left trigger to be able to use for controller. I just don't want the
-- UI to say that."* So LT/RT keep WORKING; they may never be DRAWN.
--
-- WHY v17.55 DID NOT CLOSE IT. That pass put the device read in
-- CoD.TodKeycap.PadDevice() and had every surface call it. Correct, but it is
-- reached through `CoD.TodKeycap ~= nil and ...` — and this menu deliberately
-- pcall-requires that widget, so if the require ever fails the whole test
-- silently returns FALSE. A pad player then gets the KEYBOARD layout, and the
-- engine fills those caps with the pad's own words: LT / RT. The guard for the
-- third set lived inside the thing whose absence causes the third set.
--
-- So the test is twinned HERE, with no dependency on the widget — the same
-- argument the stub above is built on, and the same one CoD.TodKeycap.IsPadName
-- makes; that copy stays the canonical one. Keep them in step.
--
-- [tod v18.32] THE FOURTH TIME, AND THE FIRST ONE WITH A PICTURE OF IT. User
-- 2026-09-08: *"When we show A, LT, and RT why are they inside key caps ... If
-- you are using controller we dont use key caps asset."* The screenshot settles
-- what three passes of lexical matching could not: the engine expands a pad
-- bind into a BUTTON ICON, not the letters "LT". No path in this file draws a
-- pad image and a keycap together, so the icon in that shot came out of the
-- expansion, through the keycap's own text fallback. Matching on spelling was
-- always going to miss it. TodPadGlyph is the structural test — see
-- CoD.TodKeycap.IsPadGlyph for the whole argument; keep the two in step.
local function TodPadWord( tok )
    local s = Engine.Localize( tok ) or ""
    s = s:gsub( "%^%d", "" )
    local cut = s:find( "%s*[,/]" ) or s:find( "%s+[Oo][Rr]%s+" )
    if cut and cut > 1 then
        s = s:sub( 1, cut - 1 )
    end
    s = s:gsub( "^%s+", "" ):gsub( "%s+$", "" )
    s = string.upper( s )
    if s == "" then
        return false
    end
    -- Xbox LB RB LT RT / PlayStation L1 R1 L2 R2, plus any spelled-out form.
    -- Kept for a build that DOES spell the button out; the icon test above is
    -- what actually fires on this engine.
    if s:match( "^[LR][BT12]$" ) then
        return true
    end
    return s:find( "TRIGGER", 1, true ) ~= nil or s:find( "BUMPER", 1, true ) ~= nil
        or s:find( "DPAD", 1, true ) ~= nil or s:find( "D-PAD", 1, true ) ~= nil
end
-- [tod v18.48] KEYBOARD IS THE DEFAULT; A PAD MUST BE PROVEN. User 2026-09-08:
-- *"I thought we decided on starting KBM controls and if controller is detected
-- we use controller controls."* So this returns false unless something POSITIVE
-- says pad, and the only two proofs allowed are ones that cannot misfire toward
-- the pad: the d-pad latch, and a pad BUTTON NAME (LT/RT/LB/RB/L1..R2) in the
-- offhand expansion, which no keyboard key is called.
--
-- TodPadGlyph is NOT consulted here any more — see the note on it above. A test
-- that can be wrong in the direction of "pad" has no business in a function
-- whose default is "keyboard"; it cost the keyboard its whole control set for
-- one build. It still runs, but only at draw time on one keycap's contents.
local function UsingController()
    if CoD.TodPad == true then
        return true
    end
    if CoD.TodKeycap ~= nil and CoD.TodKeycap.PadDevice() == true then
        return true
    end
    -- ...and the widget-free arm, so a failed require cannot resurrect the
    -- third set. The offhand pair only: A/B/X/Y are keyboard key names too.
    return TodPadWord( "[{+smoke}]" ) or TodPadWord( "[{+frag}]" )
end
local function LockHint()
    if UsingController() then
        return "HOLD [ A ] TO LOCK"
    end
    return "HOLD [ SPACE ] TO LOCK"
end
local function SwitchHint()
    if UsingController() then
        -- v14.20: NOT "/ STICK" any more. The server-side panel latches the
        -- device off the first d-pad press and from then on ignores stick, RT,
        -- LT, R3 and X for that player (_tod_upgrade_ui::wait_for_choice), so
        -- the d-pad is the only lane a pad player can rely on. The BAKED pad
        -- hint plate (i_tod_hint_switch_pad) already draws a d-pad glyph alone
        -- and needs no re-bake — this is the no-art fallback catching up.
        -- [tod v18.16] ONE LANE, NOT THREE — twin of the class draft; the
        -- argument lives there. LB/RB still switch, they are just not named.
        return "SWITCH: D-PAD   LOCK: HOLD [ A ]"
    end
    -- v10.19: mouse + F joined (user retest: "keyboard still does nothing" —
    -- the movement/jump reads were never live-verified on KBM; mouse1/mouse2
    -- and USE ride reads the engine core exercises constantly). Arrows work
    -- when bound to movement; the engine exposes no raw-key read.
    -- v10.20: advertise the PROVEN lane only. WASD/arrows reach the server via
    -- GetNormalizedMovement, which reads ~0 under the menu freeze's 0.001
    -- move-speed pin, so they are a bonus and must never be the headline.
    -- Mouse/V/R are action buttons every keyboard binds by default.
    return "SWITCH: [TACTICAL] [LETHAL] or [V]   LOCK: HOLD [ SPACE / F ]"
end

-- [tod v16.32, docs/69 §6] THE OVERLAY LINES drawn over the blank frame when
-- USE_HINT_FRAME_ART is on. Every [{+bind}] token is expanded by the ENGINE
-- into the key or pad glyph bound right now on this device, so the plate
-- follows the player's real device and binds at every render — no latch, no
-- lock-in (user 2026-09-02: "keep detecting and swapping assets"; the server
-- cannot tell which device locked a class, because jump and use exist on
-- both, so a lock-in would prove nothing). The one-way d-pad latch
-- (CoD.TodPad) is used only to SHORTEN the line once the pad is proven —
-- before that the shared lanes (RT/LT/R3, or MOUSE1/MOUSE2/V) are the truth
-- for either device, and D-PAD is named on the line so a pad player finds the
-- lane that arms the latch early instead of fighting the shared ones at the
-- station. ^5 cyan labels / ^3 gold keys / ^7 white: the baked plates' palette.
-- The strings must be set through Engine.Localize at SHOW time — the tokens
-- expand when the string is set, not when it is drawn.
-- [tod v16.83, user 2026-09-03: "our last update made it more confusing and
-- less simplified by adding so much to look at"] ONE LANE PER ACTION, AND ITS
-- DIRECTION.
--
-- WHAT WAS ON SCREEN. Measured against the user's own
-- `players/bindings_0.cfg` (+smoke=E, +frag=G, +melee=V, +gostand=SPACE,
-- +activate=F), a single 15-second deal drew THREE plates, FOUR lines and
-- SEVEN key names for a two-button decision:
--     SWITCH: E / G / V / D-PAD          (plate line 1)
--     LOCK: HOLD SPACE / F               (plate line 2)
--     HOLD SPACE / F TO LOCK             (under the focused card — the SAME
--                                         instruction, said twice)
--     AUTO IN 15s
-- Nothing here was ever removed: pre-v16.32 this was ONE baked plate with ONE
-- line; v16.32 split it in two to fit the tokens, v16.57 swapped in the
-- offhand pair and kept D-PAD. Every step added.
--
-- THE REAL DEFECT IS NOT THE LENGTH, IT IS THAT A LIST HAS NO DIRECTION.
-- "SWITCH: E / G / V" tells a player which keys are live and NOT which card
-- each one moves to — the one fact they need. Direction is now the whole line.
--
-- WHICH LANE GETS NAMED. The offhand pair, because it is the ONLY pair that is
-- correct on every device in every place this panel opens: tactical/lethal are
-- read ABOVE the station's device gate in `_tod_upgrade_ui::wait_for_choice`,
-- so they survive the pad's d-pad-only station rule, and by v16.57's argument
-- they sit left/right on every pad layout by construction. Melee, reload,
-- WASD, the strafe stick and the d-pad all keep working exactly as before —
-- they are simply no longer ADVERTISED. A prompt teaches one reliable way;
-- stock does the same ("Hold [X] To Buy" never lists its alternatives).
--
-- NO DEVICE BRANCH ANY MORE. Both strings are now identical for pad and
-- keyboard, because the engine expands every token into the live device's own
-- key or glyph — the D-PAD tail was the last thing on these plates that keyed
-- off `CoD.TodPad`, and that latch is not a device proof (v16.81: a keyboard
-- binds 3/4 to action slots). So a falsely-latched KBM player can no longer be
-- shown pad wording here. `UsingController()` survives for the flag-off baked
-- plates below, which are per-device art.
local function SwitchLine1()
    return "^3[{+smoke}]^7 ^5<  SWITCH  >^7 ^3[{+frag}]^7"
end
-- LOCK IS SAID ONCE, UNDER THE FOCUSED CARD, where the eye already is and
-- where the hold bar fills. The bottom plate no longer repeats it.
local function LockLine()
    return "HOLD ^3[{+gostand}]^7 TO LOCK"
end

-- =============================================================================
-- THE LEVEL PIPS (docs/172, user 2026-10-04).
--
-- "players arent really aware of what basic, super, and ultimate even mean and
-- will pick up a basic instead of ultimate ... a visual upgrade on all the cards
-- that has to be custom and not part of the actual card but should look like it
-- ... shows all the levels of that upgrade, fills in the level you are and then
-- shows what the upgrade will take you ... Fill Fill Purple Purple Empty ...
-- maybe even a small pulse animation on the purple dots ... I dont think this
-- impacts dark upgrades at all."
--
-- ONE LIVE ROW PER CARD, exactly where the card art's own dots sat: a dot per
-- level of the domain (the player's real cap), CYAN for the levels already owned
-- (the pause menu's own level-pip colour, so "cyan = mine" reads the same on every
-- screen), the card's RARITY colour for the levels this card adds (white REGULAR,
-- violet SUPER, gold ULTIMATE - the colours the card's band and text already
-- wear), dark for the room left. The added dots light one at a time as the card
-- lands, then breathe (a soft glow + a core shine) until the pick, and on the
-- pick they turn cyan - they are yours now. A locked promotion shows where it
-- would take you and nothing moves.
--
-- THE ART: ten sprites built by tools/card_pips/build_card_pips.py out of the
-- card's own dot (fitted to the baked dots: mean error under one colour step),
-- 48 texels = 48 card px, so they filter exactly like the card they sit on. The
-- tool also painted the baked dot row OUT of every live card (regular / super /
-- ultimate + the class-tier cards): a cover cannot hide it, because an unfocused
-- card is drawn at alpha 0.4 and anything layered over a translucent card lets
-- the baked dots through. DARK cards keep their baked row and get no live one.
-- The tool's --check gates every build.
--
-- THE DATA: the card fields carry the current level; the cap and the levels the
-- card PAYS ride `tod_upg_pips` (one int per slot, _tod_upgrade_ui.gsc pips_push)
-- ahead of the deal. Until it arrives the cap falls back to CoD.TodOwned (synced,
-- per player), then DOMAIN.max; the gain to the rarity's +N. Clamped either way.
--
-- MOTION: only alpha and rects are tweened, colours are stamped (this file's
-- rule). Every chain is driven by a tween completing on an element this module
-- owns - never a UITimer - and stops on an interrupted event or a cleared flag.
-- Render runs at ~7 Hz while the cards are up (the focus blink), so a row is laid
-- out ONLY when its card's signature changes; otherwise the motion is left alone.
-- Dev: `[TOD_CARD_PIPS] DEAL` on the server says what each card was sent.
-- =============================================================================
local USE_CARD_PIP_ART = true
-- LOCKSTEP with tools/card_pips/build_card_pips.py: its --check reads these seven
-- out of this file. Card px on the 768 x 1152 card art.
local PIP_CX = 384.0          -- the card art's dot row centre
local PIP_CY = 1028.0
local PIP_PITCH = 58          -- the baked dots' centre-to-centre
local PIP_USABLE_W = 428      -- x 170..598, between the panel's two lower screws
local PIP_HALO_R = 22.1       -- a lit dot's outer edge (its halo ring)
local PIP_SPRITE = 48         -- a dot sprite's footprint (1 texel per card px)
local PIP_GLOW = 80           -- the glow sprite's footprint
local PIP = {
    MAX = 10,                 -- the highest domain cap (DAMAGE, the heavy's DR)
    GAIN_MAX = 3,             -- an ULTIMATE pays +3: the most dots one card lights
    LV = { 1, 2, 3 },         -- what a rarity pays when the server has not said
    IN_AT = 60,               -- the row fades in as the card face finishes opening
    IN_MS = 100,
    FIRST_MS = 90,            -- then the added dots light, one at a time
    TICK_MS = 120,
    POP_MS = 160, POP_K = 1.6,          -- each one stamps in from 1.6x (Bounce)
    FLASH_MS = 280, FLASH_K = 1.75,     -- with a flash of its glow and a core shine
    REST_MS = 180,            -- a beat after the last one, then the breathing
    BEAT_MS = 620,            -- half a breath: 1.24 s a cycle
    LO = { glowA = 0.25, glowK = 1.00, shineA = 0.00 },
    HI = { glowA = 0.85, glowK = 1.18, shineA = 0.40 },
    COMMIT_K = 1.35,          -- the picked card's new dots pop as they turn cyan
    LOCK_RGB = { 0.55, 0.60, 0.72 },    -- the locked tier card's own tint
}

local CardPips = {}

local function PipBox( e, cx, cy, half )
    e:setLeftRight( true, false, cx - half, cx + half )
    e:setTopBottom( true, false, cy - half, cy + half )
end

-- The row's layout: dot centres in card px + the dot scale. Up to seven dots keep
-- the art's own 58 pitch and size; eight to ten tighten the pitch first and shrink
-- the dot only for ten. LOCKSTEP with build_card_pips.py plan().
function CardPips.Plan( n )
    if n < 1 then n = 1 end
    if n > PIP.MAX then n = PIP.MAX end
    local k, p = 1, PIP_PITCH
    if n > 7 then
        k = ( PIP_USABLE_W - 3 * ( n - 1 ) ) / ( 2 * PIP_HALO_R * n )
        if k > 1 then k = 1 end
        p = ( PIP_USABLE_W - 2 * PIP_HALO_R * k ) / ( n - 1 )
        if p > PIP_PITCH then p = PIP_PITCH end
    end
    local xs = {}
    for i = 1, n do
        xs[ i ] = PIP_CX + ( i - ( n + 1 ) / 2 ) * p
    end
    return xs, k
end

-- One slot of tod_upg_pips: domain_id * 256 + max * 16 + levels (0 = no card).
function CardPips.Decode( v )
    if type( v ) ~= "number" or v <= 0 then
        return nil
    end
    v = math.floor( v )
    return { dom = math.floor( v / 256 ), max = math.floor( v / 16 ) % 16, lvl = v % 16 }
end

-- What one dealt card's row shows, or nil for no row (an empty slot, a DARK card,
-- an unknown id). ev = that slot's decoded tod_upg_pips, used only when its domain
-- matches the card actually showing.
function CardPips.Info( dom, rar, cur, ev )
    if not dom or dom <= 0 then
        return nil
    end
    local isTier = ( dom == TIER_DOMAIN )
    if cur == DARK_L and not isTier then
        return nil    -- a DARK card keeps its own baked row (user: dark is not part of this)
    end
    local d = DOMAIN[ dom ]
    if d == nil and not isTier then
        return nil
    end
    cur = cur or 0
    local evOk = ( ev ~= nil and ev.dom == dom )
    local n, owned, gain
    if isTier then
        -- the level field packs (class-1)*2 + (target tier-2); the player holds
        -- the tier below the target, and a promotion is one tier
        n = ( evOk and ev.max > 0 ) and ev.max or 3
        owned = ( cur % 2 ) + 1
        gain = 1
    else
        n = d.max or 5
        local o = CoD.TodOwned and CoD.TodOwned[ dom ]
        if o and type( o.max ) == "number" and o.max > 0 then
            n = o.max
        end
        if evOk and ev.max > 0 then
            n = ev.max
        end
        owned = cur
        gain = PIP.LV[ rar ] or 1
        if evOk then
            gain = ev.lvl
        end
    end
    -- The CAP is the trustworthy number when the two disagree: the server clamps
    -- every card's rarity to the room left, so a +N past the cap only happens on
    -- the fallback path (or the rarity lock - MYSTICAL HANDS is an ULTIMATE frame
    -- paying one level). A level the player OWNS is never hidden, though.
    if n > PIP.MAX then n = PIP.MAX end
    if owned < 0 then owned = 0 end
    if owned > n then n = math.min( PIP.MAX, owned ) end
    if owned > n then owned = n end
    if owned + gain > n then gain = n - owned end
    if gain > PIP.GAIN_MAX then gain = PIP.GAIN_MAX end
    if gain < 0 then gain = 0 end
    if n < 1 then
        return nil
    end
    return { dom = dom, n = n, owned = owned, gain = gain, rar = rar or 1, tier = isTier }
end

-- Built once per card. Everything lives under one root that joins card.group, so
-- the row takes every alpha the card takes (focus dim, the pick, the lock).
function CardPips.Build( owner, art, xLo, xHi, y0 )
    local P = { art = art, xLo = xLo, y0 = y0, s = ( xHi - xLo ) / 768, body = {}, glow = {}, shine = {} }
    local root = LUI.UIElement.new()
    root:setLeftRight( true, true, 0, 0 )
    root:setTopBottom( true, true, 0, 0 )
    -- the root closes its own children: LUI close never cascades (TodUIOwnership)
    CoD.TodUIOwnership.Attach( root )
    owner:addElement( root )
    P.root = root
    local function Img( list, i, img )
        local e = LUI.UIImage.new()
        e:setLeftRight( true, false, xLo, xLo + 1 )
        e:setTopBottom( true, false, y0, y0 + 1 )
        if img then
            e:setImage( img )
        end
        e:setAlpha( 0 )
        root:addElement( e )
        list[ i ] = e
    end
    for j = 1, PIP.GAIN_MAX do Img( P.glow, j ) end           -- under the dots
    for i = 1, PIP.MAX do Img( P.body, i, art.empty ) end
    for j = 1, PIP.GAIN_MAX do Img( P.shine, j, art.shine ) end
    -- two invisible metronomes: one paces the light-up, one the breathing
    P.seq = LUI.UIElement.new()
    P.seq:setLeftRight( true, false, 0, 1 )
    P.seq:setTopBottom( true, false, 0, 1 )
    P.seq:setAlpha( 0 )
    root:addElement( P.seq )
    P.beat = LUI.UIElement.new()
    P.beat:setLeftRight( true, false, 0, 1 )
    P.beat:setTopBottom( true, false, 0, 1 )
    P.beat:setAlpha( 0 )
    root:addElement( P.beat )
    P.seq:registerEventHandler( "transition_complete_tod_pip_seq", function ( element, event )
        if not event.interrupted then
            CardPips.SeqStep( P )
        end
    end )
    P.beat:registerEventHandler( "transition_complete_tod_pip_beat", function ( element, event )
        if not event.interrupted then
            CardPips.Beat( P )
        end
    end )
    return P
end

-- canvas x of dot i
local function PipX( P, i )
    return P.xLo + P.xs[ i ] * P.s
end

-- Every chain off, every tween snapped to its end. Flags FIRST: a completion
-- event fired from inside completeAnimation must find nothing to continue.
function CardPips.Stop( P )
    P.seqOn, P.pulseOn = false, false
    P.seq:completeAnimation()
    P.beat:completeAnimation()
    for j = 1, PIP.GAIN_MAX do
        P.glow[ j ]:completeAnimation()
        P.shine[ j ]:completeAnimation()
    end
    for i = 1, PIP.MAX do
        P.body[ i ]:completeAnimation()
    end
end

function CardPips.Hide( P )
    if not P or not P.shown then
        return
    end
    CardPips.Stop( P )
    for i = 1, PIP.MAX do
        P.body[ i ]:setAlpha( 0 )
    end
    for j = 1, PIP.GAIN_MAX do
        P.glow[ j ]:setAlpha( 0 )
        P.shine[ j ]:setAlpha( 0 )
    end
    P.shown, P.sig, P.info = false, nil, nil
end

-- The panel is going down: the motion stops, the dots stay and fade WITH the
-- panel (hiding them here would pop them off 250 ms before their card), and the
-- next deal starts from a clean slate.
function CardPips.Freeze( P )
    if not P or not P.sig then
        return
    end
    CardPips.Stop( P )
    for j = 1, PIP.GAIN_MAX do
        P.glow[ j ]:setAlpha( 0 )
        P.shine[ j ]:setAlpha( 0 )
    end
    P.sig = nil
end

function CardPips.Layout( P, info, locked, animate )
    CardPips.Stop( P )
    local art = P.art
    local xs, k = CardPips.Plan( info.n )
    P.xs, P.k, P.info, P.locked = xs, k, info, locked
    P.cy = P.y0 + PIP_CY * P.s
    P.half = PIP_SPRITE * 0.5 * k * P.s
    P.glowHalf = PIP_GLOW * 0.5 * k * P.s
    P.gainImg = info.tier and art.tier or ( art.gain[ info.rar ] or art.gain[ 1 ] )
    local glowImg = info.tier and art.glow[ 3 ] or ( art.glow[ info.rar ] or art.glow[ 1 ] )
    local tint = locked and PIP.LOCK_RGB or nil
    for i = 1, PIP.MAX do
        local e = P.body[ i ]
        if i <= info.n then
            local img = art.empty
            if i <= info.owned then
                img = art.owned
            elseif i <= info.owned + info.gain and ( locked or not animate ) then
                img = P.gainImg    -- (a locked card's never lights: it shows where it leads)
            end
            e:setImage( img )
            PipBox( e, PipX( P, i ), P.cy, P.half )
            if tint then
                e:setRGB( tint[ 1 ], tint[ 2 ], tint[ 3 ] )
            else
                e:setRGB( 1, 1, 1 )
            end
            e:setAlpha( animate and 0 or 1 )
        else
            e:setAlpha( 0 )
        end
    end
    for j = 1, PIP.GAIN_MAX do
        local g, sh = P.glow[ j ], P.shine[ j ]
        g:setImage( glowImg )
        g:setAlpha( 0 )
        sh:setAlpha( 0 )
        local i = info.owned + j
        if j <= info.gain and i <= info.n then
            PipBox( g, PipX( P, i ), P.cy, P.glowHalf * PIP.LO.glowK )
            PipBox( sh, PipX( P, i ), P.cy, P.half )
        end
    end
    P.shown, P.lit = true, 0
    if animate then
        -- every landing fades its row in with the card face; a locked card (or one
        -- with nothing to add) stops there, the rest light and breathe
        P.seqOn, P.seqStep = true, 0
        P.seq:beginAnimation( "tod_pip_seq", PIP.IN_AT, false, false, CoD.TweenType.Linear )
        P.seq:setAlpha( 0 )
    elseif not locked and info.gain >= 1 then
        P.lit = info.gain
        CardPips.PulseStart( P )
    end
end

-- one added dot lights: stamp in, flash its glow, flash the core
function CardPips.Light( P, j )
    local i = P.info.owned + j
    local e, g, sh = P.body[ i ], P.glow[ j ], P.shine[ j ]
    if not e or i > P.info.n then
        return
    end
    local cx = PipX( P, i )
    e:completeAnimation()
    e:setImage( P.gainImg )
    e:setAlpha( 1 )
    PipBox( e, cx, P.cy, P.half * PIP.POP_K )
    e:beginAnimation( "tod_pip_pop", PIP.POP_MS, false, false, CoD.TweenType.Bounce )
    PipBox( e, cx, P.cy, P.half )
    g:completeAnimation()
    PipBox( g, cx, P.cy, P.glowHalf * PIP.FLASH_K )
    g:setAlpha( 1 )
    g:beginAnimation( "tod_pip_flash", PIP.FLASH_MS, false, true, CoD.TweenType.Linear )
    PipBox( g, cx, P.cy, P.glowHalf * PIP.LO.glowK )
    g:setAlpha( PIP.LO.glowA )
    sh:completeAnimation()
    sh:setAlpha( 0.9 )
    sh:beginAnimation( "tod_pip_flash", PIP.FLASH_MS, false, true, CoD.TweenType.Linear )
    sh:setAlpha( 0 )
end

-- the light-up, paced by P.seq: step 0 fades the row in with the card face, then
-- one added dot per tick, then a rest, then the breathing
function CardPips.SeqStep( P )
    if not P.seqOn or not P.info then
        return
    end
    local info = P.info
    local nextMs = nil
    if P.seqStep == 0 then
        for i = 1, info.n do
            local e = P.body[ i ]
            e:completeAnimation()
            e:setAlpha( 0 )
            e:beginAnimation( "tod_pip_in", PIP.IN_MS, false, false, CoD.TweenType.Linear )
            e:setAlpha( 1 )
        end
        P.seqStep = 1
        if P.locked or info.gain < 1 then
            P.seqOn = false
            return
        end
        nextMs = PIP.FIRST_MS
    elseif P.lit < info.gain then
        P.lit = P.lit + 1
        CardPips.Light( P, P.lit )
        nextMs = ( P.lit < info.gain ) and PIP.TICK_MS or PIP.REST_MS
    else
        P.seqOn = false
        CardPips.PulseStart( P )
        return
    end
    P.seq:beginAnimation( "tod_pip_seq", nextMs, false, false, CoD.TweenType.Linear )
    P.seq:setAlpha( 0 )
end

function CardPips.PulseStart( P )
    local info = P.info
    if not info or P.locked or info.gain < 1 then
        return
    end
    P.pulseOn, P.hi = true, false
    CardPips.Beat( P )
end

-- half a breath, paced by P.beat: every added dot's glow and shine swing together
function CardPips.Beat( P )
    if not P.pulseOn or not P.info then
        return
    end
    P.hi = not P.hi
    local to = P.hi and PIP.HI or PIP.LO
    local info = P.info
    for j = 1, info.gain do
        local i = info.owned + j
        local g, sh = P.glow[ j ], P.shine[ j ]
        if g and i <= info.n then
            g:beginAnimation( "tod_pip_breathe", PIP.BEAT_MS, true, true, CoD.TweenType.Linear )
            PipBox( g, PipX( P, i ), P.cy, P.glowHalf * to.glowK )
            g:setAlpha( to.glowA )
            sh:beginAnimation( "tod_pip_breathe", PIP.BEAT_MS, true, true, CoD.TweenType.Linear )
            sh:setAlpha( to.shineA )
        end
    end
    P.beat:beginAnimation( "tod_pip_beat", PIP.BEAT_MS, false, false, CoD.TweenType.Linear )
    P.beat:setAlpha( 0 )
end

-- every dot at its final face, motion off (the pick can land mid light-up)
local function PipSettle( P, img )
    local info = P.info
    for i = 1, info.n do
        local e = P.body[ i ]
        if i > info.owned and i <= info.owned + info.gain then
            e:setImage( img )
        end
        e:setAlpha( 1 )
    end
end

-- the picked card: its new dots turn cyan with one last pop and flash
function CardPips.Commit( P )
    P.committed = true
    local info = P.info
    if not info or P.locked or info.gain < 1 then
        return
    end
    CardPips.Stop( P )
    PipSettle( P, P.art.owned )
    for j = 1, info.gain do
        local i = info.owned + j
        local e, g, sh = P.body[ i ], P.glow[ j ], P.shine[ j ]
        if e and i <= info.n then
            local cx = PipX( P, i )
            PipBox( e, cx, P.cy, P.half * PIP.COMMIT_K )
            e:beginAnimation( "tod_pip_pop", PIP.POP_MS, false, false, CoD.TweenType.Bounce )
            PipBox( e, cx, P.cy, P.half )
            PipBox( g, cx, P.cy, P.glowHalf * PIP.LO.glowK )
            g:setAlpha( 0.9 )
            g:beginAnimation( "tod_pip_flash", PIP.FLASH_MS, false, true, CoD.TweenType.Linear )
            PipBox( g, cx, P.cy, P.glowHalf * PIP.FLASH_K )
            g:setAlpha( 0 )
            sh:setAlpha( 0.8 )
            sh:beginAnimation( "tod_pip_flash", PIP.FLASH_MS, false, true, CoD.TweenType.Linear )
            sh:setAlpha( 0 )
        end
    end
end

-- the card passed over: motion off, its dots stay as they are
function CardPips.Quiet( P )
    if P.quiet or not P.info then
        return
    end
    P.quiet = true
    CardPips.Stop( P )
    if not P.locked then
        PipSettle( P, P.gainImg )
    end
    for j = 1, PIP.GAIN_MAX do
        P.glow[ j ]:setAlpha( 0 )
        P.shine[ j ]:setAlpha( 0 )
    end
end

-- Once per Render per card. Lays the row out only on a NEW signature; a landing
-- during the reveal (the slot was empty) plays the light-up, anything else (the
-- cap arriving late, a re-present) settles instantly.
function CardPips.Sync( P, info, revealing, pick, locked )
    if not P then
        return
    end
    if info == nil then
        CardPips.Hide( P )
        return
    end
    local sig = info.dom .. "/" .. info.n .. "/" .. info.owned .. "/" .. info.gain .. "/" .. info.rar
        .. ( info.tier and "t" or "" ) .. ( locked and "L" or "" )
    if sig ~= P.sig then
        local landing = revealing and not P.shown
        P.sig, P.committed, P.quiet = sig, false, false
        CardPips.Layout( P, info, locked, landing )
    end
    if pick == "chosen" then
        if not P.committed then
            CardPips.Commit( P )
        end
    elseif pick == "other" then
        CardPips.Quiet( P )
    end
end
-- read by tools/test_card_pips.lua
CoD.TodCardPips = CardPips

CoD.TodUpgradePanel = InheritFrom( LUI.UIElement )

function CoD.TodUpgradePanel.new( HudRef, InstanceRef )
    local self = LUI.UIElement.new()
    CoD.TodUIOwnership.Attach( self )
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
        if USE_LUCK_LEGEND_ART then
            art.luckLegend = RegisterImage( "i_tod_luck_legend" )
        end
        if USE_TIER_GATE_ART then
            -- keyed by the TIER the strip names (2 or 3), not by the floor, so
            -- a floor retune re-bakes the art without moving the table
            art.tierGate = {
                [2] = RegisterImage( "i_tod_tier_gate_2" ),
                [3] = RegisterImage( "i_tod_tier_gate_3" ),
            }
        end
        art.badges = {}
        for i = 1, 10 do
            art.badges[ i ] = RegisterImage( "i_tod_badge_luck_" .. ( i * 10 ) )
        end
        -- [tod v16] CLASS BADGE plates, keyed by CLASS ID 1..4 -- the same ids
        -- tod_class_select.lua's CLASSES table and _tod_classes::class_id use.
        -- Class 0 is CLASSLESS (pre-draft) and deliberately has no entry.
        if USE_CLASS_BADGE_ART then
            art.classPlate = {
                [1] = RegisterImage( "i_tod_upg_class_skirmisher" ),
                [2] = RegisterImage( "i_tod_upg_class_assault" ),
                [3] = RegisterImage( "i_tod_upg_class_heavy" ),
                [4] = RegisterImage( "i_tod_upg_class_slasher" ),
                [5] = RegisterImage( "i_tod_upg_class_mage" ),   -- docs/116
            }
        end
        art.hintLockPad = RegisterImage( "i_tod_hint_lock_pad" )
        art.hintLockKbm = RegisterImage( "i_tod_hint_lock_kbm" )
        art.hintSwitchPad = RegisterImage( "i_tod_hint_switch_pad" )
        art.hintSwitchKbm = RegisterImage( "i_tod_hint_switch_kbm" )
        art.hintLocked = RegisterImage( "i_tod_hint_locked" )
        if USE_HINT_FRAME_ART then
            art.hintFrame = RegisterImage( "i_tod_hint_frame" )
        end
        -- [tod v16.88] REAL BUTTON GLYPHS (docs/88, drop 2026-09-03 13:38).
        -- The engine renders a bind token as a TEXT NAME, never a picture — a
        -- pad player read the letters "LT"/"RT" — so the glyphs are baked here
        -- and only the KEYBOARD key name is still engine-drawn, inside a baked
        -- keycap. See the switch-glyph block below for the device rule.
        if USE_CARD_GLYPH_ART then
            art.padDpadL   = RegisterImage( "i_tod_pad_dpad_left" )
            art.padDpadR   = RegisterImage( "i_tod_pad_dpad_right" )
            art.padBtnA    = RegisterImage( "i_tod_pad_button_a" )
            -- (i_tod_key_blank, the SQUARE keycap, is deliberately NOT
            -- registered or zoned: the bind expansion can be "MOUSE3", and
            -- since nothing here can measure it in advance the WIDE cap is
            -- used for every key. A single letter simply centres in it. The
            -- PNG and its GDT block stay for the day a width read exists.)
            art.keyWide    = RegisterImage( "i_tod_key_blank_wide" )
            art.holdPlate  = RegisterImage( "i_tod_hold_plate" )
            -- (i_tod_hold_fill is NOT used and NOT zoned. It was drawn to fill
            -- the plate groove, but the plate bakes HOLD / TO LOCK ON TOP of
            -- that groove, so a fill layered over the plate would cover the
            -- words and a fill layered under it would be hidden by the opaque
            -- plate. The progress bar therefore sits BELOW the plate using the
            -- timer pair. PNG + GDT kept for a future plate whose groove is
            -- clear of its lettering.)
            -- ONE bar pair serves BOTH the hold-to-lock progress and the
            -- auto-pick countdown: they are the same object (a track that
            -- fills or drains), so they share art rather than minting a
            -- second pair that would have to be kept in visual lockstep.
            art.barTrack   = RegisterImage( "i_tod_timer_track" )
            art.barFill    = RegisterImage( "i_tod_timer_fill" )
        end
        -- the 54-card baked set, keyed [domain id][rarity 1..3]
        local RNAME = { [1] = "regular", [2] = "super", [3] = "ultimate" }
        local CARD_SLUG = {
            [1]  = "damage",      [2]  = "dmg_reduction", [3]  = "bounty",
            [4]  = "luck",        [5]  = "sprint",        [6]  = "headshot",
            [7]  = "mag_size",    [8]  = "reserve",
            -- [9] "mobility" REMOVED v15 (2026-08-31) with the domain. On the
            -- IMPACT ROUNDS precedent: an unreachable art slug is dead weight in
            -- the .ff (where an inert Lua DOMAIN/DETAIL row costs nothing), so
            -- the slug AND the three i_tod_card_mobility_* zone lines are gone.
            -- The PNGs stay in source_data. Id 9 is still MAPPED everywhere else.
            [10] = "bullet_feed",
            -- 11 echo_rounds / 12 regen: slugs + the six i_tod_card_echo_rounds_*
            -- / i_tod_card_regen_* zone lines REMOVED 2026-09-03 (v16.86), the
            -- v16.80 perkslots treatment applied to the domains retired before
            -- it. Neither has a live add_domain, so no deal can roll them; the
            -- cards were still packed uncompressed (768x1152 = 3.4 MB of load
            -- RAM each). PNGs stay in source_data; ids stay MAPPED elsewhere.
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
            -- 27 kill_reload: slug + zone lines REMOVED 2026-09-01 with the domain.
            [29] = "suppressing_fire",
            -- 30 meat_grinder: slug + zone lines REMOVED 2026-09-03 (v16.86) with the domain.
            [31] = "draw_cut",
            [33] = "second_wind",   -- art installed 2026-08-23
            -- 34 momentum: slug + zone lines REMOVED 2026-09-03 (v16.86) with the domain.
            [35] = "giant_slayer",  -- art installed + zoned 2026-08-23 (files (38).zip, docs/31)
            [36] = "back_armor",    -- art installed + zoned 2026-08-23 (files (38).zip, docs/31)
            [37] = "march",         -- FORCED MARCH — art installed + zoned 2026-08-24 (files (39).zip, docs/33)
            [38] = "vitality",      -- VITALITY — art installed + zoned 2026-08-30 (files (69).zip, docs/46)
            [39] = "recovery",      -- RECOVERY — art installed + zoned 2026-08-30 (files (69).zip, docs/46)
            [40] = "perkslots",     -- RESTORED v17.3 with the domain; the three i_tod_card_perkslots_* images re-zoned
            [41] = "distraction",   -- DISTRACTION — art installed + zoned 2026-09-01 (files (78).zip, docs/56)
            [42] = "full_steam",    -- FULL STEAM — art installed + zoned 2026-09-01 (files (78).zip, docs/56)
            [43] = "athlete",       -- ATHLETE — art installed + zoned 2026-09-01 (files (79).zip, docs/57)
            [44] = "gunslinger",    -- GUNSLINGER — art installed + zoned 2026-09-02 (files - 2026-09-02T190025.581.zip, docs/79)
            [46] = "trailblazer",   -- TRAILBLAZER — art installed + zoned 2026-09-02 (files - 2026-09-02T235756.963.zip, docs/83); the r46 PLATE is zoned too but PAUSE_PLATE_MAX stays 44 until r45 (RIOT SHIELD) lands — the plate max is a contiguous ceiling
            [45] = "riot_shield",   -- RIOT SHIELD — art installed + zoned 2026-09-03 (files - 2026-09-02T235756.963.zip, docs/82)
            -- MAGE elements, art installed + zoned 2026-09-07 (docs/115,
            -- files - 2026-09-07T191007.498.zip). NOTE 51's slug is
            -- "attunement", NOT "mage_attune" - the domain key and the image
            -- name differ, which is exactly why this table exists.
            [49] = "mage_fire",
            [50] = "mage_ice",
            -- [51] "attunement" RETIRED v18.41 with the domain; its three cards
            -- are unzoned in the same edit (retire it whole).
            [52] = "mage_heal",   -- HEALING AURA — art installed + zoned 2026-09-07 (docs/116). The DARK card was baked and zoned that day and UNZONED v18.42: mage_heal is set_no_dark(), so it could never be dealt, and an undealable card is 3.4 MB of load RAM
            -- The last three mage domains, art installed + zoned 2026-09-08
            -- (docs/120). Three rarities each and NO dark rung — all six mage
            -- domains are set_no_dark(), and DARK_NONE below is the load-bearing
            -- mirror of that.
            [53] = "mage_bolt",
            [54] = "mage_arch",
            [55] = "mage_blink",
            [56] = "mystical_hands",
            [57] = "mage_rate",   -- RAPID FLAME - art installed + zoned 2026-09-21 (files - 2026-09-21T115409.834.zip, docs/151); r57 plate landed with it, so the contiguous ceiling moves 56 -> 57. r58 (THUNDER SMASH) has no plate yet.
            -- [47] "deadshot" REMOVED v19.25 with the domain. The image is no
            -- longer zoned, and RegisterImage on an unzoned name is undefined
            -- behaviour (this file's own contract) -- so the slug had to go in
            -- the same commit as the zone line, not after it.
        }
        -- ONE-IMAGE DOMAINS (v16.67, DEADSHOT 47): a domain that is only ever
        -- dealt at ONE rarity (server-side set_rarity_lock) ships ONE card file,
        -- so registering "_regular"/"_super" would name images that do not
        -- exist. Fill all three rarity slots with the one image instead — the
        -- tier cards' own { img, img, img } idiom — so PaintCard's set[ rar ]
        -- can never be nil whatever rarity arrives on the wire.
        local CARD_ONE_IMAGE = {
            [56] = "ultimate", -- MYSTICAL HANDS: one-time ultimate only.
            -- [47] DEADSHOT retired v19.25; it was the idiom's other user.
        }
        art.cards = {}
        for id, slug in pairs( CARD_SLUG ) do
            art.cards[ id ] = {}
            if CARD_ONE_IMAGE[ id ] then
                local img = RegisterImage( "i_tod_card_" .. slug .. "_" .. CARD_ONE_IMAGE[ id ] )
                art.cards[ id ] = { img, img, img }
            else
                for r = 1, 3 do
                    art.cards[ id ][ r ] = RegisterImage( "i_tod_card_" .. slug .. "_" .. RNAME[ r ] )
                end
            end
        end
        -- DARK UPGRADE cards, keyed by domain id. Reuses CARD_SLUG so a rename
        -- follows automatically.
        --
        -- DARK_NONE IS THE MIRROR OF set_no_dark() IN _tod_upgrades.gsc AND IT IS
        -- LOAD-BEARING, not documentation: these thirteen domains have no dark
        -- step, so their dark cards are NOT zoned, and RegisterImage on an
        -- unzoned name is undefined behavior (this file's own contract, top of
        -- file). Registering all 37 would name thirteen images that do not exist
        -- in the .ff.
        --
        -- The first ten are permanent; the last three (MAG SIZE / HANDLING /
        -- KNIFE SPEED) are PARKED and come off this list the same commit the
        -- generator learns per-gun axis levels. The art for all thirteen is
        -- already baked and waiting in source_data.
        local DARK_NONE = {
            [21] = true, [33] = true, [41] = true, [47] = true,   -- SPRINT FIRE / SECOND WIND / DISTRACTION / DEADSHOT
            [29] = true, [31] = true,                             -- SUPPRESSING FIRE / DRAW CUT
            [4]  = true,                                          -- LUCK (removed 2026-09-05)
            [15] = true, [19] = true, [40] = true,                -- FIRE RATE / PENETRATION / PERK SLOTS
            -- MAGE elements 2026-09-07: all four are set_no_dark() in
            -- _tod_upgrades.gsc, and NO _dark image was drawn or zoned for them.
            -- This is the load-bearing half of that decision: without these
            -- rows the loop below would RegisterImage four names that are not
            -- in the .ff, which this file's own contract calls undefined
            -- behaviour. 52 HEALING AURA JOINED THEM v18.42: its dark card was
            -- baked and zoned, but mage_heal is set_no_dark like the rest, so
            -- that card could never be dealt -- 3.4 MB of load RAM (cards are
            -- uncompressed 768x1152) for an image nothing could ever draw. The
            -- zone line came out in the SAME build as this row, which is the
            -- only order that works: this row is what stops the loop below
            -- registering a name the .ff no longer carries.
            [51] = true,    -- ATTUNEMENT (retired). 49/50/52/54/55 went DARK-CAPABLE 2026-09-09 (user: "there are no dark upgrades for the mage"); 52 has baked art, the rest are DARK_TEXT_ONLY until docs/126 lands
            [56] = true, -- MYSTICAL HANDS has no dark version.
            [58] = true, -- THUNDER SMASH: no dark; art request docs/152.
            [57] = true, -- RAPID FLAME: set_no_dark in _tod_upgrades (v19.25). No CARD_SLUG yet either, so the loop below cannot reach it today -- this row is here so that adding the art is one edit, not two.
        }
        if USE_DARK_CARD_ART then
            art.dark = {}
            for id, slug in pairs( CARD_SLUG ) do
                if not DARK_NONE[ id ] and not DARK_TEXT_ONLY[ id ] then
                    art.dark[ id ] = RegisterImage( "i_tod_card_" .. slug .. "_dark" )
                end
            end
        end

        -- the 8 TIER cards, keyed [class id][tier 2|3]
        if USE_TIER_CARD_ART then
            -- #TCLS, not a literal 4: the table is the authority, so adding
            -- a fifth class here is a one-line change. Identical at four.
            -- MAGE joins unconditionally (docs/116, 2026-09-07). No flag: its
            -- tier cards are installed and zoned, so this is now exactly as
            -- true as the other four. The MAGE_ART flag that used to guard it
            -- is GONE, and build_map.ps1 fails any attempt to reintroduce a
            -- second Lua mage flag.
            local TCLS = { "skirmisher", "assault", "heavy", "slasher", "mage" }
            art.tier = {}
            for c = 1, #TCLS do
                art.tier[ c ] = {}
                for t = 2, 3 do
                    art.tier[ c ][ t ] = RegisterImage( "i_tod_card_tier_" .. TCLS[ c ] .. "_" .. t )
                end
            end
        end
        -- [docs/172] THE LEVEL PIPS: the ten sprites tools/card_pips builds and
        -- zones in its GENERATED zone block (every name literal, for lint_tod_assets).
        if USE_CARD_PIP_ART then
            art.pip = {
                empty = RegisterImage( "i_tod_cardpip_empty" ),
                owned = RegisterImage( "i_tod_cardpip_owned" ),
                tier  = RegisterImage( "i_tod_cardpip_gain_tier" ),
                shine = RegisterImage( "i_tod_cardpip_shine" ),
                gain  = {
                    [1] = RegisterImage( "i_tod_cardpip_gain_regular" ),
                    [2] = RegisterImage( "i_tod_cardpip_gain_super" ),
                    [3] = RegisterImage( "i_tod_cardpip_gain_ultimate" ),
                },
                glow  = {
                    [1] = RegisterImage( "i_tod_cardpip_glow_regular" ),
                    [2] = RegisterImage( "i_tod_cardpip_glow_super" ),
                    [3] = RegisterImage( "i_tod_cardpip_glow_ultimate" ),
                },
            }
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
            -- v15: FULL STEAM (42). Icon-only art; the CARD art is wired through
            -- CARD_SLUG above, so this is the composite/no-card-set fallback path.
            [42] = RegisterImage( "i_tod_up_full_steam" ),
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

    -- [tod v18.10] THE LEGEND, directly beneath the badge and in the badge's own
    -- box width (950..1230 = 280) at the same 60 height, so the two stack as one
    -- unit and the 420x90 art keeps its aspect exactly. y 214..274 is clear of
    -- everything: the cards start at CARD_Y0 226 but are centred (cx +/- 117),
    -- the LuckLine text band ends at 212, and the CLASS badge is the mirror on
    -- the far left. It shows and hides WITH the badge -- it is a caption, and a
    -- caption under nothing is noise.
    local LuckLegend = nil
    if art.luckLegend then
        LuckLegend = LUI.UIImage.new()
        LuckLegend:setLeftRight( true, false, 950, 1230 )
        LuckLegend:setTopBottom( true, false, 214, 274 )
        LuckLegend:setImage( art.luckLegend )
        LuckLegend:setAlpha( 0 )
        self:addElement( LuckLegend )
    end

    -- [tod v16] CLASS badge -- the luck badge's mirror, same 280x60 at the same
    -- height on the opposite side. The tier-gate strip USED to fall back to this
    -- exact rect when no card was dealt; it now sits one row lower (see the
    -- TierGateImg placement below) so the two can never overlap.
    local ClassBadge = nil
    if art.classPlate then
        ClassBadge = LUI.UIImage.new()
        ClassBadge:setLeftRight( true, false, 50, 330 )
        ClassBadge:setTopBottom( true, false, 150, 210 )
        ClassBadge:setAlpha( 0 )
        self:addElement( ClassBadge )
    end

    -- SWITCH-HINT plate (controller/KBM baked; the countdown stays live text)
    -- 280x43 = the art's true 460x70 aspect (was 320x32 — visibly stretched,
    -- user 2026-08-20); below the powerup tray band, countdown text BELOW it
    -- (they overlapped before).
    local SwitchHintImg = nil
    if art.hintSwitchPad then
        SwitchHintImg = LUI.UIImage.new()
        -- [tod v16.83] BACK TO ONE LINE, so back to ONE geometry. v16.32 grew
        -- this to 320x49 purely to fit a second text line; with LOCK said only
        -- under the focused card there is one line again, and 280x43 is the
        -- art's own 460/70 aspect. Both paths share it now — the frame path
        -- and the baked path can no longer be different sizes.
        SwitchHintImg:setLeftRight( false, false, -140, 140 )
        SwitchHintImg:setTopBottom( true, false, 650, 693 )
        SwitchHintImg:setAlpha( 0 )
        self:addElement( SwitchHintImg )
    end

    -- [tod v16.32, one line since v16.83] the key line drawn over the blank
    -- frame (USE_HINT_FRAME_ART; see SwitchLine1 at the top of the file).
    -- Centred in the plate's 650..693 band.
    local SwitchHintText1 = nil
    if SwitchHintImg and USE_HINT_FRAME_ART and art.hintFrame then
        SwitchHintText1 = LUI.UIText.new()
        SwitchHintText1:setLeftRight( false, false, -134, 134 )
        SwitchHintText1:setTopBottom( true, false, 663, 680 )
        SwitchHintText1:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
        SwitchHintText1:setRGB( 1, 1, 1 )
        SwitchHintText1:setAlpha( 0 )
        self:addElement( SwitchHintText1 )
    end

    -- [tod v16.88] THE SWITCH GLYPHS — one beside each card, on the side it
    -- moves to. DIRECTION IS A POSITION, not a sentence: the left glyph sits
    -- outside card A (which starts at x 369), the right one outside card B
    -- (which ends at 911), both on the cards' mid-height. This is what
    -- REPLACES the bottom plate; that plate stays constructed above purely as
    -- the flag-off fallback, and ShowSwitchPlate picks exactly one of the two.
    --
    -- Each side is an image plus a text slot. On a pad the image is the d-pad
    -- glyph and the text is empty — the lit arm carries the meaning. On a
    -- keyboard the image is the WIDE blank keycap and the text is the bind
    -- token, engine-expanded into whatever that player actually bound, drawn
    -- INSIDE the cap. The wide cap is used for both because the expansion can
    -- be as long as "MOUSE3"; a single letter simply centres in it.
    -- THE PAIR SITS CENTRED UNDER THE CARDS, in the band the old switch plate
    -- occupied (user 2026-09-03: *"i wanted to keep the position under the
    -- cards in the middle of the screen. Same spot as before"*). v16.88 first
    -- put them out at the cards' outer edges to make direction spatial; the
    -- user's call is that the familiar spot matters more, and the d-pad glyph
    -- carries its own arrow anyway, so nothing is lost by moving them back.
    --
    -- BOTH RECTS ARE SET PER DEVICE by the writer, not here: the pad glyph is
    -- square (48) and the keycap is wide and short (72 x 36), so a single
    -- construction-time rect cannot serve both without stretching one of them.
    -- Each slot stores only its SIDE; the writer does the arithmetic about a
    -- fixed screen centre so the pair stays centred at either size.
    local SwitchGlyph = {}
    if USE_CARD_GLYPH_ART and art.padDpadL then
        local function GlyphSlot( side )
            local g = { side = side }
            g.Img = LUI.UIImage.new()
            g.Img:setAlpha( 0 )
            self:addElement( g.Img )
            g.Text = LUI.UIText.new()
            g.Text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
            g.Text:setRGB( 0.06, 0.07, 0.10 )   -- dark ink on the pale keycap
            g.Text:setAlpha( 0 )
            self:addElement( g.Text )
            -- [tod v17.27] the key name in the MAP'S OWN TYPEFACE. Built after
            -- g.Img so the glyphs draw over the cap, and given g.Text as the
            -- no-glyph fallback. See TodKeycap.lua.
            g.Key = TodKeycapMake( self, g.Text )
            return g
        end
        SwitchGlyph.L = GlyphSlot( -1 )
        SwitchGlyph.R = GlyphSlot(  1 )
    end

    -- ---------------------------------------------------------------------
    -- [tod v18.32] THE WORD BETWEEN THEM — twin of the class draft, where the
    -- whole argument lives. Short version: v16.88 replaced the baked switch
    -- plate with two glyphs and hid the plate for the whole match, and the
    -- plate was the only thing that said SWITCH. `SwitchLine1()` still spells
    -- the documented copy and has been unreachable on every real build since.
    -- Drawn in the map's baked typeface so the row is one piece of lettering.
    -- ---------------------------------------------------------------------
    local SwitchWord, SwitchWordText = nil, nil
    if SwitchGlyph.L then
        SwitchWordText = LUI.UIText.new()
        SwitchWordText:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
        SwitchWordText:setRGB( PAL.line[ 1 ], PAL.line[ 2 ], PAL.line[ 3 ] )
        SwitchWordText:setAlpha( 0 )
        self:addElement( SwitchWordText )
        if CoD.TodGlyphRow then
            SwitchWord = CoD.TodGlyphRow.make( self, 8 )   -- "SWITCH" is 6
            SwitchWord.setRGB( PAL.line[ 1 ], PAL.line[ 2 ], PAL.line[ 3 ] )
        end
    end

    -- ONE writer for the switch plate (image + its lines): every show/hide
    -- site goes through here so the frame path and the baked path can never
    -- disagree about what is on screen.
    local function ShowSwitchPlate( on )
        -- [tod v16.88] TWO PRESENTATIONS, EXACTLY ONE OF THEM VISIBLE. With the
        -- glyphs available this writer drives them and leaves the bottom plate
        -- hidden for the whole match; with the flag off it falls back to the
        -- v16.83 plate untouched. Keeping both behind ONE writer is what stops
        -- the two from ever being on screen together.
        if SwitchGlyph.L then
            local pad = UsingController()
            -- SCREEN CENTRE, then half-width + half-gap out on each side.
            -- 640 is the 1280 canvas centre; the y band is the old plate's.
            local CX, HW, Y0, Y1
            if pad then
                CX, HW, Y0, Y1 = 640, 24, 644, 692   -- 48 sq glyph
            else
                -- 96 x 48, the art's true 2:1. [v17.4] widened it from 72 x 36
                -- on the premise that a MULTI-BOUND action needs the room —
                -- `+frag` is on BOTH G and MOUSE3 in the user's bindings_0.cfg,
                -- and the engine expands that to `G OR MIDDLE MOUSE`.
                --
                -- [v17.27] THE ROOM WAS NEVER THE PROBLEM. That expansion is
                -- now TRIMMED to its first key, and the key is drawn in the
                -- map's baked typeface by CoD.TodKeycap, which measures it and
                -- shrinks only if it truly will not fit. The size stays because
                -- it is a good size for one big legible key, not because a
                -- 17-character string has to fit in it.
                CX, HW, Y0, Y1 = 640, 48, 644, 692   -- 96 x 48 keycap
            end
            -- [tod v18.32] the word sets the spacing, so the two buttons flank
            -- it instead of touching each other. WCAP is the lettering height;
            -- WPAD is the air between a button and the word.
            local WCAP, WPAD = 17, 18
            local wordW = -1
            if SwitchWord then
                wordW = SwitchWord.measure( "SWITCH", WCAP, CoD.TodGlyphRow.nameSet )
            end
            local wordOk = ( wordW > 0 )
            if not wordOk then
                wordW = 78          -- the UIText fallback's box
            end
            local HALF = HW + WPAD + wordW / 2
            local WCY  = ( Y0 + Y1 ) / 2
            if not on then
                if SwitchWord then SwitchWord.hide() end
                SwitchWordText:setAlpha( 0 )
            elseif wordOk then
                -- the row draws RIGHT-aligned; baseline is half a cap below
                -- the optical centre, the same rule TodKeycap uses.
                SwitchWord.set( "SWITCH", WCAP, CX + wordW / 2, WCY + WCAP / 2, CoD.TodGlyphRow.nameSet )
                SwitchWordText:setAlpha( 0 )
            else
                SwitchWordText:setLeftRight( true, false, CX - wordW / 2, CX + wordW / 2 )
                SwitchWordText:setTopBottom( true, false, WCY - 9, WCY + 9 )
                SwitchWordText:setText( "SWITCH" )
                SwitchWordText:setAlpha( 0.95 )
            end
            local function Paint( g, padImg, tok )
                if not on then
                    g.Img:setAlpha( 0 )
                    g.Key.hide()
                    return
                end
                local cx = CX + g.side * HALF
                g.Img:setLeftRight( true, false, cx - HW, cx + HW )
                g.Img:setTopBottom( true, false, Y0, Y1 )
                -- [tod v18.16] THE LAST WORD ON WHAT GETS DRAWN, and it reads
                -- the very string it is about to draw. `pad` is a decision made
                -- once, further up, from a latch and a device probe; TodPadWord
                -- asks the only question that actually matters here — "is this
                -- token going to render as LT/RT?" — and if so we draw the
                -- d-pad glyph instead. A stale latch, a failed widget require or
                -- a device switched mid-menu cannot get a pad word onto a
                -- keycap any more, because the check is on the text, not on a
                -- belief about the player. The d-pad is a live input lane in
                -- both menus, so the glyph it draws is always true.
                if pad or TodPadWord( tok ) then
                    g.Img:setImage( padImg )
                    g.Key.hide()
                else
                    -- [tod v17.27] the cap's rect is ALL TodKeycap needs: it
                    -- measures the key name in the baked typeface and picks the
                    -- size that fits the art's own bright face. It also trims
                    -- the multi-bind (`+frag` renders as `G OR MIDDLE MOUSE`).
                    g.Img:setImage( art.keyWide )
                    if g.Key.paint( cx - HW, Y0, HW * 2, Y1 - Y0, tok ) == nil then
                        -- [tod v18.48] THE KEYCAP REFUSED IT. The name could
                        -- not be drawn in our typeface AND carries a high byte,
                        -- i.e. the engine is handing back a button PICTURE — so
                        -- draw the button, rather than a pale cap with an
                        -- engine icon squatting inside it (the 2026-09-08
                        -- screenshot). This is the ONLY place the glyph test
                        -- still decides anything, and the worst it can do is
                        -- put one wrong glyph on screen; it cannot flip the
                        -- menu's device, which is what v18.47 did.
                        local half = ( Y1 - Y0 ) / 2
                        g.Img:setImage( padImg )
                        g.Img:setLeftRight( true, false, cx - half, cx + half )
                    end
                end
                g.Img:setAlpha( 1 )
            end
            Paint( SwitchGlyph.L, art.padDpadL, "[{+smoke}]" )
            Paint( SwitchGlyph.R, art.padDpadR, "[{+frag}]" )
            if SwitchHintImg then
                SwitchHintImg:setAlpha( 0 )
                if SwitchHintText1 then
                    SwitchHintText1:setAlpha( 0 )
                end
            end
            return
        end
        if not SwitchHintImg then
            return
        end
        if not on then
            SwitchHintImg:setAlpha( 0 )
            if SwitchHintText1 then
                SwitchHintText1:setAlpha( 0 )
            end
            return
        end
        if SwitchHintText1 then
            SwitchHintImg:setImage( art.hintFrame )
            SwitchHintText1:setText( Engine.Localize( SwitchLine1() ) )
            SwitchHintText1:setAlpha( 0.95 )
        else
            SwitchHintImg:setImage( UsingController() and art.hintSwitchPad or art.hintSwitchKbm )
        end
        SwitchHintImg:setAlpha( 0.9 )
    end

    -- ONE writer for a card's under-plate. mode = "lock" (focused: the key
    -- line), "locked" (the baked LOCKED plate — it names no key, so it stays
    -- baked under both paths), "off". `a` = alpha for the visible modes.
    local function CardHint( card, mode, a )
        if not card.HintImg then
            return
        end
        if mode == "off" then
            card.HintImg:setAlpha( 0 )
            if card.HintText then
                card.HintText:setAlpha( 0 )
            end
            if card.LockGlyph then
                card.LockGlyph:setAlpha( 0 )
                card.LockKey.hide()
            end
            return
        end
        if mode == "locked" then
            card.HintImg:setImage( art.hintLocked )
            if card.HintText then
                card.HintText:setAlpha( 0 )
            end
            if card.LockGlyph then
                card.LockGlyph:setAlpha( 0 )
                card.LockKey.hide()
            end
        elseif card.LockGlyph then
            -- [tod v16.88] THE BAKED PLATE SAYS THE WORDS; THE GAP HOLDS THE
            -- BUTTON. `i_tod_hold_plate` carries "HOLD" and "TO LOCK" as art
            -- with a deliberate empty gap between them, and the glyph drops
            -- into that gap: the A button on a pad, a blank keycap carrying
            -- the engine-expanded jump bind on a keyboard. No LUI text on the
            -- plate itself any more.
            card.HintImg:setImage( art.holdPlate )
            if card.HintText then
                card.HintText:setAlpha( 0 )
            end
            -- [tod v18.32] the jump token gets the ICON test as well: if the
            -- engine is going to hand us a picture of the A button, the pale
            -- keycap must not be drawn behind it (2026-09-08 screenshot).
            -- [tod v18.32] BOTH SIZES COME OUT OF THE MEASURED GAP, each art at
            -- its own aspect — twin of the draft. The old literals (30 and 64)
            -- were typed against a 56 px gap and the wide one overhung the
            -- baked lettering.
            local cx, cy = card.lockCx, card.lockCy
            -- [tod v18.48] DEVICE ONLY. v18.47 OR'd the jump token's icon
            -- test in here; that test fires on a keyboard too, so it put every
            -- KBM player on the A button. The keycap's own fallback still
            -- refuses to draw a picture inside itself — that is where the
            -- guard belongs, not in the device choice.
            if UsingController() then
                local s = math.floor( card.plateH * 0.85 / 2 )   -- half of ~28
                card.LockGlyph:setImage( art.padBtnA )
                card.LockGlyph:setLeftRight( true, false, cx - s, cx + s )
                card.LockGlyph:setTopBottom( true, false, cy - s, cy + s )
                card.LockKey.hide()
            else
                -- [tod v17.27] TodKeycap measures the key name in the map's own
                -- typeface and sizes it to the cap's bright face, so the cap
                -- only has to be the right SHAPE and inside the gap.
                local w = math.floor( ( card.lockGapW - 2 ) / 2 ) * 2
                local h = math.floor( w / 2 )                    -- the art is 2:1
                card.LockGlyph:setImage( art.keyWide )
                card.LockGlyph:setLeftRight( true, false, cx - w / 2, cx + w / 2 )
                card.LockGlyph:setTopBottom( true, false, cy - h / 2, cy + h / 2 )
                card.LockKey.paint( cx - w / 2, cy - h / 2, w, h, "[{+gostand}]", a )
            end
            card.LockGlyph:setAlpha( a )
        elseif card.HintText then
            card.HintImg:setImage( art.hintFrame )
            card.HintText:setText( Engine.Localize( LockLine() ) )
            card.HintText:setAlpha( a )
        else
            card.HintImg:setImage( UsingController() and art.hintLockPad or art.hintLockKbm )
        end
        card.HintImg:setAlpha( a )
    end

    -- (BOSS BANNERS lived here until 2026-08-20, when they moved to
    -- LUI.createMenu.tod_upgrade — this panel's root alpha is 0 outside upgrade
    -- events, which swallowed the banner in the ONLY scenario it fired: round
    -- start. They were then DELETED outright 2026-08-22, user: unnecessary.
    -- Kept as a warning: anything that must render outside an upgrade event
    -- belongs at the MENU root, not in this panel.)

    -- [tod v14.35] WHY THERE IS NO TIER CARD IN THIS DEAL.
    --
    -- Sits in the clear band between the cards' input hints (which end at
    -- CARD_Y1 + 35 = 612) and the countdown (697) — measured, not guessed,
    -- because both neighbours are baked-art rows and an overlap here would land
    -- on the one screen the player cannot look away from.
    --
    -- Shown ONLY when the floor gate is the sole thing withholding the card
    -- (GSC tier_floor_pending decides; 0 = say nothing). It is deliberately not
    -- a general "here is why you got what you got" line: a message that fires
    -- for every reason teaches players to stop reading it.
    --
    -- BAKED ART is the real thing here (docs/50, two badges keyed by tier); the
    -- LUI text below is the no-art fallback and is what ships until the PNGs
    -- land. Amber, not the luck cyan — this is a requirement, not a bonus.
    --
    -- IT IS THE EXACT MIRROR OF THE LUCK BADGE: that one is 280x60 at
    -- x 950..1230, y 150..210, so this is 280x60 at x 50..330 on the same row —
    -- the banner between them spans 340..940, so both gutters are free and the
    -- panel's two deal-status indicators become a matched pair. Source canvas
    -- 420x90 = the luck badge's own, aspect 4.667 held EXACTLY (the v6.6
    -- stretched-plate lesson: never draw a plate off its own aspect).
    --
    -- IT IS *NOT* UNDER THE CARDS, and that is measured rather than preferred:
    -- the band below them is already full. The cards' input hints end at
    -- CARD_Y1 + 35 = 612, SwitchHintImg occupies 650..693, and the countdown
    -- 697..717 — 38 free pixels, which cannot hold a legible plate. Anything
    -- placed there lands on the switch hint.
    -- DECLARED HERE, CONSTRUCTED AFTER THE CARDS — see the addElement below.
    -- LUI draws in addElement order, so an element added before CardA/CardB is
    -- BEHIND them. That was harmless while this badge lived in the empty
    -- top-left gutter and fatal the moment it became a stamp across the card:
    -- it would have been invisible, and "the art did not pack" is exactly what
    -- that looks like from the outside.
    local TierGateImg = nil
    -- The FALLBACK sits in that 38px band instead, because unstyled text needs
    -- the full panel width to stay legible and would clip inside the badge box.
    -- Different position from the art on purpose; only one of the two is ever
    -- visible.
    local TierLine = LUI.UIText.new()
    TierLine:setLeftRight( false, false, -300, 300 )
    TierLine:setTopBottom( true, false, 618, 642 )
    TierLine:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
    TierLine:setScale( 0.85 )
    TierLine:setRGB( 1.0, 0.78, 0.30 )
    TierLine:setText( "" )
    self:addElement( TierLine )

    -- countdown to auto-select (below the cards; red when nearly out)
    local TimeLine = LUI.UIText.new()
    TimeLine:setLeftRight( false, false, -300, 300 )
    TimeLine:setTopBottom( true, false, 697, 717 )
    TimeLine:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
    TimeLine:setScale( 0.9 )
    TimeLine:setText( "" )
    self:addElement( TimeLine )

    -- [tod v16.88] THE COUNTDOWN AS A DRAINING BAR. "AUTO IN 15s" was the last
    -- pure-LUI element on the control UI, and a bar says the same thing with no
    -- digits to render — which is also why it needs no per-number art. Same two
    -- images as the card hold bar: a countdown and a hold are the same object,
    -- one draining and one filling. 280 x 15 is the art's true 460/24 aspect;
    -- it sits in the band the deleted bottom plate used to occupy.
    -- THE PANEL IS NEVER TOLD THE TIMEOUT LENGTH. `todUpgTime` is a countdown
    -- of whole seconds and no field carries its starting value (the pool is at
    -- its proven 61-bit ceiling — see __init__ — so adding one is not on the
    -- table). The bar therefore learns the maximum by WATCHING: the first tick
    -- of a deal is the largest value it will ever see, so remember the highest
    -- and reset on hide. That is exact for a round deal and for the shorter
    -- station deal alike, with no server change at all.
    local timeMaxSeen = 0
    local TimeTrack, TimeFill = nil, nil
    if USE_CARD_GLYPH_ART and art.barTrack then
        TimeTrack = LUI.UIImage.new()
        TimeTrack:setLeftRight( false, false, -140, 140 )
        TimeTrack:setTopBottom( true, false, 700, 714 )
        TimeTrack:setImage( art.barTrack )
        TimeTrack:setAlpha( 0 )
        self:addElement( TimeTrack )

        TimeFill = LUI.UIImage.new()
        TimeFill:setLeftRight( false, false, -140, 140 )
        TimeFill:setTopBottom( true, false, 700, 714 )
        TimeFill:setImage( art.barFill )
        TimeFill:setAlpha( 0 )
        self:addElement( TimeFill )
    end

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

        -- ---- REVEAL LAYER (v14.52) -----------------------------------------
        -- Added HERE, before every face element, because LUI draws in
        -- addElement order and both of these belong BEHIND the card: the aura
        -- stands proud of the card rect (so it reads as a halo around opaque
        -- 2:3 card art), and the socket is what you look at while the face is
        -- still alpha 0. The Flare is the mirror case and is built after BOTH
        -- cards — see below.
        --
        -- DELIBERATELY OUTSIDE card.group. That group's alpha is driven by
        -- "does this slot have a domain yet", which is exactly false for the
        -- whole socket phase; joining it would blank the socket the moment it
        -- matters. The aura instead follows focus through card.glowMul.
        local Glow = CoD.TextWithBg.new( HudRef, InstanceRef )
        Glow:setLeftRight( true, false, xLo - REVEAL_GLOW_PAD, xHi + REVEAL_GLOW_PAD )
        Glow:setTopBottom( true, false, CARD_Y0 - REVEAL_GLOW_PAD, CARD_Y1 + REVEAL_GLOW_PAD )
        Glow.Text:setText( "" )
        Glow.Bg:setAlpha( 1 )
        Glow:setAlpha( 0 )
        self:addElement( Glow )
        card.Glow = Glow
        card.glowBase = 0    -- set on land, read by the focus/flash branches
        card.glowMul  = 1

        -- The socket is two flat panels, not one bordered one: a rarity-tinted
        -- rect with a dark rect inset over it leaves a REVEAL_SOCKET_PAD rim,
        -- which is the only way to draw a border out of CoD.TextWithBg. The rim
        -- is what carries the charge — its alpha ramps over the server's hold.
        local SockRim = CoD.TextWithBg.new( HudRef, InstanceRef )
        SockRim:setLeftRight( true, false, xLo, xHi )
        SockRim:setTopBottom( true, false, CARD_Y0, CARD_Y1 )
        SockRim.Text:setText( "" )
        SockRim.Bg:setAlpha( 1 )
        SockRim:setAlpha( 0 )
        self:addElement( SockRim )
        card.SockRim = SockRim

        local SockFill = CoD.TextWithBg.new( HudRef, InstanceRef )
        SockFill:setLeftRight( true, false, xLo + REVEAL_SOCKET_PAD, xHi - REVEAL_SOCKET_PAD )
        SockFill:setTopBottom( true, false, CARD_Y0 + REVEAL_SOCKET_PAD, CARD_Y1 - REVEAL_SOCKET_PAD )
        SockFill.Text:setText( "" )
        SockFill.Bg:setRGB( PAL.glass[ 1 ], PAL.glass[ 2 ], PAL.glass[ 3 ] )
        SockFill.Bg:setAlpha( 1 )
        SockFill:setAlpha( 0 )
        self:addElement( SockFill )
        card.SockFill = SockFill

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

        -- [docs/172] THE LEVEL PIPS, on the card face where its baked dots were:
        -- over the art, under the burst (the Flare is added last, below).
        if art.pip then
            card.Pips = CardPips.Build( self, art.pip, xLo, xHi, CARD_Y0 )
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
            -- [tod v16.88] +35 -> +38: 222 x 34 is the hold plate's true
            -- 460/70 aspect, and the extra 3 px is what lets a 30 px button
            -- glyph sit in its gap without touching the rim. The hold bar
            -- below moved down with it (see HoldTrack).
            -- [tod v18.32] and now the rule is CODE, not a literal that happens
            -- to satisfy it. Still 34 today; it stays right the next time the
            -- card width moves — which is exactly how the class draft's copy of
            -- this plate came to be 27% too tall when the mage narrowed a card.
            local plateH = math.floor( ( ( xHi - 6 ) - ( xLo + 6 ) ) / PLATE_ASPECT + 0.5 )
            HintImg:setTopBottom( true, false, CARD_Y1 + 4, CARD_Y1 + 4 + plateH )
            HintImg:setAlpha( 0 )
            self:addElement( HintImg )
            card.HintImg = HintImg
            -- [tod v16.88] the button that drops into the plate's baked gap,
            -- centred on the card. Two sizes: the round A button at 30 px, the
            -- wide keycap at 52 px (it may have to hold "MOUSE3"). CardHint
            -- sets the image, the width and the text.
            if USE_CARD_GLYPH_ART and art.holdPlate then
                local cx = ( xLo + xHi ) / 2
                -- [tod v18.32] where the GAP is, from the plate as drawn. Both
                -- rects are written by CardHint (the pad button is square, the
                -- keycap is 2:1 — no one rect serves both unstretched).
                local plateL = xLo + 6
                local plateW = ( xHi - 6 ) - plateL
                card.plateH   = math.floor( plateW / PLATE_ASPECT + 0.5 )
                card.lockCx   = math.floor( plateL + plateW * PLATE_GAP_CX )
                card.lockCy   = math.floor( CARD_Y1 + 4 + card.plateH * PLATE_INK_CY )
                card.lockGapW = math.floor( plateW * PLATE_GAP_W )
                local LockGlyph = LUI.UIImage.new()
                LockGlyph:setAlpha( 0 )
                self:addElement( LockGlyph )
                card.LockGlyph = LockGlyph
                local LockKeyText = LUI.UIText.new()
                LockKeyText:setLeftRight( true, false, cx - 26, cx + 26 )
                LockKeyText:setTopBottom( true, false, CARD_Y1 + 13, CARD_Y1 + 29 )
                LockKeyText:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
                LockKeyText:setRGB( 0.06, 0.07, 0.10 )
                LockKeyText:setAlpha( 0 )
                self:addElement( LockKeyText )
                card.LockKeyText = LockKeyText
                -- [tod v17.27] the key name in the map's typeface, over this
                -- cap. Built last so the glyphs draw above plate and cap alike.
                card.LockKey = TodKeycapMake( self, LockKeyText )
            end
            if USE_HINT_FRAME_ART and art.hintFrame then
                -- [tod v16.32] the key line over the blank frame; centred on
                -- the plate (plate spans CARD_Y1+4..+35, centre +19.5)
                local HintText = LUI.UIText.new()
                HintText:setLeftRight( true, false, xLo + 16, xHi - 16 )
                HintText:setTopBottom( true, false, CARD_Y1 + 14, CARD_Y1 + 26 )
                HintText:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
                HintText:setRGB( 1, 1, 1 )
                HintText:setAlpha( 0 )
                self:addElement( HintText )
                card.HintText = HintText
            end
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

        -- [tod v16.88] THE HOLD BAR IN ART. Deliberately NEW elements rather
        -- than re-skinning the two above: `CoD.TextWithBg` is defined in the
        -- bytecode LUI core, so whether its `.Bg` accepts setImage is
        -- UNVERIFIABLE from this tree — and a wrong guess in LUI fails
        -- SILENTLY, taking the whole menu with it. The colour quads stay
        -- constructed and are simply held at alpha 0 whenever the art is on;
        -- with the flag off they are still the bar, unchanged.
        -- Geometry: the plate above now ends at CARD_Y1 + 38, so the bar sits
        -- at +42 and is 10 px tall — the timer art's true 460/24 aspect at
        -- this width, where the old quad was a flat 4 px.
        if USE_CARD_GLYPH_ART and art.barTrack then
            local BarTrack = LUI.UIImage.new()
            BarTrack:setLeftRight( true, false, xLo + 14, xHi - 14 )
            BarTrack:setTopBottom( true, false, CARD_Y1 + 42, CARD_Y1 + 52 )
            BarTrack:setImage( art.barTrack )
            BarTrack:setAlpha( 0 )
            self:addElement( BarTrack )
            card.BarTrack = BarTrack

            local BarFill = LUI.UIImage.new()
            BarFill:setLeftRight( true, false, xLo + 14, xLo + 14 )
            BarFill:setTopBottom( true, false, CARD_Y1 + 42, CARD_Y1 + 52 )
            BarFill:setImage( art.barFill )
            BarFill:setAlpha( 0 )
            self:addElement( BarFill )
            card.BarFill = BarFill
        end
        card.holdLo = xLo + 14
        card.holdHi = xHi - 14

        -- THE BURST. Added LAST inside BuildCard so it draws over this card's
        -- own face. It does not need to clear the OTHER card: the two rects are
        -- 74px apart and the burst grows by at most REVEAL_FLARE_GROW (34).
        local Flare = CoD.TextWithBg.new( HudRef, InstanceRef )
        Flare:setLeftRight( true, false, xLo, xHi )
        Flare:setTopBottom( true, false, CARD_Y0, CARD_Y1 )
        Flare.Text:setText( "" )
        Flare.Bg:setAlpha( 1 )
        Flare:setAlpha( 0 )
        self:addElement( Flare )
        card.Flare = Flare

        -- own geometry, so the reveal helpers take a card and nothing else
        card.xLo, card.xHi = xLo, xHi
        card.xMid = ( xLo + xHi ) * 0.5

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
        if card.Pips then
            card.group[ #card.group + 1 ] = card.Pips.root
        end
        return card
    end

    local function SetCardAlpha( card, a )
        for i = 1, #card.group do
            -- CardImg stays hidden while it does not carry this card (see imgLive)
            if card.group[ i ] == card.CardImg and card.imgLive == false then
                card.group[ i ]:setAlpha( 0 )
            else
                card.group[ i ]:setAlpha( a )
            end
        end
    end

    local CardA = BuildCard( CARD_AX0, CARD_AX1, "" )
    local CardB = BuildCard( CARD_BX0, CARD_BX1, "" )
    -- [docs/172] the two pip rows, for tools/test_card_pips.lua (nil when the flag is off)
    self.todPipRows = { a = CardA.Pips, b = CardB.Pips }

    -- ---- THE REVEAL, client half (v14.52) ----------------------------------
    -- Per-slot latches. Render() runs on EVERY model change, so "this card just
    -- landed" has to be told apart from "this card is still sitting there" —
    -- these carry what the slot looked like on the previous paint. They are
    -- reset in the show == 0 branch, so a deal can never inherit the last one's
    -- edges.
    local rv = { a = { d = 0, r = 0 }, b = { d = 0, r = 0 } }
    local wasRevealing = false

    -- ONLY ALPHA AND RECTS ARE EVER TWEENED here. Those are the two lanes this
    -- file and the vendored Aetherium kit it copies from have actually shipped
    -- (AetheriumPowerupNotification tweens both; nothing in-tree tweens colour).
    -- An RGB tween would be a guess, so every colour below is STAMPED and only
    -- its alpha moves.

    -- Socket down, now. Called on every settled paint rather than only on the
    -- transition — the same both-directions-every-paint discipline as the
    -- locked-card tint further down. A socket stranded by an aborted deal has
    -- nothing else that would ever take it back down.
    local function SocketClear( card )
        card.SockRim:completeAnimation()
        card.SockFill:completeAnimation()
        card.SockRim:setAlpha( 0 )
        card.SockFill:setAlpha( 0 )
        card.SockRim:setLeftRight( true, false, card.xLo, card.xHi )
        card.SockFill:setLeftRight( true, false, card.xLo + REVEAL_SOCKET_PAD, card.xHi - REVEAL_SOCKET_PAD )
    end

    -- The empty slot, charging toward `rar`. Re-entered on every rarity change,
    -- which is exactly when the server starts that slot's hold — so the ramp
    -- and the wait are the same event seen from two sides.
    local function SocketOpen( card, rar )
        local col = ( RARITY[ rar ] or RARITY[ 1 ] ).col
        card.SockRim:completeAnimation()
        card.SockFill:completeAnimation()
        card.SockRim:setLeftRight( true, false, card.xLo, card.xHi )
        card.SockRim:setTopBottom( true, false, CARD_Y0, CARD_Y1 )
        card.SockRim.Bg:setRGB( col[ 1 ], col[ 2 ], col[ 3 ] )
        card.SockFill:setLeftRight( true, false, card.xLo + REVEAL_SOCKET_PAD, card.xHi - REVEAL_SOCKET_PAD )
        card.SockFill:setTopBottom( true, false, CARD_Y0 + REVEAL_SOCKET_PAD, CARD_Y1 - REVEAL_SOCKET_PAD )
        card.SockFill:setAlpha( 0.9 )

        card.SockRim:setAlpha( 0.12 )
        card.SockRim:beginAnimation( "tod_charge", REVEAL_HOLD_MS[ rar ] or 100,
                                     false, false, CoD.TweenType.Linear )
        card.SockRim:setAlpha( ( rar >= 2 ) and 1 or 0.5 )

        card.Flare:completeAnimation()
        card.Flare:setAlpha( 0 )
        card.Glow:completeAnimation()
        card.Glow:setAlpha( 0 )
        card.glowBase = 0
    end

    -- The pull. Socket blows apart into the card's spine, the face opens out of
    -- that same spine, and the rarity pays for itself in the burst it throws.
    local function LandCard( card, rar )
        local col = ( RARITY[ rar ] or RARITY[ 1 ] ).col
        local mid = card.xMid

        card.SockRim:completeAnimation()
        card.SockFill:completeAnimation()
        card.SockRim:beginAnimation( "tod_sock_out", REVEAL_SOCKET_MS, false, false, CoD.TweenType.Linear )
        card.SockRim:setLeftRight( true, false, mid - 2, mid + 2 )
        card.SockRim:setAlpha( 0 )
        card.SockFill:beginAnimation( "tod_sock_out", REVEAL_SOCKET_MS, false, false, CoD.TweenType.Linear )
        card.SockFill:setLeftRight( true, false, mid - 2, mid + 2 )
        card.SockFill:setAlpha( 0 )

        -- Bounce OVERSHOOTS the final rect and settles back — that is the pop.
        -- Linear here reads as the card sliding into place, which is the one
        -- thing this whole feature exists to stop looking like.
        -- (No-art fallback: with USE_CARD_SET_ART off there is no CardImg to
        -- open, so the flip is skipped and the burst carries the moment alone.)
        if card.CardImg then
            card.CardImg:completeAnimation()
            card.CardImg:setLeftRight( true, false, mid - 3, mid + 3 )
            card.CardImg:setTopBottom( true, false, CARD_Y0 + 26, CARD_Y1 - 26 )
            -- a text-only card (imgLive false) flips its frame, never a stale picture
            card.CardImg:setAlpha( ( card.imgLive == false ) and 0 or 1 )
            card.CardImg:beginAnimation( "tod_flip", REVEAL_FLIP_MS, false, false, CoD.TweenType.Bounce )
            card.CardImg:setLeftRight( true, false, card.xLo, card.xHi )
            card.CardImg:setTopBottom( true, false, CARD_Y0, CARD_Y1 )
        end

        -- the aura it keeps, and the burst it throws once
        card.glowBase = REVEAL_GLOW[ rar ] or 0
        card.Glow:completeAnimation()
        card.Glow.Bg:setRGB( col[ 1 ], col[ 2 ], col[ 3 ] )
        card.Glow:setAlpha( card.glowBase * ( card.glowMul or 1 ) )

        card.Flare:completeAnimation()
        local peak = REVEAL_FLARE_PEAK[ rar ] or 0
        if peak > 0 then
            local grow = REVEAL_FLARE_GROW[ rar ]
            card.Flare.Bg:setRGB( col[ 1 ], col[ 2 ], col[ 3 ] )
            card.Flare:setLeftRight( true, false, card.xLo, card.xHi )
            card.Flare:setTopBottom( true, false, CARD_Y0, CARD_Y1 )
            card.Flare:setAlpha( peak )
            card.Flare:beginAnimation( "tod_flare", REVEAL_FLARE_MS[ rar ], false, false, CoD.TweenType.Linear )
            card.Flare:setLeftRight( true, false, card.xLo - grow, card.xHi + grow )
            card.Flare:setTopBottom( true, false, CARD_Y0 - grow, CARD_Y1 + grow )
            card.Flare:setAlpha( 0 )
        else
            card.Flare:setAlpha( 0 )
        end
    end

    -- Panel down: every reveal element back to its rest state, INCLUDING the
    -- card face's RECT. A deal aborted mid-flip (the player goes down, the
    -- station's takeover) otherwise leaves CardImg parked at whatever sliver
    -- the tween had reached, and the NEXT deal paints a correct image into a
    -- wrong rect — a bug that would only ever show up on the second card.
    local function RevealHide( card )
        SocketClear( card )
        card.Flare:completeAnimation()
        card.Flare:setAlpha( 0 )
        card.Glow:completeAnimation()
        card.Glow:setAlpha( 0 )
        card.glowBase = 0
        card.glowMul = 1
        if card.CardImg then
            card.CardImg:completeAnimation()
            card.CardImg:setLeftRight( true, false, card.xLo, card.xHi )
            card.CardImg:setTopBottom( true, false, CARD_Y0, CARD_Y1 )
        end
    end

    -- One slot, one paint. `rar`/`dom` are that slot's live fields; see the
    -- REVEAL header at the top of this file for the three-fact contract.
    local function RevealDrive( key, card, rar, dom, revealing )
        local s = rv[ key ]
        if revealing then
            if dom == 0 then
                if rar >= 1 then
                    if s.r ~= rar or s.d ~= 0 then
                        SocketOpen( card, rar )
                    end
                else
                    SocketClear( card )   -- one-card deal: no second socket
                end
            elseif s.d == 0 then
                LandCard( card, rar )
            end
        else
            SocketClear( card )
        end
        s.d = dom
        s.r = rar
    end

    -- The aura follows the card it belongs to: full on the focused card, dimmed
    -- on the passed-over one, gone when the slot never landed. Called at the end
    -- of every Render so it cannot disagree with the alphas set above it.
    local function ApplyGlow( card )
        card.Glow:setAlpha( ( card.glowBase or 0 ) * ( card.glowMul or 1 ) )
    end

    -- [tod v14.39] CLASS TIER GATE BADGE — constructed HERE, after both cards,
    -- because LUI draws in addElement order and this has to sit ON TOP of the
    -- locked card (user 2026-08-31: "grayed out with these new images over the
    -- top of it"). Declared far above so the render closure captures it; only
    -- the construction is deferred. Position is set per paint — the stamp band
    -- over card B when a locked tier card is dealt, the top-left gutter
    -- otherwise — so the coordinates here are just a safe initial state.
    if art.tierGate then
        TierGateImg = LUI.UIImage.new()
        TierGateImg:setLeftRight( true, false, 50, 330 )
        TierGateImg:setTopBottom( true, false, 150, 210 )
        TierGateImg:setAlpha( 0 )
        self:addElement( TierGateImg )
    end

    -- ---- state + render -----------------------------------------------------
    local st = { show = 0, ad = 0, ar = 1, al = 0, bd = 0, br = 1, bl = 0, luck = 0, focus = 0, time = 0, hold = 0 }
    -- LUCK AT DEAL TIME, latched on the show 0->1 edge (audit 2026-08-25).
    -- todUpgLuck is the LIVE luck bar and it keeps moving while the cards are
    -- up — which is fine for the top-left bar, but the badge claims to describe THESE
    -- rolls. At a HEAVENLY GIFT ALTAR the world is NOT paused, so a player who
    -- keeps killing watched the badge climb under a deal it had nothing to do
    -- with. Latched client-side because a second clientfield is not affordable
    -- (the pool is at 58 of the proven 61 bits).
    local dealLuck = 0
    local wasShown = 0
    -- [docs/172] each slot's decoded tod_upg_pips (cap + levels paid), or nil
    local pipData = {}

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
            -- [tod v14.12] the kept-list is NOT enumerated here on purpose: it
            -- has grown three times (DR+LUCK -> +sprint pair -> +vitality ->
            -- +headshot/scavenger) and a stale enumeration lies on a card.
            -- tierSafe() in AetheriumStartMenu.lua is the fallback; the pause
            -- menu's reset badges show the player exactly what survives.
            d = { name = "TIER " .. tierN .. ": " .. gun,
                  desc = cls .. " - new weapon. Gun upgrades reset; class-wide upgrades kept",
                  max = 3 }
        end
        local r = RARITY[ rar ] or RARITY[ 1 ]
        -- DARK UPGRADE: the server sends the sentinel in the LEVEL field rather
        -- than a real level. Checked AFTER the tier decode above on purpose --
        -- the tier card packs class+tier into the same field and can legally
        -- reach 15 (class 4 / tier 3 would be 7, so it cannot today, but the
        -- ordering is what keeps that true if the ladder ever grows).
        local isDark = ( cur == DARK_L and dom ~= TIER_DOMAIN )
        if isDark then
            r = { tag = "DARK UPGRADE", col = { 0.85, 0.15, 0.22 } }
        end
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
            -- DARK art wins when it exists. When USE_DARK_CARD_ART is off there
            -- is no art.dark table at all and a dark card falls through to its
            -- ULTIMATE image -- correct-looking, just not yet distinct.
            local darkImg = isDark and art.dark and art.dark[ dom ] or nil
            -- An enabled Dark card without its own art must show DARK text,
            -- never the Ultimate image with its baked, incorrect +3 label.
            if isDark and not darkImg then
                set = nil
            end
            -- imgLive (2026-09-09): whether CardImg currently carries THIS card.
            -- LandCard's flip and SetCardAlpha used to set its alpha to 1
            -- unconditionally, so a text-only DARK card (CHAIN LIGHTNING, no
            -- _dark art) drew its composite text over the PREVIOUS deal's
            -- picture -- user 2026-09-09: "chain lightning LUA over an ice
            -- shatter ultimate card". An image element cannot be cleared, only
            -- hidden, so every alpha writer has to know whether it is live.
            card.imgLive = true
            if darkImg then
                card.CardImg:setImage( darkImg )
                card.CardImg:setAlpha( 1 )
            elseif set and set[ rar ] then
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
                card.imgLive = false
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
            CardHint( chosen, "locked", 1 )
            chosen.Bind:setText( "" )
        else
            chosen.Bind:setText( "LOCKED IN" )
            chosen.Bind:setRGB( PAL.pick[ 1 ], PAL.pick[ 2 ], PAL.pick[ 3 ] )
            chosen.Bind:setAlpha( 1 )
        end
        CardHint( other, "off", 0 )
        for i = 1, #other.group do
            other.group[ i ]:setAlpha( 0.2 )
        end
    end

    local function Render()
        if st.show == 0 then
            RevealHide( CardA )
            RevealHide( CardB )
            -- [docs/172] motion off; the dots fade out with the panel
            CardPips.Freeze( CardA.Pips )
            CardPips.Freeze( CardB.Pips )
            rv.a.d, rv.a.r = 0, 0
            rv.b.d, rv.b.r = 0, 0
            self:completeAnimation()
            self:beginAnimation( "keyframe", 250, false, false, CoD.TweenType.Linear )
            self:setAlpha( 0 )
            -- [tod 2026-09-22, bug review F21] re-arm the luck latch below:
            -- this early return used to skip `wasShown = st.show`, so the
            -- badge froze on the FIRST deal's luck for the rest of the life
            -- (in solo, the round-1 deal at 0% = no badge for the whole run).
            wasShown = 0
            return
        end

        if st.show ~= 0 and wasShown == 0 then
            dealLuck = st.luck            -- freeze the luck this deal was rolled at
        end
        wasShown = st.show

        -- [tod v14.52] THE REVEAL IS RUNNING. show == 1 with focus == 0 is the
        -- server's reveal contract and is reachable no other way — see the
        -- REVEAL header at the top of this file. While it holds, the panel is
        -- NOT an input surface: no focus, no hold bar, no countdown, no gate
        -- badge. Everything below reads this rather than re-deriving it.
        local revealing = ( st.show == 1 and st.focus == 0 )

        -- [tod v14.52] THE PANEL'S OWN completeAnimation MOVED UP HERE, away
        -- from the beginAnimation/setAlpha pair it used to sit against at the
        -- bottom of this function. LUI's completeAnimation is documented
        -- nowhere in this tree and MAY snap child animations as well as the
        -- element's own — and if it does, calling it after the reveal has just
        -- started a card's tween would end that tween on the frame it began,
        -- silently, with everything still looking correct in the code. Run it
        -- FIRST and the question stops mattering: whatever it reaches, it
        -- reaches before this paint's tweens exist. The fade-in pair stays at
        -- the bottom, where it only ever touches this element's alpha.
        self:completeAnimation()

        -- [tod v14.52] ARM THE SOCKETS OFF THE REVEAL'S OWN 0 -> 1 EDGE, not off
        -- the slot data. rv latches per-slot FIELDS, and a deal can re-open with
        -- the same rarity sitting in the same slot — no field changes, no edge,
        -- no socket, and slot A spends its whole hold as a blank gap.
        --
        -- That is not hypothetical: a round event kills an in-flight PERSONAL
        -- STATION pick (level notify "tod_global_upg_takeover") and re-presents
        -- immediately, so show goes 1 -> 1 and the show == 0 reset below is
        -- never reached. -1 is a rarity no slot can hold, which forces the
        -- "rarity changed" branch in RevealDrive exactly once.
        if revealing and not wasRevealing then
            rv.a.r, rv.a.d = -1, 0
            rv.b.r, rv.b.d = -1, 0
        end
        wasRevealing = revealing

        PaintCard( CardA, st.ad, st.ar, st.al )
        PaintCard( CardB, st.bd, st.br, st.bl )

        -- [tod v16] CLASS badge. Unlike the luck badge this is not keyed to the
        -- deal -- it states a standing fact about the player, so it is simply on
        -- whenever the panel is. CoD.TodClass is pushed by
        -- _tod_upgrades::push_panel_hints before EVERY deal (0 = classless).
        if ClassBadge then
            local ci = CoD.TodClass or 0
            -- NO UPPER CLAMP: the table is the authority, so a fifth class
            -- shows its badge the moment MAGE_ENABLED registers one. The
            -- old "ci <= 4" would have hidden it silently.
            if ci >= 1 and art.classPlate[ ci ] then
                ClassBadge:setImage( art.classPlate[ ci ] )
                ClassBadge:setAlpha( 1 )
            else
                ClassBadge:setAlpha( 0 )
            end
        end

        -- LUCK BOOST badge (baked per 10%); LuckLine text is the no-art fallback
        if LuckBadge then
            local li = dealLuck            -- the deal's luck, not the live bar
            if li > 10 then li = 10 end
            if li > 0 and art.badges[ li ] then
                LuckBadge:setImage( art.badges[ li ] )
                LuckBadge:setAlpha( 1 )
                if LuckLegend then LuckLegend:setAlpha( 1 ) end
            else
                LuckBadge:setAlpha( 0 )
                if LuckLegend then LuckLegend:setAlpha( 0 ) end
            end
            LuckLine:setText( "" )
        elseif dealLuck > 0 then
            LuckLine:setText( "LUCK " .. ( dealLuck * 10 ) .. "% BOOSTED THESE ROLLS" )
        else
            LuckLine:setText( "" )
        end

        -- [tod v14.35] CLASS TIER floor requirement — see TierLine above.
        -- Read live from the shared global rather than latched at panel-open:
        -- GSC pushes the value immediately BEFORE it raises todUpgShow, so it
        -- is already correct on the first paint, and a re-push (the station's
        -- re-present after a round event takes over) lands without any extra
        -- wiring. Rendered only while the panel is actually up, so a value left
        -- over from the last deal can never flash on a hidden panel.
        local need = CoD.TodTierNeed or 0
        -- [tod v14.39] IS THE RIGHT CARD A LOCKED TIER CARD? The server deals
        -- the promotion even below its floor gate now and marks it unselectable
        -- (_tod_upgrades::make_tier_option). No new channel was needed to say
        -- so: `bd == TIER_DOMAIN` means a tier card is in the right slot, and
        -- `need > 0` means this player is floor-blocked — together they can only
        -- mean the dealt card is the locked one. A tier card dealt to a player
        -- who HAS cleared the floor arrives with need == 0 and stays takeable.
        -- `not revealing` (v14.52): while the cards are still being dealt, bd is
        -- 0 for slot B by design, so this would read false, park the badge in
        -- the gutter, and then jump it onto the card the instant B lands. One
        -- badge that MOVES mid-reveal is worse than one that arrives with the
        -- card it belongs to.
        local lockedB = ( not revealing ) and ( st.bd == TIER_DOMAIN ) and need > 0
        -- WHERE THE BADGE GOES depends on whether there is a card to attach it
        -- to: STAMPED ACROSS the locked card when one is dealt, in the top-left
        -- gutter otherwise. NEVER BOTH — one badge, one meaning, two homes.
        --
        -- THE STAMP BAND IS MEASURED OFF THE CARD ART, not eyeballed (user
        -- 2026-08-31: "grayed out with these new images over the top of it").
        -- The 768x1152 tier card draws into 234x351 at x 677..911, y 226..577,
        -- and it is dense with text that must stay readable — the whole reason
        -- the card is shown at all is so the player sees WHAT they are climbing
        -- toward. Bands, as fractions of the source art:
        --   0.074-0.165  "TIER 2" header      -> screen 252..284   KEEP
        --   0.19 -0.61   gun illustration     -> screen 293..440   stamp here
        --   0.616-0.69   class name banner    -> screen 442..468   KEEP
        --   0.707-0.868  gun name + "GUN UPGRADES RESET" -> 474..531  KEEP
        -- So the badge lands on the PICTURE and never on a word. It overhangs
        -- the card by 23px each side, which reads as a deliberate stamp rather
        -- than a mis-sized inlay, and clears card A (ends 603) comfortably.
        if TierGateImg then
            if lockedB then
                TierGateImg:setLeftRight( true, false, 654, 934 )   -- 280 wide, centred on card B's 794
                TierGateImg:setTopBottom( true, false, 336, 396 )   -- across the gun illustration only
            else
                -- [tod v16] ONE ROW DOWN. This was 150..210, which the CLASS
                -- badge now owns; stacked under it instead of on top of it.
                TierGateImg:setLeftRight( true, false, 50, 330 )
                TierGateImg:setTopBottom( true, false, 216, 276 )
            end
        end
        if st.show == 1 and need > 0 and not revealing then
            -- The tier comes from TIER_FLOOR_TO_TIER (file scope, LOCKSTEP with
            -- GSC tier_floor_req). It was floor/10+1 until 2026-09-02, which
            -- only inverts an evenly spaced ladder; see the table's comment.
            local nextTier = TIER_FLOOR_TO_TIER[ need ] or 2
            -- ART FIRST, text only when the strip for this tier is missing —
            -- and per-tier, not per-set, so a half-installed pair still shows
            -- the correct thing for the tier that has its strip.
            local strip = art.tierGate and art.tierGate[ nextTier ]
            if TierGateImg and strip then
                TierGateImg:setImage( strip )
                TierGateImg:setAlpha( 1 )
                TierLine:setText( "" )
            else
                if TierGateImg then
                    TierGateImg:setAlpha( 0 )
                end
                TierLine:setText( "CLASS TIER " .. nextTier .. " - REACH FLOOR " .. need )
            end
        else
            if TierGateImg then
                TierGateImg:setAlpha( 0 )
            end
            TierLine:setText( "" )
        end

        -- `not revealing` (v14.52): the countdown does not start until input
        -- does, and it does not — wait_for_choice runs AFTER the reveal. Showing
        -- "AUTO IN 15s" over two empty sockets promises a clock that is not
        -- ticking yet.
        if st.show == 1 and st.time > 0 and not revealing then
            ShowSwitchPlate( true )
            if TimeTrack then
                -- [tod v16.88] THE BAR IS THE CLOCK — no digits. It drains from
                -- full toward the left as the deal times out. The server sends
                -- whole seconds and MAX is the deal's own start value, so the
                -- first paint is always a full bar whatever the timeout is set
                -- to; clamped because a station deal and a round deal do not
                -- share a length.
                TimeLine:setText( "" )
                if st.time > timeMaxSeen then
                    timeMaxSeen = st.time
                end
                local maxT = timeMaxSeen
                if maxT < 1 then
                    maxT = 1
                end
                local frac = st.time / maxT
                if frac > 1 then frac = 1 end
                if frac < 0 then frac = 0 end
                TimeFill:setLeftRight( false, false, -140, -140 + 280 * frac )
                TimeTrack:setAlpha( 0.85 )
                TimeFill:setAlpha( 1 )
                -- the last few seconds go red, the one thing the text did that
                -- a bar must not lose
                if st.time <= MAX_LEVEL_TIME_DANGER then
                    TimeFill:setRGB( 1.0, 0.25, 0.3 )
                else
                    TimeFill:setRGB( 1, 1, 1 )
                end
            elseif SwitchHintImg then
                TimeLine:setText( "AUTO IN " .. st.time .. "s" )
            else
                TimeLine:setText( SwitchHint() .. "   AUTO IN " .. st.time .. "s" )
            end
            if not TimeTrack then
                if st.time <= MAX_LEVEL_TIME_DANGER then
                    TimeLine:setRGB( 1.0, 0.25, 0.3 )
                else
                    TimeLine:setRGB( PAL.dim[ 1 ], PAL.dim[ 2 ], PAL.dim[ 3 ] )
                end
            end
        else
            ShowSwitchPlate( false )
            TimeLine:setText( "" )
            if TimeTrack then
                TimeTrack:setAlpha( 0 )
                TimeFill:setAlpha( 0 )
                -- reset the watched maximum, or the NEXT deal starts its bar
                -- part-drained against the previous deal's longer clock
                timeMaxSeen = 0
            end
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
                CardHint( focused, "lock", bright and 1 or 0.75 )
                CardHint( other, "off", 0 )
                focused.Bind:setText( "" )
            else
                focused.Bind:setText( LockHint() )
                focused.Bind:setRGB( PAL.pick[ 1 ], PAL.pick[ 2 ], PAL.pick[ 3 ] )
                focused.Bind:setAlpha( bright and 1 or 0.75 )
            end
            other.Bind:setText( "" )
            local w = ( focused.holdHi - focused.holdLo ) * ( hold / 15 )
            -- [tod v16.88] ART BAR WHEN PRESENT, COLOUR QUADS OTHERWISE — never
            -- both, or the quad shows through the art's rounded ends.
            if focused.BarTrack then
                focused.HoldTrack.Bg:setAlpha( 0 )
                focused.HoldFill.Bg:setAlpha( 0 )
                focused.BarTrack:setAlpha( 0.85 )
                focused.BarFill:setLeftRight( true, false, focused.holdLo, focused.holdLo + w )
                focused.BarFill:setAlpha( ( hold > 0 ) and 1 or 0 )
                other.BarTrack:setAlpha( 0 )
                other.BarFill:setAlpha( 0 )
            else
                focused.HoldTrack.Bg:setAlpha( 0.3 )
                focused.HoldFill:setLeftRight( true, false, focused.holdLo, focused.holdLo + w )
                focused.HoldFill.Bg:setAlpha( ( hold > 0 ) and 0.95 or 0 )
            end
            other.HoldTrack.Bg:setAlpha( 0 )
            other.HoldFill.Bg:setAlpha( 0 )
        end
        -- single-option events (todUpgBD == 0): CardB was hidden by PaintCard
        -- with STALE text still set — never re-raise it (the ghost-card bug,
        -- verify pass 2026-08-19).
        local two = ( DOMAIN[ st.bd ] ~= nil )
        if revealing then
            -- [tod v14.52] THE FOCUS BLOCK IS SKIPPED, NOT ADAPTED. It writes an
            -- alpha to every element of both cards on every paint, which is
            -- precisely what a reveal tween cannot survive — and there is
            -- nothing for it to say yet: no card is focused until the deal
            -- finishes. PaintCard has already put each slot at its natural
            -- alpha (1 once its domain arrives, 0 while it is still a socket),
            -- so the cards are correct without it.
            CardA.glowMul = 1
            CardB.glowMul = 1
            CardA.Bind:setText( "" )
            CardB.Bind:setText( "" )
            CardHint( CardA, "off", 0 )
            CardHint( CardB, "off", 0 )
            CardA.HoldTrack.Bg:setAlpha( 0 )
            CardA.HoldFill.Bg:setAlpha( 0 )
            CardB.HoldTrack.Bg:setAlpha( 0 )
            CardB.HoldFill.Bg:setAlpha( 0 )
            -- [tod v16.88] the art bar hides with the quads
            if CardA.BarTrack then
                CardA.BarTrack:setAlpha( 0 )
                CardA.BarFill:setAlpha( 0 )
                CardB.BarTrack:setAlpha( 0 )
                CardB.BarFill:setAlpha( 0 )
            end
        elseif st.show == 1 then
            if two and ( st.focus == 3 or st.focus == 4 ) then
                FocusCards( CardB, CardA, st.focus == 3, st.hold )
                CardB.glowMul, CardA.glowMul = 1, 0.45
            else
                FocusCards( CardA, CardB, st.focus ~= 2, st.hold )
                CardA.glowMul, CardB.glowMul = 1, 0.45
                if not two then
                    SetCardAlpha( CardB, 0 )
                    CardB.HoldTrack.Bg:setAlpha( 0 )
                    CardB.HoldFill.Bg:setAlpha( 0 )
                    CardB.glowMul = 0
                end
            end
        else
            CardA.HoldTrack.Bg:setAlpha( 0 )
            CardA.HoldFill.Bg:setAlpha( 0 )
            CardB.HoldTrack.Bg:setAlpha( 0 )
            CardB.HoldFill.Bg:setAlpha( 0 )
            -- [tod v16.88] the art bar hides with the quads
            if CardA.BarTrack then
                CardA.BarTrack:setAlpha( 0 )
                CardA.BarFill:setAlpha( 0 )
                CardB.BarTrack:setAlpha( 0 )
                CardB.BarFill:setAlpha( 0 )
            end
        end

        -- [tod v14.39] THE LOCKED CARD'S LOOK — applied AFTER the focus block,
        -- because that block is what sets the alphas and would otherwise undo
        -- this on the next paint.
        --
        -- A normal unfocused card already sits at 0.4; that is not enough on its
        -- own, because "unfocused" and "unselectable" would look identical and
        -- the player would keep trying to reach it. So the locked card ALSO
        -- takes a cold grey-blue tint, which no live card ever has — the tint,
        -- not the alpha, is what carries "dead", and the stamped badge says why.
        --
        -- THE DIM IS DELIBERATELY MILD (0.55, not the 0.22 this first shipped
        -- with). Alpha and tint MULTIPLY: 0.22 x ~0.5 left the card at ~0.11
        -- effective, which grey it out so hard the gun name stopped being
        -- readable — and being able to read WHAT you are climbing toward is the
        -- entire reason the card is dealt instead of hidden. 0.55 x ~0.6 lands
        -- near 0.33: below a live unfocused card, still legible.
        --
        -- THE RESTORE IS NOT OPTIONAL. setRGB persists on the element, so a
        -- deal that skipped this branch would inherit the previous deal's tint
        -- and show a live, takeable card looking dead. Both directions are
        -- written every paint, deliberately — the same discipline as the
        -- ghost-card fix above.
        if CardB.CardImg then
            if lockedB and st.show == 1 then
                CardB.CardImg:setRGB( 0.55, 0.60, 0.72 )
            else
                CardB.CardImg:setRGB( 1, 1, 1 )
            end
        end
        if lockedB and st.show == 1 then
            SetCardAlpha( CardB, 0.55 )
            CardB.Bind:setText( "" )
            CardHint( CardB, "off", 0 )
            CardB.HoldTrack.Bg:setAlpha( 0 )
            CardB.HoldFill.Bg:setAlpha( 0 )
        end

        if st.show == 2 then
            FlashPick( CardA, CardB )
            CardA.glowMul, CardB.glowMul = 1, 0.2
            if not two then
                SetCardAlpha( CardB, 0 )
                CardB.glowMul = 0
            end
        elseif st.show == 3 then
            FlashPick( CardB, CardA )
            CardB.glowMul, CardA.glowMul = 1, 0.2
        end

        -- [tod v14.52] THE REVEAL RUNS LAST, deliberately. PaintCard has already
        -- set each slot's image and its natural alpha, and the focus/flash
        -- blocks above have had their say about presence — the reveal is what
        -- gets to overwrite the RECT, and it must not then be overwritten back.
        RevealDrive( "a", CardA, st.ar, st.ad, revealing )
        RevealDrive( "b", CardB, st.br, st.bd, revealing )
        ApplyGlow( CardA )
        ApplyGlow( CardB )

        -- [docs/172] THE LEVEL PIPS, after the reveal has had its say. Only the
        -- right slot can hold a LOCKED promotion; unlike the gate badge this does
        -- not wait for the reveal to end - a locked card must never light its gain.
        if CardA.Pips then
            local pipLockB = ( st.bd == TIER_DOMAIN ) and ( ( CoD.TodTierNeed or 0 ) > 0 )
            local pickA = ( st.show == 2 ) and "chosen" or ( ( st.show == 3 ) and "other" or nil )
            local pickB = ( st.show == 3 ) and "chosen" or ( ( st.show == 2 ) and "other" or nil )
            CardPips.Sync( CardA.Pips, CardPips.Info( st.ad, st.ar, st.al, pipData.a ), revealing, pickA, false )
            CardPips.Sync( CardB.Pips, CardPips.Info( st.bd, st.br, st.bl, pipData.b ), revealing, pickB, pipLockB )
        end

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

    -- [docs/172] each dealt card's real cap + the levels it pays, pushed by
    -- _tod_upgrade_ui.gsc pips_push before the panel opens. LOCKSTEP decode:
    -- domain_id * 256 + max * 16 + levels per slot. A late arrival repaints.
    self:subscribeToGlobalModel( InstanceRef, "PerController", "scriptNotify", function ( model )
        if Engine.GetModelValue( model ) ~= "tod_upg_pips" then
            return
        end
        local d = CoD.GetScriptNotifyData( model )
        pipData.a = CardPips.Decode( d and d[ 1 ] )
        pipData.b = CardPips.Decode( d and d[ 2 ] )
        if st.show ~= 0 then
            Render()
        end
    end )

    return self
end

-- ---------------------------------------------------------------------------
-- Crosshair damage numbers (map 1's proven CoD.AccDmgNum design, ported):
-- each todDmgNum push (dmg*4 + headshot*2 + parity) spawns a number from a
-- pool at a scattered point near the crosshair; it rises and fades over 0.5s.
-- Headshots render teal and 25% larger; normal hits amber.
-- ---------------------------------------------------------------------------
--
-- v17.34 (user 2026-09-04: "our damage numbers ... displayed at center of
-- screen ... change all of that to use the alphabet we created and numbers").
-- The pool is CoD.TodGlyphText now, not UIText. Everything else about this
-- element is unchanged -- same 12 slots, same scatter table, same rise-and-fade
-- keyframe, same colour rules, same 14-bit decode.
--
-- SIZE IS A CAP, NOT A SCALE. setScale multiplied a TTF's own base size, which
-- is why DMG_SCALE's 0.4 never meant anything in canvas pixels (see the
-- lui-text-size-is-scale-not-box note). A cap height IS canvas pixels: 14, and
-- 17.5 for a headshot, which is the same 25% the two scales expressed.
local DMG_COLOR    = { 1.0, 0.88, 0.25 }
local DMG_COLOR_HS = { 0.20, 0.95, 0.85 }
-- ARMORED (sprinter) hits: RED, and red WINS over the headshot colour (v13.9,
-- user: "should be red too. Specific for this type of enemy to show you are
-- doing reduced damage" -- a reduced headshot is still reduced, and that is
-- the fact the colour carries). Distinct from WARN_COLOR's alarm red only by
-- use; same family on purpose.
local DMG_COLOR_RED = { 1.0, 0.22, 0.18 }
-- BURN ticks (v19.50, user 2026-09-23: "Any burn damage on enemies will be
-- orange on the damage display HUD. Multiple classes can do burn damage"):
-- TRAILBLAZER's trail and FIRE BLAST's elite burn, flag bit 3 off send_dmg_num.
-- ORANGE, and it WINS over red and headshot: a burn on an armored sprinter is
-- still a burn (fire has no hit location, so headshot never co-occurs anyway).
-- Sits between the amber hit colour and the red: more saturated and redder
-- than DMG_COLOR, clearly yellower than DMG_COLOR_RED.
local DMG_COLOR_BURN = { 1.0, 0.52, 0.08 }
local DMG_POOL   = 12
local DMG_LIFE   = 500
local DMG_RISE   = 36
-- v17.36 (user 2026-09-04, after playing v17.34: "the on screen damage numbers
-- need to be about 20% smaller"). 14 -> 11.2 and 17.5 -> 14, both x0.8, so the
-- headshot's +25% survives the cut untouched.
local DMG_CAP    = 11.2    -- cap height in canvas px (17 physical at 1080p)
local DMG_CAP_HS = 14      -- +25%, the ratio the old 0.4/0.5 scales carried
-- Kept for the fail-safe path only (TodGlyphText missing -> UIText, top of file)
local DMG_SCALE    = 0.4
local DMG_SCALE_HS = 0.5
-- The box is 34 tall and centred on the scatter point, so the baseline has to
-- sit BELOW the middle by half a cap for the number to read as centred.
-- DERIVED, not typed: v17.34 typed 0.71 for a cap of 14, and the very next
-- change moved the cap and would have left the number sitting low.
local DMG_BASEF  = 0.5 + DMG_CAP / 68   -- 68 = 2 x the box's 34px height
local DMG_SPREAD = 0.4
local DMG_BOXW   = 80
local DMG_SCATTER = {
    { 0, 0 }, { 30, -16 }, { -26, -22 }, { 10, 28 }, { -36, 6 }, { 38, 12 },
    { -12, -34 }, { 22, 34 }, { -38, -10 }, { 6, -26 }, { 34, -30 }, { -24, 26 },
}

CoD.TodDmgNum = InheritFrom( LUI.UIElement )

function CoD.TodDmgNum.new( HudRef, InstanceRef )
    local self = LUI.UIElement.new()
    CoD.TodUIOwnership.Attach( self )
    self:setClass( CoD.TodDmgNum )
    self.id = "TodDmgNum"
    self:setLeftRight( true, true, 0, 0 )
    self:setTopBottom( true, true, 0, 0 )

    -- The typeface, or the pre-v17.34 UIText if the require above did not land.
    local glyph = ( CoD.TodGlyphText ~= nil )

    local pool = {}
    for i = 1, DMG_POOL do
        local t
        if glyph then
            -- centred = true: the box is an OFFSET FROM THE SCREEN CENTRE,
            -- which is how this element has always been authored. pool 7 covers
            -- the encoding ceiling (2,047,000, seven digits) exactly.
            t = CoD.TodGlyphText.new( {
                left = -DMG_BOXW, right = DMG_BOXW, top = -17, bottom = 17,
                centered = true, align = "center", set = "digits", pool = 7,
                cap = DMG_CAP, baseFrac = DMG_BASEF,
                rgb = DMG_COLOR,
            } )
        else
            t = LUI.UIText.new()
            t:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
            t:setScale( DMG_SCALE )
            t:setRGB( DMG_COLOR[ 1 ], DMG_COLOR[ 2 ], DMG_COLOR[ 3 ] )
            t:setLeftRight( false, false, -DMG_BOXW, DMG_BOXW )
            t:setTopBottom( false, false, -17, 17 )
        end
        t:setAlpha( 0 )
        self:addElement( t )
        pool[ i ] = t
    end
    local nextIdx = 1

    local function spawnNum( dmg, hs, red, burn )
        local t = pool[ nextIdx ]
        local p = DMG_SCATTER[ nextIdx ]
        nextIdx = ( nextIdx % DMG_POOL ) + 1
        -- burn (orange) beats red; red (armored/reduced) beats headshot; scale
        -- still honours the headshot
        local c  = burn and DMG_COLOR_BURN or ( red and DMG_COLOR_RED or ( hs and DMG_COLOR_HS or DMG_COLOR ) )
        local cx = p[ 1 ] * DMG_SPREAD
        local cy = p[ 2 ] * DMG_SPREAD
        t:completeAnimation()
        t:setRGB( c[ 1 ], c[ 2 ], c[ 3 ] )
        if glyph then
            t:setCap( hs and DMG_CAP_HS or DMG_CAP )
            t:setText( tostring( dmg ) )
            -- setBox, not setLeftRight/setTopBottom: the glyph row lays out
            -- inside the box, so the one call that repaints is the one that
            -- moves it.
            t:setBox( cx - DMG_BOXW, cx + DMG_BOXW, cy - 17, cy + 17 )
        else
            t:setText( tostring( dmg ) )
            t:setScale( hs and DMG_SCALE_HS or DMG_SCALE )
            t:setLeftRight( false, false, cx - DMG_BOXW, cx + DMG_BOXW )
            t:setTopBottom( false, false, cy - 17, cy + 17 )
        end
        t:setAlpha( 1.0 )
        -- The RISE stays on the raw setTopBottom on purpose: it only moves the
        -- box, and the glyphs are children laid out in box-local coordinates,
        -- so they ride along without a repaint. Calling setBox here would
        -- re-lay-out the string 60 times a second for no visible difference.
        t:beginAnimation( "keyframe", DMG_LIFE, false, false, CoD.TweenType.Linear )
        t:setTopBottom( false, false, cy - 17 - DMG_RISE, cy + 17 - DMG_RISE )
        t:setAlpha( 0 )
    end

    -- v19.47 (user 2026-09-23: "if you use the fire blast ... and you hit
    -- multiple zombies, all of that adds up and it can say like 1 million ...
    -- I don't think I ever want to see the damage numbers combine for multiple
    -- zombies"): ONE NUMBER PER ZOMBIE. The numbers ride the int-only
    -- scriptNotify lane now (tod_dmg: amount, flags), one event per zombie
    -- hit in a server frame, so a splash over five zombies lands five events
    -- in the same frame and five numbers spawn from the pool at once. The old
    -- todDmgNum clientuimodel field carried ONE value per frame, which is why
    -- the server had to sum. The field stays registered (the 61-bit layout is
    -- untouched) but nothing writes or reads it any more.
    -- LOCKSTEP with send_dmg_num in _tod_upgrade_ui.gsc: d[1] = the amount
    -- (exact, capped at 9,999,999 = the seven-glyph pool), d[2] = flags,
    -- bit 1 headshot, bit 2 reduced (armored), bit 3 burn (v19.50, orange).
    self:subscribeToGlobalModel( InstanceRef, "PerController", "scriptNotify", function ( model )
        local ev = Engine.GetModelValue( model )
        if ev ~= "tod_dmg" then return end
        local d = CoD.GetScriptNotifyData( model )
        if not d then return end
        local dmg = ( type( d[ 1 ] ) == "number" ) and math.floor( d[ 1 ] ) or 0
        if dmg <= 0 then return end
        local flags = ( type( d[ 2 ] ) == "number" ) and math.floor( d[ 2 ] ) or 0
        local hs  = ( flags % 2 ) >= 1
        local red = ( math.floor( flags / 2 ) % 2 ) >= 1
        local burn = ( math.floor( flags / 4 ) % 2 ) >= 1
        spawnNum( dmg, hs, red, burn )
    end )

    return self
end

-- ---------------------------------------------------------------------------
-- THE HEALING AURA REVIVE BURST (2026-10-01, docs/167 item 2; lead tester:
-- "When you are at level 6 and you revive someone with healing aura it should
-- put a bunch of green + signs on screen to indicate you were healed by the
-- mage ability").
--
-- ONE int-only event, tod_heal_burst, sent by _tod_mage_elements::heal_revive
-- to the REVIVED player only, after stock's auto_revive has stood them up. It
-- carries no data the screen needs (d[1] is always 1); the event IS the burst.
--
-- The damage numbers' recipe, scaled up: a fixed pool of single "+" glyphs in
-- the map's own typeface (the digit sheet's i_tod_hud_dplus cell), placed from
-- a fixed scatter table around the screen centre, each rising and fading on
-- one keyframe. A second revive inside the life simply restarts every slot
-- (completeAnimation first, the TodDmgNum rule), so nothing can pile up.
-- Sizes and lives VARY per slot so the burst reads as a shower, not a grid.
-- ---------------------------------------------------------------------------
local HEAL_BURST_RGB  = { 0.30, 1.00, 0.45 }   -- the Healing Aura's green family
local HEAL_BURST_RGB2 = { 0.62, 1.00, 0.70 }   -- every third glyph a paler mint
local HEAL_BURST_BOXW = 40
-- { x, y, cap, life ms, rise } - x/y are offsets from the SCREEN CENTRE
-- (centered boxes, the damage numbers' frame), kept clear of the crosshair's
-- own 60-unit core so the burst frames the view instead of covering it.
local HEAL_BURST = {
    { -330, -150, 34, 1500, 70 }, {  300, -170, 30, 1400, 64 },
    { -210,  120, 26, 1300, 58 }, {  240,  130, 32, 1550, 72 },
    {  -90, -220, 22, 1250, 52 }, {  110, -235, 28, 1450, 66 },
    { -420,   20, 24, 1350, 60 }, {  430,  -10, 26, 1300, 56 },
    {  -60,  190, 30, 1500, 70 }, {   80,  210, 22, 1200, 50 },
    { -280,  -40, 20, 1150, 46 }, {  330,   60, 20, 1150, 46 },
    { -150,  -90, 18, 1100, 42 }, {  170,  -80, 18, 1100, 42 },
}

CoD.TodHealBurst = InheritFrom( LUI.UIElement )

function CoD.TodHealBurst.new( HudRef, InstanceRef )
    local self = LUI.UIElement.new()
    CoD.TodUIOwnership.Attach( self )
    self:setClass( CoD.TodHealBurst )
    self.id = "TodHealBurst"
    self:setLeftRight( true, true, 0, 0 )
    self:setTopBottom( true, true, 0, 0 )

    -- The typeface, or a plain UIText "+" if the require at the top of this
    -- file did not land (the same fail-safe the damage numbers carry).
    local glyph = ( CoD.TodGlyphText ~= nil )

    local pool = {}
    for i = 1, #HEAL_BURST do
        local p = HEAL_BURST[ i ]
        local t
        if glyph then
            t = CoD.TodGlyphText.new( {
                left = p[ 1 ] - HEAL_BURST_BOXW, right = p[ 1 ] + HEAL_BURST_BOXW,
                top = p[ 2 ] - 20, bottom = p[ 2 ] + 20,
                centered = true, align = "center", set = "digits", pool = 1,
                cap = p[ 3 ], baseFrac = 0.5 + p[ 3 ] / 80, rgb = HEAL_BURST_RGB,
            } )
            t:setText( "+" )
        else
            t = LUI.UIText.new()
            t:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
            t:setScale( p[ 3 ] / 28 )
            t:setLeftRight( false, false, p[ 1 ] - HEAL_BURST_BOXW, p[ 1 ] + HEAL_BURST_BOXW )
            t:setTopBottom( false, false, p[ 2 ] - 20, p[ 2 ] + 20 )
            t:setText( "+" )
        end
        local c = ( i % 3 == 0 ) and HEAL_BURST_RGB2 or HEAL_BURST_RGB
        t:setRGB( c[ 1 ], c[ 2 ], c[ 3 ] )
        t:setAlpha( 0 )
        self:addElement( t )
        pool[ i ] = t
    end

    local function burst()
        for i = 1, #pool do
            local t, p = pool[ i ], HEAL_BURST[ i ]
            t:completeAnimation()
            -- Back to the slot's own box before every burst: the rise below
            -- moves it, and a restarted slot must not start where the last
            -- burst left it. Raw setTopBottom, as the damage numbers do - the
            -- glyph rides its box without a repaint.
            t:setTopBottom( false, false, p[ 2 ] - 20, p[ 2 ] + 20 )
            t:setAlpha( 1 )
            t:beginAnimation( "keyframe", p[ 4 ], false, false, CoD.TweenType.Linear )
            t:setTopBottom( false, false, p[ 2 ] - 20 - p[ 5 ], p[ 2 ] + 20 - p[ 5 ] )
            t:setAlpha( 0 )
        end
    end

    self:subscribeToGlobalModel( InstanceRef, "PerController", "scriptNotify", function ( model )
        if Engine.GetModelValue( model ) ~= "tod_heal_burst" then return end
        burst()
    end )

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
    CoD.TodUIOwnership.Attach( self )
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
    CoD.TodUIOwnership.Attach( Hud )

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

    -- 2026-10-01 (docs/167 item 2): the green "+" burst for a Healing Aura
    -- Lv6 revive. Beside the damage numbers (same centred frame, same root-level
    -- hide for the pause menu and the scoreboard).
    local HealBurst = CoD.TodHealBurst.new( Hud, Instance )
    Hud:addElement( HealBurst )
    Hud.todHealBurst = HealBurst

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
    -- THE FORCED END BOARD TOO (2026-09-27, tester screenshot: the tower gauge
    -- painted over the game-end scoreboard). Stock forces that board through
    -- the per-controller "forceScoreboard" model, not the button bit, so this
    -- gate never saw it. Each bit writer below still answers only its own bit
    -- (their independence is load-bearing, see AetheriumHud.lua), but none may
    -- un-hide the HUD while the board is forced.
    local function todForcedBoard()
        local fm = Engine.GetModel( Engine.GetModelForController( Instance ), "forceScoreboard" )
        return fm ~= nil and Engine.GetModelValue( fm ) == 1
    end
    local function todBitSet( bit )
        local m = Engine.GetModel( Engine.GetModelForController( Instance ), "UIVisibilityBit." .. bit )
        local v = m and Engine.GetModelValue( m )
        return ( v and v ~= 0 ) and true or false
    end
    local function todGateHud( bit )
        local m = Engine.GetModel( Engine.GetModelForController( Instance ), "UIVisibilityBit." .. bit )
        if not m then
            return
        end
        Hud:subscribeToModel( m, function ( model )
            local v = Engine.GetModelValue( model )
            Hud:setAlpha( ( ( v and v ~= 0 ) or todForcedBoard() ) and 0 or 1 )
        end )
    end
    todGateHud( Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN )
    todGateHud( Enum.UIVisibilityBit.BIT_UI_ACTIVE )
    -- CreateModel: the root HUD makes this node only at the first force, and a
    -- subscription on a missing node never fires (the dead-node trap).
    Hud:subscribeToModel( Engine.CreateModel( Engine.GetModelForController( Instance ), "forceScoreboard" ), function ( model )
        local hide = todForcedBoard()
            or todBitSet( Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN )
            or todBitSet( Enum.UIVisibilityBit.BIT_UI_ACTIVE )
        Hud:setAlpha( hide and 0 or 1 )
    end )

    -- LUCK BAR v3 (user art drop 2026-08-29, files (65).zip): 11 BAKED fill
    -- states, i_tod_luck_00 (empty) .. i_tod_luck_10 (full) — one whole-image
    -- swap per todUpgLuck change (_tod_luck pushes bar/10). Replaces the v2
    -- frame-with-transparent-window + 10 tinted LUI quads; the gold hot tell
    -- (8..9) and the molten MAX state are baked into the art, so there is no
    -- client-side tinting or fill math left. Same screen rect as v2.
    local LUCK_X, LUCK_Y, LUCK_W, LUCK_H = 24, 56, 304, 38
    local luckStates = {}
    for i = 0, 10 do
        local n = ( i < 10 ) and ( "0" .. i ) or tostring( i )
        luckStates[ i ] = RegisterImage( "i_tod_luck_" .. n )
    end
    -- OVERCHARGE frames (v14.9): four zap variants of the full bar
    -- (i_tod_luck_max_01..04), driven by todUpgLuck 11..14 — the server cycles
    -- them (~7 Hz, random order) while the secret 150% ceiling holds. Flag per
    -- the file rule at line 27: only true once the images are installed WITH
    -- zone lines; false clamps 11..14 back to the plain full bar.
    local USE_LUCK_OVERCHARGE_ART = true
    local luckOverStates = nil
    if USE_LUCK_OVERCHARGE_ART then
        luckOverStates = {}
        for i = 1, 4 do
            luckOverStates[ i ] = RegisterImage( "i_tod_luck_max_0" .. i )
        end
    end

    -- RAMPAGE INDUCER (v14.20): the parallel RED/PURPLE set, drawn instead of
    -- the amber one while the todRampage clientfield is 1. Same eleven fill
    -- states plus four overcharge frames, same 1024x128 canvas, geometry
    -- verified pixel-identical to the amber set (alpha bbox delta 0,0,0,0), so
    -- the swap cannot move the bar. 00..09 red, 10 purple, max_01..04 purple.
    --
    -- WHY A SECOND TABLE AND NOT A TINT: the fill colour is BAKED per state
    -- (the v3 art drop retired the v2 tinted quads), so setRGB would multiply
    -- against baked amber and destroy the hot-tell at 08..09. New assets are
    -- the only lane that keeps the bar readable.
    --
    -- Same install guard as the overcharge set above: false clamps back to the
    -- amber art, so a build missing the images draws the normal bar instead of
    -- drawing nothing.
    local USE_LUCK_RAMPAGE_ART = true
    local luckStatesRmp, luckOverStatesRmp = nil, nil
    if USE_LUCK_RAMPAGE_ART then
        luckStatesRmp = {}
        for i = 0, 10 do
            local n = ( i < 10 ) and ( "0" .. i ) or tostring( i )
            luckStatesRmp[ i ] = RegisterImage( "i_tod_luck_rmp_" .. n )
        end
        luckOverStatesRmp = {}
        for i = 1, 4 do
            luckOverStatesRmp[ i ] = RegisterImage( "i_tod_luck_rmp_max_0" .. i )
        end
    end

    local LuckBar = LUI.UIImage.new()
    LuckBar:setLeftRight( true, false, LUCK_X, LUCK_X + LUCK_W )
    LuckBar:setTopBottom( true, false, LUCK_Y, LUCK_Y + LUCK_H )
    LuckBar:setImage( luckStates[ 0 ] )
    Hud:addElement( LuckBar )

    -- (no LUI text — the fill + baked gold-at-hot IS the readout, doctrine
    -- since 2026-08-20)
    -- RAMPAGE: cached because todUpgLuck changes constantly while todRampage
    -- changes at most a handful of times a match, so the luck subscription
    -- must not have to read a second model on every push.
    local luckRampageOn = false
    local luckLastValue = 0

    -- ONE draw path for both sets — the table is chosen here and nowhere else,
    -- so the rampage and overcharge branches can never disagree about which
    -- art is live.
    local function drawLuck( v )
        local fill = ( luckRampageOn and luckStatesRmp ) or luckStates
        local over = ( luckRampageOn and luckOverStatesRmp ) or luckOverStates
        -- 11..14 = OVERCHARGE zap frames (server-driven swap — this
        -- subscription only fires on a model CHANGE, which is why the
        -- server never sends the same frame twice in a row)
        if v >= 11 and v <= 14 and over then
            LuckBar:setImage( over[ v - 10 ] )
            return
        end
        if v < 0 then v = 0 elseif v > 10 then v = 10 end
        LuckBar:setImage( fill[ v ] )
    end

    local luckModel = Engine.CreateModel( Engine.GetModelForController( Instance ), "todUpgLuck" )
    if luckModel then
        LuckBar:subscribeToModel( luckModel, function ( ModelRef )
            luckLastValue = math.floor( tonumber( Engine.GetModelValue( ModelRef ) ) or 0 )
            drawLuck( luckLastValue )
        end )
    end

    -- RAMPAGE INDUCER (v14.20): swap the whole set the moment hard mode is
    -- toggled, WITHOUT waiting for the next luck change — a player sitting at a
    -- static bar (very common right after an upgrade event resets it to 0)
    -- would otherwise keep seeing amber until their next kill. Redraws at the
    -- last known fill level.
    local rampageModel = Engine.CreateModel( Engine.GetModelForController( Instance ), "todRampage" )
    if rampageModel then
        LuckBar:subscribeToModel( rampageModel, function ( ModelRef )
            local v = math.floor( tonumber( Engine.GetModelValue( ModelRef ) ) or 0 )
            luckRampageOn = ( v ~= 0 )
            drawLuck( luckLastValue )
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
    -- player, the crown lights on the roof, the base cap lights with the
    -- first cell, a pip marks the highest live PANZER (v19.46: never the
    -- Protector / Reaver), and any cell holding a
    -- DOWNED TEAMMATE swaps to its red down tile. LUI has no UV/crop, so
    -- per-cell stamping is the only way to show a variable-height lit trail —
    -- the tiles are cut out of the delivered masters by tools/slice_gauge.js.
    --
    -- v2 ART (2026-09-02, docs/70): EVERY CELL HAS ITS OWN LIT AND DOWN TILE
    -- (i_tod_gauge_c01..c25 / d01..d25), each a full-width 180x42 band of
    -- the registered master. That is what lets the trail carry the tower's
    -- five DISTRICT colours (cells 1-5 blue, 6-10 green, 11-15 orange, 16-20
    -- gold, 21-25 red — LOCKSTEP with `DISTRICTS` in gen_tower_map.js) and
    -- the lounges (cells 5/10/15/20) their wider plate, with no per-cell
    -- logic here at all: the cell number IS the image name. A shared tile
    -- was measured and rejected — the plate's vignette differs per row, so
    -- one band stamped at another height prints a faint rectangle.
    --
    -- Fed by TWO GSC LuiNotifyEvents, both of which cost ZERO clientuimodel
    -- bits (the 61-bit budget is full): tod_floor (floor, bossFloor) and
    -- tod_down (downMaskLo, downMaskHi). Two events and not one 3-arg event
    -- because the 25-cell down mask is split to keep every transmitted number
    -- under 8192 — the reasoning is written out in _tod_gauge.gsc's header.
    -- At MENU ROOT so it is never alpha-gated by the upgrade panel.
    --
    -- Art grid (canvas 180x1440, v2): crown y0..290 (crown + neck), 25 cells
    -- y290..1340 at pitch 42 (cell f top = 290 + (25 - f) * 42, full canvas
    -- width), base cap y1340..1440. Floor 25 is the TOP cell. Everything
    -- below scales that grid by GA_S — LOCKSTEP with tools/slice_gauge.js,
    -- which cuts the tiles on exactly these lines.
    -- ======================================================================
    -- v19.76: every gauge element lives in ONE container so the King's boss bar
    -- can step the whole instrument aside with one alpha (KING BAR below). The
    -- container closes its own children (LUI close never cascades).
    local GaugeRoot = nil
    if USE_CARD_SET_ART then
        GaugeRoot = LUI.UIElement.new()
        CoD.TodUIOwnership.Attach( GaugeRoot )
        GaugeRoot:setLeftRight( true, true, 0, 0 )
        GaugeRoot:setTopBottom( true, true, 0, 0 )
        Hud:addElement( GaugeRoot )
        local GA_X, GA_Y = 1216, 150          -- top-left on the 1280x720 canvas
        local GA_W, GA_H = 52, 416            -- 180x1440 at true aspect (1:8)
        local GA_S = GA_H / 1440              -- art px -> screen px
        local GA_CELLS = 25
        local GA_PITCH = 42                   -- one cell band, art px
        local GA_CELL0 = 290                  -- top of cell 25 = bottom of the crown crop
        local GA_BASE = GA_CELL0 + GA_CELLS * GA_PITCH   -- 1340, top of the base cap

        -- THE ENDLESS SPIRE SET (v16.43, docs/71): the same slot, a SECOND
        -- grid on the same 180x1440 canvas — 35 cells at pitch 30 since
        -- v17.69 (docs/105: the spire is 70 floors; 50 cells at pitch 21 for
        -- the 100-floor spire before that), two floors per cell like the
        -- tower, a hub plate every 5th, the summit in the top band. Driven by
        -- gaMode (tod_gauge_mode: 0 tower, 1 spire, 2 spire + summit won),
        -- which the server sends BEFORE the floor that follows it. LOCKSTEP
        -- with the --spire profile in tools/slice_gauge.js and
        -- TOD_GAUGE_SPIRE_CELLS in _tod_gauge.gsc.
        local SP_CELLS = 35
        local SP_PITCH = 30
        local SP_CELL0 = 290
        local SP_BASE = SP_CELL0 + SP_CELLS * SP_PITCH   -- 1340

        -- art-space -> screen-space helpers
        local function ax( v ) return GA_X + v * GA_S end
        local function ay( v ) return GA_Y + v * GA_S end
        -- top edge of a floor's cell, floor 1 at the BOTTOM
        local function cellTop( f ) return GA_CELL0 + ( GA_CELLS - f ) * GA_PITCH end
        local function cellTopSp( f ) return SP_CELL0 + ( SP_CELLS - f ) * SP_PITCH end
        -- "c07" / "d19": the tile names are the cell number, two digits
        local function cellImg( set, prefix, f )
            return RegisterImage( set .. prefix .. ( ( f < 10 ) and ( "0" .. f ) or tostring( f ) ) )
        end

        local darkTowerImg = RegisterImage( "i_tod_gauge_dark" )
        local darkSpireImg = RegisterImage( "i_tod_spire_dark" )
        local GaugeDark = LUI.UIImage.new()
        GaugeDark:setLeftRight( true, false, GA_X, GA_X + GA_W )
        GaugeDark:setTopBottom( true, false, GA_Y, GA_Y + GA_H )
        GaugeDark:setImage( darkTowerImg )
        GaugeRoot:addElement( GaugeDark )

        -- lit roof crown (hidden until the player is actually on the roof);
        -- the crop includes the neck (270..290), which is identical in both
        -- masters, so the stamp can never seam against the bar's shoulder
        local GaugeCrown = LUI.UIImage.new()
        GaugeCrown:setLeftRight( true, false, GA_X, GA_X + GA_W )
        GaugeCrown:setTopBottom( true, false, ay( 0 ), ay( GA_CELL0 ) )
        GaugeCrown:setImage( RegisterImage( "i_tod_gauge_crown" ) )
        GaugeCrown:setAlpha( 0 )
        GaugeRoot:addElement( GaugeCrown )

        -- lit base cap (its cyan ring): on from the first climbed cell, so
        -- the trail starts at the ground floor; off again when the finale
        -- clock empties the bar
        local GaugeBase = LUI.UIImage.new()
        GaugeBase:setLeftRight( true, false, GA_X, GA_X + GA_W )
        GaugeBase:setTopBottom( true, false, ay( GA_BASE ), GA_Y + GA_H )
        GaugeBase:setImage( RegisterImage( "i_tod_gauge_base" ) )
        GaugeBase:setAlpha( 0 )
        GaugeRoot:addElement( GaugeBase )

        -- the spire's top and base tiles (hidden until mode 1); the summit
        -- swaps to its green-beacon twin in mode 2
        local summitImg = RegisterImage( "i_tod_spire_summit" )
        local summitWonImg = RegisterImage( "i_tod_spire_summit_won" )
        local GaugeSummit = LUI.UIImage.new()
        GaugeSummit:setLeftRight( true, false, GA_X, GA_X + GA_W )
        GaugeSummit:setTopBottom( true, false, ay( 0 ), ay( SP_CELL0 ) )
        GaugeSummit:setImage( summitImg )
        GaugeSummit:setAlpha( 0 )
        GaugeRoot:addElement( GaugeSummit )

        local GaugeBaseSp = LUI.UIImage.new()
        GaugeBaseSp:setLeftRight( true, false, GA_X, GA_X + GA_W )
        GaugeBaseSp:setTopBottom( true, false, ay( SP_BASE ), GA_Y + GA_H )
        GaugeBaseSp:setImage( RegisterImage( "i_tod_spire_base" ) )
        GaugeBaseSp:setAlpha( 0 )
        GaugeRoot:addElement( GaugeBaseSp )

        -- one lit cell per floor, pre-built and toggled by alpha (no
        -- create/destroy churn on a widget that updates every few seconds)
        local GaugeCells = {}
        for f = 1, GA_CELLS do
            local c = LUI.UIImage.new()
            c:setLeftRight( true, false, ax( 0 ), ax( 180 ) )
            c:setTopBottom( true, false, ay( cellTop( f ) ), ay( cellTop( f ) + GA_PITCH ) )
            c:setImage( cellImg( "i_tod_gauge_", "c", f ) )
            c:setAlpha( 0 )
            GaugeRoot:addElement( c )
            GaugeCells[ f ] = c
        end
        -- ... and the spire's thirty-five, same pattern
        local GaugeCellsSp = {}
        for f = 1, SP_CELLS do
            local c = LUI.UIImage.new()
            c:setLeftRight( true, false, ax( 0 ), ax( 180 ) )
            c:setTopBottom( true, false, ay( cellTopSp( f ) ), ay( cellTopSp( f ) + SP_PITCH ) )
            c:setImage( cellImg( "i_tod_spire_", "c", f ) )
            c:setAlpha( 0 )
            GaugeRoot:addElement( c )
            GaugeCellsSp[ f ] = c
        end

        -- PLAYER MARKER REMOVED (user 2026-08-21: "remove that focus state").
        -- The top of the lit trail already reads as your altitude.

        -- boss pip: the red skull tab (i_tod_gauge_boss, 72x42 art = exactly
        -- one band tall) on the boss's cell, just left of the bar's plate.
        -- Its tip is at the art's right edge; the plate's own left edge is
        -- at art x18 (GA_X + 5), so the tip sits on the plate's glow.
        -- (v1 drew an image-less red rectangle here and tinted it with
        -- setRGB — an image tints too, and red over a white skull would
        -- erase it, so no setRGB now.)
        local GA_PIP_W, GA_PIP_H = 72, 42
        -- v19.46: a POOL of pips, one per distinct cell that holds a live
        -- Panzer (GSC tod_pips packs up to four cells, two per int, highest
        -- first). GA_PIPS is LOCKSTEP with TOD_GAUGE_PIPS_MAX in _tod_gauge.gsc.
        local GA_PIPS = 4
        local GaugePips = {}
        for i = 1, GA_PIPS do
            local pip = LUI.UIImage.new()
            pip:setLeftRight( true, false, ax( 18 ) - GA_PIP_W * GA_S, ax( 18 ) )
            pip:setTopBottom( true, false, ay( cellTop( 1 ) ), ay( cellTop( 1 ) + GA_PIP_H ) )
            pip:setImage( RegisterImage( "i_tod_gauge_boss" ) )
            pip:setAlpha( 0 )
            GaugeRoot:addElement( pip )
            GaugePips[ i ] = pip
        end
        -- (gaHidePips / gaPlacePip live below, AFTER gaMode is declared: a
        -- closure written above that `local` would bind a nil global.)

        -- ------------------------------------------------------------------
        -- DOWNED-TEAMMATE CELLS (v14.50) — the red sections.
        --
        -- ONE ELEMENT PER CELL, ALL 25 PRE-BUILT, exactly like GaugeCells
        -- above, and for the reason the user asked for directly: "there is
        -- always a possibility that multiple players are down at different
        -- areas ... I dont want the system to break cause it doesnt expect
        -- 2,3 players down at once". Nothing in this widget tracks "the"
        -- down cell or counts bodies — the server sends a 25-bit mask and
        -- this loop sets 25 alphas from it, so zero, one, two or three reds
        -- are the same code with the same cost. Two players down on ONE cell
        -- is one bit and draws one red tile.
        --
        -- Added AFTER the cells so it sits on top of them in draw order, but
        -- the handler also blanks the lit cell underneath, so a red section is
        -- a clean SWAP rather than an overlay. v2: each cell's down tile is
        -- its own band of the DOWN master (i_tod_gauge_d01..d25) — the red
        -- plate with a WHITE cross, so it cannot be mistaken for a lit cell
        -- of the RED district (21-25), and on the lounge cells it covers the
        -- wider plate, because it IS that cell's band.
        -- ------------------------------------------------------------------
        local GaugeDown = {}
        for f = 1, GA_CELLS do
            local c = LUI.UIImage.new()
            c:setLeftRight( true, false, ax( 0 ), ax( 180 ) )
            c:setTopBottom( true, false, ay( cellTop( f ) ), ay( cellTop( f ) + GA_PITCH ) )
            c:setImage( cellImg( "i_tod_gauge_", "d", f ) )
            c:setAlpha( 0 )
            GaugeRoot:addElement( c )
            GaugeDown[ f ] = c
        end
        -- the spire's down tiles are WHITE with a red cross (its lit cells are
        -- red), one per cell like everything else
        local GaugeDownSp = {}
        for f = 1, SP_CELLS do
            local c = LUI.UIImage.new()
            c:setLeftRight( true, false, ax( 0 ), ax( 180 ) )
            c:setTopBottom( true, false, ay( cellTopSp( f ) ), ay( cellTopSp( f ) + SP_PITCH ) )
            c:setImage( cellImg( "i_tod_spire_", "d", f ) )
            c:setAlpha( 0 )
            GaugeRoot:addElement( c )
            GaugeDownSp[ f ] = c
        end

        -- Powers of two, as a table so the decode below is a lookup and not 25
        -- calls to `^`. This Lua has no bit library, so masks are unpacked
        -- arithmetically — the same idiom the pause menu's TENS/flag unpack
        -- already uses (math.floor( v / 4 ) % 2).
        --
        -- GA_SPLIT is LOCKSTEP with TOD_GAUGE_MASK_SPLIT in _tod_gauge.gsc:
        -- cells 1..13 arrive in the low arg, 14..25 in the high one. Change one
        -- and you MUST change the other — a mismatch does not error, it just
        -- puts red cells in the wrong places.
        local GA_SPLIT = 13
        local GA_BIT = {}
        do
            local v = 1
            for i = 1, GA_CELLS do
                GA_BIT[ i ] = v
                v = v * 2
            end
        end

        -- The two feeds arrive on separate events and must both be able to
        -- repaint the cells, so the last value of each is held here and one
        -- function applies them together. Defaults are the pre-feature look:
        -- nothing climbed, nobody down.
        -- gaDown holds FOUR 13-bit chunks: [1],[2] from tod_down (cells
        -- 1..26) and [3],[4] from tod_down2 (cells 27..52) — the same
        -- chunk/bit arithmetic as _tod_gauge::down_mask_for.
        local gaClimbed, gaMode = 0, 0
        local gaDown = { 0, 0, 0, 0 }

        local function gaCells() return ( gaMode > 0 ) and SP_CELLS or GA_CELLS end

        local function gaApplyCells()
            local cells = gaCells()
            local lit = ( gaMode > 0 ) and GaugeCellsSp or GaugeCells
            local dn = ( gaMode > 0 ) and GaugeDownSp or GaugeDown
            for i = 1, cells do
                -- A DOWNED TEAMMATE OUTRANKS THE CLIMB TRAIL on that cell: it
                -- swaps to the down tile rather than stacking on top, so a
                -- down section always reads as one solid tile. Every cell is
                -- tested on every update, and that is exactly what makes 2 or
                -- 3 simultaneous downs — and a revive that clears only one of
                -- them — fall out for free: there is no "the" down cell
                -- anywhere in here, and no count of bodies to get wrong.
                local chunk = math.floor( ( i - 1 ) / GA_SPLIT )
                local bit = ( i - 1 ) - chunk * GA_SPLIT
                local isDown = ( math.floor( gaDown[ chunk + 1 ] / GA_BIT[ bit + 1 ] ) % 2 ) >= 1
                dn[ i ]:setAlpha( isDown and 1 or 0 )
                lit[ i ]:setAlpha( ( i <= gaClimbed and not isDown ) and 1 or 0 )
            end
            -- the ground floor lights with the first cell
            if gaMode > 0 then
                GaugeBaseSp:setAlpha( ( gaClimbed >= 1 ) and 1 or 0 )
            else
                GaugeBase:setAlpha( ( gaClimbed >= 1 ) and 1 or 0 )
            end
        end

        -- THE INSTRUMENT SWAP. Leaving a set blanks every element of it, the
        -- backing swaps, and the climb/down state resets — the server drops
        -- its caches on the same tick and re-pushes both lanes right after
        -- the mode, so the new set is painted within the same 0.35 s.
        -- THE PANZER PIPS (v19.46). Declared here, below gaMode / gaCells.
        local function gaHidePips()
            for i = 1, GA_PIPS do GaugePips[ i ]:setAlpha( 0 ) end
        end
        -- Place pip i on cell c (1..cells) of the showing instrument, or hide it.
        local function gaPlacePip( i, c, cells )
            local pip = GaugePips[ i ]
            if c >= 1 and c <= cells then
                if gaMode > 0 then
                    -- the pip is one TOWER band tall (42); centre it on the
                    -- spire's 30-px cell
                    local cy = cellTopSp( c ) + SP_PITCH / 2
                    pip:setTopBottom( true, false, ay( cy - GA_PIP_H / 2 ), ay( cy + GA_PIP_H / 2 ) )
                else
                    pip:setTopBottom( true, false, ay( cellTop( c ) ), ay( cellTop( c ) + GA_PIP_H ) )
                end
                pip:setAlpha( 1 )
            else
                pip:setAlpha( 0 )
            end
        end
        -- The last tod_pips payload, re-applied after a mode swap moves the cells.
        local gaPips = { 0, 0, 0, 0 }
        local function gaApplyPips()
            local cells = gaCells()
            for i = 1, GA_PIPS do gaPlacePip( i, gaPips[ i ], cells ) end
        end

        local function gaSetMode( m )
            local toSpire = ( m > 0 )
            if ( gaMode > 0 ) ~= toSpire then
                local offLit = toSpire and GaugeCells or GaugeCellsSp
                local offDn = toSpire and GaugeDown or GaugeDownSp
                for i = 1, #offLit do offLit[ i ]:setAlpha( 0 ) end
                for i = 1, #offDn do offDn[ i ]:setAlpha( 0 ) end
                GaugeBase:setAlpha( 0 )
                GaugeBaseSp:setAlpha( 0 )
                GaugeCrown:setAlpha( 0 )
                GaugeSummit:setAlpha( 0 )
                gaHidePips()
                GaugeDark:setImage( toSpire and darkSpireImg or darkTowerImg )
                gaClimbed = 0
                gaDown = { 0, 0, 0, 0 }
                gaPips = { 0, 0, 0, 0 }
            end
            gaMode = m
            -- v19.38: the pause PERK SLOTS row (DETAIL[40]) reads this. The
            -- gauge mode is the one spire flag the client already receives.
            CoD.TodSpireMode = toSpire
            GaugeSummit:setImage( ( m >= 2 ) and summitWonImg or summitImg )
            gaApplyCells()
        end

        GaugeDark:subscribeToGlobalModel( Instance, "PerController", "scriptNotify", function ( model )
            local ev = Engine.GetModelValue( model )
            if ev ~= "tod_floor" and ev ~= "tod_down" and ev ~= "tod_down2" and ev ~= "tod_gauge_mode" and ev ~= "tod_pips" then
                return
            end
            local d = CoD.GetScriptNotifyData( model )
            if not d then
                return
            end

            if ev == "tod_gauge_mode" then
                gaSetMode( ( type( d[ 1 ] ) == "number" ) and d[ 1 ] or 0 )
                return
            end

            if ev == "tod_down" or ev == "tod_down2" then
                local k = ( ev == "tod_down" ) and 1 or 3
                gaDown[ k ] = ( type( d[ 1 ] ) == "number" ) and d[ 1 ] or 0
                gaDown[ k + 1 ] = ( type( d[ 2 ] ) == "number" ) and d[ 2 ] or 0
                gaApplyCells()
                return
            end

            if ev == "tod_pips" then
                -- v19.46: two ints, two cells each (hi*64 + lo), highest first,
                -- LOCKSTEP with pack_pips in _tod_gauge.gsc. 0 = no pip.
                local a = ( type( d[ 1 ] ) == "number" ) and d[ 1 ] or 0
                local b = ( type( d[ 2 ] ) == "number" ) and d[ 2 ] or 0
                gaPips[ 1 ] = math.floor( a / 64 )
                gaPips[ 2 ] = a % 64
                gaPips[ 3 ] = math.floor( b / 64 )
                gaPips[ 4 ] = b % 64
                gaApplyPips()
                return
            end

            local f = ( type( d[ 1 ] ) == "number" ) and d[ 1 ] or 0
            local cells = gaCells()

            -- cells + 1 (the roof / the summit) counts as "all floors climbed"
            -- and lights the top tile of whichever instrument is showing
            local atTop = ( f > cells )
            gaClimbed = atTop and cells or f
            gaApplyCells()
            if gaMode > 0 then
                GaugeSummit:setAlpha( atTop and 1 or 0 )
            else
                GaugeCrown:setAlpha( atTop and 1 or 0 )
            end
            -- (tod_floor's second arg — the highest Panzer's cell — is no
            -- longer drawn here: the pips come from tod_pips, v19.46.)
        end )
    end

    -- ======================================================================
    -- THE KING BAR (v19.76) - the Warden King's health across the top of the
    -- screen, and the floor gauge + luck bar step aside while he lives (lead
    -- tester Nikolai, Oct 2026: "the lack of HUD feedback on damage for boss
    -- leaves players completely in the dark ... a dedicated Boss HP bar across
    -- the top of the screen ... the Luck Bar ... and the Floor Progression
    -- Counter should both be hidden"). Fed by _tod_spire::king_hp_bar on
    -- "tod_king_bar" ( state, permille ): state 1 = the fight is on, 0 = over.
    -- On every change plus a 1 s heartbeat, so a HUD rebuilt by a respawn has it
    -- back inside a second. The art is tools/boss_bar/build_boss_bar.py (the
    -- King banner's own look). LOCKSTEP: KB_* == that script's layout, and its
    -- --check gates every build. The fill is the mana bar's recipe - the image
    -- on uie_wipe_normal, shader vector 0's x = the fraction. A pale TRAIL under
    -- it holds where a hit took him from and closes 40% of the gap per push (no
    -- timer, no animation): a big hit reads as a chunk falling away.
    -- ======================================================================
    local KB_X, KB_Y, KB_W, KB_H = 384, 8, 512, 64
    local KB_FX1, KB_FY1, KB_FX2, KB_FY2 = 447.5, 41, 884.5, 60
    local KingBar = LUI.UIElement.new()
    CoD.TodUIOwnership.Attach( KingBar )
    KingBar:setLeftRight( true, true, 0, 0 )
    KingBar:setTopBottom( true, true, 0, 0 )
    KingBar:setAlpha( 0 )
    Hud:addElement( KingBar )

    local KingPlate = LUI.UIImage.new()
    KingPlate:setLeftRight( true, false, KB_X, KB_X + KB_W )
    KingPlate:setTopBottom( true, false, KB_Y, KB_Y + KB_H )
    KingPlate:setImage( RegisterImage( "i_tod_boss_bar" ) )
    KingBar:addElement( KingPlate )

    local function kingWipe( r, g, b, a )
        local e = LUI.UIImage.new()
        e:setLeftRight( true, false, KB_FX1, KB_FX2 )
        e:setTopBottom( true, false, KB_FY1, KB_FY2 )
        e:setImage( RegisterImage( "i_tod_boss_bar_fill" ) )
        e:setRGB( r, g, b )
        e:setAlpha( a )
        e:setMaterial( LUI.UIImage.GetCachedMaterial( "uie_wipe_normal" ) )
        e:setShaderVector( 0, 1, 0, 0, 0 )
        e:setShaderVector( 1, 0, 0, 0, 0 )
        e:setShaderVector( 2, 1, 0, 0, 0 )
        e:setShaderVector( 3, 0, 0, 0, 0 )
        KingBar:addElement( e )
        return e
    end
    local KingTrail = kingWipe( 1, 0.93, 0.74, 0.55 )   -- under the fill: drawn first
    local KingFill  = kingWipe( 1, 1, 1, 1 )

    local kingOn, kingTrailFrac = false, 1
    local function kingShow( on )
        if on == kingOn then return end
        kingOn = on
        KingBar:setAlpha( on and 1 or 0 )
        LuckBar:setAlpha( on and 0 or 1 )
        if GaugeRoot then GaugeRoot:setAlpha( on and 0 or 1 ) end
        if on then kingTrailFrac = 1 end
    end
    KingBar:subscribeToGlobalModel( Instance, "PerController", "scriptNotify", function ( model )
        if Engine.GetModelValue( model ) ~= "tod_king_bar" then return end
        local d = CoD.GetScriptNotifyData( model )
        if not d then return end
        local state = math.floor( tonumber( d[ 1 ] ) or 0 )
        local frac = ( tonumber( d[ 2 ] ) or 0 ) / 1000
        if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
        kingShow( state == 1 )
        if state ~= 1 then return end
        KingFill:setShaderVector( 0, frac, 0, 0, 0 )
        if kingTrailFrac < frac then
            kingTrailFrac = frac
        else
            kingTrailFrac = frac + ( kingTrailFrac - frac ) * 0.6
        end
        KingTrail:setShaderVector( 0, kingTrailFrac, 0, 0, 0 )
    end )

    -- [tod] OWNED-UPGRADES SYNC (pause-menu list): GSC's refresh_upgrade_list
    -- sends one int-only LuiNotifyEvent per owned domain (id, level, max) —
    -- map 1's kill-feed lane (scriptNotify PerController model +
    -- CoD.GetScriptNotifyData). Accumulated here because THIS menu is always
    -- open; AetheriumStartMenu.lua reads CoD.TodOwned on every pause open.
    CoD.TodOwned = CoD.TodOwned or {}
    LuckBar:subscribeToGlobalModel( Instance, "PerController", "scriptNotify", function ( model )
        if Engine.GetModelValue( model ) == "tod_upg_sync" then
            local d = CoD.GetScriptNotifyData( model )
            if d and type( d[ 1 ] ) == "number" and type( d[ 2 ] ) == "number" then
                -- [tod v14.13] the max arg CARRIES the survives-promotion bit:
                -- GSC sync_max() adds 100 when THIS player's copy of the domain
                -- survives a tier card (SCAVENGER is assault-only persistence
                -- now, so a static table cannot know — the server does). Strip
                -- it here; AetheriumStartMenu's reset badge reads .safe and
                -- falls back to its static tierSafe() only when .safe is nil.
                local m = ( type( d[ 3 ] ) == "number" and d[ 3 ] ) or 10
                -- DARK UPGRADES (v17.10): a SECOND packed bit, +200, and it MUST be
                -- stripped BEFORE the +100 survives bit. A dark row that also
                -- survives arrives as 10 + 100 + 200 = 310; testing >= 100 first
                -- would strip one hundred and leave 210, reporting a nonsense max
                -- and losing the dark flag entirely.
                local dark = false
                if m >= 200 then
                    dark = true
                    m = m - 200
                end
                local safe = nil
                if m >= 100 then
                    safe = true
                    m = m - 100
                else
                    safe = false
                end
                CoD.TodOwned[ d[ 1 ] ] = { lvl = d[ 2 ], max = m, safe = safe, dark = dark }
            end
        elseif Engine.GetModelValue( model ) == "tod_upg_class" then
            -- [tod v16] one int: this player's CLASS ID, 1..4, or 0 when they
            -- have not drafted yet. Pushed before EVERY deal alongside the tier
            -- hint, so the panel can read it while it paints and nothing has to
            -- clear it when the panel closes.
            local d = CoD.GetScriptNotifyData( model )
            CoD.TodClass = ( d and type( d[ 1 ] ) == "number" and d[ 1 ] ) or 0
        elseif Engine.GetModelValue( model ) == "tod_input_pad" then
            -- [tod v16.3] the server saw this player's d-pad (pad_latch): pad
            -- plates from now on, in this menu and the class draft. See
            -- UsingController() above. One int, always 1; never cleared.
            CoD.TodPad = true
        elseif Engine.GetModelValue( model ) == "tod_upg_tier_need" then
            -- [tod v14.35] one int: the floor this player must still REACH
            -- before a CLASS TIER card can be dealt, or 0 when the floor is not
            -- what is stopping them. GSC pushes it before EVERY deal (0
            -- included), so the panel can read it without anyone having to
            -- clear it when the panel closes.
            local d = CoD.GetScriptNotifyData( model )
            CoD.TodTierNeed = ( d and type( d[ 1 ] ) == "number" and d[ 1 ] ) or 0
        elseif Engine.GetModelValue( model ) == "tod_mage_aura" then
            -- [tod v18.39] one int: is this player standing in a MAGE HEALING
            -- AURA (1) or not (0). Read by CoD.TodAuraTint (AetheriumCharacters)
            -- when the health plate repaints. It is received HERE, in this
            -- menu's chain, because AetheriumPlayerInfo.lua cannot take an
            -- added statement -- see the helper's note.
            local a = CoD.GetScriptNotifyData( model )
            CoD.TodMageAura = ( a and type( a[ 1 ] ) == "number" and a[ 1 ] ) or 0
        end
    end )

    -- MAG +N chip — DELETED v17.9. It was dead AND in the way, which is why it
    -- goes rather than being left alone:
    --   DEAD: it read the todMagBonus model, whose only writer is
    --   _tod_upgrade_ui::set_mag_bonus, and that function has ZERO call sites.
    --   Nothing has pushed a value into it since it was written.
    --   IN THE WAY: setLeftRight(false,true,-330,-180) / setTopBottom(false,
    --   true,-52,-30) put it at canvas x950..1100, y668..690 — straight through
    --   the v17.9 gun panel's reserve row (x1000..1256, y604..678) — and this
    --   menu is the always-open additive overlay, so it draws ON TOP of the HUD.
    --   A dead element that cannot be seen is clutter; a dead element that
    --   overdraws a live readout is a bug waiting for someone to call the
    --   function. set_mag_bonus is left in the GSC as the documented entry point
    --   if the bottomless-mag pool ever needs a readout again — it would want a
    --   slot inside the gun panel now, not a chip floating over it.

    -- -----------------------------------------------------------------------
    -- HUD TOASTS + THE CO-OP "CHOOSING" LINE (v19.58, the typography pass; user
    -- 2026-09-27: "replace all the text on the screen ... some text say
    -- choosing: player1, player2 ... add the typography for the map").
    -- Both used to be SERVER text (IPrintLnBold / a hudelem SetText), which the
    -- engine always draws in its own font. The server now sends ints only:
    --   tod_toast    ( id, a, b )  -> a TOAST row, {A} / {B} filled from a / b
    --   tod_choosing ( mask )      -> bit n = client n still picking; 0 = hide
    -- LOCKSTEP: TOAST ids == _tod_toast.gsh. The words live HERE only.
    -- Both sit on this menu's root, so they hide under the scoreboard / pause
    -- menu with everything else (the todGateHud block above).
    -- -----------------------------------------------------------------------
    if CoD.TodGlyphText and CoD.TodGlyphText.new then
        local GOLD = { 1, 0.84, 0.35 }
        local PALE = { 0.92, 0.95, 1 }
        local TOAST = {
            [ 1 ] = { PALE, "CLASS TIER {A} UNLOCKS AT FLOOR {B}" },
            [ 2 ] = { PALE, "FLOOR {A} REACHED", "CLASS TIER {B} UNLOCKED" },
            [ 3 ] = { PALE, "FLOOR {A} REACHED - CLASS TIER {B} UNLOCKED", "PACK-A-PUNCH TO PROMOTE" },
            [ 4 ] = { GOLD, "NEW WEAPONS ARE NOT PACK-A-PUNCHED" },
            [ 5 ] = { GOLD, "PERK SLOTS FULL" },
            [ 6 ] = { PALE, "HOLD THE HALL" },
            [ 7 ] = { PALE, "THE TRIAL IS WON", "THE WAY IS OPEN" },
            [ 8 ] = { PALE, "MAGE - HEALING AURA BLINK AND ARCHMAGE", "UNLOCK WITH THEIR UPGRADE CARDS" },
            [ 9 ] = { GOLD, "NOTHING TO REFILL", "STAFFS AND BLADES NEVER RUN DRY" },
            [ 10 ] = { GOLD, "AMMO ALREADY FULL" },
            [ 11 ] = { GOLD, "THE TRIAL BELOW IS NOT WON", "WIN IT TO CLIMB" },   -- v19.76: _tod_spire::trial_bypass_return
        }
        -- PLACEMENT, MEASURED (v19.58) - the one clean centre band on this
        -- canvas: BELOW the crosshair (360) and the kill feed (x721.., rows
        -- 317..376, its running total at 317..328), ABOVE the prompt cards
        -- (ZMCursorHint chassis 444..520) and the powerup banner (503..). Above
        -- the crosshair is taken: the centre plates (trial / choice / arrival /
        -- win art, roughly 118..277 on screen) and IPrintLnBold's own band
        -- (CenterConsole 68.5..166.5). The CARD PANEL (226..577) and the class
        -- draft still cover this band, so a toast that arrives while either is
        -- up WAITS and shows the moment it closes (one thing at a time).
        local TOAST_L, TOAST_R = 240, 1040
        local TOAST_T1, TOAST_B1 = 396, 414
        local TOAST_T2, TOAST_B2 = 418, 434
        local TOAST_HOLD_MS, TOAST_FADE_MS = 3500, 700

        local Toast = LUI.UIElement.new()
        Toast:setLeftRight( true, true, 0, 0 )
        Toast:setTopBottom( true, true, 0, 0 )
        Toast:setAlpha( 0 )
        Hud:addElement( Toast )
        local toastA = CoD.TodGlyphText.new( { left = TOAST_L, right = TOAST_R, top = TOAST_T1, bottom = TOAST_B1, align = "center", grow = true } )
        local toastB = CoD.TodGlyphText.new( { left = TOAST_L, right = TOAST_R, top = TOAST_T2, bottom = TOAST_B2, align = "center", grow = true } )
        Toast:addElement( toastA )
        Toast:addElement( toastB )
        -- LUI close does not cascade: the container owns its two lines.
        LUI.OverrideFunction_CallOriginalSecond( Toast, "close", function ()
            toastA:close()
            toastB:close()
        end )

        local function toastFade( element, event )
            if event.interrupted then return end
            element:beginAnimation( "keyframe", TOAST_FADE_MS, false, false, CoD.TweenType.Linear )
            element:setAlpha( 0 )
        end
        local function fill( str, a, b )
            str = string.gsub( str, "{A}", tostring( a ) )
            return ( string.gsub( str, "{B}", tostring( b ) ) )
        end

        local ctrlModel = Engine.GetModelForController( Instance )
        local function panelUp()
            for _, name in ipairs( { "todUpgShow", "todClsShow" } ) do
                local m = Engine.GetModel( ctrlModel, name )
                local v = m and tonumber( Engine.GetModelValue( m ) ) or 0
                if v > 0 then return true end
            end
            return false
        end
        local pending = nil   -- the newest toast that arrived under a panel
        local function showToast( row, a, b )
            toastA:setText( fill( row[ 2 ], a, b ) )
            toastB:setText( row[ 3 ] and fill( row[ 3 ], a, b ) or "" )
            toastA:setRGB( row[ 1 ][ 1 ], row[ 1 ][ 2 ], row[ 1 ][ 3 ] )
            toastB:setRGB( row[ 1 ][ 1 ], row[ 1 ][ 2 ], row[ 1 ][ 3 ] )
            Toast:completeAnimation()
            Toast:setAlpha( 1 )
            Toast:beginAnimation( "keyframe", TOAST_HOLD_MS, false, false, CoD.TweenType.Linear )
            Toast:setAlpha( 1 )
            Toast:registerEventHandler( "transition_complete_keyframe", toastFade )
        end

        Hud:subscribeToGlobalModel( Instance, "PerController", "scriptNotify", function ( model )
            local ev = Engine.GetModelValue( model )
            if ev == "tod_game_time" then
                -- v19.59b: cache for the pause menu's GAME TIME (_tod_upgrade_ui::game_time_push)
                local g = CoD.GetScriptNotifyData( model )
                if g then
                    CoD.TodGameSecs = CoD.TodGameSecs or {}
                    CoD.TodGameSecs[ Instance ] = math.floor( tonumber( g[ 1 ] ) or 0 )
                end
                return
            end
            if ev ~= "tod_toast" then return end
            local d = CoD.GetScriptNotifyData( model )
            if not d then return end
            local row = TOAST[ math.floor( tonumber( d[ 1 ] ) or 0 ) ]
            if not row then return end
            local a = math.floor( tonumber( d[ 2 ] ) or 0 )
            local b = math.floor( tonumber( d[ 3 ] ) or 0 )
            if panelUp() then
                pending = { row = row, a = a, b = b }
                return
            end
            showToast( row, a, b )
        end )
        -- A panel closing releases the toast it held back.
        for _, name in ipairs( { "todUpgShow", "todClsShow" } ) do
            local m = Engine.CreateModel( ctrlModel, name )
            if m then
                Hud:subscribeToModel( m, function ()
                    if pending and not panelUp() then
                        local t = pending
                        pending = nil
                        showToast( t.row, t.a, t.b )
                    end
                end )
            end
        end

        -- CHOOSING: above the UPGRADE AVAILABLE banner (122..215), as the old
        -- server line was (y74). Names come from the same PlayerList models the
        -- scoreboard reads; a slot whose name has no drawable character shows
        -- as "PLAYER n" rather than vanishing from the list.
        -- x 340..940: clear of the luck bar (24..328, y56..94) beside it and of
        -- the ROUND readout on the right; a four-name line shrinks to fit this
        -- box rather than running into either. y 74..92 is already ~35 units
        -- higher than the old server line (hudelem TOP 74 = canvas ~111..131,
        -- which touched the UPGRADE AVAILABLE banner's top at 122).
        local Choosing = CoD.TodGlyphText.new( { left = 340, right = 940, top = 72, bottom = 90, align = "center", grow = true, rgb = GOLD } )
        Choosing:setAlpha( 0 )
        Hud:addElement( Choosing )
        local function nameFor( cn )
            local root = Engine.GetModelForController( Instance )
            for i = 0, 3 do
                local cm = Engine.GetModel( root, "PlayerList." .. i .. ".clientNum" )
                if cm and Engine.GetModelValue( cm ) == cn then
                    local nm = Engine.GetModel( root, "PlayerList." .. i .. ".playerName" )
                    local v = nm and Engine.GetModelValue( nm )
                    if v and CoD.TodGlyphText.Sanitize( v ) ~= "" and string.find( string.upper( tostring( v ) ), "[A-Z0-9]" ) then
                        return tostring( v )
                    end
                end
            end
            return "PLAYER " .. ( cn + 1 )
        end
        Hud:subscribeToGlobalModel( Instance, "PerController", "scriptNotify", function ( model )
            local ev = Engine.GetModelValue( model )
            if ev ~= "tod_choosing" then return end
            local d = CoD.GetScriptNotifyData( model )
            local mask = d and math.floor( tonumber( d[ 1 ] ) or 0 ) or 0
            if mask <= 0 then
                Choosing:setAlpha( 0 )
                return
            end
            local s, first = "CHOOSING - ", true
            for cn = 0, 3 do
                if math.floor( mask / ( 2 ^ cn ) ) % 2 == 1 then
                    -- " - " between names: the copy net collapses runs of
                    -- spaces, and the typeface has no comma
                    s = s .. ( first and "" or " - " ) .. nameFor( cn )
                    first = false
                end
            end
            Choosing:setText( s )
            Choosing:setAlpha( 1 )
        end )
    end

    return Hud
end
