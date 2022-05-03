unused_args = false
allow_defined_top = true

globals = {
    "minetest",
    "ranks",
}

read_globals = {
    string = {fields = {"split","trim"}},
    table = {fields = {"copy", "getn"}},

    -- Builtin
    "vector", "ItemStack",
    "dump", "DIR_DELIM", "VoxelArea", "Settings",
    "PcgRandom",

    -- MTG
    "default", "sfinv", "creative",
}

files["init_test.lua"] = {
    globals = {
        "string"
    }
}