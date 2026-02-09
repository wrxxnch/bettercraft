-- Custom Food Mod for Mineclonia
-- Adds Fried Egg and Pumpkin Slices

local modname = minetest.get_current_modname()
local S = minetest.get_translator(modname)

-------------------------------------------------
-- Pumpkin Slice (Raw)
-------------------------------------------------
minetest.register_craftitem(modname .. ":pumpkin_slice", {
	description = "Pedaço de Abóbora",
	inventory_image = "custom_food_pumpkin_slice.png",

	groups = { food = 2 ,smoker_cookable = 1},

	_mcl_food = {
		eat = 2,
		saturation = 0.4,
	},
})

minetest.register_craft({
	type = "cooking",
	output = modname .. ":pumpkin_slice_cooked",
	recipe = modname .. ":pumpkin_slice",
	cooktime = 10,
})


-------------------------------------------------
-- Cooked Pumpkin Slice
-------------------------------------------------
minetest.register_craftitem(modname .. ":pumpkin_slice_cooked", {
	description = "Pedaço de Abóbora Cozida",
	inventory_image = "custom_food_cooked_pumpkin_slice.png",

	on_place = core.item_eat(6),
	on_secondary_use = core.item_eat(6),

	groups = { food = 2, eatable = 6 },
	_mcl_saturation = 0.8,
})

-------------------------------------------------
-- Fried Egg
-------------------------------------------------
minetest.register_craftitem(modname .. ":fried_egg", {
	description = "Ovo Frito",
	inventory_image = "custom_food_fried_egg.png",

	on_place = core.item_eat(6),
	on_secondary_use = core.item_eat(6),

	groups = { food = 2, eatable = 6,smoker_cookable = 1},
	_mcl_saturation = 0.8,
})

-------------------------------------------------
-- Pumpkin Slice -> Pumpkin Seeds
-------------------------------------------------
minetest.register_craft({
	type = "shapeless",
	output = "mcl_farming:pumpkin_seeds",
	recipe = {modname .. ":pumpkin_slice"},
})

-------------------------------------------------
-- Recipes that depend on other mods
-------------------------------------------------
minetest.register_on_mods_loaded(function()
	-- Egg -> Fried Egg
	local egg_item = "mcl_throwing:egg"
	if not minetest.registered_items[egg_item] then
		egg_item = "mcl_mobitems:egg"
	end

	if minetest.registered_items[egg_item] then
		minetest.register_craft({
			type = "cooking",
			output = modname .. ":fried_egg",
			recipe = egg_item,
		})
	end

	-- Pumpkin Block -> 9 Pumpkin Slices
	local pumpkin_block = "mcl_farming:pumpkin"
	if not minetest.registered_nodes[pumpkin_block] then
		pumpkin_block = "mcl_core:pumpkin"
	end

	if minetest.registered_nodes[pumpkin_block] then
		minetest.register_craft({
			output = modname .. ":pumpkin_slice 9",
			recipe = {{pumpkin_block}},
		})
	end
end)
