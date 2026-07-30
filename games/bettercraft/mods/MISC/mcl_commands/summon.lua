-- Tabela global para salvar resultados da busca por jogador
local summon_search_results = {}

-- =========================
-- PERSISTÊNCIA DE ESCALA CUSTOMIZADA (scale=)
-- ----------------------------------------------------------------
-- Baseado no código real de games/bettercraft/mods/ENTITIES/mcl_mobs
-- (api.lua): não existe uma função genérica de "set_scale" -- só
-- `scale_size_of_child`, amarrada à flag `child`. Quando um mob
-- recarrega (mob_activate), `self.collisionbox` é resetado
-- incondicionalmente pro valor original (api.lua linha ~390), então
-- uma escala customizada por /summon precisa ser REAPLICADA a cada
-- reativação, senão ela se perde ao se afastar e voltar.
--
-- Isso estende mcl_mobs.mob_class com um método de escala genérico
-- e "envolve" mob_activate pra reaplicar a escala salva (_custom_scale)
-- depois que a ativação padrão terminar.
-- =========================
local mob_class = mcl_mobs and mcl_mobs.mob_class

if mob_class then
    function mob_class:mcl_summon_apply_scale(scale)
        if not (self.base_colbox and self.base_selbox and self.base_size) then
            return -- ainda não inicializado (não deveria acontecer pós-ativação)
        end

        local collisionbox = {
            self.base_colbox[1] * scale, self.base_colbox[2] * scale, self.base_colbox[3] * scale,
            self.base_colbox[4] * scale, self.base_colbox[5] * scale, self.base_colbox[6] * scale,
        }
        self.collisionbox = collisionbox

        self:set_properties({
            visual_size = { x = self.base_size.x * scale, y = self.base_size.y * scale },
            collisionbox = collisionbox,
            selectionbox = {
                self.base_selbox[1] * scale, self.base_selbox[2] * scale, self.base_selbox[3] * scale,
                self.base_selbox[4] * scale, self.base_selbox[5] * scale, self.base_selbox[6] * scale,
            },
        })
    end

    local original_mob_activate = mob_class.mob_activate
    function mob_class:mob_activate(staticdata, dtime)
        local ret = original_mob_activate(self, staticdata, dtime)
        -- `ret == false` significa que a ativação abortou (mob removido);
        -- não faz sentido reaplicar nada nesse caso.
        if ret == false then
            return ret
        end
        if self._custom_scale and self._custom_scale ~= 1 then
            self:mcl_summon_apply_scale(self._custom_scale)
        end
        return ret
    end
else
    minetest.log("warning", "[summon] mcl_mobs.mob_class não encontrado -- "
        .. "scale= não vai persistir entre recarregamentos do mob. "
        .. "Verifique se este arquivo carrega DEPOIS do mcl_mobs (depends).")
end

-- =========================
-- PARSER DE COORDENADAS ESTILO MINECRAFT (Função 1 -- NÃO USADA)
-- Mantida aqui só porque já existia no arquivo original; nenhum
-- comando abaixo chama parse_coordinates/parse_coord_component.
-- A função realmente usada é `parse_pos`, mais abaixo.
-- Pode remover esse bloco com segurança se não usar em outro lugar.
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
-- Retorna: pos, err -- se `err` não for nil, `pos` é nil e o comando
-- deve abortar mostrando `err` pro jogador.
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

    -- Coordenadas locais (^): assim como no Minecraft, não dá pra
    -- misturar ^ com ~ ou coordenadas absolutas no mesmo comando --
    -- as três precisam usar ^. Antes essa mistura era aceita e
    -- gerava uma posição errada silenciosamente (ex: "~5 ^ ^" somava
    -- 5 em todos os eixos ao invés de só no X).
    local caret_x = x:sub(1, 1) == "^"
    local caret_y = y:sub(1, 1) == "^"
    local caret_z = z:sub(1, 1) == "^"

    if caret_x or caret_y or caret_z then
        if not (caret_x and caret_y and caret_z) then
            return nil, "Não é possível misturar coordenadas locais (^) com "
                .. "~ ou coordenadas absolutas. Use ^ nas três (ex: ^ ^ ^3)."
        end

        local vx = parse(x, 0, "x")
        local vy = parse(y, 0, "y")
        local vz = parse(z, 0, "z")
        local result = vector.add(ppos, vx)
        result = vector.add(result, vy)
        result = vector.add(result, vz)
        return vector.round(result), nil
    end

    -- Absoluto ou relativo ~
    local px = parse(x, ppos.x)
    local py = parse(y, ppos.y)
    local pz = parse(z, ppos.z)

    if not (px and py and pz) then
        return nil, "Coordenada inválida (use números, ~ ou ^)."
    end

    return { x = px, y = py, z = pz }, nil
end

-- Um token "parece" coordenada se começar com ~ ou ^, ou for um
-- número puro. Usado pra decidir se x/y/z foram realmente passados,
-- em vez de confundir args do tipo "hp=10" com coordenadas.
local function looks_like_coord(token)
    if not token then
        return false
    end
    local first = token:sub(1, 1)
    return first == "~" or first == "^" or tonumber(token) ~= nil
end

-- Resolve um nome de item digitado sem o prefixo do mod (ex:
-- "diamond_sword") para o nome completo registrado (ex:
-- "mcl_tools:diamond_sword"). Antes, "hand=" assumia sempre o
-- prefixo "mcl_core:", que está errado pra maioria das ferramentas/
-- armas (elas ficam em mcl_tools, mcl_bows, mcl_farming etc.).
-- Retorna: nome_resolvido, erro
local function resolve_item_name(item)
    if minetest.registered_items[item] then
        return item, nil
    end

    local suffix = ":" .. item
    local matches = {}
    for itemname in pairs(minetest.registered_items) do
        if itemname:sub(-#suffix) == suffix then
            table.insert(matches, itemname)
        end
    end

    if #matches == 1 then
        return matches[1], nil
    elseif #matches > 1 then
        table.sort(matches)
        return nil, "Item ambíguo: " .. item .. " (encontrado em: "
            .. table.concat(matches, ", ") .. "). Use o nome completo com o prefixo do mod."
    else
        return nil, "Item desconhecido: " .. item
    end
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
    description = table.concat({
        "Invoca um mob com coordenadas e parâmetros.",
        "Coordenadas: absolutas (10 20 30), relativas (~ ~5 ~) ou locais (^ ^ ^3) -- não misture estilos.",
        "Args (chave=valor, separados por espaço ou vírgula; use sempre '=' mesmo pra texto, ex: name=Bob):",
        "  Vida: hp, hp_max, breath, breath_max",
        "  Visual: name, glow, scale (persiste ao recarregar), child (true/false)",
        "  Equipamento: hand (só funciona se o mob puder segurar itens), helmet, chestplate, leggings, boots",
        "  Montaria: ride=<mob_proximo> (monta em cima de um mob já spawnado, no raio de 3 nodes)",
        "  Comportamento: passive, retaliates, docile_by_day (ou day_docile), persistent, persist_in_peaceful, owner, tamed, order",
        "  Combate: damage, reach, knock_back, armor",
        "  Movimento: walk_velocity, run_velocity, jump, jump_height, stepheight, fly, swims, floats, view_range",
        "  Ambiente: water_damage, lava_damage, fire_damage, light_damage, suffocation, fall_damage, fear_height, ignited_by_sunlight=false",
        "Ex: /summon creeper ~ ~10 ~ hp=100,name=Bob",
    }, "\n"),
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

        -- Detectar se coordenadas foram fornecidas: os TRÊS tokens
        -- seguintes precisam parecer coordenada, não só o primeiro
        -- (antes, "/summon zombie ~5 hp=10 name=Bob" tentava tratar
        -- "hp=10" e "name=Bob" como Y e Z).
        if looks_like_coord(parts[2]) and looks_like_coord(parts[3]) and looks_like_coord(parts[4]) then
            local err
            pos, err = parse_pos(player, parts[2], parts[3], parts[4])
            if err then
                return false, err
            end
            argstart = 5
        end

        -- Se 'pos' não foi definido (nenhuma coordenada foi passada), usa a posição do jogador como padrão
        if not pos then
            pos = vector.round(player:get_pos())
            pos.y = pos.y + 1
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
        -- ----------------------------------------------------------
        -- Cada `parts[i]` (a partir de argstart) já veio separado por
        -- espaço; splitamos cada um também por vírgula, pra aceitar
        -- tanto "hp=100 name=Bob" quanto "hp=100,name=Bob".
        -- (Antes: os parts eram rejuntados com ESPAÇO e depois
        -- splitados por VÍRGULA -- sem vírgula no comando, tudo virava
        -- um token só e o valor do primeiro `arg` engolia o resto.)
        -- =========================
        local args = {}
        for i = argstart, #parts do
            for token in (parts[i] .. ","):gmatch("([^,]+),") do
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

        -- hp_max precisa ser aplicado ANTES de hp, senão "hp=50 hp_max=100"
        -- no mesmo comando clampava o hp usando o hp_max antigo.
        if args.hp_max then mob.hp_max = args.hp_max end
        if args.hp then
            mob.health = math.min(args.hp, mob.hp_max or args.hp)
            obj:set_hp(mob.health)
        end
        if args.breath then mob.breath = args.breath end
        if args.breath_max then mob.breath_max = args.breath_max end

        -- name= precisa ser texto. Antes, "name" digitado sem "=valor"
        -- virava `true` (booleano) no parser de args, e isso quebrava
        -- `mob_class:update_tag()` (Invalid field nametag, expected
        -- string got boolean) -- erro que interrompia o resto da
        -- reativação do mob e fazia ele "esquecer" as outras
        -- propriedades quando você se afastava e voltava.
        if args.name then
            if type(args.name) == "string" then
                mob.nametag = args.name
                mob:update_tag() -- forma oficial: chama set_properties({nametag=...}) por baixo
            else
                minetest.chat_send_player(name, "name= precisa de um texto (ex: name=Bob). Ignorado.")
            end
        end
        if args.glow then
            obj:set_properties({ glow = args.glow })
        end

        -- hand= precisa usar mob_class:set_wielditem(), não
        -- set_properties no objeto principal do mob. O item exibido
        -- na mão é uma ENTIDADE FILHA separada ("mcl_mobs:wielditem",
        -- ver combat.lua), controlada só por essa função -- setar uma
        -- propriedade no mob em si não tem efeito nenhum na visual.
        -- Só funciona se o mob tiver `can_wield_items = true`
        -- (a maioria dos animais não tem).
        if args.hand then
            if type(args.hand) ~= "string" then
                minetest.chat_send_player(name, "hand= precisa de um nome de item (ex: hand=diamond_sword). Ignorado.")
            elseif not mob.can_wield_items then
                minetest.chat_send_player(name, mobname .. " não consegue segurar itens (can_wield_items = false).")
            else
                local item, err = resolve_item_name(args.hand)
                if item then
                    mob:set_wielditem(ItemStack(item))
                else
                    minetest.chat_send_player(name, err)
                end
            end
        end

        if args.helmet then mob.armor_head = args.helmet end
        if args.chestplate then mob.armor_torso = args.chestplate end
        if args.leggings then mob.armor_legs = args.leggings end
        if args.boots then mob.armor_feet = args.boots end

        if args.ride then
            if type(args.ride) ~= "string" then
                minetest.chat_send_player(name, "ride= precisa do nome de um mob (ex: ride=horse). Ignorado.")
            else
                local ridename = args.ride
                if not ridename:find(":") then ridename = "mobs_mc:" .. ridename end
                local radius = 3
                local objs = minetest.get_objects_inside_radius(pos, radius)

                -- Escolhe o mob compatível MAIS PRÓXIMO, não o primeiro
                -- encontrado (a ordem de minetest.get_objects_inside_radius
                -- não é garantida).
                local vehicle, vehicle_dist
                for _, o in ipairs(objs) do
                    if o ~= obj then
                        local ent = o:get_luaentity()
                        if ent and ent.name == ridename then
                            local d = vector.distance(pos, o:get_pos())
                            if not vehicle_dist or d < vehicle_dist then
                                vehicle, vehicle_dist = o, d
                            end
                        end
                    end
                end

                if vehicle then
                    obj:set_attach(vehicle, "", { x = 0, y = 10, z = 0 }, { x = 0, y = 0, z = 0 })
                    mob.riding = true
                    -- Nome de campo alinhado com o resto do mod: o
                    -- despawn (`mob_class:kill_me`) já verifica
                    -- `_jockey_rider` na montaria pra desmontar o
                    -- passageiro automaticamente quando ela morre. Sem
                    -- isso, o "ride=" daqui ficava fora desse sistema.
                    mob.jockey_vehicle = vehicle
                    local vehicle_ent = vehicle:get_luaentity()
                    if vehicle_ent then
                        vehicle_ent._jockey_rider = obj
                    end
                else
                    minetest.chat_send_player(name, "Nenhum mob '" .. ridename
                        .. "' encontrado num raio de " .. radius .. " nodes pra montar.")
                end
            end
        end

        -- child= usava `mob.base_visual_size`, campo que não existe
        -- no código real (o certo é `mob.base_size`) -- então a
        -- escala visual do filhote nunca acontecia, só a flag. Agora
        -- chama o método real do mod (combat.lua/api.lua já cuidam de
        -- reaplicar isso sozinhos em toda reativação, então nem
        -- precisa do nosso hook de persistência aqui).
        if args.child ~= nil then
            mob.child = (args.child == true)
            if mob.child and mob.scale_size_of_child then
                mob:scale_size_of_child(0.5)
            end
        end

        -- scale= agora usa a função de escala persistente definida no
        -- topo do arquivo (mcl_summon_apply_scale), que também fica
        -- guardada em `_custom_scale` e é reaplicada sozinha a cada
        -- vez que o mob recarrega (ver o "wrap" de mob_activate).
        if args.scale then
            local s = tonumber(args.scale)
            if s and s > 0 then
                if mob.mcl_summon_apply_scale then
                    mob._custom_scale = s
                    mob:mcl_summon_apply_scale(s)
                else
                    -- fallback caso o hook não tenha carregado por algum motivo
                    obj:set_properties({ visual_size = { x = s, y = s } })
                end
            else
                minetest.chat_send_player(name, "scale= precisa ser um número maior que 0. Ignorado.")
            end
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
            if type(args.owner) == "string" then
                mob.owner = args.owner
                mob.tamed = true
            else
                minetest.chat_send_player(name, "owner= precisa de um texto (nome do jogador). Ignorado.")
            end
        end
        if args.tamed ~= nil then mob.tamed = args.tamed end
        if args.order then
            if type(args.order) == "string" then
                mob.order = args.order
            else
                minetest.chat_send_player(name, "order= precisa de um texto (ex: order=stand). Ignorado.")
            end
        end

        if mob.on_spawn then
            mob:on_spawn()
        end

        return true, "Mob spawnado: " .. mobname .. " em " .. minetest.pos_to_string(pos)
    end
})
