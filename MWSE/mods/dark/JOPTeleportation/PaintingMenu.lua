local config = require("dark.JOPTeleportation.config")
if not config then return end

---@type mwseLogger
local log = mwse.Logger.new("JOPT - Painting Menu")

local EnchantMenu = include("dark.JOPTeleportation.EnchantMenu")

---@type JOP.Painting
local Painting = require("mer.joyOfPainting.items.Painting")
if not Painting then return end

---@type fun(self: JOP.Painting)
local original_Painting_paintingMenu = Painting.paintingMenu

--- Overrides the JOP method for opening the "Vew Painting" menu, injecting additional UI elements into the menu after calling the original.
--- It should only ever run this replacer when the painting menu is opened for a valid, completed painting. Not, for example, when naming a painting right after finishing it.
--- This method should hopefully be the most future-proof and have no code copying. 
function Painting:paintingMenu()
    log:debug("Running Painting:paintingMenu replacer patch")

    -- Call the original version of Painting:paintingMenu, since this method overrides it
    log:trace("Calling original JOP Painting:paintingMenu")
    original_Painting_paintingMenu(self)

    ---@type tes3uiElement?
    local menu = tes3ui.findMenu("JOP.NamePaintingMenu")
    if menu then
        log:trace("Found JOP.NamePaintingMenu")
        local enchantMenu = EnchantMenu:new {
            painting = self,
            parent = menu,
            addDivider = true,
            borderSides = 20,
        }
    else
        log:error("Failed to find the name painting menu after it should have been created.")
    end
    log:trace("Finished running Painting:paintingMenu replacer patch")
end
