-- Compiled using luac for Black Ops III

CoD.PromptTemplate = InheritFrom( LUI.UIElement )

function CoD.PromptTemplate.new( menu, controller )
    local self = LUI.UIElement.new()
    
    if PreLoadFunc then
        PreLoadFunc( self, controller )
    end
    
    self:setUseStencil( false )
    self:setClass( CoD.PromptTemplate )
    self.id = "PromptTemplate"
    self.soundSet = "default"
    self:setLeftRight( true, false, 0, 1280 )
    self:setTopBottom( true, false, 0, 720 )
    
    -- Start hidden
    self:setAlpha(0)
    
    if PostLoadFunc then
        PostLoadFunc( self, controller, menu )
    end
    
    return self
end

return CoD.PromptTemplate