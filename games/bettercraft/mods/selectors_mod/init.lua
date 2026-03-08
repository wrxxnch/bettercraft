local selectors = dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/selectors.lua")


-- Exemplo: Comando /tp customizado que aceita seletores
minetest.override_chatcommand("tp", {
    params = "<alvo> <destino>",
    description = "Teleport com selectors",
    privs = {teleport = true},

    func = function(name, param)

        local args = {}
        for word in param:gmatch("%S+") do
            table.insert(args, word)
        end

        if #args == 0 then
            return false, "Uso: /tp <alvo> [destino]"
        end

        local player = minetest.get_player_by_name(name)
        local targets = {}

        --------------------------------------------------
        -- RESOLVE TARGETS
        --------------------------------------------------

        if args[1]:sub(1,1) == "@" then
            targets = selectors.resolve(name, args[1])
        else
            local p = minetest.get_player_by_name(args[1])
            if p then
                targets = {p}
            end
        end

        if #targets == 0 then
            return false, "Alvo não encontrado."
        end

        --------------------------------------------------
        -- /tp <destino>
        --------------------------------------------------

        if #args == 1 then

            local dest = targets[1]

            if not dest then
                return false, "Destino inválido."
            end

            player:set_pos(dest:get_pos())

            return true, "Teleportado."

        end

        --------------------------------------------------
        -- DESTINO
        --------------------------------------------------

        local dest_pos = nil

        -- selector
        if args[2]:sub(1,1) == "@" then

            local dest = selectors.resolve(name, args[2])

            if #dest == 0 then
                return false, "Destino não encontrado."
            end

            dest_pos = dest[1]:get_pos()

        -- coordenadas
        elseif args[2] == "~" or args[2]:match("^~") then

            local base = player:get_pos()

            local x = tonumber(args[2]:gsub("~","")) or 0
            local y = tonumber(args[3]:gsub("~","")) or 0
            local z = tonumber(args[4]:gsub("~","")) or 0

            dest_pos = {
                x = base.x + x,
                y = base.y + y,
                z = base.z + z
            }

        -- nome player
        else

            local dest = minetest.get_player_by_name(args[2])

            if dest then
                dest_pos = dest:get_pos()
            end

        end

        if not dest_pos then
            return false, "Destino inválido."
        end

        --------------------------------------------------
        -- TELEPORT
        --------------------------------------------------

        for _, obj in ipairs(targets) do

            if obj:is_player() then
                obj:set_pos(dest_pos)
            else
                obj:move_to(dest_pos)
            end

        end

        return true, "Teleportado(s)."

    end
})

-- Exemplo: Comando /kill que aceita seletores
minetest.register_chatcommand("kill", {
    params = "<alvo>",
    description = "Mata o alvo",
    privs = {give = true},
    func = function(name, param)
        local targets = selectors.resolve(name, param)
        for _, obj in ipairs(targets) do
            obj:set_hp(0)
        end
        return true, "Alvo(s) eliminados."
    end,
})
