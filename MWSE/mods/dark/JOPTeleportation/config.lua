local config = {}
---@type mwseLogger
local log = mwse.Logger.new("JOPT - Config")
log:info("Initializing MCM config")

---@enum JOPT.MagicItemBorders
JOPT_MagicItemBorders = {
    None = 0,
    Vanilla = 1,
    Recall = 2,
    Both = 3,
}
---@class JOPT_Config
---@field metadata MWSE.Metadata?
---@field logLevel mwseLogger.logLevel|mwseLogger.logLevelString
---@field minSoulStrength integer Minimum strength to filter soul gems using
---@field baseChance number The base chance before all other contributions are added
---@field optimalSoulValue integer Soul values below this incur a penalty to enchant chance
---@field optimalEnchantLevel integer Enchant skill levels below this incur a penalty to enchant chance
---@field minChance number Minimum 0-1 chance that enchanting will succeed
---@field tooltipToggle boolean
---@field enchantedLabelColor mwseColorTable
---@field locationNameTruncateLength integer
---@field magicItemIconEffect JOPT.MagicItemBorders
---@field magicItemIconEffectStyle string
---@field magicItemIconEffectSize integer
---@field magicItemIconEffectX number
---@field magicItemIconEffectY number

---@type JOPT_Config
local defaultConfig = {
    logLevel = "INFO",
    minSoulStrength = 50,
    baseChance = 0.4,
    optimalSoulValue = 300,
    optimalEnchantLevel = 75,
    minChance = 0,
    tooltipToggle = true,
    enchantedLabelColor = { r = 0.5, g = 0.35, b = 0.6 },
    locationNameTruncateLength = 30,
    magicItemIconEffect = JOPT_MagicItemBorders.Vanilla,
    magicItemIconEffectStyle = "icon",
    magicItemIconEffectSize = 12,
    magicItemIconEffectX = 0.9,
    magicItemIconEffectY = 0.1,
}


---@type string
local configPath = "JOP Teleportation"

config = mwse.loadConfig(configPath, defaultConfig) --[[@as JOPT_Config]]
if not config then
    log:error("Error loading mod config.")
    return
end
log.level = config.logLevel


if toml.loadMetadata then
    config.metadata = toml.loadMetadata("Joy Of Painting Teleportation")
else
    config.metadata = toml.loadFile("Data Files\\Joy Of Painting Teleportation-metadata.toml")
end
if not config.metadata then
    log:warn("Failed to load metadata.toml")
    ---@diagnostic disable missing-fields
    config.metadata = {
        package = {
            name = "Joy Of Painting Teleportation",
        }
    }
    ---@diagnostic enable missing-fields
end


local lfs = require("lfs")

-- Special compatibility with Seph's Inventory Decorator
-- Only load the config if the scripts folder exists (in case the user removed the scripts but not the config)
local config_inventoryDecorator
if lfs.directoryexists("Data Files\\MWSE\\mods\\Seph\\InventoryDecorator") then
    config_inventoryDecorator = mwse.loadConfig("Seph's Inventory Decorator")
end

---@param sidebar mwseMCMMouseOverPage
local function doSidebar(sidebar)
    sidebar:createCategory(config.metadata.package.name)
    sidebar:createInfo { text = config.metadata.package.description }

    local linksCategory = sidebar:createCategory("Links")
    linksCategory:createHyperlink { text = "Joy Of Painting (Required)", url = "https://www.nexusmods.com/morrowind/mods/53036" }
    linksCategory:createHyperlink { text = "Seph's Inventory Decorator (Compatible, recommended)", url = "https://www.nexusmods.com/morrowind/mods/50582" }

    local creditsCategory = sidebar:createCategory("Credits")
    creditsCategory:createHyperlink { text = "Created by Dark", url = "" }
    creditsCategory:createHyperlink { text = "Original mod by Merlord", url = "https://next.nexusmods.com/profile/Merlord/mods" }
end

---Creates the MCM for the mod
local function registerModConfig()
    ---@type mwseMCMTemplate
    local template = mwse.mcm.createTemplate({
        name = "Joy Of Painting Teleportation",
        config = config,
        defaultConfig = defaultConfig,
        showDefaultSetting = true,
    })

    template:register()

    template:saveOnClose(configPath, config)

    local page = template:createSideBarPage({ label = "Settings" })

    doSidebar(page.sidebar)

    page:createDropdown({
        label = "Logging Level",
        description = "Set the log level. DEBUG and TRACE not recommended for normal play, only for troubleshooting.",
        configKey = "logLevel",
        options = {
            {  label = "TRACE", value = "TRACE" },
            {  label = "DEBUG", value = "DEBUG" },
            {  label = "INFO", value = "INFO" },
            {  label = "ERROR", value = "ERROR" },
            {  label = "NONE", value = "NONE" },
        },
        callback = function(self)
            log.level = self.variable.value
        end
    })

    -- Balance settings
    local category_balance = page:createCategory({
        label = "Balance",
        description = "Tweaks to the balance of enchanting paintings."
    })
    category_balance:createPercentageSlider({
        label = "Base enchant success chance",
        configKey = "baseChance",
        description = "The minimum chance enchanting a frame will work, before any modifiers applied.\nNote that the final chance may be lower than this value if the soul is weak and/or Enchant skill is low."
    })

    category_balance:createSlider({
        label = "Minimum soul strength",
        configKey = "minSoulStrength",
        max = 1600,
        step = 10,
        description = "The minimum strength of a trapped soul for a soul gem to be valid for enchanting."
    })

    category_balance:createSlider({
        label = "Optimal soul strength",
        configKey = "optimalSoulValue",
        max = 1600,
        step = 10,
        description = "Souls of this value or greater will have the highest chance of success.",
    })

    category_balance:createSlider({
        label = "Optimal Enchant level",
        configKey = "optimalEnchantLevel",
        max = 100,
        description = "Enchanting a frame with an Enchant skill below this value will result in decreased success chance. Above this value will increase the chance.",
    })

    category_balance:createPercentageSlider({
        label = "Minimum success chance",
        configKey = "minChance",
        description = "The minimum chance enchanting a frame will work. Set this to 100% to make enchants always succeed.",
    })

    -- Appearance
    local category_appearance = page:createCategory({
        label = "Appearance",
    })

    -- If Seph's Inventory Decorator is running, copy its settings. Otherwise, show some settings similar to its
    if not config_inventoryDecorator then
        -- Magic Effect icons
        local category_magicEffectIcon = category_appearance:createCategory({
            label = "Magic Effect Icons",
            description = [[
If the Magic Effect is set to display the icon, these settings control its appearance. Does nothing if it is not enabled.
Analagous to Seph's Inventory Customizer.
]],
            postCreate = function(self)
                local block = self.elements.labelBlock:createBlock()
                block.flowDirection = tes3.flowDirection.leftToRight
                block.paddingLeft = 10
                block.paddingBottom = 6
                if block then
                    block:createLabel {
                        text = "Compatible (and designed to work with) "
                    }
                    block:createHyperlink {
                        text = "Seph's Inventory Decorator",
                        url = "https://www.nexusmods.com/morrowind/mods/50582"
                    }
                end
            end
        })
        category_magicEffectIcon:createDropdown({
            label = "Inventory Icon",
            configKey = "magicItemIconEffect",
            description = [[
Choose the visual effect added to item icons of paintings that have been enchanted.
"Vanilla" will add the same swirly magic effect that enchanted items usually have in vanilla. If you have a replacer for this texture it should use your modded texture.
"Recall" will add a small icon for the recall spell in the corner of the tile, similar to Seph's Inventory Decorator.
If Seph's Inventory Decorator is detected, use its MCM to change these instead.
]],
            options = (function()
                local options = {}
                for k, v in pairs(JOPT_MagicItemBorders) do
                    options[#options + 1] = { label = k, value = v }
                end
                return options
            end)(),
        })

        category_magicEffectIcon:createDropdown({
            label = "Style",
            description = "Exactly like Seph's Inventory Decorator, lets you toggle between the large, detailed textures or the small, simple ones.",
            configKey = "magicItemIconEffectStyle",
            options = {
                { label = "Simple", value = "icon" },
                { label = "Detailed", value = "bigIcon" }
            }
        })
        category_magicEffectIcon:createSlider({
            label = "Size",
            configKey = "magicItemIconEffectSize",
            max = 64,
        })
        category_magicEffectIcon:createPercentageSlider({
            label = "Horizontal position",
            configKey = "magicItemIconEffectX"
        })
        category_magicEffectIcon:createPercentageSlider({
            label = "Vertical position",
            configKey = "magicItemIconEffectY"
        })
    end

    -- Tooltip settings
    local category_tooltips = category_appearance:createCategory({
        label = "Tooltips",
    })

    local truncateSlider
    local colorPicker
    category_tooltips:createDropdown({
        label = "Add enchanted info to tooltips",
        configKey = "tooltipToggle",
        description = "If enabled, paintings that have been enchanted for teleportation will have extra info added to their item tooltips.\nAlso includes frames and easels containing an enchanted painting.",
        options = {
            { value = true, label = "Enabled" },
            { value = false, label = "Disabled" },
        },
        callback = function(self)
            if config[self.configKey] then
                truncateSlider:enable()
                colorPicker:enable()
            else
                truncateSlider:disable()
                colorPicker:disable()
            end
        end,
    })
    
    truncateSlider = category_tooltips:createSlider({
        label = "Maximum location name length",
        configKey = "locationNameTruncateLength",
        description = "Location names longer than this will be cut off in tooltips to prevent the UI layout from getting messed up.",
        max = 64,
    })

    colorPicker = category_tooltips:createColorPicker({
        label = "Enchanted tooltip color",
        configKey = "enchantedLabelColor",
        description = "Color of the extra label added to enchanted paintings.",
        vertical = true,
    })
end
event.register(tes3.event.modConfigReady, registerModConfig)

return config
