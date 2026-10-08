-- Compiled using luac for Black Ops III

CoD.PromptBBG = InheritFrom( LUI.UIElement )

-- [tod 2026-09-02, KBM audit] One footer line carrying the engine's bind
-- token, so the key is the player's real bound key or pad glyph (the kit
-- hardcoded "F"). This card is UNREACHABLE on this map (no GobbleGum;
-- classifyHint has no BBG arm) and is patched only so no literal key name
-- survives anywhere in Prompts/. Full note in PromptDefault.lua.
local HOLD_KEY = "Hold ^3[{+activate}]^7 "
function CoD.PromptBBG.SetFooter( self, verb )
	if not self.footerLine then
		return
	end
	self.footerLine:setText( Engine.Localize( HOLD_KEY .. ( verb or "" ) ) )
end

function CoD.PromptBBG.new( menu, controller )
    local self = LUI.UIElement.new()
    
    if PreLoadFunc then
        PreLoadFunc( self, controller )
    end
    
	self:setUseStencil( false )
	self:setClass( CoD.PromptBBG )
	self.id = "PromptBBG"
	self.soundSet = "default"
	self:setLeftRight( true, false, 0, 1280 )
	self:setTopBottom( true, false, 0, 720 )
	
	-- image_3a5dcba7b0d44850 (decorative border top)
	self.borderTop = LUI.UIImage.new()
	self.borderTop:setLeftRight(true, false, 616, 772)
	self.borderTop:setTopBottom(true, false, 460, 518)
	self.borderTop:setImage(RegisterImage("i_mtl_image_3a5dcba7b0d44850"))
	self.borderTop:setRGB(1, 1, 1)
	self:addElement(self.borderTop)
	
	-- image_4b19966fe6b8a3f4 (decorative border header)
	self.borderHeader = LUI.UIImage.new()
	self.borderHeader:setLeftRight(true, false, 615, 773)
	self.borderHeader:setTopBottom(true, false, 446, 461)
	self.borderHeader:setImage(RegisterImage("i_mtl_image_4b19966fe6b8a3f4"))
	self.borderHeader:setRGB(1, 1, 1)
	self:addElement(self.borderHeader)
	
	-- bbg_text (title - machine mode)
	self.titleText = LUI.UIText.new()
	self.titleText:setLeftRight(true, false, 620, 754)
	self.titleText:setTopBottom(true, false, 449, 459)
	self.titleText:setText("GobbleGum Machine")
	self.titleText:setTTF("fonts/ltromatic.ttf")
	self.titleText:setRGB(1, 1, 1)
	self.titleText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.titleText)
	
	-- bbg_name_text (pickup mode - specific gobblegum name)
	self.bbgNameText = LUI.UIText.new()
	self.bbgNameText:setLeftRight(true, false, 620, 754)
	self.bbgNameText:setTopBottom(true, false, 449, 459)
	self.bbgNameText:setText("")
	self.bbgNameText:setTTF("fonts/orbitron.ttf")
	self.bbgNameText:setRGB(1, 1, 1)
	self.bbgNameText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self.bbgNameText:setAlpha(0)  -- Hidden by default
	self:addElement(self.bbgNameText)
	
	-- image_6bac5ab6cef2cf7d (decorative border right)
	self.borderRight = LUI.UIImage.new()
	self.borderRight:setLeftRight(true, false, 618, 775)
	self.borderRight:setTopBottom(true, false, 449, 517)
	self.borderRight:setImage(RegisterImage("i_mtl_image_6bac5ab6cef2cf7d"))
	self.borderRight:setRGB(1, 1, 1)
	self:addElement(self.borderRight)

	-- bbg_description
	self.bbgDescription = LUI.UIText.new()
    self.bbgDescription:setLeftRight(true, false, 620, 767)
    self.bbgDescription:setTopBottom(true, false, 467, 474)
	self.bbgDescription:setText("Spin to get a random gobble gum from your pack")
	self.bbgDescription:setTTF("fonts/ltromatic.ttf")
	self.bbgDescription:setRGB(1, 1, 1)
	self.bbgDescription:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.bbgDescription)
	
	-- image_7d9423641070f37e (decorative border left)
	self.borderLeft = LUI.UIImage.new()
	if self.borderLeft then
		self.borderLeft:setLeftRight(true, false, 546, 615)
		self.borderLeft:setTopBottom(true, false, 445, 518)
		self.borderLeft:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
		self.borderLeft:setRGB(1, 1, 1)
		self:addElement(self.borderLeft)
	end
	
	-- image_8a21f7a0f930d3f (decorative border outer)
	self.borderOuter = LUI.UIImage.new()
	self.borderOuter:setLeftRight(true, false, 544, 775)
	self.borderOuter:setTopBottom(true, false, 444, 520)
	self.borderOuter:setImage(RegisterImage("i_mtl_image_8a21f7a0f930d3f"))
	self.borderOuter:setRGB(1, 1, 1)
	self:addElement(self.borderOuter)
	
	-- bbg_cost (dynamic cost from hint)
	self.bbgCost = LUI.UIText.new()
	self.bbgCost:setLeftRight(true, false, 740, 773)
	self.bbgCost:setTopBottom(true, false, 506, 515)
	self.bbgCost:setText("1500")
	self.bbgCost:setTTF("fonts/ltromatic.ttf")
	self.bbgCost:setRGB(0.8941176470588236, 0.8823529411764706, 0.4235294117647059)
	self.bbgCost:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.bbgCost)
	
	-- (the kit's separate "Hold " element is gone -- the footer line below
	-- carries the whole "Hold <key> <verb>" line; see SetFooter)
	
	-- ui_icons_zombie_essence (points icon)
	self.pointsIcon = LUI.UIImage.new()
	self.pointsIcon:setLeftRight(true, false, 727, 742)
	self.pointsIcon:setTopBottom(true, false, 503, 515)
	self.pointsIcon:setImage(RegisterImage("i_tod_hud_points_icon"))
	self.pointsIcon:setRGB(1, 1, 1)
	self:addElement(self.pointsIcon)
	
	-- bbg_icon_image (GobbleGum icon)
	self.bbgIcon = LUI.UIImage.new()
	self.bbgIcon:setLeftRight(true, false, 562, 599)
	self.bbgIcon:setTopBottom(true, false, 463, 500)
	self.bbgIcon:setImage(RegisterImage("i_mtl_ui_icon_zm_ping_gobblegum_machine"))
	self.bbgIcon:setRGB(1, 1, 1)
	self:addElement(self.bbgIcon)
	
	-- interact_text_button
	-- Footer: "Hold <key> To Dispense" -- one line, key resolved by the engine
	-- (SetFooter above; re-set on every SetMode)
	self.footerLine = LUI.UIText.new()
	self.footerLine:setLeftRight(true, false, 620, 724)
	self.footerLine:setTopBottom(true, false, 507, 515)
	self.footerLine:setTTF("fonts/ltromatic.ttf")
	self.footerLine:setRGB(1, 1, 1)
	self.footerLine:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.footerLine)
	CoD.PromptBBG.SetFooter(self, "To Dispense")
	
	-- footer_text_2
	-- (the kit's separate "F" and "To Dispense" elements are gone -- the
	-- footer line above carries both; see SetFooter)
	
	-- Start hidden
	self:setAlpha(0)
    
    if PostLoadFunc then
        PostLoadFunc( self, controller, menu )
    end
    
    -- [tod 2026-09-22, bug review F23] this card is never routed to (classifyHint
    -- has no arm for it) but is still built per HUD life; its children were
    -- left open on close. Attach the shared owner so they close with it.
    if CoD.TodUIOwnership then CoD.TodUIOwnership.Attach( self ) end
    return self
end

-- SetMode function to switch between machine and pickup modes
-- Modes: "machine" (default dispense) or "pickup" (specific gobblegum)
function CoD.PromptBBG.SetMode( self, mode, ggData )
	if mode == "pickup" and ggData then
		-- PICKUP MODE - Specific gobblegum collection
		
		-- Hide machine title, show gobblegum name
		if self.titleText then
			self.titleText:setAlpha(0)
		end
		if self.bbgNameText and ggData.name then
			self.bbgNameText:setText( ggData.name )
			self.bbgNameText:setAlpha(1)
		end
		
		-- Update description
		if self.bbgDescription and ggData.description then
			self.bbgDescription:setText( ggData.description )
		end
		
		-- Update footer text to "To Retrieve"
		if self.footerLine then
			CoD.PromptBBG.SetFooter( self, "To Retrieve" )
		end
		
		-- Update icon to specific gobblegum
		if self.bbgIcon and ggData.icon then
			self.bbgIcon:setImage( RegisterImage( ggData.icon ) )
		end
		
		-- Hide cost and points icon (not needed for pickup)
		if self.bbgCost then
			self.bbgCost:setAlpha(0)
		end
		if self.pointsIcon then
			self.pointsIcon:setAlpha(0)
		end
		
	else
		-- MACHINE MODE - Default dispense prompt
		
		-- Show machine title, hide gobblegum name
		if self.titleText then
			self.titleText:setAlpha(1)
		end
		if self.bbgNameText then
			self.bbgNameText:setAlpha(0)
		end
		
		-- Reset description to default 
		if self.bbgDescription then
			self.bbgDescription:setText( "Spin to get a random gobble gum from your pack" )
		end
		
		-- Reset footer text to "To Dispense"
		if self.footerLine then
			CoD.PromptBBG.SetFooter( self, "To Dispense" )
		end
		
		-- Reset icon to default machine icon
		if self.bbgIcon then
			self.bbgIcon:setImage( RegisterImage( "i_mtl_ui_icon_zm_ping_gobblegum_machine" ) )
		end
		
		-- Show cost and points icon
		if self.bbgCost then
			self.bbgCost:setAlpha(1)
		end
		if self.pointsIcon then
			self.pointsIcon:setAlpha(1)
		end
	end
end

return CoD.PromptBBG