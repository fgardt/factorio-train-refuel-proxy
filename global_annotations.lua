---@meta

---@class LocomotiveInfo Storing all necessary details about a locomotive
---@field entity LuaEntity The locomotive entity
---@field burner LuaBurner The burner of the locomotive
---@field last_fuel LuaItemPrototype? The last burnt fuel of this locomotive
---@field fuel_inv LuaInventory The fuel inventory of the locomotive
---@field request_proxy LuaEntity? The item_request_proxy to provide this locomotive with new fuel
---@field next_unit uint The unit_number of the next locomotive in the ringbuffer
---@field prev_unit uint The unit_number of the previous locomotive in the ringbuffer

---@class Global
---@field rate 0|1|60|300|600
---@field locomotives {[uint]: LocomotiveInfo} Ringbuffer of locomotives
---@field count uint
---@field next_check uint? unit_number of the locomotive that gets checked next
---@field ticks_per_check uint
---@field entities_per_check uint
---@field recalculate_timings boolean
