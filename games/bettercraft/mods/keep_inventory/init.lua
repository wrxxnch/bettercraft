-- ===================================================
-- MOD: keep_inventory (BetterCraft / Luanti)
-- Estado Padrão: DESATIVADO
-- Requisito: Permissão 'server' para ativar/desativar
-- Comandos: /keepinv <false|true|status>
-- Pasta de Instalação: games/bettercraft/mods/keep_inventory
-- ===================================================

local keep_inventory_enabled = false
local saved_inventories = {}

-- Registra comando restrito para administradores (/keepinv)
minetest.register_chatcommand("keepinv", {
    params = "<false|true|status>",
    description = "keeps invntory on death (grantme server)",
    privs = { server = true }, -- Apenas administradores com permissao 'server'
    func = function(name, param)
        param = param and param:lower():trim() or ""

        if param == "true" then
            keep_inventory_enabled = true
            minetest.chat_send_all("[Keep Inventory] ATIVADO pelo administrador " .. name .. "!")
            return true, "Keep Inventory foi ATIVADO! Jogadores nao perderao itens ao morrer."

        elseif param == "false" then
            keep_inventory_enabled = false
            minetest.chat_send_all("[Keep Inventory] DESATIVADO pelo administrador " .. name .. "!")
            return true, "Keep Inventory foi DESATIVADO. Jogadores perderao itens ao morrer."

        elseif param == "status" or param == "" then
            local status_text = keep_inventory_enabled and "ATIVADO (Itens protegidos)" or "DESATIVADO (Itens caem no chao)"
            return true, "[Keep Inventory] status:: " .. status_text

        else
            return false, "try /keepinventory true or false"
        end
    end,
})

-- Alias para o comando /keepinventory
minetest.register_chatcommand("keepinventory", {
    params = "<true|false|status>",
    description = "Alias para /keepinv",
    privs = { server = true },
    func = function(name, param)
        return minetest.registered_chatcommands["keepinv"].func(name, param)
    end,
})

-- Guarda o inventário no momento da morte se estiver ATIVADO
minetest.register_on_dieplayer(function(player)
    if not keep_inventory_enabled then
        return -- Se estiver desativado, o comportamento padrão do jogo dropa os itens
    end

    local name = player:get_player_name()
    local inv = player:get_inventory()
    if not inv then return end

    local saved_main = {}
    local main_list = inv:get_list("main")
    if main_list then
        for i, item in ipairs(main_list) do
            saved_main[i] = item:to_string()
        end
    end

    local saved_craft = {}
    local craft_list = inv:get_list("craft")
    if craft_list then
        for i, item in ipairs(craft_list) do
            saved_craft[i] = item:to_string()
        end
    end

    saved_inventories[name] = {
        main = saved_main,
        craft = saved_craft,
    }

    -- Limpa o inventário para evitar drops duplos
    inv:set_list("main", {})
    inv:set_list("craft", {})

    -- minetest.chat_send_player(name, "[Keep Inventory] Seus itens foram salvos e mantidos!")
end)

-- Restaura o inventário no respawn do jogador
minetest.register_on_respawnplayer(function(player)
    local name = player:get_player_name()
    local saved = saved_inventories[name]

    if saved and keep_inventory_enabled then
        local inv = player:get_inventory()
        if inv then
            if saved.main then
                for i, item_str in ipairs(saved.main) do
                    inv:set_stack("main", i, ItemStack(item_str))
                end
            end
            if saved.craft then
                for i, item_str in ipairs(saved.craft) do
                    inv:set_stack("craft", i, ItemStack(item_str))
                end
            end
        end
        saved_inventories[name] = nil
    end
end)

minetest.log("action", "[keep_inventory] Mod Keep Inventory carregado em games/bettercraft/mods/keep_inventory (Padrao: DESATIVADO, Priv: server).")
