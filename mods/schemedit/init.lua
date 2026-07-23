-- ===================================================
-- MOD: schemedit (BetterCraft / Luanti)
-- Estado Padrão: DESATIVADO
-- Requisito: Permissão 'server' para ativar/desativar
-- Comandos: /schemedit <on|off|p1|p2|save <nome>|status>
-- Pasta de Instalação: games/bettercraft/mods/schemedit
-- ===================================================

local schemedit_enabled = false
local player_p1 = {}
local player_p2 = {}

minetest.register_chatcommand("schemedit", {
    params = "<on|off|p1|p2|save <nome>|status>",
    description = "Editor e exportador de esquematicos .mts (Requer permissao SERVER)",
    privs = { server = true }, -- Restrito a Administradores
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Jogador nao encontrado." end

        local args = {}
        for word in string.gmatch(param or "", "%S+") do
            table.insert(args, word)
        end

        local subcmd = args[1] and args[1]:lower() or ""

        if subcmd == "on" then
            schemedit_enabled = true
            return true, "[SchemEdit] O editor de esquematicos foi ATIVADO."

        elseif subcmd == "off" then
            schemedit_enabled = false
            player_p1[name] = nil
            player_p2[name] = nil
            return true, "[SchemEdit] O editor de esquematicos foi DESATIVADO e selecoes limpas."

        elseif subcmd == "p1" then
            if not schemedit_enabled then
                return false, "[SchemEdit] O editor esta DESATIVADO. Ative com '/schemedit on'"
            end
            local pos = vector.round(player:get_pos())
            player_p1[name] = pos
            return true, string.format("[SchemEdit] Posicao 1 definida em (X=%d, Y=%d, Z=%d)", pos.x, pos.y, pos.z)

        elseif subcmd == "p2" then
            if not schemedit_enabled then
                return false, "[SchemEdit] O editor esta DESATIVADO. Ative com '/schemedit on'"
            end
            local pos = vector.round(player:get_pos())
            player_p2[name] = pos
            return true, string.format("[SchemEdit] Posicao 2 definida em (X=%d, Y=%d, Z=%d)", pos.x, pos.y, pos.z)

        elseif subcmd == "save" then
            if not schemedit_enabled then
                return false, "[SchemEdit] O editor esta DESATIVADO. Ative com '/schemedit on'"
            end

            local schem_name = args[2]
            if not schem_name or schem_name == "" then
                return false, "Especifique o nome do arquivo! Exemplo: /schemedit save minha_construcao"
            end

            local p1 = player_p1[name]
            local p2 = player_p2[name]
            if not p1 or not p2 then
                return false, "Voce precisa definir a Posicao 1 (/schemedit p1) e a Posicao 2 (/schemedit p2) antes de salvar!"
            end

            local minp = { x = math.min(p1.x, p2.x), y = math.min(p1.y, p2.y), z = math.min(p1.z, p2.z) }
            local maxp = { x = math.max(p1.x, p2.x), y = math.max(p1.y, p2.y), z = math.max(p1.z, p2.z) }

            local filepath = minetest.get_worldpath() .. "/" .. schem_name .. ".mts"
            local success = minetest.create_schematic(minp, maxp, nil, filepath)

            if success then
                return true, string.format("★ Esquematico '%s.mts' salvo com sucesso no mundo!", schem_name)
            else
                return false, "Erro ao tentar salvar o arquivo esquematico no servidor."
            end

        elseif subcmd == "status" or subcmd == "" then
            local pos1_str = player_p1[name] and string.format("(%d,%d,%d)", player_p1[name].x, player_p1[name].y, player_p1[name].z) or "Nao definida"
            local pos2_str = player_p2[name] and string.format("(%d,%d,%d)", player_p2[name].x, player_p2[name].y, player_p2[name].z) or "Nao definida"
            return true, string.format("[SchemEdit] Status: %s | P1: %s | P2: %s", (schemedit_enabled and "ATIVADO" or "DESATIVADO"), pos1_str, pos2_str)

        else
            return false, "Comando invalido! Uso: /schemedit <on|off|p1|p2|save <nome>|status>"
        end
    end,
})

minetest.log("action", "[schemedit] Mod SchemEdit carregado em games/bettercraft/mods/schemedit (Padrao: DESATIVADO, Priv: server).")
