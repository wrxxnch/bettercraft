mcl_shelves = {}
mcl_hunger = mcl_hunger or {}

-- cria função dummy caso não exista
function mcl_hunger.prevent_eating(player)
    -- nada a fazer, só evita o erro
end

local player_reach = 8
local item_entity_offsets = {
	vector.new(-0.3, 0, 0.25),
	vector.new(0,    0, 0.25),
	vector.new(0.3,  0, 0.25),
}
local shelf_item_entities = {}

local function escape_texture (text)
	return text:gsub("\\", "\\\\"):gsub("%^", "\\%^"):gsub(":", "\\:")
end

function mcl_shelves.sliced_shelf_texture(texture)
	local function sheet_at(x, y)
		return texture .. "^[sheet:2x4:" .. x .. "," .. y
	end
	local base_tex = texture .. "^[sheet:2x2:1,0"
	return {
		normal =         {base_tex, base_tex, base_tex, base_tex, base_tex, "[combine:16x16:0,0=" .. texture},
		powered =        {base_tex, base_tex, base_tex, base_tex, base_tex, base_tex .. "^[combine:16x16:0,4=" .. escape_texture(sheet_at(1, 3))},
		powered_left =   {base_tex, base_tex, base_tex, base_tex, base_tex, base_tex .. "^[combine:16x16:0,4=" .. escape_texture(sheet_at(0, 2))},
		powered_center = {base_tex, base_tex, base_tex, base_tex, base_tex, base_tex .. "^[combine:16x16:0,4=" .. escape_texture(sheet_at(0, 3))},
		powered_right =  {base_tex, base_tex, base_tex, base_tex, base_tex, base_tex .. "^[combine:16x16:0,4=" .. escape_texture(sheet_at(1, 2))},
	}
end

local function rotate_dir_90_deg_clockwise(dir)
	local rotated_dir = vector.copy(dir)
	rotated_dir.x = -dir.z
	rotated_dir.z = dir.x
	return rotated_dir
end

local function get_shelf_variant(nodename)
	local _, _, variant = string.find(nodename, ".*(_powered.*)")
	return variant
end

local function clear_shelf_entities(pos)
	local hash = core.hash_node_position(pos)
	local objects = shelf_item_entities[hash] or {}
	for _, obj in pairs(objects) do
		if obj:is_valid() then
			local l = obj:get_luaentity()
			if l then l.about_to_be_removed = true end
			obj:remove()
		end
	end
	shelf_item_entities[hash] = nil
end

local function initalize_shelf(pos, inv)
	local node = core.get_node(pos)
	local rotation
	if node.param2 == 0 then rotation = 0
	elseif node.param2 == 1 then rotation = math.pi / 2
	elseif node.param2 == 2 then rotation = math.pi
	else rotation = math.pi * 3/2 end

	local objects = {}
	for i = 1, 3 do
		local obj = core.add_entity(
			pos + vector.rotate_around_axis(item_entity_offsets[i], vector.new(0, -1, 0), rotation),
			"mcl_shelves:item_entity"
		)
		if obj then
			obj:set_yaw(rotation)
			local stack = inv:get_stack("main", i)
			local stack_name = stack:get_name()
			if stack_name == "" then
				obj:set_properties({visual = "sprite", textures = {"blank.png"}})
			else
				obj:set_properties({visual = "wielditem", textures = {stack_name}})
			end
			table.insert(objects, obj)
		end
	end
	shelf_item_entities[core.hash_node_position(pos)] = objects
end

local function set_shelf_entities(pos, inv)
	local hash = core.hash_node_position(pos)
	if not shelf_item_entities[hash] then
		initalize_shelf(pos, inv)
		return
	end
	local objects = shelf_item_entities[hash]
	for i = 1, 3 do
		local obj = objects[i]
		if obj and obj:is_valid() then
			local stack_name = inv:get_stack("main", i):get_name()
			local props = obj:get_properties()
			if props.textures[1] ~= stack_name then
				if stack_name == "" then
					obj:set_properties({visual = "sprite", textures = {"blank.png"}})
				else
					obj:set_properties({visual = "wielditem", textures = {stack_name}})
				end
			end
		end
	end
end

local function normal_on_rightclick(pos, node, player, stack, pointed_thing)
	if not core.is_player(player) then return end
	local dir = pointed_thing.under - pointed_thing.above
	local perpendicular_dir = rotate_dir_90_deg_clockwise(dir)
	local player_pos = vector.offset(player:get_pos(), 0, 1.5, 0)
	local look_dir = player:get_look_dir()
	local ray = core.raycast(player_pos, player_pos + vector.multiply(look_dir, player_reach), false, false)
	local ray_pt = ray:next()
	if not ray_pt or ray_pt.type ~= "node" or not vector.equals(ray_pt.under, pos) then return end
	local pos_diff = vector.multiply(ray_pt.intersection_point - pos, perpendicular_dir)
	local from_left = (pos_diff.x ~= 0 and pos_diff.x) or (pos_diff.y ~= 0 and pos_diff.y) or (pos_diff.z ~= 0 and pos_diff.z)
	local slot = (from_left >= 0.15 and 1) or (from_left <= -0.15 and 3) or 2
	local inv = core.get_meta(pos):get_inventory()
	local shelf_stack = inv:get_stack("main", slot)
	inv:set_stack("main", slot, stack)
	set_shelf_entities(pos, inv)
	mcl_redstone.update_comparators(pos)
	mcl_hunger.prevent_eating(player)
	return shelf_stack
end

local function powered_on_rightclick(pos, node, player, stack, pointed_thing)
	if not core.is_player(player) then return end
	local dir = pointed_thing.under - pointed_thing.above
	local perpendicular_dir = rotate_dir_90_deg_clockwise(dir)
	local left_pos = pos + perpendicular_dir
	local right_pos = pos - perpendicular_dir
	local variant = get_shelf_variant(node.name)
	local shelf_positions
	if variant == "_powered_left" then
		local rv = get_shelf_variant(core.get_node(right_pos).name)
		if rv == "_powered_right" then shelf_positions = {right_pos, pos}
		elseif rv == "_powered_center" then shelf_positions = {right_pos - perpendicular_dir, right_pos, pos}
		else return end
	elseif variant == "_powered_right" then
		local lv = get_shelf_variant(core.get_node(left_pos).name)
		if lv == "_powered_left" then shelf_positions = {pos, left_pos}
		elseif lv == "_powered_center" then shelf_positions = {pos, left_pos, left_pos + perpendicular_dir}
		else return end
	elseif variant == "_powered_center" then shelf_positions = {right_pos, pos, left_pos}
	else shelf_positions = {pos} end

	local player_inv = player:get_inventory()
	local shelf_inv
	local leftover_index = player:get_wield_index()
	local leftover = stack
	for i = 0, #shelf_positions * 3 - 1 do
		if i % 3 == 0 then
			if shelf_inv then
				set_shelf_entities(shelf_positions[(i / 3)], shelf_inv)
				mcl_redstone.update_comparators(shelf_positions[(i / 3)])
			end
			shelf_inv = core.get_inventory({type = "node", pos = shelf_positions[(i / 3) + 1]})
		end
		local slot = 3 - (i % 3)
		local s_stack = shelf_inv:get_stack("main", slot)
		local p_stack = player_inv:get_stack("main", 9 - i)
		if 9 - i == leftover_index then leftover = s_stack
		else player_inv:set_stack("main", 9 - i, s_stack) end
		shelf_inv:set_stack("main", slot, p_stack)
	end
	mcl_redstone.update_comparators(shelf_positions[#shelf_positions])
	mcl_hunger.prevent_eating(player)
	set_shelf_entities(shelf_positions[#shelf_positions], shelf_inv)
	return leftover
end

local function propagate_redstone_update(pos)
	local node = core.get_node(pos)
	local root_name = string.gsub(node.name, "_powered.*", "")
	if core.get_item_group(root_name, "mcl_shelf") <= 0 then return end
	local dir = core.facedir_to_dir(node.param2)
	local p_dir = rotate_dir_90_deg_clockwise(dir)
	local pos_l1 = pos + p_dir
	local node_l1 = core.get_node(pos_l1)
	local var_l1 = get_shelf_variant(node_l1.name)
	local connect_left = (var_l1 == "_powered" or var_l1 == "_powered_left") and node.param2 == node_l1.param2
	if not connect_left and var_l1 == "_powered_right" and node.param2 == node_l1.param2 then
		local node_l2 = core.get_node(pos_l1 + p_dir)
		if get_shelf_variant(node_l2.name) == "_powered_left" and node.param2 == node_l2.param2 then
			core.swap_node(pos_l1 + p_dir, {name = root_name .. "_powered_left", param2 = node.param2})
			core.swap_node(pos_l1, {name = root_name .. "_powered_center", param2 = node.param2})
			core.swap_node(pos, {name = root_name .. "_powered_right", param2 = node.param2})
			return
		end
	end
	local pos_r1 = pos - p_dir
	local node_r1 = core.get_node(pos_r1)
	local var_r1 = get_shelf_variant(node_r1.name)
	local connect_right = (var_r1 == "_powered" or var_r1 == "_powered_right") and node.param2 == node_r1.param2
	if connect_left and connect_right then
		core.swap_node(pos_l1, {name = root_name .. "_powered_left", param2 = node.param2})
		core.swap_node(pos, {name = root_name .. "_powered_center", param2 = node.param2})
		core.swap_node(pos_r1, {name = root_name .. "_powered_right", param2 = node.param2})
		return
	end
	if not connect_right and var_r1 == "_powered_left" and node.param2 == node_r1.param2 then
		local node_r2 = core.get_node(pos_r1 - p_dir)
		if get_shelf_variant(node_r2.name) == "_powered_right" and node.param2 == node_r2.param2 then
			core.swap_node(pos, {name = root_name .. "_powered_left", param2 = node.param2})
			core.swap_node(pos_r1, {name = root_name .. "_powered_center", param2 = node.param2})
			core.swap_node(pos_r2, {name = root_name .. "_powered_right", param2 = node.param2})
			return
		end
	end
	if connect_left then
		core.swap_node(pos, {name = root_name .. "_powered_right", param2 = node.param2})
		core.swap_node(pos_l1, {name = root_name .. "_powered_left", param2 = node.param2})
	elseif connect_right then
		core.swap_node(pos, {name = root_name .. "_powered_left", param2 = node.param2})
		core.swap_node(pos_r1, {name = root_name .. "_powered_right", param2 = node.param2})
	else
		core.swap_node(pos, {name = root_name .. "_powered", param2 = node.param2})
	end
end

local function empty_shelf(pos)
	local inv = core.get_inventory({ type = "node", pos = pos })
	if inv then
		for i = 1, 3 do
			inv:set_stack("main", i, "")
		end
	end
	clear_shelf_entities(pos)
end


local function propagate_redsone_removal(pos)
	local node = core.get_node(pos)
	local root_name = string.gsub(node.name, "_powered.*", "")
	local variant = get_shelf_variant(node.name)
	core.swap_node(pos, {name = root_name, param2 = node.param2})
	local p_dir = rotate_dir_90_deg_clockwise(core.facedir_to_dir(node.param2))
	if variant == "_powered_left" then propagate_redstone_update(pos - p_dir)
	elseif variant == "_powered_right" then propagate_redstone_update(pos + p_dir)
	elseif variant == "_powered_center" then
		propagate_redstone_update(pos + p_dir)
		propagate_redstone_update(pos - p_dir)
	end
end

local function comparator_measure(pos)
	local inv = core.get_inventory({type = "node", pos = pos})
	local power = 0
	for i = 1, 3 do
		if not inv:get_stack("main", i):is_empty() then power = bit.bor(power, bit.lshift(1, i - 1)) end
	end
	return power
end

local function is_shelf_empty(pos)
	local inv = core.get_inventory({type = "node", pos = pos})
	if not inv then return true end
	for i = 1, 3 do
		if not inv:get_stack("main", i):is_empty() then
			return false
		end
	end
	return true
end

if mcl_pistons and mcl_pistons.register_on_move then
	mcl_pistons.register_on_move(function(moved_nodes)
		for _, moved in ipairs(moved_nodes) do
			local name = moved.node.name

			-- qualquer variante da shelf
			if core.get_item_group(name, "mcl_shelf") > 0 then
				-- esvazia ANTES e DEPOIS por segurança
				empty_shelf(moved.old_pos)
				empty_shelf(moved.pos)
			end
		end
	end)
end


local shelf_tpl = {
	drawtype = "nodebox",
	paramtype2 = "4dir",
	paramtype = "light",
	on_neighbor_changed = function(pos)
	for _, dir in ipairs({
		{x=1,y=0,z=0}, {x=-1,y=0,z=0},
		{x=0,y=1,z=0}, {x=0,y=-1,z=0},
		{x=0,y=0,z=1}, {x=0,y=0,z=-1},
	}) do
		local n = core.get_node(pos + dir).name
		if n == "mcl_pistons:piston_pusher"
		or n == "mcl_pistons:piston_pusher_sticky" then
			empty_shelf(pos)
			return
		end
	end
end,

	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, 10/32, 0.5, 0.5,   0.5},
			{-0.5, -0.5, 6/32,  0.5, -8/32, 0.5},
			{-0.5, 8/32, 6/32,  0.5, 0.5,   0.5},
		}
	},
	groups = {mcl_shelf = 1, deco_block = 1, container = 3},

	-- Bloqueia o movimento se houver itens
	_mcl_pistons_move = function(pos, node, dir)
		return is_shelf_empty(pos)
	end,

	

	on_construct = function(pos)
		local inv = core.get_meta(pos):get_inventory()
		inv:set_size("main", 3)
		initalize_shelf(pos, inv)
	end,

	on_destruct = function(pos)
		local inv = core.get_inventory({type = "node", pos = pos})
		if inv then
			for i = 1, 3 do
				local stack = inv:get_stack("main", i)
				if not stack:is_empty() then core.add_item(pos, stack) end
			end
		end
		clear_shelf_entities(pos)
		propagate_redsone_removal(pos)
	end,

	on_rightclick = normal_on_rightclick,
	_mcl_redstone = {
		update = function(pos, node)
			if mcl_redstone.get_power(pos) > 0 then propagate_redstone_update(pos) end
		end
	},
	_after_hopper_out = function(pos) set_shelf_entities(pos, core.get_inventory({type = "node", pos = pos})) end,
	_after_hopper_in = function(pos) set_shelf_entities(pos, core.get_inventory({type = "node", pos = pos})) end,
}

function mcl_shelves.register_shelf(name, def)
	local root_name = "mcl_shelves:" .. name
	local base_def = table.merge(shelf_tpl, {
		tiles = def.tiles.normal,
		inventory_image = def.inventory_image,
		description = def.description,
		groups = table.merge(shelf_tpl.groups, def.groups),
		sounds = def.sounds,
		_mcl_baseitem = root_name,
		drop = root_name,
	}, def.overrides or {})

	local powered_def = table.merge(base_def, {
		on_rightclick = powered_on_rightclick,
		groups = table.merge(base_def.groups, {not_in_creative_inventory = 1}),
		_mcl_redstone = {
			update = function(pos, node)
				if mcl_redstone.get_power(pos) == 0 then propagate_redsone_removal(pos) end
			end
		}
	})

	core.register_node(":" .. root_name, base_def)
	core.register_node(":" .. root_name .. "_powered", table.merge(powered_def, {tiles = def.tiles.powered}))
	core.register_node(":" .. root_name .. "_powered_left", table.merge(powered_def, {tiles = def.tiles.powered_left}))
	core.register_node(":" .. root_name .. "_powered_center", table.merge(powered_def, {tiles = def.tiles.powered_center}))
	core.register_node(":" .. root_name .. "_powered_right", table.merge(powered_def, {tiles = def.tiles.powered_right}))

	local names = {root_name, root_name.."_powered", root_name.."_powered_left", root_name.."_powered_center", root_name.."_powered_right"}
	for _, n in ipairs(names) do mcl_redstone.register_comparator_measure_func(n, comparator_measure) end
end

core.register_entity("mcl_shelves:item_entity", {
	initial_properties = {
		visual = "wielditem",
		visual_size = {x = 0.1, y = 0.1},
		physical = false,
		pointable = false,
		static_save = false,
		textures = {"blank.png"},
	},
	_mcl_pistons_unmovable = true,
	get_staticdata = function(self)
		if not self.about_to_be_removed then
			clear_shelf_entities(vector.round(self.object:get_pos()))
		end
	end,
})

core.register_lbm({
	label = "Spawn shelf entities",
	name = "mcl_shelves:item_entity_spawner",
	nodenames = {"group:mcl_shelf"},
	run_at_every_load = true,
	bulk_action = function(pos_list)
		for _, pos in pairs(pos_list) do
			clear_shelf_entities(pos)
			local inv = core.get_inventory({type = "node", pos = pos})
			if inv then initalize_shelf(pos, inv) end
		end
	end
})
