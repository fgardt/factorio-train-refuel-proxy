local const = require("constants")

---@return 0|1|60|300|600
local function parse_rate_setting()
    local rate = settings.global[const.scan_rate_setting].value

    if rate == "Off" then
        return 0
    end

    if rate == "Slow" then
        return 600
    end

    if rate == "Normal" then
        return 300
    end

    if rate == "Fast" then
        return 60
    end

    if rate == "Insane" then
        return 1
    end

    return 0
end

local function init_globals()
    ---@type Global
    global = global or {}

    global.rate = global.rate or parse_rate_setting()
    global.locomotives = global.locomotives or {}
    global.count = global.count or 0 ---@type uint
    global.next_check = global.next_check or nil

    global.ticks_per_check = global.ticks_per_check or 1 ---@type uint
    global.entities_per_check = global.entities_per_check or 1 ---@type uint
    global.recalculate_timings = false
end

---@param info LocomotiveInfo
local function check_locomotive(info)
    if not info.entity.valid or not info.burner.valid then
        -- remove locomotive from ring buffer
        global.count = global.count - 1
        --global.recalculate_timings = true

        if global.count == 0 then
            global.next_check = nil
        else
            global.locomotives[info.prev_unit].next_unit = info.next_unit
            global.locomotives[info.next_unit].prev_unit = info.prev_unit
        end

        info = nil ---@type LocomotiveInfo

        return
    end

    -- check if the locomotive is still burning something
    if info.burner.currently_burning then
        info.last_fuel = info.burner.currently_burning
        return
    end

    -- check if the locomotive had any fuel in its lifetime
    if not info.last_fuel then
        return
    end

    -- check if the locomotive still has fuel in its inventory -> just standing still and not burning anything
    if not info.fuel_inv.is_empty() then
        return
    end

    -- locomotive ran out of fuel
    -- check if locomotive is still moving
    if info.entity.speed ~= 0 then
        return
    end

    -- locomotive is stranded
    -- check if there already is a item-request-proxy
    if info.request_proxy and info.request_proxy.valid then
        return
    end

    -- create a new item-request-proxy and request more fuel
    info.request_proxy = info.entity.surface.create_entity({
        name = "item-request-proxy",
        position = info.entity.position,
        force = info.entity.force,
        target = info.entity,
        raise_built = true,
        modules = {
            [info.last_fuel.name] = info.last_fuel.stack_size,
        }
    })
end

---@param _ NthTickEventData
local function run_checks(_)
    for _ = 1, global.entities_per_check do
        if not global.next_check then
            return
        end

        local info = global.locomotives[ global.next_check --[[@as uint]] ]
        global.next_check = info.next_unit

        check_locomotive(info)
    end
end

local function update_timings()
    local count = global.count
    local rate = global.rate

    -- check if we can disable locomotive scanning
    if count == 0 or rate == 0 then
        script.on_nth_tick(global.ticks_per_check, nil)
        return
    end

    local ticks_per_check = math.ceil(rate / count) --[[@as uint]]
    local entities_per_check = math.ceil(count / rate) --[[@as uint]]

    -- check if this clashes with the recalculation interval
    if ticks_per_check == 1800 then
        ticks_per_check = 1799
    end

    script.on_nth_tick(global.ticks_per_check, nil)
    script.on_nth_tick(ticks_per_check, run_checks)

    global.ticks_per_check = ticks_per_check
    global.entities_per_check = entities_per_check
    global.recalculate_timings = false
end

script.on_nth_tick(1800, function(_)
    --if global.recalculate_timings then
    update_timings()
    --end
end)

---@param entity LuaEntity?
local function register_locomotive(entity)
    if not entity or not entity.valid or not entity.type == "locomotive" or not entity.unit_number then
        return
    end

    local burner = entity.burner
    if not burner then
        return
    end

    local fuel_inv = entity.get_fuel_inventory()
    if not fuel_inv then
        return
    end

    ---@type uint, uint
    local next_unit, prev_unit
    if not global.next_check then
        global.next_check = entity.unit_number
        next_unit = entity.unit_number ---@type uint
        prev_unit = entity.unit_number ---@type uint
    else
        prev_unit = global.next_check ---@type uint
        next_unit = global.locomotives[prev_unit].next_unit

        global.locomotives[prev_unit].next_unit = entity.unit_number
        global.locomotives[next_unit].prev_unit = entity.unit_number
    end

    global.count = global.count + 1
    global.locomotives[entity.unit_number] = {
        entity = entity,
        burner = burner,
        last_fuel = burner.currently_burning,
        fuel_inv = fuel_inv,
        next_unit = next_unit,
        prev_unit = prev_unit,
    }

    update_timings()
end

---@param clear boolean?
local function init(clear)
    if clear then
        global = {}
    end

    init_globals()
    global.rate = parse_rate_setting()
    update_timings()

    if clear or global.count == 0 then
        for _, surface in pairs(game.surfaces) do
            for _, entity in pairs(surface.find_entities_filtered({ type = "locomotive" })) do
                register_locomotive(entity)
            end
        end
    end
end

script.on_init(function() init(true) end)
script.on_configuration_changed(function() init(false) end)

script.on_load(function()
    if not global then return end
    if global.count == 0 or global.rate == 0 then return end
    if not global.ticks_per_check then return end

    script.on_nth_tick(global.ticks_per_check, run_checks)
end)

---@param event
---| EventData.on_robot_built_entity
---| EventData.script_raised_revive
---| EventData.script_raised_built
---| EventData.on_built_entity
local function placed_locomotive(event)
    local entity = event.created_entity or event.entity

    register_locomotive(entity)
end

local ev = defines.events
script.on_event(ev.on_runtime_mod_setting_changed, init)

script.on_event(ev.on_robot_built_entity, placed_locomotive, { { filter = "type", type = "locomotive" } })
script.on_event(ev.script_raised_revive, placed_locomotive, { { filter = "type", type = "locomotive" } })
script.on_event(ev.script_raised_built, placed_locomotive, { { filter = "type", type = "locomotive" } })
script.on_event(ev.on_built_entity, placed_locomotive, { { filter = "type", type = "locomotive" } })
