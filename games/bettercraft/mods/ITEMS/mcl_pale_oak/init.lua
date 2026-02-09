local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)

mcl_trees.register_wood("pale_oak",{
	readable_name = "Pale Oak",
	sign_color = "#cfbfc5",
	tree_schems_2x2 = {
		{file = modpath.."/schematics/mcl_pale_oak_1.mts", offset = vector.new(1,0,1)},
		{file = modpath.."/schematics/mcl_pale_oak_2.mts", offset = vector.new(1,0,1)},
		{file = modpath.."/schematics/mcl_pale_oak_3.mts", offset = vector.new(1,0,1)},
		--hearted
		{file = modpath.."/schematics/pale_oak1_hearted.mts", offset = vector.new(1,0,1)},
		{file = modpath.."/schematics/pale_oak2_hearted.mts", offset = vector.new(1,0,1)},
		{file = modpath.."/schematics/pale_oak3_hearted.mts", offset = vector.new(1,0,1)},
	},
	tree = { tiles = {"mcl_pale_oak_log_top.png", "mcl_pale_oak_log_top.png","mcl_pale_oak_log.png" }},
	bark = { tiles = {"mcl_pale_oak_log.png"}},
	leaves = {
		tiles = { "mcl_pale_oak_leaves.png" },
		paramtype2 = "none"
	},
	shelf = {
		tiles = mcl_shelves.sliced_shelf_texture("mcl_pale_shelf.png")
	},
	wood = { tiles = {"mcl_pale_oak_planks.png"}},
	stripped = {
		tiles = {"mcl_stripped_pale_oak_log_top.png", "mcl_stripped_pale_oak_log_top.png","mcl_stripped_pale_oak_log_side.png"}
	},
	stripped_bark = {
		tiles = {"mcl_stripped_pale_oak_log_side.png"}
	},
	fence = {
		tiles = { "mcl_pale_oak_planks.png" },
	},
	fence_gate = {
		tiles = { "mcl_pale_oak_planks.png" },
	},
	door = {
		inventory_image = "mcl_pale_oak_door_item.png",
		tiles_bottom = {"mcl_pale_oak_door_bottom.png", "mcl_pale_oak_door_bottom.png"},
		tiles_top = {"mcl_pale_oak_door_top.png", "mcl_pale_oak_door_top.png"}
	},
	trapdoor = {
		tile_front = "mcl_pale_oak_trapdoor.png",
		tile_side = "mcl_pale_oak_trapdoor_side.png",
		wield_image = "mcl_pale_oak_trapdoor.png",
	},
	hanging_sign = true,

    -- 🔥 AQUI ESTÁ O PONTO CHAVE 🔥
	_after_grow = function(pos, schematic_def, is_2by2)
	local trunk_nodes = {}

	local radius = is_2by2 and 8 or 6
	local minp = vector.subtract(pos, radius)
	local maxp = vector.add(pos, radius)

	for x = minp.x, maxp.x do
	for y = minp.y, maxp.y do
	for z = minp.z, maxp.z do
		local p = {x=x,y=y,z=z}
		local node = minetest.get_node(p)

		if node.name == "mcl_trees:tree_pale_oak" then
			table.insert(trunk_nodes, {pos=p, param2=node.param2})
		end
	end
	end
	end

	-- Coloca apenas UM coração
	if #trunk_nodes > 0 then
		local pick = trunk_nodes[math.random(#trunk_nodes)]
		minetest.set_node(pick.pos, {
			name = "mcl_pale_oak:creaking_heart",
			param2 = pick.param2
		})
	end
end,
})


dofile(modpath .. "/resin_blocks.lua")
dofile(modpath .. "/plants.lua")
dofile(modpath .. "/creaking_heart.lua")
dofile(modpath .. "/creaking.lua")


