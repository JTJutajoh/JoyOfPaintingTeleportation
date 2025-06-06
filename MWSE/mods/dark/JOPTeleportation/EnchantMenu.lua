local EnchantMenu = {}
---@type JOPT_Config
local config = require("dark.JOPTeleportation.config")
if not config then return end

---@type mwseLogger
local log = mwse.Logger.new("JOPT - Enchant Menu")

local JOPConfig = require("mer.joyOfPainting.config")
if not JOPConfig then return end

local CraftingFramework = require("CraftingFramework")
if not CraftingFramework then return end

PaintingRegistry = require("dark.JOPTeleportation.PaintingRegistry")

---@alias JOPT.tes3itemChildren tes3item|tes3alchemy|tes3apparatus|tes3armor|tes3book|tes3clothing|tes3ingredient|tes3light|tes3lockpick|tes3misc|tes3probe|tes3repairTool|tes3weapon
---@alias JOPT.tes3soulOwner tes3actor|tes3container|tes3containerInstance|tes3creature|tes3creatureInstance|tes3npc|tes3npcInstance

--- An instance of the enchant menu that has been added to a UI element.<br>
--- Stores data needed to actually perform the enchantment
---@class JOPT.EnchantMenu
---@field chosenSoulGem JOPT.EnchantMenu.SoulGem?
---@field painting JOP.Painting

--- All necessary data related to a soul gem to keep track of which gem has been chosen for enchanting
---@class JOPT.EnchantMenu.SoulGem
---@field item JOPT.tes3itemChildren
---@field itemData tes3itemData?
---@field reference tes3reference

--- Given a painting or a container for paintings (frames, easels, sketchbook, etc.) returns the unique ID of the specific painting
---@param item JOPT.tes3itemChildren|JOP.Painting|JOP.Sketchbook.sketch|nil The painting, frame, easel, sketchbook, etc. that contains a painting
---@return string? ID The paintingID for the painting if one exists, otherwise nil
---@see JOP.Painting.data.paintingId
function EnchantMenu.getPaintingID(item)
    if not item then
        log:warn("Tried to get painting ID from nothing")
        return nil
    end
    log:trace("Fetching painting ID from %s", item.id or item.itemId)

    -- Paintings have their ID set as the texture's filename ending with .dds,
    -- so check a substring of the paintingId to make sure that it's the ID we want.
    if item and item.data and item.data.paintingId and string.sub(item.data.paintingId, -4, -1) == ".dds" then
        log:trace("Found painting ID: %s", item.data.paintingId)
        return item.data.paintingId
    end

    log:warn("Did not find any painting ID on %s", item)
    return nil
end

--- Given a painting or a container for paintings (frames, easels, sketchbook, etc.) returns whether or not the painting is enchanted.<br>
--- Currently just a wrapper for DataRegistry.isEnchanted
---@param painting JOP.Painting|JOP.Sketchbook.sketch
---@return boolean enchanted
function EnchantMenu.isEnchanted(painting)
    local paintingId = EnchantMenu.getPaintingID(painting)
    ---@type boolean
    local enchanted = PaintingRegistry.isEnchanted(paintingId)

    log:trace("Checking enchanted status of %s, result: %s", paintingId, enchanted)

    return enchanted
end

---@param painting JOP.Painting|JOP.Sketchbook.sketch
function EnchantMenu.multiplyValue(painting)
    log:info("Attempting to adjust painting's value")
    if painting.item and painting.item.value then
        log:trace("Painting was a painting, changing its item value")
        painting.item.value = (painting.item.value or painting:calculateValue()) * config.valueMultiplier
    else
        log:debug("Painting item was not valid or did not have a value, trying to find its item by ID")
        local paintingId = painting.itemId or painting.data.paintingId
        local item = tes3.getObject(paintingId)
        if item then
            log:debug("Found the item with ID %s, adjusting its value", paintingId)
            item.value = item.value * config.valueMultiplier
        else
            log:warn("Failed to find the item with ID %s, the painting's value will not be adjusted.", paintingId)
        end
    end
end

--- Given a painting, mark it as enchanted in the DataRegistry
---@param paintingHolder JOP.Painting|JOP.Sketchbook.sketch|JOPT.tes3itemChildren A painting or an item that can contain a painting such as a frame or easel.
---@return boolean success
function EnchantMenu.enchant(paintingHolder)
    local paintingId = EnchantMenu.getPaintingID(paintingHolder)
    if paintingId then
        PaintingRegistry.storePaintingIsEnchanted(paintingId, true)
        log:debug("Set %s as enchanted", paintingId)
        event.trigger("JOPT.EnchantedPainting", { id = paintingId })
        return true
    else
        log:warn("Failed to mark '%s' as enchanted, invalid paintingId", paintingHolder.id)
        return false
    end
end

---@class JOPT.EnchantMenu.attemptEnchant.params
---@field soulGem JOPT.EnchantMenu.SoulGem
---@field painting JOP.Painting|JOP.Sketchbook.sketch

---Called when the user clicks the button to perform an enchantment.  
---Checks if the soul in the chosen gem is valid and performs the dice rolls to check if it should enchant.
---@param e JOPT.EnchantMenu.attemptEnchant.params
---@return boolean enchanted
function EnchantMenu.attemptEnchant(e)
    log:debug("Attempting to enchant")

    local soul = e.soulGem.itemData.soul.soul
    local chance = EnchantMenu.calcEnchantChance(soul, e.painting)
    log:debug("Enchant chance: %f", chance)
    local roll = math.random()
    log:debug("Rolled: %f", roll)

    log:info("Consuming soul gem")
    CraftingFramework.CarryableContainer.removeItem {
        count = 1,
        item = e.soulGem.item,
        itemData = e.soulGem.itemData,
        reference = e.soulGem.reference,
        playSound = false,
        updateGUI = true,
    }

    if chance >= roll then
        if EnchantMenu.enchant(e.painting) then
            log:info("Enchant success")
            tes3.messageBox("Successfully enchanted painting.")
            tes3.playSound {
                reference = tes3.player,
                sound = "enchant success"
            }
            return true
        end
    end
    log:info("Enchant failed")
    tes3.messageBox("Enchantment failed!")
    tes3.playSound {
        reference = tes3.player,
        sound = "enchant fail"
    }
    return false
end

---@param location JOP.Painting.location
function EnchantMenu.teleport(location)
    if config.noCombatTeleport and tes3.mobilePlayer and tes3.mobilePlayer.inCombat then
        log:info("Blocking teleport because of combat.")

        tes3.messageBox {
            message = "Unable to teleport while in combat.",
        }
        return
    end

    log:debug("Attempting to teleport to painting")
    
    if location and location.cellId and location.position and location.orientation then
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
        log:info("Trying to close menu(s)")
        tes3ui.leaveMenuMode()
        local menu = tes3ui.findMenu("JOP.NamePaintingMenu")
        if menu then
            log:debug("Closing instance of JOP.NamePaintingMenu")
            menu:destroy()
        else
            menu = tes3ui.findMenu("JOP_SketchbookMenu")
            if menu then
                log:debug("Closing instance of JOP_SketchbookMenu")
                menu:destroy()
            end
        end
        event.trigger("JOPT.Teleport")
    else
        log:error("Failed to teleport to location: %s", function() return json.encode(location or {}) end)
        tes3.messageBox("Teleport error (Check MWSE.log)")
    end
end

--- Given an input soul value from a soul gem, returns a 0-1 chance of enchantment success based on the soul value and the player's Enchant skill and the painting's skill
---@param soulValue number
---@param painting JOP.Painting|JOP.Sketchbook.sketch
---@return number chance 0-1 chance of success
function EnchantMenu.calcEnchantChance(soulValue, painting)
    log:trace("Calculating enchant chance")
    log:trace("Base chance: %f", config.baseChance)

    local soulMult = 1.2 -- Higher values increase the penalty that weak souls incur
    local enchantMult = 1.2 -- Higher values increase the penalty for being below the optimal enchant level
    local paintingMult = 0.4 -- Lower values increase the penalty for being below the optimal painting level

    local soulFrac = (config.optimalSoulValue - soulValue) / config.optimalSoulValue
    local soulContribution = math.max(-1 * soulFrac * soulMult, -1)
    log:trace("Soul contribution: %f", soulContribution)

    local enchantFrac = (-config.optimalEnchantLevel + tes3.mobilePlayer.enchant.current) / config.optimalEnchantLevel
    local enchantContribution = math.max(enchantFrac * enchantMult, -1)
    log:trace("Enchant skill contribution: %f", enchantContribution)

    local artStyleOptimalLevel = JOPConfig.artStyles[painting.data.artStyle].maxDetailSkill
    local paintingSkill = PaintingRegistry.skillWhenPainted(EnchantMenu.getPaintingID(painting)) or 100
    local paintingContribution = math.min((paintingSkill / artStyleOptimalLevel), 1) * paintingMult
    log:trace("Painting skill contribution : %f", paintingContribution)
    log:trace("Minimum chance: %f", config.minChance)

    return math.max((config.baseChance + enchantContribution + paintingContribution) * 0.75 + soulContribution, config.minChance)
end

--- Opens a CraftingFramework selection menu filtering for valid soul gems
--- Calls the provided callback with the chosen soul gem as the argument, so that UI can be updated
---@param callback fun(chosenSoulGem: JOPT.EnchantMenu.SoulGem?)?
function EnchantMenu.chooseSoulGem(callback)
    log:debug("Importing CraftingFramework")
    local InventorySelectMenu = require("CraftingFramework.carryableContainers.components.InventorySelectMenu")
    if not InventorySelectMenu then
        log:error("CraftingFramework missing")
        return
    end

    log:info("Creating CraftingFramework InventorySelectMenu to choose soul gem")
    InventorySelectMenu.open {
        title = "Select a soul gem",
        noResultsText = "No sufficiently filled soul gems found",
        callback = function(e)
            log:trace("Inventory select menu callback, result: %s", e.item.name)
            if e and e.itemData then
                log:info("Chose soul gem %s with soul %s of strength %i", e.item.name, e.itemData.soul, e.itemData.soul.soul)
                ---@type JOPT.EnchantMenu.SoulGem?
                local chosenSoulGem = {
                    item = e.item,
                    itemData = e.itemData,
                    reference = e.reference
                }
                log:trace("Calling callback with chosen soul gem")
                if callback then callback(chosenSoulGem) end
                event.trigger("JOPT.ChoseSoulGem")
            else
                log:warn("itemData on %s not found", e.item.name)
                if callback then callback(nil) end
            end
        end,
        filter = function(e2)
            log:trace("Filtering on %s", e2.item.id)
            if not e2.itemData then
                log:trace("No itemData")
                return false
            end
            if not e2.itemData.soul then
                log:trace("No soul in itemData")
                return false
            end
            if e2.itemData.soul.soul < config.minSoulStrength then
                log:debug("Soul strength (%i) below minimum set in config (%i)", e2.itemData.soul.soul, config.minSoulStrength)
                return false
            end

            log:debug("Matched usable soul gem: %s", e2.item.id)
            return true
        end,
        noResultsCallback = function(e)
            log:info("No soul gems were found")
            if callback then callback(nil) end
        end
    }
end

---@class JOPT.EnchantMenu.params
---@field parent tes3uiElement
---@field painting JOP.Painting|JOP.Sketchbook.sketch
---@field borderSides number?
---@field addDivider boolean?

--- Adds a block to a given UI parent for a given painting.<br>
--- If the painting is already enchanted, it adds the teleport GUI. If not, it adds the enchantment GUI.
---@param e JOPT.EnchantMenu.params
---@return JOPT.EnchantMenu 
function EnchantMenu:new(e)
    log:info("Creating EnchantMenu for %s on %s", e.painting, e.parent.name)
    ---@type JOPT.EnchantMenu
    local enchantMenu = setmetatable({}, self)

    if not e.painting then
        log:error("Couldn't create enchant menu, painting was nil")
        return enchantMenu
    end

    log:trace("Including JOP UIHelper")
    local UIHelper = require("mer.joyOfPainting.services.UIHelper")
    if not UIHelper then log:error("Failed to get JOP UIHelper.") end

    if EnchantMenu.isEnchanted(e.painting) then
        log:debug("Painting is enchanted, adding the teleport UI block to the name painting menu")
        EnchantMenu:createTeleportBlock {
            parent = e.parent,
            painting = e.painting,
            teleportCallback = EnchantMenu.teleport,
            borderSides = e.borderSides,
            addDivider = e.addDivider,
        }
    else
        log:debug("Painting is NOT enchanted.")
        if PaintingRegistry.skillWhenPainted(e.painting.id) or 100 >= config.minPaintingSkill then
            log:debug("Adding the enchant UI block to the name painting menu")
            EnchantMenu:createEnchantBlock {
                parent = e.parent,
                painting = e.painting,
                enchantChanceTooltipCallback = function()
                    log:trace("Creating tooltip for enchant chance label")
                    UIHelper.createTooltipMenu {
                        header = "Chance of success",
                        text = [[
Based on: Soul strength, Enchant skill, and Painting skill at the time the painting was painted.
(Configurable in MCM)
]],
                    }
                end,
                confirmEnchantTooltipCallback = function()
                    log:trace("Creating tooltip for enchant confirm button")
                    UIHelper.createTooltipMenu {
                        header = "Enchant",
                        text = "If successful, the painting will be magically linked to the exact spot where it was originally painted, allowing it to be used as a portal.",
                    }
                end,
                onEnchantSuccessCallback = function()
                    log:debug("Painting successfully enchanted, adding the teleport UI block to the name painting menu")
                    EnchantMenu:createTeleportBlock {
                        parent = e.parent,
                        painting = e.painting,
                        teleportCallback = EnchantMenu.teleport,
                        borderSides = e.borderSides,
                        addDivider = e.addDivider,
                    }
                    
                    EnchantMenu.multiplyValue(e.painting)

                    local player = tes3.mobilePlayer --[[@as tes3mobilePlayer]]
                    if player and player.exerciseSkill then
                        log:info("Giving the player Enchant XP")
                        player:exerciseSkill(tes3.skill["enchant"], config.enchantProgressGain)
                    end
                end,
                -- onEnchantFailCallback = function()

                -- end,
                skillTooltipCallback = function()
                    log:trace("Creating tooltip for skill")
                    UIHelper.createTooltipMenu {
                        header = "Painting Skill",
                        text = [[
At the time that the painting was painted, NOT current level.
Depends on the art style/medium. Usually the best chance requires ~50 Painting skill.
]],
                    }
                end,
                borderSides = e.borderSides,
                addDivider = e.addDivider,
            }
        else
            log:info("Painting skill level (%i) too low to enchant", PaintingRegistry.skillWhenPainted(e.painting.id))
        end
    end

    log:debug("Finished creating EnchantMenu")
    return enchantMenu
end

---@class JOPT.EnchantMenu.createEnchantBlock.params
---@field parent tes3uiElement
---@field painting JOP.Painting|JOP.Sketchbook.sketch
---@field enchantChanceTooltipCallback function?
---@field confirmEnchantTooltipCallback function?
---@field skillTooltipCallback function?
---@field onEnchantSuccessCallback function?
---@field onEnchantFailCallback function?
---@field borderSides number?
---@field addDivider boolean?

--- Creates and adds a UI block to a given parent for enchanting a painting
---@param e JOPT.EnchantMenu.createEnchantBlock.params
function EnchantMenu:createEnchantBlock(e)
    log:debug("Creating enchant block, parent: %s", e.parent.name)

    ---@type JOPT.EnchantMenu.SoulGem?
    local soulGem

    ---@type boolean
    local collapsed = true

    local block_outer = e.parent:createBlock({ id = "JOPT.EnchantOuterBlock" })
    block_outer.autoHeight = true
    block_outer.widthProportional = 1.0
    block_outer.flowDirection = "top_to_bottom"
    block_outer.childAlignX = 0.5
    block_outer.borderTop = 6
    block_outer.borderLeft = e.borderSides or 50
    block_outer.borderRight = e.borderSides or 50

    --enchant button
    local button_enchant = block_outer:createButton { text = "Enchant", id = "JOPT.CollapseButton" }
    button_enchant.borderAllSides = 8
    button_enchant.paddingTop = 8
    button_enchant.paddingBottom = 8
    button_enchant.paddingLeft = 24
    button_enchant.paddingRight = 24

    if e.addDivider then block_outer:createDivider() end

    --body
    local border = block_outer:createThinBorder {}
    border.flowDirection = "top_to_bottom"
    -- border.widthProportional = 1.0
    border.width = 300
    border.autoHeight = true
    border.paddingAllSides = 8
    border.borderAllSides = 4
    border.childAlignX = 0.5

    local block_inner = border:createBlock()
    block_inner.flowDirection = "left_to_right"
    block_inner.autoHeight = true
    block_inner.widthProportional = 1.0
    block_inner.childAlignY = 0.5
    block_inner.paddingLeft = 16
    block_inner.paddingRight = 16

    --soul gem
    local soul_block = block_inner:createBlock()
    soul_block.flowDirection = "top_to_bottom"
    soul_block.childAlignY = 0.5
    soul_block.childAlignX = 0.5
    soul_block.autoHeight = true
    soul_block.autoWidth = true

    soul_block:createLabel { text = "Soul" }

    local item_border = soul_block:createThinBorder({ id = "JOPT.SoulGemBorder" })
    item_border.height = 48
    item_border.width = 48
    item_border.flowDirection = "top_to_bottom"
    item_border.childAlignX = 0.5
    item_border.childAlignY = 0.5
    item_border.borderAllSides = 2
    item_border.paddingAllSides = 4

    local item_icon = item_border:createImage({ id = "JOPT.SoulGemIcon" })
    item_icon.width = 40
    item_icon.height = 40
    item_icon.scaleMode = true
    item_icon.alpha = 0

    -- Define this early so that it can be referenced in the closure below
    local button_confirm
    local enchantChance

    item_border:register("mouseClick", function()
        log:trace("Item border clicked, choosing soul gem")
        EnchantMenu.chooseSoulGem(function(chosenSoulGem)
            soulGem = chosenSoulGem
            log:trace("Chose soul gem: %s", soulGem)

            if soulGem and soulGem.itemData and soulGem.itemData.soul then
                log:debug("Valid soul gem chosen, updating UI elements")

                local iconPath = "Data Files\\icons\\" .. soulGem.item.icon
                log:trace("Setting item icon to %s", iconPath)
                item_icon.contentPath = iconPath
                item_icon.alpha = 1

                local soul = soulGem.itemData.soul --[[@as JOPT.tes3soulOwner]]
                log:trace("Contained soul: %s", soul.name)
                
                local chance = EnchantMenu.calcEnchantChance(soul.soul, e.painting)
                log:trace("Enchant chance: %f", chance)
                enchantChance.text = string.format("Chance: %i%%", chance * 100)

                log:trace("Enabling confirm button")
                button_confirm.disabled = false
            else
                log:debug("No valid soul gem chosen, clearing all UI elements")
                item_icon.contentPath = nil
                item_icon.alpha = 0
                enchantChance.text = "Chance: 0%"
                button_confirm.disabled = true
            end
        end)
    end)
    item_border:register(tes3.uiEvent.help, function()
        if soulGem then
            tes3ui.createTooltipMenu {
                object = soulGem.item,
                itemData = soulGem.itemData,
            }
        else

        end
    end)

    local block_details = block_inner:createBlock({ id = "JOPT.EnchantDetails" })
    block_details.autoHeight = true
    block_details.widthProportional = 1.0
    block_details.flowDirection = "top_to_bottom"
    block_details.childAlignX = 0.5
    block_details.borderLeft = 4

    local paintingSkill = PaintingRegistry.skillWhenPainted(EnchantMenu.getPaintingID(e.painting))
    if paintingSkill then
        log:trace("Skill for skill label: %s", paintingSkill)
        local paintingSkillLabel = block_details:createLabel { text = string.format("Painting skill: %s", paintingSkill), id = "JOPT.PaintingSkillLabel" }
        paintingSkillLabel:register(tes3.uiEvent.help, e.skillTooltipCallback)
    end

    local enchantSkill = tes3.mobilePlayer.enchant.current
    if enchantSkill then
        local enchantSkillLabel = block_details:createLabel { text = string.format("Enchant skill: %s", enchantSkill), id = "JOPT.EnchantSkillLabel" }
    end

    if enchantSkill or paintingSkill then
        block_details:createDivider()
    end

    enchantChance = block_details:createLabel { text = "Chance: 0%", id = "JOPT.ChanceLabel" }
    enchantChance:register("help", e.enchantChanceTooltipCallback)

    --buttons
    local button_block = border:createBlock { id = "JOPT.EnchantButtonBlock" }
    button_block.autoHeight = true
    button_block.autoWidth = true
    button_block.flowDirection = "left_to_right"
    button_block.borderTop = 6

    local button_cancel = button_block:createButton { text = "Cancel", id = "JOPT.CancelEnchantButton" }
    button_cancel.paddingAllSides = 6
    button_cancel.borderLeft = 12
    button_cancel.borderRight = 12
    button_cancel:register("mouseClick", function()
        collapsed = true
        button_enchant.visible = true
        border.visible = false
        log:debug("Clearing chosen soul gem")
        soulGem = nil
        item_icon.contentPath = nil
        item_icon.alpha = 0
        enchantChance.text = "Chance: 0%"
        button_confirm.disabled = true
    end)

    button_confirm = button_block:createButton { text = "Enchant", id = "JOPT.ConfirmEnchantButton" }
    button_confirm.paddingAllSides = 6
    button_confirm.borderLeft = 12
    button_confirm.borderRight = 12
    button_confirm.disabled = true
    button_confirm:register("mouseClick", function()
        log:trace("Enchant button clicked")
        local enchanted = EnchantMenu.attemptEnchant {
            painting = e.painting,
            soulGem = soulGem
        }
        log:debug("Clearing chosen soul gem")
        soulGem = nil
        item_icon.contentPath = nil
        item_icon.alpha = 0
        enchantChance.text = "Chance: 0%"
        button_confirm.disabled = true

        if enchanted then
            log:info("Removing enchantment UI block because painting was enchanted")
            if e.onEnchantSuccessCallback then e.onEnchantSuccessCallback() end
            block_outer:destroy()
        else
            if e.onEnchantFailCallback then e.onEnchantFailCallback() end
        end
    end)
    button_confirm:register("help", e.confirmEnchantTooltipCallback)


    button_enchant:register("mouseClick", function()
        collapsed = false
        button_enchant.visible = false
        border.visible = true
    end)


    if collapsed then
        button_enchant.visible = true
        border.visible = false
    else
        button_enchant.visible = false
        border.visible = true
    end

    log:trace("Enchant menu creation completed")
    event.trigger("JOPT.EnchantMenuCreated")
end

---@class JOPT.EnchantMenu.createTeleportBlock.params
---@field parent tes3uiElement
---@field painting JOP.Painting|JOP.Sketchbook.sketch
---@field teleportCallback fun(location: JOP.Painting.location)?
---@field borderSides number?
---@field addDivider boolean?

---@param e JOPT.EnchantMenu.createTeleportBlock.params
function EnchantMenu:createTeleportBlock(e)
    log:debug("Creating teleport block, parent: %s", e.parent.name)

    local block_outer = e.parent:createBlock({ id = "JOPT.TeleportOuterBlock" })
    block_outer.autoHeight = true
    block_outer.widthProportional = 1.0
    block_outer.flowDirection = "top_to_bottom"
    block_outer.childAlignX = 0.5
    block_outer.borderTop = 6
    block_outer.borderLeft = e.borderSides or 50
    block_outer.borderRight = e.borderSides or 50
    if e.addDivider then block_outer:createDivider() end

    ---@type JOP.Painting.location|string
    local location
    if e.painting.dataHolder then
        -- If it's a painting item
        location = e.painting.dataHolder.data.joyOfPainting.location
    else
        -- If it's a sketch in a sketchbook
        location = e.painting.data.location
    end
    local cellName = location.cellName or location --[[@as string]]
    local coords = string.format("(%i, %i, %i)", location.position.x, location.position.y, location.position.z)
    local header = block_outer:createLabel {
        text = string.format("Magically linked to %s, %s", cellName, coords),
        id = "JOPT.DestinationLabel"
    }
    header.widthProportional = 1.0
    header.autoHeight = true
    header.wrapText = true

    local button_teleport = block_outer:createButton { text = "Recall", id = "JOPT.TeleportButton" }
    button_teleport.borderAllSides = 8
    button_teleport.paddingTop = 8
    button_teleport.paddingBottom = 8
    button_teleport.paddingLeft = 24
    button_teleport.paddingRight = 24
    button_teleport:register("mouseClick", function()
        log:trace("Teleport button clicked")
        if e.teleportCallback then e.teleportCallback(location) end
    end)
    event.trigger("JOPT.TeleportMenuCreated")
end

return EnchantMenu
