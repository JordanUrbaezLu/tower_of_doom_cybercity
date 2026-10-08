-- Aetherium Pause Menu (Custom Design)

require("ui.uieditor.widgets.StartMenu.AetheriumMenuButton")
require("ui.uieditor.widgets.StartMenu.AetheriumSmallButton")
-- [tod v17.24] the ONE writer for a bind name inside the pale keycap, shared
-- with tod_upgrade.lua and tod_class_select.lua. See its header.
--
-- [tod v17.30] AND IT IS FAIL-SAFED, because this file is THE PAUSE MENU. A
-- require that throws — the rawfile missing from the .ff, a Lua error inside the
-- widget or inside TodGlyphRow beneath it — aborts this entire file, silently,
-- and a player who cannot open the pause menu cannot leave the match. Risking
-- that on an unguarded require, for the sake of a key name drawn on a legend, is
-- not a trade worth making.
--
-- So: pcall the require, and route the call site through TodKeycapMake, which
-- degrades to the plain LUI text this menu already builds. THE STUB IS
-- DELIBERATELY LOCAL AND TWINNED across the three menus that use the widget — a
-- fail-safe that lives inside the thing it guards against is not a fail-safe,
-- and that is the one case where a twin beats a shared file.
pcall(require, "ui.uieditor.widgets.HUD.AetheriumWidgets.TodKeycap")

-- [tod v19.58] THE MAP'S TYPEFACE ON EVERY PAUSE-MENU LINE (user 2026-09-27:
-- "replace all the text on the screen like pause menu descriptions ... add the
-- typography for the map. It increases consistency"). TodLabel() is a drop-in
-- for LUI.UIText.new() - same setLeftRight/setTopBottom/setText/setRGB/
-- setAlignment/setScale calls - drawn from the baked glyph sheets. FAIL-SAFED
-- like TodKeycap above (this is the pause menu): if the widget cannot load, the
-- line falls back to the engine text it always was. Lines that carry a
-- [{+bind}] token stay engine text on purpose: the engine draws the live key or
-- button picture there, which no glyph can.
pcall(require, "ui.uieditor.widgets.HUD.AetheriumWidgets.TodGlyphText")
local function TodLabel()
	if CoD.TodGlyphText and CoD.TodGlyphText.Label then
		local ok, e = pcall(CoD.TodGlyphText.Label)
		if ok and e then
			return e, true
		end
	end
	return LUI.UIText.new(), false
end

-- [tod v19.59] KEYBOARD KEYS IN THE TYPEFACE. An act line with a [{+bind}]
-- token used to stay engine text whole, so the Mage rows read as small
-- mixed-case lines beside the glyph rows (user screenshot 2026-09-27). On a
-- keyboard the key is a NAME, so resolve it the way the Mage tile badge does
-- (AetheriumLoadout TutKey, docs/145: GetKeyBindingLocalizedString, keep the
-- first key before " OR ") and draw the whole line in glyphs. A controller
-- gets a button PICTURE only the engine can draw, so it keeps engine text, as
-- does any key name the lookup cannot resolve cleanly. Returns text, glyphOk.
--
-- ALTERNATE COMMANDS (user screenshot 2026-09-27: "PRESS UNBOUND TO
-- ACTIVATE"). The stock keyboard config binds aim as MOUSE2 "+toggleads_throw";
-- "+speed_throw" is bound only on the pad, so its lookup answers "Unbound".
-- The server reads AdsButtonPressed(), which both commands drive, so the key
-- to show is whichever of them is bound. "Unbound" is never a key name.
local TOD_KEY_ALTS = {
	["+speed_throw"] = { "+speed_throw", "+toggleads_throw" },
}
local function TodActKeys(controller, s)
	if not string.find(s, "[{", 1, true) then
		return s, true
	end
	local okPad, pad = pcall(function() return Engine.LastInput_Gamepad(controller) end)
	if not okPad or pad then
		return s, false
	end
	local failed = false
	local out = string.gsub(s, "%[%{(.-)%}%]", function(command)
		local raw = ""
		for _, cmd in ipairs(TOD_KEY_ALTS[command] or { command }) do
			local ok, r = pcall(Engine.GetKeyBindingLocalizedString, controller, cmd, 0, false, false)
			r = (ok and type(r) == "string") and r or ""
			r = string.gsub(r, "%^%d", "")
			r = string.gsub(r, "[%c]", "")
			local separator = string.find(r, "%s+[Oo][Rr]%s+")
			if separator then r = string.sub(r, 1, separator - 1) end
			r = string.gsub(r, "^%s+", "")
			r = string.gsub(r, "%s+$", "")
			if r ~= "" and string.upper(r) ~= "UNBOUND" then
				raw = r
				break
			end
		end
		if string.find(raw, "[{", 1, true) then
			failed = true
			return nil
		end
		for i = 1, #raw do
			if string.byte(raw, i) > 126 then
				failed = true
				return nil
			end
		end
		if raw == "" then
			failed = true
			return nil
		end
		-- a name the typeface would drop characters from (a bracket, a
		-- backtick ...) is drawn by the engine instead: a wrong key is worse
		-- than an engine-font key
		if CoD.TodGlyphText and CoD.TodGlyphText.Sanitize then
			local drawn = string.gsub(CoD.TodGlyphText.Sanitize(raw), "[^%w]", "")
			if drawn ~= string.gsub(string.upper(raw), "[^%w]", "") then
				failed = true
				return nil
			end
		end
		return string.upper(raw)
	end)
	if failed then
		return s, false
	end
	return out, true
end

-- [tod v19.60] "PRESS <KEY> TO <VERB> - <WHAT IT DOES>" (user 2026-09-27:
-- "Abilities should say Press <key> to use - <Description> ... For controller
-- its fine but the image needs to be 25% larger").
--
-- The line is split at its one bind token into three pieces laid end to end:
--   PRESS            the map's typeface
--   <key>            the typeface (yellow) when the keyboard name resolves
--                    (TodActKeys); otherwise ENGINE text, the only renderer for
--                    a button picture - drawn TOD_PAD_KEY_GROW taller on a pad
--   TO CAST - ...    the map's typeface
-- The engine key's width comes from UIText:getTextWidth(), the stock call
-- ScaleWidgetToLabel makes straight after a setText (uieditor/actions.lua in
-- the T7 dump); if it answers 0 an estimate stands in. All glyph pieces share
-- ONE cap: a line too long for the column shrinks as a whole, never the tail
-- alone.
--
-- ROOM FOR THE BIGGER BUTTON: it stays centred on the act line, which is also
-- the middle of the gap between the effect line's baseline and the next row's
-- plate (normal 45.2..59, compact 39.2..50). 1.25x the old box is 17.5 / 15
-- units, so its BOX edges pass those bounds by ~2; the button art inside an
-- engine text box is drawn smaller than the box (the old 1.0x box already
-- crossed the effect baseline and read clean). Judged in game.
local TOD_PAD_KEY_GROW = 1.25
local TOD_KEY_RGB = { 1, 0.84, 0.24 }     -- the ^3 yellow the engine key has always worn

-- DEV DIAGNOSTIC (docs/145 left keyboard key resolution UNPROVEN in game).
-- Once per command per session the raw lookup result goes to the server on the
-- proven menu-response lane (the scoreboard's tod_sb); _tod_upgrade_ui::
-- scoreboard_watch prints it as [TOD_KEYS] under tod_dev. Byte values, so a
-- control byte or a deferred token is visible in the log.
local TodKeyDiagSent = {}
local function TodKeyDiag(controller, tok)
	local command = string.match(tok, "%[%{(.-)%}%]")
	if not command or TodKeyDiagSent[command] then
		return
	end
	TodKeyDiagSent[command] = true
	pcall(function()
		local okPad, pad = pcall(function() return Engine.LastInput_Gamepad(controller) end)
		local ok, raw = pcall(Engine.GetKeyBindingLocalizedString, controller, command, 0, false, false)
		local isStr = ok and type(raw) == "string"
		local bytes = {}
		if isStr then
			for i = 1, math.min(#raw, 24) do
				bytes[#bytes + 1] = tostring(string.byte(raw, i))
			end
		end
		local _, glyphOk = TodActKeys(controller, tok)
		Engine.SendMenuResponse(controller, "StartMenu_Main", "tod_keydiag|" .. command
			.. "|pad=" .. ((okPad and pad) and "1" or "0")
			.. "|call=" .. (ok and "1" or "0")
			.. "|type=" .. type(raw)
			.. "|len=" .. (isStr and #raw or -1)
			.. "|glyph=" .. (glyphOk and "1" or "0")
			.. "|bytes=" .. table.concat(bytes, "."))
	end)
end

local function TodActLine(owner, controller, act, left, right, top, bottom, glyphScale, engineScale, rgb)
	local tokS, tokE = string.find(act, "%[%{.-%}%]")
	local first, glyph = TodLabel()
	first:setTTF("fonts/orbitron.ttf")
	first:setRGB(rgb[1], rgb[2], rgb[3])
	first:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	first:setTopBottom(true, false, top, bottom)
	if not tokS or not glyph then
		-- no key, or no typeface: one line, exactly as before
		first:setLeftRight(true, false, left, right)
		first:setText(glyph and act or Engine.Localize(act))
		first:setScale(glyph and glyphScale or engineScale)
		owner:addElement(first)
		return
	end

	local tok = string.sub(act, tokS, tokE)
	local function trim(x)
		x = string.gsub(x, "%^%d", "")
		x = string.gsub(x, "^%s+", "")
		return (string.gsub(x, "%s+$", ""))
	end
	local before = trim(string.sub(act, 1, tokS - 1))
	local after = trim(string.sub(act, tokE + 1))
	TodKeyDiag(controller, tok)

	local h = bottom - top
	local cap = h * 0.80 * glyphScale
	local rest = TodLabel()
	local lw = (before ~= "") and first:measure(before, cap) or 0
	local rw = (after ~= "") and rest:measure(after, cap) or 0

	local keyName, keyGlyph = TodActKeys(controller, tok)
	local keyEl, kw
	if keyGlyph then
		keyEl = TodLabel()
		kw = keyEl:measure(keyName, cap)
	else
		local okPad, pad = pcall(function() return Engine.LastInput_Gamepad(controller) end)
		local isPad = (okPad and pad) and true or false
		local kh = h * (isPad and TOD_PAD_KEY_GROW or 1)
		local kt = top + (h - kh) / 2
		keyEl = LUI.UIText.new()
		keyEl:setLeftRight(true, false, left, right)
		keyEl:setTopBottom(true, false, kt, kt + kh)
		keyEl:setTTF("fonts/orbitron.ttf")
		keyEl:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
		keyEl:setText(Engine.Localize("^3" .. tok .. "^7"))
		local okW, tw = pcall(function() return keyEl:getTextWidth() end)
		tw = okW and tonumber(tw) or nil
		if tw and tw > 0 then
			kw = tw
		else
			kw = isPad and (kh * 1.3) or (h * 5)
		end
	end

	-- one cap for every glyph piece; the whole line shrinks together if needed.
	-- EDGE keeps a glyph's drawn rect (slightly wider than its advance) inside
	-- the column - test_pause_text_all measured the overhang at ~1.7.
	local EDGE = 3
	right = right - EDGE
	local gap = cap * 0.45
	local glyphW = lw + rw + (keyGlyph and kw or 0)
	local fixedW = (keyGlyph and 0 or kw) + ((before ~= "") and gap or 0) + ((after ~= "") and gap or 0)
	local room = (right - left) - fixedW
	if glyphW > room and glyphW > 0 and room > 0 then
		local k = room / glyphW
		cap, lw, rw = cap * k, lw * k, rw * k
		if keyGlyph then
			kw = kw * k
		end
	end

	local x = left
	if before ~= "" then
		first:setLeftRight(true, false, x, x + lw + 2)
		first:setCap(cap)
		first:setText(before)
		owner:addElement(first)
		x = x + lw + gap
	else
		first:close()
	end
	if keyGlyph then
		keyEl:setLeftRight(true, false, x, x + kw + 2)
		keyEl:setTopBottom(true, false, top, bottom)
		keyEl:setRGB(TOD_KEY_RGB[1], TOD_KEY_RGB[2], TOD_KEY_RGB[3])
		keyEl:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
		keyEl:setCap(cap)
		keyEl:setText(keyName)
	else
		keyEl:setLeftRight(true, false, x, x + kw + 4)
	end
	owner:addElement(keyEl)
	x = x + kw + gap
	if after ~= "" then
		rest:setLeftRight(true, false, x, right)
		rest:setTopBottom(true, false, top, bottom)
		rest:setRGB(rgb[1], rgb[2], rgb[3])
		rest:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
		rest:setCap(cap)
		rest:setText(after)
		owner:addElement(rest)
	else
		rest:close()
	end
end

-- [tod v18.32] IS THIS EXPANSION A BUTTON PICTURE? Twin of the test in the two
-- card menus and of CoD.TodKeycap.IsPadGlyph, which is the canonical copy and
-- carries the argument. It has to be twinned HERE for the same reason the stub
-- below is: a guard that lives inside the widget cannot cover the widget being
-- absent, and with the widget absent the stub's own fallback would happily set
-- the engine's LT / RT / A icon as text inside a pale keycap -- the exact
-- failure in the user's 2026-09-08 screenshot.
local function TodPadGlyph(tok)
	local s = Engine.Localize(tok) or ""
	s = s:gsub("%^%d", "")
	if s == "" then
		return false
	end
	-- [tod v18.48] HIGH BYTES ONLY. v18.47 also matched b < 32 and every
	-- keyboard player was drawn as a controller -- something in the KEYBOARD
	-- expansion carries a low control byte. And this is no longer a DEVICE
	-- test: it decides only whether a string may be drawn inside a keycap, and
	-- is consulted after the typeface has already failed to draw it.
	for i = 1, #s do
		if string.byte(s, i) > 126 then
			return true
		end
	end
	return false
end
local function TodKeycapMake(owner, text)
	if CoD.TodKeycap then
		return CoD.TodKeycap.make(owner, text)
	end
	return {
		hide = function ()
			if text then
				text:setAlpha(0)
			end
		end,
		paint = function (capL, capT, capW, capH, token, alpha)
			if not text then
				return ""
			end
			-- never a button picture inside a keycap
			if TodPadGlyph(token) then
				text:setAlpha(0)
				return nil
			end
			local cy = capT + capH * 0.435
			text:setLeftRight(true, false, capL + 6, capL + capW - 6)
			text:setTopBottom(true, false, cy - 8, cy + 8)
			text:setScale(1)
			text:setText(Engine.Localize(token))
			text:setAlpha((alpha == nil) and 1 or alpha)
			return ""
		end,
	}
end

-- Configuration
local ShowSignatures = true  -- Set to false to hide signature images

-- Third Person Toggle Functions
local GetThirdPersonLabel = function(controller)
	local thirdPersonModel = Engine.GetModel(Engine.GetModelForController(controller), "ui_menu_option_third_person")
	local thirdPerson = Engine.GetModelValue(thirdPersonModel)
	
	if thirdPerson == nil then
		Engine.SetModelValue(thirdPersonModel, false)
		thirdPerson = false
	end
	
	return thirdPerson and "Switch To First Person" or "Switch To Third Person"
end

local ToggleThirdPerson = function(self, element, controller, actionParam, menu)
	local thirdPersonModel = Engine.CreateModel(Engine.GetModelForController(controller), "ui_menu_option_third_person")
	local newValue = not Engine.GetModelValue(thirdPersonModel)
	Engine.SetModelValue(thirdPersonModel, newValue)
	Engine.SendMenuResponse(controller, "StartMenu_Main", "ui_menu_option_third_person|" .. (newValue and "1" or "0"))
	
	-- Update button list to show new label
	if menu.ButtonList then
		menu.ButtonList:updateDataSource()
	end
end

-- [tod] GAME-OVER MODE (v9.24, port of map 1's retry-on-death v3): on a wipe (or
-- the finale's win), _tod_gameover.gsc re-enables the ingame menu (stock disables
-- it at end_game), force-opens THIS menu on every player and sets the host-side
-- dvar tod_go_active=1. In that mode the button list is exactly two entries —
-- Restart Map / End Game — navigated with the menu's own native up/down +
-- confirm. The dvar is host-machine-only, so co-op peers get the normal pause
-- list (Leave Game works there; restarting is the host's call). GSC scrubs the
-- dvar at init, so a mid-run pause menu is never in this mode. Every read is
-- pcall'd through a try-list (the dvar-read signature differs by build).
local TodDvarIsOne = function(controller, name)
	local tries = {
		function() return Engine.DvarString(controller, name) end,
		function() return Engine.DvarString(name) end,
		function() return Engine.GetDvarString(name) end,
	}
	for i = 1, #tries do
		local ok, r = pcall(tries[i])
		if ok and r ~= nil and tostring(r) == "1" then
			return true
		end
	end
	return false
end
local TodGoActive = function(controller)
	return TodDvarIsOne(controller, "tod_go_active")
end
-- [tod 2026-09-24] tod_go_won: _tod_gameover sets it beside tod_go_active after
-- an escape or a conquered spire, so the menu stops saying "Game Over" on a win.
local TodGoWon = function(controller)
	return TodDvarIsOne(controller, "tod_go_won")
end

-- [tod 2026-10-01] SCOPE CORRECTION: the server request below is now ONLY for a
-- host with a teammate on ANOTHER machine. Solo and split-screen use the kit's
-- own console restart / leave again (TodLocalParty, TodKitRestart, TodKitLeave):
-- v19.63 moved EVERY restart onto the server and the solo game then froze on a
-- paused server (docs/167 item 9). The co-op reasoning below still stands.
--
-- [tod v19.63] RESTART / END GAME ARE SERVER REQUESTS, AND THE PARTY FACTS COME
-- FROM THE SERVER (Workshop: Tixy 2026-09-07 "Fix restart level button please,
-- it kicks the other player out in coop!"; Biffbrooks11 2026-09-29 "When my
-- buddy and I die, the restart button doesn't work leaving hitting 'End Game' as
-- our only option. This disconnects us from each other.").
--
-- Engine.Exec(controller, "map_restart") ran the console command on the PRESSING
-- machine: the host reloaded alone and the peer fell to the main menu. v19.16
-- answered by hiding Restart in co-op, which IS the second report. The button
-- now sends "tod_go|restart" / "tod_go|end" on the StartMenu_Main menu-response
-- lane (the scoreboard's tod_sb lane, proven in the user's logs) and
-- _tod_gameover.gsc::go_menu_watch acts on the HOST's request with stock's own
-- server calls: map_restart( true ) keeps every client connected (the MP round
-- switch), ExitLevel( false ) returns the whole party to the lobby together.
-- The menu is CLOSED AND THE GAME UNPAUSED first (TodGoClose, 2026-10-01 - plain
-- GoBack closed the menu but left a solo game paused): a paused server
-- processes nothing.
--
-- WHO SEES RESTART: the host. _tod_gameover::party_push sends "tod_party"
-- ( humans, i_am_host, game_over_menu_up ) to EVERY client on every party change
-- and every 5 s; AetheriumHud caches it as CoD.TodParty. The tod_party /
-- tod_go_active dvars stay as the FALLBACK and are host-machine only, so a
-- readable numeric tod_party itself proves this machine is the host. A client
-- that has neither yet is treated as the host (solo is the common case; a wrong
-- "host" costs one ignored request, a wrong "peer" hides a real button).
--
-- ⚠️ Engine.GetPlayerCount() is still not read here - see the Leave Game lane
-- below for why (it does not report solo; two shipped bugs came from trusting it).
local TodDvarNumber = function(controller, name)
	local tries = {
		function() return Engine.DvarString(controller, name) end,
		function() return Engine.DvarString(name) end,
		function() return Engine.GetDvarString(name) end,
	}
	for i = 1, #tries do
		local ok, r = pcall(tries[i])
		if ok and r ~= nil then
			local n = tonumber(tostring(r))
			if n ~= nil then
				return n
			end
		end
	end
	return nil
end
-- -> humans, i_am_host (nil = unknown), game_over_menu_up
-- [tod 2026-10-01] PER CONTROLLER FIRST (docs/167 item 10, "Restart is still
-- completely missing from the split-screen UI"). Every local player's HUD runs
-- in this ONE client Lua VM, and each wrote its own tod_party facts into the
-- single CoD.TodParty: on a split-screen machine the guest's host=0 landed last
-- and hid Restart on BOTH screens. AetheriumHud now also files the facts under
-- the controller that received them (CoD.TodPartyBy), and this reads that copy.
-- CoD.TodParty stays as the any-controller fallback for a HUD from before it.
local TodParty = function(controller)
	local p = nil
	if type(CoD.TodPartyBy) == "table" and controller ~= nil then
		p = CoD.TodPartyBy[controller]
	end
	if type(p) ~= "table" then
		p = CoD.TodParty
	end
	if type(p) == "table" and type(p.n) == "number" then
		return p.n, (p.host == true), (p.go == true), p.localOnly
	end
	local n = TodDvarNumber(controller, "tod_party")
	if n ~= nil then
		return n, true, TodDvarIsOne(controller, "tod_go_active"), nil
	end
	return nil, nil, false, nil
end
-- [tod 2026-10-01] IS EVERY HUMAN IN THIS GAME AT THIS MACHINE? (solo or
-- split-screen). Then Restart / End Game are the Aetherium kit's own console
-- commands, exactly as the kit shipped them (TodKitRestart / TodKitLeave below):
-- the console command runs on THIS machine, which here is the whole game, and it
-- worked for months - the user: "the stock aetherium HUD had this perfectly set
-- up ... once we started tweaking i think we got lost in our own code". Only a
-- host with a teammate on ANOTHER machine needs the server request, because the
-- console command reloads the host alone and drops that teammate (Tixy, Sep 7).
-- Order: the server's own answer for this controller (tod_party host value 2 =
-- all local, 1 = a remote teammate), then the host-machine dvar
-- tod_party_remote (_tod_main::party_dvar_watch writes it on its first tick, at
-- level start, before any HUD exists - so a solo / split-screen machine always
-- has it), then "no": with neither, this is a teammate's machine in its first
-- seconds (a SetDvar never reaches another machine), and the server request is
-- the lane a non-host cannot act on - the server ignores it.
local TodLocalParty = function(controller)
	local _, _, _, localOnly = TodParty(controller)
	if localOnly ~= nil then
		return localOnly == true
	end
	local remote = TodDvarNumber(controller, "tod_party_remote")
	if remote ~= nil then
		return remote <= 0
	end
	return false
end
local TodGoActive = function(controller)
	local _, _, go = TodParty(controller)
	if go then
		return true
	end
	return TodDvarIsOne(controller, "tod_go_active")
end
-- [tod 2026-09-24] tod_go_won: _tod_gameover sets it beside tod_go_active after
-- an escape or a conquered spire, so the menu stops saying "Game Over" on a win.
-- A peer reads the end-screen kind the scoreboard cached (2 = a won ending).
local TodGoWon = function(controller)
	if TodDvarIsOne(controller, "tod_go_won") then
		return true
	end
	local e = CoD.TodEndScreen
	return type(e) == "table" and e.kind == 2
end
local TodCoop = function(controller)
	local n = TodParty(controller)
	return n ~= nil and n > 1
end
local TodIsHost = function(controller)
	local _, host = TodParty(controller)
	if host == nil then
		return true
	end
	return host
end
-- [tod 2026-10-01] TWO LANES, ONE REQUEST (user's co-op test: "restart map with
-- another player does nothing" - the game-over menu's response never reached the
-- server; stock's end_game marks the match ended and menu responses stop there).
-- 1. dvar tod_go_request on THIS machine. On the host's machine the menu and the
--    server share one dvar table (server -> menu: tod_go_active since v9.24;
--    menu -> server: tod_go_restart_mark, the same test's log), and
--    _tod_gameover::go_request_watch reads it every 0.1 s - mid-game AND at game
--    over. A teammate's machine runs no server: only the host can act, by design.
-- 2. the menu response, as before - the backup; the server acts once (latch).
local TodGoRequest = function(controller, what)
	pcall(function()
		Engine.SetDvar("tod_go_request", what)
	end)
	pcall(function()
		Engine.SendMenuResponse(controller, "StartMenu_Main", "tod_go|" .. what)
	end)
end
-- [tod 2026-10-01] CLOSE *AND UNPAUSE* BEFORE A SERVER REQUEST (docs/167 item 9:
-- "Restarts freeze on a single frame while allowing menu navigation ... randomly
-- 1 minute later it might restart").
--
-- v19.63 closed the menu with plain GoBack. GoBack only pops the menu stack: in
-- SOLO the pause menu has the game PAUSED (cl_paused 1) and GoBack never clears
-- it, so the tod_go request sat unprocessed on a paused server - one frozen frame
-- with a live UI - until something ELSE unpaused (reopening the menu and leaving
-- it with Back / Start / Return To Game runs StartMenuGoBack, which does). Then
-- the queued restart finally ran: the "random minute later". Co-op never pauses,
-- which is why the online test passed.
--
-- Stock's own restart / leave popups clear cl_paused FIRST and then close through
-- StartMenuGoBack (unpause + SetActiveMenu NONE + pop + clear saved state). This
-- does the same, in that order, before every host request.
local TodGoClose = function(menu, controller)
	Engine.SetDvar("cl_paused", 0)
	StartMenuGoBack(menu, controller)
end
-- [tod 2026-10-01] The cached "game-over menu is up" flag must not outlive this
-- level: the Lua VM survives a restart, and the next game's pause menu reads it.
local TodClearGoFlag = function()
	if type(CoD.TodPartyBy) == "table" then
		for _, p in pairs(CoD.TodPartyBy) do
			if type(p) == "table" then
				p.go = false
			end
		end
	end
	if type(CoD.TodParty) == "table" then
		CoD.TodParty.go = false
	end
end
-- THE AETHERIUM KIT'S OWN RESTART, VERBATIM (upstream AetheriumStartMenu.lua
-- "Restart Level"): close the menu, run the console map_restart on this machine.
-- Used only when every human is at this machine (TodLocalParty).
local TodKitRestart = function(menu, controller)
	TodClearGoFlag()
	-- The new level logs that this restart came back (_tod_gameover::
	-- restart_back_log, [TOD_GAMEOVER] RESTART_BACK / RESTART_UP lane=kit).
	Engine.SetDvar("tod_go_restart_mark", "kit")
	-- Close menu first
	GoBack(menu, controller)
	-- Restart the map
	Engine.Exec(controller, "map_restart")
end
-- THE KIT'S OWN LEAVE, VERBATIM (upstream "Leave Game"): the solo / split-screen
-- End Game and every non-host's exit.
local TodKitLeave = function(menu, controller)
	menu:processEvent({
		name = "close_all_ingame_menus",
		controller = controller
	})
	Engine.SendMenuResponse(controller, "popup_leavegame", "endround")
	Engine.SetDvar("cl_paused", 0)
	Engine.Exec(controller, "disconnect")
end
-- [tod 2026-10-01] THE SERVER LANE, IN THIS ORDER: the request (both lanes, see
-- TodGoRequest), the cached game-over flag, THEN close and unpause. Request first
-- so nothing in closing the menu can stop it - the server-opened game-over menu
-- had never been pressed on this lane before the 2026-10-01 test - and a paused
-- server simply reads the dvar the moment TodGoClose unpauses it. Declared BELOW
-- every helper it calls (a Lua closure above a `local` binds a nil global).
local TodGoServer = function(menu, controller, what)
	TodGoRequest(controller, what)
	if what == "restart" then
		TodClearGoFlag()
	end
	pcall(TodGoClose, menu, controller)
end

-- DataSource for small top buttons
DataSources.AetheriumSmallMenuButtons = ListHelper_SetupDataSource("AetheriumSmallMenuButtons", function(controller)
	local buttons = {}

	-- Graphics Settings
	table.insert(buttons, {
		models = {
			icon = "i_mtl_icon_ftueftus_audio_config_tv",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Graphics_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Graphics", controller, "", "")
				end
			end
		}
	})

	-- Sound/Audio Settings
	table.insert(buttons, {
		models = {
			icon = "i_mtl_image_2d767ba54c664e54",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Sound_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Sound", controller, "", "")
				end
			end
		}
	})

	-- Keybinds/Controls Settings
	table.insert(buttons, {
		models = {
			icon = "i_mtl_firing_range_input_settings_kbm",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Controls_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Controls", controller, "", "")
				end
			end
		}
	})

	-- All Options (Show inline options)
	table.insert(buttons, {
		models = {
			icon = "i_mtl_ui_menu_codhq_icon_settings",
			action = function(self, element, controller, actionParam, menu)
				-- Same action as Game Settings button
				menu.ButtonList:completeAnimation()
				menu.SmallButtonList:completeAnimation()
				menu.OptionsList:completeAnimation()
				menu.OptionsHeaderText:completeAnimation()
				menu.PauseMenuText:completeAnimation()
				
				menu.ButtonList:setAlpha(0)
				menu.SmallButtonList:setAlpha(0)
				menu.PauseMenuText:setAlpha(0)
				menu.OptionsList:setAlpha(1)
				menu.OptionsHeaderText:setAlpha(1)
				menu.OptionsList:processEvent({name = "gain_focus", controller = controller})
			end
		}
	})

	return buttons
end, true)

-- DataSource for menu buttons
DataSources.AetheriumStartMenuButtons = ListHelper_SetupDataSource("AetheriumStartMenuButtons", function(controller)
	local buttons = {}

	-- [tod] game-over mode: Restart Map for the HOST machine, End Game for
	-- everyone. No "Return To Game" — there is no game to return to.
	-- [2026-10-01] Solo / split-screen (every human at this machine): the kit's
	-- own map_restart / disconnect, exactly as before v19.63. A host with a
	-- teammate on another machine: the server request (keeps that teammate).
	if TodGoActive(controller) then
		if TodIsHost(controller) then
			table.insert(buttons, {
				models = {
					displayText = "Restart Map",
					action = function(self, element, controller, actionParam, menu)
						if TodLocalParty(controller) then
							TodKitRestart(menu, controller)
							return
						end
						TodGoServer(menu, controller, "restart")
					end
				}
			})
		end
		table.insert(buttons, {
			models = {
				displayText = "End Game",
				action = function(self, element, controller, actionParam, menu)
					-- Online co-op host: stock's ExitLevel from the server, the
					-- whole party back to the lobby together. Everyone else:
					-- the kit's own leave.
					if TodIsHost(controller) and not TodLocalParty(controller) then
						TodGoServer(menu, controller, "end")
						return
					end
					TodKitLeave(menu, controller)
				end
			}
		})
		return buttons
	end

	table.insert(buttons, {
		models = {
			displayText = "Return To Game",
			action = function(self, element, controller, actionParam, menu)
				RefreshLobbyRoom(menu, controller)
				StartMenuGoBack(menu, controller)
			end
		}
	})

	-- [tod v19.63] HOST MACHINE ONLY (see TodIsHost above). A peer on another
	-- machine does not get the button - restarting is the host's call; Leave
	-- Game below is the peer's exit.
	-- [2026-10-01] Solo / split-screen: the kit's own restart, verbatim
	-- (TodKitRestart). A teammate on another machine: the server restart, after
	-- closing AND unpausing the menu (TodGoClose).
	if TodIsHost(controller) then
		table.insert(buttons, {
			models = {
				displayText = "Restart Level",
				action = function(self, element, controller, actionParam, menu)
					if TodLocalParty(controller) then
						TodKitRestart(menu, controller)
						return
					end
					TodGoServer(menu, controller, "restart")
				end
			}
		})
	end

	table.insert(buttons, {
		models = {
			displayText = GetThirdPersonLabel(controller),
			action = ToggleThirdPerson
		}
	})

	table.insert(buttons, {
		models = {
			displayText = "Game Settings",
			action = function(self, element, controller, actionParam, menu)
				-- Instantly switch to options
				menu.ButtonList:completeAnimation()
				menu.SmallButtonList:completeAnimation()
				menu.OptionsList:completeAnimation()
				menu.OptionsHeaderText:completeAnimation()
				menu.PauseMenuText:completeAnimation()
				
				menu.ButtonList:setAlpha(0)
				menu.SmallButtonList:setAlpha(0)
				menu.PauseMenuText:setAlpha(0)
				menu.OptionsList:setAlpha(1)
				menu.OptionsHeaderText:setAlpha(1)
				menu.OptionsList:processEvent({name = "gain_focus", controller = controller})
			end
		}
	})

	-- HUD Settings and Social buttons removed

	table.insert(buttons, {
		models = {
			displayText = "Leave Game",
			action = function(self, element, controller, actionParam, menu)
				-- Close all menus first
				menu:processEvent({
					name = "close_all_ingame_menus",
					controller = controller
				})
				
				-- Send menu response for proper cleanup
				Engine.SendMenuResponse(controller, "popup_leavegame", "endround")
				
				-- ⚠️ THIS BRANCH IS INERT AND MUST NOT BE CITED AS PROOF OF
				-- ANYTHING (2026-09-07). Both arms are the same three lines, so
				-- Engine.GetPlayerCount()'s return value has never changed a
				-- single behaviour here — which means a WRONG value is invisible
				-- in this file. Two separate changes read this code as evidence
				-- that the call works and shipped bugs on it: the solo Quick
				-- Revive price (quoted 1500 in solo from 2026-08-23) and the
				-- co-op restart gate (hid RESTART LEVEL in SOLO, 2026-09-07).
				-- It does not report solo. If you need the party size, read the
				-- `tod_party` dvar that _tod_main::party_dvar_watch publishes —
				-- see TodCoop at the top of this file.
				--
				-- Kept rather than deleted only because it is upstream kit code
				-- and deleting it changes nothing; the comment is the point.
				Engine.SetDvar("cl_paused", 0)
				Engine.Exec(controller, "disconnect")
			end
		}
	})

	return buttons
end, true)

-- DataSource for options buttons (shown when Game Settings is clicked)
DataSources.AetheriumOptionsButtons = ListHelper_SetupDataSource("AetheriumOptionsButtons", function(controller)
	local options = {}
	
	table.insert(options, {
		models = {
			displayText = "Graphics",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Graphics_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Graphics", controller, "", "")
				end
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Audio",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Sound_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Sound", controller, "", "")
				end
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Controls",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Controls_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Controls", controller, "", "")
				end
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Voice & Muting",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_Voice_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_Voice", controller, "", "")
				end
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Network",
			action = function(self, element, controller, actionParam, menu)
				OpenPopup(menu, "StartMenu_Options_Network", controller, "", "")
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Safe Area",
			action = function(self, element, controller, actionParam, menu)
				OpenPopup(menu, "StartMenu_Options_Graphics_SafeArea", controller, "", "")
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Content Filter",
			action = function(self, element, controller, actionParam, menu)
				if IsPC() then
					OpenPopup(menu, "StartMenu_Options_GraphicContent_PC", controller, "", "")
				else
					OpenPopup(menu, "StartMenu_Options_GraphicContent", controller, "", "")
				end
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Credits",
			action = function(self, element, controller, actionParam, menu)
				OpenPopup(menu, "Credit_Fullscreen", controller, "", "")
			end
		}
	})
	
	table.insert(options, {
		models = {
			displayText = "Back",
			action = function(self, element, controller, actionParam, menu)
				-- Instantly hide options and show main menu
				menu.OptionsList:completeAnimation()
				menu.OptionsHeaderText:completeAnimation()
				menu.ButtonList:completeAnimation()
				menu.SmallButtonList:completeAnimation()
				menu.PauseMenuText:completeAnimation()
				
				menu.OptionsList:setAlpha(0)
				menu.OptionsHeaderText:setAlpha(0)
				menu.ButtonList:setAlpha(1)
				menu.SmallButtonList:setAlpha(1)
				menu.PauseMenuText:setAlpha(1)
				menu.ButtonList:processEvent({name = "gain_focus", controller = controller})
			end
		}
	})
	
	return options
end, true)

local PostLoadFunc = function(self, controller)
	self:registerEventHandler("menu_opened", function(element, event)
		Engine.SetUIActive(controller, true)
		
		-- Hide HUD when pause menu opens
		local controllerModel = Engine.GetModelForController(controller)
		local hudVisibilityModel = Engine.GetModel(controllerModel, "UIVisibility.Visibility")
		if hudVisibilityModel then
			Engine.SetModelValue(hudVisibilityModel, 0)
		end
		
		return true
	end)
	
	self:registerEventHandler("menu_closed", function(element, event)
		Engine.SetUIActive(controller, false)
		
		-- Show HUD when pause menu closes
		local controllerModel = Engine.GetModelForController(controller)
		local hudVisibilityModel = Engine.GetModel(controllerModel, "UIVisibility.Visibility")
		if hudVisibilityModel then
			Engine.SetModelValue(hudVisibilityModel, 1)
		end
		
		return true
	end)
	
	if CoD.isZombie then
		self.disableDarkenElement = true
		self.disablePopupOpenCloseAnim = false
	end
end

LUI.createMenu.StartMenu_Main = function(controller)
	local self = CoD.Menu.NewForUIEditor("StartMenu_Main")

	self.soundSet = "default"
	self:setOwner(controller)
	self:setLeftRight(true, true, 0, 0)
	self:setTopBottom(true, true, 0, 0)
	self:playSound("menu_open", controller)
	self.buttonModel = Engine.CreateModel(Engine.GetModelForController(controller), "StartMenu_Main.buttonPrompts")
	self.anyChildUsesUpdateState = true

	-- Dark Blur Overlay
	self.DarkOverlay = LUI.UIImage.new()
	self.DarkOverlay:setLeftRight(true, true, 0, 0)
	self.DarkOverlay:setTopBottom(true, true, 0, 0)
	self.DarkOverlay:setImage(RegisterImage("$white"))
	self.DarkOverlay:setRGB(0.05, 0.05, 0.05)
	self.DarkOverlay:setAlpha(0.8)
	self:addElement(self.DarkOverlay)

	-- pause_menu_bg
	self.BGMain = LUI.UIImage.new()
	self.BGMain:setLeftRight(true, false, 0, 1280)
	self.BGMain:setTopBottom(true, false, 0, 720)
	self.BGMain:setImage(RegisterImage("i_mtl_image_2c20915dba690ea5"))
	self:addElement(self.BGMain)

	-- sat_pause_menu_bg
	self.BGRight = LUI.UIImage.new()
	self.BGRight:setLeftRight(true, false, 823, 1252)
	self.BGRight:setTopBottom(true, false, 0, 720)
	self.BGRight:setImage(RegisterImage("i_mtl_sat_pause_menu_bg"))
	self:addElement(self.BGRight)

	-- bg_blood
	self.BGBlood = LUI.UIImage.new()
	self.BGBlood:setLeftRight(true, false, 814, 1338)
	self.BGBlood:setTopBottom(true, false, 390, 711)
	self.BGBlood:setImage(RegisterImage("i_mtl_image_273102a380412bec"))
	self:addElement(self.BGBlood)

	-- Game mode icon
	self.GameModeIcon = LUI.UIImage.new()
	self.GameModeIcon:setLeftRight(true, false, 5, 97)
	self.GameModeIcon:setTopBottom(true, false, 10, 102)
	self.GameModeIcon:setImage(RegisterImage("i_mtl_sat_ui_icon_gamemode_zm_standard"))
	self:addElement(self.GameModeIcon)

	-- Logo
	self.Logo = LUI.UIImage.new()
    self.Logo:setLeftRight(true, false, 79, 377)
    self.Logo:setTopBottom(true, false, 55, 102)
	self.Logo:setImage(RegisterImage("i_mtl_image_2fe6956607db6e68"))
	self:addElement(self.Logo)

	-- Map Name
	self.MapName = TodLabel()
    self.MapName:setLeftRight(true, false, 102, 192)
    self.MapName:setTopBottom(true, false, 37, 50)
	self.MapName:setText(Engine.Localize(CoD.UsermapName or "UNKNOWN MAP"))
	self.MapName:setTTF("fonts/orbitron.ttf")
	self.MapName:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.MapName)

	-- Round Label
	self.RoundLabel = TodLabel()
    self.RoundLabel:setLeftRight(true, false, 217, 281)
    self.RoundLabel:setTopBottom(true, false, 37, 50)
	self.RoundLabel:setText(Engine.Localize("ROUND"))
	self.RoundLabel:setTTF("fonts/orbitron.ttf")
	self:addElement(self.RoundLabel)

	-- Round Number
	self.RoundNumber = TodLabel()
    self.RoundNumber:setLeftRight(true, false, 293, 330)
    self.RoundNumber:setTopBottom(true, false, 37, 50)
	self.RoundNumber:setTTF("fonts/orbitron.ttf")
	-- [tod v17.25] THE HUD'S NUMBER WINS. CoD.TodRound is published by
	-- AetheriumRoundCounter from the server's own level.round_number (the
	-- tod_round LuiNotifyEvent lane) — the same number the top-right readout is
	-- showing. The stock "gameScore.roundsPlayed" model stays as the fallback
	-- for the window before the first push, but it is NOT the authority: note
	-- the -1 it needs to read right, which nobody here can explain, and which is
	-- reached through the three round functions _tod_endless_rounds.gsc
	-- replaces. Two round readouts that disagree is worse than either one being
	-- a beat late, so they now share a source.
	self.RoundNumber:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "gameScore.roundsPlayed"), function(model)
		local roundsPlayed = Engine.GetModelValue(model)
		if CoD.TodRound and CoD.TodRound >= 1 then
			self.RoundNumber:setText(Engine.Localize(tostring(CoD.TodRound)))
		elseif roundsPlayed then
			self.RoundNumber:setText(Engine.Localize(tostring(math.max(1, roundsPlayed - 1))))
		end
	end)
	self:addElement(self.RoundNumber)

	-- Game Mode Text
	self.GameModeText = TodLabel()
    self.GameModeText:setLeftRight(true, false, 102, 357)
    self.GameModeText:setTopBottom(true, false, 57, 74)
	-- 2026-10-01 (docs/167 item 12): the floor you are on, not "Round Based
	-- Zombies" (MapName already sits on the line above). This menu is rebuilt on
	-- every open, so the cached label is current; the map name until the first push.
	local todFloor = CoD.TodFloorLabelText and CoD.TodFloorLabelText(controller)
	self.GameModeText:setText(todFloor or Engine.Localize(CoD.UsermapName or "MAP_NAME"))
	self.GameModeText:setTTF("fonts/orbitron.ttf")
	self:addElement(self.GameModeText)

	-- [tod] YOUR UPGRADES — pause-menu-only readout (user 2026-08-20: the
	-- always-on HUD column cluttered play). Data = CoD.TodOwned, accumulated
	-- by tod_upgrade.lua (always-open HUD menu) from GSC tod_upg_sync
	-- LuiNotifyEvents; this menu is re-created on every pause, so a plain
	-- read here is always current. Names come from CoD.TodDomainInfo (the
	-- HUD's own DOMAIN table — one source of truth).
	--
	-- BAKED ART (user 2026-08-20, files (12).zip — the images-over-LUI rule):
	-- header plate (i_tod_pause_hdr, 500x70) + one name plate per domain
	-- (i_tod_pause_rNN, 300x44, NN = _tod_upgrade_ui::domain_id) + a level pip
	-- (i_tod_pause_pip, 24x24) repeated once per owned level. All drawn at TRUE
	-- ASPECT — the v6.6 stretched-plate lesson. Set USE_PAUSE_ART=false to fall
	-- back to the old text rows (kept intact below).
	--
	local USE_PAUSE_ART = true

	-- [tod] WHAT A CLASS TIER-UP TAKES FROM YOU (user 2026-08-27: "players dont
	-- know about is that upgrading class tiers will reset after an upgrade ...
	-- maybe in pause menu we can mark that upgrades that will get lost").
	--
	-- [tod v14.13] THE BADGE IS SERVER-COMPUTED NOW. v14.13 made persistence a
	-- property of the PLAYER, not just the domain (SCAVENGER survives a tier
	-- card for the ASSAULT ALONE — set_scope's scope_class lane), so a static
	-- client table can no longer answer "will a promotion take this row?".
	-- GSC's sync_max() packs the answer into every tod_upg_sync row (+100 on
	-- the max arg; tod_upgrade.lua strips it into row.safe), computed by the
	-- same domain_survives_tier() that tier_up's reset actually uses — the
	-- badge and the reset can never disagree, and class SWITCHING at stations
	-- re-syncs it for free. This table is the FALLBACK ONLY (row.safe == nil:
	-- an event older than the pack, which no live build sends). It lists the
	-- INVERTED 2026-08-31 (v15 item 19): persistence is now the RULE, so this
	-- fallback lists the EXCEPTIONS — the 13 domains a promotion still destroys
	-- — and anything absent is safe. It used to list the ten survivors; a build
	-- that still reads it that way is stale.
	-- SCAVENGER (8) is now SAFE FOR EVERY CLASS (the v14.13 assault-only
	-- carve-out is gone), so it is simply absent, and the fallback is right for
	-- all three classes that roll it rather than for one.
	--   6 twin ladders:  7 MAG SIZE  15 FIRE RATE  16 HANDLING  17 RECOIL
	--                   18 KNIFE SPEED  19 PENETRATION
	--   7 gun-bound:    25 ADRENALINE  26 OVERDRIVE  29 SUPPRESSING FIRE
	--                   31 DRAW CUT  33 SECOND WIND  37 FORCED MARCH
	--                   20 THOR'S THUNDER
	local TIER_RESETS = { [7] = true, [15] = true, [16] = true, [17] = true,
	                      [18] = true, [19] = true, [20] = true, [25] = true,
	                      [26] = true, [29] = true, [31] = true, [33] = true,
	                      [37] = true }
	-- 24 is the CLASS TIER row itself and is never badged, so it must read safe.
	local function tierSafe( id ) return id == 24 or not TIER_RESETS[ id ] end

	local todOwned = CoD.TodOwned or {}
	local todInfo = CoD.TodDomainInfo or {}

	-- AT THE TOP TIER THERE IS NOTHING LEFT TO LOSE (user 2026-08-27: "if you are
	-- in last tier in class the pause menu shouldnt show the reset icon assets
	-- anymore"). A player on their class's final gun can never be dealt another
	-- CLASS TIER card, so no upgrade they hold is at risk and every badge would be
	-- a warning about an event that cannot happen.
	--
	-- Row 24 is the CLASS TIER row: refresh_upgrade_list sends lvl = the current
	-- tier and max = tier_max(). Compared as lvl >= max rather than against a
	-- hardcoded 3, so raising tier_max never silently strands this.
	-- ABSENT MEANS TIER 1, not "unknown": that row is only sent from tier 2 on
	-- (tier 1 is the baseline, not an upgrade). Tier 1 is the furthest thing from
	-- the top, so the badges must show — which is what the nil path here does.
	local tierRow = todOwned[ 24 ]
	local atTopTier = tierRow ~= nil and tierRow.lvl ~= nil and tierRow.max ~= nil
	                  and tierRow.lvl >= tierRow.max
	local todRows = {}
	for id = 1, 63 do   -- the domain-id field is 6 bits (2026-08-22); ids above PAUSE_PLATE_MAX (below) render as TEXT rows; the body is nil-guarded so unused ids cost nothing
		local o = todOwned[ id ]
		if o and o.lvl and o.lvl > 0 then
			-- Detail lines come from tod_upgrade.lua's DETAIL table via
			-- CoD.TodDomainDesc — LEVEL-AWARE, so the number shown is the value
			-- at the level this player actually holds, not the per-level rule.
			-- Nil-guarded twice: the accessor may be absent (older HUD lua) and
			-- may return nil for an id with no detail row; DOMAIN.desc is the
			-- fallback so a new domain is never rendered blank.
			local eff, act = nil, nil
			if CoD.TodDomainDesc then
				eff, act = CoD.TodDomainDesc( id, o.lvl, o.dark )   -- v17.10: o.dark comes off the +200 bit sync_max packs into the max arg
			end
			if not eff then
				eff = ( todInfo[ id ] and todInfo[ id ].desc ) or ""
			end
			if CoD.TodRoundText then   -- [tod v16.57] the rounding guard (see tod_upgrade.lua)
				eff = CoD.TodRoundText( eff )
				act = CoD.TodRoundText( act )
			end
			todRows[ #todRows + 1 ] = {
				id = id,
				dark = ( o.dark == true ),   -- v17.10: drives the RED plate; comes off sync_max's +200 bit

				lvl = o.lvl,
				max = o.max or 10,
				name = ( todInfo[ id ] and todInfo[ id ].name ) or ( "UPGRADE " .. id ),
				eff = eff,
				act = act or "",
				-- Marked with the warning badge below. Will-be-taken AND a
				-- promotion still possible — at the top tier nothing can be
				-- taken, so the whole column of badges disappears. The
				-- authority is the row's server-computed safe bit (v14.13);
				-- tierSafe() is only the nil fallback.
				resets = ( not ( ( o.safe ~= nil and o.safe ) or ( o.safe == nil and tierSafe( id ) ) ) )
				         and ( not atTopTier ),
			}
		end
	end

	if #todRows > 0 and USE_PAUSE_ART then
		-- header: RE-CUT to 1000x70 for the two-column panel (files (36).zip,
		-- 2026-08-23) -> 700x49, aspect 14.286 held EXACTLY. The old art was
		-- 500x70 at 232x32 (aspect 7.14) and looked undersized once the panel
		-- grew to two columns. Right edge 802 stays clear of BGBlood at 814.
		-- PANEL SCALED UP ~10% (user 2026-08-27: "everything in the pause menu can
		-- you increase by 10% ... Assets and text ... I see we have a bit of space
		-- so we can have it fill out the menu a bit more").
		--
		-- IT COULD NOT BE A UNIFORM 10%, AND THAT IS WORTH KNOWING BEFORE ANYONE
		-- "finishes the job": the panel was already against its right wall. Column
		-- B ended at x=810 and the BGBlood art starts at x=814 — four pixels, i.e.
		-- 0.6% of width. A naive 10% scale about the panel origin overflowed the
		-- blood art by 67px.
		--
		-- The space the user could see is on the LEFT and BELOW, so that is where
		-- this takes it. x 0..102 is empty in the panel's own y band (the logo and
		-- mode icon stop at y=102, the signatures start at y=637), so the panel now
		-- STARTS at x=60 and keeps its right edge pinned at 810. That buys +6.0% of
		-- column width; the rest of the 10% goes into row pitch, plate size and
		-- text, all of which fit vertically inside the 49px that were spare.
		--
		-- The three bounds that decide everything here, all verified:
		--   right   810 < 814 BGBlood
		--   bottom  legend ends 630 < 637 signatures
		--   column  plate + a full 10-pip run = 365 <= 369
		self.TodUpgHeader = LUI.UIImage.new()
		self.TodUpgHeader:setLeftRight( true, false, 60, 810 )
		self.TodUpgHeader:setTopBottom( true, false, 119, 171 )
		self.TodUpgHeader:setImage( RegisterImage( "i_tod_pause_hdr" ) )
		self:addElement( self.TodUpgHeader )

		-- ------------------------------------------------------------------
		-- TWO-COLUMN DETAIL ROWS (v9.37, user 2026-08-23: "players forget or
		-- don't know exactly what each upgrade does"). Each row is the baked
		-- name plate + level pips, then TWO authored text lines: what it does
		-- at YOUR level (cyan) and how it activates (dim).
		--
		-- Geometry is bounded by real elements, not taste:
		--   * BGBlood's left edge is x=814 -> right bound 810.
		--   * The four signature images (x 0..508, y 637..720) are addElement'd
		--     AFTER this block, so they PAINT OVER anything below y=637.
		--   * Rows must therefore end above y=637. Two columns of 7 at 54px
		--     pitch end at y=546, with room to spare.
		-- THIS COMMENT HAS NOW BEEN STALE TWICE, AND BOTH TIMES IT SILENTLY ATE
		-- ROWS. The single-column version claimed "at most 8 domains"; the
		-- two-column version that replaced it claimed "the true ceiling is 14
		-- rows ... 2 columns x 7 covers it exactly" and was already wrong by
		-- 2026-09-02, when RIOT SHIELD became the 15th universal-or-heavy row.
		-- A ROW BUDGET IS NOT A COMMENT — it is a number that moves every time
		-- add_domain is called, so tools/lint_tod_assets.js now counts the
		-- reachable set per class off the live add_domain scopes and fails the
		-- build when it passes what this panel can draw. See the compact preset
		-- below for the counts as of 2026-09-04.
		--
		-- Highest domain id with a baked row plate. Domains ABOVE this render
		-- as text until their art lands — RegisterImage on a missing image is
		-- undefined behavior, so never reach for a plate that does not exist.
		-- DARK UPGRADE PLATES (v17.10): 24 red variants, i_tod_pause_rNN_dark.
		-- THE RULE MOVED to tod_upgrade.lua's CoD.TodDarkPlate (v17.11,
		-- 2026-09-04) because the SCOREBOARD draws this same list from the same
		-- CoD.TodOwned and had never been taught any of it — it read o.dark for
		-- the value text and then drew the plain blue plate. The flag and the
		-- not-yet-baked list live with the function; nothing here mirrors them.
		local PAUSE_PLATE_MAX = 57 -- RAPID FLAME's r57 plate landed 2026-09-21, extending the contiguous nameplates to r57. THUNDER SMASH (r58) has no plate yet, so 58 still renders as a text row.

		local COL_X    = { 60, 441 }    -- column left edges; col B still ends at 810 (< BGBlood 814)
		local COL_W    = 369            -- +6.0%: all the width the BGBlood bound allows
		local ROW_Y0   = 180            -- 9px under the re-cut header (bottom 171)
		local ROW_H    = 59             -- the row PITCH; recomputed below from the room left (v19.61)
		local ROWS_MAX = 7              -- per column; 2 x 7 = 14
		local PLATE_W  = 210            -- 300x44 art -> 210x31, aspect 6.77 (art 6.82) held
		local PLATE_H  = 31
		local PIP_D    = 13
		local PIP_PITCH = 15            -- plate + a full 10-pip run = 365 <= COL_W 369
		-- Offsets INSIDE a row, all measured from the row's own top edge. They
		-- were literals in the loop until 2026-09-04; the compact preset below
		-- has to move every one of them together, and a literal is a lockstep
		-- partner nobody remembers.
		local PIP_Y    = 9              -- pip top, under the plate's own top
		local MARK_W   = 12             -- reset badge, square
		local MARK_Y   = 31
		local EFF_IND  = 17             -- extra left indent when the badge is drawn
		-- v19.61: the effect line sits 2 units closer to its own plate, so a
		-- row's title and description read as one block (see ROW SPACING below).
		-- v19.62 (user: "the two lines ... need a tiny bit padding between
		-- them"): the act line keeps its old place, so the air between the two
		-- lines' caps is ~4.4 units (normal) / ~4.1 (compact), was ~2.4 / ~1.1.
		local EFF_T, EFF_B, EFF_S = 30, 44, 0.90
		local ACT_T, ACT_B, ACT_S = 45, 59, 0.79
		-- GLYPH SCALES (v19.59, user 2026-09-27: "the text is too small to
		-- read"). EFF_S / ACT_S were tuned for the ENGINE font, whose line box
		-- carries ascender + descender room, so the same scale drew the glyph
		-- caps a size smaller (compact: 7.9 / 6.4 canvas units). The glyph
		-- lines now use their own scales; cap = box * 0.80 * scale. Measured in
		-- the row (baseline = box top + 0.94 box):
		--   normal   eff cap 11.2 top 32.0 base 43.2 | act cap 10.5 top 47.6 base 58.2 < 59
		--   compact  eff cap 10.4 top 25.8 base 36.2 | act cap  9.0 top 40.3 base 49.3 < 50
		-- (v19.62; the plate art's own bottom padding keeps the eff caps clear)
		-- so the two lines never touch each other or the next row's plate, and
		-- width is safe by construction (a long line shrinks to its box).
		local EFF_GS, ACT_GS = 1.0, 0.94

		-- ------------------------------------------------------------------
		-- COMPACT PRESET (2026-09-04, user: "I dont even see riot shield in the
		-- pause menu. Is there too many upgrades to fit in the menu for heavy
		-- class?" — yes, exactly that).
		--
		-- 2 x 7 = 14 WAS NEVER THE CEILING, and the comment that said so was
		-- stale the day RIOT SHIELD landed. Counted off the live add_domain
		-- scopes on 2026-09-04, the reachable set per class is:
		--     SKIRMISHER 16   ASSAULT 15   HEAVY 16   SLASHER 15
		-- (15 domains + the CLASS TIER row for the two 16s). Rows render in
		-- ASCENDING DOMAIN ID, so overflow always eats the NEWEST domains —
		-- 45 RIOT SHIELD fell off for ALL FOUR CLASSES, 42 FULL STEAM for the
		-- heavy too, and 47 DEADSHOT for the assault. The "+N MORE" line the
		-- old code printed instead was honest and completely unnoticed.
		--
		-- Rather than restructure a layout that is correct for a short list,
		-- long lists get a proportionally scaled preset: every metric above
		-- x 50/59, which buys a 9th row per column. Capacity 18 against a real
		-- max of 16, so one more universal domain still fits.
		--
		-- The bounds are the same three as ever, re-checked at 8 rows/column
		-- (16 rows, the worst real case):
		--   right   plate 177 + 7 + a full 10-pip run at 13 = 314 <= COL_W 369
		--   bottom + legend: the pitch is now derived from them (ROW SPACING,
		--           below the column split), so they hold by construction
		-- LEGEND_Y_MAX below is the belt to that braces: at 9 rows/column the
		-- legend would land at 636 and be painted over, so it is clamped.
		if #todRows > ROWS_MAX * 2 then
			ROWS_MAX = 9              -- per column; 2 x 9 = 18
			PLATE_W  = 177            -- 300x44 art -> 177x26, aspect 6.81 (art 6.82) held
			PLATE_H  = 26
			PIP_D    = 11
			PIP_PITCH = 13
			PIP_Y    = 8
			MARK_W   = 10
			MARK_Y   = 25
			EFF_IND  = 14
			EFF_T, EFF_B, EFF_S = 24, 37, 0.76
			ACT_T, ACT_B, ACT_S = 38, 50, 0.67
			EFF_GS, ACT_GS = 1.0, 0.94   -- same scales; the smaller boxes shrink the caps (see above)
		end

		-- Balance the columns: <=7 rows stay in one column (a short list reads
		-- worse split), 8..14 split evenly.
		local shown = #todRows
		local overflow = 0
		if shown > ROWS_MAX * 2 then
			overflow = shown - ROWS_MAX * 2
			shown = ROWS_MAX * 2
		end
		local perCol = shown
		if shown > ROWS_MAX then
			perCol = math.ceil( shown / 2 )
		end

		local anyReset = false
		for i = 1, shown do
			if todRows[ i ].resets then anyReset = true break end
		end

		-- ROW SPACING (v19.61, user 2026-09-27: "add more space between the
		-- upgrades. Under the description and above the upgrade title"). The
		-- pitch used to equal the row's own height (ACT_B), so the next plate
		-- started where the description ended. It now takes whatever room is
		-- left above the bottom bound, spread evenly between the rows, capped at
		-- ROW_GAP_MAX of air and never below the row height (rows never touch).
		-- The bound is the same one as ever: the signatures paint over y >= 637,
		-- and the legend (6 + 31) and the "+N MORE" line (20) sit under the rows.
		--   16 rows, compact: 8/col -> gap  7 (no legend) /  2 (legend)
		--   14 rows, normal : 7/col -> gap  6 (no legend) /  1 (legend)
		--   fewer rows      : the full ROW_GAP_MAX
		local ROW_GAP_MAX = 12
		local rowsBottom = anyReset and ( 637 - 6 - 31 ) or 632
		if overflow > 0 then rowsBottom = rowsBottom - 20 end
		ROW_H = ACT_B + ROW_GAP_MAX
		if perCol > 1 then
			local fit = math.floor( ( rowsBottom - ROW_Y0 - ACT_B ) / ( perCol - 1 ) )
			if fit < ROW_H then ROW_H = fit end
		end
		if ROW_H < ACT_B then ROW_H = ACT_B end

		for i = 1, shown do
			local r = todRows[ i ]
			local col = 1
			local idx = i
			if i > perCol then
				col = 2
				idx = i - perCol
			end
			local cx = COL_X[ col ]
			local y = ROW_Y0 + ( idx - 1 ) * ROW_H

			local darkMark = false   -- 2026-09-09: "DARK: " on the effect line when no red plate is baked
			if r.id <= PAUSE_PLATE_MAX then
				local plate = LUI.UIImage.new()
				plate:setLeftRight( true, false, cx, cx + PLATE_W )
				plate:setTopBottom( true, false, y, y + PLATE_H )
				-- DARK UPGRADE (v17.10): a dark-held domain gets a RED plate, or
				-- the ordinary plate tinted red where no red one was baked.
				-- CoD.TodDarkPlate (tod_upgrade.lua) owns which — the scoreboard
				-- asks the same function, so the two screens cannot diverge again.
				-- Nil-guarded: an older HUD lua has no such function, and the
				-- plain plate is the right answer then.
				local img, tint = nil, false
				if r.dark and CoD.TodDarkPlate then
					img, tint, darkMark = CoD.TodDarkPlate( r.id, PAUSE_PLATE_MAX )
				end
				plate:setImage( RegisterImage( img or string.format( "i_tod_pause_r%02d", r.id ) ) )
				if tint then
					plate:setRGB( 1.0, 0.34, 0.36 )
				end
				self:addElement( plate )
			else
				local label = TodLabel()   -- v19.59b: the typeface here too
				label:setLeftRight( true, false, cx + 4, cx + PLATE_W )
				label:setTopBottom( true, false, y + 6, y + 22 )   -- cap 12.8 in the plate slot
				label:setText( Engine.Localize( r.name ) )
				label:setTTF( "fonts/orbitron.ttf" )
				label:setRGB( 0.86, 0.9, 0.95 )
				label:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
				self:addElement( label )
			end

			-- Level pips: FILLED to the owned level, then the EMPTY pip out to the
			-- cap, so the panel shows how much room is left as well as what you
			-- hold. Capped at 10 (the highest domain max) to bound the row width.
			-- i_tod_pause_pip_empty is a real hollow unlit ring (files (36).zip,
			-- 2026-08-23); before it landed this drew the FILLED pip at alpha
			-- 0.22, which read as a ghost of a filled pip rather than an
			-- empty slot.
			local pipN = r.max
			if pipN > 10 then pipN = 10 end
			if pipN < r.lvl then pipN = r.lvl end
			for p = 1, pipN do
				local px = cx + PLATE_W + 7 + ( p - 1 ) * PIP_PITCH
				local pip = LUI.UIImage.new()
				pip:setLeftRight( true, false, px, px + PIP_D )
				pip:setTopBottom( true, false, y + PIP_Y, y + PIP_Y + PIP_D )
				if p > r.lvl then
					pip:setImage( RegisterImage( "i_tod_pause_pip_empty" ) )
				else
					pip:setImage( RegisterImage( "i_tod_pause_pip" ) )
				end
				self:addElement( pip )
			end

			-- TIER-UP WARNING BADGE. Sits at the head of the effect line, so the
			-- mark reads as belonging to the row without needing width the row
			-- does not have: the name plate plus a full 10-pip run already reaches
			-- cx+338 of a 348-wide column, and the right edge is hard-bounded by
			-- BGBlood at x=814. The effect line's left margin is the one piece of
			-- guaranteed empty space in the row.
			local effX = cx + 2
			if r.resets then
				local mark = LUI.UIImage.new()
				mark:setLeftRight( true, false, cx + 2, cx + 2 + MARK_W )
				mark:setTopBottom( true, false, y + MARK_Y, y + MARK_Y + MARK_W )
				mark:setImage( RegisterImage( "i_tod_pause_reset_mark" ) )
				self:addElement( mark )
				effX = cx + 2 + EFF_IND   -- indent the text clear of the badge
			end

			-- WHAT IT DOES, at this player's current level.
			local effLine, effGlyph = TodLabel()
			effLine:setLeftRight( true, false, effX, cx + COL_W - 4 )
			effLine:setTopBottom( true, false, y + EFF_T, y + EFF_B )
			effLine:setText( darkMark and ( "DARK: " .. r.eff ) or r.eff )
			effLine:setTTF( "fonts/orbitron.ttf" )
			effLine:setRGB( 0.42, 0.92, 1 )
			effLine:setScale( effGlyph and EFF_GS or EFF_S )
			effLine:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
			self:addElement( effLine )

			-- HOW IT ACTIVATES — trigger, window, cooldown, stack cap. An ability
			-- line ("Press <key> to cast - ...") is laid out by TodActLine above.
			-- Near-white (v19.58, user: "should be more white so its readable"),
			-- so the blue effect line above still leads.
			if r.act ~= "" then
				TodActLine( self, controller, r.act, cx + 2, cx + COL_W - 4, y + ACT_T, y + ACT_B,
					ACT_GS, ACT_S, { 0.92, 0.95, 1 } )
			end
		end

		-- THE LEGEND, drawn once and only when at least one row carries the badge.
		-- Placed off the LAST ROW ACTUALLY USED rather than a constant, so it
		-- follows a short list up the panel instead of floating below empty space,
		-- and it drops clear of the "+N MORE" line when that renders. 380x28 holds
		-- the art's exact 13.571 aspect (760x56) — the v6.6 stretched-plate lesson.
		-- Bottom bound is y=637, where the four signature images paint over
		-- everything: worst case here is 580+28 = 608.
		if anyReset then
			local legendY = ROW_Y0 + ( perCol - 1 ) * ROW_H + ACT_B + 6
			if overflow > 0 then legendY = legendY + 20 end
			-- CLAMP (2026-09-04): the signature images paint over everything
			-- below y=637, so a legend pushed past 606 is a legend nobody sees.
			-- It only bites at a FULL compact panel (9 rows/column would put it
			-- at 636) — which no current class can reach, but the panel grew
			-- past its budget once already by trusting exactly that.
			local LEGEND_Y_MAX = 606
			if legendY > LEGEND_Y_MAX then legendY = LEGEND_Y_MAX end
			local legend = LUI.UIImage.new()
			legend:setLeftRight( true, false, COL_X[ 1 ], COL_X[ 1 ] + 418 )
			legend:setTopBottom( true, false, legendY, legendY + 31 )
			legend:setImage( RegisterImage( "i_tod_pause_legend_reset" ) )
			self:addElement( legend )
		end

		-- Fires past 18 concurrent domains (the compact preset's 2 x 9). It DID
		-- fire, for every class, from 2026-09-02 until 2026-09-04 — and this is
		-- the shape of that failure worth remembering: the code was HONEST, it
		-- printed "+2 MORE", and nobody read it. A truthful count of what you
		-- dropped is a last resort, not a fallback: the row it drops is always
		-- the newest domain, i.e. the one the player is most curious about.
		-- If this ever renders again, raise the capacity; do not tune the text.
		if overflow > 0 then
			local more = TodLabel()   -- v19.59b: the typeface here too
			more:setLeftRight( true, false, COL_X[ 1 ], COL_X[ 1 ] + COL_W )
			local moreY = ROW_Y0 + ( ROWS_MAX - 1 ) * ROW_H + ACT_B
			more:setTopBottom( true, false, moreY + 4, moreY + 20 )
			more:setText( "+" .. overflow .. " MORE" )
			more:setTTF( "fonts/orbitron.ttf" )
			more:setRGB( 0.6, 0.66, 0.74 )
			more:setScale( 0.8 )
			more:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
			self:addElement( more )
		end
	elseif #todRows > 0 then
		-- text fallback (pre-art path)
		self.TodUpgHeader = LUI.UIText.new()
		self.TodUpgHeader:setLeftRight( true, false, 102, 380 )
		self.TodUpgHeader:setTopBottom( true, false, 132, 149 )
		self.TodUpgHeader:setText( Engine.Localize( "YOUR UPGRADES" ) )
		self.TodUpgHeader:setTTF( "fonts/orbitron.ttf" )
		self.TodUpgHeader:setRGB( 0.35, 0.9, 1 )
		self.TodUpgHeader:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
		self:addElement( self.TodUpgHeader )

		local y = 158
		for i = 1, #todRows do
			local r = todRows[ i ]
			local t = LUI.UIText.new()
			t:setLeftRight( true, false, 102, 380 )
			t:setTopBottom( true, false, y, y + 14 )
			t:setText( Engine.Localize( r.name .. "  " .. r.lvl .. "/" .. r.max ) )
			t:setTTF( "fonts/orbitron.ttf" )
			t:setRGB( 0.86, 0.9, 0.95 )
			t:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
			self:addElement( t )

			local d = LUI.UIText.new()
			d:setLeftRight( true, false, 102, 500 )
			d:setTopBottom( true, false, y + 14, y + 26 )
			d:setText( r.eff )
			d:setTTF( "fonts/orbitron.ttf" )
			d:setRGB( 0.6, 0.66, 0.74 )
			d:setScale( 0.75 )
			d:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
			self:addElement( d )

			y = y + 30
		end
	end

	-- Game Time Label
	self.GameTimeLabel = TodLabel()
    self.GameTimeLabel:setLeftRight(true, false, 925, 1033)
    self.GameTimeLabel:setTopBottom(true, false, 173, 187)
	self.GameTimeLabel:setText(Engine.Localize("GAME TIME"))
	self.GameTimeLabel:setTTF("fonts/orbitron.ttf")
	self.GameTimeLabel:setRGB(1, 1, 1)
	self.GameTimeLabel:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
	self:addElement(self.GameTimeLabel)

	-- Game Time Value (Official Method)
	self.GameTimeValue = LUI.UIText.new()
    self.GameTimeValue:setLeftRight(true, false, 1041, 1114)
    self.GameTimeValue:setTopBottom(true, false, 172, 188)
	self.GameTimeValue:setTTF("fonts/ltromatic.ttf")
	self.GameTimeValue:setRGB(0.878, 0, 0)
	self.GameTimeValue:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
	self.GameTimeValue:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "hudItems.time.game_start_time"), function(model)
		local time = Engine.GetModelValue(model)
		if time then
			self.GameTimeValue:setupServerTime(time)
		end
	end)
	self:addElement(self.GameTimeValue)

	-- [tod v19.59b] THE CLOCK IN THE MAP'S TYPEFACE. setupServerTime above is
	-- an engine clock (its text cannot be read from Lua), so GSC sends the
	-- elapsed seconds once a second (_tod_upgrade_ui::game_time_push) and the
	-- HUD caches them in CoD.TodGameSecs. With a value in hand the glyph clock
	-- shows and the engine clock hides; without one (HUD lua missing, first
	-- second of a match) the engine clock stays exactly as it always was.
	do
		local clock, clockGlyph = TodLabel()
		if clockGlyph then
			clock:setLeftRight(true, false, 1041, 1114)
			clock:setTopBottom(true, false, 173, 187)
			clock:setRGB(0.878, 0, 0)
			clock:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
			clock:setAlpha(0)
			self:addElement(clock)
			local function fmt(t)
				local h = math.floor(t / 3600)
				local m = math.floor((t % 3600) / 60)
				local sec = t % 60
				if h > 0 then
					return string.format("%d:%02d:%02d", h, m, sec)
				end
				return string.format("%d:%02d", m, sec)
			end
			local function show(t)
				if t == nil then return end
				clock:setText(fmt(t))
				clock:setAlpha(1)
				self.GameTimeValue:setAlpha(0)
			end
			show(CoD.TodGameSecs and CoD.TodGameSecs[controller])
			-- live in co-op, where the world keeps running under this menu
			self:subscribeToGlobalModel(controller, "PerController", "scriptNotify", function(model)
				if Engine.GetModelValue(model) ~= "tod_game_time" then return end
				local d = CoD.GetScriptNotifyData(model)
				if d then show(math.floor(tonumber(d[1]) or 0)) end
			end)
		else
			clock:close()   -- the no-typeface stand-in was never parented
		end
	end

	-- [tod 2026-09-02, KBM audit] UPGRADE CARDS controls legend.
	--
	-- The upgrade panel and the class draft show their controls on BAKED
	-- plates that carry the DEFAULT binds (MOUSE1 / MOUSE2 / V / SPACE, or the
	-- Xbox-layout pad glyphs). This line is the one place a player can read
	-- the LIVE ones: every [{+bind}] token below is expanded by the engine into
	-- the key or pad glyph bound RIGHT NOW on THIS device -- the same mechanism
	-- every stock "Hold [X]" hint rides, and the one PromptDefault.lua's
	-- SetFooter now uses for the cursor-hint cards. A rebinder who moved USE to
	-- E reads E here; a PS-layout pad reads its own glyphs.
	--
	-- Pad players get the d-pad line once the server has PROVED the pad
	-- (CoD.TodPad, the same one-way latch the HUD plates key on) -- before the
	-- latch the keyboard line is ALSO the truth for a pad, because RT / LT / R3
	-- are live lanes until the first d-pad press. Nothing here reads the
	-- device itself: the LUI probe guessed wrong for keyboard players with a
	-- pad plugged in (v16.3), and the latch is the only proof there is.
	--
	-- Menu-only by design (the card panels keep their art, the images-over-LUI
	-- rule), and it doubles as the first in-game proof of which bind names the
	-- engine expands: if any token here renders as literal "[{+...}]", that
	-- name is wrong and the frame-plate art in docs/69 must not use it.
	-- Sits under the button list (ends y=560); the signatures start at 637.
	-- [tod v16.32] baked header strip (i_tod_pause_ctl_header, files (96).zip,
	-- 760x56 drawn 342x25 — the legend_reset strip's own aspect); the text
	-- header below survives as the no-art fallback (images-over-LUI rule).
	local USE_TOD_CTL_HEADER_ART = true
	if USE_TOD_CTL_HEADER_ART then
		self.TodCtlHeader = LUI.UIImage.new()
		self.TodCtlHeader:setLeftRight(true, false, 868, 1210)
		self.TodCtlHeader:setTopBottom(true, false, 571, 596)
		self.TodCtlHeader:setImage(RegisterImage("i_tod_pause_ctl_header"))
		self:addElement(self.TodCtlHeader)
	else
		self.TodCtlHeader = LUI.UIText.new()
		self.TodCtlHeader:setLeftRight(true, false, 868, 1210)
		self.TodCtlHeader:setTopBottom(true, false, 576, 592)
		self.TodCtlHeader:setText(Engine.Localize("UPGRADE CARDS"))
		self.TodCtlHeader:setTTF("fonts/orbitron.ttf")
		self.TodCtlHeader:setRGB(0.35, 0.9, 1)
		self.TodCtlHeader:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
		self:addElement(self.TodCtlHeader)
	end

	-- [tod v16.83] THIS LINE WAS ADVERTISING TWO DEAD LANES. It named
	-- `+attack` and `+speed_throw` -- fire and aim -- which v16.57 REMOVED as
	-- menu inputs (they can never be given a side that is right on both a pad
	-- and a mouse; `_tod_upgrade_ui::wait_for_choice` still reads them, but
	-- only for the dev probe, and neither one assigns `want` any more). A
	-- player following this legend pressed fire, watched the focus not move,
	-- and concluded the menu was broken. It now names the same single lane the
	-- in-world plates do -- the offhand pair, with its direction -- so the two
	-- readouts can never disagree again.
	--
	-- No `CoD.TodPad` branch: that latch is not a device proof (v16.81 -- a
	-- keyboard binds 3/4 to action slots), and it never needed to be here.
	-- The engine expands each token into the live device's own key or glyph.
	-- [tod v16.93] THE LEGEND GETS THE SAME GLYPHS AS THE CARD MENUS.
	-- v16.83 fixed this line's WORDING and stopped there, so the pause menu was
	-- still spelling out key names while both card panels had moved to baked
	-- button art (v16.88). A readout that disagrees with the thing it describes
	-- is the exact failure v16.83 was fixing, one level up -- so it is not
	-- enough for the legend to be CORRECT, it has to MATCH.
	--
	-- Layout: two switch glyphs, the word SWITCH, the lock glyph, the word LOCK,
	-- inside the same 868..1210 band the text used. Rects are computed PER
	-- DEVICE for the reason the card menus document: the pad glyph is square and
	-- the keycap is wide and short, so one fixed rect would stretch one of them.
	-- [tod v17.55] the latch OR the bind expansion, through the ONE reader the
	-- card menus use (CoD.TodKeycap.PadDevice, argument in TodKeycap.lua) — so
	-- a pad player never reads keycaps here while the panels show a d-pad.
	local TodPad = ( CoD.TodPad == true )
	if not TodPad and CoD.TodKeycap ~= nil then
		TodPad = ( CoD.TodKeycap.PadDevice() == true )
	end
	-- [tod v18.48] the widget-free arm is GONE. v18.47 put a byte scan here and
	-- it reported "pad" for keyboard players, so this legend -- and both card
	-- menus -- drew controller art for everyone. KEYBOARD IS THE DEFAULT and a
	-- pad has to be proven; the only proof this file can make without the
	-- widget is CoD.TodPad, which it already reads above.
	local GW, GH = 30, 30           -- pad glyph: square
	if not TodPad then
		-- [v17.4] 64 x 32 and the text scaled: a multi-bound action (the user's
		-- +frag sits on both G and MOUSE3) expands to a string naming both, and
		-- the old 56 could not hold it. Same fix as the two card menus.
		GW, GH = 64, 32             -- keycap: wide and short
	end
	local gy = 601 + ( 30 - GH ) / 2
	local function CtlGlyph(x, img)
		local e = LUI.UIImage.new()
		e:setLeftRight(true, false, x, x + GW)
		e:setTopBottom(true, false, gy, gy + GH)
		e:setImage(RegisterImage(img))
		self:addElement(e)
		return e
	end
	local function CtlKey(x, tok)
		-- only drawn on KBM: the live bind, INSIDE the keycap.
		-- [tod v17.27] set in the MAP'S OWN TYPEFACE through CoD.TodKeycap, the
		-- one writer shared with both card menus. It trims a multi-bound action
		-- to its first key, measures the string in the baked glyph sheets and
		-- sizes it to the art's own bright face (centred at 43.5% of the cap
		-- height, not 50%). The UIText stays as the no-glyph fallback.
		local t = LUI.UIText.new()
		t:setTTF("fonts/ltromatic.ttf")
		t:setRGB(0.06, 0.07, 0.10)
		t:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
		t:setAlpha(0)
		self:addElement(t)
		TodKeycapMake(self, t).paint(x, gy, GW, GH, tok)
		return t
	end
	local function CtlWord(x, w, str)
		local t = TodLabel()
		t:setLeftRight(true, false, x, x + w)
		t:setTopBottom(true, false, 608, 624)
		t:setText(Engine.Localize(str))
		t:setTTF("fonts/ltromatic.ttf")
		t:setRGB(0.86, 0.9, 0.95)
		t:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
		self:addElement(t)
		return t
	end
	do
		-- pack the row and centre it in the band
		local gap, wordW = 4, 62
		local rowW = GW + gap + GW + 6 + wordW + 16 + GW + 6 + wordW
		local x = 1039 - rowW / 2      -- 1039 = centre of 868..1210
		local lImg = CtlGlyph(x, TodPad and "i_tod_pad_dpad_left" or "i_tod_key_blank_wide")
		if not TodPad then CtlKey(x, "[{+smoke}]") end
		x = x + GW + gap
		local rImg = CtlGlyph(x, TodPad and "i_tod_pad_dpad_right" or "i_tod_key_blank_wide")
		if not TodPad then CtlKey(x, "[{+frag}]") end
		x = x + GW + 6
		CtlWord(x, wordW, "SWITCH")
		x = x + wordW + 16
		CtlGlyph(x, TodPad and "i_tod_pad_button_a" or "i_tod_key_blank_wide")
		if not TodPad then CtlKey(x, "[{+gostand}]") end
		x = x + GW + 6
		CtlWord(x, wordW, "LOCK")
		-- keep the handle the rest of the file expects to exist
		self.TodCtlLine = lImg
		self.TodCtlLineR = rImg
	end

	-- Options Header Text (hidden by default, shown with options)
	self.OptionsHeaderText = TodLabel()
    self.OptionsHeaderText:setLeftRight(true, false, 907, 1168)
    self.OptionsHeaderText:setTopBottom(true, false, 108, 132)
	self.OptionsHeaderText:setText(Engine.Localize("Options & Controls"))
	self.OptionsHeaderText:setTTF("fonts/orbitron.ttf")
	self.OptionsHeaderText:setRGB(1, 1, 1)
	self.OptionsHeaderText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
	self.OptionsHeaderText:setAlpha(0)
	self:addElement(self.OptionsHeaderText)

	-- Pause Menu Text (hidden when options are shown)
	self.PauseMenuText = TodLabel()
	self.PauseMenuText:setLeftRight(true, false, 952, 1127)
	self.PauseMenuText:setTopBottom(true, false, 44, 68)
	self.PauseMenuText:setText(Engine.Localize("Pause Menu"))
	self.PauseMenuText:setTTF("fonts/orbitron.ttf")
	self.PauseMenuText:setRGB(1, 1, 1)
	self.PauseMenuText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.PauseMenuText)

	-- Small Top Buttons List
	self.SmallButtonList = LUI.UIList.new(self, controller, 2, 0, nil, true, false, 0, 0, false, false)
	self.SmallButtonList:makeFocusable()
	self.SmallButtonList:setLeftRight(true, false, 897, 1176)
	self.SmallButtonList:setTopBottom(true, false, 101, 142)
	self.SmallButtonList:setWidgetType(CoD.AetheriumSmallButton)
	self.SmallButtonList:setHorizontalCount(4)
	self.SmallButtonList:setSpacing(9)
	self.SmallButtonList:setDataSource("AetheriumSmallMenuButtons")
	self.SmallButtonList:registerEventHandler("gain_focus", function(element, event)
		local retVal = nil
		if element.gainFocus then
			retVal = element:gainFocus(event)
		elseif element.super.gainFocus then
			retVal = element.super:gainFocus(event)
		end
		CoD.Menu.UpdateButtonShownState(element, self, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS)
		return retVal
	end)
	self.SmallButtonList:registerEventHandler("lose_focus", function(element, event)
		local retVal = nil
		if element.loseFocus then
			retVal = element:loseFocus(event)
		elseif element.super.loseFocus then
			retVal = element.super:loseFocus(event)
		end
		return retVal
	end)
	self:AddButtonCallbackFunction(self.SmallButtonList, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "ENTER", function(element, menu, controller, model)
		ProcessListAction(self, element, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "MENU_SELECT")
		return true
	end, false)
	self:addElement(self.SmallButtonList)
	self.SmallButtonList.id = "SmallButtonList"

	-- Button List (replaces individual button images)
	self.ButtonList = LUI.UIList.new(self, controller, 5, 0, nil, false, false, 0, 0, false, false)
	self.ButtonList:makeFocusable()
	self.ButtonList:setLeftRight(true, false, 868, 1210)
	self.ButtonList:setTopBottom(true, false, 221, 560)
	self.ButtonList:setWidgetType(CoD.AetheriumMenuButton)
	self.ButtonList:setVerticalCount(7)
	self.ButtonList:setSpacing(10)
	self.ButtonList:setDataSource("AetheriumStartMenuButtons")
	self.ButtonList:registerEventHandler("gain_focus", function(element, event)
		local retVal = nil
		if element.gainFocus then
			retVal = element:gainFocus(event)
		elseif element.super.gainFocus then
			retVal = element.super:gainFocus(event)
		end
		CoD.Menu.UpdateButtonShownState(element, self, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS)
		return retVal
	end)
	self.ButtonList:registerEventHandler("lose_focus", function(element, event)
		local retVal = nil
		if element.loseFocus then
			retVal = element:loseFocus(event)
		elseif element.super.loseFocus then
			retVal = element.super:loseFocus(event)
		end
		return retVal
	end)
	self:AddButtonCallbackFunction(self.ButtonList, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "ENTER", function(element, menu, controller, model)
		ProcessListAction(self, element, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "MENU_SELECT")
		return true
	end, false)
	self:addElement(self.ButtonList)
	self.ButtonList.id = "ButtonList"
	
	-- Options List (hidden by default, shown when Game Settings is clicked)
	self.OptionsList = LUI.UIList.new(self, controller, 5, 0, nil, false, false, 0, 0, false, false)
	self.OptionsList:makeFocusable()
	self.OptionsList:setLeftRight(true, false, 868, 1210)
	self.OptionsList:setTopBottom(true, false, 221, 560)
	self.OptionsList:setWidgetType(CoD.AetheriumMenuButton)
	self.OptionsList:setVerticalCount(9)
	self.OptionsList:setSpacing(10)
	self.OptionsList:setDataSource("AetheriumOptionsButtons")
	self.OptionsList:setAlpha(0)
	self.OptionsList:registerEventHandler("gain_focus", function(element, event)
		local retVal = nil
		if element.gainFocus then
			retVal = element:gainFocus(event)
		elseif element.super.gainFocus then
			retVal = element.super:gainFocus(event)
		end
		CoD.Menu.UpdateButtonShownState(element, self, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS)
		return retVal
	end)
	self.OptionsList:registerEventHandler("lose_focus", function(element, event)
		local retVal = nil
		if element.loseFocus then
			retVal = element:loseFocus(event)
		elseif element.super.loseFocus then
			retVal = element.super:loseFocus(event)
		end
		return retVal
	end)
	self:AddButtonCallbackFunction(self.OptionsList, controller, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "ENTER", function(element, menu, controller, model)
		ProcessListAction(self, element, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_XBA_PSCROSS, "MENU_SELECT")
		return true
	end, false)
	
	-- Add fade animations to OptionsList
	self.OptionsList.clipsPerState = {
		DefaultState = {
			FadeIn = function()
				self.OptionsList:completeAnimation()
				self.OptionsList:setAlpha(1, 150)
			end,
			FadeOut = function()
				self.OptionsList:completeAnimation()
				self.OptionsList:setAlpha(0, 150)
			end
		}
	}
	
	self:addElement(self.OptionsList)
	self.OptionsList.id = "OptionsList"

	-- [tod] CONTROLLER / ARROW-KEY NAVIGATION BETWEEN THE TWO LISTS (v17.26).
	-- The kit shipped the top icon row (SmallButtonList, horizontal) and the
	-- main button column (ButtonList, vertical) as two INDEPENDENT UILists with
	-- nothing linking them. A UIList only ever moves INSIDE itself: LUI.UIList.new
	-- registers LUI_KEY_UP/DOWN/LEFT/RIGHT callbacks that call navigateItem*(),
	-- and GridLayout.navigateItem* returns FALSE at the grid's edge, which leaves
	-- the press unhandled. Focus starts on the icon row (see the bottom of this
	-- function), so on a gamepad the stick walked the four icons and DOWN did
	-- NOTHING — Return To Game / Restart Level / Leave Game were unreachable
	-- without a mouse. Mouse HOVER focuses either list directly, which is the
	-- only reason this survived: it is a gamepad/keyboard-only bug, it is
	-- upstream's (map 1's copy of the kit has it too), and a KBM tester with a
	-- hand on the mouse can play the whole menu and never see it.
	--
	-- The framework's own linkage is LUI.UIElement.navigation — the
	-- {up=,down=,left=,right=} table stock menus set (e.g.
	-- StartMenu_Options_Controls_ButtonLayout wiring its list to its dropdown).
	-- We deliberately do NOT use it. A UIList hands each ITEM an empty navigation
	-- table and its own table is only reached after the press bubbles, so whether
	-- the list's internal move or the navigation hop wins depends on the relative
	-- order of two different input paths: the ButtonBits model subscriptions that
	-- drive buttonFunctions, and the gamepad_button event that drives
	-- handleGamepadButton. Lose that race and UP jumps out of the column from the
	-- middle instead of stepping a row. So instead we REPLACE the two edge
	-- callbacks — a second AddButtonCallbackFunction for the same element+button
	-- overwrites element.buttonFunctions[button] — and ONE handler owns each
	-- direction. Every handler tries the list's own move first and only hops when
	-- that returns false, so movement inside a list is byte-for-byte the stock
	-- behaviour.
	--
	-- The hop replays the two steps stock's doNavigationForElement performs —
	-- gain_focus on the target, then lose_focus on the source with
	-- ignoreFocusCheck — but it does NOT gate on the gain_focus RETURN VALUE the
	-- way stock does. The decompiled `LUI.UIList.gainFocus` is lossy (dead
	-- stores, no visible return), so what it hands back here is UNKNOWN, and a
	-- wrong guess either strands focus on nothing or leaves both lists lit. We
	-- gate on the OBSERVABLE post-condition instead: `hasListFocus`, the flag
	-- `UIList.loseFocus` and `setListItemInFocus` both read. If the target
	-- refuses, focus stays exactly where it was — the failure mode is "the press
	-- does nothing", which is today's behaviour, never a dead panel.
	--
	-- Guard: game-over mode makes SmallButtonList NOT focusable and the Game
	-- Settings page hides it, so TodHopLists refuses a non-focusable target and
	-- UP at the top of the column is simply inert in both — never a dead panel.
	local TodHopLists = function(from, to, hopController, dir)
		if to == nil or to.m_focusable == false then
			return false
		end
		local took = to:processEvent({
			name = "gain_focus",
			controller = hopController,
			button = dir
		})
		if took ~= true and to.hasListFocus ~= true then
			return false
		end
		from:processEvent({
			name = "lose_focus",
			controller = hopController,
			button = dir,
			ignoreFocusCheck = true
		})
		return true
	end

	self:AddButtonCallbackFunction(self.SmallButtonList, controller, Enum.LUIButton.LUI_KEY_DOWN, "DOWNARROW", function(element, menu, cbController, model)
		if self.SmallButtonList.m_disableNavigation then
			return false
		end
		if self.SmallButtonList:navigateItemDown() then
			return true
		end
		return TodHopLists(self.SmallButtonList, self.ButtonList, cbController, "down")
	end, nil, false)

	self:AddButtonCallbackFunction(self.ButtonList, controller, Enum.LUIButton.LUI_KEY_UP, "UPARROW", function(element, menu, cbController, model)
		if self.ButtonList.m_disableNavigation then
			return false
		end
		if self.ButtonList:navigateItemUp() then
			return true
		end
		return TodHopLists(self.ButtonList, self.SmallButtonList, cbController, "up")
	end, nil, false)

	-- Add fade animations to ButtonList and SmallButtonList
	self.ButtonList.clipsPerState = {
		DefaultState = {
			FadeIn = function()
				self.ButtonList:completeAnimation()
				self.ButtonList:setAlpha(1, 150)
			end,
			FadeOut = function()
				self.ButtonList:completeAnimation()
				self.ButtonList:setAlpha(0, 150)
			end
		}
	}
	
	self.SmallButtonList.clipsPerState = {
		DefaultState = {
			FadeIn = function()
				self.SmallButtonList:completeAnimation()
				self.SmallButtonList:setAlpha(1, 150)
			end,
			FadeOut = function()
				self.SmallButtonList:completeAnimation()
				self.SmallButtonList:setAlpha(0, 150)
			end
		}
	}
	
	-- Add fade animations to OptionsHeaderText
	self.OptionsHeaderText.clipsPerState = {
		DefaultState = {
			FadeIn = function()
				self.OptionsHeaderText:completeAnimation()
				self.OptionsHeaderText:setAlpha(1, 150)
			end,
			FadeOut = function()
				self.OptionsHeaderText:completeAnimation()
				self.OptionsHeaderText:setAlpha(0, 150)
			end
		}
	}

	-- Signature Images (optional)
	if ShowSignatures then
		self.KingsLayerKyleSignature = LUI.UIImage.new()
		self.KingsLayerKyleSignature:setLeftRight(true, false, 0, 125)
		self.KingsLayerKyleSignature:setTopBottom(true, false, 637, 720)
		self.KingsLayerKyleSignature:setImage(RegisterImage("i_mtl_ui_icon_kingslayer_kyle_signature"))
		self:addElement(self.KingsLayerKyleSignature)

		self.OwenC137Signature = LUI.UIImage.new()
		self.OwenC137Signature:setLeftRight(true, false, 128, 253)
		self.OwenC137Signature:setTopBottom(true, false, 637, 720)
		self.OwenC137Signature:setImage(RegisterImage("i_mtl_ui_icon_owenc137_signature"))
		self:addElement(self.OwenC137Signature)

		self.ShidouriSignature = LUI.UIImage.new()
		self.ShidouriSignature:setLeftRight(true, false, 255, 380)
		self.ShidouriSignature:setTopBottom(true, false, 637, 720)
		self.ShidouriSignature:setImage(RegisterImage("i_mtl_ui_icon_shidouri_signature"))
		self:addElement(self.ShidouriSignature)

		self.MadgazSignature = LUI.UIImage.new()
		self.MadgazSignature:setLeftRight(true, false, 383, 508)
		self.MadgazSignature:setTopBottom(true, false, 637, 720)
		self.MadgazSignature:setImage(RegisterImage("i_mtl_ui_icon_madgaz_signature"))
		self:addElement(self.MadgazSignature)
	end

	-- Button Callbacks
	self:AddButtonCallbackFunction(self, controller, Enum.LUIButton.LUI_KEY_XBB_PSCIRCLE, nil, function(element, menu, controller, model)
		RefreshLobbyRoom(menu, controller)
		StartMenuGoBack(menu, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_XBB_PSCIRCLE, "MENU_BACK")
		return true
	end, false)

	self:AddButtonCallbackFunction(self, controller, Enum.LUIButton.LUI_KEY_START, "M", function(element, menu, controller, model)
		RefreshLobbyRoom(menu, controller)
		StartMenuGoBack(menu, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_START, "MENU_DISMISS_MENU")
		return true
	end, false)

	self:AddButtonCallbackFunction(self, controller, Enum.LUIButton.LUI_KEY_NONE, "ESCAPE", function(element, menu, controller, model)
		RefreshLobbyRoom(menu, controller)
		StartMenuGoBack(menu, controller)
		return true
	end, function(element, menu, controller)
		CoD.Menu.SetButtonLabel(menu, Enum.LUIButton.LUI_KEY_NONE, "")
		return true
	end, false, true)

	self:processEvent({
		name = "menu_loaded",
		controller = controller
	})

	self:processEvent({
		name = "update_state",
		menu = self
	})

	-- [tod] game-over mode visuals (see TodGoActive above): retitle, hide the
	-- pause-only top row of settings icons (and take it out of focus navigation
	-- so up/down can never land on an invisible list), and put initial focus
	-- straight on the two-entry button list. One guarded block — a failure here
	-- may cost polish but can never take down the menu.
	local todGo = TodGoActive(controller)
	if todGo then
		pcall(function()
			self.PauseMenuText:setText(Engine.Localize(TodGoWon(controller) and "Victory" or "Game Over"))
			self.SmallButtonList:setAlpha(0)
		end)
		pcall(function()
			self.SmallButtonList:makeNotFocusable()
		end)
	end

	if todGo then
		self.ButtonList:processEvent({
			name = "gain_focus",
			controller = controller
		})
	elseif not self:restoreState() then
		-- Give initial focus to small buttons
		self.SmallButtonList:processEvent({
			name = "gain_focus",
			controller = controller
		})
	end

	if PostLoadFunc then
		PostLoadFunc(self, controller)
	end

	LUI.OverrideFunction_CallOriginalSecond(self, "close", function(element)
		-- The old fixed list omitted OptionsList, upgrade plates/pips/text and
		-- the controls legend. Close every direct child, including locals that
		-- have no named member. UIList.close also releases its item bindings.
		local child = element:getFirstChild()
		while child do
			local nextChild = child:getNextSibling()
			child:close()
			child = nextChild
		end
		Engine.UnsubscribeAndFreeModel(Engine.GetModel(Engine.GetModelForController(controller), "StartMenu_Main.buttonPrompts"))
	end)

	return self
end
