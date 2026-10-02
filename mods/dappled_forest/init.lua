local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)

-- Poplar wood follows the same mcl_trees.register_wood contract as Cherry.
-- Texture files are generated placeholders and can be replaced by a texture pack.
mcl_trees.register_wood("poplar", {
	readable_name = "Poplar",
	sign_color = "#A86F45",
	tree_schems = {
		{file = modpath .. "/schematics/poplar_tree.mts"},
	},
	tree = {
		tiles = {"dappled_forest_poplar_log_top.png", "dappled_forest_poplar_log_top.png", "dappled_forest_poplar_log.png"},
	},
	wood = {tiles = {"dappled_forest_poplar_planks.png"}},
	sapling = {
		tiles = {"dappled_forest_poplar_sapling.png"},
		inventory_image = "dappled_forest_poplar_sapling.png",
		wield_image = "dappled_forest_poplar_sapling.png",
		_after_grow = mcl_trees.sapling_add_bee_nest,
	},
	shelf = {
		tiles = mcl_shelves and mcl_shelves.sliced_shelf_texture("dappled_forest_poplar_shelf.png") or {"dappled_forest_poplar_shelf.png"},
	},
	potted_sapling = {image = "dappled_forest_poplar_sapling.png"},
	leaves = {
		tiles = {"dappled_forest_poplar_leaves.png"},
		paramtype2 = "none",
		palette = "",
	},
	stripped = {
		tiles = {"dappled_forest_poplar_log_top_stripped.png", "dappled_forest_poplar_log_top_stripped.png", "dappled_forest_poplar_log_stripped.png"},
	},
	stripped_bark = {tiles = {"dappled_forest_poplar_log_stripped.png"}},
	fence = {tiles = {"dappled_forest_poplar_planks.png"}},
	fence_gate = {tiles = {"dappled_forest_poplar_planks.png"}},
	door = {
		inventory_image = "poplar_door.png",
		tiles_bottom = {"dappled_forest_poplar_door_bottom.png", "dappled_forest_poplar_door_bottom_side.png"},
		tiles_top = {"dappled_forest_poplar_door_top.png", "dappled_forest_poplar_door_top_side.png"},
	},
	sign = {
		inventory_image = "dappled_forest_poplar_sign.png",
	},
	boat = {
		item = {
			inventory_image = "dappled_forest_poplar_boat.png",
			wield_image = "dappled_forest_poplar_boat.png",
		},
	},
	chest_boat = {
		item = {
			inventory_image = "dappled_forest_poplar_chest_boat.png",
			wield_image = "dappled_forest_poplar_chest_boat.png",
		},
	},
	trapdoor = {
		tile_front = "dappled_forest_poplar_trapdoor.png",
		tile_side = "dappled_forest_poplar_trapdoor_side.png",
		wield_image = "dappled_forest_poplar_trapdoor.png",
	},
	hanging_sign = true,
})

dofile(modpath .. "/lg_register.lua")
dofile(modpath .. "/hay_bed.lua")
