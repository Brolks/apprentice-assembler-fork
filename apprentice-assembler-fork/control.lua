require("shared")

local Inserters = require("scripts.inserters")

local ZERO_EFFECTS = {
  speed = 0,
  productivity = 0,
  consumption = 0,
  pollution = 0,
  quality = 0,
}

local function safe_set_effects(struct, effects)
  local beacon = struct and struct.beacon_interface
  if not (beacon and beacon.valid and beacon.unit_number) then
    return false
  end

  local ok = pcall(remote.call, "beacon-interface", "set_effects", beacon.unit_number, effects)
  if not ok then
    return false
  end

  return true
end

local function new_struct(table, struct)
  assert(struct.id, serpent.block(struct))
  assert(table[struct.id] == nil)
  table[struct.id] = struct
  return struct
end

local function reset_offering_1(struct)
  struct.inserter_1.held_stack.clear()
  struct.inserter_1_offering = storage.surface.create_entity{
    name = "item-on-ground",
    force = "neutral",
    position = {0.5 + struct.index, -0.5},
    stack = {name = "wood"},
  }
  storage.deathrattles[script.register_on_object_destroyed(struct.inserter_1_offering)] = {"offering_1", struct.id}
end

local function reset_offering_2(struct)
  struct.inserter_2.held_stack.clear()
  struct.inserter_2_offering = storage.surface.create_entity{
    name = "item-on-ground",
    force = "neutral",
    position = {0.5 + struct.index, -3.5},
    stack = {name = "wood"},
  }
  storage.deathrattles[script.register_on_object_destroyed(struct.inserter_2_offering)] = {"offering_2", struct.id}
end

local Handler = {}

script.on_init(function()
  storage.surface = game.planets[mod_name].create_surface()
  storage.surface.generate_with_lab_tiles = true

  storage.surface.create_global_electric_network()
  storage.surface.create_entity{
    name = "electric-energy-interface",
    force = "neutral",
    position = {-1, -1},
  }

  storage.index = 0
  storage.structs = {}
  storage.deathrattles = {}
end)

script.on_configuration_changed(function(data)
  storage.index = storage.index or 0
  storage.structs = storage.structs or {}
  storage.deathrattles = storage.deathrattles or {}

  for _, struct in pairs(storage.structs) do
    struct.products_finished = struct.products_finished or 0
    struct.last_idle_at = struct.last_idle_at or 0
    struct.working = struct.working or false
  end
end)

function Handler.on_created_entity(event)
  local entity = event.entity or event.destination
  if not (entity and entity.valid and entity.unit_number) then return end

  local struct = new_struct(storage.structs, {
    id = entity.unit_number,
    index = storage.index,
    entity = entity,

    products_finished = 0,
    last_idle_at = event.tick,

    inserter_1 = nil, -- F > 0
    inserter_1_offering = nil,
    inserter_2 = nil, -- W = 0
    inserter_2_offering = nil,
    beacon_interface = nil,

    working = false,
  })
  storage.index = storage.index + 1

  storage.deathrattles[script.register_on_object_destroyed(entity)] = {"crafter", struct.id}

  struct.beacon_interface = entity.surface.create_entity{
    name = mod_prefix .. "beacon-interface",
    force = entity.force,
    position = entity.position,
    raise_built = true,
  }
  if struct.beacon_interface and struct.beacon_interface.valid then
    struct.beacon_interface.destructible = false
  end

  Inserters.create_for_struct(struct)
  reset_offering_1(struct)
  reset_offering_2(struct)
end

for _, event in ipairs({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.on_space_platform_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
  defines.events.on_entity_cloned,
}) do
  script.on_event(event, Handler.on_created_entity, {
    {filter = "name", name = mod_name},
  })
end

local function finished_crafting(struct)
  if struct.working == false then
    struct.working = true
    reset_offering_2(struct)
    local idle_for = game.tick - struct.last_idle_at
    struct.products_finished = math.max(0, struct.products_finished - idle_for / 3) -- lose 20% for each second of activity 
  end

  if 500 > struct.products_finished then
    struct.products_finished = struct.products_finished + 1
    safe_set_effects(struct, {
      speed = struct.products_finished,
      productivity = 0,
      consumption = struct.products_finished,
      pollution = 0,
      quality = 0,
    })
    reset_offering_1(struct)
  end
end

local function stopped_working(struct)
  struct.working = false
  struct.last_idle_at = game.tick
  safe_set_effects(struct, ZERO_EFFECTS)
  reset_offering_1(struct)
end

script.on_event(defines.events.on_object_destroyed, function(event)
  local deathrattle = storage.deathrattles[event.registration_number]
  if deathrattle then storage.deathrattles[event.registration_number] = nil

    if deathrattle[1] == "offering_1" then
      local struct = storage.structs[deathrattle[2]]
      if struct then
        -- game.print(string.format("#%d finished crafting @ %d", struct.id, event.tick))
        finished_crafting(struct)
      end
    elseif deathrattle[1] == "offering_2" then
      local struct = storage.structs[deathrattle[2]]
      if struct then
        -- game.print(string.format("#%d stopped working @ %d", struct.id, event.tick))
        stopped_working(struct)
      end
    elseif deathrattle[1] == "crafter" then
      local struct = storage.structs[deathrattle[2]]
      if struct then
        if struct.inserter_1 and struct.inserter_1.valid then struct.inserter_1.destroy() end
        if struct.inserter_1_offering and struct.inserter_1_offering.valid then struct.inserter_1_offering.destroy() end
        if struct.inserter_2 and struct.inserter_2.valid then struct.inserter_2.destroy() end
        if struct.inserter_2_offering and struct.inserter_2_offering.valid then struct.inserter_2_offering.destroy() end
        if struct.beacon_interface and struct.beacon_interface.valid then struct.beacon_interface.destroy() end
        storage.structs[struct.id] = nil
      end
    else
      error(serpent.block(deathrattle))
    end
  end
end)
