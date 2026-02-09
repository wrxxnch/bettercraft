-- Mineclonia Commands Mod
-- Implementa autocomplete, coordenadas relativas (~, ^) e comandos execute, particle, testfor, testforblock, setblock

local modname = minetest.get_current_modname()

-- Registro manual de partículas conhecidas
local registered_particles = {}

local function set_commandblock_result(success)
	local pos = core.commandblock_pos
	if not pos then return end

	local meta = core.get_meta(pos)
	meta:set_int("comparator_power", success and 15 or 0)
	mcl_redstone.update_comparators(pos)
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


local function normalize_texture(name)
    if not name or name == "" then return nil end
    if not name:find("%.png$") then
        name = name .. ".png"
    end
    return name
end

local function parse_pos(str)
	local x,y,z = str:match("^(-?%d+),(-?%d+),(-?%d+)$")
	if not x then return nil end
	return {x=tonumber(x), y=tonumber(y), z=tonumber(z)}
end

local function distance(a, b)
	return vector.distance(a, b)
end

local function entity_matches(obj, filters)
	local lua = obj:get_luaentity()
	if not lua then return false end

	-- type
	if filters.type and lua.name ~= filters.type then
		return false
	end

	-- name / nametag
	if filters.name or filters.nametag then
		local tag = lua.nametag or ""
		if filters.name and tag ~= filters.name then
			return false
		end
		if filters.nametag and not tag:find(filters.nametag, 1, true) then
			return false
		end
	end

	-- radius
	if filters.center and filters.radius then
		if distance(obj:get_pos(), filters.center) > filters.radius then
			return false
		end
	end

	-- area (intervalo)
	if filters.pos1 and filters.pos2 then
		local p = obj:get_pos()
		if not (
			p.x >= filters.pos1.x and p.x <= filters.pos2.x and
			p.y >= filters.pos1.y and p.y <= filters.pos2.y and
			p.z >= filters.pos1.z and p.z <= filters.pos2.z
		) then
			return false
		end
	end

	return true
end

local function parse_testfor_args(param)
	local filters = {}

	-- @e[...]
	local inside = param:match("^@e%[(.+)%]$")
	if inside then
		for pair in inside:gmatch("[^,]+") do
			local k,v = pair:match("([^=]+)=([^=]+)")
			if k and v then filters[k] = v end
		end
	else
		-- formato solto: key=value key=value
		for pair in param:gmatch("%S+") do
			local k,v = pair:match("([^=]+)=([^=]+)")
			if k and v then filters[k] = v end
		end
	end

	-- pos
	if filters.pos then
		local parts = {}
		for n in filters.pos:gmatch("[^,]+") do table.insert(parts, n) end

		if #parts == 3 then
			filters.center = parse_pos(filters.pos)
		elseif #parts == 6 then
			filters.pos1 = {
				x = tonumber(parts[1]), y = tonumber(parts[2]), z = tonumber(parts[3])
			}
			filters.pos2 = {
				x = tonumber(parts[4]), y = tonumber(parts[5]), z = tonumber(parts[6])
			}
		end
	end

	-- radius
	if filters.r or filters.radius then
		filters.radius = tonumber(filters.r or filters.radius)
	end

	return filters
end



minetest.register_chatcommand("particle", {
    params = "<textura> [args...] ",
    description = "Particle (coords, sphere, hollow, distance, static/falling/floating) summon particles,particles inside textures are not listed by particle_search but you can use on particle command,example:/particle heart.png floating",
     privs = {server = true},
    func = function(name, param)
        local args = param:split(" ")
        if #args == 0 then
            return false, "Uso: /particle <textura> [args]"
        end

        local player = minetest.get_player_by_name(name)
        if not player then return false end

        -- TEXTURA
        local texture = normalize_texture(table.remove(args,1))
        if not texture then
            return false, "Textura inválida"
        end

        -- DEFAULTS
        local cfg = {
            mode = "static",
            shape = "point",
            hollow = false,
            radius = 3,
            size = 4,
            count = 30,
            spread = 0.3,
            seed = os.time(),
        }

        -- PARSE KEY=VALUE + FLAGS
        local i = 1
        while i <= #args do
            local a = args[i]:lower()

            if a == "floating" or a == "falling" or a == "static" then
                cfg.mode = a
                table.remove(args,i)

            elseif a == "hollow" then
                cfg.hollow = true
                table.remove(args,i)

            elseif a:match("^sphere=") then
                cfg.shape = "sphere"
                cfg.radius = tonumber(a:match("sphere=(.+)")) or cfg.radius
                table.remove(args,i)

            elseif a == "sphere" then
                cfg.shape = "sphere"
                table.remove(args,i)

            elseif a:match("^size=") then
                cfg.size = tonumber(a:match("size=(.+)")) or cfg.size
                table.remove(args,i)

            elseif a:match("^count=") then
                cfg.count = tonumber(a:match("count=(.+)")) or cfg.count
                table.remove(args,i)

            elseif a:match("^spread=") then
                cfg.spread = tonumber(a:match("spread=(.+)")) or cfg.spread
                table.remove(args,i)

            elseif a:match("^seed=") then
                cfg.seed = tonumber(a:match("seed=(.+)")) or cfg.seed
                table.remove(args,i)

            else
                i = i + 1
            end
        end

        -- POSIÇÃO
        local pos = parse_pos(args, player)

        math.randomseed(cfg.seed)

        -- MOVIMENTO
        local vel, acc, collision = vector.zero(), vector.zero(), false

        if cfg.mode == "falling" then
            vel = {x=0,y=1,z=0}
            acc = {x=0,y=-9.8,z=0}
            collision = true
        elseif cfg.mode == "floating" then
            vel = {x=0,y=1,z=0}
            acc = {x=0,y=0.3,z=0}
        end

        -- SPAWN
        if cfg.shape == "sphere" then
            for x=-cfg.radius,cfg.radius do
                for y=-cfg.radius,cfg.radius do
                    for z=-cfg.radius,cfg.radius do
                        local d = math.sqrt(x*x+y*y+z*z)
                        if d <= cfg.radius and (not cfg.hollow or d >= cfg.radius-1) then
                            minetest.add_particle({
                                pos = vector.add(pos,{x=x,y=y,z=z}),
                                velocity = vel,
                                acceleration = acc,
                                expirationtime = 4,
                                size = cfg.size,
                                texture = texture,
                                collisiondetection = collision,
                                glow = 10,
                            })
                        end
                    end
                end
            end
        else
            minetest.add_particlespawner({
                amount = cfg.count,
                time = 0.1,
                minpos = vector.subtract(pos, cfg.spread),
                maxpos = vector.add(pos, cfg.spread),
                minvel = vel,
                maxvel = vel,
                minacc = acc,
                maxacc = acc,
                minsize = cfg.size,
                maxsize = cfg.size,
                texture = texture,
                collisiondetection = collision,
                glow = 10,
            })
        end

        return true, "Particle "..texture.." criado!"
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
	params = "@e[...] | filtros",
	description = "Testa entidades por filtros",
	privs = { server = true },

	func = function(name, param)
		if param == "" then
			set_commandblock_result(false)
			return false, "Filtros não especificados"
		end

		local filters = parse_testfor_args(param)
		local objects = minetest.get_objects_inside_radius(
			filters.center or {x=0,y=0,z=0},
			filters.radius or 32768
		)

		for _, obj in ipairs(objects) do
			if entity_matches(obj, filters) then
				set_commandblock_result(true)
				return true, "Entidade encontrada"
			end
		end

		set_commandblock_result(false)
		return false, "Nenhuma entidade encontrada"
	end,
})



-- Comando: /testforblock <pos> <node_name>
minetest.register_chatcommand("testforblock", {
	params = "<x> <y> <z> <node>",
	description = "Testa se um bloco é de um tipo específico",
	privs = { server = true },

	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			set_commandblock_result(false)
			return false, "Jogador inválido"
		end

		local args = param:split(" ")
		local pos, rest = get_pos_from_args(args, player)
		local nodename = rest and rest[1]

		if not pos or not nodename then
			set_commandblock_result(false)
			return false, "Argumentos inválidos"
		end

		local node = minetest.get_node(pos)
		local success = node.name == nodename
		set_commandblock_result(success)

		if success then
			return true, "Bloco "..nodename.." encontrado"
		else
			return false, "Encontrado "..node.name
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
