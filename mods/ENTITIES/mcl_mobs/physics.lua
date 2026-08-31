-- register extra flavours of a base nodedef
walkover = {}

local on_walk = {}
local on_walk_through = {}
local registered_globals = {}

walkover.registered_globals = registered_globals

function walkover.register_global(func)
	table.insert(registered_globals, func)
end

core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_nodes) do
		if def.on_walk_over then
			on_walk[name] = def.on_walk_over
		end

		if def._on_walk_through then
			on_walk_through[name] = def._on_walk_through
		end
	end
end)

mcl_player.register_globalstep(function(player)
	local pos = player:get_pos()

	-- Posição do bloco onde o jogador está em pé
	local npos = vector.add(pos, mcl_player.node_offsets.stand)
	local node = core.get_node(npos)

	-- Eventos normais de walkover
	if on_walk[mcl_player.players[player].nodes.stand] then
		on_walk[mcl_player.players[player].nodes.stand](
			npos,
			node,
			player
		)
	end

	-- Eventos globais
	for i = 1, #registered_globals do
		registered_globals[i](npos, node, player)
	end

	-- Walk through nos pés
	if on_walk_through[mcl_player.players[player].nodes.feet] then
		local feet_pos = vector.add(
			pos,
			mcl_player.node_offsets.feet
		)

		on_walk_through[mcl_player.players[player].nodes.feet](
			feet_pos,
			core.get_node(feet_pos),
			player
		)
	end

	-- Walk through na cabeça
	if on_walk_through[mcl_player.players[player].nodes.head] then
		local head_pos = vector.add(
			pos,
			mcl_player.node_offsets.head
		)

		on_walk_through[mcl_player.players[player].nodes.head](
			head_pos,
			core.get_node(head_pos),
			player
		)
	end
end)

-- Registro da lógica do Frost Walker no sistema walkover
walkover.register_global(function(npos, node, player)
	-- 1. Verifica se o jogador está em modo "pointable" (não está morto ou invisível de forma que ignore blocos)
	if not player:get_properties().pointable then return end

	-- 2. Pega as botas (Slot 5 no Mineclone/BetterCraft)
	local inv = player:get_inventory()
	if not inv then return end
	local boots = inv:get_stack("armor", 5)

	-- 3. Verifica o nível do encantamento
	-- Certifique-se que o ID "frost_walker" é o mesmo que está no seu enchantments.lua
	local level = mcl_enchanting.get_enchantment(boots, "frost_walker")
	
	if level > 0 then
		-- Só ativa se o jogador estiver no chão (não nadando)
		-- Verificamos se onde o jogador está "pisando" é água ou se ele está logo acima dela
		local pos = player:get_pos()
		local ground_pos = {x = pos.x, y = pos.y - 0.5, z = pos.z}
		local ground_node = core.get_node(ground_pos)

		-- O Frost Walker só deve funcionar se o bloco abaixo for água sólida (source)
		if ground_node.name == "mcl_core:water_source" or ground_node.name == "mcl_core:water_flowing" then
			
			local radius = 2 + level
			local p_pos = vector.round(pos)
			
			-- Loop para criar o gelo ao redor
			for dx = -radius, radius do
				for dz = -radius, radius do
					if dx * dx + dz * dz <= radius * radius then
						local ice_pos = {x = p_pos.x + dx, y = p_pos.y - 1, z = p_pos.z + dz}
						local check_node = core.get_node(ice_pos)
						
						-- Verifica se é água e se há ar acima (regra do Minecraft)
						if check_node.name == "mcl_core:water_source" then
							local above_node = core.get_node({x = ice_pos.x, y = ice_pos.y + 1, z = ice_pos.z})
							if above_node.name == "air" then
								core.set_node(ice_pos, {name = "mcl_core:frosted_ice_0"})
								-- Inicia o timer para o gelo derreter
								core.get_node_timer(ice_pos):start(math.random(2, 4))
							end
						end
					end
				end
			end
		end
	end
end)