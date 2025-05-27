---@type JOPT_Config
local config = require("dark.JOPTeleportation.config")
if not config then return end

---@type mwseLogger
local log = mwse.Logger.new("JOP Teleportation")

---Entrypoint for the whole mod, loads the other modules
local function initialized()
    log:info("Teleportation addon initialized")

    include("dark.JOPTeleportation.PaintingMenu")
    include("dark.JOPTeleportation.ActivatorMessageMenu")
end
event.register(tes3.event.initialized, initialized)
