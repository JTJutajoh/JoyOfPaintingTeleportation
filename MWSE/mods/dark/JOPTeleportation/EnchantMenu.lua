local EnchantMenu = {}
---@type JOPT_Config
local config = require("dark.JOPTeleportation.config")
if not config then return end

---@type mwseLogger
local log = mwse.Logger.new()

-- local JoyOfPainting = require("mer.joyOfPainting")
-- if not JoyOfPainting then return end

---@alias JOPT.tes3itemChildren tes3item|tes3alchemy|tes3apparatus|tes3armor|tes3book|tes3clothing|tes3ingredient|tes3light|tes3lockpick|tes3misc|tes3probe|tes3repairTool|tes3weapon
---@alias JOPT.tes3soulOwner tes3actor|tes3container|tes3containerInstance|tes3creature|tes3creatureInstance|tes3npc|tes3npcInstance

---@class JOPT.EnchantMenu.SoulGem
---@field item JOPT.tes3itemChildren
---@field itemData tes3itemData?
---@field reference tes3reference

---@class JOPT.EnchantMenu
---@field chosenSoulGem JOPT.EnchantMenu.SoulGem
---@field painting JOP.Painting

---@class JOPT.EnchantMenu.attemptEnchant.params
---@field soulGem JOPT.EnchantMenu.SoulGem
---@field painting JOP.Painting

---Called when the user clicks the button to perform an enchantment.  
---Checks if the soul in the chosen gem is valid and performs the dice rolls to check if it should enchant.
---@param e JOPT.EnchantMenu.attemptEnchant.params
---@return boolean enchanted
function EnchantMenu.attemptEnchant(e)
    log:trace("Enchant menu confirmed")

    local soul = e.soulGem.itemData.soul.soul
    local chance = EnchantMenu.calcEnchantChance(soul)

    if chance >= math.random() then
        tes3.messageBox("Successfully enchanted painting.")
        e.painting.dataHolder.data.enchanted = true
        tes3.playSound {
            reference = tes3.player,
            sound = "mysticism hit"
        }
        return true
    else
        tes3.messageBox("Enchantment failed!")
        tes3.playSound {
            reference = tes3.player,
            sound = "miss"
        }
        return false
    end
end

---@param painting JOP.Painting
---@return boolean enchanted
function EnchantMenu.isEnchanted(painting)
    return painting.dataHolder and painting.dataHolder.data and painting.dataHolder.data.enchanted
end

---@param location JOP.Painting.location
function EnchantMenu.teleport(location)
    log:trace("Attempting to teleport to painting")
    
    if location.cellId and location.position and location.orientation then
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
    else
        log:error("Failed to teleport to location: %s", json.encode(location))
        tes3.messageBox("Teleport error (Check MWSE.log)")
    end
end

---Given an input soul value from a soul gem, returns a 0-1 chance of enchantment success based on the soul value and the player's Enchant skill
---@param soulValue number
---@return number chance 0-1 chance of success
function EnchantMenu.calcEnchantChance(soulValue)
    local soulContribution = (1 - math.max(((config.optimalSoulValue - soulValue) / config.optimalSoulValue), 0))
    local skillContribution = math.max((-config.optimalEnchantLevel + tes3.mobilePlayer.enchant.current) / config.optimalEnchantLevel, -1)
    return math.max(config.baseChance + soulContribution + skillContribution, config.minChance)
end

---Opens a CraftingFramework selection menu filtering for valid soul gems and returns the chosen soul gem
---@param callback fun(chosenSoulGem: JOPT.EnchantMenu.SoulGem?)?
function EnchantMenu.chooseSoulGem(callback)
    log:debug("Importing CraftingFramework")
    local CraftingFramework = require("CraftingFramework")
    if not CraftingFramework then
        log:error("CraftingFramework missing")
        return
    end

    log:debug("Creating CraftingFramework.InventorySelectMenu to choose soul gem")
    CraftingFramework.InventorySelectMenu.open {
        title = "Select a soul gem",
        noResultsText = "No sufficiently filled soul gems found",
        callback = function(e)
            log:trace("Inventory select menu callback, result: %s", e.item.name)
            if e and e.itemData then
                log:debug("Chose soul gem %s with soul %s of strength %i", e.item.name, e.itemData.soul, e.itemData.soul.soul)
                ---@type JOPT.EnchantMenu.SoulGem?
                local chosenSoulGem = {
                    item = e.item,
                    itemData = e.itemData,
                    reference = e.reference
                }
                log:trace("Calling callback with chosen soul gem")
                if callback then callback(chosenSoulGem) end
            else
                log:warn("itemData on %s not found", e.item.name)
                if callback then callback(nil) end
            end
        end,
        filter = function(e2)
            log:debug("Filtering on %s", e2.item.id)
            if not e2.itemData then
                log:debug("No itemData")
                return false
            end
            if not e2.itemData.soul then
                log:debug("No soul in itemData")
                return false
            end
            if e2.itemData.soul.soul < config.minSoulStrength then
                log:debug("Soul strength (%i) below minimum set in config (%i)", e2.itemData.soul.soul, config.minSoulStrength)
                return false
            end

            return true
        end,
        noResultsCallback = function(e)
            log:debug("No soul gems were found")
            if callback then callback(nil) end
        end
    }
end

---@class JOPT.EnchantMenu.params
---@field parent tes3uiElement
---@field painting JOP.Painting

---@param e JOPT.EnchantMenu.params
---@return JOPT.EnchantMenu
function EnchantMenu:new(e)
    local enchantMenu = setmetatable({}, self)

    UIHelper = require("mer.joyOfPainting.services.UIHelper")
    if not UIHelper then log:error("Failed to get JOP UIHelper.") end

    if EnchantMenu.isEnchanted(e.painting) then
        log:debug("Painting is enchanted, adding the teleport UI block to the name painting menu")
        EnchantMenu:createTeleportBlock {
            parent = e.parent,
            painting = e.painting,
            teleportCallback = EnchantMenu.teleport
        }
    else
        log:debug("Painting is NOT enchanted, adding the enchant UI block to the name painting menu")
        EnchantMenu:createEnchantBlock {
            parent = e.parent,
            painting = e.painting,
            enchantChanceTooltipCallback = function()
                UIHelper.createTooltipMenu {
                    header = "Chance of success",
                    text = "Based on the strength of the soul and the enchanter's Enchant skill (configurable in MCM).",
                }
            end,
        }
    end

    return enchantMenu
end

---@class JOPT.EnchantMenu.createEnchantBlock.params
---@field parent tes3uiElement
---@field painting JOP.Painting
---@field enchantChanceTooltipCallback function?

---@param e JOPT.EnchantMenu.createEnchantBlock.params
function EnchantMenu:createEnchantBlock(e)
    e.parent:createDivider()

    ---@type JOPT.EnchantMenu.SoulGem?
    local soulGem

    local headerRow = e.parent:createBlock {}
    headerRow.widthProportional = 1.0
    headerRow.autoHeight = true
    headerRow.flowDirection = "left_to_right"

    local header = headerRow:createLabel { text = "Enchant" }
    header.childAlignX = 0.5
    header.autoWidth = true

    local spacer = headerRow:createBlock()
    spacer.widthProportional = 1.0

    local enchantChance = headerRow:createLabel { text = "Chance: 0%" }
    enchantChance:register("help", e.enchantChanceTooltipCallback)
    enchantChance.childAlignX = 1.0
    enchantChance.autoWidth = true

    local border = e.parent:createThinBorder {}
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
    -- item_icon.widthProportional = 1.0
    -- item_icon.heightProportional = 1.0
    -- item_icon.autoHeight = true
    -- item_icon.autoWidth = true
    item_icon.width = 40
    item_icon.height = 40
    item_icon.scaleMode = false
    -- item_icon.childAlignX = 0.5
    -- item_icon.childAlignY = 0.5

    local noSoulText = "Select a sufficiently filled soul gem"
    local soulDetails = border:createLabel { text = noSoulText }
    soulDetails.autoWidth = true
    soulDetails.autoHeight = true
    soulDetails.borderLeft = 8

    local button_block = e.parent:createBlock {}
    button_block.widthProportional = 1.0
    button_block.autoHeight = true
    button_block.childAlignX = 1.0

    local button_confirm = button_block:createButton { text = "Enchant" }
    button_confirm.disabled = soulGem == nil

    item_border:register("mouseClick", function()
        EnchantMenu.chooseSoulGem(function(chosenSoulGem)
            soulGem = chosenSoulGem

            log:trace("Chose soul gem: %s", soulGem)
            if soulGem and soulGem.itemData and soulGem.itemData.soul then
                log:debug("Valid soul gem chosen, updating UI elements")
                item_icon.contentPath = "Data Files\\icons\\" .. soulGem.item.icon
                local soul = soulGem.itemData.soul --[[@as JOPT.tes3soulOwner]]
                soulDetails.text = string.format("%s (%s)\nStrength: %i", soulGem.item.name, soul.name, soul.soul)
                enchantChance.text = string.format("Chance: %i%%", EnchantMenu.calcEnchantChance(soul.soul) * 100)
                button_confirm.disabled = false
            else
                log:debug("No valid soul gem chosen, clearing all UI elements")
                item_icon.contentPath = nil
                soulDetails.text = noSoulText
                enchantChance.text = "Chance: 0%"
                button_confirm.disabled = true
            end
        end)
    end)

    button_confirm:register("mouseClick", function()
        log:trace("Enchant button clicked")
        local enchanted = EnchantMenu.attemptEnchant {
            painting = e.painting,
            soulGem = soulGem
        }
        if enchanted then
            log:debug("Closing menu after successful enchantment")
            local menu = tes3ui.findMenu("JOP.NamePaintingMenu")
            if menu then
                menu:destroy()
                tes3ui.leaveMenuMode()
            end
        end
    end)
    button_confirm:register("help", function()
        UIHelper.createTooltipMenu {
            header = "Enchant",
            text = "If successful, the painting will be magically linked to the exact spot where it was originally painted, allowing it to be used as a portal.",
        }
    end)
    log:trace("Enchant menu creation completed")
end

---@class JOPT.EnchantMenu.createTeleportBlock.params
---@field parent tes3uiElement
---@field painting JOP.Painting
---@field teleportCallback fun(location: JOP.Painting.location)?

---@param e JOPT.EnchantMenu.createTeleportBlock.params
function EnchantMenu:createTeleportBlock(e)
    e.parent:createDivider()

    local headerRow = e.parent:createBlock {}
    headerRow.widthProportional = 1.0
    headerRow.autoHeight = true
    headerRow.flowDirection = "left_to_right"
    headerRow.childAlignY = 1
    headerRow.borderAllSides = 10

    local location = e.painting.dataHolder.data.joyOfPainting.location --[[@as JOP.Painting.location|string]]
    local cellName = location.cellName or location --[[@as string]]
    local header = headerRow:createLabel { text = string.format("Linked to %s", cellName) }
    header.autoWidth = true

    local button_teleport = headerRow:createButton { text = "Recall" }
    button_teleport.childAlignX = 1.0
    button_teleport.paddingAllSides = 6
    button_teleport:register("mouseClick", function()
        if e.teleportCallback then e.teleportCallback(e.painting.data.location) end
    end)
end

return EnchantMenu
