-- Mineclonia Commands Mod
-- Implementa autocomplete, coordenadas relativas (~, ^) e comandos execute, particle, testfor, testforblock, setblock

local modname = minetest.get_current_modname()

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

-- Função robusta para extrair posição de argumentos, lidando com ~~~ e ~ ~ ~
local function get_pos_from_args(args, player)
    if not player then return nil end
    local ppos = player:get_pos()
    local look_dir = player:get_look_dir()
    
    -- Primeiro, vamos verificar se o primeiro argumento contém múltiplos símbolos (ex: ~~~ ou ^^^6)
    local first_arg = args[1] or ""
    
    -- Caso especial: o usuário digitou "~~~" ou "^^^" colado
    if first_arg:match("^[~^][~^][~^]") then
        local symbol = first_arg:sub(1, 1)
        local rest = first_arg:sub(4) -- Pega o que vem depois dos 3 símbolos
        
        local x = parse_coord(symbol .. (rest ~= "" and rest or ""), ppos.x, look_dir.x)
        local y = parse_coord(symbol, ppos.y, look_dir.y)
        local z = parse_coord(symbol, ppos.z, look_dir.z)
        
        -- Remove o primeiro argumento e retorna a posição e os argumentos restantes
        table.remove(args, 1)
        return {x = x, y = y, z = z}, args
    end
    
    -- Caso padrão: "~ ~ ~" ou "23 ~ 23"
    local x = parse_coord(args[1], ppos.x, look_dir.x)
    local y = parse_coord(args[2], ppos.y, look_dir.y)
    local z = parse_coord(args[3], ppos.z, look_dir.z)
    
    -- Remove os 3 primeiros argumentos consumidos
    for i = 1, 3 do table.remove(args, 1) end
    
    return {x = x, y = y, z = z}, args
end

-- Comando: /setblock <x> <y> <z> <block>
minetest.register_chatcommand("setblock", {
    params = "<x> <y> <z> <block>",
    description = "Coloca um bloco em uma posição específica",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Jogador não encontrado"
        end

        local args = param:split(" ")
        local pos, remaining_args = get_pos_from_args(args, player)

        if not pos then
            return false, "Posição inválida"
        end

        local block_name = remaining_args[1]
        if not block_name then
            return false, "Uso: /setblock <x> <y> <z> <block>"
        end

        -- 🔒 VERIFICA SE O BLOCO EXISTE
        if not minetest.registered_nodes[block_name] then
            return false, "Bloco inexistente: " .. block_name
        end

        -- 🔒 PROTEÇÃO CONTRA CRASH
        local ok, err = pcall(function()
            minetest.set_node(pos, { name = block_name })
        end)

        if not ok then
            minetest.log("error", "[setblock] Erro ao colocar bloco: " .. tostring(err))
            return false, "Erro interno ao colocar o bloco (ver log)"
        end

        return true, "Bloco " .. block_name ..
            " colocado em " .. minetest.pos_to_string(pos)
    end,
})

-- Comando: /execute <pos> <cmd> ...
minetest.register_chatcommand("execute", {
    params = "<x> <y> <z> <command> [args...]",
    description = "Executa um comando em uma posição específica",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Jogador não encontrado" end
        
        local args = param:split(" ")
        local pos, remaining_args = get_pos_from_args(args, player)
        
        local cmd = remaining_args[1]
        if not cmd then
            return false, "Uso: /execute <x> <y> <z> <command> [args...]"
        end
        
        table.remove(remaining_args, 1)
        local cmd_args = table.concat(remaining_args, " ")
        
        local cmd_def = minetest.registered_chatcommands[cmd]
        if cmd_def then
            -- Nota: No Minetest real, mudar a posição do executor exige mais lógica, 
            -- mas aqui simulamos a chamada do comando.
            return cmd_def.func(name, cmd_args)
        else
            return false, "Comando não encontrado: " .. cmd
        end
    end,
})

-- Comando: /particle <name> <pos>
minetest.register_chatcommand("particle", {
    params = "<name> <x> <y> <z>",
    description = "Cria uma partícula na posição",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Jogador não encontrado" end
        
        local args = param:split(" ")
        local p_name = table.remove(args, 1)
        if not p_name then return false, "Especifique o nome da partícula" end
        
        local pos = get_pos_from_args(args, player)
        
        minetest.add_particle({
            pos = pos,
            velocity = {x=0, y=0, z=0},
            acceleration = {x=0, y=0, z=0},
            expirationtime = 2,
            size = 4,
            collisiondetection = false,
            vertical = false,
            texture = p_name,
        })
        return true, "Partícula " .. p_name .. " gerada em " .. minetest.pos_to_string(pos)
    end,
})

-- Comando: /testfor <player_name>
minetest.register_chatcommand("testfor", {
    params = "<player_name>",
    description = "Testa se um jogador está online",
    privs = {server = true},
    func = function(name, param)
        if param == "" then return false, "Especifique um nome" end
        local target = minetest.get_player_by_name(param)
        if target then
            return true, "Jogador " .. param .. " encontrado."
        else
            return false, "Jogador " .. param .. " não encontrado."
        end
    end,
})

-- Comando: /testforblock <pos> <node_name>
minetest.register_chatcommand("testforblock", {
    params = "<x> <y> <z> <node_name>",
    description = "Testa se um bloco em uma posição é de um tipo específico",
    privs = {server = true},
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Jogador não encontrado" end
        
        local args = param:split(" ")
        local pos, remaining_args = get_pos_from_args(args, player)
        local target_node = remaining_args[1]
        
        if not target_node then return false, "Especifique o nome do bloco" end
        
        local node = minetest.get_node(pos)
        if node.name == target_node then
            return true, "Bloco " .. target_node .. " encontrado em " .. minetest.pos_to_string(pos)
        else
            return false, "Bloco em " .. minetest.pos_to_string(pos) .. " é " .. node.name .. " (esperado: " .. target_node .. ")"
        end
    end,
})

-- Sistema de Autocomplete Melhorado
local custom_commands = {"execute", "particle", "testfor", "testforblock", "setblock"}

minetest.register_on_chat_message(function(name, message)
    if message:sub(1, 1) == "/" then
        local parts = message:sub(2):split(" ")
        local cmd_input = parts[1]
        
        local suggestions = {}
        for _, cmd in ipairs(custom_commands) do
            if cmd:sub(1, #cmd_input) == cmd_input then
                table.insert(suggestions, "/" .. cmd)
            end
        end
        
        if #suggestions > 0 and #parts == 1 and cmd_input ~= suggestions[1]:sub(2) then
            minetest.chat_send_player(name, "Sugestões: " .. table.concat(suggestions, ", "))
        end
    end
end)

minetest.log("action", "[Mineclonia Commands] Mod carregado com sucesso!")
