-- One tint owner for local and party HP bars. The color parent animates
-- separately from the fill's health/bleedout shader animation. No UITimers.
CoD.TodHealthTint = {}
local Tint = CoD.TodHealthTint
local COLORS = {
    { 1, 0.15, 0.2 }, { 1, 0.65, 0.05 }, { 0.9, 1, 0.15 },
    { 0.15, 1, 0.3 }, { 0.15, 0.65, 1 }, { 0.75, 0.2, 1 },
}

local function Mode( widget )
    if widget.currentPlayerState == 1 then return "down" end
    local id = widget.todHealthClientNum
    if id ~= nil and id >= 0 and id <= 3 and widget.currentPlayerState ~= 2 then
        if math.floor( ( widget.todArchMask or 0 ) / ( 2 ^ id ) ) % 2 == 1 then
            return "arch"
        end
    end
    if widget.todHealthLocal and widget.todHealthAura == 1 then return "aura" end
    -- 2026-09-09: party rows read the broadcast aura mask (tod_aura_bars), the
    -- same four-player snapshot shape as the ARCHMAGE mask above; the local bar
    -- keeps its faster edge notify and falls through to the mask as well.
    if id ~= nil and id >= 0 and id <= 3 and widget.currentPlayerState ~= 2 then
        if math.floor( ( widget.todAuraMask or 0 ) / ( 2 ^ id ) ) % 2 == 1 then
            return "aura"
        end
    end
    return "normal"
end

local function Step( widget )
    if widget.todHealthClosed then return end
    if Mode( widget ) ~= "arch" then Tint.Paint( widget ); return end
    widget.todHealthPhase = ( widget.todHealthPhase or 1 ) % #COLORS + 1
    local c = COLORS[ widget.todHealthPhase ]
    widget.health_tint:beginAnimation( "tod_arch_color", 180, false, false, CoD.TweenType.Linear )
    widget.health_tint:setRGB( c[1], c[2], c[3] )
end

function Tint.Paint( widget )
    if not widget.health_tint or widget.todHealthClosed then return end
    local mode = Mode( widget )
    if widget.todHealthMode == mode then return end
    widget.todHealthMode = mode
    widget.health_tint:completeAnimation()
    if mode == "arch" then
        widget.todHealthPhase = 1
        local c = COLORS[1]
        widget.health_tint:setRGB( c[1], c[2], c[3] )
        Step( widget )
    elseif mode == "down" then
        widget.health_tint:setRGB( 1, 0.2, 0.2 )
    elseif mode == "aura" then
        widget.health_tint:setRGB( 0.21, 0.65, 0.34 )
    else
        widget.health_tint:setRGB( 1, 1, 1 )
    end
end

-- Replaces the existing addElement(fill) call, keeping the large local widget
-- below its compiled closure limit. Original fill coordinates stay unchanged.
function Tint.Attach( widget, controller, isLocal )
    widget.todHealthLocal = isLocal
    widget.todArchMask = 0
    widget.todAuraMask = 0
    local parent = LUI.UIElement.new()
    parent:setLeftRight( true, true, 0, 0 )
    parent:setTopBottom( true, true, 0, 0 )
    widget.health_tint = parent
    widget:addElement( parent )
    parent:addElement( widget.health_fill )
    parent:registerEventHandler( "transition_complete_tod_arch_color", function( element, event )
        if not event.interrupted then Step( widget ) end
    end )
    widget:linkToElementModel( widget, "clientNum", true, function( model )
        widget.todHealthClientNum = Engine.GetModelValue( model )
        Tint.Paint( widget )
    end )
    -- One subscription per widget lifetime, never per roster rebind.
    widget:subscribeToGlobalModel( controller, "PerController", "scriptNotify", function( model )
        local name = Engine.GetModelValue( model )
        if name == "tod_arch_bars" or name == "tod_aura_bars" or ( isLocal and name == "tod_mage_aura" ) then
            local data = CoD.GetScriptNotifyData( model )
            local value = data and data[1]
            if type( value ) ~= "number" then return end
            if name == "tod_arch_bars" then widget.todArchMask = value
            elseif name == "tod_aura_bars" then widget.todAuraMask = value
            else widget.todHealthAura = value end
            Tint.Paint( widget )
        end
    end )
    LUI.OverrideFunction_CallOriginalSecond( widget, "close", function( element )
        element.todHealthClosed = true
        parent:completeAnimation()
        -- Party rows may already have closed the fill. Close only children
        -- still attached, so the local UIList row also releases its fill.
        local child = parent:getFirstChild()
        while child do
            local nextChild = child:getNextSibling()
            child:close()
            child = nextChild
        end
        parent:close()
    end )
    Tint.Paint( widget )
end
