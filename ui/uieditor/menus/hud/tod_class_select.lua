-- =============================================================================
-- tod_class_select.lua — the game-start class draft panel (4 cards).
--
-- Same doctrine as tod_upgrade.lua: additive overlay opened per-player from
-- GSC (OpenLUIMenu "tod_class_select"), a DUMB renderer fed by all-INT
-- clientuimodel fields (registered in _tod_upgrade_ui.gsc/.csc lockstep).
-- BUDGET NOTE (the clientuimodel overflow aborts map load — 2026-08-19):
-- only todClsShow is class-specific; focus/time/hold RIDE the upgrade
-- panel's fields (the two panels are never live together):
--   todClsShow  0 hidden | 1 choosing | 2 locked (confirm flash)
--   todUpgFocus focused class 1-4 (steady bright; at show==2 = the PICK)
--   todUpgTime  HALVED seconds until random auto-pick (display x2, red <= 3)
--   todUpgHold  hold-to-lock progress 0..15 (the fill bar)
-- Class ids MUST mirror _tod_class_select.gsc::class_key:
--   1 SKIRMISHER / 2 ASSAULT / 3 HEAVY / 4 SLASHER
--
-- ART DROP-IN (LIVE 2026-08-20, art8 sheet): class icon slots use
-- i_tod_class_skirmisher / i_tod_class_assault / i_tod_class_heavy /
-- i_tod_class_slasher (+ image,i_tod_class_* zone lines). Never flip the
-- flag before the assets are zoned.
-- =============================================================================

local PAL = {
    glass = { 0, 0.035, 0.085 },
    line  = { 0.2, 0.75, 1.0 },
    text  = { 0.86, 0.9, 0.95 },
    dim   = { 0.55, 0.62, 0.7 },
    pick  = { 0.2, 0.95, 0.85 },
}

-- id -> presentation. accent = the class's neon identity color.
local CLASSES = {
    -- CLASS TIERS (2026-08-22): the tier-1 guns changed — MAC-10 / Enfield open
    -- the run; desc2 now names each class's three-gun ladder. (Baked class
    -- card art carries the real text; this is the no-art fallback.)
    [1] = { name = "SKIRMISHER", gun = "MAC-10 SMG",      role = "RUN AND GUN",
            desc1 = "fastest fire rate + speed",   desc2 = "MAC-10 > MP5 > MP7",
            accent = { 0.20, 0.85, 1.00 } },
    [2] = { name = "ASSAULT",    gun = "ENFIELD RIFLE",   role = "PRECISION",
            desc1 = "headshots + recoil control",  desc2 = "ENFIELD > KRIG 6 > AK-47",
            accent = { 1.00, 0.75, 0.25 } },
    [3] = { name = "HEAVY",      gun = "STONER 63 LMG",   role = "SUSTAINED FIRE",
            desc1 = "bullet feed + suppression",   desc2 = "STONER > HK21 > DEATH MACHINE",
            accent = { 1.00, 0.35, 0.30 } },
    [4] = { name = "SLASHER",    gun = "COMBAT KNIFE",    role = "UP CLOSE",
            desc1 = "cleave + life leech",         desc2 = "KNIFE > KATANA > STORMBREAKER",
            accent = { 0.75, 0.45, 1.00 } },
}

local USE_CLASS_ICON_ART = true   -- ON 2026-08-20: i_tod_class_* installed + zoned (art8 sheet)
-- FULL-CARD CLASS ART (files (10).zip 2026-08-20): 4 baked portrait cards
-- (i_tod_card_class_*) replace the composite; LUI keeps bind/hold/focus.
local USE_CLASS_CARD_ART = true
if USE_CLASS_CARD_ART then
    USE_CLASS_ICON_ART = false
end
-- portrait card rect: 210x315 (2:3), 4 across the 1280 canvas
local CCARD_Y0, CCARD_Y1 = 210, 525

local TIME_DANGER = 3   -- in HALF-seconds (todUpgTime is halved) = last 6s red

-- Per-input wording (nil-guarded — controller fallback; PS-vs-Xbox is not
-- distinguishable on PC BO3, the engine only knows gamepad vs KBM).
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
    -- v10.19: mouse + F joined (see tod_upgrade.lua)
    -- v10.20: proven lane only (see tod_upgrade.lua)
    return "SWITCH: [MOUSE1] [MOUSE2] or [V]   LOCK: HOLD [ SPACE / F ]"
end

CoD.TodClassSelect = InheritFrom( LUI.UIElement )

function CoD.TodClassSelect.new( HudRef, InstanceRef )
    local self = LUI.UIElement.new()
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
        }
        -- UI-family art (files (11).zip): the draft banner + input hints
        art.banner = RegisterImage( "i_tod_banner_choose_class" )
        art.hintLockPad = RegisterImage( "i_tod_hint_lock_pad" )
        art.hintLockKbm = RegisterImage( "i_tod_hint_lock_kbm" )
        art.hintSwitchPad = RegisterImage( "i_tod_hint_switch_pad" )
        art.hintSwitchKbm = RegisterImage( "i_tod_hint_switch_kbm" )
        art.hintLocked = RegisterImage( "i_tod_hint_locked" )
    end
    if USE_CLASS_ICON_ART then
        art.icons = {
            [1] = RegisterImage( "i_tod_class_skirmisher" ),
            [2] = RegisterImage( "i_tod_class_assault" ),
            [3] = RegisterImage( "i_tod_class_heavy" ),
            [4] = RegisterImage( "i_tod_class_slasher" ),
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
        SwitchHintImg:setLeftRight( false, false, -140, 140 )
        SwitchHintImg:setTopBottom( true, false, 568, 611 )   -- 280x43 true aspect; clear of the hold bars
        SwitchHintImg:setAlpha( 0 )
        self:addElement( SwitchHintImg )
    end

    -- countdown (bottom)
    local TimeLine = LUI.UIText.new()
    TimeLine:setLeftRight( false, false, -340, 340 )
    TimeLine:setTopBottom( true, false, 615, 639 )
    TimeLine:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_CENTER )
    TimeLine:setScale( 0.9 )
    TimeLine:setText( "" )
    self:addElement( TimeLine )

    -- ---- one class card (built 4x) ------------------------------------------
    -- PORTRAIT layout: 4 baked 2:3 class cards (210x315). The composite text
    -- stack survives as the no-art fallback; with card art on, the baked
    -- image carries name/gun/role/descs and the texts are blanked. Bind +
    -- hold bar live BELOW the card; Top/Bot accent strips stay for focus.
    local function BuildCard( id )
        local c = CLASSES[ id ]
        local xLo = 88 + ( id - 1 ) * 298
        local xHi = xLo + 210
        local card = {}

        local Bg = CoD.TextWithBg.new( HudRef, InstanceRef )
        Bg:setLeftRight( true, false, xLo, xHi )
        Bg:setTopBottom( true, false, CCARD_Y0, CCARD_Y1 )
        Bg.Text:setText( "" )
        Bg.Bg:setRGB( PAL.glass[ 1 ], PAL.glass[ 2 ], PAL.glass[ 3 ] )
        Bg.Bg:setAlpha( 0.85 )
        self:addElement( Bg )
        card.Bg = Bg

        if art.cards then
            local CardImg = LUI.UIImage.new()
            CardImg:setLeftRight( true, false, xLo, xHi )
            CardImg:setTopBottom( true, false, CCARD_Y0, CCARD_Y1 )
            CardImg:setImage( art.cards[ id ] )
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
            Icon:setLeftRight( true, false, xLo + 73, xLo + 137 )
            Icon:setTopBottom( true, false, CCARD_Y0 + 10, CCARD_Y0 + 66 )
            Icon:setImage( art.icons[ id ] )
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
        if not art.cards then
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
            local HintImg = LUI.UIImage.new()
            HintImg:setLeftRight( true, false, xLo + 5, xHi - 5 )
            HintImg:setTopBottom( true, false, CCARD_Y1 + 4, CCARD_Y1 + 34 )
            HintImg:setAlpha( 0 )
            self:addElement( HintImg )
            card.HintImg = HintImg
        end

        -- hold-to-lock bar
        local HoldFill = CoD.TextWithBg.new( HudRef, InstanceRef )
        HoldFill:setLeftRight( true, false, xLo + 10, xLo + 10 )
        HoldFill:setTopBottom( true, false, CCARD_Y1 + 36, CCARD_Y1 + 40 )   -- below the hint plate (verify 2026-08-20)
        HoldFill.Text:setText( "" )
        HoldFill.Bg:setRGB( PAL.pick[ 1 ], PAL.pick[ 2 ], PAL.pick[ 3 ] )
        HoldFill.Bg:setAlpha( 0 )
        self:addElement( HoldFill )
        card.HoldFill = HoldFill
        card.holdLo = xLo + 10
        card.holdHi = xHi - 10

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
    for i = 1, 4 do
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
        if fCls < 1 or fCls > 4 then
            fCls = 1
        end

        if st.show == 1 then
            if not art.banner then
                TitleBg.Bg:setAlpha( 0.85 )   -- glass plate only in the no-art fallback
            end
            if st.time > 0 then
                -- todUpgTime carries HALF-seconds (30s draft in a 4-bit field)
                if SwitchHintImg then
                    SwitchHintImg:setImage( UsingController() and art.hintSwitchPad or art.hintSwitchKbm )
                    SwitchHintImg:setAlpha( 0.9 )
                    TimeLine:setText( "RANDOM IN " .. ( st.time * 2 ) .. "s" )
                else
                    TimeLine:setText( SwitchHint() .. "   RANDOM IN " .. ( st.time * 2 ) .. "s" )
                end
                if st.time <= TIME_DANGER then
                    TimeLine:setRGB( 1.0, 0.25, 0.3 )
                else
                    TimeLine:setRGB( PAL.dim[ 1 ], PAL.dim[ 2 ], PAL.dim[ 3 ] )
                end
            else
                TimeLine:setText( "" )
                if SwitchHintImg then
                    SwitchHintImg:setAlpha( 0 )
                end
            end

            for i = 1, 4 do
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
                        card.HintImg:setImage( UsingController() and art.hintLockPad or art.hintLockKbm )
                        card.HintImg:setAlpha( 1 )
                        card.Bind:setText( "" )
                    else
                        card.Bind:setText( LockHint() )
                        card.Bind:setAlpha( 1 )
                    end
                    local w = ( card.holdHi - card.holdLo ) * ( st.hold / 15 )
                    card.HoldFill:setLeftRight( true, false, card.holdLo, card.holdLo + w )
                    card.HoldFill.Bg:setAlpha( ( st.hold > 0 ) and 0.95 or 0 )
                else
                    SetCardAlpha( card, 0.45 )
                    card.Top.Bg:setAlpha( 0.95 )
                    card.Bot.Bg:setAlpha( 0.95 )
                    card.Bind:setText( "" )
                    if card.HintImg then
                        card.HintImg:setAlpha( 0 )
                    end
                    card.HoldFill.Bg:setAlpha( 0 )
                end
            end
        elseif st.show == 2 then
            -- confirm flash: focus IS the pick while show==2
            TimeLine:setText( "" )
            if SwitchHintImg then
                SwitchHintImg:setAlpha( 0 )
            end
            for i = 1, 4 do
                local card = cards[ i ]
                if i == fCls then
                    SetCardAlpha( card, 1 )
                    card.Top.Bg:setRGB( PAL.pick[ 1 ], PAL.pick[ 2 ], PAL.pick[ 3 ] )
                    card.Bot.Bg:setRGB( PAL.pick[ 1 ], PAL.pick[ 2 ], PAL.pick[ 3 ] )
                    card.Top.Bg:setAlpha( 0.95 )
                    card.Bot.Bg:setAlpha( 0.95 )
                    if card.HintImg then
                        card.HintImg:setImage( art.hintLocked )
                        card.HintImg:setAlpha( 1 )
                        card.Bind:setText( "" )
                    else
                        card.Bind:setText( "LOCKED IN" )
                        card.Bind:setAlpha( 1 )
                    end
                    card.HoldFill.Bg:setAlpha( 0 )
                else
                    SetCardAlpha( card, 0.15 )
                    card.Bind:setText( "" )
                    if card.HintImg then
                        card.HintImg:setAlpha( 0 )
                    end
                    card.HoldFill.Bg:setAlpha( 0 )
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

    Hud.soundSet = "HUD"
    Hud:setOwner( Instance )
    Hud:setLeftRight( true, true, 0, 0 )
    Hud:setTopBottom( true, true, 0, 0 )

    local Panel = CoD.TodClassSelect.new( Hud, Instance )
    Hud:addElement( Panel )
    Hud.todClassSelect = Panel

    return Hud
end
