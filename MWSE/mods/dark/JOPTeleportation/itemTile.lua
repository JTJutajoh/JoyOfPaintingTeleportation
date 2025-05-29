---@type JOPT_Config
local config = require("dark.JOPTeleportation.config")
if not config then return end

---@type mwseLogger
local log = mwse.Logger.new("JOPT - Tooltips")

PaintingRegistry = require("dark.JOPTeleportation.PaintingRegistry")
EnchantMenu = require("dark.JOPTeleportation.EnchantMenu")

local lfs = require("lfs")

-- Special compatibility with Seph's Inventory Decorator
-- Only load the config if the scripts folder exists (in case the user removed the scripts but not the config)
local config_inventoryDecorator

local function loadInventoryDecoratorConfigs()
    log:info("Loading configs from Seph's Inventory Decorator")
    -- Defaults copied directly from Seph's Inventory Decorator
    --in case they have never been modified for that mod, so they were never serialized to the config file.
    config_inventoryDecorator = mwse.loadConfig(
        "Seph's Inventory Decorator",
        {
            showEquipmentEffectIcons = true,
            effectIconSize = 12,
            effectIconStyle = "icon",
            effectIconPositionX = 90,
            effectIconPositionY = 10,
        }
    )
    if config_inventoryDecorator then
        log:trace("Loaded Seph's Inventory Decorator configs:\n%s", function() return json.encode(config_inventoryDecorator) end)
    end
end

if lfs.directoryexists("Data Files\\MWSE\\mods\\Seph\\InventoryDecorator") then
    log:info("Seph's Inventory Decorator detected, attempting to load its configs.")
    
    -- This is a HACK but it shouldn't be too bad.
    -- Every time a save is loaded, the configs from Seph's Inventory Decorator will be refreshed one frame later.
    -- I can't think of any better way to check if the configs have been updated and only refresh them as necessary, so this will have to do.
    -- It should be infrequent enough to not cause any performance issues, but frequent enough that most users will hardly notice it's happening, if any at all.
    event.register(tes3.event.loaded, function() timer.delayOneFrame(loadInventoryDecoratorConfigs) end)

    loadInventoryDecoratorConfigs()
end


---@param e itemTileUpdatedEventData
local function doEnchantedItemTile(e)
    log:trace("Drawing magic border on item %s", e.item.name)

    -- First fetch all settings from this mod's config
    local doMagicBorder = config.magicItemIconEffect == JOPT_MagicItemBorders.Vanilla or config.magicItemIconEffect == JOPT_MagicItemBorders.Both
    local doMagicEffectIcon = config.magicItemIconEffect == JOPT_MagicItemBorders.Recall or config.magicItemIconEffect == JOPT_MagicItemBorders.Both
    local magicItemIconEffectStyle = config.magicItemIconEffectStyle
    local magicItemIconEffectSize = config.magicItemIconEffectSize
    local magicItemIconEffectX = config.magicItemIconEffectX
    local magicItemIconEffectY = config.magicItemIconEffectY

    -- Then if Seph's Inventory Decorator is running, overwrite local settings with its settings
    if config_inventoryDecorator then
        log:info("Seph's Inventory Decorator is running, using its settings for item icons.")
        doMagicBorder = not config_inventoryDecorator.removeVanillaDecorators
        doMagicEffectIcon = config_inventoryDecorator.showEquipmentEffectIcons
        magicItemIconEffectStyle = config_inventoryDecorator.effectIconStyle
        magicItemIconEffectSize = config_inventoryDecorator.effectIconSize
        -- Seph's mod stores the positions as integer percentages, I'm using 0-1 decimals instead.
        magicItemIconEffectX = config_inventoryDecorator.effectIconPositionX / 100
        magicItemIconEffectY = config_inventoryDecorator.effectIconPositionY / 100
    end

    if doMagicEffectIcon then
        -- Ensure that the icon is only added to the tile once
        if not e.element:findChild("JOPT_MagicEffectIcon") then
            local iconPath = "Icons/" .. tes3.getMagicEffect(tes3.effect.recall)[magicItemIconEffectStyle]
            local icon = e.element:createImage { id = "JOPT_MagicEffect_Icon", path = iconPath }
            icon.scaleMode = true
            icon.absolutePosAlignX = magicItemIconEffectX
            icon.absolutePosAlignY = magicItemIconEffectY
            icon.width = magicItemIconEffectSize
            icon.height = magicItemIconEffectSize
            icon.consumeMouseEvents = false

            -- Move the iconv to the "end" AKA the foreground
            icon.parent:reorderChildren(-1, icon, 1)
        end
    else
        -- Remove the icon if we added it previously (such as if the setting was changed)
        local icon = e.element:findChild("JOPT_MagicEffectIcon")
        if icon then icon:destroy() end
    end
    if doMagicBorder then
        -- Ensure that the border is only added to the tile once
        if not e.element:findChild("JOPT_MagicBorder") then
            local border = e.element:createImage { id = "JOPT_MagicBorder", path = "Textures/menu_icon_magic.dds" }
            border.ignoreLayoutX = true
            border.ignoreLayoutY = true
            border.positionX = 0
            border.positionY = 0
            border.width = 64
            border.height = 64
            border.consumeMouseEvents = false

            -- Move the border to the "start" AKA the background
            border.parent:reorderChildren(0, border, 1)
        end
    else
        -- Remove the border if we added it previously (such as if the setting was changed)
        local border = e.element:findChild("JOPT_MagicBorder")
        if border then border:destroy() end
    end
end

---@param e itemTileUpdatedEventData
local function onItemTileUpdated(e)
    -- if not config.tooltipToggle then return end
    log:trace("onItemTileUpdated()")


    if e.itemData and e.itemData.data and e.itemData.data.joyOfPainting then
        local paintingData = e.itemData.data.joyOfPainting --[[@as JOP.Painting.data]]
    
        local enchanted = PaintingRegistry.isEnchanted(paintingData.paintingId)

        if enchanted then
            doEnchantedItemTile(e)
        end
    end
end
event.register(tes3.event.itemTileUpdated, onItemTileUpdated)
