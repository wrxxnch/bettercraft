-- selectors mod init.lua
local selectors = dofile(minetest.get_modpath("selectors") .. "/selectors.lua")
local S = minetest.get_translator("selectors")

-- Utility to trim strings
function string.trim(s)
	return s:match("^%s*(.-)%s*$")
end

-- Function to override a command
local function override_command(name, new_def)
	local old_def = minetest.registered_chatcommands[name]
	if old_def then
		local def = table.copy(old_def)
		for k, v in pairs(new_def) do
			def[k] = v
		end
		minetest.unregister_chatcommand(name)
		minetest.register_chatcommand(name, def)
	end
end

-- 1. Override /kill
override_command("kill", {
	func = function(name, param)
		local targets = selectors.resolve(name, param)
		if #targets == 0 then
			return false, "Nenhum alvo encontrado para: " .. param
		end
		
		local count = 0
		for _, obj in ipairs(targets) do
	if obj:is_player() then
		-- ignora jogador
	else
		local ent = obj:get_luaentity()
		if ent then
			obj:remove()
			count = count + 1
		end
	end
end

		return true, "Mortos " .. count .. " alvos."
	end,
})

-- 2. Override /teleport (tp)
local function handle_tp(name, param)

	if param == "" then
		return false, "Uso: /tp <x y z> OU /tp <alvo> <x y z>"
	end

	local caller = minetest.get_player_by_name(name)
	if not caller then
		return false, "Player não encontrado."
	end

	--------------------------------------------------
	-- CASO 1: /tp x y z  (teleporta a si mesmo)
	--------------------------------------------------
	local x1, y1, z1 = param:match("^([%d.~%-]+)[, ]+([%d.~%-]+)[, ]+([%d.~%-]+)$")

	if x1 and y1 and z1 then
		local pos = minetest.parse_coordinates(x1, y1, z1, caller:get_pos())
		if not pos then
			return false, "Coordenadas inválidas."
		end

		caller:set_pos(pos)
		return true, "Teletransportado para " .. minetest.pos_to_string(pos)
	end

	--------------------------------------------------
	-- CASO 2: /tp <alvo> <x y z>
	--------------------------------------------------
	local target_str, dest_str = param:match("^(%S+)%s+(.+)$")
	if not target_str then
		return false, "Uso inválido."
	end

	local targets = selectors.resolve(name, target_str)
	if #targets == 0 then
		return false, "Alvo não encontrado: " .. target_str
	end

	-- Tentar coordenadas
	local x, y, z = dest_str:match("^([%d.~%-]+)[, ]+([%d.~%-]+)[, ]+([%d.~%-]+)$")
	local dest_pos

	if x and y and z then
		dest_pos = minetest.parse_coordinates(x, y, z, caller:get_pos())
	else
		-- Tentar player como destino
		local target_player = minetest.get_player_by_name(dest_str)
		if target_player then
			dest_pos = target_player:get_pos()
		end
	end

	if not dest_pos then
		return false, "Destino inválido: " .. dest_str
	end

	local count = 0
	for _, obj in ipairs(targets) do
		if obj and obj:get_pos() then
			obj:set_pos(dest_pos)
			count = count + 1
		end
	end

	return true, "Teleportados " .. count .. " alvos para " .. minetest.pos_to_string(dest_pos)
end

override_command("teleport", { func = handle_tp })
if minetest.registered_chatcommands["tp"] then
	override_command("tp", { func = handle_tp })
end

-- 3. Override /msg
override_command("msg", {
	func = function(name, param)
		local target_str, message = param:match("^(%S+)%s+(.+)$")
		if not target_str then return false, "Uso: /msg <alvo> <mensagem>" end
		
		local targets = selectors.resolve(name, target_str)
		local count = 0
		for _, obj in ipairs(targets) do
			if obj:is_player() then
				minetest.chat_send_player(obj:get_player_name(), "DM de " .. name .. ": " .. message)
				count = count + 1
			end
		end
		return true, "Mensagem enviada para " .. count .. " jogadores."
	end,
})

minetest.log("action", "[selectors] Mod carregado e comandos sobrescritos.")
