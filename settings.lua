require("shared")

data:extend({
  {
    type = "int-setting",
    name = mod_name .. "-module-slots",
    setting_type = "startup",
    default_value = 1,
    minimum_value = 1,
    maximum_value = 16,
    order = "a",
  },
})
