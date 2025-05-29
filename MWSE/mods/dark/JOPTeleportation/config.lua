---@type mwseLogger
local log = mwse.Logger.new("JOPT - Config")
log:info("Initializing MCM config")

---@class (exact) JOPT_Config
---@field logLevel mwseLogger.logLevel|mwseLogger.logLevelString
---@field minSoulStrength integer Minimum strength to filter soul gems using
---@field baseChance number The base chance before all other contributions are added
---@field optimalSoulValue integer Soul values below this incur a penalty to enchant chance
---@field optimalEnchantLevel integer Enchant skill levels below this incur a penalty to enchant chance
---@field minChance number Minimum 0-1 chance that enchanting will succeed
---@field tooltipToggle boolean
---@field enchantedLabelColor mwseColorTable
---@field locationNameTruncateLength integer

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
}

---@type string
local configPath = "JOP Teleportation"

local config = mwse.loadConfig(configPath, defaultConfig) --[[@as JOPT_Config]]
if not config then
    log:error("Error loading mod config.")
    return
end
log.level = config.logLevel

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

    page:createDropdown({
        label = "Logging Level",
        description = "Set the log level.",
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

    page:createPercentageSlider({
        label = "Base enchant success chance",
        configKey = "baseChance",
        description = "The minimum chance enchanting a frame will work, before any modifiers applied.\nNote that the final chance may be lower than this value if the soul is weak and/or Enchant skill is low."
    })

    page:createSlider({
        label = "Minimum soul strength",
        configKey = "minSoulStrength",
        max = 1600,
        step = 10,
        description = "The minimum strength of a trapped soul for a soul gem to be valid for enchanting."
    })

    page:createSlider({
        label = "Optimal soul strength",
        configKey = "optimalSoulValue",
        max = 1600,
        step = 10,
        description = "Souls of this value or greater will have the highest chance of success.",
    })

    page:createSlider({
        label = "Optimal Enchant level",
        configKey = "optimalEnchantLevel",
        max = 100,
        description = "Enchanting a frame with an Enchant skill below this value will result in decreased success chance. Above this value will increase the chance.",
    })

    page:createPercentageSlider({
        label = "Minimum success chance",
        configKey = "minChance",
        description = "The minimum chance enchanting a frame will work. Set this to 100% to make enchants always succeed.",
    })

    page:createDropdown({
        label = "Add enchanted info to tooltips",
        configKey = "tooltipToggle",
        description = "If enabled, paintings that have been enchanted for teleportation will have extra info added to their item tooltips.",
        options = {
            { value = true, label = "Enabled" },
            { value = false, label = "Disabled" },
        }
    })

    page:createColorPicker({
        label = "Enchanted tooltip color",
        configKey = "enchantedLabelColor",
        description = "Color of the extra label added to enchanted paintings."
    })

    page:createSlider({
        label = "Max location name in tooltips",
        configKey = "locationNameTruncateLength",
        max = 64,
    })
end
event.register(tes3.event.modConfigReady, registerModConfig)

return config
