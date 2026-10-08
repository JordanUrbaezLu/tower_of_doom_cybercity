-- The teleporter's recharge readout: a countdown line and a progress bar drawn
-- INSIDE the prompt card, on top of whatever PromptDefault has written.
--
-- Numeric countdown is LUI-side on purpose: never mint a trigger hint per
-- second. SetHintString takes ONE PERMANENT engine slot per distinct string,
-- capped at 250 for the whole match, so a counting hint would burn the budget
-- and fatal the match at whatever registered next.
--
-- v19.3: THE LABEL IS THE MAP'S TYPEFACE. It was the kit's ltromatic, sitting
-- two rows above a title that had already been converted — one of the "half
-- work" surfaces the user found in play. The bar keeps its own art.
require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodGlyphText" )

CoD.TodTeleportFeedback = {}

function CoD.TodTeleportFeedback.Attach( widget, controller )
    local seconds, percent, recharging = 0, 0, false

    local label = CoD.TodGlyphText.new( {
        left = 620, right = 767, top = 488, bottom = 496,
        align = "left", set = "name", pool = 18,
        rgb = { 0.6, 0.85, 1 },
    } )
    label:setAlpha( 0 )
    widget:addElement( label )

    local track, fill = LUI.UIImage.new(), LUI.UIImage.new()
    for _, image in ipairs( { track, fill } ) do
        image:setImage( RegisterImage( "i_tod_hud_health_fill" ) )
        image:setLeftRight( true, false, 620, 767 )
        image:setTopBottom( true, false, 500, 502 )
        image:setRGB( 0.35, 0.8, 1 )
        image:setAlpha( 0 )
        widget:addElement( image )
    end

    local function paint()
        local show = recharging and seconds > 0
        label:setAlpha( show and 1 or 0 )
        track:setAlpha( show and 0.2 or 0 )
        fill:setAlpha( show and 0.8 or 0 )
        if show then
            -- No "%d"/"s" formatting punctuation: the typeface has 42 glyphs
            -- and a stray mark would be dropped silently mid-word.
            label:setText( "READY IN " .. seconds .. " SEC" )
            fill:setLeftRight( true, false, 620, 620 + 147 * percent / 100 )
        end
    end

    label:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" ), function( model )
        local hint = string.lower( Engine.GetModelValue( model ) or "" )
        recharging = string.find( hint, "teleporter", 1, true ) ~= nil
            and string.find( hint, "recharging", 1, true ) ~= nil
        paint()
    end )

    track:subscribeToGlobalModel( controller, "PerController", "scriptNotify", function( model )
        if Engine.GetModelValue( model ) ~= "tod_tp_recharge" then return end
        local data = CoD.GetScriptNotifyData( model )
        seconds = math.max( 0, math.floor( tonumber( data and data[1] ) or 0 ) )
        percent = math.min( 100, math.max( 0, tonumber( data and data[2] ) or 0 ) )
        paint()
    end )
end
