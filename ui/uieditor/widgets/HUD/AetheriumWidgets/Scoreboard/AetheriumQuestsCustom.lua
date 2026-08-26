-- Aetherium Quests/Quest Items Widget (extracted from scoreboard)

CoD.AetheriumQuestsCustom = InheritFrom( LUI.UIElement )

function CoD.AetheriumQuestsCustom.new(menu, controller)
    local self = LUI.UIElement.new()

    self:setUseStencil(false)
    self:setClass(CoD.AetheriumQuestsCustom)
    self.id = "AetheriumQuestsCustom"
    self.soundSet = "default"
    self:setLeftRight(true, false, 0, 1280)
    self:setTopBottom(true, false, 0, 720)

    -- Quest color header
    self.quest_color_header = LUI.UIImage.new()
    self.quest_color_header:setLeftRight(true, false, 0, 1280)
    self.quest_color_header:setTopBottom(true, false, 0, 107)
    self.quest_color_header:setImage(RegisterImage("i_mtl_image_570a038958e924a7"))
    self.quest_color_header:setRGB(1, 1, 1)
    self:addElement(self.quest_color_header)

    -- Quest Items Text
    self.quest_items_text = LUI.UIText.new()
    self.quest_items_text:setLeftRight(true, false, 512, 686)
    self.quest_items_text:setTopBottom(true, false, 83, 98)
    self.quest_items_text:setText(Engine.Localize("Quest Items"))
    self.quest_items_text:setTTF("fonts/ltromatic.ttf")
    self.quest_items_text:setRGB(1, 1, 1)
    self.quest_items_text:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
    self:addElement(self.quest_items_text)

    -- Quest Item Background
    self.quest_item_bg = LUI.UIImage.new()
    self.quest_item_bg:setLeftRight(true, false, 16, 1258)
    self.quest_item_bg:setTopBottom(true, false, 104, 182)
    self.quest_item_bg:setImage(RegisterImage("i_mtl_sat_quest_widget"))
    self.quest_item_bg:setRGB(1, 1, 1)
    self:addElement(self.quest_item_bg)

    -- ========================================
    -- QUEST ITEM ICONS & TEXT (copied as-is)
    -- ========================================

    -- Power Section
    self.power_text = LUI.UIText.new()
    self.power_text:setLeftRight(true, false, 118, 191)
    self.power_text:setTopBottom(true, false, 112, 121)
    self.power_text:setText(Engine.Localize("Power"))
    self.power_text:setTTF("fonts/ltromatic.ttf")
    self.power_text:setRGB(1, 1, 1)
    self.power_text:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
    self:addElement(self.power_text)

    self.power_icon = LUI.UIImage.new()
    self.power_icon:setLeftRight(true, false, 129, 180)
    self.power_icon:setTopBottom(true, false, 124, 175)
    self.power_icon:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
    self.power_icon:setRGB(1, 1, 1)
    self:addElement(self.power_icon)

    -- Shield Parts Section
    self.shield_text = LUI.UIText.new()
    self.shield_text:setLeftRight(true, false, 234, 381)
    self.shield_text:setTopBottom(true, false, 111, 122)
    self.shield_text:setText(Engine.Localize("Shield Parts"))
    self.shield_text:setTTF("fonts/ltromatic.ttf")
    self.shield_text:setRGB(1, 1, 1)
    self.shield_text:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
    self:addElement(self.shield_text)

    self.shield_icon_1 = LUI.UIImage.new()
    self.shield_icon_1:setLeftRight(true, false, 230, 281)
    self.shield_icon_1:setTopBottom(true, false, 124, 175)
    self.shield_icon_1:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
    self.shield_icon_1:setRGB(1, 1, 1)
    self:addElement(self.shield_icon_1)

    self.shield_icon_2 = LUI.UIImage.new()
    self.shield_icon_2:setLeftRight(true, false, 281, 332)
    self.shield_icon_2:setTopBottom(true, false, 124, 175)
    self.shield_icon_2:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
    self.shield_icon_2:setRGB(1, 1, 1)
    self:addElement(self.shield_icon_2)

    self.shield_icon_3 = LUI.UIImage.new()
    self.shield_icon_3:setLeftRight(true, false, 332, 383)
    self.shield_icon_3:setTopBottom(true, false, 124, 175)
    self.shield_icon_3:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
    self.shield_icon_3:setRGB(1, 1, 1)
    self:addElement(self.shield_icon_3)

    -- Easter Egg Items Section
    self.ee_text = LUI.UIText.new()
    self.ee_text:setLeftRight(true, false, 496, 639)
    self.ee_text:setTopBottom(true, false, 111, 119)
    self.ee_text:setText(Engine.Localize("Easter Egg Items"))
    self.ee_text:setTTF("fonts/ltromatic.ttf")
    self.ee_text:setRGB(1, 1, 1)
    self.ee_text:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
    self:addElement(self.ee_text)

    self.ee_icon_1 = LUI.UIImage.new()
    self.ee_icon_1:setLeftRight(true, false, 435, 486)
    self.ee_icon_1:setTopBottom(true, false, 124, 175)
    self.ee_icon_1:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
    self.ee_icon_1:setRGB(1, 1, 1)
    self:addElement(self.ee_icon_1)

    self.ee_icon_2 = LUI.UIImage.new()
    self.ee_icon_2:setLeftRight(true, false, 486, 537)
    self.ee_icon_2:setTopBottom(true, false, 124, 175)
    self.ee_icon_2:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
    self.ee_icon_2:setRGB(1, 1, 1)
    self:addElement(self.ee_icon_2)

    self.ee_icon_3 = LUI.UIImage.new()
    self.ee_icon_3:setLeftRight(true, false, 537, 588)
    self.ee_icon_3:setTopBottom(true, false, 124, 175)
    self.ee_icon_3:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
    self.ee_icon_3:setRGB(1, 1, 1)
    self:addElement(self.ee_icon_3)

    self.ee_icon_4 = LUI.UIImage.new()
    self.ee_icon_4:setLeftRight(true, false, 588, 639)
    self.ee_icon_4:setTopBottom(true, false, 124, 175)
    self.ee_icon_4:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
    self.ee_icon_4:setRGB(1, 1, 1)
    self:addElement(self.ee_icon_4)

    self.ee_icon_5 = LUI.UIImage.new()
    self.ee_icon_5:setLeftRight(true, false, 638, 689)
    self.ee_icon_5:setTopBottom(true, false, 124, 175)
    self.ee_icon_5:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
    self.ee_icon_5:setRGB(1, 1, 1)
    self:addElement(self.ee_icon_5)

    -- Wonder Weapon Section
    self.ww_text = LUI.UIText.new()
    self.ww_text:setLeftRight(true, false, 745, 888)
    self.ww_text:setTopBottom(true, false, 113, 121)
    self.ww_text:setText(Engine.Localize("Wonder Weapon"))
    self.ww_text:setTTF("fonts/ltromatic.ttf")
    self.ww_text:setRGB(1, 1, 1)
    self.ww_text:setAlignment(Enum.LUIAlignment.LUI_ALIGNMENT_CENTER)
    self:addElement(self.ww_text)

    self.ww_icon_1 = LUI.UIImage.new()
    self.ww_icon_1:setLeftRight(true, false, 740, 791)
    self.ww_icon_1:setTopBottom(true, false, 124, 175)
    self.ww_icon_1:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
    self.ww_icon_1:setRGB(1, 1, 1)
    self:addElement(self.ww_icon_1)

    self.ww_icon_2 = LUI.UIImage.new()
    self.ww_icon_2:setLeftRight(true, false, 791, 842)
    self.ww_icon_2:setTopBottom(true, false, 124, 175)
    self.ww_icon_2:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
    self.ww_icon_2:setRGB(1, 1, 1)
    self:addElement(self.ww_icon_2)

    self.ww_icon_3 = LUI.UIImage.new()
    self.ww_icon_3:setLeftRight(true, false, 842, 893)
    self.ww_icon_3:setTopBottom(true, false, 124, 175)
    self.ww_icon_3:setImage(RegisterImage("i_mtl_image_7d9423641070f37e"))
    self.ww_icon_3:setRGB(1, 1, 1)
    self:addElement(self.ww_icon_3)

    -- Add more quest item sections as needed...

    return self
end

return CoD.AetheriumQuestsCustom
