local function ensure_additional_category(recipe_name, category)
  local recipe = data.raw.recipe[recipe_name]
  if not recipe then return end

  recipe.additional_categories = recipe.additional_categories or {}
  for _, existing in pairs(recipe.additional_categories) do
    if existing == category then
      return
    end
  end
  table.insert(recipe.additional_categories, category)
end

local function remove_additional_category(recipe_name, category)
  local recipe = data.raw.recipe[recipe_name]
  if not (recipe and recipe.additional_categories) then return end

  for i = #recipe.additional_categories, 1, -1 do
    if recipe.additional_categories[i] == category then
      table.remove(recipe.additional_categories, i)
    end
  end
end

-- data.lua changes
remove_additional_category("production-science-pack", "advanced-centrifuging")
remove_additional_category("utility-science-pack", "advanced-centrifuging")
remove_additional_category("centrifuge", "advanced-centrifuging")
remove_additional_category("nuclear-reactor", "advanced-centrifuging")
remove_additional_category("uranium-fuel-cell", "advanced-centrifuging")

ensure_additional_category("nuclear-fuel", "advanced-centrifuging")
ensure_additional_category("aop-uranium-233-breeding", "advanced-centrifuging")
ensure_additional_category("kovarex-enrichment-process", "advanced-centrifuging")

-- entities.lua changes
local atomic_enricher_item = data.raw.item["aop-atomic-enricher"]
if atomic_enricher_item then
  atomic_enricher_item.weight = 1000000
end

local atomic_enricher_recipe = data.raw.recipe["aop-atomic-enricher"]
if atomic_enricher_recipe then
  atomic_enricher_recipe.category = "advanced-crafting"
  atomic_enricher_recipe.additional_categories = nil
end

local atomic_enricher_entity = data.raw["assembling-machine"]["aop-atomic-enricher"]
if atomic_enricher_entity then
  if atomic_enricher_entity.minable then
    atomic_enricher_entity.minable.mining_time = 1
  end

  atomic_enricher_entity.crafting_categories = {"advanced-centrifuging"}
  atomic_enricher_entity.crafting_speed = 1
  atomic_enricher_entity.energy_usage = "1.8MW"
  atomic_enricher_entity.module_slots = 3

  if atomic_enricher_entity.energy_source then
    atomic_enricher_entity.energy_source.emissions_per_minute = {pollution = 5}
  end

  local animation_layers = atomic_enricher_entity.graphics_set
    and atomic_enricher_entity.graphics_set.animation
    and atomic_enricher_entity.graphics_set.animation.layers
  if animation_layers and animation_layers[2] then
    animation_layers[2].animation_speed = 0.1
  end
end

-- recipes.lua changes
local uranium_sifting = data.raw.recipe["aop-uranium-sifting"]
if uranium_sifting then
  uranium_sifting.category = "centrifuging"
end

local radiation_cladding = data.raw.recipe["aop-radiation-cladding"]
if radiation_cladding then
  radiation_cladding.category = "advanced-crafting"
end

ensure_additional_category("aop-uranium-233-breeding", "advanced-centrifuging")
ensure_additional_category("aop-fission-science-pack", "advanced-centrifuging")
