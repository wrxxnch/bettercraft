-- Armor Stand with Arms — Minetest Game / 3d_armor code path (see init.lua
-- for how the game is picked; mcl.lua is the Mineclonia/VoxeLibre path).
--
-- Forks 3d_armor_stand's chest-style stand (formspec inventory, group
-- armor_<element> slots, composited entity texture) and adds two arms with
-- hand slots: a weapon (group sword/axe/weapon) and a shield (group
-- armor_shield, from 3d_armor's shields mod).

local S = core.get_translator(core.get_current_modname())

local NODE_NAME = "armor_stand_arms:armor_stand"

-- Per-hand display + acceptance config. Offsets are in the entity-yaw
-- frame; the OBJ importer mirrors X, so a point authored in the .obj at
-- (x, y, z) is placed here at (-x, y, z). Keep |x|,|z| < 0.5 so a stray
-- item entity still rounds back onto its own node.
-- Ranged/charge weapons (group weapon_ranged, e.g. bows/crossbows/spears in
-- mods that add them) are excluded on purpose: such weapons typically track
-- a right-mouse charge-and-release action on the player's wielded item, and
-- taking the item out of the player's hand mid-action (as putting it in the
-- stand does) desyncs that tracking and can error.
local HANDS = {
	main = {
		list = "hand",
		accept = function(def)
			local g = def and def.groups or {}
			return ((g.sword or 0) > 0 or (g.axe or 0) > 0 or (g.weapon or 0) > 0)
				and (g.armor_shield or 0) == 0 and (g.weapon_ranged or 0) == 0
		end,
		offset = vector.new(-0.3275, 0.5475, -0.39),
		rotation = vector.new(-math.pi / 12, -math.pi / 2, 0),
		scale = 0.324,
	},
	off = {
		list = "offhand",
		accept = function(def)
			local g = def and def.groups or {}
			return (g.armor_shield or 0) > 0
		end,
		offset = vector.new(0.33, 0.4225, -0.255),
		rotation = vector.new(0, -math.pi, 0),
		scale = 0.34,
	},
}

local elements = {"head", "torso", "legs", "feet"}

local formspec = "size[8,7]" ..
	armor.add_formspec_list("current_name", "main", 3, 0.5, 2, 1) ..
	armor.add_formspec_list("current_name", "main", 3, 1.5, 2, 1, 2) ..
	"image[3,0.5;1,1;3d_armor_stand_head.png]" ..
	"image[4,0.5;1,1;3d_armor_stand_torso.png]" ..
	"image[3,1.5;1,1;3d_armor_stand_legs.png]" ..
	"image[4,1.5;1,1;3d_armor_stand_feet.png]" ..
	"list[current_name;hand;1.5,1;1,1;]" ..
	"list[current_name;offhand;5.5,1;1,1;]" ..
	"image[5.5,1;1,1;3d_armor_stand_shield.png]" ..
	"list[current_player;main;0,3;8,1;]" ..
	"list[current_player;main;0,4.25;8,3;8]" ..
	"listring[current_name;main]" ..
	"listring[current_player;main]"

local function stand_yaw(node)
	return core.dir_to_yaw(core.facedir_to_dir(node.param2 % 4))
end

local function hand_world_pos(pos, node, hand)
	return vector.add(pos, vector.rotate(hand.offset, vector.new(0, stand_yaw(node), 0)))
end

local function init_inventory(pos)
	local inv = core.get_meta(pos):get_inventory()
	inv:set_size("main", 4)
	inv:set_size("hand", 1)
	inv:set_size("offhand", 1)
	return inv
end

-- Find the wielditem entity for a given slot, if any
local function get_item_entity(pos, slot)
	local node_pos = vector.round(pos)
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 1)) do
		local luaentity = obj:get_luaentity()
		if luaentity and luaentity.name == "armor_stand_arms:item_entity"
				and luaentity.slot == slot
				and luaentity.node_pos and vector.equals(luaentity.node_pos, node_pos) then
			return luaentity
		end
	end
end

-- Sync one slot's wielditem entity with its inventory list
local function update_slot_display(pos, node, slot)
	node = node or core.get_node(pos)
	local hand = HANDS[slot]
	local stack = init_inventory(pos):get_stack(hand.list, 1)
	local entity = get_item_entity(pos, slot)
	if stack:is_empty() then
		if entity then
			entity.object:remove()
		end
		return
	end
	if not entity then
		local obj = core.add_entity(hand_world_pos(pos, node, hand),
			"armor_stand_arms:item_entity",
			slot .. " " .. core.pos_to_string(vector.round(pos)))
		entity = obj and obj:get_luaentity()
		if not entity then
			return
		end
	end
	entity:set_item(stack:get_name())
	entity:update_pose(node)
end

local function update_hand_displays(pos, node)
	node = node or core.get_node(pos)
	for slot in pairs(HANDS) do
		update_slot_display(pos, node, slot)
	end
end

-- Find the armor display entity, spawning one if needed, and rebuild its
-- composited texture from the armor slots (3d_armor_stand's approach: each
-- piece contributes def.texture or "<mod>_<item>.png", overlaid with ^)
local function update_entity(pos)
	local node = core.get_node(pos)
	local object
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 0.5)) do
		local ent = obj:get_luaentity()
		if ent and ent.name == "armor_stand_arms:armor_entity" then
			if object then
				obj:remove() -- remove duplicates
			else
				object = obj
			end
		end
	end
	if node.name ~= NODE_NAME then
		if object then
			object:remove()
		end
		return
	end
	object = object or core.add_entity(pos, "armor_stand_arms:armor_entity")
	if not object then
		return
	end
	local textures = {}
	local inv = init_inventory(pos)
	for i, element in ipairs(elements) do
		local stack = inv:get_stack("main", i)
		if stack:get_count() == 1 then
			local def = stack:get_definition() or {}
			if (def.groups or {})["armor_" .. element] then
				table.insert(textures,
					def.texture or stack:get_name():gsub("%:", "_") .. ".png")
			end
		end
	end
	object:set_yaw(stand_yaw(node))
	object:set_properties({textures = {#textures > 0 and table.concat(textures, "^") or "blank.png"}})
	update_hand_displays(pos, node)
end

-- Which list does this stack belong in? Returns listname, slot index
local function target_list(stack)
	local def = stack:get_definition() or {}
	local groups = def.groups or {}
	for i, element in ipairs(elements) do
		if groups["armor_" .. element] then
			return "main", i
		end
	end
	for slot, hand in pairs(HANDS) do
		if hand.accept(def) then
			return hand.list, 1
		end
	end
end

local function drop_everything(pos)
	local inv = core.get_meta(pos):get_inventory()
	for _, listname in ipairs({"main", "hand", "offhand"}) do
		for i = 1, inv:get_size(listname) do
			local stack = inv:get_stack(listname, i)
			if not stack:is_empty() then
				core.add_item(vector.offset(pos,
					math.random() - 0.5, 0, math.random() - 0.5), stack)
				inv:set_stack(listname, i, nil)
			end
		end
	end
end

-- The stand is two nodes tall; 3d_armor_stand's hidden top node provides
-- the upper collision/selection box
local function add_hidden_node(pos, player)
	local p = vector.offset(pos, 0, 1, 0)
	if core.get_node(p).name == "air"
			and not core.is_protected(pos, player:get_player_name()) then
		core.set_node(p, {name = "3d_armor_stand:top"})
	end
end

local function remove_hidden_node(pos)
	local p = vector.offset(pos, 0, 1, 0)
	if core.get_node(p).name == "3d_armor_stand:top" then
		core.remove_node(p)
	end
end

core.register_node(NODE_NAME, {
	description = S("Armor Stand with Arms"),
	drawtype = "mesh",
	mesh = "armor_stand_arms_minetest.obj",
	tiles = {"3d_armor_stand.png"},
	use_texture_alpha = "clip",
	paramtype = "light",
	paramtype2 = "facedir",
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.25, -0.4375, -0.25, 0.25, 1.4, 0.25},
			{-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5},
		},
	},
	groups = {choppy = 2, oddly_breakable_by_hand = 2},
	is_ground_content = false,
	sounds = armor.sounds.wood,
	on_construct = function(pos)
		local meta = core.get_meta(pos)
		meta:set_string("formspec", formspec)
		meta:set_string("infotext", S("Armor Stand with Arms"))
		init_inventory(pos)
	end,
	can_dig = function(pos)
		local inv = core.get_meta(pos):get_inventory()
		return inv:is_empty("main") and inv:is_empty("hand") and inv:is_empty("offhand")
	end,
	after_place_node = function(pos, placer)
		update_entity(pos)
		add_hidden_node(pos, placer)
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if core.is_protected(pos, player:get_player_name()) then
			return 0
		end
		local list = target_list(stack)
		if list ~= listname then
			return 0
		end
		if listname == "main" then
			-- only if the element's dedicated slot is free
			local _, slot = target_list(stack)
			if not core.get_meta(pos):get_inventory():get_stack("main", slot):is_empty() then
				return 0
			end
		end
		return 1
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		if core.is_protected(pos, player:get_player_name()) then
			return 0
		end
		return stack:get_count()
	end,
	allow_metadata_inventory_move = function()
		return 0
	end,
	on_metadata_inventory_put = function(pos, listname, index, stack)
		if listname == "main" then
			-- relocate the piece to its element's dedicated slot
			local _, slot = target_list(stack)
			if slot and slot ~= index then
				local inv = core.get_meta(pos):get_inventory()
				inv:set_stack(listname, slot, stack)
				inv:set_stack(listname, index, nil)
			end
		end
		update_entity(pos)
	end,
	on_metadata_inventory_take = function(pos)
		update_entity(pos)
	end,
	after_destruct = function(pos)
		update_entity(pos)
		remove_hidden_node(pos)
	end,
	on_blast = function(pos)
		drop_everything(pos)
		core.remove_node(pos)
	end,
	on_rotate = function(pos, node, _, mode)
		if screwdriver and mode == screwdriver.ROTATE_FACE then
			node.param2 = (node.param2 + 1) % 4
			core.swap_node(pos, node)
			update_entity(pos)
			return true
		end
		return false
	end,
})

core.register_entity("armor_stand_arms:armor_entity", {
	initial_properties = {
		physical = true,
		visual = "mesh",
		mesh = "3d_armor_entity.obj",
		visual_size = {x = 1, y = 1},
		collisionbox = {0, 0, 0, 0, 0, 0},
		pointable = false,
		textures = {"blank.png"},
		static_save = false,
	},
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
		self.node_pos = vector.round(self.object:get_pos())
	end,
	on_step = function(self)
		if core.get_node(self.node_pos).name ~= NODE_NAME then
			self.object:remove()
		end
	end,
})

core.register_entity("armor_stand_arms:item_entity", {
	initial_properties = {
		physical = false,
		pointable = false,
		visual = "wielditem",
		visual_size = {x = HANDS.main.scale, y = HANDS.main.scale},
		textures = {"air"},
		static_save = false,
	},
	on_activate = function(self, staticdata)
		self.object:set_armor_groups({immortal = 1})
		if staticdata and staticdata ~= "" then
			self.slot = staticdata:match("^(%S+)")
			self.node_pos = core.string_to_pos(staticdata:match("%s(.+)$") or "")
		end
		self.slot = HANDS[self.slot] and self.slot or "main"
		local hand = HANDS[self.slot]
		-- fallback if spawned without staticdata: undo the vertical part
		-- of the hand offset (|x|,|z| stay < 0.5, y may not) and round
		self.node_pos = self.node_pos
			or vector.round(vector.offset(self.object:get_pos(), 0, -hand.offset.y, 0))
		local node = core.get_node(self.node_pos)
		if node.name ~= NODE_NAME then
			self.object:remove()
			return
		end
		local stack = init_inventory(self.node_pos):get_stack(hand.list, 1)
		if stack:is_empty() then
			self.object:remove()
			return
		end
		self.object:set_properties({visual_size = {x = hand.scale, y = hand.scale}})
		self:set_item(stack:get_name())
		self:update_pose(node)
	end,
	on_step = function(self)
		if core.get_node(self.node_pos).name ~= NODE_NAME then
			self.object:remove()
		end
	end,
	set_item = function(self, itemname)
		self.object:set_properties({textures = {itemname}})
	end,
	update_pose = function(self, node)
		local hand = HANDS[self.slot]
		self.object:set_pos(hand_world_pos(self.node_pos, node, hand))
		self.object:set_rotation(vector.new(
			hand.rotation.x,
			stand_yaw(node) + hand.rotation.y,
			hand.rotation.z
		))
	end,
})

core.register_lbm({
	label = "Respawn armor stand with arms entities",
	name = "armor_stand_arms:respawn_entities",
	nodenames = {NODE_NAME},
	run_at_every_load = true,
	action = function(pos)
		update_entity(pos)
	end,
})

core.register_craft({
	output = NODE_NAME,
	recipe = {
		{"default:stick", "default:stick", "default:stick"},
		{"default:stick", "default:stick", "default:stick"},
		{"default:stick", "stairs:slab_stone", "default:stick"},
	}
})

-- Early on, this stand existed as a separate mod named
-- armor_stand_arms_minetest (never released on ContentDB, but available on
-- GitHub). Migrate any nodes placed under that name (skipped if the old mod
-- is still installed, so the two never fight over the name).
if not core.get_modpath("armor_stand_arms_minetest") then
	core.register_alias("armor_stand_arms_minetest:armor_stand", NODE_NAME)
end

core.log("action", "[armor_stand_arms] loaded (Minetest Game / 3d_armor)")
