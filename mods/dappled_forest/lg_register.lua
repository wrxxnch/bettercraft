-- Level-generation registration for the Dappled Forest.
-- The file is intentionally separate so it can be loaded by Mineclonia's
-- lg_register convention or by init.lua in older MineClone-compatible games.
local modpath = core.get_modpath(core.get_current_modname())

local biome = {
	name = "dappled_forest",
	node_top = "mcl_core:dirt_with_grass",
	node_filler = "mcl_core:dirt",
	depth_top = 1,
	depth_filler = 3,
	y_min = 1,
	y_max = 31000,
	heat_point = 0.45,
	humidity_point = 0.65,
	vertical_blend = 4,
}

if core.register_biome then
	core.register_biome(biome)
end
