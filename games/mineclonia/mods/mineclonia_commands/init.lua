-- Mineclonia Commands Mod
-- Implementa autocomplete, coordenadas relativas (~, ^) e comandos execute, particle, testfor, testforblock, setblock

local modname = minetest.get_current_modname()

-- Registro manual de partículas conhecidas
local registered_particles = {}


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

-- Função para limpar nomes de textura (v2+)
local function clean_texture_name(str)
    if not str or type(str) ~= "string" then return nil end
    local base = str:split("^")[1]:split("[")[1]
    base = base:gsub("^%(", ""):gsub("%)$", ""):gsub("[%(%)]", "")
    base = base:trim()
    return base ~= "" and base or nil
end

-- Busca refinada STRICT (v4)
local function find_textures_refined(search)
    local exact_png = {}
    local exact_name = {}
    search = search:lower()

    for _, def in pairs(minetest.registered_items) do
        local candidates = {}

        if def.tiles then
            for _, t in ipairs(def.tiles) do
                local n = type(t) == "table" and t.name or t
                if type(n) == "string" then
                    table.insert(candidates, n)
                end
            end
        end

        if def.inventory_image and def.inventory_image ~= "" then
            table.insert(candidates, def.inventory_image)
        end

        for _, tex in ipairs(candidates) do
            local clean = clean_texture_name(tex)
            if clean then
                local cl = clean:lower()

                -- prioridade ABSOLUTA
                if cl == search .. ".png" then
                    exact_png[clean] = true
                elseif cl == search then
                    exact_name[clean] = true
                end
            end
        end
    end

    -- converte sets para lista
    local function to_list(t)
        local r = {}
        for k in pairs(t) do table.insert(r, k) end
        table.sort(r)
        return r
    end

    if next(exact_png) then
        return to_list(exact_png)
    end

    if next(exact_name) then
        return to_list(exact_name)
    end

    -- NADA de fallback parcial
    return {}
end

minetest.register_chatcommand("particle", {
    params = "<texture> <falling|floating|static> [count] [size] [speed]",
    description = "summon particles,particles inside textures are not listed by particle_search but you can use on particle command,example:/particle heart.png floating",
    privs = {server = true},
    func = function(name, param)
        local args = param:split(" ")
        if #args < 2 then
            return false,
                "Uso: /particle <texture.png> <falling|floating|static> [quantidade] [tamanho] [velocidade]"
        end

        -- textura EXATA
        local texture = args[1]
        local mode = args[2]:lower()
        local count = tonumber(args[3]) or 30
        local base_size = tonumber(args[4]) or 1
        local base_speed = tonumber(args[5]) or 2

        if mode ~= "falling" and mode ~= "floating" and mode ~= "static" then
            return false, "Modo inválido: use falling, floating ou static"
        end

        local player = minetest.get_player_by_name(name)
        if not player then return false, "Jogador não encontrado" end

        local pos = player:get_pos()
        pos.y = pos.y + 1.5

        -- Lógica de Movimento
        local minvel, maxvel, minacc, maxacc
        local collision = true

        if mode == "falling" then
            minvel = {x = -0.5, y = 0, z = -0.5}
            maxvel = {x = 0.5, y = 1, z = 0.5}
            minacc = {x = 0, y = -9.8, z = 0}
            maxacc = {x = 0, y = -9.8, z = 0}

        elseif mode == "floating" then
            minvel = {x = -base_speed, y = base_speed / 2, z = -base_speed}
            maxvel = {x = base_speed, y = base_speed, z = base_speed}
            minacc = {x = -0.1, y = 0.1, z = -0.1}
            maxacc = {x = 0.1, y = 0.5, z = 0.1}

        else -- static
            minvel = {x = 0, y = 0, z = 0}
            maxvel = {x = 0, y = 0, z = 0}
            minacc = {x = 0, y = 0, z = 0}
            maxacc = {x = 0, y = 0, z = 0}
            collision = false
        end

        minetest.add_particlespawner({
            amount = count,
            time = 2,
            minpos = {x = pos.x - 0.3, y = pos.y, z = pos.z - 0.3},
            maxpos = {x = pos.x + 0.3, y = pos.y + 0.6, z = pos.z + 0.3},
            minvel = minvel,
            maxvel = maxvel,
            minacc = minacc,
            maxacc = maxacc,
            minexptime = (mode == "static" and 5 or 1),
            maxexptime = (mode == "static" and 10 or 3),
            minsize = base_size,
            maxsize = base_size * 1.5,
            collisiondetection = collision,
            collision_removal = (mode == "falling"),
            texture = texture, 
            glow = 12,
        })

        return true,
            count .. " partículas de '" .. texture ..
            "' geradas! (Modo: " .. mode .. ")"
    end,
})



-- Função auxiliar para coletar todas as texturas registradas no jogo
local function get_all_textures()
    local textures = {}
    
    -- 1. Coletar texturas de todos os itens e nós registrados
    for name, def in pairs(minetest.registered_items) do
        -- Texturas de inventário
        if def.inventory_image and def.inventory_image ~= "" then
            textures[def.inventory_image] = true
        end
        -- Texturas de tiles (para nós)
        if def.tiles then
            for _, tile in ipairs(def.tiles) do
                local tile_name = type(tile) == "table" and tile.name or tile
                if type(tile_name) == "string" and tile_name ~= "" then
                    textures[tile_name] = true
                end
            end
        end
        -- Texturas especiais
        if def.special_tiles then
            for _, tile in ipairs(def.special_tiles) do
                local tile_name = type(tile) == "table" and tile.name or tile
                if type(tile_name) == "string" and tile_name ~= "" then
                    textures[tile_name] = true
                end
            end
        end
    end

    -- 2. Coletar texturas de entidades registradas
    for name, def in pairs(minetest.registered_entities) do
        if def.initial_properties and def.initial_properties.textures then
            for _, tex in ipairs(def.initial_properties.textures) do
                if type(tex) == "string" and tex ~= "" then
                    textures[tex] = true
                end
            end
        end
    end

    -- Converter o set em uma lista ordenada
    local list = {}
    for tex in pairs(textures) do
        -- Limpar modificadores de textura (ex: [combine, ^, etc) para busca mais limpa
        local base_tex = tex:split("^")[1]:split("[")[1]
        if base_tex ~= "" then
            list[base_tex] = true
        end
    end
    
    local final_list = {}
    for tex in pairs(list) do
        table.insert(final_list, tex)
    end
    table.sort(final_list)
    return final_list
end

minetest.register_chatcommand("particle_search", {
    params = "<termo>",
    description = "Lista texturas registradas que podem ser usadas como partículas",
    privs = {server = true},
    func = function(name, param)
        if param == "" then
            return false, "Uso: /particle_search <termo>"
        end
        
        local search = param:lower()
        local all_textures = get_all_textures()
        local found = {}
        
        for _, tex in ipairs(all_textures) do
            if tex:lower():find(search, 1, true) then
                table.insert(found, tex)
            end
        end
        
        if #found == 0 then
            return false, "Nenhuma textura encontrada contendo: " .. param
        end
        
        -- Limitar a exibição se houver muitos resultados para não travar o chat
        local max_display = 50
        local output = "✨ Texturas contendo '" .. param .. "':\n"
        for i = 1, math.min(#found, max_display) do
            output = output .. found[i] .. (i == #found and "" or ", ")
        end
        
        if #found > max_display then
            output = output .. "\n... e mais " .. (#found - max_display) .. " resultados."
        end
        
        minetest.chat_send_player(name, output)
        return true
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
