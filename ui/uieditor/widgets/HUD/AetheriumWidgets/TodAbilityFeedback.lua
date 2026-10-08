-- Recharge follows the server's paused timers. No client clock or new art.
CoD.TodAbilityFeedback = {}
local Feedback = CoD.TodAbilityFeedback

local function Frame( owner, x, color )
    local frame = { tracks = {}, fills = {} }
    local edges = {
        { x, x + 46, 568, 570 }, { x + 44, x + 46, 570, 598 },
        { x, x + 46, 598, 600 }, { x, x + 2, 570, 598 },
    }
    for i, edge in ipairs( edges ) do
        for _, group in ipairs( { frame.tracks, frame.fills } ) do
            local image = LUI.UIImage.new()
            image:setImage( RegisterImage( "i_tod_hud_health_fill" ) )
            image:setLeftRight( true, false, edge[1], edge[2] )
            image:setTopBottom( true, false, edge[3], edge[4] )
            image:setRGB( color[1], color[2], color[3] )
            image:setAlpha( 0 )
            owner:addElement( image )
            group[i] = image
        end
    end
    frame.set = function( percent )
        local active = type( percent ) == "number" and percent >= 0
        local left = active and math.min( percent, 100 ) * 148 / 100 or 0
        for i, edge in ipairs( edges ) do
            local length = ( i == 1 or i == 3 ) and 46 or 28
            local n = math.min( math.max( left, 0 ), length )
            left = left - length
            frame.tracks[i]:setAlpha( active and 0.18 or 0 )
            frame.fills[i]:setAlpha( active and n > 0 and 0.75 or 0 )
            if i == 1 then frame.fills[i]:setLeftRight( true, false, edge[1], edge[1] + n )
            elseif i == 2 then frame.fills[i]:setTopBottom( true, false, edge[3], edge[3] + n )
            elseif i == 3 then frame.fills[i]:setLeftRight( true, false, edge[2] - n, edge[2] )
            else frame.fills[i]:setTopBottom( true, false, edge[4] - n, edge[4] ) end
        end
    end
    return frame
end

function Feedback.Attach( widget, dx )
    widget.todHealRecharge = Frame( widget, 1210 + dx, { 0.35, 0.9, 0.55 } )
    widget.todBlinkRecharge = Frame( widget, 1160 + dx, { 0.35, 0.8, 1 } )
    local pulse = LUI.UIImage.new()
    pulse:setImage( RegisterImage( "i_tod_hud_off_blink" ) )
    pulse:setLeftRight( true, false, 1165 + dx, 1189 + dx )
    pulse:setTopBottom( true, false, 572, 596 )
    pulse:setRGB( 1, 0.65, 0.15 )
    pulse:setAlpha( 0 )
    widget:addElement( pulse )
    widget.todBlinkBlocked = pulse
end

function Feedback.Progress( widget, heal, blink )
    if not widget.todHealRecharge then return end
    widget.todHealRecharge.set( widget.todFeedbackMage and heal or -1 )
    widget.todBlinkRecharge.set( widget.todFeedbackMage and blink or ( widget.todFeedbackSmash or -1 ) )
end

function Feedback.Mode( widget, mage )
    widget.todFeedbackMage = mage
    if mage then return end
    Feedback.Progress( widget, -1, -1 )
    if widget.todBlinkBlocked then
        widget.todBlinkBlocked:completeAnimation()
        widget.todBlinkBlocked:setAlpha( 0 )
    end
end

function Feedback.Blocked( widget )
    if not widget.todFeedbackMage or not widget.todBlinkBlocked then return end
    local pulse = widget.todBlinkBlocked
    pulse:completeAnimation()
    pulse:setAlpha( 0.9 )
    pulse:beginAnimation( "tod_blink_blocked", 350, false, false, CoD.TweenType.Linear )
    pulse:setAlpha( 0 )
end

function Feedback.Smash( widget, percent )
    widget.todFeedbackSmash = percent
    if widget.todFeedbackMage or not widget.todBlinkRecharge then return end
    widget.todBlinkRecharge.set( percent )
end
