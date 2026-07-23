-- ===================================================
-- MOD: death_coords (BetterCraft / Luanti)
-- Estado Padrão: DESATIVADO
-- Requisito: Permissão 'server' para ativar/desativar
-- Comandos: /deathcoords <on|off|status> e /lastdeath
-- Pasta de Instalação: games/bettercraft/mods/death_coords
-- ===================================================

local death_coords_enabled = false
local last_death_locations = {}

-- Comando principal do administrador para alternar status (/deathcoords)
minetest.register_chatcommand("deathcoords", {
    params = "<on|off|status>",
    description = "Ativa ou desativa a exibicao de coordenadas de morte no servidor (Requer permissao SERVER)",
    privs = { server = true }, -- Restrito a administradores do servidor
    func = function(name, param)
        param = param and param:lower():trim() or ""

        if param == "on" then
            death_coords_enabled = true
            minetest.chat_send_all("[Death Coords] ATIVADO pelo administrador " .. name .. "!")
            return true, "Death Coords ativado! Coordenadas de morte serao exibidas aos jogadores."

        elseif param == "off" then
            death_coords_enabled = false
            minetest.chat_send_all("[Death Coords] DESATIVADO pelo administrador " .. name .. "!")
            return true, "Death Coords desativado."

        elseif param == "status" or param == "" then
            local st = death_coords_enabled and "ATIVADO" or "DESATIVADO"
            return true, "[Death Coords] Status do servidor: " .. st

        else
            return false, "Uso incorreto! Digite: /deathcoords on | /deathcoords off | /deathcoords status"
        end
    end,
})

-- Intercepta a morte do jogador e avisa a coordenada exata
minetest.register_on_dieplayer(function(player)
    if not death_coords_enabled then
        return
    end

    local name = player:get_player_name()
    local pos = player:get_pos()

    if pos then
        local x = math.floor(pos.x + 0.5)
        local y = math.floor(pos.y + 0.5)
        local z = math.floor(pos.z + 0.5)

        last_death_locations[name] = { x = x, y = y, z = z }

        local msg = string.format("☠️ [Morte] Voce morreu em: X = %d | Y = %d | Z = %d", x, y, z)
        minetest.chat_send_player(name, msg)
        minetest.log("action", string.format("[death_coords] Jogador %s morreu na posicao (%d, %d, %d)", name, x, y, z))
    end
end)

-- Comando secundário público para consultar a última morte individual
minetest.register_chatcommand("lastdeath", {
    params = "",
    description = "Mostra a localizacao da sua ultima morte",
    privs = { interact = true },
    func = function(name, param)
        if not death_coords_enabled then
            return false, "[Death Coords] O sistema esta DESATIVADO no servidor."
        end

        local pos = last_death_locations[name]
        if pos then
            return true, string.format("☠️ Sua ultima morte registrada foi em: X = %d, Y = %d, Z = %d", pos.x, pos.y, pos.z)
        else
            return false, "Nenhuma morte registrada recentemente para voce nesta sessao."
        end
    end,
})

minetest.log("action", "[death_coords] Mod Death Coords carregado em games/bettercraft/mods/death_coords (Padrao: DESATIVADO, Priv: server).")
