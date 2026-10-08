-- =============================================================================
-- PromptPAP.lua — the Pack-a-Punch machine.
--
-- v19.3: REBUILT ON CoD.TodPromptCard, and TWO DEAD THINGS REMOVED.
--
--   1. THE TYPEFACE. Title orbitron, description and price ltromatic. Gone.
--
--   2. `SetMode( isRepack )` IS KEPT — ZMCursorHintNew.lua:372 calls it on every
--      PaP hint, so removing it would have been a nil call that took the HUD
--      down. Its RE-PACK branch is currently unreachable: zm_cwpap.gsc gates
--      the AAT hint behind `USE_AAT_REPACK false` (v13.17, the user's own
--      order), so `isRepackHint` never sees the text that would trigger it.
--      It is left wired rather than deleted precisely because the caller is
--      live — if that flag is ever turned back on the card is already correct.
--
--   3. THE PRICE WAS HARDCODED "5000" IN LUA. That is the same fault that
--      shipped the Quick Revive card showing 1500 while the server charged 500
--      (v18.99l): a UI that carries its own copy of a server number will
--      eventually disagree with it. The cost is parsed from the hint now. The
--      5000 fallback is the figure zm_cwpap.gsc:609 actually passes, so a parse
--      miss shows the truth rather than nothing — but the hint wins.
--
-- WHAT THIS CARD DOES NOT HANDLE, and should not: PACK II / PACK III and the
-- ALREADY PACKED refusals are separate hint strings that LEAD WITH A NOUN, so
-- classifyHint routes them to PromptDefault. Only the stock machine lands here.
--
-- THE ICON IS OURS AS OF 2026-09-14 (docs/136 round 2). It was
-- `i_mtl_ui_icon_zm_ping_pack_a_punch` — the other game's kit art on our own
-- chassis, on the most-used vendor in the map, sitting beside crates and doors
-- that already wore i_tod_* icons.
-- =============================================================================

require( "ui.uieditor.widgets.HUD.ZM_CursorHint.Prompts.TodPromptCard" )

CoD.PromptPAP = InheritFrom( LUI.UIElement )

-- The authored machine price (zm_cwpap.gsc:609 passes this into the hint).
-- Used ONLY when the hint carries no parsable cost.
local PAP_COST_FALLBACK = "5000"

function CoD.PromptPAP.SetFooter( self, verb )
	CoD.TodPromptCard.SetFooter( self, verb )
end

function CoD.PromptPAP.new( menu, controller )
	local self = LUI.UIElement.new()

	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end

	self:setUseStencil( false )
	self:setClass( CoD.PromptPAP )
	self.id = "PromptPAP"
	self.soundSet = "HUD"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self:setAlpha( 0 )  -- start hidden

	CoD.TodPromptCard.Build( self, {
		icon   = "i_tod_prompt_icon_pap",
		footer = "UPGRADE",
	} )

	CoD.TodPromptCard.SetTitle( self, "PACK-A-PUNCH" )
	CoD.TodPromptCard.SetDetail( self, "UPGRADES THE WEAPON YOU HOLD", "" )
	CoD.TodPromptCard.SetPrice( self, PAP_COST_FALLBACK )

	self:subscribeToModel( Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.cursorHintText" ), function ( model )
		local hintText = Engine.GetModelValue( model )
		if not hintText or hintText == "" then
			return
		end

		local cost = string.match( hintText, "%[[Cc]ost:%s*(%d+)%]" )
		          or string.match( hintText, "[Cc]ost:%s*(%d+)" )
		          or string.match( hintText, "(%d%d%d+)" )
		CoD.TodPromptCard.SetPrice( self, cost or PAP_COST_FALLBACK )

		-- Re-resolve the bind every update: device and binds are read at the
		-- moment the line is set, not at HUD load.
		CoD.TodPromptCard.SetFooter( self, "UPGRADE" )
	end )

	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end

	return self
end

-- SetMode( isRepack ) — called by ZMCursorHintNew on every PaP hint.
--
-- ⚠️ IT HAS A LIVE CALLER. Do not delete it because the re-pack branch looks
-- dead: the FUNCTION is reached on every single Pack-a-Punch prompt, and only
-- the `true` argument is currently impossible (see the header).
function CoD.PromptPAP.SetMode( self, isRepack )
	if isRepack then
		CoD.TodPromptCard.SetTitle( self, "RE-PACK" )
		CoD.TodPromptCard.SetDetail( self, "ADD AN ALTERNATE AMMO TYPE", "" )
		CoD.TodPromptCard.SetFooter( self, "RE-PACK" )
		-- No price written here: the hint subscription owns the number, and a
		-- literal would be the same fault this file just removed.
		return
	end
	CoD.TodPromptCard.SetTitle( self, "PACK-A-PUNCH" )
	CoD.TodPromptCard.SetDetail( self, "UPGRADES THE WEAPON YOU HOLD", "" )
	CoD.TodPromptCard.SetFooter( self, "UPGRADE" )
end

return CoD.PromptPAP
