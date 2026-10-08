-- Compiled using luac for Black Ops III

CoD.PromptMysteryBox = InheritFrom( LUI.UIElement )

-- [tod 2026-09-02, KBM audit] One footer line carrying the engine's bind
-- token, so the key is the player's real bound key or pad glyph (the kit
-- hardcoded "F"). This card is UNREACHABLE on this map (no mystery box;
-- classifyHint has no MysteryBox arm) and is patched only so no literal key
-- name survives anywhere in Prompts/. Full note in PromptDefault.lua.
local HOLD_KEY = "Hold ^3[{+activate}]^7 "
function CoD.PromptMysteryBox.SetFooter( self, verb )
	if not self.footerLine then
		return
	end
	self.footerLine:setText( Engine.Localize( HOLD_KEY .. ( verb or "" ) ) )
end

function CoD.PromptMysteryBox.new( menu, controller )
	local self = LUI.UIElement.new()
	
	if PreLoadFunc then
		PreLoadFunc( self, controller )
	end
	
	self:setUseStencil( false )
	self:setClass( CoD.PromptMysteryBox )
	self.id = "PromptMysteryBox"
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
	
	-- box_text (title)
	self.titleText = LUI.UIText.new()
	self.titleText:setLeftRight(true, false, 620, 754)
	self.titleText:setTopBottom(true, false, 449, 459)
	self.titleText:setText("Mystery Box")
	self.titleText:setTTF("fonts/orbitron.ttf")
	self.titleText:setRGB(1, 1, 1)
	self.titleText:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.titleText)
	
	-- image_6bac5ab6cef2cf7d (decorative border right)
	self.borderRight = LUI.UIImage.new()
	self.borderRight:setLeftRight(true, false, 618, 775)
	self.borderRight:setTopBottom(true, false, 449, 517)
	self.borderRight:setImage(RegisterImage("i_mtl_image_6bac5ab6cef2cf7d"))
	self.borderRight:setRGB(1, 1, 1)
	self:addElement(self.borderRight)

	-- box_description (dynamic - weapon info or default text)
	self.boxDescription = LUI.UIText.new()
	self.boxDescription:setLeftRight(true, false, 620, 766)
	self.boxDescription:setTopBottom(true, false, 467, 474)
	self.boxDescription:setText("Spin for a random weapon")
	self.boxDescription:setTTF("fonts/ltromatic.ttf")
	self.boxDescription:setRGB(1, 1, 1)
	self.boxDescription:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.boxDescription)
	
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
	
	-- box_cost (dynamic - mystery box cost)
	self.boxCost = LUI.UIText.new()
	self.boxCost:setLeftRight(true, false, 740, 773)
	self.boxCost:setTopBottom(true, false, 506, 515)
	self.boxCost:setText("950")
	self.boxCost:setTTF("fonts/ltromatic.ttf")
	self.boxCost:setRGB(0.8941176470588236, 0.8823529411764706, 0.4235294117647059)
	self.boxCost:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.boxCost)
	
	-- (the kit's separate "Hold " element is gone -- the footer line below
	-- carries the whole "Hold <key> <verb>" line; see SetFooter)
	
	-- ui_icons_zombie_essence (points icon)
	self.pointsIcon = LUI.UIImage.new()
	self.pointsIcon:setLeftRight(true, false, 727, 742)
	self.pointsIcon:setTopBottom(true, false, 503, 515)
	self.pointsIcon:setImage(RegisterImage("i_tod_hud_points_icon"))
	self.pointsIcon:setRGB(1, 1, 1)
	self:addElement(self.pointsIcon)
	
	-- box_icon_image (mystery box icon / weapon icon)
	self.boxIcon = LUI.UIImage.new()
	self.boxIcon:setLeftRight(true, false, 559, 602)
	self.boxIcon:setTopBottom(true, false, 455, 498)
	self.boxIcon:setImage(RegisterImage("i_mtl_ui_icon_zm_ping_mystery_box"))
	self.boxIcon:setRGB(1, 1, 1)
	self:addElement(self.boxIcon)
	
	-- interact_text_button
	-- Footer: "Hold <key> To Spin Box" -- one line, key resolved by the engine
	-- (SetFooter above; re-set on every SetMode)
	self.footerLine = LUI.UIText.new()
	self.footerLine:setLeftRight(true, false, 620, 763)
	self.footerLine:setTopBottom(true, false, 507, 515)
	self.footerLine:setTTF("fonts/ltromatic.ttf")
	self.footerLine:setRGB(1, 1, 1)
	self.footerLine:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_LEFT)
	self:addElement(self.footerLine)
	CoD.PromptMysteryBox.SetFooter(self, "To Spin Box")
	
	-- footer_text_2
	-- (the kit's separate "F" and "To Spin Box" elements are gone -- the
	-- footer line above carries both; see SetFooter)
	
	-- Start hidden
	self:setAlpha(0)
	
	if PostLoadFunc then
		PostLoadFunc( self, controller, menu )
	end
	

	-- =========================================================================
	-- [tod 2026-09-22, bug review F23] this card is never routed to (classifyHint
	-- has no arm for it) but is still built per HUD life; its children were
	-- left open on close. Attach the shared owner so they close with it.
	if CoD.TodUIOwnership then CoD.TodUIOwnership.Attach( self ) end
	return self
end

-- SetMode function - Switch between "spin" and "weapon" modes
function CoD.PromptMysteryBox.SetMode( self, mode, weaponName )
	if mode == "weapon" and weaponName then
		-- Weapon pickup mode
		local weaponData = nil
		
		if CoD.GetWeaponDataByName then
			weaponData = CoD.GetWeaponDataByName(weaponName)
		end
		
		if weaponData then
			-- Update with weapon info
			if self.titleText then 
				self.titleText:setText(weaponData.ingame_name or "WEAPON")
			end
			if self.boxDescription then 
				self.boxDescription:setText(weaponData.description or "")
			end
			if self.boxIcon then 
				self.boxIcon:setImage(RegisterImage(weaponData.icon or "blacktransparent"))
				-- Weapon mode icon position
				self.boxIcon:setLeftRight(true, false, 550, 611)
				self.boxIcon:setTopBottom(true, false, 464, 500)
			end
			if self.boxCost then 
				self.boxCost:setAlpha(0)
			end
			if self.pointsIcon then 
				self.pointsIcon:setAlpha(0)
			end
			if self.footerLine then 
				CoD.PromptMysteryBox.SetFooter(self, "To Claim")
			end
		else
			-- Fallback if weapon not found - show the raw name
			if self.titleText then 
				self.titleText:setText(weaponName)
			end
			if self.boxDescription then 
				self.boxDescription:setText("Unknown weapon")
			end
			if self.boxIcon then 
				self.boxIcon:setImage(RegisterImage("blacktransparent"))
				-- Weapon mode icon position
				self.boxIcon:setLeftRight(true, false, 552, 609)
				self.boxIcon:setTopBottom(true, false, 462, 504)
			end
			if self.boxCost then 
				self.boxCost:setAlpha(0)
			end
			if self.pointsIcon then 
				self.pointsIcon:setAlpha(0)
			end
			if self.footerLine then 
				CoD.PromptMysteryBox.SetFooter(self, "To Claim Weapon")
			end
		end
	else
		-- Default "spin box" mode
		if self.titleText then 
			self.titleText:setText("Mystery Box")
		end
		if self.boxDescription then 
			self.boxDescription:setText("Spin for a random weapon")
		end
		if self.boxIcon then 
			self.boxIcon:setImage(RegisterImage("i_mtl_ui_icon_zm_ping_mystery_box"))
			-- Box mode icon position (original)
			self.boxIcon:setLeftRight(true, false, 559, 602)
			self.boxIcon:setTopBottom(true, false, 455, 498)
		end
		if self.boxCost then 
			self.boxCost:setAlpha(1)
			self.boxCost:setText("950")
		end
		if self.pointsIcon then 
			self.pointsIcon:setAlpha(1)
		end
		if self.footerLine then 
			CoD.PromptMysteryBox.SetFooter(self, "To Spin Box")
		end
	end
end

return CoD.PromptMysteryBox