require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodUIOwnership" )
-- =============================================================================
-- tod_class_select.lua — the game-start class draft panel (CLASS_N cards).
--
-- Same doctrine as tod_upgrade.lua: additive overlay opened per-player from
-- GSC (OpenLUIMenu "tod_class_select"), a DUMB renderer fed by all-INT
-- clientuimodel fields (registered in _tod_upgrade_ui.gsc/.csc lockstep).
-- BUDGET NOTE (the clientuimodel overflow aborts map load — 2026-08-19):
-- only todClsShow is class-specific; focus/time/hold RIDE the upgrade
-- panel's fields (the two panels are never live together):
--   todClsShow  0 hidden | 1 choosing | 2 locked (confirm flash)
--   todUpgFocus focused class 1-CLASS_N (steady bright; at show==2 = the PICK)
--   todUpgTime  QUARTERED seconds until random auto-pick (display x4, red <= 2)
--   todUpgHold  hold-to-lock progress 0..15 (the fill bar)
-- Class ids MUST mirror _tod_class_select.gsc::class_key:
--   1 SKIRMISHER / 2 ASSAULT / 3 HEAVY / 4 SLASHER / 5 MAGE (docs/114,
--   gated OFF -- MAGE_ENABLED below and TOD_MAGE_ENABLED in _tod_mage.gsh)
--
-- ART DROP-IN (LIVE 2026-08-20, art8 sheet): class icon slots use
-- i_tod_class_skirmisher / i_tod_class_assault / i_tod_class_heavy /
-- i_tod_class_slasher (+ image,i_tod_class_* zone lines). Never flip the
-- flag before the assets are zoned.
-- =============================================================================

-- [tod v17.24] the ONE writer for a bind name inside the pale keycap — the fit
-- rule, the multi-bind trim and the cap's measured face geometry all live there,
-- shared with tod_upgrade.lua and the pause legend. See its header.
--
-- [tod v17.30] AND IT IS FAIL-SAFED, because a bare `require` is a way to lose
-- this whole menu. A require that throws — the rawfile missing from the .ff, a
-- Lua error inside the widget, or inside TodGlyphRow beneath it — aborts THIS
-- ENTIRE FILE, and a LUI failure is SILENT (no build complaint, no crash, just
-- nothing on screen). The class draft would never appear and every player would
-- be handed a random class on the 30 s timeout, with no way to tell why.
--
-- So: pcall the require, and route every call site through TodKeycapMake, which
-- degrades to the plain LUI text this menu already builds. THE STUB IS
-- DELIBERATELY LOCAL AND TWINNED across the three menus that use the widget — a
-- fail-safe that lives inside the thing it guards against is not a fail-safe,
-- and that is the one case where a twin beats a shared file.
pcall( require, "ui.uieditor.widgets.HUD.AetheriumWidgets.TodKeycap" )
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
    glass = { 0, 0.035, 0.085 },
    line  = { 0.2, 0.75, 1.0 },
    text  = { 0.86, 0.9, 0.95 },
    dim   = { 0.55, 0.62, 0.7 },
    pick  = { 0.2, 0.95, 0.85 },
}

-- id -> presentation. accent = the class's neon identity color.
local CLASSES = {
    -- CLASS TIERS (2026-08-22): the tier-1 guns changed — MSMC / Enfield open
    -- the run; desc2 now names each class's three-gun ladder. (Baked class
    -- card art carries the real text; this is the no-art fallback.)
    [1] = { name = "SKIRMISHER", gun = "MSMC SMG",      role = "RUN AND GUN",
            desc1 = "fastest fire rate + speed",   desc2 = "MSMC > MP5 > MP7",
            accent = { 0.20, 0.85, 1.00 } },
    [2] = { name = "ASSAULT",    gun = "ENFIELD RIFLE",   role = "PRECISION",
            desc1 = "headshots + recoil control",  desc2 = "ENFIELD > KRIG 6 > AK-47",
            accent = { 1.00, 0.75, 0.25 } },
    [3] = { name = "HEAVY",      gun = "MK 48 LMG",   role = "SUSTAINED FIRE",
            desc1 = "bullet feed + suppression",   desc2 = "MK 48 > HK21 > DEATH MACHINE",
            accent = { 1.00, 0.35, 0.30 } },
    [4] = { name = "SLASHER",    gun = "BASEBALL BAT",    role = "UP CLOSE",
            desc1 = "cleave + life leech",         desc2 = "KNIFE > KATANA > STORMBREAKER",
            accent = { 0.75, 0.45, 1.00 } },
    -- [tod docs/114] THE MAGE. TEXT ONLY, and no i_tod_card_class_mage or
    -- i_tod_class_mage registration ANYWHERE in this file until that art is
    -- baked and zoned: tools/lint_tod_assets.js GATE A scans every Lua for
    -- literal "i_tod_*" strings (comment-stripped, flag-blind) and HARD FAILS
    -- on any with no `image,` line. Until then card 5 falls back to the
    -- composite text stack, which is what this row feeds.
    [5] = { name = "MAGE",       gun = "THREE STAFFS",    role = "SPELLCASTER",
            desc1 = "lethal = aura, aim = archmage", desc2 = "LIGHTNING > +FIRE > +ICE",
            accent = { 0.35, 1.00, 0.80 } },
}

local USE_CLASS_ICON_ART = true   -- ON 2026-08-20: i_tod_class_* installed + zoned (art8 sheet)
-- FULL-CARD CLASS ART (files (10).zip 2026-08-20): 4 baked portrait cards
-- (i_tod_card_class_*) replace the composite; LUI keeps bind/hold/focus.
local USE_CLASS_CARD_ART = true
if USE_CLASS_CARD_ART then
    USE_CLASS_ICON_ART = false
end
-- [tod v16.32, KBM audit — docs/69 §6] the hint plates draw the LIVE binds:
-- blank frame (i_tod_hint_frame) + engine-expanded [{+bind}] tokens. Twin of
-- the flag in tod_upgrade.lua; full note there.
local USE_HINT_FRAME_ART = true
-- [tod v16.88] BAKED BUTTON GLYPHS — twin of the flag in tod_upgrade.lua,
-- where the whole argument and the device caveat live. The draft is the FIRST
-- menu of the match, so it is where a player forms their idea of how this map
-- is driven; leaving it on text while the deal panel showed glyphs would have
-- been the worse half to skip.
local USE_CARD_GLYPH_ART = true
-- [v17.27] the v17.4 keycap text scale is GONE, here and in tod_upgrade.lua:
-- keycap text is no longer LUI text, it is the map's baked typeface sized by
-- CoD.TodKeycap. Retired whole rather than left as an unread constant.
-- [tod 2026-09-07, docs/114] THE MAGE GATE, Lua half. Lua cannot read a GSC
-- #define, so this MIRRORS TOD_MAGE_ENABLED in
-- scripts/zm/zm_tower_of_doom/_tod_mage.gsh, and tools/build_map.ps1 asserts
-- the two agree (with TOD_CLS_COUNT) on every build. Flip all three or none:
-- true here with 0 there draws a fifth card the server will never accept;
-- false here with 1 there makes the fifth class silently unpickable.
local MAGE_ENABLED = true
local CLASS_N = MAGE_ENABLED and 5 or 4
-- Draft slots mirror _tod_class_select::class_key; stable class IDs stay intact.
local DISPLAY_CLASSES = MAGE_ENABLED and { 1, 2, 5, 3, 4 } or { 1, 2, 3, 4 }
local DEFAULT_FOCUS = MAGE_ENABLED and 3 or 1

-- Portrait card rect, DERIVED so the row re-centres when CLASS_N moves.
-- AT CLASS_N 4 THIS REPRODUCES THE OLD LITERALS EXACTLY: CARD_W 210,
-- CARD_PITCH 298, ROW_W 3*298+210 = 1104, CARD_X0 (1280-1104)/2 = 88,
-- CCARD_Y1 210 + floor(210*1.5) = 525. Not a pixel moves today.
-- The 5-card pair (186/244) is HAND-PICKED, not a formula -- a sixth class
-- would need another pair. The 2:3 portrait aspect is preserved because the
-- baked class cards are cut to it and a stretched card is worse than a small
-- one. Only xLo/xHi and the icon inset are re-derived below; every other inset
-- rides xLo/xHi, so nothing breaks, but at 186 wide they eat proportionally
-- more of the plate -- eyeball the panel the first time CLASS_N is 5.
local CARD_W     = ( CLASS_N >= 5 ) and 186 or 210
local CARD_PITCH = ( CLASS_N >= 5 ) and 244 or 298
local ROW_W      = ( CLASS_N - 1 ) * CARD_PITCH + CARD_W
local CARD_X0    = math.floor( ( 1280 - ROW_W ) / 2 )
local CCARD_Y0   = 210
local CCARD_Y1   = CCARD_Y0 + math.floor( CARD_W * 1.5 )

-- ---------------------------------------------------------------------------
-- [tod v18.32] THE HOLD PLATE, MEASURED OFF ITS OWN PIXELS.
--
-- `i_tod_hold_plate` is 460x70 and carries "HOLD" and "TO LOCK" as BAKED
-- lettering with a deliberate empty gap between them for the button. Decoding
-- the PNG: bright ink runs x96..401, the gap is x169..286 (118 wide, centred at
-- 227.5 — two and a half pixels LEFT of the plate's own centre), and the
-- lettering band is y25..42. `i_tod_hint_frame` and `i_tod_hint_locked` are the
-- same 460x70 sheet size.
--
-- WHY FRACTIONS. Two bugs in the 2026-09-08 screenshots came from typing pixel
-- literals for a plate whose drawn size had moved underneath them:
--
--   * THE PLATE WAS STRETCHED. It is drawn at xLo+5..xHi-5, which was 200 wide
--     when a class card was 210. The mage made the card 186, the plate 176 —
--     and the height stayed 34, so 176/34 = 5.18 against the art's 6.571. Every
--     plate on this menu was ~27% too tall. THE RULE IS width = height *
--     PLATE_ASPECT, and it must be derived, never re-typed. (tod_upgrade.lua
--     learned this in v16.4 and wrote the rule down; this menu never got it.)
--
--   * THE GLYPH DID NOT FIT THE GAP. The keycap was a literal 60 px wide. At a
--     176-wide plate the gap is 176 * 0.2565 = 45 px, so the cap overhung the
--     baked "HOLD" and "TO LOCK" by ~7 px each side — which is exactly what the
--     screenshot shows, on the pad glyph and the keyboard cap alike.
--
-- Both are now arithmetic off these four numbers. Re-measure only if the plate
-- art is re-baked.
-- ---------------------------------------------------------------------------
local PLATE_ASPECT = 460 / 70      -- 6.571. A plate drawn off this is stretched.
local PLATE_GAP_CX = 227.5 / 460   -- 0.4946 — the GAP's centre, not the plate's
local PLATE_GAP_W  = 118 / 460     -- 0.2565 — the widest a glyph may be drawn
local PLATE_INK_CY = 33.5 / 70     -- 0.4786 — the lettering's optical centre
local PLATE_H      = 34            -- the band this menu gives the plate
local PLATE_W      = math.floor( PLATE_H * PLATE_ASPECT )   -- 223

local TIME_DANGER = 2   -- in QUARTER-seconds (todUpgTime is quartered) = last 8s red

-- Per-input wording. [tod v16.3] Keyboard plates by default (PC-only mod), pad
-- plates once the server has seen this player's d-pad: CoD.TodPad is set by the
-- always-open tod_upgrade HUD menu's "tod_input_pad" receiver, and Render()
-- re-reads it on every model change (the d-pad press that latches also moves
-- focus, so the plate follows within a frame or two). The old
-- Engine.IsGamepadEnabled( 0 ) probe said "controller" for keyboard players
-- with a pad plugged in — see the twin note in tod_upgrade.lua.
-- [tod v17.55] the latch OR the bind expansion — twin of tod_upgrade.lua; the
-- argument lives in TodKeycap.lua (PadDevice). Kills the "LT / RT / A" keycap
-- set a pad player saw before their first d-pad press.
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
-- always going to miss it.
--
-- TodPadGlyph is the structural test — see CoD.TodKeycap.IsPadGlyph, which is
-- the canonical copy and carries the whole argument. Keep the two in step.
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
        -- [tod v18.16] ONE LANE, NOT FOUR. This line named D-PAD, STICK, LB
        -- and RB — four inputs for a one-button decision, and two of them are
        -- the very words the user asked to stop seeing. Stick, bumpers,
        -- triggers and melee ALL still switch cards; the map's standing rule
        -- is that a menu may accept eight inputs and must advertise one.
        return "SWITCH: D-PAD   LOCK: HOLD [ A ]"
    end
    -- v10.19: mouse + F joined (see tod_upgrade.lua)
    -- v10.20: proven lane only (see tod_upgrade.lua)
    return "SWITCH: [TACTICAL] [LETHAL] or [V]   LOCK: HOLD [ SPACE / F ]"
end

-- [tod v16.32, docs/69 §6] THE OVERLAY LINES over the blank frame
-- (USE_HINT_FRAME_ART): engine-expanded [{+bind}] tokens, set through
-- Engine.Localize at SHOW time.
--
-- [tod v16.83] ONE LANE PER ACTION, AND ITS DIRECTION — twin of the block in
-- tod_upgrade.lua, where the whole argument lives. Draft-specific note: this
-- menu has FOUR cards, not two, so tactical/lethal STEP the selection (they
-- wrap), and `_tod_class_select::run_select_input` gives them the same sides
-- the deal panel does (tactical = previous, lethal = next). No device branch:
-- the tokens expand to whatever the live device has bound.
local function SwitchLine1()
    return "^3[{+smoke}]^7 ^5<  SWITCH  >^7 ^3[{+frag}]^7"
end
local function LockLine()
    return "HOLD ^3[{+gostand}]^7 TO LOCK"
end

CoD.TodClassSelect = InheritFrom( LUI.UIElement )

function CoD.TodClassSelect.new( HudRef, InstanceRef )
    local self = LUI.UIElement.new()
    CoD.TodUIOwnership.Attach( self )
    self:setClass( CoD.TodClassSelect )
    self.id = "TodClassSelect"
    self.soundSet = "HUD"
    self:setLeftRight( true, true, 0, 0 )
    self:setTopBottom( true, true, 0, 0 )
    self:setAlpha( 0 )

    local art = {}
    if USE_CLASS_CARD_ART then
        art.cards = {
            [1] = RegisterImage( "i_tod_card_class_skirmisher" ),
            [2] = RegisterImage( "i_tod_card_class_assault" ),
            [3] = RegisterImage( "i_tod_card_class_heavy" ),
            [4] = RegisterImage( "i_tod_card_class_slasher" ),
            -- MAGE (docs/116, installed 2026-09-07). Registered ONLY now that
            -- its zone line exists: lint_tod_assets GATE A is comment-stripped
            -- and flag-blind, so the literal and the zone line must land in
            -- the same build.
            [5] = RegisterImage( "i_tod_card_class_mage" ),
        }
        -- UI-family art (files (11).zip): the draft banner + input hints
        art.banner = RegisterImage( "i_tod_banner_choose_class" )
        art.hintLockPad = RegisterImage( "i_tod_hint_lock_pad" )
        art.hintLockKbm = RegisterImage( "i_tod_hint_lock_kbm" )
        art.hintSwitchPad = RegisterImage( "i_tod_hint_switch_pad" )
        art.hintSwitchKbm = RegisterImage( "i_tod_hint_switch_kbm" )
        art.hintLocked = RegisterImage( "i_tod_hint_locked" )
        if USE_HINT_FRAME_ART then
            art.hintFrame = RegisterImage( "i_tod_hint_frame" )
        end
        -- [tod v16.88] real button glyphs (docs/88). The square keycap is
        -- deliberately not registered — see the note in tod_upgrade.lua.
        if USE_CARD_GLYPH_ART then
            art.padDpadL  = RegisterImage( "i_tod_pad_dpad_left" )
            art.padDpadR  = RegisterImage( "i_tod_pad_dpad_right" )
            art.padBtnA   = RegisterImage( "i_tod_pad_button_a" )
            art.keyWide   = RegisterImage( "i_tod_key_blank_wide" )
            art.holdPlate = RegisterImage( "i_tod_hold_plate" )
            art.barTrack  = RegisterImage( "i_tod_timer_track" )
            art.barFill   = RegisterImage( "i_tod_timer_fill" )
        end
    end
    if USE_CLASS_ICON_ART then
        art.icons = {
            [1] = RegisterImage( "i_tod_class_skirmisher" ),
            [2] = RegisterImage( "i_tod_class_assault" ),
            [3] = RegisterImage( "i_tod_class_heavy" ),
            [4] = RegisterImage( "i_tod_class_slasher" ),
            [5] = RegisterImage( "i_tod_class_mage" ),
        }
    end

    -- ---- title --------------------------------------------------------------
    local TitleBg = CoD.TextWithBg.new( HudRef, InstanceRef )
    TitleBg:setLeftRight( false, false, -340, 340 )
    TitleBg:setTopBottom( true, false, 148, 188 )
    TitleBg.Text:setText( "" )
    TitleBg.Bg:setRGB( PAL.glass[ 1 ], PAL.glass[ 2 ], PAL.glass[ 3 ] )
    TitleBg.Bg:setAlpha( 0.85 )
    self:addElement( TitleBg )

    local Title = LUI.UIText.new()
    Title:setLeftRight( false, false, -340, 340 )
    Title:setTopBottom( true, false, 156, 182 )
    Title:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
    Title:setRGB( PAL.line[ 1 ], PAL.line[ 2 ], PAL.line[ 3 ] )
    self:addElement( Title )

    local SubTitle = LUI.UIText.new()
    SubTitle:setLeftRight( false, false, -340, 340 )
    SubTitle:setTopBottom( true, false, 190, 208 )
    SubTitle:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
    SubTitle:setScale( 0.8 )
    SubTitle:setRGB( PAL.dim[ 1 ], PAL.dim[ 2 ], PAL.dim[ 3 ] )
    self:addElement( SubTitle )

    if art.banner then
        -- baked "CHOOSE YOUR CLASS" banner (900x140 art at 600x93) — the
        -- title/subtitle texts above stay as the no-art fallback (blank)
        local BannerImg = LUI.UIImage.new()
        BannerImg:setLeftRight( false, false, -300, 300 )
        BannerImg:setTopBottom( true, false, 104, 197 )
        BannerImg:setImage( art.banner )
        self:addElement( BannerImg )
        TitleBg.Bg:setAlpha( 0 )   -- the glass plate would poke out past the banner
    else
        Title:setText( "CHOOSE YOUR CLASS" )
        SubTitle:setText( "your gun and upgrade paths - PERMANENT for this run" )
    end

    -- SWITCH-HINT plate (baked; countdown stays live text)
    local SwitchHintImg = nil
    if art.hintSwitchPad then
        SwitchHintImg = LUI.UIImage.new()
        -- [tod v16.83] ONE line, so ONE geometry for both paths: 280x43, the
        -- art's true 460/70 aspect, clear of the hold bars (end 565) and the
        -- countdown (starts 615).
        SwitchHintImg:setLeftRight( false, false, -140, 140 )
        SwitchHintImg:setTopBottom( true, false, 568, 611 )
        SwitchHintImg:setAlpha( 0 )
        self:addElement( SwitchHintImg )
    end

    -- [tod v16.32, one line since v16.83] the key line over the blank frame
    -- (USE_HINT_FRAME_ART), centred in the plate's 568..611 band.
    local SwitchHintText1 = nil
    if SwitchHintImg and USE_HINT_FRAME_ART and art.hintFrame then
        SwitchHintText1 = LUI.UIText.new()
        SwitchHintText1:setLeftRight( false, false, -134, 134 )
        SwitchHintText1:setTopBottom( true, false, 581, 598 )
        SwitchHintText1:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
        SwitchHintText1:setRGB( 1, 1, 1 )
        SwitchHintText1:setAlpha( 0 )
        self:addElement( SwitchHintText1 )
    end

    -- [tod v16.88] THE SWITCH GLYPHS, flanking the four-card row. The draft
    -- STEPS and WRAPS rather than toggling, so the arrows read as "move along
    -- the row" — which is exactly what tactical/lethal and the d-pad do here.
    local SwitchGlyph = {}
    if USE_CARD_GLYPH_ART and art.padDpadL then
        -- CENTRED UNDER THE ROW, in the old switch plate's band — twin of the
        -- deal panel; the reasoning and the per-device rect rule are there.
        local function GlyphSlot( side )
            local g = { side = side }
            g.Img = LUI.UIImage.new()
            g.Img:setAlpha( 0 )
            self:addElement( g.Img )
            g.Text = LUI.UIText.new()
            g.Text:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
            g.Text:setRGB( 0.06, 0.07, 0.10 )
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
    -- [tod v18.32] THE WORD BETWEEN THEM. User 2026-09-08, on the shipped
    -- screens: *"Spacing is not best or good design."*
    --
    -- WHAT WAS ACTUALLY MISSING WAS THE SENTENCE, not the spacing. v16.88
    -- replaced the baked switch plate with two glyphs and hid the plate for
    -- the whole match — and the plate was the only thing that said SWITCH.
    -- `SwitchLine1()` still spells `[tac] < SWITCH > [lethal]`, the copy
    -- CLAUDE.md documents, but it has been unreachable on every real build
    -- since: two bare buttons, centred, with nothing to read. On a pad the
    -- arrows at least imply "move along the row"; on a keyboard it is two
    -- blank caps with letters in them, which is the map's own standing rule
    -- broken — a menu may ACCEPT eight inputs but must ADVERTISE one, WITH
    -- ITS DIRECTION.
    --
    -- Drawn in the map's baked typeface, like the key names beside it, so the
    -- row is one piece of lettering rather than a font sitting next to art.
    -- The UIText is the no-typeface fallback, same contract as TodKeycap.
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

    -- ONE writer each for the switch plate and a card's under-plate — twins
    -- of tod_upgrade.lua's ShowSwitchPlate / CardHint.
    local function ShowSwitchPlate( on )
        if SwitchGlyph.L then
            local pad = UsingController()
            local CX, HW, Y0, Y1
            if pad then
                CX, HW, Y0, Y1 = 640, 24, 566, 614   -- 48 sq glyph
            else
                -- [v17.4] 96 x 48, sized for a multi-bound action — the full
                -- reasoning is on the twin block in tod_upgrade.lua.
                CX, HW, Y0, Y1 = 640, 48, 566, 614   -- 96 x 48 keycap
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
            -- [tod v16.88] baked plate says the words, the gap holds the button
            card.HintImg:setImage( art.holdPlate )
            if card.HintText then
                card.HintText:setAlpha( 0 )
            end
            -- [tod v18.32] the jump token gets the ICON test as well: if the
            -- engine is going to hand us a picture of the A button, the pale
            -- keycap must not be drawn behind it (2026-09-08 screenshot).
            --
            -- BOTH SIZES COME OUT OF THE GAP, and each keeps its art's own
            -- aspect. The pad button is square, sized to the plate's band; the
            -- keycap is the art's true 2:1, as wide as the gap allows and no
            -- wider. The old literals (28 and 60) were typed against a plate
            -- that has since been drawn at three different widths.
            local gap = card.lockGapW
            local cx, cy = card.lockCx, card.lockCy
            -- [tod v18.48] DEVICE ONLY. v18.47 OR'd the jump token's icon
            -- test in here; that test fires on a keyboard too, so it put every
            -- KBM player on the A button. The keycap's own fallback still
            -- refuses to draw a picture inside itself — that is where the
            -- guard belongs, not in the device choice.
            if UsingController() then
                local s = math.floor( PLATE_H * 0.85 / 2 )      -- half of ~28
                card.LockGlyph:setImage( art.padBtnA )
                card.LockGlyph:setLeftRight( true, false, cx - s, cx + s )
                card.LockGlyph:setTopBottom( true, false, cy - s, cy + s )
                card.LockKey.hide()
            else
                -- [tod v17.27] TodKeycap measures the key name in the map's own
                -- typeface and sizes it to the cap's bright face, so the cap
                -- only has to be the right SHAPE and inside the gap.
                local w = math.floor( ( gap - 2 ) / 2 ) * 2     -- even, fits gap
                local h = math.floor( w / 2 )                   -- the art is 2:1
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

    -- countdown (bottom)
    local TimeLine = LUI.UIText.new()
    TimeLine:setLeftRight( false, false, -340, 340 )
    TimeLine:setTopBottom( true, false, 615, 639 )
    TimeLine:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
    TimeLine:setScale( 0.9 )
    TimeLine:setText( "" )
    self:addElement( TimeLine )

    -- [tod v16.95] THE DRAFT COUNTDOWN BECOMES A BAR TOO (user 2026-09-03:
    -- *"I did like the timer bar instead of the seconds text"*). v16.88 gave the
    -- bar to the DEAL panel and left its twin here on "RANDOM IN 30s", which is
    -- the same half-finished shape as the pause legend in v16.93: three surfaces
    -- present these controls and a change to one owes the other two.
    --
    -- Draft-specific: todUpgTime is QUARTERED here (the display multiplied by 4),
    -- but the bar is a RATIO so the quartering cancels and no x4 is needed. Same
    -- watched-maximum trick as the deal panel — no field carries the timeout, so
    -- the first tick of the draft is the largest value it will ever see.
    local timeMaxSeen = 0
    local TimeTrack, TimeFill = nil, nil
    if USE_CARD_GLYPH_ART and art.barTrack then
        TimeTrack = LUI.UIImage.new()
        TimeTrack:setLeftRight( false, false, -140, 140 )
        TimeTrack:setTopBottom( true, false, 620, 634 )
        TimeTrack:setImage( art.barTrack )
        TimeTrack:setAlpha( 0 )
        self:addElement( TimeTrack )

        TimeFill = LUI.UIImage.new()
        TimeFill:setLeftRight( false, false, -140, 140 )
        TimeFill:setTopBottom( true, false, 620, 634 )
        TimeFill:setImage( art.barFill )
        TimeFill:setAlpha( 0 )
        self:addElement( TimeFill )
    end

    -- ---- one class card (built 4x) ------------------------------------------
    -- PORTRAIT layout: 4 baked 2:3 class cards (210x315). The composite text
    -- stack survives as the no-art fallback; with card art on, the baked
    -- image carries name/gun/role/descs and the texts are blanked. Bind +
    -- hold bar live BELOW the card; Top/Bot accent strips stay for focus.
    local function BuildCard( id )
        local classId = DISPLAY_CLASSES[ id ]
        local c = CLASSES[ classId ]
        local xLo = CARD_X0 + ( id - 1 ) * CARD_PITCH
        local xHi = xLo + CARD_W
        local card = {}

        local Bg = CoD.TextWithBg.new( HudRef, InstanceRef )
        Bg:setLeftRight( true, false, xLo, xHi )
        Bg:setTopBottom( true, false, CCARD_Y0, CCARD_Y1 )
        Bg.Text:setText( "" )
        Bg.Bg:setRGB( PAL.glass[ 1 ], PAL.glass[ 2 ], PAL.glass[ 3 ] )
        Bg.Bg:setAlpha( 0.85 )
        self:addElement( Bg )
        card.Bg = Bg

        -- PER-CARD, not per-table (docs/114). art.cards is a 4-entry table, so
        -- with a fifth card the truthiness test below passes, art.cards[5] is
        -- nil, setImage(nil) draws nothing AND the composite text stack stays
        -- suppressed -- a glass rectangle with no text and no diagnosis.
        local cardImg = art.cards and art.cards[ classId ]
        if cardImg then
            local CardImg = LUI.UIImage.new()
            CardImg:setLeftRight( true, false, xLo, xHi )
            CardImg:setTopBottom( true, false, CCARD_Y0, CCARD_Y1 )
            CardImg:setImage( cardImg )
            self:addElement( CardImg )
            card.CardImg = CardImg
            Bg.Bg:setAlpha( 0 )   -- the art IS the card
        end

        local Top = CoD.TextWithBg.new( HudRef, InstanceRef )
        Top:setLeftRight( true, false, xLo, xHi )
        Top:setTopBottom( true, false, CCARD_Y0, CCARD_Y0 + 5 )
        Top.Text:setText( "" )
        Top.Bg:setRGB( c.accent[ 1 ], c.accent[ 2 ], c.accent[ 3 ] )
        Top.Bg:setAlpha( 0.95 )
        self:addElement( Top )
        card.Top = Top

        local Bot = CoD.TextWithBg.new( HudRef, InstanceRef )
        Bot:setLeftRight( true, false, xLo, xHi )
        Bot:setTopBottom( true, false, CCARD_Y1 - 5, CCARD_Y1 )
        Bot.Text:setText( "" )
        Bot.Bg:setRGB( c.accent[ 1 ], c.accent[ 2 ], c.accent[ 3 ] )
        Bot.Bg:setAlpha( 0.95 )
        self:addElement( Bot )
        card.Bot = Bot
        card.accent = c.accent   -- cached for the per-render accent re-assert

        if art.icons then
            local Icon = LUI.UIImage.new()
            Icon:setLeftRight( true, false, xLo + math.floor( ( CARD_W - 64 ) / 2 ), xLo + math.floor( ( CARD_W - 64 ) / 2 ) + 64 )
            Icon:setTopBottom( true, false, CCARD_Y0 + 10, CCARD_Y0 + 66 )
            Icon:setImage( art.icons[ classId ] )
            self:addElement( Icon )
            card.Icon = Icon
        end

        local function Line( topPx, botPx, scale )
            local t = LUI.UIText.new()
            t:setLeftRight( true, false, xLo + 10, xHi - 10 )
            t:setTopBottom( true, false, topPx, botPx )
            t:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
            t:setScale( scale )
            self:addElement( t )
            return t
        end

        -- fallback composite stack (portrait); blanked when card art is on
        local yBase = ( art.icons and ( CCARD_Y0 + 76 ) ) or ( CCARD_Y0 + 60 )
        card.Role  = Line( yBase, yBase + 18, 0.7 )
        card.Role:setRGB( c.accent[ 1 ], c.accent[ 2 ], c.accent[ 3 ] )
        card.Name  = Line( yBase + 20, yBase + 48, 1.1 )
        card.Name:setRGB( PAL.text[ 1 ], PAL.text[ 2 ], PAL.text[ 3 ] )
        card.Gun   = Line( yBase + 50, yBase + 68, 0.85 )
        card.Gun:setRGB( c.accent[ 1 ], c.accent[ 2 ], c.accent[ 3 ] )
        card.Desc1 = Line( yBase + 72, yBase + 87, 0.7 )
        card.Desc1:setRGB( PAL.dim[ 1 ], PAL.dim[ 2 ], PAL.dim[ 3 ] )
        card.Desc2 = Line( yBase + 89, yBase + 104, 0.7 )
        card.Desc2:setRGB( PAL.dim[ 1 ], PAL.dim[ 2 ], PAL.dim[ 3 ] )
        if not cardImg then
            card.Role:setText( c.role )
            card.Name:setText( c.name )
            card.Gun:setText( c.gun )
            card.Desc1:setText( c.desc1 )
            card.Desc2:setText( c.desc2 )
        end
        -- Bind + bar BELOW the card (disjoint, the upgrade-panel spacing)
        card.Bind  = Line( CCARD_Y1 + 6, CCARD_Y1 + 26, 0.8 )
        card.Bind:setText( "" )
        card.Bind:setRGB( PAL.pick[ 1 ], PAL.pick[ 2 ], PAL.pick[ 3 ] )
        if art.hintLockPad then
            -- baked input-hint plate under the card
            -- [tod v18.32] TRUE ASPECT, CENTRED ON THE CARD. Not xLo+5..xHi-5:
            -- that tied the plate's width to the CARD's, and the mage's narrower
            -- card squashed all three plate arts by 27%. The plate is now as
            -- wide as its own aspect demands for the 34 px band it is given, and
            -- overhangs the card — which is fine, and deliberate: the cards sit
            -- CARD_PITCH apart and only ONE plate is ever shown lit.
            local plateL = math.floor( ( xLo + xHi ) / 2 - PLATE_W / 2 )
            local HintImg = LUI.UIImage.new()
            HintImg:setLeftRight( true, false, plateL, plateL + PLATE_W )
            HintImg:setTopBottom( true, false, CCARD_Y1 + 4, CCARD_Y1 + 4 + PLATE_H )
            HintImg:setAlpha( 0 )
            self:addElement( HintImg )
            card.HintImg = HintImg
            card.plateL  = plateL
            card.plateT  = CCARD_Y1 + 4
            if USE_HINT_FRAME_ART and art.hintFrame then
                -- [tod v16.32] the key line over the blank frame; centred on
                -- the plate's own lettering band (PLATE_INK_CY).
                local inkCy = CCARD_Y1 + 4 + PLATE_H * PLATE_INK_CY
                local HintText = LUI.UIText.new()
                HintText:setLeftRight( true, false, plateL + 9, plateL + PLATE_W - 9 )
                HintText:setTopBottom( true, false, inkCy - 6, inkCy + 6 )
                HintText:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
                HintText:setRGB( 1, 1, 1 )
                HintText:setAlpha( 0 )
                self:addElement( HintText )
                card.HintText = HintText
            end
        end

        -- [tod v16.88] the button that drops into the hold plate's baked gap.
        -- [tod v18.32] BOTH RECTS ARE WRITTEN BY CardHint, from the measured
        -- gap — the pad button is square and the keycap is 2:1, so no single
        -- construction-time rect serves both without stretching one. What is
        -- stored here is only where the gap IS.
        if USE_CARD_GLYPH_ART and art.holdPlate then
            local cx = ( xLo + xHi ) / 2
            card.lockCx = math.floor( card.plateL + PLATE_W * PLATE_GAP_CX )
            card.lockCy = math.floor( card.plateT + PLATE_H * PLATE_INK_CY )
            card.lockGapW = math.floor( PLATE_W * PLATE_GAP_W )
            local LockGlyph = LUI.UIImage.new()
            LockGlyph:setAlpha( 0 )
            self:addElement( LockGlyph )
            card.LockGlyph = LockGlyph
            local LockKeyText = LUI.UIText.new()
            LockKeyText:setLeftRight( true, false, cx - 24, cx + 24 )
            LockKeyText:setTopBottom( true, false, CCARD_Y1 + 12, CCARD_Y1 + 28 )
            LockKeyText:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
            LockKeyText:setRGB( 0.06, 0.07, 0.10 )
            LockKeyText:setAlpha( 0 )
            self:addElement( LockKeyText )
            card.LockKeyText = LockKeyText
            -- [tod v17.27] the key name in the map's typeface, over this cap.
            -- Built last so the glyphs draw above both the plate and the cap.
            card.LockKey = TodKeycapMake( self, LockKeyText )
        end

        -- hold-to-lock bar
        -- [tod v16.88] +36 -> +42: the hold plate above grew to 34 px tall so a
        -- button glyph fits in its gap. The art bar below replaces this quad
        -- when the glyph set is on (same reasoning as tod_upgrade.lua: whether
        -- CoD.TextWithBg's Bg takes an image is unverifiable from this tree).
        local HoldFill = CoD.TextWithBg.new( HudRef, InstanceRef )
        HoldFill:setLeftRight( true, false, xLo + 10, xLo + 10 )
        HoldFill:setTopBottom( true, false, CCARD_Y1 + 42, CCARD_Y1 + 46 )
        HoldFill.Text:setText( "" )
        HoldFill.Bg:setRGB( PAL.pick[ 1 ], PAL.pick[ 2 ], PAL.pick[ 3 ] )
        HoldFill.Bg:setAlpha( 0 )
        self:addElement( HoldFill )
        card.HoldFill = HoldFill
        card.holdLo = xLo + 10
        card.holdHi = xHi - 10

        if USE_CARD_GLYPH_ART and art.barTrack then
            local BarTrack = LUI.UIImage.new()
            BarTrack:setLeftRight( true, false, xLo + 10, xHi - 10 )
            BarTrack:setTopBottom( true, false, CCARD_Y1 + 42, CCARD_Y1 + 52 )
            BarTrack:setImage( art.barTrack )
            BarTrack:setAlpha( 0 )
            self:addElement( BarTrack )
            card.BarTrack = BarTrack

            local BarFill = LUI.UIImage.new()
            BarFill:setLeftRight( true, false, xLo + 10, xLo + 10 )
            BarFill:setTopBottom( true, false, CCARD_Y1 + 42, CCARD_Y1 + 52 )
            BarFill:setImage( art.barFill )
            BarFill:setAlpha( 0 )
            self:addElement( BarFill )
            card.BarFill = BarFill
        end

        card.group = { Bg, Top, Bot, card.Role, card.Name, card.Gun, card.Desc1, card.Desc2, card.Bind }
        if card.CardImg then
            card.group[ #card.group + 1 ] = card.CardImg
        end
        if card.Icon then
            card.group[ #card.group + 1 ] = card.Icon
        end
        return card
    end

    local cards = {}
    for i = 1, CLASS_N do
        cards[ i ] = BuildCard( i )
    end

    local function SetCardAlpha( card, a )
        for i = 1, #card.group do
            card.group[ i ]:setAlpha( a )
        end
    end

    -- ---- state + render -----------------------------------------------------
    local st = { show = 0, focus = 0, time = 0, hold = 0 }

    local function Render()
        if st.show == 0 then
            self:completeAnimation()
            self:beginAnimation( "keyframe", 250, false, false, CoD.TweenType.Linear )
            self:setAlpha( 0 )
            return
        end

        local fCls = st.focus
        if fCls < 1 or fCls > CLASS_N then
            fCls = DEFAULT_FOCUS
        end

        if st.show == 1 then
            if not art.banner then
                TitleBg.Bg:setAlpha( 0.85 )   -- glass plate only in the no-art fallback
            end
            if st.time > 0 then
                -- todUpgTime carries QUARTER-seconds (60s draft in a 4-bit field).
                -- LOCKSTEP with TOD_CLS_TIMEOUT + its /4 encoding in
                -- _tod_class_select.gsc. The x4 here is the whole decode.
                if SwitchHintImg then
                    ShowSwitchPlate( true )
                    if TimeTrack then
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
                        if st.time <= TIME_DANGER then
                            TimeFill:setRGB( 1.0, 0.25, 0.3 )
                        else
                            TimeFill:setRGB( 1, 1, 1 )
                        end
                    else
                        TimeLine:setText( "RANDOM IN " .. ( st.time * 4 ) .. "s" )
                    end
                else
                    TimeLine:setText( SwitchHint() .. "   RANDOM IN " .. ( st.time * 4 ) .. "s" )
                end
                if st.time <= TIME_DANGER then
                    TimeLine:setRGB( 1.0, 0.25, 0.3 )
                else
                    TimeLine:setRGB( PAL.dim[ 1 ], PAL.dim[ 2 ], PAL.dim[ 3 ] )
                end
            else
                TimeLine:setText( "" )
                ShowSwitchPlate( false )
                if TimeTrack then
                    TimeTrack:setAlpha( 0 )
                    TimeFill:setAlpha( 0 )
                    timeMaxSeen = 0   -- or the next draft opens part-drained
                end
            end

            for i = 1, CLASS_N do
                local card = cards[ i ]
                -- re-assert the class accent every render (state-restore:
                -- a confirm-flash recolors strips to PAL.pick and nothing
                -- else ever restored them — verify 2026-08-20)
                card.Top.Bg:setRGB( card.accent[ 1 ], card.accent[ 2 ], card.accent[ 3 ] )
                card.Bot.Bg:setRGB( card.accent[ 1 ], card.accent[ 2 ], card.accent[ 3 ] )
                if i == fCls then
                    SetCardAlpha( card, 1 )
                    card.Top.Bg:setAlpha( 0.95 )
                    card.Bot.Bg:setAlpha( 0.95 )
                    if card.HintImg then
                        CardHint( card, "lock", 1 )
                        card.Bind:setText( "" )
                    else
                        card.Bind:setText( LockHint() )
                        card.Bind:setAlpha( 1 )
                    end
                    local w = ( card.holdHi - card.holdLo ) * ( st.hold / 15 )
                    -- [tod v16.88] art bar when present, colour quad otherwise
                    if card.BarTrack then
                        card.HoldFill.Bg:setAlpha( 0 )
                    if card.BarTrack then
                        card.BarTrack:setAlpha( 0 )
                        card.BarFill:setAlpha( 0 )
                    end
                        card.BarTrack:setAlpha( 0.85 )
                        card.BarFill:setLeftRight( true, false, card.holdLo, card.holdLo + w )
                        card.BarFill:setAlpha( ( st.hold > 0 ) and 1 or 0 )
                    else
                        card.HoldFill:setLeftRight( true, false, card.holdLo, card.holdLo + w )
                        card.HoldFill.Bg:setAlpha( ( st.hold > 0 ) and 0.95 or 0 )
                    end
                else
                    SetCardAlpha( card, 0.45 )
                    card.Top.Bg:setAlpha( 0.95 )
                    card.Bot.Bg:setAlpha( 0.95 )
                    card.Bind:setText( "" )
                    CardHint( card, "off", 0 )
                    card.HoldFill.Bg:setAlpha( 0 )
                    if card.BarTrack then
                        card.BarTrack:setAlpha( 0 )
                        card.BarFill:setAlpha( 0 )
                    end
                end
            end
        elseif st.show == 2 then
            -- confirm flash: focus IS the pick while show==2
            TimeLine:setText( "" )
            ShowSwitchPlate( false )
            if TimeTrack then
                TimeTrack:setAlpha( 0 )
                TimeFill:setAlpha( 0 )
            end
            for i = 1, CLASS_N do
                local card = cards[ i ]
                if i == fCls then
                    SetCardAlpha( card, 1 )
                    card.Top.Bg:setRGB( PAL.pick[ 1 ], PAL.pick[ 2 ], PAL.pick[ 3 ] )
                    card.Bot.Bg:setRGB( PAL.pick[ 1 ], PAL.pick[ 2 ], PAL.pick[ 3 ] )
                    card.Top.Bg:setAlpha( 0.95 )
                    card.Bot.Bg:setAlpha( 0.95 )
                    if card.HintImg then
                        CardHint( card, "locked", 1 )
                        card.Bind:setText( "" )
                    else
                        card.Bind:setText( "LOCKED IN" )
                        card.Bind:setAlpha( 1 )
                    end
                    card.HoldFill.Bg:setAlpha( 0 )
                    if card.BarTrack then
                        card.BarTrack:setAlpha( 0 )
                        card.BarFill:setAlpha( 0 )
                    end
                else
                    SetCardAlpha( card, 0.15 )
                    card.Bind:setText( "" )
                    CardHint( card, "off", 0 )
                    card.HoldFill.Bg:setAlpha( 0 )
                    if card.BarTrack then
                        card.BarTrack:setAlpha( 0 )
                        card.BarFill:setAlpha( 0 )
                    end
                end
            end
        end

        self:completeAnimation()
        self:beginAnimation( "keyframe", 250, false, false, CoD.TweenType.Linear )
        self:setAlpha( 1 )
    end

    -- ---- model subscriptions (shared fields — see the header) ---------------
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
    Watch( "todUpgFocus", "focus" )
    Watch( "todUpgTime", "time" )
    Watch( "todUpgHold", "hold" )
    Watch( "todClsShow", "show" )   -- last: paints with the full state

    return self
end

function LUI.createMenu.tod_class_select( Instance )
    local Hud = CoD.Menu.NewForUIEditor( "tod_class_select" )
    CoD.TodUIOwnership.Attach( Hud )

    Hud.soundSet = "HUD"
    Hud:setOwner( Instance )
    Hud:setLeftRight( true, true, 0, 0 )
    Hud:setTopBottom( true, true, 0, 0 )

    local Panel = CoD.TodClassSelect.new( Hud, Instance )
    Hud:addElement( Panel )
    Hud.todClassSelect = Panel

    return Hud
end
