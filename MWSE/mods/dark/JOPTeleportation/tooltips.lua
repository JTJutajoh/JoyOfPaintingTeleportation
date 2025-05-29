---@type JOPT_Config
local config = require("dark.JOPTeleportation.config")
if not config then return end

---@type mwseLogger
local log = mwse.Logger.new("JOPT - Tooltips")

-- local JoyOfPainting = require("mer.joyOfPainting")
-- if not JoyOfPainting then return end

PaintingRegistry = require("dark.JOPTeleportation.PaintingRegistry")
EnchantMenu = require("dark.JOPTeleportation.EnchantMenu")

---@class JOPT.doEnchantedTooltip.params
---@field tooltip tes3uiElement
---@field paintingId string
---@field location JOP.Painting.location

---@param params JOPT.doEnchantedTooltip.params
local function doEnchantedTooltip(params)
    local block_outer = params.tooltip:createBlock()
    block_outer.flowDirection = "top_to_bottom"
    block_outer.childAlignX = 0.5
    block_outer.autoWidth = true
    block_outer.autoHeight = true
    block_outer.borderTop = 4
    block_outer.borderBottom = 4
    block_outer.borderLeft = 10
    block_outer.borderRight = 10
    
    local enchantedLabel = block_outer:createLabel { text = "Enchanted" }
    enchantedLabel.color = { config.enchantedLabelColor.r, config.enchantedLabelColor.g, config.enchantedLabelColor.b }
    
    block_outer:createLabel { text = "Magically linked to:" }

    local locationText = params.location.cellName or "Unknown"
    if #locationText > config.locationNameTruncateLength then
        locationText = locationText:sub(1, config.locationNameTruncateLength - 3) .. "..."
    end
    local locationLabel = block_outer:createLabel {
        text = locationText
    }

    block_outer:createDivider()
end

---@param e uiObjectTooltipEventData
local function onTooltip(e)
    if not config.tooltipToggle then return end

    log:trace("onTooltip()")

    -- If it's an in-world object it will be a reference, otherwise it will be an object

    ---@type JOP.Painting.data
    local paintingData
    ---@type tes3itemData
    local itemData
    if e.reference then
        itemData = e.reference.itemData
    end
    if e.itemData then
        itemData = e.itemData
    end

    if itemData and itemData.data and itemData.data.joyOfPainting then
        paintingData = itemData.data.joyOfPainting --[[@as JOP.Painting.data]]
    else
        return
    end

    local enchanted = PaintingRegistry.isEnchanted(paintingData.paintingId)

    if enchanted then
        doEnchantedTooltip {
            tooltip = e.tooltip,
            location = paintingData.location,
            paintingId = paintingData.paintingId
        }
    end
end
event.register(tes3.event.uiObjectTooltip, onTooltip)
