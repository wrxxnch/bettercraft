-- Tabela global para salvar resultados da busca por jogador
local summon_search_results = {}

-- =========================
-- PARSER DE COORDENADAS ESTILO MINECRAFT (Função 1)
-- Esta função parece ser uma versão mais antiga ou alternativa.
-- A função parse_pos (abaixo) é a que está sendo usada no comando summon.
-- =========================
local function parse_coord_component(comp, base, dir, right, up)
    if comp:sub(1, 1) == "~" then
        local offset = tonumber(comp:sub(2)) or 0
        return base + offset
    elseif comp:sub(1, 1) == "^" then
        local offset = tonumber(comp:sub(2)) or 0
        return {
            type = "local",
            value = offset
        }
    else
        return tonumber(comp)
    end
end

local function parse_coordinates(player, x, y, z)
    local pos = player:get_pos()
    local base = vector.round(pos)
    local look = player:get_look_dir()
    local right = vector.cross(look, { x = 0, y = 1, z = 0 })
    local up = { x = 0, y = 1, z = 0 }

    local cx = parse_coord_component(x, base.x)
    local cy = parse_coord_component(y, base.y)
    local cz = parse_coord_component(z, base.z)

    -- Coordenadas locais ^
    if type(cx) == "table" or type(cy) == "table" or type(cz) == "table" then
        local lx = type(cx) == "table" and cx.value or 0
        local ly = type(cy) == "table" and cy.value or 0
        local lz = type(cz) == "table" and cz.value or 0
        local result = vector.add(pos, vector.add(vector.multiply(right, lx),
            vector.add(vector.multiply(up, ly), vector.multiply(look, lz))))
        return vector.round(result)
    end

    return { x = cx, y = cy, z = cz }
end

-- =========================
-- PARSER DE COORDENADAS ESTILO MINECRAFT (Função 2 - Usada no comando)
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
            if axis == "x" then
                return vector.multiply(right, num)
            elseif axis == "y" then
                return vector.multiply(up, num)
            elseif axis == "z" then
                return vector.multiply(look, num)
            end
        else
            return tonumber(comp)
        end
    end

    -- Se usar ^
    if x:sub(1, 1) == "^" or y:sub(1, 1) == "^" or z:sub(1, 1) == "^" then
        local vx = parse(x, 0, "x")
        local vy = parse(y, 0, "y")
        local vz = parse(z, 0, "z")
        local result = vector.add(ppos, vx)
        result = vector.add(result, vy)
        result = vector.add(result, vz)
        return vector.round(result)
    end

    -- Absoluto ou relativo ~
    return {
        x = parse(x, ppos.x),
        y = parse(y, ppos.y),
        z = parse(z, ppos.z)
    }
end

-- =========================
-- COMANDO: /summon_search
-- =========================
minetest.register_chatcommand("summon_search", {
    params = "[filtro]",
    description = "Procura entidades registradas",
    privs = { server = true },
    func = function(name, param)
        local filter = param:lower()
        local list = {}
        for entname, def in pairs(minetest.registered_entities) do
            if filter == "" or entname:lower():find(filter, 1, true) then
                table.insert(list, entname)
            end
        end
        table.sort(list)

        if #list == 0 then
            return false, "Nenhuma entidade encontrada."
        end

        summon_search_results[name] = list
        local text = "Resultados (" .. #list .. "):\n"
        local max = math.min(#list, 50)
        for i = 1, max do
            text = text .. i .. ": " .. list[i] .. "\n"
        end
        if #list > max then
            text = text .. "... e mais " .. (#list - max)
        end
        text = text .. "\nUse: /summon_pick <num>"
        minetest.chat_send_player(name, text)
        return true, #list .. " entidades encontradas."
    end
})

-- =========================
-- COMANDO: /summon_pick
-- =========================
minetest.register_chatcommand("summon_pick", {
    params = "<numero> [args]",
    description = "Seleciona e invoca entidade da busca",
    privs = { server = true },
    func = function(name, param)
        local numstr, argstr = param:match("^(%S+)%s*(.*)$")
        local num = tonumber(numstr)
        if not num then
            return false, "Use: /summon_pick <numero> [args]"
        end

        local list = summon_search_results[name]
        if not list then
            return false, "Use /summon_search primeiro."
        end

        local entname = list[num]
        if not entname then
            return false, "Número inválido."
        end

        local cmd = entname
        if argstr and argstr ~= "" then
            cmd = cmd .. " " .. argstr
        end

        local def = minetest.registered_chatcommands["summon"]
        if not def then
            return false, "Comando summon não encontrado."
        end
        return def.func(name, cmd)
    end
})

-- =========================
-- COMANDO: /summon (VERSÃO CORRIGIDA)
-- =========================
minetest.register_chatcommand("summon", {
    params = "<mob> [x y z] [args]",
    description = "Invoca um mob com coordenadas e parâmetros (ex: /summon creeper ~ ~10 ~ hp=100)",
    privs = { server = true },
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Jogador não encontrado"
        end

        if param == "" then
            return false, "Uso: /summon <mob> [x y z] [args]"
        end

        local parts = {}
        for w in param:gmatch("%S+") do
            table.insert(parts, w)
        end

        local mobname = parts[1]
        local pos
        local argstart = 2 -- Onde os argumentos (hp=, etc.) começam

        -- Detectar se coordenadas foram fornecidas
        if parts[2] and parts[3] and parts[4] then
            -- Verifica se o segundo argumento parece ser uma coordenada
            if parts[2]:find("~") or parts[2]:find("%^") or tonumber(parts[2]) then
                -- Usa a sua função parse_pos para calcular a posição
                pos = parse_pos(player, parts[2], parts[3], parts[4])
                argstart = 5 -- Argumentos começarão depois das coordenadas
            end
        end

        -- Se 'pos' não foi definido (nenhuma coordenada foi passada), usa a posição do jogador como padrão
        if not pos then
            pos = vector.round(player:get_pos())
            pos.y = pos.y + 1
        end

        -- Reconstruir a string de argumentos (hp=, name=, etc.)
        local argstr = ""
        for i = argstart, #parts do
            argstr = argstr .. parts[i]
            if i < #parts then
                argstr = argstr .. " "
            end
        end

        -- Normaliza o nome do mob (igual ao Minecraft)
        if not mobname:find(":") then
            mobname = "mobs_mc:" .. mobname
        end

        -- Adiciona a entidade na posição correta ('pos' agora tem o valor certo)
        local obj = minetest.add_entity(pos, mobname)
        if not obj then
            return false, "Falha ao spawnar mob: " .. mobname
        end

        local mob = obj:get_luaentity()
        if not mob then
            obj:remove()
            return false, "Entidade não é um mob válido"
        end

        -- =========================
        -- Parse dos argumentos
        -- =========================
        local args = {}
        if argstr and argstr ~= "" then
            for token in argstr:gmatch("[^,]+") do
                local k, v = token:match("^([^=]+)=?(.*)$")
                if k then
                    k = k:trim()
                    v = v:trim()
                    if v == "" or v == "true" then
                        v = true
                    elseif v == "false" then
                        v = false
                    elseif tonumber(v) then
                        v = tonumber(v)
                    end
                    args[k] = v
                end
            end
        end

        -- =========================
        -- APLICAR FLAGS E ATRIBUTOS
        -- =========================

        if args.hp then
            mob.health = math.min(args.hp, mob.hp_max or args.hp)
            obj:set_hp(mob.health)
        end
        if args.hp_max then mob.hp_max = args.hp_max end
        if args.breath then mob.breath = args.breath end
        if args.breath_max then mob.breath_max = args.breath_max end

        if args.name then
            mob.nametag = args.name
            obj:set_properties({ nametag = args.name })
        end
        if args.glow then
            obj:set_properties({ glow = args.glow })
        end

        if args.hand then
            local item = args.hand
            if not item:find(":") then item = "mcl_core:" .. item end
            mob.wield_item = item
            obj:set_properties({ wield_item = item })
        end

        if args.helmet then mob.armor_head = args.helmet end
        if args.chestplate then mob.armor_torso = args.chestplate end
        if args.leggings then mob.armor_legs = args.leggings end
        if args.boots then mob.armor_feet = args.boots end

        if args.ride then
            local ridename = args.ride
            if not ridename:find(":") then ridename = "mobs_mc:" .. ridename end
            local radius = 3
            local objs = minetest.get_objects_inside_radius(pos, radius)
            for _, o in ipairs(objs) do
                if o ~= obj then
                    local ent = o:get_luaentity()
                    if ent and ent.name == ridename then
                        obj:set_attach(o, "", { x = 0, y = 10, z = 0 }, { x = 0, y = 0, z = 0 })
                        mob.riding = true
                        mob.rider = o
                        break
                    end
                end
            end
        end

        if args.child ~= nil then
            mob.child = (args.child == true)
            if mob.child and mob.base_visual_size then
                obj:set_properties({
                    visual_size = {
                        x = mob.base_visual_size.x * 0.5,
                        y = mob.base_visual_size.y * 0.5
                    }
                })
            end
        end
        if args.scale then
            local s = args.scale
            obj:set_properties({ visual_size = { x = s, y = s } })
        end

        if args.passive ~= nil then mob.passive = args.passive end
        if args.retaliates ~= nil then mob.retaliates = args.retaliates end
        if args.docile_by_day ~= nil then mob.docile_by_day = args.docile_by_day end
        if args.day_docile ~= nil then mob.docile_by_day = args.day_docile end
        if args.persistent ~= nil then mob.persistent = args.persistent end
        if args.persist_in_peaceful ~= nil then mob.persist_in_peaceful = args.persist_in_peaceful end

        if args.damage then mob.damage = args.damage end
        if args.reach then mob.reach = args.reach end
        if args.knock_back ~= nil then mob.knock_back = args.knock_back end
        if args.armor then mob.armor = args.armor end

        if args.walk_velocity then mob.walk_velocity = args.walk_velocity end
        if args.run_velocity then mob.run_velocity = args.run_velocity end
        if args.jump ~= nil then mob.jump = args.jump end
        if args.jump_height then mob.jump_height = args.jump_height end
        if args.stepheight then mob.stepheight = args.stepheight end
        if args.fly ~= nil then mob.fly = args.fly end
        if args.swims ~= nil then mob.swims = args.swims end
        if args.floats ~= nil then mob.floats = args.floats end
        if args.view_range then mob.view_range = args.view_range end

        if args.water_damage then mob.water_damage = args.water_damage end
        if args.lava_damage then mob.lava_damage = args.lava_damage end
        if args.fire_damage then mob.fire_damage = args.fire_damage end
        if args.light_damage then mob.light_damage = args.light_damage end
        if args.suffocation ~= nil then mob.suffocation = args.suffocation end
        if args.fall_damage ~= nil then mob.fall_damage = args.fall_damage end
        if args.fear_height then mob.fear_height = args.fear_height end

        if args.ignited_by_sunlight == false then
            mob.ignited_by_sunlight = false
            mob.sunlight_damage = 0
            if mob.extinguish then
                mob:extinguish()
            end
        end

        if args.owner then
            mob.owner = args.owner
            mob.tamed = true
        end
        if args.tamed ~= nil then mob.tamed = args.tamed end
        if args.order then mob.order = args.order end

        if mob.on_spawn then
            mob:on_spawn()
        end

        return true, "Mob spawnado: " .. mobname .. " em " .. minetest.pos_to_string(pos)
    end
})
