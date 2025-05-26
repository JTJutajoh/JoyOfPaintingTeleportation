local config = require("dark.joyOfPaintingTeleportationAddon.config")
if not config then return end

local utils = require("dark.joyOfPaintingTeleportationAddon.utils")
if not utils then return end

local JoyOfPainting = require("mer.joyOfPainting")
local UIHelper = require("mer.joyOfPainting.services.UIHelper")
if not JoyOfPainting then return end

local log = mwse.Logger.new()

local EnchantMenu = {}

local function initialize()
    log:debug("Initialized enchant menu")
    EnchantMenu.menuID = tes3ui.registerID("JOPT:EnchantMenu")
end
event.register(tes3.event.initialized, initialize)

function EnchantMenu:onCancel()
    log:trace("Enchant menu canceled")
    local menu = tes3ui.findMenu(EnchantMenu.menuID)

    if menu then
        log:debug("Closing enchant menu (canceled).")
        tes3ui.leaveMenuMode()
        menu:destroy()
    end
end

function EnchantMenu:onConfirm()
    log:trace("Enchant menu confirmed")
    local menu = tes3ui.findMenu(EnchantMenu.menuID)

    if menu then
        tes3.playSound{
            reference = tes3.player,
            sound = "mysticism hit"
        }
        tes3.messageBox("Successfully enchanted painting.")
        EnchantMenu.painting.dataHolder.data.enchanted = true
        log:debug("Closing enchant menu (confirmed).")
        tes3ui.leaveMenuMode()
        menu:destroy()
    end
end

---@param painting JOP.Painting
function EnchantMenu:createMenu(painting)
    if tes3ui.findMenu(self.menuID) ~= nil then
        log:warn("Tried to create duplicate EnchantMenu")
        return
    end

    if painting == nil then
        log:error("Cannot create enchant menu, painting was nil")
        return
    end
    EnchantMenu.painting = painting

    log:debug("Creating enchant menu.")

    local menu = tes3ui.createMenu{
        id = EnchantMenu.menuID,
        fixedFrame = true,
    }
    menu.minWidth = 500
    menu.maxWidth = 800
    menu.minHeight = 400
    menu.maxHeight = 800
    menu.alpha = 0.9
    menu.paddingAllSides = 12
    menu.flowDirection = "top_to_bottom"
    menu.childAlignX = 0.5

    local label = menu:createLabel{text = "Enchant painting"}
    label.borderBottom = 10

    local painting_texture = menu:createImage{
        path = "Textures\\jop\\p\\"..EnchantMenu.painting.data.paintingTexture
    }
    painting_texture.widthProportional = 1.0
    painting_texture.autoHeight = true

    local block = menu:createBlock{}
    block.width = 700
    block.autoHeight = true
    block.childAlignX = 0.5

    local border = block:createThinBorder{}
    border.widthProportional = 1.0
    border.autoHeight = true
    border.childAlignX = 0.5
    border.childAlignY = 0.5
    border.flowDirection = "left_to_right"

    local border_soul = border:createThinBorder{}
    border_soul.width = 100
    border_soul.height = 100
    border_soul.childAlignX = 0.5
    border_soul.childAlignY = 0.5

    local item_icon = border_soul:createImage{
        path = "icons\\jop\\pastels.dds"
    }
    item_icon.scaleMode = true
    item_icon.height = 100
    item_icon.width = 100

    local details = border:createLabel{text = [[
Various text about the enchantment goes here.
Like enchantment %
Soul information
And justifications.
]]}
    details.autoWidth = true
    details.autoHeight = true
    details.justifyText = tes3.justifyText.right

    local description = menu:createLabel{text = [[
Attempt to enchant the painting/drawing with the power of a trapped soul.
If successful, the painting will be magically linked to the exact spot where it was originally painted, allowing it to be used as a portal.
The chance of success is based on the strength of the soul and the enchanter's Enchant skill (configurable in MCM).
]]}
    description.autoHeight = true
    description.widthProportional = 1.0

    local button_block = menu:createBlock{}
    button_block.widthProportional = 1.0
    button_block.autoHeight = true
    button_block.childAlignX = 1.0

    local button_confirm = button_block:createButton{text = "Enchant"}
    local button_cancel = button_block:createButton{text = "Cancel"}

    button_confirm:register("mouseClick", EnchantMenu.onConfirm)
    button_cancel:register("mouseClick", EnchantMenu.onCancel)
    border_soul:register("mouseClick", function() tes3ui.showNotifyMenu("Clicked soul border") end)

    log:trace("Showing enchant menu.")
    menu:updateLayout()
    tes3ui.enterMenuMode(menu.id)
end

return EnchantMenu