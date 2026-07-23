-- Função auxiliar para pegar o bloco que o jogador está olhando
local function get_pointed_node(player)
	local eye_pos = player:get_pos()
	eye_pos.y = eye_pos.y + player:get_properties().eye_height
	local look_dir = player:get_look_dir()
	local dist = 10 -- distância máxima
	local ray = minetest.raycast(eye_pos, eye_pos + look_dir * dist, false, false)
	local pointed = ray:next()

	if pointed and pointed.type == "node" then
		return pointed.under
	end
	return nil
end

-- Comando /set_param <num>
minetest.register_chatcommand("set_param", {
	params = "<num>",
	description = "Altera o param2 do bloco que você está olhando",
	privs = {server = true},
	func = function(name, param)
		local val = tonumber(param)
		if not val then
			return false, "Erro: digite um número (Ex: /set_param 4)"
		end

		local player = minetest.get_player_by_name(name)
		local pos = get_pointed_node(player)

		if pos then
			local node = minetest.get_node(pos)
			node.param2 = val
			minetest.swap_node(pos, node)
			return true, "Param2 de " .. node.name .. " alterado para " .. val
		end
		return false, "Nenhum bloco encontrado na mira."
	end
})

-- Comando /honeylevel <0-5>
minetest.register_chatcommand("honeylevel", {
	params = "<0-5>",
	description = "Altera o nível de mel da colmeia que você está olhando",
	privs = {server = true},
	func = function(name, param)
		local level = tonumber(param)
		if not level then
			return false, "Uso: /honeylevel <número>"
		end

		local player = minetest.get_player_by_name(name)
		local pos = get_pointed_node(player)

		if pos then
			local node = minetest.get_node(pos)
			-- Remove qualquer sufixo de mel atual (ex: beehive_1 vira beehive)
			local base_name = node.name:gsub("_%d+$", "")
			
			local new_name
			if level == 0 then
				new_name = base_name
			else
				new_name = base_name .. "_" .. level
			end

			-- Verifica se esse bloco existe no jogo antes de trocar
			if minetest.registered_nodes[new_name] then
				minetest.swap_node(pos, {name = new_name, param2 = node.param2})
				return true, "Colmeia alterada para: " .. new_name
			else
				return false, "Erro: O bloco " .. new_name .. " não existe no registro."
			end
		end
		return false, "Nenhum bloco encontrado na mira."
	end
})