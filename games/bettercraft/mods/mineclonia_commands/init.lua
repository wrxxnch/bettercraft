-- Mineclonia Commands Mod
-- Implementa autocomplete, coordenadas relativas (~, ^) e comandos execute, particle, testfor, testforblock, setblock

local modname = minetest.get_current_modname()

--load particle.lua
dofile(minetest.get_modpath(modname) .. "/particle.lua")

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
local function get_pos_from_args(args, player)
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

-- Comando: /testfor <seletor> [x y z] [,radius=n] execute=...
minetest.register_chatcommand("testfor", {
    params = "<@a|@e> [x y z] [,radius=n] execute=...",
    description = "Testa entidades/jogadores com precisão",
    privs = { server = true },
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        local exec_if, exec_unless, clean_param = extract_conditional_commands(param)
        
        if clean_param == "" then
            set_commandblock_result(false)
            return false, "Filtros não especificados"
        end

        -- Extrair radius fora do seletor se houver (ex: ,radius=5)
        local extra_radius = clean_param:match(",%s*radius=(%d+)") or clean_param:match(",%s*r=(%d+)")
        if extra_radius then
            clean_param = clean_param:gsub(",%s*radius=%d+", ""):gsub(",%s*r=%d+", "")
        end

        local args = clean_param:split(" ")
        local selector = args[1]
        table.remove(args, 1)

        local filters = {}
        local ppos = player and player:get_pos() or {x=0, y=0, z=0}
        filters.center = {x=ppos.x, y=ppos.y, z=ppos.z}
        filters.radius = 32768 -- Padrão: mundo todo

        -- Tratar seletores
        if selector:sub(1,2) == "@a" then
            filters.only_players = true
        end

        -- Extrair filtros de colchetes: @a[r=10]
        local inside = selector:match("%[(.+)%]")
        if inside then
            for pair in inside:gmatch("[^,]+") do
                local k,v = pair:match("([^=]+)=([^=]+)")
                if k and v then
                    if k == "x" then filters.center.x = tonumber(v) or filters.center.x
                    elseif k == "y" then filters.center.y = tonumber(v) or filters.center.y
                    elseif k == "z" then filters.center.z = tonumber(v) or filters.center.z
                    elseif k == "r" or k == "radius" then filters.radius = tonumber(v)
                    else filters[k] = v end
                end
            end
        end

        -- Se houver coordenadas X Y Z diretas
        if #args >= 3 then
            local pos, _ = get_pos_from_args(args, player)
            if pos then 
                filters.center = pos 
                -- Se forneceu coordenadas diretas mas não o raio, o padrão é 1 (precisão exata)
                filters.radius = tonumber(extra_radius) or 1
            end
        elseif extra_radius then
            filters.radius = tonumber(extra_radius)
        end

        local objects = minetest.get_objects_inside_radius(filters.center, filters.radius)
        local count = 0
        for _, obj in ipairs(objects) do
            if entity_matches(obj, filters) then count = count + 1 end
        end

        local success = count > 0
        set_commandblock_result(success)
        
        if success and exec_if then run_conditional_command(name, exec_if) end
        if not success and exec_unless then run_conditional_command(name, exec_unless) end

        return success, (success and "Encontrado(s) " .. count .. " alvo(s)" or "Nenhum alvo encontrado")
    end,
})

-- Comando: /testforblock
minetest.register_chatcommand("testforblock", {
    params = "<x> <y> <z> <node> execute=...",
    description = "Testa bloco e executa comandos",
    privs = { server = true },
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Jogador inválido" end
        local exec_if, exec_unless, clean_param = extract_conditional_commands(param)
        local args = clean_param:split(" ")
        for i = #args, 1, -1 do if args[i] == "" then table.remove(args, i) end end
        local pos, rest = get_pos_from_args(args, player)
        local nodename = rest and rest[1]
        if not pos or not nodename then return false, "Uso: /testforblock <x> <y> <z> <node> [execute=...]" end
        if not nodename:find(":") then
            local full_name = "mcl_core:" .. nodename
            if minetest.registered_nodes[full_name] then nodename = full_name end
        end
        local node = minetest.get_node(pos)
        local success = (node.name == nodename)
        set_commandblock_result(success)
        if success and exec_if then run_conditional_command(name, exec_if) end
        if not success and exec_unless then run_conditional_command(name, exec_unless) end
        return success, (success and "Bloco " .. nodename .. " encontrado" or "Encontrado " .. node.name)
    end,
})

-- Comando: /setblock
minetest.register_chatcommand("setblock", {
    params = "<x> <y> <z> <block>",
    description = "Coloca um bloco",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false end
        local args = param:split(" ")
        local pos, remaining_args = get_pos_from_args(args, player)
        if not pos then return false end
        local block_name = remaining_args[1]
        if not block_name then return false end
        if not block_name:find(":") then
            local full_name = "mcl_core:" .. block_name
            if minetest.registered_nodes[full_name] then block_name = full_name end
        end
        minetest.set_node(pos, { name = block_name })
        return true
    end,
})

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