-- SPDX-License-Identifier: MIT
local core = minetest
local S = core.get_translator("sulphur_update")
local modname = "sulphur_update"

-- Escalas visuais
local SLIME_VISUAL_SIZE = { x = 9, y = 9 }
local SULFUR_BLOCK_VISUAL_SIZE = { x = 0.08, y = 0.08 }

local function tex(name) return name .. ".png" end

-- Registro de blocos básicos
local function register_full_block(name, description, texture, groups)
	core.register_node(modname .. ":" .. name, {
		description = S(description),
		tiles = { tex(texture) },
		is_ground_content = true,
		stack_max = 64,
		groups = groups or { pickaxey = 1, building_block = 1 },
		sounds = mcl_sounds and mcl_sounds.node_sound_stone_defaults(),
	})
end

-- Função auxiliar para medir a altura da coluna de água acima do bloco
local function get_water_column_height(pos)
	local height = 0
	local check_pos = {x = pos.x, y = pos.y + 1, z = pos.z}
	-- Limite máximo de 20 blocos para performance e balanceamento
	while height < 20 do
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


register_full_block("cinnabar", "Cinnabar", "cinnabar", { pickaxey = 1, building_block = 1, material_rock = 1 })
register_full_block("chiseled_cinnabar", "Chiseled Cinnabar", "chiseled_cinnabar")
register_full_block("polished_cinnabar", "Polished Cinnabar", "polished_cinnabar")
register_full_block("cinnabar_bricks", "Cinnabar Bricks", "cinnabar_bricks")
register_full_block("potent_sulfur", "Potent Sulfur", "potent_sulfur", { pickaxey = 1, building_block = 1, material_sulphur = 1 })
register_full_block("sulfur", "Sulfur", "sulfur", { pickaxey = 1, building_block = 1, material_sulphur = 1 })
register_full_block("chiseled_sulfur", "Chiseled Sulfur", "chiseled_sulfur")
register_full_block("polished_sulfur", "Polished Sulfur", "polished_sulfur")
register_full_block("sulfur_bricks", "Sulfur Bricks", "sulfur_bricks")

-------------------------------------------------------
-- SISTEMA DE ESPELEOTEMAS (SPIKES) - LÓGICA DE COLUNA
-------------------------------------------------------

local sulfur_spike_directions = { [-1] = "down", [1] = "up" }
local sulfur_spike_stages = { "tip_merge", "tip", "frustum", "middle", "base" }

local function sulfur_spike_node(stage, direction)
	return modname .. ":sulfur_spike_" .. sulfur_spike_directions[direction] .. "_" .. sulfur_spike_stages[stage]
end

local function sulfur_spike_direction(name)
	return string.find(name, ":sulfur_spike_down_", 1, true) and -1 or 1
end

-- Calcula o comprimento de uma coluna de spikes
local function sulfur_spike_length(pos, direction)
	local offset_pos = vector.copy(pos)
	local length = 0
	repeat
		length = length + 1
		offset_pos = vector.offset(offset_pos, 0, direction, 0)
	until core.get_item_group(core.get_node(offset_pos).name, "sulfur_spike_stage") == 0
	return length
end

-- Lógica de atualização para criar colunas e gerenciar estágios
local function sulfur_spike_update(pos, direction)
	-- Verifica se encontrou um spike na direção oposta para fundir (Merge)
	local other_pos = vector.offset(pos, 0, direction, 0)
	local other_node = core.get_node(other_pos).name
	if core.get_item_group(other_node, "sulfur_spike_stage") ~= 0 then
		local other_dir = sulfur_spike_direction(other_node)
		if other_dir == -direction then
			core.swap_node(pos, { name = sulfur_spike_node(1, direction) })
			core.swap_node(other_pos, { name = sulfur_spike_node(1, -direction) })
		end
	end

	-- Atualiza os blocos atrás do novo spike para engrossar a base
	local check_pos = vector.copy(pos)
	local stage = 0
	local previous_stage = 0
	while true do
		check_pos = vector.offset(check_pos, 0, -direction, 0)
		previous_stage = stage
		stage = core.get_item_group(core.get_node(check_pos).name, "sulfur_spike_stage")
		
		if stage == 4 or stage == 5 then -- Se chegou na base ou meio, para.
			break
		elseif stage == 0 then
			-- Se o anterior era o frustum(3), transforma o vizinho em base(5)
			if previous_stage == 3 then
				core.swap_node(vector.offset(check_pos, 0, direction, 0), { name = sulfur_spike_node(5, direction) })
			end
			break
		end
		-- Incrementa o estágio do bloco anterior
		core.swap_node(check_pos, { name = sulfur_spike_node(math.min(stage + 1, 5), direction) })
	end
end

-- Quebra a coluna se a base for removida
local function sulfur_spike_break_column(pos, direction)
	local offset_pos = vector.copy(pos)
	while true do
		offset_pos = vector.offset(offset_pos, 0, direction, 0)
		local node = core.get_node(offset_pos)
		local stage = core.get_item_group(node.name, "sulfur_spike_stage")
		if stage == 0 then break end
		
		-- Se era uma ponta mesclada, volta a ser uma ponta normal
		if stage == 1 then
			core.swap_node(offset_pos, { name = sulfur_spike_node(2, sulfur_spike_direction(node.name)) })
			break
		end
		
		core.add_item(offset_pos, ItemStack(modname .. ":sulphur_stalactite"))
		core.swap_node(offset_pos, { name = "air" })
	end
end

local function sulfur_spike_destruct(pos)
	local node = core.get_node(pos)
	local direction = sulfur_spike_direction(node.name)
	sulfur_spike_break_column(pos, direction)
end

-- Registro dos 5 estágios x 2 direções
for i, stage in ipairs(sulfur_spike_stages) do
	local add = (i - 1) / 16
	local box = { type = "fixed", fixed = {
		-0.18 - add, -0.5, -0.18 - add,
		 0.18 + add,  0.5,  0.18 + add
	}}
	for direction, label in pairs(sulfur_spike_directions) do
		core.register_node(sulfur_spike_node(i, direction), {
			description = S("Sulfur speleothem"),
			drawtype = "plantlike",
			tiles = { "sulfur_spike_" .. label .. "_" .. stage .. ".png" },
			paramtype = "light",
			use_texture_alpha = true,
			sunlight_propagates = true,
			walkable = true,
			groups = {
				pickaxey = 1, attached_node = 1, material_sulphur = 1,
				not_in_creative_inventory = (i == 2 and 0 or 1), 
				sulfur_spike_stage = i,
			},
			drop = modname .. ":sulphur_stalactite",
			on_destruct = sulfur_spike_destruct,
			sounds = mcl_sounds and mcl_sounds.node_sound_stone_defaults(),
		})
	end
end

core.register_craftitem(modname .. ":sulphur_stalactite", {
	description = S("Sulfur speleothem"),
	inventory_image = tex("sulfur_spike_up_tip"),
	on_place = function(itemstack, player, pointed_thing)
		if not pointed_thing or pointed_thing.type ~= "node" then return itemstack end
		local side = pointed_thing.above.y - pointed_thing.under.y
		local direction = (side == 0) and 1 or side
		
		core.set_node(pointed_thing.above, { name = sulfur_spike_node(2, direction) })
		sulfur_spike_update(pointed_thing.above, direction)
		
		if not core.is_creative_enabled(player:get_player_name()) then itemstack:take_item() end
		return itemstack
	end,
})

-------------------------------------------------------
-- GEYSER, SLIME E EFEITOS (O RESTANTE DO SEU CÓDIGO)
-------------------------------------------------------


core.register_abm({
	label = "Sulphur Constant Nausea",
	nodenames = { modname .. ":potent_sulfur" },
	interval = 1, -- Verifica a cada segundo
	chance = 1,
	action = function(pos)
		local water_h = get_water_column_height(pos)
		if water_h == 0 then return end

		-- Detecta jogadores na coluna de água
		local objs = core.get_objects_in_area(
			{x = pos.x - 0.7, y = pos.y + 0.5, z = pos.z - 0.7},
			{x = pos.x + 0.7, y = pos.y + water_h + 0.5, z = pos.z + 0.7}
		)

		for _, obj in ipairs(objs) do
			if obj:is_player() and mcl_potions and mcl_potions.give_effect then
				-- Aplica náusea por 2 segundos (se renova a cada segundo)
				mcl_potions.give_effect("nausea", obj, 1, 2, false)
			end
		end
	end
})

core.register_abm({
	label = "Sulphur Geyser Pulse",
	nodenames = { modname .. ":potent_sulfur" },
	interval = 12, -- Intervalo médio
	chance = 1,
	action = function(pos)
		-- Check for magma below
		local node_below = core.get_node({x = pos.x, y = pos.y - 1, z = pos.z}).name
		if node_below ~= "mcl_nether:magma" then return end
		
		-- Check for water above
		local water_h = get_water_column_height(pos)
		if water_h == 0 then return end

		-- Animated particles (smoke rising quickly)
		core.add_particlespawner({
			amount = 50,
			time = 2.0,
			minpos = {x = pos.x - 0.3, y = pos.y + 0.5, z = pos.z - 0.3},
			maxpos = {x = pos.x + 0.3, y = pos.y + 1.2, z = pos.z + 0.3},
			minvel = {x = -0.3, y = 15, z = -0.3},
			maxvel = {x = 0.3, y = 22, z = 0.3},
			minexptime = 0.8, maxexptime = 1.5,
			minsize = 5, maxsize = 10,
			texture = {
				name = "mcl_particles_smoke_anim.png",
				animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 0.8 },
			},
			glow = 14
		})

		core.sound_play("fire_large", { pos = pos, gain = 0.5, max_hear_distance = 30 })

		-- PHYSICAL EJECTION:
		-- Increase the force to overcome water resistance
		local upward_force = 12 + (water_h * 2) 
		
		-- Slightly larger search area to ensure player detection
		local objs = core.get_objects_in_area(
			{x = pos.x - 0.7, y = pos.y, z = pos.z - 0.7},
			{x = pos.x + 0.7, y = pos.y + water_h + 1, z = pos.z + 0.7}
		)

		for _, obj in ipairs(objs) do
			if obj:is_player() then
				-- add_velocity is the most reliable way to launch players
				obj:add_velocity({x = 0, y = upward_force, z = 0})
			else
				local v = obj:get_velocity()
				if v then
					obj:set_velocity({x = v.x, y = upward_force, z = v.z})
				end
			end
		end
	end
})

-- ABM de Crescimento natural de spikes (Baseado no seu código)
core.register_abm({
	label = "Sulfur speleothem growth",
	nodenames = { modname .. ":sulfur_spike_up_tip" },
	interval = 69, chance = 88,
	action = function(pos)
		local length = sulfur_spike_length(pos, 1)
		if length > 7 then return end
		local target = vector.offset(pos, 0, 1, 0)
		if core.get_node(target).name == "air" then
			core.set_node(target, { name = sulfur_spike_node(2, 1) })
			sulfur_spike_update(target, 1)
		end
	end,
})

-- LOGICA DO SLIME (Resumida para o init.lua)
if mcl_mobs and mcl_mobs.register_mob then
	mcl_mobs.register_mob(modname .. ":sulfur_slime", {
		description = S("Sulfur slime"),
		type = "animal", spawn_class = "passive",
		hp_min = 16, hp_max = 16, armor = 80,
		collisionbox = { -0.75, -0.01, -0.75, 0.75, 1.5, 0.75 },
		visual = "mesh", mesh = "mobs_mc_slime.b3d",
		visual_size = SLIME_VISUAL_SIZE,
		textures = { "sulfur_cube_entity.png^[opacity:237" },
		on_rightclick = function(self, clicker)
			local stack = clicker:get_wielded_item()
			if stack:get_name() == "mcl_buckets:bucket_empty" then
				clicker:set_wielded_item(ItemStack(modname .. ":bucket_of_sulfur_cube"))
				self.object:remove()
			end
		end,
	})
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

-- Crafting do Potent Sulfur
core.register_craft({ output = modname .. ":potent_sulfur", recipe = { { modname .. ":sulfur", modname .. ":sulfur" }, { modname .. ":sulfur", modname .. ":sulfur" } } })