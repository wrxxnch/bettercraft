-- Hay Bed entity for BetterCraft/Mineclonia.
-- It uses the regular mcl_beds sleep/night-skip flow, but calls the
-- no-respawn variant so entering it never changes the player's spawn point.

local modname = core.get_current_modname()
local hay_def = core.registered_nodes["mcl_farming:hay_block"]
local hay_tiles = hay_def and hay_def.tiles or {"mcl_farming_hay_block.png"}
local hay_texture = hay_tiles[1]
if type(hay_texture) == "table" then
	-- Some Luanti versions normalize tile definitions into tables.
	hay_texture = hay_texture.name or hay_texture[1]
end
-- Prefix the texture with the actual mod name. This avoids texture lookup
-- differences between Luanti/Minetest builds when the item is a craftitem.
local ITEM_TEXTURE = "strawbed.png"
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
	local above_def = above and core.registered_nodes[above.name]
	return node and above_def and above_def.buildable_to
end

local function find_bed(pos)
	for _, object in ipairs(core.get_objects_inside_radius(pos, 0.35)) do
		local entity = object:get_luaentity()
		if entity and entity.name == ENTITY_NAME then return object end
	end
end

local function wake_sleepers_on_bed(pos)
	if not mcl_beds or not mcl_beds.player or not mcl_beds.bed_pos then return end
	for name in pairs(mcl_beds.player) do
		local bed_pos = mcl_beds.bed_pos[name]
		if bed_pos and vector.distance(pos, bed_pos) <= 2 then
			local player = core.get_player_by_name(name)
			if player then mcl_beds.kick_player(player) end
		end
	end
end

local function lie_down(object, player)
	if not player or not player:is_player() then return end
	if not mcl_beds or not mcl_beds.on_rightclick_no_spawn then
		core.chat_send_player(player:get_player_name(), "This BetterCraft version needs the no-respawn bed API.")
		return
	end
	local entity = object:get_luaentity()
	if not entity then return end
	local pos = entity.base_pos or vector.round(object:get_pos())
	mcl_beds.on_rightclick_no_spawn(pos, player, true, entity.param2 or 0, {
		allow_day = true,
		no_night_skip = true,
		silent = true,
		center_override = {x = pos.x, y = pos.y + 0.1, z = pos.z},
	})
end

-- Resting is cancelled by any intentional movement, jump or crouch, just as
-- the previous Hay Bed implementation did. Only silent daytime sleepers are
-- handled here; regular beds keep the normal mcl_beds controls/formspec.
core.register_globalstep(function()
	if not mcl_beds or not mcl_beds.no_night_skip then return end
	local to_wake = {}
	for name in pairs(mcl_beds.no_night_skip) do
		local player = core.get_player_by_name(name)
		if not player then
			to_wake[#to_wake + 1] = name
		else
			local control = player:get_player_control()
			if control.up or control.down or control.left or control.right
				or control.jump or control.sneak or control.aux1 then
				to_wake[#to_wake + 1] = name
			end
		end
	end
	for _, name in ipairs(to_wake) do
		local player = core.get_player_by_name(name)
		if player and mcl_beds.player[name] then
			mcl_beds.kick_player(player)
		end
	end
end)

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
			local pos = self.base_pos or vector.round(self.object:get_pos())
			wake_sleepers_on_bed(pos)
			local leftover = puncher:get_inventory():add_item("main", ItemStack(ITEM_NAME))
			if leftover and not leftover:is_empty() then core.add_item(puncher:get_pos(), leftover) end
			self.object:remove()
		end
	end,
})

core.register_craftitem(ITEM_NAME, {
	description = "Hay Bed",
	_tt_help = "A thin bed that sleeps without setting a spawn point",
	inventory_image = ITEM_TEXTURE,
	wield_image = ITEM_TEXTURE,
	stack_max = 16,
	groups = {handy = 1, deco_block = 1},
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" or not placer then return itemstack end
		local pos = pointed_thing.above
		if not can_place(pos, placer) or find_bed(pos) then return itemstack end
		local entity = core.add_entity(vector.offset(pos, 0, -0.5, 0), ENTITY_NAME)
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
	},
})
