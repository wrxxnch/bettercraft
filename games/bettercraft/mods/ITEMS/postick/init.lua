local S = core.get_translator(core.get_current_modname())

-- =========================
-- Storage por jogador
-- =========================
local selections = {}

local function get_sel(name)
    selections[name] = selections[name] or {
        step = 1,
        pos1 = nil,
        pos2 = nil
    }
    return selections[name]
end

-- =========================
-- Raycast no ar (AUX1)
-- =========================
local function get_pointed_air(player)
    local eye = vector.add(player:get_pos(), {x=0, y=1.5, z=0})
    local dir = player:get_look_dir()
    local range = 10

    local ray = core.raycast(
        eye,
        vector.add(eye, vector.multiply(dir, range)),
        false,
        false
    )

    for pointed in ray do
        if pointed.type == "node" then
            return pointed.under
        end
    end

    return vector.round(vector.add(eye, vector.multiply(dir, range)))
end

-- =========================
-- Ferramenta PosTick
-- =========================
core.register_tool("postick:postick", {
    description = S("PosTick (AUX1 + Colocar Bloco)"),
    inventory_image = "default_stick.png^[colorize:#00ffff:120",

    on_place = function(itemstack, player, pointed)
        if not player then return itemstack end

        local ctrl = player:get_player_control()
        if not ctrl.aux1 then
            core.chat_send_player(
                player:get_player_name(),
                "Segure AUX1 + clique direito para selecionar."
            )
            return itemstack
        end

        local name = player:get_player_name()
        local sel = get_sel(name)

        local pos
        if pointed and pointed.type == "node" then
            pos = pointed.under
        else
            pos = get_pointed_air(player)
        end

        pos = vector.round(pos)

        if sel.step == 1 then
            sel.pos1 = pos
            sel.step = 2
            core.chat_send_player(
                name,
                "Pos1 selecionada: §7" .. core.pos_to_string(pos)
            )
        else
            sel.pos2 = pos
            sel.step = 1
            core.chat_send_player(
                name,
                "Pos2 selecionada: §7" .. core.pos_to_string(pos)
            )
            core.chat_send_player(
                name,
                "Você pode usar: pos1 & pos2 em comandos."
            )
        end

        return itemstack
    end
})

-- =========================
-- Comando /postick
-- =========================
core.register_chatcommand("postick", {
    description = "Receber a ferramenta PosTick",
    privs = { give = true },

    func = function(name)
        local player = core.get_player_by_name(name)
        if not player then return end

        player:get_inventory():add_item("main", "postick:postick")
        return true, "PosTick adicionada ao inventário."
    end
})

-- =========================
-- API para outros comandos
-- =========================
function postick_get_pos(playername, which)
    local sel = selections[playername]
    if not sel then return nil end
    return sel[which]
end
