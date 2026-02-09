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
	local target_str, dest_str = param:match("^(%S+)%s+(.+)$")
	if not target_str then
		-- Fallback to original behavior if it's just one param (teleport self)
		return minetest.registered_chatcommands["teleport"].func(name, param)
	end
	
	local targets = selectors.resolve(name, target_str)
	local dest_pos
	
	-- Try to parse dest as coordinates
	local x, y, z = dest_str:match("^([%d.~-]+)[, ] *([%d.~-]+)[, ] *([%d.~-]+)$")
	if x and y and z then
		local caller = minetest.get_player_by_name(name)
		dest_pos = minetest.parse_coordinates(x, y, z, caller and caller:get_pos())
	else
		-- Try to parse dest as a player name
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
		obj:set_pos(dest_pos)
		count = count + 1
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
