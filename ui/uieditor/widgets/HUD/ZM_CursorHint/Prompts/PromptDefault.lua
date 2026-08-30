-- Default Prompt Widget - Shows for any hint we don't customize
CoD.PromptDefault = InheritFrom( LUI.UIElement )

function CoD.PromptDefault.new( menu, controller )
	local self = LUI.UIElement.new()
	
	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end
	
	self:setUseStencil( false )
	self:setClass( CoD.PromptDefault )
	self.id = "PromptDefault"
	self.soundSet = "HUD"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	self:setAlpha( 0 )  -- Start hidden
	
	-- image_3a5dcba7b0d44850
	self.bgMain = LUI.UIImage.new()
	self.bgMain:setLeftRight(true, false, 616, 772)
	self.bgMain:setTopBottom(true, false, 447, 518)
	self.bgMain:setImage(RegisterImage("i_mtl_image_3a5dcba7b0d44850"))
	self.bgMain:setRGB(1, 1, 1)
	self:addElement(self.bgMain)
	
	-- image_6bac5ab6cef2cf7d
	self.bgFrame = LUI.UIImage.new()
	self.bgFrame:setLeftRight(true, false, 618, 775)
	self.bgFrame:setTopBottom(true, false, 449, 517)
	self.bgFrame:setImage(RegisterImage("i_mtl_image_6bac5ab6cef2cf7d"))
	self.bgFrame:setRGB(1, 1, 1)
	self:addElement(self.bgFrame)
	
	-- image_7d9423641070f37e
	self.bgIcon = LUI.UIImage.new()
	self.bgIcon:setLeftRight(true, false, 546, 615)
	self.bgIcon:setTopBottom(true, false, 445, 518)
	self.bgIcon:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
	self.bgIcon:setRGB(1, 1, 1)
	self:addElement(self.bgIcon)
	
	-- Description (hint text - dynamically set)
	self.hintText = LUI.UIText.new()
	self.hintText:setLeftRight(true, false, 620, 766)
	self.hintText:setTopBottom(true, false, 467, 474)
	self.hintText:setText(Engine.Localize("Hint text here"))
	self.hintText:setTTF("fonts/ltromatic.ttf")
	self.hintText:setRGB(1, 1, 1)
	self.hintText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.hintText)
	
	-- image_8a21f7a0f930d3f
	self.bgBorder = LUI.UIImage.new()
	self.bgBorder:setLeftRight(true, false, 544, 775)
	self.bgBorder:setTopBottom(true, false, 444, 520)
	self.bgBorder:setImage(RegisterImage("i_mtl_image_8a21f7a0f930d3f"))
	self.bgBorder:setRGB(1, 1, 1)
	self:addElement(self.bgBorder)
	
	-- i_mtl_ui_icon_zm_ping_documents
	self.defaultIcon = LUI.UIImage.new()
	self.defaultIcon:setLeftRight(true, false, 556, 607)
	self.defaultIcon:setTopBottom(true, false, 457, 506)
	self.defaultIcon:setImage(RegisterImage("i_mtl_ui_icon_zm_ping_documents"))
	self.defaultIcon:setRGB(1, 1, 1)
	self:addElement(self.defaultIcon)
	
	-- [tod 2026-08-21] LIVE HINT TEXT.
	-- BUG THIS FIXES: hintText was hardcoded to the placeholder "Hint text
	-- here" and never bound to anything, so EVERY interactable that falls
	-- through to the default prompt (our upgrade stations, and anything else
	-- the dispatcher does not special-case) literally rendered "Hint text
	-- here" on screen — the user's "text that doesn't really make sense".
	-- Subscribe to the same model the working prompts use (PromptDoors:142).
	--
	-- The raw hint carries GSC colour codes (^3 ... ^7) and a button token
	-- ({+activate}); strip the colours and drop the leading "Hold [btn]"
	-- since this prompt already draws its own button glyph, then show the
	-- action and its price on one clean line.
	self:subscribeToModel(Engine.GetModel(Engine.GetModelForController(controller), "hudItems.cursorHintText"), function(model)
		local hintText = Engine.GetModelValue(model)
		if not hintText or hintText == "" then
			return
		end
		local t = hintText
		t = string.gsub(t, "%^%d", "")            -- ^3 / ^7 colour codes
		-- KEEP THE INSTRUCTION (map-wide UI audit 2026-08-28). The two lines
		-- below used to delete the button token AND the leading "Hold", on the
		-- stated premise that this prompt draws its own glyph — IT DOES NOT.
		-- PromptDefault has no interactButton and no footer trio (PromptDoors
		-- has both, :113-136); this widget is only a background, an icon and
		-- ONE line of text. So every interactable routed here — the 12,000
		-- EXTRACTION, the ammo crates, the upgrade stations, the class-swap
		-- stations, the teleporters — rendered its action and price with
		-- nothing telling the player to hold USE at all.
		-- Render the token as the key instead of deleting it, matching the
		-- kit's own hardcoded "F" (PromptDoors:126).
		t = string.gsub(t, "%[{%+[%w_]+}%]", "[F]")
		t = string.gsub(t, "^%s+", "")
		t = string.gsub(t, "%s+$", "")
		t = string.gsub(t, "%s%s+", " ")          -- collapse doubled spaces
		if t ~= "" then
			self.hintText:setText(t)
		end
	end)

	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end

	return self
end
