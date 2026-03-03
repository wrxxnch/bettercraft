-- Mineclonia Commands Mod
-- Implementa autocomplete, coordenadas relativas (~, ^) e comandos execute, particle, testfor, testforblock, setblock


-- tabela principal do mod
mineclonia_commands = {}
-- mineclonia_commands.execute = {}

local modname = minetest.get_current_modname()


dofile(minetest.get_modpath(modname) .. "/particle.lua")
dofile(minetest.get_modpath(modname) .. "/testfor.lua")
dofile(minetest.get_modpath(modname) .. "/give.lua")
dofile(minetest.get_modpath(modname) .. "/setblock.lua")

-- Função para atualizar o sinal de Redstone do Command Block e ativar comparadores
local function set_commandblock_result(success)
    local pos = core.commandblock_pos or (minetest.get_commandblock_pos and minetest.get_commandblock_pos())
    if not pos then return end

    local meta = minetest.get_meta(pos)
    meta:set_int("success_count", success and 1 or 0)
    meta:set_int("comparator_power", success and 15 or 0)

    if mcl_redstone and mcl_redstone.update_comparators then
        mcl_redstone.update_comparators(pos)
    end
end

-- Função para executar um comando como se fosse o jogador/bloco de comando
local function run_conditional_command(name, cmd_str)
    if not cmd_str or cmd_str == "" then return end
    
    for single_cmd in cmd_str:gmatch("([^,]+)") do
        local trimmed = single_cmd:gsub("^%s*(.-)%s*$", "%1")
        if trimmed:sub(1,1) == "/" then trimmed = trimmed:sub(2) end
        
        local parts = trimmed:split(" ")
        local cmd = parts[1]
        table.remove(parts, 1)
        local args = table.concat(parts, " ")
        
        local cmd_def = minetest.registered_chatcommands[cmd]
        if cmd_def then
            cmd_def.func(name, args)
        else
            minetest.chat_send_player(name, "Comando condicional não encontrado: " .. cmd)
        end
    end
end

-- Função auxiliar para parsear uma única coordenada
local function parse_coord(coord_str, current_val, look_dir)
    if not coord_str or coord_str == "" then return current_val end
    local first_char = coord_str:sub(1, 1)
    if first_char == "~" or first_char == "^" then
        local val_part = coord_str:gsub("^[~^]+", "")
        local offset = tonumber(val_part) or 0
        if first_char == "^" then
            return current_val + (look_dir * offset)
        else
            return current_val + offset
        end
    end
    return tonumber(coord_str) or current_val
end

-- Função robusta para extrair posição de argumentos
function get_pos_from_args(args, player)
    if not player then return nil end
    local ppos = player:get_pos()
    local look_dir = player:get_look_dir()
    local first_arg = args[1] or ""
    
    if first_arg:match("^[~^][~^][~^]") then
        local symbol = first_arg:sub(1, 1)
        local rest = first_arg:sub(4)
        local x = parse_coord(symbol .. (rest ~= "" and rest or ""), ppos.x, look_dir.x)
        local y = parse_coord(symbol, ppos.y, look_dir.y)
        local z = parse_coord(symbol, ppos.z, look_dir.z)
        table.remove(args, 1)
        return {x = x, y = y, z = z}, args
    end
    
    if #args < 3 then return nil, args end
    local x = parse_coord(args[1], ppos.x, look_dir.x)
    local y = parse_coord(args[2], ppos.y, look_dir.y)
    local z = parse_coord(args[3], ppos.z, look_dir.z)
    for i = 1, 3 do table.remove(args, 1) end
    return {x = x, y = y, z = z}, args
end

-- Função central de parsing para extrair execute= e execute!=
local function extract_conditional_commands(param)
    local exec_if, exec_unless
    
    local function find_and_remove(p, key)
        local start_idx, end_idx = p:find(key .. "=")
        if not start_idx then return nil, p end
        
        local cmd_start = end_idx + 1
        local next_marker = p:find(" execute", cmd_start)
        local cmd_end = next_marker and (next_marker - 1) or #p
        
        local cmd = p:sub(cmd_start, cmd_end)
        local new_p = p:sub(1, start_idx - 1) .. p:sub(cmd_end + 1)
        return cmd, new_p
    end

    exec_unless, param = find_and_remove(param, "execute!")
    exec_if, param = find_and_remove(param, "execute")
    
    param = param:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
    return exec_if, exec_unless, param
end

local function entity_matches(obj, filters)
    local is_player = obj:is_player()
    local lua = obj:get_luaentity()
    if not is_player and not lua then return false end
    
    if filters.only_players and not is_player then return false end

    if filters.type then
        local ent_type = is_player and "player" or lua.name
        if ent_type ~= filters.type then return false end
    end
    if filters.name then
        local ent_name = is_player and obj:get_player_name() or (lua.name or "")
        if ent_name ~= filters.name then return false end
    end
    if filters.center and filters.radius then
        if vector.distance(obj:get_pos(), filters.center) > filters.radius then
            return false
        end
    end
    return true
end

-- Autocomplete
local custom_commands = {"execute", "particle", "testfor", "testforblock", "setblock"}
minetest.register_on_chat_message(function(name, message)
    if message:sub(1, 1) == "/" then
        local parts = message:sub(2):split(" ")
        local cmd_input = parts[1]
        local suggestions = {}
        for _, cmd in ipairs(custom_commands) do
            if cmd:sub(1, #cmd_input) == cmd_input then table.insert(suggestions, "/" .. cmd) end
        end
        if #suggestions > 0 and #parts == 1 and cmd_input ~= suggestions[1]:sub(2) then
            minetest.chat_send_player(name, "Sugestões: " .. table.concat(suggestions, ", "))
        end
    end
end)

minetest.log("action", "[Mineclonia Commands] Mod carregado com sucesso!")