-- Install immediately after construction, BEFORE feature-specific close hooks.
-- Those hooks run first; this closes the remaining direct children through
-- their own close methods (including UIList item/subscription cleanup).
-- Never recurse past a child's close method or close named children twice.
CoD.TodUIOwnership = {}
local announced = false

function CoD.TodUIOwnership.Attach( owner )
    -- Existing stock developer channel, no timers, relay or UI overlay.
    if not announced then
        announced = true
        if DebugPrint then DebugPrint( "[TOD_UI_LIFETIME] rev=20260915 ownership_loaded" ) end
    end
    LUI.OverrideFunction_CallOriginalSecond( owner, "close", function( element )
        local count = 0
        local child = element:getFirstChild()
        while child do
            local nextChild = child:getNextSibling()
            child:close()
            count = count + 1
            child = nextChild
        end
        if DebugPrint then
            DebugPrint( "[TOD_UI_LIFETIME] close id=" .. tostring( element.id ) .. " remaining_children=" .. count )
        end
    end )
end
