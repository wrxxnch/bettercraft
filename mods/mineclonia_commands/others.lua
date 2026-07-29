core.register_chatcommand("fallingnode", {
	params = "<bloco> <x> <y> <z>",
	description = "Spawna qualquer bloco como falling node (suporta ~)",
	privs = {server = true},

	func = function(name, param)
		local nodename, xs, ys, zs =
			param:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$")

		if not nodename then
			return false, "Uso: /fallingnode <bloco> <x> <y> <z>"
		end

		local player = core.get_player_by_name(name)
		if not player then
			return false, "Player não encontrado"
		end

		local base = vector.round(player:get_pos())

		local x = parse_coord(xs, base.x)
		local y = parse_coord(ys, base.y)
		local z = parse_coord(zs, base.z)

		if not x or not y or not z then
			return false, "Coordenadas inválidas"
		end

		-- Resolver nome curto (stone -> mcl_core:stone)
		if not core.registered_nodes[nodename] then
			for full, _ in pairs(core.registered_nodes) do
				if full:sub(full:find(":") + 1) == nodename then
					nodename = full
					break
				end
			end
		end

		local def = core.registered_nodes[nodename]
		if not def then
			return false, "Bloco inexistente: " .. nodename
		end

		local pos = vector.new(x, y, z)

		-- Spawn FORÇADO do falling node
		local obj = core.add_entity(pos, "__builtin:falling_node")
		if not obj then
			return false, "Falha ao criar falling node"
		end

		obj:get_luaentity():set_node({
			name = nodename,
			param1 = 0,
			param2 = 0
		}, {})

		if def.sounds and def.sounds.fall then
			core.sound_play(def.sounds.fall, {pos = pos}, true)
		end

		return true, "Falling node criado em " .. core.pos_to_string(pos)
	end
})

--[[
	summon_jockey_command.lua
	----------------------------------------------------------------
	Comando: /summon_jockey <mob1> <mob2> [<mob3> ...] [offset=x,y,z]

	Spawna uma PILHA de jockeys na posição do jogador:
	  - mob1 = montaria da base (o que fica no chão)
	  - mob2 = monta mob1
	  - mob3 = monta mob2 (se informado)
	  - ...e assim por diante, quantos mobs você passar.

	offset=x,y,z (opcional, em nodes) substitui o cálculo automático
	de onde o passageiro fica preso, aplicado em TODOS os "andares"
	da pilha. Ex: summon_jockey zombie zombie offset=0,1.5,0
	Componentes vazios viram 0 (ex: offset=,1.5, equivale a 0,1.5,0).

	Baseado no padrão do chatcommand `spawn_mob` já existente no seu
	arquivo, e na lógica de jockey vista em `mob_class:kill_me`
	(campos `_jockey_rider` na montaria e `jockey_vehicle` no
	passageiro, usados para desmontar automaticamente quando a
	montaria morre).

	IMPORTANTE: este arquivo assume que `mob_class:jock()` /
	`mob_class:unjock()` (chamados em `kill_me`) existem em algum
	outro lugar do mod, mas não define eles — o attach aqui é feito
	manualmente com `object:set_attach`. Se o seu mod já tiver um
	`mob_class:jock(vehicle)` que cuida de offsets/sons/animação,
	é melhor usar ele no lugar do bloco "monta a pilha" abaixo.

	Coloque este arquivo junto aos outros do mod mcl_mobs (ele espera
	`core.registered_entities`, `core.add_entity`, etc. já
	disponíveis, sem precisar de nenhum require extra).
]]--

local S = core.get_translator(core.get_current_modname())

-- Calcula um deslocamento vertical aproximado pra sentar o rider em
-- cima da montaria, usando a collisionbox da montaria (índice 5 = Y
-- máximo da caixa). set_attach espera a posição em unidades de 1/10
-- de node, por isso o * 10.
local function estimate_mount_offset(vehicle_luaentity)
	if vehicle_luaentity
		and vehicle_luaentity.initial_properties
		and vehicle_luaentity.initial_properties.collisionbox then
		local cbox = vehicle_luaentity.initial_properties.collisionbox
		return cbox[5] * 10
	end
	return 0
end

-- Faz o parse de um token "offset=x,y,z" pro comando summon_jockey.
-- Retorna: tabela {x=,y=,z=} em unidades de node (será convertida pra
-- 1/10 de node depois), ou nil, erro se o formato estiver errado.
-- Componentes ausentes (ex: "offset=,2,") viram 0.
local function parse_offset(token)
	local raw = token:match("^offset=(.*)$")
	if not raw then
		return nil, nil -- não é um token de offset
	end

	local parts = {}
	for part in (raw .. ","):gmatch("([^,]*),") do
		table.insert(parts, part)
	end

	if #parts ~= 3 then
		return nil, S("Offset inválido: @1 (use offset=x,y,z)", token)
	end

	local coords = {}
	for i, axis in ipairs({ "x", "y", "z" }) do
		local text = parts[i]
		if text == "" then
			coords[axis] = 0
		else
			local num = tonumber(text)
			if not num then
				return nil, S("Offset inválido: @1 (use offset=x,y,z)", token)
			end
			coords[axis] = num
		end
	end

	return coords, nil
end

-- Desfaz o attach de uma pilha parcialmente montada, em caso de erro
-- no meio do processo (ex: um mob no meio da lista não existe).
local function cleanup_objects(objects)
	for i = #objects, 1, -1 do
		local obj = objects[i]
		if obj and obj:get_luaentity() then
			obj:remove()
		end
	end
end

-- Resolve um nome de mob digitado sem o prefixo do mod (ex: "zombie")
-- para o nome completo registrado (ex: "mobs_mc:zombie").
-- Retorna: nome_resolvido, erro
--   - Se `mob` já for um nome completo registrado, devolve ele mesmo.
--   - Senão, procura entre todas as entidades registradas por algo
--     terminando em ":"..mob.
--   - Se achar exatamente uma, resolve. Se achar mais de uma (nome
--     ambíguo entre mods), devolve erro listando as opções. Se não
--     achar nenhuma, devolve erro de "mob desconhecido".
local function resolve_mob_name(mob)
	if core.registered_entities[mob] then
		return mob, nil
	end

	local suffix = ":" .. mob
	local matches = {}
	for entity_name in pairs(core.registered_entities) do
		if entity_name:sub(-#suffix) == suffix then
			table.insert(matches, entity_name)
		end
	end

	if #matches == 1 then
		return matches[1], nil
	elseif #matches > 1 then
		table.sort(matches)
		return nil, S("Nome de mob ambíguo: @1 (encontrado em: @2). "
			.. "Digite o nome completo com o prefixo do mod.",
			mob, table.concat(matches, ", "))
	else
		return nil, S("Mob desconhecido: @1", mob)
	end
end

core.register_chatcommand("summon_jockey", {
	privs = { debug = true },
	params = "<mob1> <mob2> [<mob3> ...] [offset=x,y,z]",
	description = S("Spawna uma pilha de jockeys: mob1 é a montaria da base, "
		.. "mob2 monta mob1, mob3 monta mob2, e assim por diante. "
		.. "Use offset=x,y,z (em nodes) pra ajustar manualmente onde o "
		.. "passageiro fica preso na montaria, no lugar do cálculo "
		.. "automático. Ex: summon_jockey zombie zombie offset=0,1.5,0"),
	func = function(playername, param)
		local player = core.get_player_by_name(playername)
		if not player then
			return false, S("Jogador não encontrado.")
		end
		local pos = player:get_pos()

		-- Separa os tokens em nomes de mob e um possível
		-- "offset=x,y,z" (pode vir em qualquer posição do comando)
		local mobs = {}
		local custom_offset = nil
		for token in param:gmatch("%S+") do
			local coords, err = parse_offset(token)
			if err then
				return false, err
			elseif coords then
				custom_offset = coords
			else
				table.insert(mobs, token)
			end
		end

		if #mobs < 2 then
			return false, S("Uso: summon_jockey <mob1> <mob2> [<mob3> ...] "
				.. "[offset=x,y,z] (precisa de pelo menos 2 mobs).")
		end

		-- Resolve cada nome (com ou sem prefixo de mod) ANTES de
		-- spawnar qualquer coisa, pra não deixar spawns "pela
		-- metade" se um nome estiver errado ou ambíguo.
		local resolved = {}
		for i, mob in ipairs(mobs) do
			local full_name, err = resolve_mob_name(mob)
			if not full_name then
				return false, err
			end
			resolved[i] = full_name
		end
		mobs = resolved

		-- Spawna cada mob da pilha na mesma posição
		local objects = {}
		for i, mob in ipairs(mobs) do
			local staticdata = core.serialize({ persist_in_peaceful = true })
			local obj = core.add_entity(pos, mob, staticdata)
			if not obj then
				cleanup_objects(objects)
				return false, S("Falha ao spawnar @1, abortando a pilha.", mob)
			end
			objects[i] = obj
		end

		-- Monta a pilha: objects[i+1] monta objects[i]
		for i = 1, #objects - 1 do
			local vehicle = objects[i]
			local rider = objects[i + 1]
			local vehicle_ent = vehicle:get_luaentity()
			local rider_ent = rider:get_luaentity()

			local attach_pos
			if custom_offset then
				-- offset= é dado em unidades de node;
				-- set_attach espera 1/10 de node, por isso * 10
				attach_pos = {
					x = custom_offset.x * 10,
					y = custom_offset.y * 10,
					z = custom_offset.z * 10,
				}
			else
				attach_pos = { x = 0, y = estimate_mount_offset(vehicle_ent), z = 0 }
			end

			rider:set_attach(vehicle, "", attach_pos, { x = 0, y = 0, z = 0 })

			-- Mesmos campos que `mob_class:kill_me` já espera
			-- pra desmontar o rider automaticamente quando a
			-- montaria morrer.
			if vehicle_ent then
				vehicle_ent._jockey_rider = rider
			end
			if rider_ent then
				rider_ent.jockey_vehicle = vehicle
			end
		end

		core.log("action", playername .. " spawned jockey stack ("
			.. table.concat(mobs, " > ") .. ") at "
			.. core.pos_to_string(pos))

		return true, S("Jockey spawnado: @1", table.concat(mobs, " montando "))
	end,
})
