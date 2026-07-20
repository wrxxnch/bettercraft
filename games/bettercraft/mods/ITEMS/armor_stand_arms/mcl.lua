local S = core.get_translator(core.get_current_modname())

local NODE_NAME = "armor_stand_arms:armor_stand"

-- VoxeLibre's shield icon is drawn at a stylized angle rather than as a
-- plain rectangle, which looks skewed when shown flat on the stand's arm.
-- vl_weaponry only exists in VoxeLibre (it adds spears), so it's used here
-- as a reliable marker to tell the two games apart.
local IS_VOXELIBRE = core.get_modpath("vl_weaponry") ~= nil
local SHIELD_DISPLAY_ITEM = "armor_stand_arms:shield_display"

core.register_craftitem(SHIELD_DISPLAY_ITEM, {
	description = S("Shield (display)"),
	inventory_image = "armor_stand_arms_shield.png",
	groups = {not_in_creative_inventory = 1},
})

-- Per-hand display + acceptance config.
--
-- Offsets are in the entity-yaw frame. The mesh importer mirrors X, so a
-- point authored in the .obj at (x, y, z) is placed here at (-x, y, z):
-- negate X only, Z passes through (the stand's visual front is -Z). Keep
-- |offset.x| and |offset.z| below 0.5 so a stray item entity still rounds
-- back onto its own node.
--
--   main = weapon arm = the stand's right hand (tilted forward); accepts
--                       melee weapons only (shields and ranged weapons
--                       excluded).
--   off  = shield arm = the stand's left hand; accepts shields only.
--
-- Ranged/charge weapons (bows, crossbows, spears: group weapon_ranged) are
-- excluded on purpose. They use controls.register_on_hold /
-- register_on_release to track a right-mouse charge-and-release action on
-- the player's currently wielded item; taking the item out of the player's
-- hand mid-click (as putting it in the stand does) desyncs that tracking
-- and can error. Tridents are an exception: they can also be thrown, but a
-- plain node right-click (placing on the stand) doesn't trigger the throw
-- charge, so they are safe. Mineclonia's trident carries no weapon_ranged
-- group anyway; VoxeLibre's does, hence the explicit trident exemption
-- below. Both display with their own item art.
local HANDS = {
	main = {
		list = "hand",
		accept = function(def)
			local g = def and def.groups or {}
			if (g.weapon or 0) == 0 or (g.shield or 0) > 0 then
				return false
			end
			-- ranged weapons are rejected, except tridents
			return (g.weapon_ranged or 0) == 0 or (g.trident or 0) > 0
		end,
		offset = vector.new(-0.3275, 0.5475, -0.39),
		rotation = vector.new(-math.pi / 12, -math.pi / 2, 0),
		scale = 0.27,
	},
	off = {
		list = "offhand",
		accept = function(def)
			local g = def and def.groups or {}
			return (g.shield or 0) > 0
		end,
		-- mirrored to the other arm, a touch forward of it
		offset = vector.new(0.33, 0.4225, -0.255),
		-- a shield's flat image sits 90 deg off a sword's, so this yaw
		-- turns its broad face to the front instead of out to the side
		rotation = vector.new(0, -math.pi, 0),
		scale = 0.34,
	},
}
-- Order in which hand slots are tried when placing an item.
local HAND_ORDER = {"main", "off"}

-- Empty-hand takes are positional: a click whose face position lies more
-- than this far sideways from the stand's center line (in the stand's own
-- frame) targets the hand on that side instead of the armor. The arms
-- start 0.25 out; the held items float around 0.33.
local HAND_TAKE_ZONE = 0.22

-- The VoxeLibre shield display renders visibly smaller than a real
-- (Mineclonia) shield at the same visual_size, so it gets its own size
-- multiplier on top of HANDS.off.scale. Starting guess per user feedback;
-- tune this number like any other value in HANDS.
local VOXELIBRE_SHIELD_SCALE_MULT = 1.5
-- On Mineclonia both held items render 10% smaller (user-tuned; the HANDS
-- scales themselves stay the VoxeLibre-tuned values).
local MINECLONIA_SCALE_MULT = 0.9

local function effective_scale(slot)
	local scale = HANDS[slot].scale
	if IS_VOXELIBRE then
		if slot == "off" then
			scale = scale * VOXELIBRE_SHIELD_SCALE_MULT
		end
	else
		scale = scale * MINECLONIA_SCALE_MULT
	end
	return scale
end

local function stand_yaw(node)
	return core.dir_to_yaw(core.facedir_to_dir(node.param2))
end

local function hand_world_pos(pos, node, hand)
	return vector.add(pos, vector.rotate(hand.offset, vector.new(0, stand_yaw(node), 0)))
end

local function init_inventory(pos)
	local inv = core.get_meta(pos):get_inventory()
	inv:set_size("armor", 5)
	inv:set_size("hand", 1)
	inv:set_size("offhand", 1)
	return inv
end

-- Spawn a stand entity
local function spawn_stand_entity(pos, node)
	local luaentity = core.add_entity(pos, "armor_stand_arms:armor_entity"):get_luaentity()
	if luaentity then
		luaentity:update_rotation(node or core.get_node(pos))
		return luaentity
	end
end

-- Find a stand entity or spawn one
local function get_stand_entity(pos, node)
	for obj in core.objects_inside_radius(pos, 0) do
		local luaentity = obj:get_luaentity()
		if luaentity and luaentity.name == "armor_stand_arms:armor_entity" then
			return luaentity
		end
	end
	return spawn_stand_entity(pos, node)
end

-- Find the wielditem entity for a given slot, if any
local function get_item_entity(pos, slot)
	local node_pos = vector.round(pos)
	for obj in core.objects_inside_radius(pos, 1) do
		local luaentity = obj:get_luaentity()
		if luaentity and luaentity.name == "armor_stand_arms:item_entity"
				and luaentity.slot == slot
				and luaentity.node_pos and vector.equals(luaentity.node_pos, node_pos) then
			return luaentity
		end
	end
end

-- staticdata for an item entity: "<slot> <pos>"
local function item_staticdata(slot, pos)
	return slot .. " " .. core.pos_to_string(vector.round(pos))
end

-- Which item name to actually render for a slot's stack. Normally the
-- stack's own item, but on VoxeLibre the shield slot shows the bundled flat
-- shield icon in place of that game's angled one (see IS_VOXELIBRE above).
local function display_item_name(slot, stack)
	if slot == "off" and IS_VOXELIBRE then
		return SHIELD_DISPLAY_ITEM
	end
	return stack:get_name()
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
			"armor_stand_arms:item_entity", item_staticdata(slot, pos))
		entity = obj and obj:get_luaentity()
		if not entity then
			return
		end
	end
	entity:set_item(display_item_name(slot, stack))
	entity:update_pose(node)
end

-- Sync every slot
local function update_all_displays(pos, node)
	node = node or core.get_node(pos)
	for slot in pairs(HANDS) do
		update_slot_display(pos, node, slot)
	end
end

-- Remove every item entity belonging to this stand
local function remove_item_entities(pos)
	for slot in pairs(HANDS) do
		local entity = get_item_entity(pos, slot)
		if entity then
			entity.object:remove()
		end
	end
end

-- Is there an armor piece in the given "armor" slot? (local so we work on
-- both Mineclonia and VoxeLibre, which lacks mcl_armor.has_piece)
local function stand_has_piece(pos, armor_index)
	return not init_inventory(pos):get_stack("armor", armor_index):is_empty()
end

-- Take an armor piece off the stand and return it. Mirrors what
-- mcl_armor.unequip does in Mineclonia, but VoxeLibre has no such function;
-- both games do have mcl_armor.on_unequip (which also refreshes the visual).
local function stand_unequip(pos, obj, armor_index)
	local inv = init_inventory(pos)
	local stack = inv:get_stack("armor", armor_index)
	if stack and not stack:is_empty() then
		inv:set_stack("armor", armor_index, "")
		mcl_armor.on_unequip(stack, obj)
	end
	return stack
end

-- Drop a stack near the stand (core.add_item works on both games;
-- mcl_util.drop_item_stack is Mineclonia-only)
local function drop_stack(pos, stack)
	if stack and not stack:is_empty() then
		core.add_item(vector.offset(pos, math.random() - 0.5, 0, math.random() - 0.5), stack)
	end
end

-- Drop everything on the ground when the stand got destroyed
local function drop_inventory(pos)
	local inv = core.get_meta(pos):get_inventory()
	for _, listname in pairs({"armor", "hand", "offhand"}) do
		local list = inv:get_list(listname)
		if list then
			for _, stack in pairs(list) do
				drop_stack(pos, stack)
			end
		end
	end
end

core.register_node(NODE_NAME, {
	description = S("Armor Stand with Arms"),
	_tt_help = S("Displays armor, holds a weapon and a shield"),
	_doc_items_longdesc = S("An armor stand with arms is a decorative object which can display different pieces of armor. It can also hold a weapon in one hand and a shield in the other."),
	_doc_items_usagehelp = S("Place an armor item on the armor stand to equip it. Use a weapon on it to put the weapon in its hand, or a shield to put the shield in its other hand; other items are not accepted. To take something back, select your hand and use the place key on the armor stand: point at the weapon or the shield to take it, or at a piece of armor to take that piece."),
	drawtype = "mesh",
	mesh = "armor_stand_arms.obj",
	inventory_image = "armor_stand_arms_item.png",
	wield_image = "armor_stand_arms_item.png",
	tiles = {"default_wood.png", "mcl_stairs_stone_slab_top.png"},
	paramtype = "light",
	paramtype2 = "facedir",
	walkable = false,
	is_ground_content = false,
	stack_max = 16,
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, -7/16, 0.5},
			{-6/16, -0.5, -2/16, 6/16, 22/16, 2/16},
		}
	},
	groups = {handy=1, deco_block=1, dig_by_piston=1, attached_node=1},
	_mcl_hardness = 2,
	sounds = mcl_sounds.node_sound_wood_defaults(),
	on_construct = function(pos)
		init_inventory(pos)
		spawn_stand_entity(pos)
	end,
	on_destruct = function(pos)
		drop_inventory(pos)
		remove_item_entities(pos)
	end,
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local protname = clicker:get_player_name()
		if core.is_protected(pos, protname) then
			core.record_protection_violation(pos, protname)
			return itemstack
		end

		local stand_entity = get_stand_entity(pos, node).object
		local inv = init_inventory(pos)
		-- try to take armor or a held item if pointing at side face.
		-- pointed_thing can be nil here: some weapons (e.g. VoxeLibre's
		-- bow) forward an unrelated click to the pointed node's
		-- on_rightclick without passing it through. Treat that the same
		-- as "not pointing at a specific face" and fall through to the
		-- placing logic below.
		local px, py, pz = pos.x, pos.y, pos.z
		local ax, az
		if pointed_thing then
			ax, az = pointed_thing.above.x, pointed_thing.above.z
		end
		if pointed_thing and clicker:get_wielded_item():get_name() == "" and (px ~= ax or pz ~= az) then
			-- try to determine pointed armor element by preparing
			-- pointed_thing for core.pointed_thing_to_face_pos:
			--
			-- 1. force y to node pos.y (works around unexpected
			--    pointed_thing.above.y values when pointing at the
			--    part of the armor stand extending above the node
			--    position)
			--
			-- 2. move intersection plane closer to the plane where
			--    the armor is visually located to make the computed
			--    position less dependent on distance of player to
			--    armor stand
			local above = vector.new(ax, py, az)
			pointed_thing = { type = "node", under = (pos - above) * 0.75 + pos, above = above}
			local fpos = core.pointed_thing_to_face_pos(clicker, pointed_thing)
			local pointed_fpos = fpos.y - py

			-- Pointing at an arm (sideways of the torso column, in the
			-- stand's own frame) takes that hand's item directly: the
			-- weapon hangs on the negative-x side, the shield on the
			-- positive-x side (matching HAND_OFFSET signs).
			if pointed_fpos > 0 then
				local lx = vector.rotate(vector.subtract(fpos, pos),
					vector.new(0, -stand_yaw(node), 0)).x
				local zone_slot
				if lx < -HAND_TAKE_ZONE then
					zone_slot = "main"
				elseif lx > HAND_TAKE_ZONE then
					zone_slot = "off"
				end
				if zone_slot then
					local held = inv:get_stack(HANDS[zone_slot].list, 1)
					if not held:is_empty() then
						inv:set_stack(HANDS[zone_slot].list, 1, "")
						update_slot_display(pos, node, zone_slot)
						return held
					end
				end
			end

			local pointed_piece_index

			if pointed_fpos > 0.9375 then
				pointed_piece_index = mcl_armor.elements.head.index
			elseif pointed_fpos > 0.25 then
				pointed_piece_index = mcl_armor.elements.torso.index
			elseif pointed_fpos > -0.0625 then
				pointed_piece_index = mcl_armor.elements.legs.index
			else
				pointed_piece_index = mcl_armor.elements.feet.index
			end

			-- If the pointed piece has no armor, try again from the
			-- bottom with more margins to find a piece in a location
			-- that would otherwise be covered.
			if not stand_has_piece(pos, pointed_piece_index) then
				if pointed_fpos > 0.9375 + 1/16 then
					pointed_piece_index = mcl_armor.elements.head.index
				elseif pointed_fpos > 0.3125 + 4/16 then
					pointed_piece_index = mcl_armor.elements.torso.index
				elseif pointed_fpos > -0.0625 + 2/16 then
					pointed_piece_index = mcl_armor.elements.legs.index
				else
					pointed_piece_index = mcl_armor.elements.feet.index
				end
			end

			if pointed_piece_index then
				return stand_unequip(pos, stand_entity, pointed_piece_index)
			end
		end

		-- Armor goes on the body; a weapon or shield goes into the
		-- matching hand; anything else is rejected.
		local wdef = itemstack:get_definition()
		if wdef and wdef._mcl_armor_element then
			return mcl_armor.equip(itemstack, stand_entity, true)
		elseif not itemstack:is_empty() then
			for _, slot in ipairs(HAND_ORDER) do
				if HANDS[slot].accept(wdef) then
					local held = inv:get_stack(HANDS[slot].list, 1)
					inv:set_stack(HANDS[slot].list, 1, itemstack)
					update_slot_display(pos, node, slot)
					return held
				end
			end
		end

		return itemstack
	end,
	on_rotate = function(pos, node, _, mode)
		if mode == screwdriver.ROTATE_FACE then
			node.param2 = (node.param2 + 1) % 4
			core.swap_node(pos, node)
			get_stand_entity(pos, node):update_rotation(node)
			update_all_displays(pos, node)
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
		visual_size = {x=1, y=1},
		collisionbox = {-0.1,-0.4,-0.1, 0.1,1.3,0.1},
		pointable = false,
		textures = {"blank.png"},
		timer = 0,
		static_save = false,
		_mcl_pistons_unmovable = true,
	},
	_mcl_fishing_hookable = true,
	_mcl_fishing_reelable = true,
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
		self.node_pos = vector.round(self.object:get_pos())
		self.inventory = init_inventory(self.node_pos)
		-- Mineclonia-only: renders 3D mob heads worn as armor
		if mcl_armor.head_entity_equip then
			mcl_armor.head_entity_equip(self.object)
		end
		mcl_armor.update(self.object)
	end,
	on_step = function(self)
		if core.get_node(self.node_pos).name ~= NODE_NAME then
			self.object:remove()
		end
	end,
	on_deactivate = function(self, _)
		if mcl_armor.head_entity_unequip then
			mcl_armor.head_entity_unequip(self.object)
		end
	end,
	update_armor = function(self, info)
		self.object:set_properties({textures = {info.texture}})
	end,
	update_rotation = function(self, node)
		self.object:set_yaw(core.dir_to_yaw(core.facedir_to_dir(node.param2)))
	end,
	_head_armor_bone = "",
	_head_armor_position = vector.new(0, 14, 0),
})

core.register_entity("armor_stand_arms:item_entity", {
	initial_properties = {
		physical = false,
		pointable = false,
		visual = "wielditem",
		visual_size = {x=HANDS.main.scale, y=HANDS.main.scale},
		textures = {"air"},
		static_save = false,
		_mcl_pistons_unmovable = true,
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
		local scale = effective_scale(self.slot)
		self.object:set_properties({visual_size = {x = scale, y = scale}})
		self:set_item(display_item_name(self.slot, stack))
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
	action = function(pos, node)
		spawn_stand_entity(pos, node)
		update_all_displays(pos, node)
	end,
})

core.register_craft({
	output = NODE_NAME,
	recipe = {
		{"mcl_core:stick", "mcl_core:stick", "mcl_core:stick"},
		{"mcl_core:stick", "mcl_core:stick", "mcl_core:stick"},
		{"", "mcl_stairs:slab_stone", ""},
	}
})

core.log("action", "[armor_stand_arms] loaded ("
	.. (IS_VOXELIBRE and "VoxeLibre" or "Mineclonia") .. ")")
