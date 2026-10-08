-- =============================================================================
-- TodKeycap.lua — ONE WRITER for the bind name drawn inside `i_tod_key_blank_wide`.
--
-- WHY THIS FILE EXISTS. Three surfaces draw a keyboard bind inside that pale
-- keycap — the class draft (2 switch caps + 4 card lock caps), the deal panel
-- (2 switch caps + 2 card lock caps) and the pause menu's UPGRADE CARDS legend
-- (3 caps). They were three independent copies of the same arithmetic, and the
-- repo has already paid twice for control copy that lives on three surfaces
-- (v16.83 fixed the wording on two of three; v16.93 fixed the third).
--
-- THE KEY NAME IS SET IN THE MAP'S OWN TYPEFACE (v17.27, user 2026-09-04:
-- *"is it possible to use our typography alphabet and numbers instead of
-- LUI"*). Same baked glyph sheets as the gun HUD and the ROUND readout, through
-- the shared `CoD.TodGlyphRow`. That is not only a look — it is the fix for the
-- size problem, because a glyph row can be MEASURED before it is drawn and a
-- LUI text string cannot.
--
-- ---------------------------------------------------------------------------
-- THE HISTORY THIS REPLACES, because two builds were spent on the wrong model.
--
--   v16.88 put a LUI text inside the cap. v17.4 saw it overflow, grew the cap
--   72x36 -> 96x48 and scaled the text box with it. v17.24 (this file's first
--   version) read the repo's standing belief — *"if the line overflows the
--   pill, shrink the box height"* (v16.32) — as fact, and drove the BOX HEIGHT
--   to fit an ESTIMATED character width.
--
--   THE USER'S SCREENSHOT KILLED THAT MODEL. Measured off it: the right switch
--   cap drew `G OR MIDDLE MOUSE` — 17 characters — in roughly 61 canvas px,
--   about 3.6 px per character. A 30 px box at scale 0.72 would have to be
--   drawing a ~22 px font, and nothing that size fits 17 characters in 61 px. So
--   in this LUI **the font is a fixed base times `setScale`, and the element's
--   box height does not size it at all** — the v16.32 note said of itself that
--   it was a first guess, and it was wrong. Every box-height write in v17.24 was
--   INERT. The complaint was never overflow at all: the text was TINY, ~8 px,
--   dwarfed by the baked HOLD / TO LOCK lettering three pixels away from it.
--
--   THE LESSON, and it is the map's own: a guard nobody has watched fire is not
--   a guard. A sizing model nobody has measured is not a model — and two builds
--   of arithmetic were written on top of this one before a picture was taken.
-- ---------------------------------------------------------------------------
--
-- WHAT THE GLYPH ROW BUYS. `CoD.TodGlyphRow.measure()` returns the exact canvas
-- width of a string at a given cap height, out of the GENERATED metrics that
-- `tools/slice_hud_sheets.js` reads from the art's own alpha channel. So the fit
-- is EXACT, there is no estimated character width left to calibrate, and a
-- redrawn glyph re-fits itself on the next slice. The size is now chosen the way
-- it should always have been: pick a cap height as a fraction of the keycap, and
-- shrink it only if the MEASURED string will not fit the face.
--
-- A MULTI-BOUND ACTION STILL NAMES EVERY KEY. `+frag` sits on BOTH `G` and
-- `MOUSE3` in the user's `players/bindings_0.cfg`, and the engine renders that
-- as the literal string `G OR MIDDLE MOUSE` (read off the screenshot — that is
-- also where the separator, " OR ", is confirmed from). A keycap advertises ONE
-- key, so Name() trims at the separator. Note what this proves in passing: a key
-- DISPLAY NAME CAN CONTAIN A SPACE, so a plain space is never a separator.
--
-- THE CAP'S GEOMETRY IS MEASURED, NOT GUESSED. `i_tod_key_blank_wide` is
-- 384x192; decoding it, the BRIGHT face runs x 29..354 and y 19..148, with a
-- dark outline at y~152 and a grey bottom lip below that. So the face is inset
-- 7.6% each side and its centre sits at 43.5% of the cap height — NOT 50%, which
-- is where every caller used to centre, pushing glyph bottoms onto the lip.
-- Re-measure if the art is ever re-baked (recipe in the v17.24 changelog entry).
-- =============================================================================

require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodGlyphRow" )

CoD.TodKeycap = {}

-- Bright-face geometry, as fractions of the DRAWN cap rect (measured above).
CoD.TodKeycap.FACE_X  = 0.076   -- left/right inset of the readable face
CoD.TodKeycap.FACE_CY = 0.435   -- vertical centre of the readable face

-- Letter CAP HEIGHT as a fraction of the drawn keycap's height. 0.52 is sized
-- against the baked plate it sits inside: `i_tod_hold_plate`'s own HOLD /
-- TO LOCK lettering runs about 0.41 of the plate, and the keycap is shorter than
-- the plate, so 0.52 of the cap lands the two at the same optical size. This is
-- the knob to move if the key still reads small, or now reads large.
CoD.TodKeycap.CAP_FRAC = 0.52

-- Per-keycap glyph pool. Long enough for every single-key display name that
-- matters — MWHEELDOWN (10), MIDDLE MOUSE (11 glyphs), BACKSPACE (9). A name
-- that would not fit the pool falls back to LUI text rather than being silently
-- TRUNCATED, which is what `row.set` does on its own (see its header).
CoD.TodKeycap.POOL = 12

-- Dark ink on the pale cap. The glyph art is a light face with a dark outline,
-- so the tint MULTIPLIES both down into one dark, legible silhouette.
CoD.TodKeycap.INK_R = 0.10
CoD.TodKeycap.INK_G = 0.13
CoD.TodKeycap.INK_B = 0.20

-- ---------------------------------------------------------------------------
-- Name( token ) -> the single key to print, upper-cased for the glyph sheet.
--
-- Localize first (the engine substitutes the live bind at the moment the string
-- is built), strip colour codes, then cut at the first separator. `,`, `/` and
-- the word `OR` are separators; A PLAIN SPACE IS NOT — `MIDDLE MOUSE` is one
-- key's name, and cutting there would print `MIDDLE` and lie about the bind.
--
-- If the token does not resolve, the literal `[{+frag}]` comes back; it has no
-- glyphs, so it lands on the LUI fallback and stays visible as the diagnostic it
-- is, rather than disappearing.
-- ---------------------------------------------------------------------------
function CoD.TodKeycap.Name( token )
	local s = Engine.Localize( token ) or ""
	s = s:gsub( "%^%d", "" )
	local cut = s:find( "%s*[,/]" ) or s:find( "%s+[Oo][Rr]%s+" )
	if cut and cut > 1 then
		s = s:sub( 1, cut - 1 )
	end
	s = s:gsub( "^%s+", "" ):gsub( "%s+$", "" )
	return string.upper( s )
end

-- ---------------------------------------------------------------------------
-- [tod v17.55] THE DEVICE READ, user 2026-09-04: *"There are 3 sets of
-- controls ... dpad and A, rt lt and A, and KBM. I dont even want rt lt as an
-- option for the UI. The UI should only show dpad options or KBM."*
--
-- WHAT THE THIRD SET WAS. Every surface picked pad glyphs vs keycaps off
-- CoD.TodPad, the one-way d-pad latch. A pad player who had not yet pressed the
-- d-pad got the KEYCAP layout — and the engine filled those caps with the pad's
-- own button names for the offhand pair ("LT" / "RT") and "A" for jump. That is
-- the "rt lt and A" set: keyboard art wearing controller words. It was never
-- designed; it is what a latch that starts false draws to a pad.
--
-- THE READ WAS ALREADY ON SCREEN. Engine.Localize expands a [{+bind}] token
-- into the name bound on the device the client is USING (that is how a pad
-- player came to read "LT"). So the expansion itself proves the device: if the
-- offhand pair resolves to a pad button name, this client is on a pad. That is
-- the device read docs/88 §"The device-detection problem" was looking for —
-- bounded to what it can prove (a pad name proves a pad; a keyboard name proves
-- a keyboard). Tested on the OFFHAND PAIR only: A/B/X/Y are also keyboard keys,
-- so +gostand can never decide it.
--
-- ONE READER. PadDevice() is the only place the choice is made — the two card
-- menus and the pause legend all call it — so the three surfaces cannot drift
-- (the v16.83/v16.93 lesson). The d-pad latch stays as a second proof, OR'd in.
-- ---------------------------------------------------------------------------
function CoD.TodKeycap.IsPadName( s )
	if not s or s == "" then
		return false
	end
	-- Xbox: LB RB LT RT; PlayStation: L1 R1 L2 R2; long forms if the engine
	-- ever spells them out; a d-pad direction.
	if s:match( "^[LR][BT12]$" ) then
		return true
	end
	if s:find( "TRIGGER", 1, true ) or s:find( "BUMPER", 1, true ) or s:find( "DPAD", 1, true ) or s:find( "D-PAD", 1, true ) then
		return true
	end
	return false
end

-- ---------------------------------------------------------------------------
-- [tod v18.32] IsPadGlyph( s ) -> the expansion is a BUTTON PICTURE.
--
-- ⚠️ THIS CORRECTS THE MECHANISM THIS WHOLE FILE WAS BUILT ON. v17.55 and
-- v18.16 both assumed a pad expands `[{+smoke}]` to the TEXT "LT", and matched
-- on that name. The user's 2026-09-08 screenshot shows what it actually is: a
-- trigger-shaped BUTTON ICON with LT printed on it, drawn INSIDE the keycap.
-- The proof is in the picture itself — no code path draws a pad image and a
-- keycap together (every one is an if/else), so the only place that icon can
-- have come from is the keycap's own LUI-text fallback, i.e. out of the
-- expansion. The 2026-09-03 note that recorded "the engine draws letters, never
-- a picture" read `lt < Switch > rt` off a screen; those were the LABELS ON THE
-- ICONS. Same class of error as the v14.58 "HoldX" transcription that memory
-- itself warns about: a glyph and its name look identical in a transcription.
--
-- MATCH ON STRUCTURE, NOT ON SPELLING — BUT ONLY ON HIGH BYTES.
--
-- ⚠️ v18.47 SHIPPED THIS AS `b < 32 or b > 126` AND IT MADE EVERY KEYBOARD
-- PLAYER A CONTROLLER (user, same day: *"Where is the KBM controls. All i see
-- are controller controls"*). Something in the keyboard expansion carries a LOW
-- control byte — a trailing NUL off the engine's C string is the obvious
-- candidate — so the low half of the test fired on every device and the whole
-- UI went to pad art. The high half is the part with an actual argument behind
-- it: a keyboard key DISPLAY NAME is printable ASCII (SPACE, F, MOUSE3, MIDDLE
-- MOUSE, MWHEELDOWN), and a button picture has to reach the font as something
-- outside it. Control characters prove nothing either way, so they are ignored.
--
-- AND THIS IS NO LONGER A DEVICE TEST. It decides ONE thing — "may this string
-- be drawn inside a keycap?" — and it is consulted only AFTER the baked
-- typeface has already failed to draw it, so a key name our sheets CAN render
-- never reaches it. That ordering is what makes it unable to turn a working
-- keyboard into a controller no matter what bytes the engine hands back. The
-- device question is answered by PadDevice below, on positive proof only.
-- ---------------------------------------------------------------------------
function CoD.TodKeycap.IsPadGlyph( s )
	if not s or s == "" then
		return false
	end
	for i = 1, #s do
		if string.byte( s, i ) > 126 then
			return true
		end
	end
	return false
end

-- Either proof: the icon test above, or the legacy name test (kept because a
-- build that DOES spell the button out must still be caught).
function CoD.TodKeycap.IsPadExpansion( s )
	return CoD.TodKeycap.IsPadGlyph( s ) or CoD.TodKeycap.IsPadName( s )
end

-- ---------------------------------------------------------------------------
-- PadDevice() — KEYBOARD IS THE DEFAULT; A PAD MUST BE PROVEN.
--
-- User 2026-09-08, after v18.47 inverted this: *"I thought we decided on
-- starting KBM controls and if controller is detected we use controller
-- controls."* That is the rule, and it decides the SHAPE of this function: it
-- returns false unless something POSITIVE says pad. Two such proofs, both
-- conservative:
--
--   * the d-pad latch, which the server sets from a real d-pad press;
--   * a pad BUTTON NAME in the offhand expansion (IsPadName — LT/RT/LB/RB/
--     L1/R1/L2/R2 and the spelled-out forms). It cannot match a keyboard key
--     name, so it cannot misfire toward the pad.
--
-- WHAT IS DELIBERATELY NOT HERE ANY MORE: IsPadGlyph. A byte scan looked like a
-- stronger proof and was a WEAKER one — it fired on every device and cost the
-- keyboard its entire control set for a build. A test that can be wrong in the
-- direction of "pad" does not belong in a function whose default is "keyboard".
-- The glyph test still runs, but only where being wrong is cheap: at draw time,
-- after the typeface has failed, deciding one keycap's contents.
--
-- The cost is honest and bounded: a pad player who has not yet pressed the
-- d-pad, on a build where the engine's button icon is not a high byte, reads
-- keycaps until they do. That is the OLD behaviour, and it is the right side to
-- be wrong on.
-- ---------------------------------------------------------------------------
function CoD.TodKeycap.PadDevice()
	if CoD.TodPad == true then
		return true
	end
	local K = CoD.TodKeycap
	-- The offhand pair only: A/B/X/Y are keyboard key names too, so +gostand
	-- can never decide the device by NAME.
	return K.IsPadName( K.Name( "[{+smoke}]" ) ) or K.IsPadName( K.Name( "[{+frag}]" ) )
end

-- ---------------------------------------------------------------------------
-- make( owner, fallbackText ) -> a keycap writer.
--
-- `fallbackText` is the caller's EXISTING UIText element. It is kept, not
-- deleted: a key name with a character the sheets have no cell for (a bracket, a
-- semicolon, an unresolved token) must degrade to readable text, never to a gap.
-- Same doctrine as AetheriumLoadout's `weapon_name`.
--
-- The pool is built ONCE here. Creating elements per update is a documented
-- state-pool leak in this tree.
-- ---------------------------------------------------------------------------
function CoD.TodKeycap.make( owner, fallbackText )
	local K  = CoD.TodKeycap
	local kc = { text = fallbackText }
	kc.row = CoD.TodGlyphRow.make( owner, K.POOL )
	kc.row.setRGB( K.INK_R, K.INK_G, K.INK_B )

	kc.hide = function ()
		kc.row.hide()
		if kc.text then
			kc.text:setAlpha( 0 )
		end
	end

	-- paint( capL, capT, capW, capH, token, alpha )
	-- capL/capT/capW/capH describe the keycap image AS DRAWN. Returns the string.
	kc.paint = function ( capL, capT, capW, capH, token, alpha )
		local s = K.Name( token )
		if alpha == nil then
			alpha = 1
		end
		if s == "" then
			kc.hide()
			return ""
		end

		-- [tod v18.32] A BUTTON PICTURE IS NEVER DRAWN INSIDE A KEYCAP. The
		-- caller has already decided the device; this is the backstop for the
		-- case where that decision was wrong, and it is the exact failure in
		-- the 2026-09-08 screenshot — the LUI-text fallback below happily drew
		-- the engine's LT/RT/A icon on top of the pale cap. Returning nil (not
		-- "") lets a caller that cares re-draw the pad glyph instead; every
		-- caller that does not still gets an EMPTY cap rather than a wrong one.
		if K.IsPadGlyph( s ) then
			kc.hide()
			return nil
		end

		local inset  = capW * K.FACE_X
		local innerW = capW - 2 * inset - 2       -- 2 px of breathing room
		local cy     = capT + capH * K.FACE_CY

		-- Count the glyphs this will actually draw. `row.set` advances its pool
		-- index for every non-space character that HAS a glyph, and the measure
		-- below proves every one of them does — so this count and its count are
		-- the same walk. It is needed only to re-apply a partial alpha, which
		-- set() cannot do (it always draws at 1).
		local glyphs = 0
		for i = 1, #s do
			if string.sub( s, i, i ) ~= " " then
				glyphs = glyphs + 1
			end
		end

		local cap = capH * K.CAP_FRAC
		local w   = kc.row.measure( s, cap, CoD.TodGlyphRow.nameSet )

		if w < 0 or glyphs > K.POOL then
			-- No cell for some character, or more glyphs than the pool holds.
			-- LUI text, sized by SCALE — the box height does not size text in
			-- this build (see the header), so driving it here would do nothing.
			kc.row.hide()
			if kc.text then
				kc.text:setLeftRight( true, false, capL + inset, capL + capW - inset )
				kc.text:setTopBottom( true, false, cy - 8, cy + 8 )
				kc.text:setScale( 1 )
				kc.text:setText( s )
				kc.text:setAlpha( alpha )
			end
			return s
		end

		if w > innerW then
			cap = cap * ( innerW / w )
			w   = innerW
		end

		-- Centred on the face: the row draws RIGHT-aligned, so its right edge is
		-- the cap's centre plus half the measured width. The baseline sits half a
		-- cap-height below the face centre, which centres the INK rather than the
		-- cell.
		kc.row.set( s, cap, capL + capW / 2 + w / 2, cy + cap / 2, CoD.TodGlyphRow.nameSet )
		if alpha < 1 then
			for i = 1, glyphs do
				kc.row.img[ i ]:setAlpha( alpha )
			end
		end
		if kc.text then
			kc.text:setAlpha( 0 )
		end
		return s
	end

	return kc
end

-- [tod v17.30] THE CONTRACT, STATED ONCE. Every caller's fail-safe is a single
-- `if CoD.TodKeycap then` test, so this file must not exist half-alive: without
-- the typeface there is no keycap writer, and the caller takes its LUI-text
-- fallback instead. The `require` above would normally throw first and leave
-- CoD.TodKeycap unassigned — this only covers a TodGlyphRow that loads cleanly
-- and still fails to export, which is the case the single test could not see.
if not CoD.TodGlyphRow then
	CoD.TodKeycap = nil
end
