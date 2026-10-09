local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)

-- Poplar wood follows the same mcl_trees.register_wood contract as Cherry.
-- Texture files are generated placeholders and can be replaced by a texture pack.
mcl_trees.register_wood("poplar", {
	readable_name = "Poplar",
	sign_color = "#A86F45",
	tree_schems = {
		{file = modpath .. "/schematics/poplar_tree.mts"},
		{file = modpath .. "/schematics/poplar_tree_red.mts"},
		{file = modpath .. "/schematics/poplar_tree_yellow.mts"},
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
		wield_image = "dappled_forest_poplar_sign.png",
		tiles = {"dappled_forest_poplar_sign_uv.png"},
	},
	boat = {
		item = {
			inventory_image = "dappled_forest_poplar_boat.png",
			wield_image = "dappled_forest_poplar_boat.png",
		},
		object = {
			textures = {"dappled_forest_poplar_boat_uv.png", "blank.png"},
		},
	},
	chest_boat = {
		item = {
			inventory_image = "dappled_forest_poplar_chest_boat.png",
			wield_image = "dappled_forest_poplar_chest_boat.png",
		},
		object = {
			textures = {"dappled_forest_poplar_boat_uv.png", "blank.png"},
		},
	},
	trapdoor = {
		tile_front = "dappled_forest_poplar_trapdoor.png",
		tile_side = "dappled_forest_poplar_trapdoor_side.png",
		wield_image = "dappled_forest_poplar_trapdoor.png",
	},
	hanging_sign = {
		inventory_image = "dappled_forest_poplar_hanging_sign.png",
		wield_image = "dappled_forest_poplar_hanging_sign.png",
		tiles = {"dappled_forest_poplar_hanging_sign_uv.png"},
	},
})

-- Dappled Forest seasonal leaf variants. They share the Poplar sapling drop
-- and the normal Mineclonia leaf lifecycle, but use separate node IDs so a
-- schematic can choose red, orange or yellow foliage explicitly.
local function register_poplar_leaf_variant(name, texture)
	local def = mcl_trees.generate_leaves_def("mcl_trees:", "leaves_poplar_" .. name, {
		tiles = {texture},
		description = "Poplar " .. name:gsub("^%l", string.upper) .. " Leaves",
		_doc_items_longdesc = "Colored leaves from a Poplar tree.",
	}, "mcl_trees:sapling_poplar", false, {20, 16, 12, 10})
	core.register_node(":" .. def.leaves_id, def.leaves_def)
	core.register_node(":" .. def.orphan_leaves_id, def.orphan_leaves_def)
end

register_poplar_leaf_variant("red", "dappled_forest_red_poplar_leaves.png")
register_poplar_leaf_variant("yellow", "dappled_forest_yellow_poplar_leaves.png")

dofile(modpath .. "/lg_register.lua")
dofile(modpath .. "/polypore.lua")
dofile(modpath .. "/vegetation.lua")
dofile(modpath .. "/hay_bed.lua")
dofile(modpath .. "/functions.lua")

