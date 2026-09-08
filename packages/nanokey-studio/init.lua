-- packages/nanokey-studio/init.lua
-- Facade export for Korg nanoKEY Studio driver, macros, and diagnostics probe.

local nanokey = require("nanokey")
local macros = require("macros")
local probe = require("probe")

return {
  driver = nanokey,
  macros = macros,
  probe = probe,
  connect = nanokey.connect,
  disconnect = nanokey.disconnect,
  setHud = nanokey.setHud,
  getLayer = nanokey.getLayer,
  setLayer = nanokey.setLayer
}
