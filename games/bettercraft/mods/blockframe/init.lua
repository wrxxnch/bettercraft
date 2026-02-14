--------------------------------------------------
-- INIT.LUA COMPLETO - BLOCKFRAME (UPDATED V3)
--------------------------------------------------
blockframe = {}
blockframe.active = {} -- [name] = { type="single"|"composite", entities={}, ... }
blockframe.memory = {}
blockframe.del_history = {}
blockframe.world_path = minetest.get_worldpath()

--------------------------------------------------
-- HELP
--------------------------------------------------
function blockframe.help_text()
    return [[
📦 BlockFrame — Ajuda

Uso:
/blockframe <args>
/blockframe_set
/blockframe_cancel
/blockframe_undo
/blockframe_del radius=N
/blockframe_del_undo
/blockframe_save <nome> radius=N
/blockframe_load <nome> <args>
/blockframe_help

ARGS (Preview & Load):
 size=x,y,z        tamanho/escala
 rotate=x,y,z      rotação XYZ
 mirror=x|y|z      espelho
 pos=x,y,z         posição absoluta ou offset
 step=valor        snap da mira
 collision=true    ativa colisão (no set/load)

Exemplos:
/blockframe size=0.5 rotate=0,45,0
/blockframe_load minha_casa size=2 rotate=0,90,0
]]
end

--------------------------------------------------
-- PARSER
--------------------------------------------------
function blockframe.parse_args(param)
    local args = {}
    for w in param:gmatch("%S+") do
        local k, v = w:match("([^=]+)=([^=]+)")
        if k then
            if v == "true" then
                v = true
            elseif v == "false" then
                v = false
            end
            args[k] = v
        end
    end
    return args
end

--------------------------------------------------
-- FUNÇÕES AUXILIARES
--------------------------------------------------
local function parse_vec(str, def)
    if not str then
        return def
    end
    if type(str) == "table" then
        return str
    end
    if type(str) == "number" then
        -- se for número único, aplica para x,y,z
        return {
            x = str,
            y = str,
            z = str
        }
    end
    -- se for string
    local vals = {}
    for n in str:gmatch("([^,]+)") do
        table.insert(vals, tonumber(n))
    end
    if #vals == 1 then
        return {
            x = vals[1],
            y = vals[1],
            z = vals[1]
        }
    end
    if #vals == 2 then
        return {
            x = vals[1],
            y = vals[2],
            z = vals[2]
        }
    end
    if #vals >= 3 then
        return {
            x = vals[1],
            y = vals[2],
            z = vals[3]
        }
    end
    return def
end

local function snap(v, step)
    if not step or step <= 0 then
        return v
    end
    return {
        x = math.floor(v.x / step + 0.5) * step,
        y = math.floor(v.y / step + 0.5) * step,
        z = math.floor(v.z / step + 0.5) * step
    }
end

local function safe(v)
    return math.max(0.001, math.abs(v or 0))
end

local function get_wielded_item(player)
    local stack = player:get_wielded_item()
    if stack:is_empty() then
        return
    end
    return stack:get_name()
end

-- Aplica transformações (escala, rotação, espelho)
local function apply_transform(base_val, transform_val, is_rotation)
    if not transform_val then
        return base_val
    end
    if is_rotation then
        return {
            x = (base_val.x or 0) + (transform_val.x or 0),
            y = (base_val.y or 0) + (transform_val.y or 0),
            z = (base_val.z or 0) + (transform_val.z or 0)
        }
    else
        -- Escala multiplicativa
        return {
            x = (base_val.x or 1) * (transform_val.x or 1),
            y = (base_val.y or 1) * (transform_val.y or 1),
            z = (base_val.z or 1) * (transform_val.z or 1)
        }
    end
end

local function update_entity_properties(self)
    local base_size = self.args.size or {
        x = 0.5,
        y = 0.5,
        z = 0.5
    }
    local visual_v = table.copy(base_size)

    -- aplica espelhamento só na visualização
    if self.args.mirror == "x" then
        visual_v.x = -visual_v.x
    end
    if self.args.mirror == "y" then
        visual_v.y = -visual_v.y
    end
    if self.args.mirror == "z" then
        visual_v.z = -visual_v.z
    end

    local props = {
        visual_size = visual_v,
        physical = false,
        pointable = false,
        collisionbox = {0, 0, 0, 0, 0, 0} -- padrão sem colisão
    }

    if self.args.collision then
        props.physical = true
        props.pointable = true

        local rot_deg = parse_vec(self.args.rotate, {
            x = 0,
            y = 0,
            z = 0
        })
        local initial_size = {}

        -- define o tamanho da colisão
        local parsed_coll

        if self.args.collision ~= true then
            parsed_coll = parse_vec(tostring(self.args.collision))
        end

        if type(parsed_coll) == "table" then
            initial_size.x = math.abs(parsed_coll.x or base_size.x)
            initial_size.y = math.abs(parsed_coll.y or base_size.y)
            initial_size.z = math.abs(parsed_coll.z or base_size.z)
        else
            initial_size.x = math.abs(base_size.x)
            initial_size.y = math.abs(base_size.y)
            initial_size.z = math.abs(base_size.z)
        end

        -- converte ângulos para radianos
        local cx, sx = math.cos(math.rad(rot_deg.x)), math.sin(math.rad(rot_deg.x))
        local cy, sy = math.cos(math.rad(rot_deg.y)), math.sin(math.rad(rot_deg.y))
        local cz, sz = math.cos(math.rad(rot_deg.z)), math.sin(math.rad(rot_deg.z))

        local m = {{cy * cz, cz * sx * sy - cx * sz, cx * cz * sy + sx * sz},
                   {cy * sz, sx * sy * sz + cx * cz, cx * sy * sz - cz * sx}, {-sy, cy * sx, cx * cy}}

        -- calcula bounding box alinhado ao mundo
        local final_size = {
            x = safe(math.abs(m[1][1]) * initial_size.x + math.abs(m[1][2]) * initial_size.y + math.abs(m[1][3]) *
                         initial_size.z),

            y = safe(math.abs(m[2][1]) * initial_size.x + math.abs(m[2][2]) * initial_size.y + math.abs(m[2][3]) *
                         initial_size.z),

            z = safe(math.abs(m[3][1]) * initial_size.x + math.abs(m[3][2]) * initial_size.y + math.abs(m[3][3]) *
                         initial_size.z)
        }

        props.collisionbox = {-final_size.x / 2, -final_size.y / 2, -final_size.z / 2, final_size.x / 2,
                              final_size.y / 2, final_size.z / 2}
    end

    self.object:set_properties(props)

    -- aplica rotação visual
    if self.args.rotate then
        local rot_rad = parse_vec(self.args.rotate, {
            x = 0,
            y = 0,
            z = 0
        })
        self.object:set_rotation({
            x = math.rad(rot_rad.x or 0),
            y = math.rad(rot_rad.y or 0),
            z = math.rad(rot_rad.z or 0)
        })
    end
end

--------------------------------------------------
-- ENTIDADES
--------------------------------------------------
minetest.register_entity("blockframe:preview", {
    initial_properties = {
        visual = "wielditem",
        physical = false,
        pointable = false,
        glow = 5,
        visual_size = {
            x = 0.5,
            y = 0.5
        },
        collisionbox = {0, 0, 0, 0, 0, 0},
        static_save = false
    },
    on_activate = function(self, staticdata)
        local data = minetest.deserialize(staticdata) or {}
        self.node = data.node or "default:stone"
        self.args = {}
        self.step = 0
        self.player_name = data.player_name
        self.rel_pos = data.rel_pos or {
            x = 0,
            y = 0,
            z = 0
        } -- para composite
        self.offset = {
            x = 0,
            y = 0,
            z = 0
        }
        self.object:set_properties({
            wield_item = self.node,
            opacity = 120
        })
    end,
    apply_args = function(self, args, global_args)
        local final_args = table.copy(args or {})

        -- 🔴 CONVERSÕES IMPORTANTES
        if final_args.size then
            final_args.size = parse_vec(final_args.size, {
                x = 0.5,
                y = 0.5,
                z = 0.5
            })
        end

        if final_args.rotate then
            final_args.rotate = parse_vec(final_args.rotate, {
                x = 0,
                y = 0,
                z = 0
            })
        end

        -- Merge com argumentos globais (do comando /blockframe_load)
        if global_args then
            if global_args.size then
                local scale = parse_vec(global_args.size, {
                    x = 1,
                    y = 1,
                    z = 1
                })
                final_args.size = apply_transform(final_args.size or {
                    x = 0.5,
                    y = 0.5,
                    z = 0.5
                }, scale, false)
            end
            if global_args.rotate then
                local rot_offset = parse_vec(global_args.rotate, {
                    x = 0,
                    y = 0,
                    z = 0
                })
                final_args.rotate = apply_transform(final_args.rotate or {
                    x = 0,
                    y = 0,
                    z = 0
                }, rot_offset, true)
            end
            if global_args.mirror then
                final_args.mirror = global_args.mirror
            end
            if global_args.collision ~= nil then
                final_args.collision = global_args.collision
            end
        end

        self.args = final_args
        update_entity_properties(self)
    end,
    on_step = function(self)
        local player = minetest.get_player_by_name(self.player_name)
        if not player then
            return
        end

        local active = blockframe.active[self.player_name]
        if not active then
            return
        end

        -- Apenas a entidade "mestre" ou controlada pelo step calcula a posição
        -- Se for composite, o controlador central cuida da posição de todos
    end
})

minetest.register_entity("blockframe:placed", {
    initial_properties = {
        visual = "wielditem",
        physical = false,
        pointable = true,
        static_save = true,
        visual_size = {
            x = 0.5,
            y = 0.5
        },
        collisionbox = {0, 0, 0, 0, 0, 0}
    },
    on_activate = function(self, staticdata)
        local data = minetest.deserialize(staticdata) or {}
        self.node = data.node or "default:stone"
        self.args = data.args or {}
        self.object:set_properties({
            wield_item = self.node
        })
        update_entity_properties(self)
        if self.args.pos then
            self.object:set_pos(self.args.pos)
        end
    end,
    get_staticdata = function(self)
        return minetest.serialize({
            node = self.node,
            args = self.args
        })
    end
})

--------------------------------------------------
-- CENTRAL PREVIEW LOGIC
--------------------------------------------------
-- Gerencia o movimento de todos os previews ativos de um jogador
minetest.register_globalstep(function(dtime)
    for name, data in pairs(blockframe.active) do
        local player = minetest.get_player_by_name(name)
        if player then
            local eye = vector.add(player:get_pos(), {
                x = 0,
                y = player:get_properties().eye_height or 1.6,
                z = 0
            })
            local dir = player:get_look_dir()
            local ray = minetest.raycast(vector.add(eye, vector.multiply(dir, 0.2)),
                vector.add(eye, vector.multiply(dir, 6)), true, true)

            local hit_pos
            for hit in ray do
                if hit.type ~= "object" or hit.ref ~= player then
                    hit_pos = hit.intersection_point or hit.above
                    break
                end
            end

            if hit_pos then
                hit_pos = snap(hit_pos, data.step or 0)
                hit_pos = vector.add(hit_pos, data.offset or {
                    x = 0,
                    y = 0,
                    z = 0
                })
                data.last_pos = hit_pos

                for _, ent_obj in ipairs(data.entities) do
                    local ent = ent_obj:get_luaentity()
                    if ent then
                        local final_pos = vector.add(hit_pos, ent.rel_pos or {
                            x = 0,
                            y = 0,
                            z = 0
                        })
                        ent_obj:set_pos(final_pos)
                    end
                end
            end
        end
    end
end)

--------------------------------------------------
-- SPAWN HELPERS
--------------------------------------------------
function blockframe.clear_active(name)
    if blockframe.active[name] then
        for _, obj in ipairs(blockframe.active[name].entities) do
            obj:remove()
        end
        blockframe.active[name] = nil
    end
end

--------------------------------------------------
-- COMANDOS
--------------------------------------------------
minetest.register_chatcommand("blockframe", {
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return
        end
        local args = blockframe.parse_args(param)

        blockframe.clear_active(name)

        local node = get_wielded_item(player)
        if not node and blockframe.memory[name] then
            node = blockframe.memory[name].node
        end
        if not node then
            return false, "Segure um bloco ou use um anterior."
        end

        local obj = minetest.add_entity(player:get_pos(), "blockframe:preview", minetest.serialize({
            node = node,
            player_name = name
        }))
        if obj then
            local ent = obj:get_luaentity()
            ent:apply_args(args)
            blockframe.active[name] = {
                type = "single",
                entities = {obj},
                step = tonumber(args.step) or 0,
                offset = parse_vec(args.pos, {
                    x = 0,
                    y = 0,
                    z = 0
                })
            }
        end
        return true
    end
})

minetest.register_chatcommand("blockframe_load", {
    params = "<nome> [args]",
    func = function(name, param)
        local filename, args_str = param:match("^(%S+)%s*(.*)$")
        if not filename then
            return false, "Uso: /blockframe_load <nome> [args]"
        end

        local filepath = blockframe.world_path .. "/" .. filename .. ".bf"
        local file = io.open(filepath, "r")
        if not file then
            return false, "Arquivo não encontrado."
        end
        local data = minetest.deserialize(file:read("*all"))
        file:close()

        if not data or not data.entities then
            return false, "Arquivo inválido."
        end

        blockframe.clear_active(name)
        local global_args = blockframe.parse_args(args_str)
        local preview_objs = {}

        for _, e in ipairs(data.entities) do
            local obj = minetest.add_entity(minetest.get_player_by_name(name):get_pos(), "blockframe:preview",
                minetest.serialize({
                    node = e.node,
                    player_name = name,
                    rel_pos = e.rel_pos
                }))
            if obj then
                local ent = obj:get_luaentity()
                ent:apply_args(e.args, global_args)
                table.insert(preview_objs, obj)
            end
        end

        blockframe.active[name] = {
            type = "composite",
            entities = preview_objs,
            step = tonumber(global_args.step) or 0,
            offset = parse_vec(global_args.pos, {
                x = 0,
                y = 0,
                z = 0
            })
        }

        return true, "Preview carregado. Use /blockframe_set para confirmar."
    end
})

minetest.register_chatcommand("blockframe_set", {
    func = function(name)
        local data = blockframe.active[name]
        if not data then
            return false, "Nenhum preview ativo."
        end

        local count = 0
        for _, obj in ipairs(data.entities) do
            local ent = obj:get_luaentity()
            if ent then
                local pos = obj:get_pos()
                local final_args = table.copy(ent.args)
                final_args.pos = pos
                minetest.add_entity(pos, "blockframe:placed", minetest.serialize({
                    node = ent.node,
                    args = final_args
                }))

                -- Salvar no memory (apenas o último para single, ou info geral para composite)
                blockframe.memory[name] = {
                    node = ent.node,
                    args = final_args,
                    pos = pos
                }
                count = count + 1
            end
        end

        blockframe.clear_active(name)
        return true, "Confirmado: " .. count .. " bloco(s) colocado(s)."
    end
})

minetest.register_chatcommand("blockframe_save", {
    params = "<nome> [radius=N]",
    func = function(name, param)
        local filename, args_str = param:match("^(%S+)%s*(.*)$")
        if not filename then
            return false, "Uso: /blockframe_save <nome> [radius=N]"
        end
        local args = blockframe.parse_args(args_str)
        local radius = tonumber(args.radius) or 10
        local player = minetest.get_player_by_name(name)
        local success, count = blockframe.save_map(filename, player:get_pos(), radius)
        if success then
            return true, "Salvo: " .. count .. " blocos."
        else
            return false, count
        end
    end
})

minetest.register_chatcommand("blockframe_cancel", {
    func = function(name)
        if not blockframe.active[name] then
            return false, "Nenhum preview para cancelar."
        end
        blockframe.clear_active(name)
        return true, "Preview cancelado."
    end
})

-- (Manter comandos blockframe_undo, blockframe_del, blockframe_del_undo e blockframe_help iguais, mas atualizados com as novas tabelas se necessário)
-- Re-implementando blockframe_save para compatibilidade
function blockframe.save_map(filename, center_pos, radius)
    local objs = minetest.get_objects_inside_radius(center_pos, radius)
    local data = {
        version = 1,
        entities = {}
    }
    for _, obj in ipairs(objs) do
        local ent = obj:get_luaentity()
        if ent and ent.name == "blockframe:placed" then
            table.insert(data.entities, {
                node = ent.node,
                rel_pos = vector.subtract(obj:get_pos(), center_pos),
                args = ent.args
            })
        end
    end
    local file = io.open(blockframe.world_path .. "/" .. filename .. ".bf", "w")
    if file then
        file:write(minetest.serialize(data));
        file:close();
        return true, #data.entities
    end
    return false, "Erro ao salvar."
end

-- Re-adicionando comandos de deleção e undo para garantir o arquivo completo
minetest.register_chatcommand("blockframe_undo", {
    func = function(name)
        local mem = blockframe.memory[name]
        if not mem then
            return false, "Nenhum bloco para desfazer."
        end
        local objs = minetest.get_objects_inside_radius(mem.pos, 0.5)
        for _, obj in ipairs(objs) do
            local luaent = obj:get_luaentity()
            if luaent and luaent.name == "blockframe:placed" then
                obj:remove();
                break
            end
        end
        blockframe.memory[name] = nil
        return true, "Desfeito."
    end
})

minetest.register_chatcommand("blockframe_del", {
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        local args = blockframe.parse_args(param)
        local radius = tonumber(args.radius) or 2
        local objs = minetest.get_objects_inside_radius(player:get_pos(), radius)
        local removed_list = {}
        for _, obj in ipairs(objs) do
            local ent = obj:get_luaentity()
            if ent and ent.name == "blockframe:placed" then
                table.insert(removed_list, {
                    node = ent.node,
                    pos = obj:get_pos(),
                    args = table.copy(ent.args)
                })
                obj:remove()
            end
        end
        blockframe.del_history[name] = removed_list
        return true, "Removido " .. #removed_list .. " blocos."
    end
})

minetest.register_chatcommand("blockframe_del_undo", {
    func = function(name)
        local history = blockframe.del_history[name]
        if not history then
            return false, "Nada para desfazer."
        end
        for _, item in ipairs(history) do
            minetest.add_entity(item.pos, "blockframe:placed", minetest.serialize({
                node = item.node,
                args = item.args
            }))
        end
        blockframe.del_history[name] = nil
        return true, "Restaurado."
    end
})

minetest.register_chatcommand("blockframe_help", {
    func = function()
        return true, blockframe.help_text()
    end
})

minetest.register_on_leaveplayer(function(player)
    blockframe.clear_active(player:get_player_name())
end)