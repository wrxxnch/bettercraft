-- Hay Bed entity for BetterCraft/Mineclonia.
-- It is intentionally not a node: it is 0.5 node high and uses Get Comfortable
-- (mcl_cozy.lay) to make the player lie down without setting a respawn point.

local modname = core.get_current_modname()
local hay_def = core.registered_nodes["mcl_farming:hay_block"]
local hay_tiles = hay_def and hay_def.tiles or {"mcl_farming_hay_block.png"}
local hay_texture = hay_tiles[1]

-- Entity cube textures need six entries. Reuse the actual hay block definition,
-- not a copied texture, so texture packs can replace it normally.
local cube_textures = {}
for i = 1, 6 do
	cube_textures[i] = hay_tiles[((i - 1) % #hay_tiles) + 1]
end

local ENTITY_NAME = modname .. ":hay_bed_entity"
local ITEM_NAME = modname .. ":hay_bed"

local function direction_param2(player)
	local dir = player and player:get_look_dir() or vector.new(0, 0, 1)
	return core.dir_to_facedir(vector.new(dir.x, 0, dir.z))
end

local function can_place(pos, player)
	if not player then return false end
	local name = player:get_player_name()
	if core.is_protected(pos, name) then
		core.record_protection_violation(pos, name)
		return false
	end
	local node = core.get_node_or_nil(pos)
	local above = core.get_node_or_nil(vector.offset(pos, 0, 1, 0))
	if not node or not above then return false end
	local above_def = core.registered_nodes[above.name]
	return above_def and above_def.buildable_to
end

local function find_bed(pos)
	for _, object in ipairs(core.get_objects_inside_radius(pos, 0.35)) do
		local entity = object:get_luaentity()
		if entity and entity.name == ENTITY_NAME then
			return object
		end
	end
end

local function lie_down(object, player)
	if not player or not player:is_player() then return end
	if not mcl_cozy or not mcl_cozy.lay then
		core.chat_send_player(player:get_player_name(), "Get Comfortable (mcl_cozy) is required to use the Hay Bed.")
		return
	end
	local entity = object:get_luaentity()
	if not entity then return end
	local pos = entity.base_pos or vector.round(object:get_pos())
	local node = {name = "mcl_farming:hay_block", param2 = entity.param2 or 0}
	mcl_cozy.lay(pos, node, player)
end

core.register_entity(ENTITY_NAME, {
	initial_properties = {
		physical = false,
		pointable = true,
		collide_with_objects = false,
		visual = "cube",
		visual_size = {x = 1, y = 0.2, z = 2},
		textures = cube_textures,
		selectionbox = {-0.5, -0.1, -1, 0.5, 0.1, 1},
		collisionbox = {-0.5, -0.1, -1, 0.5, 0.1, 1},
		static_save = true,
	},

	on_activate = function(self, staticdata)
		if staticdata and staticdata ~= "" then
			local data = core.deserialize(staticdata)
			if data then
				self.base_pos = data.base_pos
				self.param2 = data.param2 or 0
			end
		end
		self.object:set_rotation(vector.new(0, -((self.param2 or 0) % 4) * math.pi / 2, 0))
	end,

	get_staticdata = function(self)
		return core.serialize({base_pos = self.base_pos, param2 = self.param2})
	end,

	on_rightclick = function(self, clicker)
		lie_down(self.object, clicker)
	end,

	on_punch = function(self, puncher)
		if puncher and puncher:is_player() then
			local stack = ItemStack(ITEM_NAME)
			local inventory = puncher:get_inventory()
			local leftover = inventory:add_item("main", stack)
			if leftover and not leftover:is_empty() then
				core.add_item(puncher:get_pos(), leftover)
			end
			self.object:remove()
		end
	end,
})

core.register_craftitem(ITEM_NAME, {
	description = "Hay Bed",
	_tt_help = "A half-height bed for sleeping without setting a spawn point",
	inventory_image = hay_texture,
	wield_image = hay_texture,
	stack_max = 1,
	groups = {handy = 1, deco_block = 1},
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" or not placer then return itemstack end
		local pos = pointed_thing.above
		if not can_place(pos, placer) or find_bed(pos) then return itemstack end
		local entity = core.add_entity(vector.offset(pos, 0, 0.1, 0), ENTITY_NAME)
		if not entity then return itemstack end
		local luaentity = entity:get_luaentity()
		luaentity.base_pos = vector.copy(pos)
		luaentity.param2 = direction_param2(placer)
		entity:set_rotation(vector.new(0, -((luaentity.param2 or 0) % 4) * math.pi / 2, 0))
		if not core.is_creative_enabled(placer:get_player_name()) then itemstack:take_item() end
		return itemstack
	end,
})

core.register_craft({
	output = ITEM_NAME,
	recipe = {
		{"mcl_farming:hay_block", "mcl_farming:hay_block", "mcl_farming:hay_block"},
		{"group:wood", "group:wood", "group:wood"},
	},
})
