local config = require("dark.joyOfPaintingTeleportationAddon.config")
if not config then return end

local EnchantMenu = require("dark.joyOfPaintingTeleportationAddon.EnchantMenu")
if not EnchantMenu then return end

local JoyOfPainting = require("mer.joyOfPainting")
local UIHelper = require("mer.joyOfPainting.services.UIHelper")
if not JoyOfPainting then return end

local log = mwse.Logger.new()

local original_Painting_paintingMenu = JoyOfPainting.Painting.paintingMenu

local function teleport(location)
    log:info("Teleporting to painting")
    log:debug("Teleport destination location:\n%s", function() return json.encode(location) end)
    tes3.playSound{
        reference = tes3.player,
        sound = "mysticism hit"
    }
    tes3.positionCell{
        reference = tes3.mobilePlayer,
        cell = location.cellId,
        position = location.position,
        orientation = location.orientation,
        teleportCompanions = true
    }
end

---@param painting JOP.Painting
local function generateButtons(painting)
    log:debug("Generating button(s) for painting menu.")
    if not painting.dataHolder.data then
        log:error("No item data found on painting.")
        return
    end

    local buttons = {}
    local data = painting.dataHolder.data
    log:trace("Painting data:\n%s", function() return json.encode(data) end)

    if data.enchanted then
        log:debug("Painting is already enchanted. Adding Teleport button to the painting menu's buttons")
        local location = data.joyOfPainting.location
        if location == nil then
            log:error("No location data in the painting's dataHolder. Data:\n%s", function() return json.encode(data) end)
            tes3ui.showNotifyMenu("Painting has no location data, check MWSE.log.")
        else
            log:trace("Inserting Teleport button")
            table.insert(buttons, {
                text = "Teleport",
                callback = teleport(location),
                closesMenu = true
            })
        end
    else
        log:debug("Painting is not enchanted, adding Enchant button to the painting menu's buttons.")
        table.insert(buttons, {
            text = "Enchant",
            callback = function()
                log:trace("Inserting Enchant button")
                if data.enchanted then
                    log:warn("Attempted to enchant a painting that has already been enchanted.")
                    tes3.messageBox("Painting already enchanted!")
                else
                    log:trace("Creating enchant menu next frame.")
                    timer.delayOneFrame(function() 
                        EnchantMenu:createMenu(painting) 
                    end)
                end
            end,
            closesMenu = true
        })
    end

    return buttons
end

--- Overrides the JOP method for opening the "Vew Painting" menu, injecting additional button(s) into the menu before calling the original.
--- It's a somewhat janky solution but it works. It hard-coded replaces one of the (unused) parameters in the original UIHelper.openPaintingMenu method every time it is called by Painting:paintingMenu
--- This means it should only ever run this replacer when the painting menu is opened for a valid, completed painting. Not, for example, when naming a painting right after finishing it.
--- This method should hopefully be the most future-proof and have no code copying. 
function JoyOfPainting.Painting:paintingMenu()
    log:trace("Running Painting:paintingMenu replacer patch")

    -- Store a reference to the original version of the function in JOP
    local original_UIHelper_openPaintingMenu = UIHelper.openPaintingMenu
    
    local buttons = generateButtons(self)

    -- Replace the reference to the function with a new function that:
    -- 1. Inserts buttons into the params table 'e'
    -- 2. Calls the original method with the edited params table
    log:debug("Replacing joyOfPainting.services.UIHelper.openPaintingMenu with patched version.")
    UIHelper.openPaintingMenu = function(e) -- IGNORE THE IDE WARNING! Duplicate field is intentional
        log:debug("Adding buttons to the painting menu")
        e.buttons = e.buttons or {}
        log:trace("Original buttons:\n%s", function() return json.encode(e.buttons) end)
        for _, button in ipairs(buttons) do
            log:debug("Adding button: \"%s\"", button.text)
            table.insert(e.buttons, button)
        end
        
        log:trace("Calling original JOP UIHelper.openPaintingMenu with button(s) injected into the params.")
        return original_UIHelper_openPaintingMenu(e)
    end

    -- Call the original version of Painting:paintingMenu, since this method overrides it
    log:trace("Calling original JOP Painting:paintingMenu")
    original_Painting_paintingMenu(self)

    -- Restore the original version of the UIHelper function (in case it gets called by something else)
    log:debug("Restoring original joyOfPainting.services.UIHelper.openPaintingMenu.")
    UIHelper.openPaintingMenu = original_UIHelper_openPaintingMenu
end
