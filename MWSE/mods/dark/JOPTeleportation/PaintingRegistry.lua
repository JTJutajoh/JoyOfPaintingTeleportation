local PaintingRegistry = {}

local SkillService = include("mer.joyOfPainting.services.SkillService")
if not SkillService then return end

---@type JOPT_Config
local config = require("dark.JOPTeleportation.config")
if not config then return end

---@type mwseLogger
local log = mwse.Logger.new("JOPT - Painting Registry")

--- A single entry in the data registry that is matched to a unique painting ID
---@class JOPT.PaintingRegistry.Painting
---@field enchanted boolean?
---@field skill number?

--- A table that stores all paintings and their enchanted status, so it persists even when JOP destroys the painting items
---@class JOPT.PaintingRegistry
---@field enchantedPaintings { [string] : JOPT.PaintingRegistry.Painting } Map of painting IDs to enchanted status

--- Fetches the data registry attached to the player, which is serialized and persistent within the save. 
--- If no registry is found, initializes an empty one.
---@return JOPT.PaintingRegistry? registry
function PaintingRegistry.getRegistry()
    local playerData = tes3.player and tes3.player.data or nil
    if not playerData then
        log:warn("Failed to get data registry, playerData not found")
        return nil
    end
    if playerData.JOPT then
        -- log:trace("Read registry. Contents: %s", function() return json.encode(playerData.JOPT) end)
    else
        log:info("Initializing new empty PaintingRegistry on player")
        playerData.JOPT = { enchantedPaintings = {} } --[[@as JOPT.PaintingRegistry]]
    end
    return playerData.JOPT
end

--- Replaces the data associated with a given painting ID in the registry, creating a new entry for it if one does not exist
---@param paintingId string The unique ID for a specific painting set by JOP, will be the filename of the texture
---@param data JOPT.PaintingRegistry.Painting
---@see JOP.Painting.data.paintingId
function PaintingRegistry.storePaintingData(paintingId, data)
    local registry = PaintingRegistry.getRegistry()
    if registry then
        log:info("Storing data for painting '%s': %s", paintingId, data)
        if registry[paintingId] then
            log:warn(
                [[
Overwriting data stored in registry for '%s'.
Old data: %s
New data: %s
]],
                paintingId,
                function() return json.encode(registry[paintingId]) end,
                function() return json.encode(data) end
            )
        end
        registry.enchantedPaintings[paintingId] = data
        event.trigger("JOPT.PaintingDataStored", { paintingId = paintingId, data = data })
    end
end

--- Marks a painting's corresponding entry as being enchanted, modifying the entry if it already exists and creating a new one if it does not.
---@param paintingId string The unique ID for a specific painting set by JOP, will be the filename of the texture
---@param enchanted boolean
---@see JOP.Painting.data.paintingId
function PaintingRegistry.storePaintingIsEnchanted(paintingId, enchanted)
    local registry = PaintingRegistry.getRegistry()
    if registry then
        log:info("Storing data for painting '%s': %s", paintingId, enchanted)
        if registry.enchantedPaintings[paintingId] then
            log:debug("Updating existing record for '%s' setting enchanted to %s", paintingId, enchanted)
            registry.enchantedPaintings[paintingId].enchanted = enchanted
        else
            log:debug("Creating new record for '%s' with enchanted %s", paintingId, enchanted)
            PaintingRegistry.storePaintingData(paintingId, {
                enchanted = enchanted,
            })
        end
        event.trigger("JOPT.PaintingEnchanted", { paintingId = paintingId, enchanted = enchanted })
    end
end

--- Returns all of the data stored in the registry for a given painting ID, or nil if it is not tracked
---@param paintingId string The unique ID for a specific painting set by JOP, will be the filename of the texture
---@return JOPT.PaintingRegistry.Painting? data Data associated with the painting or nil if it has not been registered
---@see JOP.Painting.data.paintingId
function PaintingRegistry.getPaintingData(paintingId)
    local registry = PaintingRegistry.getRegistry()
    if registry and registry.enchantedPaintings[paintingId] then
        log:trace("Fetching data for painting '%s': %s", paintingId, registry.enchantedPaintings[paintingId])
        return registry.enchantedPaintings[paintingId]
    end
    log:trace("No data found for painting '%s'", paintingId)
    return nil
end

--- Fetches data from the registry for a given painting if it exists
---@param paintingId string The unique ID for a specific painting set by JOP, will be the filename of the texture
---@return boolean enchanted True if the painting is tracked and the data says it is enchanted. False if it is untracked or marked unenchanted for some reason
---@see JOP.Painting.data.paintingId
function PaintingRegistry.isEnchanted(paintingId)
    local data = PaintingRegistry.getPaintingData(paintingId)
    if data then
        return data.enchanted
    end
    return false
end

---@param paintingId string
---@return number? skill Will be nil if there is no stored data on the given painting
function PaintingRegistry.skillWhenPainted(paintingId)
    local data = PaintingRegistry.getPaintingData(paintingId)
    if data and data.skill then
        return data.skill
    end
    return nil
end

--- Event callback that runs whenever any object is created in the game so that it can catch and track any paintings
--- This is to attach the player painting skill level at the time of painting to the painting, since JOP does not store that data
---@param e objectCreatedEventData
function PaintingRegistry.onObjectCreated(e)
    if not tes3.player then return end
    if e.object.objectType == tes3.objectType.miscItem and e.object.id:sub(-4, -1) == ".dds" then
        local object = e.object --[[@as tes3misc]]
        local id = object.id
        local alreadyTracked = PaintingRegistry.getPaintingData(id) ~= nil
        log:debug("Painting object just created: %s (Already tracked? %s)", id, alreadyTracked)
        if not alreadyTracked then
            timer.start {
                duration = 0.2,
                callback = function()
                    local skill = SkillService.getPaintingSkillLevel()
                    log:info("Storing painting skill level %i with %s", skill, id)
                    PaintingRegistry.storePaintingData(id, { skill = skill, enchanted = false })
                end
            }
        end
    end
end
event.register(tes3.event.objectCreated, PaintingRegistry.onObjectCreated)

return PaintingRegistry
