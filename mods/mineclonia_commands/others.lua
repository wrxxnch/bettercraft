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

local S = core.get_translator(core.get_current_modname())

-- Função principal do comando
local function rejoin_func(name)
    -- Envia uma mensagem de log para o console (opcional)
    core.log("action", "Player " .. name .. " is rejoining using /rejoin")
    
    -- Kicka o jogador. O Luanti mostrará o botão "Reconnect" na tela de desconexão.
    core.kick_player(name, S("Rejoining... Click the Reconnect button below."))
    return true
end

-- Registro do comando /rejoin
core.register_chatcommand("rejoin", {
    description = S("Disconnect and show the reconnect button."),
    privs = {interact = true}, -- Apenas jogadores que podem interagir
    func = rejoin_func,
})

-- Registro do alias /rj
core.register_chatcommand("rj", {
    description = S("Alias for /rejoin"),
    privs = {interact = true},
    func = rejoin_func,
})