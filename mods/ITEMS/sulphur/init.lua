-- SPDX-License-Identifier: MIT
local core = minetest
local S = core.get_translator("sulphur_update")

local modname = "sulphur_update"

-- Escalas visuais configuráveis.
local SLIME_VISUAL_SIZE = { x = 9, y = 9 }
local SULFUR_BLOCK_VISUAL_SIZE = { x = 0.08, y = 0.08 }

local function tex(name)
	return name .. ".png"
end

local function register_full_block(name, description, texture, groups, sounds)
	core.register_node(modname .. ":" .. name, {
		description = S(description),
		tiles = { tex(texture) },
		is_ground_content = false,
		stack_max = 64,
		groups = groups or { pickaxey = 1, building_block = 1 },
		sounds = sounds or
			(mcl_sounds and mcl_sounds.node_sound_stone_defaults and mcl_sounds.node_sound_stone_defaults() or {}),
	})
end

local stone_groups = { pickaxey = 1, building_block = 1 }

-- Registro de blocos
register_full_block("cinnabar", "Cinnabar", "cinnabar", { pickaxey = 1, building_block = 1, material_rock = 1 })
register_full_block("chiseled_cinnabar", "Chiseled Cinnabar", "chiseled_cinnabar", stone_groups)
register_full_block("polished_cinnabar", "Polished Cinnabar", "polished_cinnabar", stone_groups)
register_full_block("cinnabar_bricks", "Cinnabar Bricks", "cinnabar_bricks", stone_groups)
register_full_block("potent_sulfur", "Potent Sulfur", "potent_sulfur",
	{ pickaxey = 1, building_block = 1, material_sulphur = 1 })
register_full_block("sulfur", "Sulfur", "sulfur", { pickaxey = 1, building_block = 1, material_sulphur = 1 })
register_full_block("chiseled_sulfur", "Chiseled Sulfur", "chiseled_sulfur",
	{ pickaxey = 1, building_block = 1, material_sulphur = 1 })
register_full_block("polished_sulfur", "Polished Sulfur", "polished_sulfur",
	{ pickaxey = 1, building_block = 1, material_sulphur = 1 })
register_full_block("sulfur_bricks", "Sulfur Bricks", "sulfur_bricks",
	{ pickaxey = 1, building_block = 1, material_sulphur = 1 })

-- Sistema de Espeleotemas (Estalactites/Estalagmites)
local spike_groups = { pickaxey = 1, attached_node = 1, material_sulphur = 1 }
local spike_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 } }

local sulfur_spike_directions = { [-1] = "down", [1] = "up" }
local sulfur_spike_stages = { "tip_merge", "tip", "frustum", "middle", "base" }

local function sulfur_spike_node(stage, direction)
	return modname .. ":sulfur_spike_" .. sulfur_spike_directions[direction] .. "_" .. sulfur_spike_stages[stage]
end

local function sulfur_spike_direction(name)
	return string.find(name, ":sulfur_spike_down_", 1, true) and -1 or 1
end

local function sulfur_spike_length(pos, direction)
	local offset_pos = vector.copy(pos)
	local length = 0
	repeat
		length = length + 1
		offset_pos = vector.offset(offset_pos, 0, direction, 0)
	until core.get_item_group(core.get_node(offset_pos).name, "sulfur_spike_stage") == 0
	return length
end

local function sulfur_spike_break_column(pos, direction)
	local offset_pos = vector.copy(pos)
	while true do
		offset_pos = vector.offset(offset_pos, 0, -direction, 0)
		local node = core.get_node(offset_pos)
		local stage = core.get_item_group(node.name, "sulfur_spike_stage")
		if stage == 1 and sulfur_spike_direction(node.name) == -direction then
			core.swap_node(offset_pos, { name = sulfur_spike_node(2, -direction) })
			break
		elseif stage == 0 then
			break
		else
			core.add_item(offset_pos, ItemStack(modname .. ":sulphur_stalactite"))
			core.swap_node(offset_pos, { name = "air" })
		end
	end
end

local function sulfur_spike_update(pos, direction)
	local other_pos = vector.offset(pos, 0, -direction, 0)
	local other_name = core.get_node(other_pos).name
	if core.get_item_group(other_name, "sulfur_spike_stage") ~= 0 then
		core.swap_node(pos, { name = sulfur_spike_node(1, direction) })
		core.swap_node(other_pos, { name = sulfur_spike_node(1, -direction) })
	end

	local stage
	local previous_stage
	while true do
		pos = vector.offset(pos, 0, direction, 0)
		previous_stage = stage
		stage = core.get_item_group(core.get_node(pos).name, "sulfur_spike_stage")
		if stage == 4 or stage == 5 then
			break
		elseif stage == 0 then
			if previous_stage == 3 then
				core.swap_node(vector.offset(pos, 0, -direction, 0), { name = sulfur_spike_node(5, direction) })
			end
			break
		end
		core.swap_node(pos, { name = sulfur_spike_node(stage + 1, direction) })
	end
end

local function place_sulfur_spike(itemstack, player, pointed_thing)
	if not pointed_thing or pointed_thing.type ~= "node" then return itemstack end
	local under_node = core.get_node(pointed_thing.under)
	if core.get_item_group(under_node.name, "solid") == 0
		and core.get_item_group(under_node.name, "sulfur_spike_stage") == 0 then
		return itemstack
	end
	if pointed_thing.above.x ~= pointed_thing.under.x or pointed_thing.above.z ~= pointed_thing.under.z then
		return itemstack
	end
	local direction = pointed_thing.above.y - pointed_thing.under.y
	if direction == 0 then return itemstack end
	if not core.is_creative_enabled(player:get_player_name()) then itemstack:take_item() end
	core.set_node(pointed_thing.above, { name = sulfur_spike_node(2, direction) })
	sulfur_spike_update(pointed_thing.above, direction)
	return itemstack
end

local function sulfur_spike_destruct(pos)
	local direction = sulfur_spike_direction(core.get_node(pos).name)
	sulfur_spike_break_column(pos, direction)

	local offset_pos = vector.offset(pos, 0, direction, 0)
	if core.get_item_group(core.get_node(offset_pos).name, "sulfur_spike_stage") ~= 0 then
		core.swap_node(offset_pos, { name = sulfur_spike_node(2, direction) })
		while true do
			offset_pos = vector.offset(offset_pos, 0, direction, 0)
			local stage = core.get_item_group(core.get_node(offset_pos).name, "sulfur_spike_stage")
			if stage == 3 then
				core.swap_node(offset_pos, { name = sulfur_spike_node(2, direction) })
			elseif stage == 4 or stage == 5 then
				core.swap_node(offset_pos, { name = sulfur_spike_node(3, direction) })
				break
			else
				break
			end
		end
	end
end

for i, stage in ipairs(sulfur_spike_stages) do
	local add = (i - 1) / 16
	local box = { type = "fixed", fixed = {
		math.max(-0.5, -3 / 16 - add), -0.5,
		math.max(-0.5, -3 / 16 - add),
		math.min(0.5, 3 / 16 + add), 0.5,
		math.min(0.5, 3 / 16 + add)
	} }
	for direction, label in pairs(sulfur_spike_directions) do
		core.register_node(sulfur_spike_node(i, direction), {
			description = S("Sulfur speleothem (@1/@2)", i, #sulfur_spike_stages),
			_doc_items_hidden = true,
			drawtype = "plantlike",
			tiles = { "sulfur_spike_" .. label .. "_" .. stage .. ".png" },
			paramtype = "light",
			use_texture_alpha = true,
			sunlight_propagates = true,
			is_ground_content = false,
			walkable = true,
			climbable = false,
			selection_box = box,
			collision_box = box,
			groups = {
				pickaxey = 1, attached_node = 1, material_sulphur = 1,
				not_in_creative_inventory = 1, sulfur_spike_stage = i, pathfinder_partial = 2,
			},
			drop = modname .. ":sulphur_stalactite",
			on_destruct = sulfur_spike_destruct,
			sounds = mcl_sounds and mcl_sounds.node_sound_stone_defaults and mcl_sounds.node_sound_stone_defaults() or {},
		})
	end
end

core.register_craftitem(modname .. ":sulphur_stalactite", {
	description = S("Sulfur speleothem"),
	inventory_image = tex("sulfur_spike_up_tip"),
	on_place = place_sulfur_spike,
	on_secondary_use = place_sulfur_spike,
})

-- ABM de Crescimento natural de espigões
core.register_abm({
	label = "Sulfur speleothem growth",
	nodenames = { modname .. ":sulfur_spike_up_tip" },
	interval = 69,
	chance = 88,
	action = function(pos)
		local stalactite_length = sulfur_spike_length(pos, 1)
		local water_pos = vector.offset(pos, 0, stalactite_length + 1, 0)
		if core.get_item_group(core.get_node(water_pos).name, "water") == 0 then return end
		if core.get_node(vector.offset(pos, 0, stalactite_length, 0)).name ~= modname .. ":sulfur" then return end

		if math.random(2) == 1 then
			for i = 1, 10 do
				local candidate = vector.offset(pos, 0, -i, 0)
				local node = core.get_node(candidate)
				local groups = core.registered_nodes[node.name] and core.registered_nodes[node.name].groups or {}
				if (groups.solid or 0) > 0 or (groups.sulfur_spike_stage or 0) > 0 then
					if i <= 7 then
						core.set_node(vector.offset(pos, 0, -i + 1, 0), { name = sulfur_spike_node(2, -1) })
						sulfur_spike_update(vector.offset(pos, 0, -i + 1, 0), -1)
					end
					return
				elseif node.name ~= "air" then
					return
				end
			end
		else
			if stalactite_length > 7 then return end
			local target = vector.offset(pos, 0, -1, 0)
			if core.get_node(target).name == "air" then
				core.set_node(target, { name = sulfur_spike_node(2, 1) })
				sulfur_spike_update(target, 1)
			end
		end
	end,
})

-- Musicas e itens diversos
if mcl_jukebox and mcl_jukebox.register_record then
	mcl_jukebox.register_record({
		title = "Bounce",
		author = "fingerspit",
		id = "bounce",
		texture = tex("music_disc_bounce"),
		sound = "mcl_jukebox_track_7",
		exclude_from_creeperdrop = true,
		comparator_signal = 8
	})
else
	core.register_craftitem(modname .. ":music_disc_bounce",
		{ description = S("Music Disc — Bounce"), inventory_image = tex("music_disc_bounce"), stack_max = 1, groups = { music_record = 1 } })
end

core.register_node(modname .. ":sulphur_smoke", {
	description = S("Sulfur smoke in water"),
	drawtype = "plantlike",
	tiles = { tex("sulphur_smoke") },
	paramtype = "light",
	walkable = false,
	pointable = true,
	use_texture_alpha = true,
	sunlight_propagates = true,
	groups = { not_in_creative_inventory = 1, attached_node = 1 },
	drop = "",
})

-- Receitas de Crafting
local function craft(output, recipe)
	core.register_craft({ output = modname .. ":" .. output, recipe = recipe })
end
craft("sulphur", { { modname .. ":sulphur_stalactite", modname .. ":sulphur_stalactite" }, { modname .. ":sulphur_stalactite", modname .. ":sulphur_stalactite" } })
craft("cinnabar", { { modname .. ":cinnabar", modname .. ":cinnabar", modname .. ":cinnabar" }, { modname .. ":cinnabar", modname .. ":cinnabar", modname .. ":cinnabar" }, { modname .. ":cinnabar", modname .. ":cinnabar", modname .. ":cinnabar" } })
core.register_craft({ output = modname .. ":potent_sulfur", recipe = { { modname .. ":sulfur", modname .. ":sulfur" }, { modname .. ":sulfur", modname .. ":sulfur" } } })

-- Funções de Efeito
local function give_nausea(obj, duration)
	if mcl_potions and mcl_potions.give_effect then
		mcl_potions.give_effect("nausea", obj, 1, duration, false)
	end
end

-------------------------------------------------------
-- NOVO SISTEMA: GEYSER DE ENXOFRE (Potent Sulfur + Magma + Água)
-------------------------------------------------------

local function get_water_column_height(pos)
	local height = 0
	local check_pos = {x = pos.x, y = pos.y + 1, z = pos.z}
	while height < 15 do
		local node = core.get_node(check_pos).name
		if core.get_item_group(node, "water") ~= 0 then
			height = height + 1
			check_pos.y = check_pos.y + 1
		else
			break
		end
	end
	return height
end

core.register_abm({
	label = "Sulphur Geyser Pulse",
	nodenames = { modname .. ":potent_sulfur" },
	interval = 12, -- Entre 10 a 15 segundos aproximadamente
	chance = 1,
	action = function(pos)
		-- Requisito 1: Magma embaixo
		local node_below = core.get_node({x = pos.x, y = pos.y - 1, z = pos.z}).name
		if node_below ~= "mcl_nether:magma" then return end

		-- Requisito 2: Água em cima
		local water_h = get_water_column_height(pos)
		if water_h == 0 then return end

		-- Efeito Visual: Fumaça que sobe rápido
		core.add_particlespawner({
			amount = 50 + (water_h * 4),
			time = 2.0,
			minpos = {x = pos.x - 0.25, y = pos.y + 0.5, z = pos.z - 0.25},
			maxpos = {x = pos.x + 0.25, y = pos.y + 1.0, z = pos.z + 0.25},
			minvel = {x = -0.2, y = 10, z = -0.2},
			maxvel = {x = 0.2, y = 16, z = 0.2},
			minacc = {x = 0, y = 0, z = 0},
			maxacc = {x = 0, y = 0, z = 0},
			minexptime = 0.5,
			maxexptime = 1.2,
			minsize = 3,
			maxsize = 7,
			texture = {
				name = "mcl_particles_smoke_anim.png",
				animation = {
					type = "vertical_frames",
					aspect_w = 16,
					aspect_h = 16,
					length = 0.8,
				},
			},
			glow = 10
		})

		core.sound_play("fire_large", { pos = pos, gain = 0.3, max_hear_distance = 20 })

		-- Efeito Físico: Ejetar entidades
		local upward_force = 6 + (water_h * 1.5)
		local objs = core.get_objects_in_area(
			{x = pos.x - 0.5, y = pos.y + 0.5, z = pos.z - 0.5},
			{x = pos.x + 0.5, y = pos.y + water_h + 1, z = pos.z + 0.5}
		)

		for _, obj in ipairs(objs) do
			local v = obj:get_velocity()
			if v then
				obj:set_velocity({x = v.x, y = upward_force, z = v.z})
			end
			if obj:is_player() then give_nausea(obj, 10) end
		end
	end
})

-------------------------------------------------------
-- LOGICA DO SULFUR SLIME (CUBE)
-------------------------------------------------------

local material_rules = {
	wood = { speed = 0.78, gravity = 0.92, jump = 1.0, label = "wood" },
	stone = { speed = 0.52, gravity = 1.55, jump = 0.72, label = "stone" },
	ice = { speed = 1.65, gravity = 0.88, jump = 1.10, label = "ice" },
	default = { speed = 1.0, gravity = 1.0, jump = 1.0, label = "sulfur" },
}

local function classify_material(name)
	if core.get_item_group(name, "wood") > 0 or core.get_item_group(name, "material_wood") > 0 then return material_rules.wood end
	if core.get_item_group(name, "ice") > 0 or core.get_item_group(name, "snowy") > 0 then return material_rules.ice end
	if core.get_item_group(name, "stone") > 0 or core.get_item_group(name, "rock") > 0 or core.get_item_group(name, "pickaxey") > 0 then return material_rules.stone end
	if name == modname .. ":sulphur_block" or core.get_item_group(name, "material_sulphur") > 0 then return material_rules.default end
	return nil
end

local function sulfur_slime_ai(self, dtime)
	if self.dead or not self.object:get_luaentity() then return end
	local rule = self.sulphur_rule or material_rules.default
	self.movement_velocity = (self.movement_speed or 10) * rule.speed
end

core.register_entity(modname .. ":sulfur_cube_contents", {
	initial_properties = { physical = false, visual = "wielditem", visual_size = SULFUR_BLOCK_VISUAL_SIZE, wield_item = "air" },
	on_step = function(self) if not self.parent or not self.parent:get_pos() then self.object:remove() end end,
})

if mcl_mobs and mcl_mobs.register_mob then
	mcl_mobs.register_mob(modname .. ":sulfur_slime", {
		description = S("Sulfur slime"),
		type = "animal", 
		spawn_class = "passive",
		hp_min = 16, hp_max = 16, armor = 80,
		collisionbox = { -0.75, -0.01, -0.75, 0.75, 1.5, 0.75 },
		visual = "mesh", mesh = "mobs_mc_slime.b3d",
		visual_size = SLIME_VISUAL_SIZE,
		textures = { "sulfur_cube_entity.png^[opacity:237" },
		movement_speed = 10, jump_height = 7,
		run_ai = sulfur_slime_ai,
		on_rightclick = function(self, clicker)
			local stack = clicker:get_wielded_item()
			local name = stack:get_name()
			if name == "mcl_buckets:bucket_empty" then
				clicker:set_wielded_item(ItemStack(modname .. ":bucket_of_sulfur_cube"))
				self.object:remove()
				return
			end
			local rule = classify_material(name)
			if rule then
				self.sulphur_rule = rule
				self.object:set_properties({ nametag = S("Sulfur cube: @1", rule.label) })
				stack:take_item()
				clicker:set_wielded_item(stack)
			end
		end,
	})
	mcl_mobs.register_egg(modname .. ":sulfur_slime", S("Sulfur slime"), "#f4d35e", "#7a6a2f", true)
end

core.register_craftitem(modname .. ":bucket_of_sulfur_cube", {
	description = S("Bucket with sulfur cube"),
	inventory_image = tex("bucket_of_sulfur_cube"),
	stack_max = 1,
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type == "node" then
			core.add_entity(pointed_thing.above, modname .. ":sulfur_slime")
			return ItemStack("mcl_buckets:bucket_empty")
		end
	end,
})