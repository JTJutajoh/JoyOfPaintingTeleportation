local log = mwse.Logger.new()
log.modName = "JOP Teleportation"

local config = require("dark.joyOfPaintingTeleportationAddon.config")
if not config then return end

local JoyOfPainting = require("mer.joyOfPainting")
if not JoyOfPainting then return end

local CraftingFramework = include("CraftingFramework")
if not CraftingFramework then return end

include("dark.joyOfPaintingTeleportationAddon.PaintingMenu")

local frames = {
    {
        id = "jopt_frame_w_01",
        frameSize = "wide"
    },
    {
        id = "jopt_frame_t_01",
        frameSize = "tall"
    },
    {
        id = "jopt_frame_sq_01",
        frameSize = "square"
    }
}

local function registerFrames()
    log:info("Registering addon frame(s)")

    for _, frame in ipairs(frames) do
        JoyOfPainting.Frame.registerFrame(frame)
    end
end

local function initialized()
    log:info("Teleportation addon initialized")

    registerFrames()
end
event.register(tes3.event.initialized, initialized)

-- TileDropper implementation Below
-------------------------------------

---@param soul any The contained itemData.soul in a soul gem
---@return boolean 
local function CanUseSoulGem(soul)
    if not soul or not soul.soul then
        return false
    end
    return soul.soul >= 0
end

---@param soul any
---@return number
local function CalcEnchantChance(soul)
    if soul and soul.soul then
        local soulContribution = (1 - math.max(((config.optimalSoulValue - soul.soul) / config.optimalSoulValue), 0))
        local skillContribution = math.max((-config.optimalEnchantLevel + tes3.mobilePlayer.enchant.current) / config.optimalEnchantLevel, -1)
        return math.max(config.baseChance + soulContribution + skillContribution, config.minChance)
    end
    return 0
end

---@param itemInfo CraftingFramework.TileDropper.itemInfo
---@param soul any
local function EnchantFrame(itemInfo, soul)
    tes3.removeItem{
        reference = tes3.player,
        item = itemInfo.item,
        count = 1,
    }
    local _, item, itemData = tes3.addItem{
        reference = tes3.player,
        item = itemInfo.item,
        count = 1,
    }
    itemData = tes3.addItemData{
        to = tes3.player,
        item = item
    }
    itemData.data.echanted = true
end

CraftingFramework.TileDropper.register{
    name = "FrameEnchantingTileDropper",
    isValidTarget = function(params)
        return JoyOfPainting.Frame.isFrame(params.item)
    end,
    canDrop = function(params)
        return CanUseSoulGem(params.held.itemData.soul)
    end,
    onDrop = function(params)
        if not params.held.itemData then
            return
        end
        local soul = params.held.itemData.soul
        local chance = CalcEnchantChance(soul)
        tes3ui.showMessageMenu{
            header = "Enchant frame",
            message = "Chance increases with Enchant skill and soul value.\nUses up the soul gem.",
            buttons = {
                {
                    text = string.format("Use (Chance: %i%%)", chance*100),
                    callback = function()
                        local success = CalcEnchantChance(soul) >= math.random()
                        if success then
                            tes3ui.showNotifyMenu("Success!")
                            EnchantFrame(params.target, soul)
                        else 
                            tes3ui.showNotifyMenu("Failed")
                        end
                    end,
                    tooltip = {
                        callback = function(p) return end,
                        header = string.format("%s (%i)", soul.name, soul.soul),
                        text = "Uses and destroys the selected soul gem.\nThe displayed chance is the chance of successfully enchanting the frame. Determined by a combination of your Enchant level and the soul's strength.\nSee MCM to fine-tune these."
                    },
                    showRequirements = function() return true end,
                    enableRequirements = function()
                        return CanUseSoulGem(soul) and chance > 0
                    end,
                    tooltipDisabled = "Not a strong enough soul",
                }
            },
            ---@param parent tes3uiElement
            customBlock = function(parent)
                parent.flowDirection = tes3.flowDirection.leftToRight
                parent:createLabel{
                    text = "Using: "
                }
                local border = parent:createThinBorder()
                border.autoHeight = true
                border.autoWidth = true
                border:createImage{
                    path = "icons\\"..params.held.item.icon,
                    maxHeight = 100,
                    maxWidth = 100
                }
                parent:createLabel{
                    text = string.format("%s (%i)", soul.name, soul.soul)
                }
            end,
            cancels = true
        }
    end
}
