-- ===================================================
-- MOD: cozy (BetterCraft / Luanti)
-- Estado Padrão: DESATIVADO
-- Comandos: /cozy <on|off|toggle|sit|lay>
-- Pasta de Instalação: games/bettercraft/mods/cozy
-- ===================================================

local cozy_enabled = false
local sitting_players = {}

-- Registra comando /cozy
minetest.register_chatcommand("cozy", {
    params = "<on|off|toggle|sit|lay>",
    description = "Gerencia o modo aconchegante/cozy para sentar e deitar",
    privs = { interact = true },
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Jogador nao encontrado." end

        param = param and param:lower():trim() or ""

        if param == "on" then
            cozy_enabled = true
            minetest.chat_send_all("[Cozy] O sistema Cozy foi ATIVADO no servidor!")
            return true, "[Cozy] Sistema ativado com sucesso. Use /cozy sit para sentar."

        elseif param == "off" then
            cozy_enabled = false
            -- Levanta todos os jogadores sentados
            for p_name, _ in pairs(sitting_players) do
                local p = minetest.get_player_by_name(p_name)
                if p then
                    p:set_physics_override({ speed = 1, jump = 1 })
                    sitting_players[p_name] = nil
                end
            end
            minetest.chat_send_all("[Cozy] O sistema Cozy foi DESATIVADO no servidor.")
            return true, "[Cozy] Sistema desativado."

        elseif param == "toggle" then
            if cozy_enabled then
                return minetest.registered_chatcommands["cozy"].func(name, "off")
            else
                return minetest.registered_chatcommands["cozy"].func(name, "on")
            end

        elseif param == "sit" or param == "" then
            if not cozy_enabled then
                return false, "[Cozy] O sistema esta DESATIVADO no servidor. Use '/cozy on' primeiro."
            end

            if sitting_players[name] then
                -- Se ja estiver sentado, levanta
                player:set_physics_override({ speed = 1, jump = 1 })
                sitting_players[name] = nil
                return true, "[Cozy] Voce se levantou."
            else
                -- Sentar
                player:set_physics_override({ speed = 0, jump = 0 })
                sitting_players[name] = true
                return true, "[Cozy] Voce se sentou! Digite '/cozy sit' novamente para levantar."
            end

        elseif param == "lay" then
            if not cozy_enabled then
                return false, "[Cozy] O sistema esta DESATIVADO no servidor. Use '/cozy on' primeiro."
            end
            player:set_physics_override({ speed = 0, jump = 0 })
            sitting_players[name] = true
            return true, "[Cozy] Voce se deitou para descansar. Digite '/cozy sit' para levantar."

        else
            return false, "Comando invalido! Opcoes: /cozy on | /cozy off | /cozy sit | /cozy lay (Status: " .. (cozy_enabled and "ATIVADO" or "DESATIVADO") .. ")"
        end
    end,
})

-- Limpa estado do jogador ao desconectar
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    sitting_players[name] = nil
end)

minetest.log("action", "[cozy] Mod Cozy carregado em games/bettercraft/mods/cozy (Padrao: DESATIVADO).")
