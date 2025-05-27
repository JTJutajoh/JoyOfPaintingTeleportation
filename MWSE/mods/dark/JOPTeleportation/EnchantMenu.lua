local EnchantMenu = {}
---@type JOPT_Config
local config = require("dark.JOPTeleportation.config")
if not config then return end

---@type mwseLogger
local log = mwse.Logger.new()

-- local JoyOfPainting = require("mer.joyOfPainting")
-- if not JoyOfPainting then return end

---@alias JOPT.tes3itemChildren tes3item|tes3alchemy|tes3apparatus|tes3armor|tes3book|tes3clothing|tes3ingredient|tes3light|tes3lockpick|tes3misc|tes3probe|tes3repairTool|tes3weapon


---Called when the user clicks the button to perform an enchantment.  
---Checks if the soul in the chosen gem is valid and performs the dice rolls to check if it should enchant.
function EnchantMenu:onConfirm()
    log:trace("Enchant menu confirmed")

    local soul = EnchantMenu.chosenSoulGem.itemData.soul
    local chance = EnchantMenu:CalcEnchantChance(soul.soul)
    local success = chance >= math.random()

    if success then
        tes3.messageBox("Successfully enchanted painting.")
        EnchantMenu.painting.dataHolder.data.enchanted = true
        tes3.playSound {
            reference = tes3.player,
            sound = "mysticism hit"
        }
        log:debug("Closing enchant menu (confirmed).")
        tes3ui.leaveMenuMode()
        local menu = tes3ui.findMenu("JOP.NamePaintingMenu")
        if menu then menu:destroy() end
    else
        tes3.messageBox("Enchantment failed!")
        tes3.playSound {
            reference = tes3.player,
            sound = "mysticism miss"
        }
    end

    EnchantMenu.chosenSoulGem = nil
    EnchantMenu:onSoulGemChosen()
end

---Checks if a given painting has been marked as enchanted or not
---@param painting JOP.Painting
---@return boolean
local function isEnchanted(painting)
    return painting.dataHolder.data.enchanted or false
end

function EnchantMenu:teleport()
    log:info("Attempting to teleport to painting")
    if EnchantMenu.painting.dataHolder.data.joyOfPainting == nil then
        log:warn("Tried to teleport to painting location but there was no location data.")
        return
    end
    if not isEnchanted(EnchantMenu.painting) then
        log:info("Tried to teleport to a painting that wasn't enchanted")
        return
    end
    local location = EnchantMenu.painting.dataHolder.data.joyOfPainting.location
    log:debug("Teleport destination location:\n%s", function() return json.encode(location) end)
    tes3.playSound {
        reference = tes3.player,
        sound = "mysticism hit"
    }
    tes3.positionCell {
        reference = tes3.mobilePlayer,
        cell = location.cellId,
        position = location.position,
        orientation = location.orientation,
        teleportCompanions = true
    }
    tes3ui.leaveMenuMode()
    local menu = tes3ui.findMenu("JOP.NamePaintingMenu")
    if menu then menu:destroy() end
end

---@param item JOPT.tes3itemChildren
---@param itemData tes3itemData
---@return boolean
function EnchantMenu:CanUseSoulGem(item, itemData)
    if item.isSoulGem == false or itemData.soul == nil then
        return false
    end
    if itemData.soul.soul >= config.minSoulStrength then
        return true
    end
    return false
end

---@param soulValue number
---@return number
function EnchantMenu:CalcEnchantChance(soulValue)
    local soulContribution = (1 - math.max(((config.optimalSoulValue - soulValue) / config.optimalSoulValue), 0))
    local skillContribution = math.max((-config.optimalEnchantLevel + tes3.mobilePlayer.enchant.current) / config.optimalEnchantLevel, -1)
    return math.max(config.baseChance + soulContribution + skillContribution, config.minChance)
end

function EnchantMenu:chooseSoulGem()
    local CraftingFramework = require("CraftingFramework")
    if not CraftingFramework then
        log:error("CraftingFramework missing")
        return nil
    end

    EnchantMenu.chosenSoulGem = nil
    EnchantMenu:onSoulGemChosen()

    CraftingFramework.InventorySelectMenu.open {
        title = "Select a soul gem",
        noResultsText = "No sufficiently filled soul gems found",
        callback = function(e)
            if e then
                EnchantMenu.chosenSoulGem = { item = e.item, itemData = e.itemData, reference = e.reference }
            else
                EnchantMenu.chosenSoulGem = nil
            end
            EnchantMenu:onSoulGemChosen()
        end,
        filter = function(e2)
            log:trace("Filtering on %s", e2.item.id)
            if not e2.itemData then return false end
            local item = e2.item
            
            return EnchantMenu:CanUseSoulGem(item, e2.itemData)
        end,
        noResultsCallback = function()
            EnchantMenu.chosenSoulGem = nil
        end,
    }
end

function EnchantMenu:onSoulGemChosen()
    if not EnchantMenu.item_icon or not EnchantMenu.soulDetails or not EnchantMenu.enchantChance then
        log:error("Failed to update soul gem UI block, UI not fully initialized.")
        return
    end

    local icon = EnchantMenu.item_icon
    local details = EnchantMenu.soulDetails
    local chance = EnchantMenu.enchantChance

    local soulGem = EnchantMenu.chosenSoulGem
    if soulGem then
        local soul = soulGem.itemData.soul

        icon.contentPath = "Data Files\\icons\\" .. soulGem.item.icon
        details.text = string.format("%s (%i)", soul.name, soul.soul)
        chance.text = string.format("Chance: %i%%", EnchantMenu:CalcEnchantChance(soul.soul) * 100)
    else
        icon.contentPath = nil
        details.text = "Select a sufficiently filled soul gem"
        chance.text = "Chance: 0%"
    end
end

---@param parent tes3uiElement
---@param painting JOP.Painting
function EnchantMenu:createEnchantBlock(parent, painting)
    if not parent then
        log:error("Failed to create enchant UI block, invalid parent")
        return nil
    end

    EnchantMenu.painting = painting

    UIHelper = require("mer.joyOfPainting.services.UIHelper")
    if not UIHelper then 
        log:error("Failed to get JOP UIHelper.")
        return
    end

    parent:createDivider()

    local headerRow = parent:createBlock {}
    headerRow.widthProportional = 1.0
    headerRow.autoHeight = true
    headerRow.flowDirection = "left_to_right"

    local header = headerRow:createLabel { text = "Enchant painting" }
    header.childAlignX = 0.5
    header.autoWidth = true

    local spacer = headerRow:createBlock()
    spacer.widthProportional = 1.0

    EnchantMenu.enchantChance = headerRow:createLabel { text = "Chance: 0%" }
    EnchantMenu.enchantChance:register("help", function()
        UIHelper.createTooltipMenu {
            header = "Chance of success",
            text = [[
Based on the strength of the soul and the enchanter's Enchant skill (configurable in MCM).
]]
        }
    end)
    EnchantMenu.enchantChance.childAlignX = 1.0
    EnchantMenu.enchantChance.autoWidth = true

    local border = parent:createThinBorder {}
    border.flowDirection = "left_to_right"
    border.widthProportional = 1.0
    border.autoHeight = true
    border.minHeight = 32
    border.minWidth = 400
    border.childAlignX = 0
    border.childAlignY = 0.5
    border.paddingAllSides = 8
    border.borderAllSides = 4

    border:createLabel { text = "Soul" }

    local item_border = border:createThinBorder()
    item_border.height = 48
    item_border.width = 48
    item_border.flowDirection = "top_to_bottom"
    item_border.childAlignX = 0.5
    item_border.childAlignY = 0.5
    item_border.borderAllSides = 10
    item_border.paddingAllSides = 4

    local item_icon = item_border:createImage()
    EnchantMenu.item_icon = item_icon
    -- item_icon.widthProportional = 1.0
    -- item_icon.heightProportional = 1.0
    -- item_icon.autoHeight = true
    -- item_icon.autoWidth = true
    item_icon.width = 40
    item_icon.height = 40
    item_icon.scaleMode = false
    -- item_icon.childAlignX = 0.5
    -- item_icon.childAlignY = 0.5

    local soulDetails = border:createLabel { text = "Select a sufficiently filled soul gem" }
    EnchantMenu.soulDetails = soulDetails
    soulDetails.autoWidth = true
    soulDetails.autoHeight = true
    soulDetails.borderLeft = 8

    local button_block = parent:createBlock {}
    button_block.widthProportional = 1.0
    button_block.autoHeight = true
    button_block.childAlignX = 1.0

    local button_confirm = button_block:createButton { text = "Enchant" }

    button_confirm:register("mouseClick", EnchantMenu.onConfirm)
    button_confirm:register("help", function()
        UIHelper.createTooltipMenu {
            header = "Enchant",
            text = [[
If successful, the painting will be magically linked to the exact spot where it was originally painted, allowing it to be used as a portal.
]]
        }
    end)
    item_border:register("mouseClick", EnchantMenu.chooseSoulGem)

    EnchantMenu:onSoulGemChosen()
end

---@param parent tes3uiElement
---@param painting JOP.Painting
function EnchantMenu:createTeleportBlock(parent, painting)
    if not parent then
        log:error("Failed to create teleport UI block, invalid parent")
        return nil
    end

    EnchantMenu.painting = painting

    -- UIHelper = require("mer.joyOfPainting.services.UIHelper")
    -- if not UIHelper then 
    --     log:error("Failed to get JOP UIHelper.")
    --     return
    -- end

    parent:createDivider()

    local headerRow = parent:createBlock {}
    headerRow.widthProportional = 1.0
    headerRow.autoHeight = true
    headerRow.flowDirection = "left_to_right"
    headerRow.childAlignY = 1
    headerRow.borderAllSides = 10

    local header = headerRow:createLabel { text = string.format("Linked to %s", painting.dataHolder.data.joyOfPainting.location.cellName) }
    -- header.widthProportional = 1.0
    -- header.childAlignX = 0.5
    header.autoWidth = true

    local button_teleport = headerRow:createButton { text = "Recall" }
    button_teleport.childAlignX = 1.0
    button_teleport.paddingAllSides = 6
    button_teleport:register("mouseClick", EnchantMenu.teleport)
end

-- ---@param painting JOP.Painting
-- function EnchantMenu:createMenu(painting)
--     if tes3ui.findMenu(self.menuID) ~= nil then
--         log:warn("Tried to create duplicate EnchantMenu")
--         return
--     end

--     if painting == nil then
--         log:error("Cannot create enchant menu, painting was nil")
--         return
--     end
--     EnchantMenu.painting = painting

--     log:debug("Creating enchant menu.")

--     if not EnchantMenu.menuID then
--         EnchantMenu.menuID = tes3ui.registerID("JOPT:EnchantMenu")
--         log:debug("Registered enchant menu ID \"%s\"", EnchantMenu.menuID)
--     end

--     local menu = tes3ui.createMenu{
--         id = EnchantMenu.menuID,
--         fixedFrame = true,
--     }
--     menu.minWidth = 600
--     menu.maxWidth = 800
--     menu.minHeight = 400
--     menu.maxHeight = 800
--     menu.autoHeight = true
--     menu.autoWidth = true
--     menu.alpha = 0.9
--     menu.paddingAllSides = 12
--     menu.flowDirection = "top_to_bottom"
--     menu.childAlignX = 0.5

--     local label = menu:createLabel{text = "Enchant painting"}
--     label.borderBottom = 10

--     UIHelper = require("mer.joyOfPainting.services.UIHelper")
--     if not UIHelper then 
--         log:error("Failed to get JOP UIHelper.")
--         menu:destroy()
--         tes3ui.leaveMenuMode()
--         return
--     end

--     local paintingData = painting.data
--     local image = UIHelper.createPaintingImage(menu, {
--         paintingName = paintingData.paintingName,
--         paintingTexture = paintingData.paintingTexture,
--         canvasId = paintingData.canvasId,
--         tooltipHeader = paintingData.paintingName,
--         tooltipText = painting:getTooltipText(),
--         height = 300,
--     })
--     if not image then
--         log:error("Image returned by UIHelper.createPaintingImage was nil")
--     else
--         image.block.flowDirection = "top_to_bottom"
--         image.block.childAlignX = 0.5
--         image.block.widthProportional = 1.0
--     end
--     menu.childAlignX = 0.5
    
--     local block = menu:createBlock{}
--     block.widthProportional = 1.0
--     block.autoHeight = true
--     block.childAlignX = 0.5

--     EnchantMenu:createEnchantBlock(block, painting)
    
--     local button_cancel = block:createButton{text = "Cancel"}
--     button_cancel:register("mouseClick", EnchantMenu.onCancel)

--     log:trace("Showing enchant menu.")
--     menu:updateLayout()
--     tes3ui.enterMenuMode(menu.id)
-- end

return EnchantMenu
