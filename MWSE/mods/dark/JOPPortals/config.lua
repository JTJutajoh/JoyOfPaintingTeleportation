local log = mwse.Logger.new()
log:trace("Initializing MCM config")

local defaultConfig = {
    logLevel = "INFO",
    baseChance = 0.2,
    optimalSoulValue = 200,
    optimalEnchantLevel = 50,
    minChance = 0
}

local configPath = "JOP Teleportation"

local config = mwse.loadConfig(configPath, defaultConfig)

local function registerModConfig()
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
            { label = "TRACE", value = "TRACE"},
            { label = "DEBUG", value = "DEBUG"},
            { label = "INFO", value = "INFO"},
            { label = "ERROR", value = "ERROR"},
            { label = "NONE", value = "NONE"},
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
end
event.register(tes3.event.modConfigReady, registerModConfig)

return config