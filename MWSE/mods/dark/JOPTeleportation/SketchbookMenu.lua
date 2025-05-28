local config = require("dark.JOPTeleportation.config")
if not config then return end

---@type mwseLogger
local log = mwse.Logger.new("JOPT - Sketchbook Menu")

local EnchantMenu = include("dark.JOPTeleportation.EnchantMenu")

---@type JOP.Painting
local Painting = require("mer.joyOfPainting.items.Painting")
if not Painting then return end

---@type JOP.Sketchbook
local Sketchbook = require("mer.joyOfPainting.items.Sketchbook")
if not Sketchbook then return end

---@type fun(self: JOP.Sketchbook, parent: tes3uiElement)
local original_Sketchbook_createNameField = Sketchbook.createNameField

--- Overrides the JOP method for opening the "Vew Painting" menu, injecting additional UI elements into the menu after calling the original.
--- It should only ever run this replacer when the painting menu is opened for a valid, completed painting. Not, for example, when naming a painting right after finishing it.
--- This method should hopefully be the most future-proof and have no code copying. 
--- @param parent tes3uiElement
function Sketchbook:createNameField(parent)
    log:debug("Running Sketchbook.createNameField replacer patch")

    -- Call the original version of Sketchbook.createNameField, since this method overrides it
    log:trace("Calling original JOP Sketchbook.createNameField")
    original_Sketchbook_createNameField(self, parent)

    if self.data and self.data.sketches and #self.data.sketches ~= 0 then
        local sketch = self:getCurrentSketch()
        if sketch then
            log:debug("Current sketch: %s with data:\n%s", sketch.itemId, sketch.data)

            ---@type JOPT.tes3itemChildren?
            local item = self:getSketchObject()
            if not item then
                log:error("Failed to get the item for the current sketch")
                return
            end

            log:trace("Sketch item %s with itemData:\n%s", item.id, sketch.data or "NONE!")

            local enchantMenu = EnchantMenu:new {
                painting = sketch,
                parent = parent,
                addDivider = false,
                borderSides = 0,
            }
        else
            log:info("Not adding enchant block, no sketch")
        end

        log:trace("Finished running Sketchbook.createNameField replacer patch")
    end
end
