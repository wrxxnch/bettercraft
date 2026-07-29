-- Tabela global para salvar resultados da busca por jogador
local summon_search_results = {}

-- =========================
-- FUNÇÕES AUXILIARES
-- =========================

local function parse_pos(player, x, y, z)
    local ppos = player:get_pos()
    local look = player:get_look_dir()
    local right = vector.normalize({ x = look.z, y = 0, z = -look.x })
    local up = { x = 0, y = 1, z = 0 }

    local function parse(comp, base, axis)
        if comp:sub(1, 1) == "~" then
            local num = tonumber(comp:sub(2)) or 0
            return base + num
        elseif comp:sub(1, 1) == "^" then
            local num = tonumber(comp:sub(2)) or 0
            if axis == "x" then return vector.multiply(right, num)
            elseif axis == "y" then return vector.multiply(up, num)
            elseif axis == "z" then return vector.multiply(look, num) end
        else
            return tonumber(comp)
        end
    end

    local caret_x = x:sub(1, 1) == "^"
    local caret_y = y:sub(1, 1) == "^"
    local caret_z = z:sub(1, 1) == "^"

    if caret_x or caret_y or caret_z then
        if not (caret_x and caret_y and caret_z) then
            return nil, "Não misture ^ com ~ ou coordenadas absolutas."
        end
        local vx = parse(x, 0, "x")
        local vy = parse(y, 0, "y")
        local vz = parse(z, 0, "z")
        return vector.round(vector.add(ppos, vector.add(vx, vector.add(vy, vz)))), nil
    end

    local px = parse(x, ppos.x)
    local py = parse(y, ppos.y)
    local pz = parse(z, ppos.z)

    if not (px and py and pz) then return nil, "Coordenada inválida." end
    return { x = px, y = py, z = pz }, nil
end

local function looks_like_coord(token)
    if not token then return false end
    local first = token:sub(1, 1)
    return first == "~" or first == "^" or tonumber(token) ~= nil
end

-- Resolve o nome do item tentando vários prefixos comuns do BetterCraft/MineClone
local function resolve_item_name(item)
    if minetest.registered_items[item] then return item end
    
    -- Se já tem prefixo e não existe, erro
    if item:find(":") then return nil, "Item não existe: " .. item end

    local prefixes = {"mcl_tools", "mcl_core", "mcl_items", "mcl_farming", "mcl_mobitems", "mcl_bows"}
    for _, pref in ipairs(prefixes) do
        local full = pref .. ":" .. item
        if minetest.registered_items[full] then return full end
    end

    -- Busca parcial se nada foi encontrado
    local suffix = ":" .. item
    for name in pairs(minetest.registered_items) do
        if name:sub(-#suffix) == suffix then return name end
    end

    return nil, "Item '" .. item .. "' não encontrado."
end

-- =========================
-- COMANDOS DE BUSCA
-- =========================

minetest.register_chatcommand("summon_search", {
    params = "[filtro]",
    description = "Procura entidades registradas",
    privs = { server = true },
    func = function(name, param)
        local filter = param:lower()
        local list = {}
        for entname in pairs(minetest.registered_entities) do
            if filter == "" or entname:lower():find(filter, 1, true) then
                table.insert(list, entname)
            end
        end
        table.sort(list)
        if #list == 0 then return false, "Nada encontrado." end
        summon_search_results[name] = list
        local text = "Resultados:\n"
        for i = 1, math.min(#list, 50) do text = text .. i .. ": " .. list[i] .. "\n" end
        minetest.chat_send_player(name, text .. "Use: /summon_pick <num>")
        return true
    end
})

minetest.register_chatcommand("summon_pick", {
    params = "<numero> [args]",
    description = "Seleciona entidade da busca",
    privs = { server = true },
    func = function(name, param)
        local numstr, argstr = param:match("^(%S+)%s*(.*)$")
        local list = summon_search_results[name]
        if not list or not tonumber(numstr) then return false, "Use /summon_search primeiro." end
        local entname = list[tonumber(numstr)]
        if not entname then return false, "Número inválido." end
        return minetest.registered_chatcommands["summon"].func(name, entname .. " " .. (argstr or ""))
    end
})

-- =========================
-- COMANDO SUMMON (FIXED)
-- =========================

minetest.register_chatcommand("summon", {
    params = "<mob> [x y z] [args]",
    description = "Invoca um mob. Ex: /summon zombie ~ ~ ~ hand=diamond_sword,size=2,name=Gigante",
    privs = { server = true },
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player or param == "" then return false, "Uso: /summon <mob> [x y z] [args]" end

        local parts = {}
        for w in param:gmatch("%S+") do table.insert(parts, w) end

        local mobname = parts[1]
        if not mobname:find(":") then mobname = "mobs_mc:" .. mobname end

        local pos, err
        local argstart = 2
        if looks_like_coord(parts[2]) and looks_like_coord(parts[3]) and looks_like_coord(parts[4]) then
            pos, err = parse_pos(player, parts[2], parts[3], parts[4])
            if err then return false, err end
            argstart = 5
        else
            pos = vector.round(player:get_pos())
            pos.y = pos.y + 1
        end

        local obj = minetest.add_entity(pos, mobname)
        if not obj then return false, "Falha ao spawnar: " .. mobname end

        local mob = obj:get_luaentity()
        if not mob then 
            obj:remove() 
            return false, "Entidade inválida." 
        end

        -- Parse de Argumentos
        local args = {}
        for i = argstart, #parts do
            for token in (parts[i] .. ","):gmatch("([^,]+),") do
                local k, v = token:match("^([^=]+)=?(.*)$")
                if k then
                    v = v:trim()
                    if v == "" or v == "true" then v = true
                    elseif v == "false" then v = false
                    elseif tonumber(v) then v = tonumber(v) end
                    args[k:trim()] = v
                end
            end
        end

        -- APLICAR SIZE / SCALE (FIX)
        local scale = args.size or args.scale
        if scale then
            local s = tonumber(scale)
            -- Para mobs do MineClone, precisamos atualizar o base_visual_size
            -- caso contrário eles resetam o tamanho ao caminhar/mudar de estado.
            mob.base_visual_size = { x = s, y = s }
            obj:set_properties({
                visual_size = { x = s, y = s, z = s }
            })
        end

        -- APLICAR HAND / ITEM (FIX)
        if args.hand then
            local item, ierr = resolve_item_name(tostring(args.hand))
            if item then
                mob.wield_item = item
                obj:set_properties({ wield_item = item })
            else
                minetest.chat_send_player(name, "Aviso: " .. ierr)
            end
        end

        -- Vida e Atributos
        if args.hp_max then mob.hp_max = args.hp_max end
        if args.hp then
            mob.health = math.min(args.hp, mob.hp_max or args.hp)
            obj:set_hp(mob.health)
        end
        
        if args.name then
            mob.nametag = args.name
            obj:set_properties({ nametag = args.name, nametag_color = "white" })
        end

        -- Child (Bebê)
        if args.child ~= nil then
            mob.child = (args.child == true)
            if mob.child then
                local s = (mob.base_visual_size and mob.base_visual_size.x or 1) * 0.5
                obj:set_properties({ visual_size = { x = s, y = s, z = s } })
            end
        end

        -- Equipamento
        if args.helmet then mob.armor_head = args.helmet end
        if args.chestplate then mob.armor_torso = args.chestplate end
        if args.leggings then mob.armor_legs = args.leggings end
        if args.boots then mob.armor_feet = args.boots end

        -- Comportamento e Outros
        if args.owner then mob.owner = args.owner; mob.tamed = true end
        if args.tamed ~= nil then mob.tamed = args.tamed end
        if args.glow then obj:set_properties({ glow = args.glow }) end
        if args.passive ~= nil then mob.passive = args.passive end
        if args.damage then mob.damage = args.damage end
        if args.view_range then mob.view_range = args.view_range end

        -- Forçar atualização visual do mob_class
        if mob.on_spawn then mob:on_spawn() end

        return true, "Mob '" .. mobname .. "' spawnado em " .. minetest.pos_to_string(pos)
    end
})