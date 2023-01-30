local const = require("constants")

data:extend{{
    type = "string-setting",
    name = const.scan_rate_setting,
    setting_type = "runtime-global",
    default_value = "Slow",
    allowed_values = {"Off", "Slow", "Normal", "Fast", "Insane"},
    order = "a"
}}
