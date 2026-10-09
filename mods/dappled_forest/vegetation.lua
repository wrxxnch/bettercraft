local modname = core.get_current_modname()

core.register_node(modname .. ":red_shrub", {
	description = "Red Shrub",
	_doc_items_longdesc = "A red shrub found in the Dappled Forest.",
	drawtype = "plantlike",
	tiles = {"dappled_forest_red_shrub.png"},
	inventory_image = "dappled_forest_red_shrub.png",
	wield_image = "dappled_forest_red_shrub.png",
	use_texture_alpha = "clip",
	sunlight_propagates = true,
	paramtype = "light",
	walkable = false,
	buildable_to = true,
	groups = {
		attached_node = 1,
		deco_block = 1,
		destroy_by_lava_flow = 1,
		dig_immediate = 3,
		dig_by_water = 1,
		dig_by_piston = 1,
		compostability = 65,
	},
	drop = modname .. ":red_shrub",
	sounds = mcl_sounds.node_sound_leaves_defaults(),
	_mcl_hardness = 0,
})
