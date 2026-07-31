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

    -- =========================
    -- SLOTS CUSTOMIZADOS DE ITEM (head=, chest=, legs=, feet=)
    -- ----------------------------------------------------------------
    -- Diferente de hand= (que usa a API oficial do mod), estes slots
    -- não existem no mcl_mobs -- criamos nós, reaproveitando a mesma
    -- entidade "mcl_mobs:wielditem" já registrada (em combat.lua),
    -- só que anexada em outro osso/posição. Como o mod não sabe
    -- desses slots, cuidamos da persistência sozinhos: item + offset
    -- ficam em campos simples do mob (salvos automaticamente) e a
    -- entidade anexada é recriada em toda reativação (via o wrap de
    -- mob_activate, logo abaixo -- por isso este bloco precisa vir
    -- ANTES dele: em Lua, uma função não enxerga um `local` declarado
    -- depois dela no mesmo arquivo).
    -- =========================
    local CUSTOM_SLOTS = {
        head  = { bone = "head", position = { x = 0, y = 0.35, z = 0 } }, -- bone sobrescrito dinamicamente, ver mcl_summon_update_slot
        chest = { bone = "",     position = { x = 0, y = 0,     z = 0 } },
        legs  = { bone = "",     position = { x = 0, y = -0.3,  z = 0 } },
        feet  = { bone = "",     position = { x = 0, y = -0.6,  z = 0 } },
    }
    mcl_mobs._summon_custom_slots = CUSTOM_SLOTS

    function mob_class:mcl_summon_update_slot(slot_key)
        local def = CUSTOM_SLOTS[slot_key]
        if not def then
            return
        end

        local item_field = "_summon_" .. slot_key .. "_item"
        local obj_field = "_summon_" .. slot_key .. "_obj"
        local offset_field = "_summon_" .. slot_key .. "_offset"
        local item = self[item_field]

        if not item or item == "" then
            local existing = self[obj_field]
            if existing then
                existing:remove()
                self[obj_field] = nil
            end
            return
        end

        local existing = self[obj_field]
        local valid = existing and pcall(function() return existing:get_pos() end)
        if not valid then
            local self_pos = self.object:get_pos()
            existing = minetest.add_entity(self_pos, "mcl_mobs:wielditem")
            self[obj_field] = existing
        end

        -- O bone "Head" (maiúsculo) só existe em JOGADORES
        -- (mcl_armor/api.lua usa isso pra players). Em mobs, cada
        -- tipo tem seu próprio campo `_head_armor_bone` (minúsculo,
        -- ex: "head" -- ver skeleton+variants.lua, zombie.lua etc.).
        -- Mobs sem cabeça humanoide (lula, galinha) não têm esse
        -- campo -- nesse caso caímos pro bone "" (raiz do objeto).
        local bone = def.bone
        if slot_key == "head" then
            bone = self._head_armor_bone or "head"
        end

        local offset = self[offset_field] or { x = 0, y = 0, z = 0 }
        local pos = {
            x = def.position.x + offset.x,
            y = def.position.y + offset.y,
            z = def.position.z + offset.z,
        }

        existing:set_attach(self.object, bone, pos, { x = 0, y = 0, z = 0 })
        existing:set_properties({ wield_item = item, visual_size = { x = 0.4, y = 0.4 } })
    end

    local original_mob_activate = mob_class.mob_activate
    function mob_class:mob_activate(staticdata, dtime)
        -- Proteção defensiva: um mob já spawnado ANTES desta correção
        -- pode ter `nametag` salvo como booleano (bug antigo do
        -- parser de args). Isso crasha `original_mob_activate` (ele
        -- mesmo chama update_tag() -- api.lua:435) ANTES do nosso
        -- código abaixo rodar, então o mob nunca recupera as outras
        -- propriedades (scale, itens etc.) enquanto isso não for
        -- sanitizado aqui, no início, todo recarregamento.
        if self.nametag ~= nil and type(self.nametag) ~= "string" then
            self.nametag = nil
        end

        local ret = original_mob_activate(self, staticdata, dtime)
        -- `ret == false` significa que a ativação abortou (mob removido);
        -- não faz sentido reaplicar nada nesse caso.
        if ret == false then
            return ret
        end
        if self._custom_scale and self._custom_scale ~= 1 then
            self:mcl_summon_apply_scale(self._custom_scale)
        end
        for slot_key in pairs(CUSTOM_SLOTS) do
            if self["_summon_" .. slot_key .. "_item"] then
                self:mcl_summon_update_slot(slot_key)
            end
        end
        return ret
    end

    -- =========================
    -- NAMETAG INVISÍVEL (name_visible=false)
    -- ----------------------------------------------------------------
    -- `mob_class:get_nametag()` (api.lua:98) só retorna `self.nametag`.
    -- Pra esconder o texto SEM apagar o nome de verdade (outros
    -- comandos, tipo o de remover mobs "nametagged", checam
    -- `o.nametag` diretamente), guardamos uma flag separada
    -- (`_nametag_hidden`) e sobrescrevemos só o que é MOSTRADO.
    -- =========================
    local original_get_nametag = mob_class.get_nametag
    function mob_class:get_nametag()
        if self._nametag_hidden then
            return ""
        end
        return original_get_nametag(self)
    end

    -- =========================
    -- OFFSET DA MÃO (hand_offset=x:y:z)
    -- ----------------------------------------------------------------
    -- `mob_class:display_wielditem` (combat.lua:1111) é a função
    -- OFICIAL que posiciona o item da mão -- inclusive nossa
    -- `wielditem_info` de fallback. Envolvemos ela pra, depois da
    -- posição oficial calculada, somar um offset customizado por
    -- cima (guardado em `_hand_offset`).
    -- =========================
    local original_display_wielditem = mob_class.display_wielditem
    function mob_class:display_wielditem(offhand)
        original_display_wielditem(self, offhand)
        if offhand or not self._hand_offset then
            return
        end
        local info = self.wielditem_info
        local obj = self._wielditem_object
        if not (info and obj) then
            return
        end
        local ok = pcall(function() return obj:get_pos() end)
        if not ok then
            return -- objeto anexado inválido/removido
        end
        local stack = ItemStack(self._wielditem or "")
        if stack:is_empty() then
            return
        end
        local rot, pos = self:wielditem_transform(info, stack)
        local off = self._hand_offset
        local newpos = { x = pos.x + off.x, y = pos.y + off.y, z = pos.z + off.z }
        if not info.rotate_bone then
            obj:set_attach(self.object, info.bone, newpos, rot)
        else
            obj:set_attach(self.object, info.bone)
            mcl_util.set_bone_position(self.object, info.bone, newpos, rot)
        end
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

-- Faz o parse de um offset no formato "x:y:z" (DOIS-PONTOS, não
-- vírgula -- a vírgula já separa os args entre si, ex:
-- "hp=10,name=Bob", então "head_offset=1,2,3" quebraria o parser
-- geral de args). Componentes vazios (ex: "0::0") viram 0.
-- Retorna: {x=,y=,z=} ou nil, erro
local function parse_xyz_offset(text)
    local parts = {}
    for part in (text .. ":"):gmatch("([^:]*):") do
        table.insert(parts, part)
    end

    if #parts ~= 3 then
        return nil, "formato inválido, use x:y:z (ex: 0:0.3:0)"
    end

    local coords = {}
    for i, axis in ipairs({ "x", "y", "z" }) do
        local text_part = parts[i]
        if text_part == "" then
            coords[axis] = 0
        else
            local num = tonumber(text_part)
            if not num then
                return nil, "formato inválido, use x:y:z (ex: 0:0.3:0)"
            end
            coords[axis] = num
        end
    end

    return coords, nil
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
        "  Offsets usam DOIS-PONTOS x:y:z, não vírgula (ex: head_offset=0:0.3:0), pra não confundir com a separação dos args.",
        "  Vida: hp, hp_max, breath, breath_max",
        "  Visual: name, name_visible (false esconde o texto sem remover o nome), glow, scale (persiste ao recarregar), child (true/false)",
        "  Item na mão: hand (força can_wield_items), hand_offset=x:y:z",
        "  Item preso no corpo (qualquer item/bloco, não precisa ser armadura registrada): head, head_offset, chest, chest_offset, legs, legs_offset, feet, feet_offset (todos offset em x:y:z)",
        "  Armadura de verdade (textura): helmet, chestplate, leggings, boots",
        "  Montaria: ride=<mob_proximo> (monta em cima de um mob já spawnado, no raio de 3 nodes)",
        "  Comportamento: passive, retaliates, docile_by_day (ou day_docile), persistent, persist_in_peaceful, owner, tamed, order",
        "  Combate: damage, reach, knock_back, armor",
        "  Movimento: walk_velocity, run_velocity, jump, jump_height, stepheight, fly, swims, floats, view_range",
        "  Ambiente: water_damage, lava_damage, fire_damage, light_damage, suffocation, fall_damage, fear_height, ignited_by_sunlight=false",
        "Ex: /summon creeper ~ ~10 ~ hp=100,name=Bob,head=mcl_core:pumpkin,head_offset=0:0.2:0",
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

        -- name_visible=false esconde o texto flutuante SEM apagar o
        -- nome de verdade (mob.nametag continua com o valor real, só
        -- o que é MOSTRADO fica em branco -- ver o "wrap" de
        -- get_nametag no topo do arquivo).
        if args.name_visible ~= nil then
            mob._nametag_hidden = (args.name_visible == false)
            mob:update_tag()
        end
        if args.glow then
            obj:set_properties({ glow = args.glow })
        end

        -- hand_offset=x:y:z precisa ser processado ANTES de hand=,
        -- pra já estar valendo quando set_wielditem() disparar
        -- display_wielditem() (que é onde o offset é aplicado, ver o
        -- wrap no topo do arquivo).
        if args.hand_offset ~= nil then
            if type(args.hand_offset) ~= "string" then
                minetest.chat_send_player(name, "hand_offset= precisa ser x:y:z (ex: 0:0.3:0). Ignorado.")
            else
                local coords, err = parse_xyz_offset(args.hand_offset)
                if coords then
                    mob._hand_offset = coords
                else
                    minetest.chat_send_player(name, "hand_offset: " .. err)
                end
            end
        end

        -- hand= precisa usar mob_class:set_wielditem(), não
        -- set_properties no objeto principal do mob. O item exibido
        -- na mão é uma ENTIDADE FILHA separada ("mcl_mobs:wielditem",
        -- ver combat.lua), controlada só por essa função.
        --
        -- can_wield_items É FORÇADO aqui mesmo em mobs que normalmente
        -- não suportam segurar item (ex: animais). MAS isso sozinho não
        -- basta: `display_wielditem()` (combat.lua:1111) também exige
        -- `self.wielditem_info` -- uma tabela com o BONE (osso do
        -- modelo) onde o item fica preso, que só existe de fábrica em
        -- mobs humanoides. Pra quem não tem, criamos um fallback
        -- genérico (flutuando acima do mob) só pra garantir que
        -- ALGUMA coisa apareça -- pode ficar com posição estranha
        -- dependendo do modelo.
        if args.hand then
            if type(args.hand) ~= "string" then
                minetest.chat_send_player(name, "hand= precisa de um nome de item (ex: hand=diamond_sword). Ignorado.")
            else
                mob.can_wield_items = true
                if not mob.wielditem_info then
                    mob.wielditem_info = {
                        bone = "",              -- sem osso próprio: prende na raiz do objeto
                        position = { x = 0, y = 1.2, z = 0 },
                        rotation = { x = 0, y = 0, z = 0 },
                    }
                end

                local item, err = resolve_item_name(args.hand)
                if item then
                    mob:set_wielditem(ItemStack(item))
                else
                    minetest.chat_send_player(name, err)
                end
            end
        end

        -- head=, chest=, legs=, feet=: slots customizados (ver o
        -- sistema CUSTOM_SLOTS no topo do arquivo) pra prender
        -- QUALQUER item/bloco no mob, cada um com seu próprio offset
        -- em x:y:z. Diferente de helmet/chestplate/leggings/boots
        -- (abaixo), que são a ARMADURA de verdade (textura aplicada
        -- no modelo do mob), estes slots são um item/bloco FLUTUANDO
        -- preso no mob -- útil pra "vestir" um bloco na cabeça, por
        -- exemplo, que não é uma peça de armadura registrada.
        if mob.mcl_summon_update_slot then
            local function apply_custom_slot(slot_key, item_value, offset_value)
                if offset_value ~= nil then
                    if type(offset_value) ~= "string" then
                        minetest.chat_send_player(name, slot_key .. "_offset= precisa ser x:y:z (ex: 0:0.3:0). Ignorado.")
                    else
                        local coords, err = parse_xyz_offset(offset_value)
                        if coords then
                            mob["_summon_" .. slot_key .. "_offset"] = coords
                        else
                            minetest.chat_send_player(name, slot_key .. "_offset: " .. err)
                        end
                    end
                end

                if item_value ~= nil then
                    if type(item_value) ~= "string" then
                        minetest.chat_send_player(name, slot_key .. "= precisa de um nome de item/bloco. Ignorado.")
                    else
                        local item, err = resolve_item_name(item_value)
                        if item then
                            mob["_summon_" .. slot_key .. "_item"] = item
                        else
                            minetest.chat_send_player(name, err)
                        end
                    end
                end

                if mob["_summon_" .. slot_key .. "_item"] then
                    mob:mcl_summon_update_slot(slot_key)
                end
            end

            apply_custom_slot("head", args.head, args.head_offset)
            apply_custom_slot("chest", args.chest, args.chest_offset)
            apply_custom_slot("legs", args.legs, args.legs_offset)
            apply_custom_slot("feet", args.feet, args.feet_offset)
        end

        -- helmet/chestplate/leggings/boots usavam campos que NÃO
        -- EXISTEM no mod real (`mob.armor_head`, `armor_torso` etc.
        -- nunca são lidos em lugar nenhum). O sistema de verdade é
        -- `mob.armor_list` (tabela com chaves head/torso/legs/feet,
        -- cada uma guardando o ITEMSTRING completo, ex:
        -- "mcl_armor:helmet_iron") + `mob:set_armor_texture()`
        -- (items.lua:18) pra atualizar a textura visual depois.
        -- Só funciona em mobs com `_armor_texture_slots` definido
        -- (mobs humanoides -- zumbi, esqueleto, etc.); forçar em
        -- quem não tem isso quebraria set_armor_texture (ele itera
        -- essa tabela sem checar se existe).
        local function equip_armor(item_key, slot_key)
            local value = args[item_key]
            if value == nil then
                return
            end
            if type(value) ~= "string" then
                minetest.chat_send_player(name, item_key .. "= precisa de um item de armadura (ex: "
                    .. item_key .. "=helmet_iron). Ignorado.")
                return
            end
            if not mob._armor_texture_slots then
                minetest.chat_send_player(name, mobname .. " não suporta armadura visual (sem _armor_texture_slots).")
                return
            end

            local item, err = resolve_item_name(value)
            if not item then
                minetest.chat_send_player(name, err)
                return
            end

            mob.wears_armor = true
            if not mob.armor_list then
                mob.armor_list = { head = "", torso = "", legs = "", feet = "" }
            end
            mob.armor_list[slot_key] = item
            mob:set_armor_texture()
        end

        equip_armor("helmet", "head")
        equip_armor("chestplate", "torso")
        equip_armor("leggings", "legs")
        equip_armor("boots", "feet")

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