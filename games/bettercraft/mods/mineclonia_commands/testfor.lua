--------------------------------------------------
-- TESTFOR.LUA COMPLETO
-- Implementa:
-- /testfor
-- /testforblock
-- /testforblocks
-- compatível com Mineclonia
--------------------------------------------------
mineclonia_commands = mineclonia_commands or {}

--------------------------------------------------
-- REDSTONE RESULT
--------------------------------------------------

local function set_commandblock_result(success)

    local pos = core.commandblock_pos or (minetest.get_commandblock_pos and minetest.get_commandblock_pos())

    if not pos then
        return
    end

    local meta = minetest.get_meta(pos)

    meta:set_int("success_count", success and 1 or 0)
    meta:set_int("comparator_power", success and 15 or 0)

    if mcl_redstone and mcl_redstone.update_comparators then
        mcl_redstone.update_comparators(pos)
    end

end

--------------------------------------------------
-- EXECUTE PARSER
--------------------------------------------------

local function extract_conditional_commands(param)

    local exec_if
    local exec_unless

    local function extract(key)

        local s, e = param:find(key .. "=")

        if not s then
            return nil
        end

        local start = e + 1
        local next = param:find(" execute", start)

        local stop = next and next - 1 or #param

        local cmd = param:sub(start, stop)

        param = param:sub(1, s - 1) .. param:sub(stop + 1)

        return cmd
    end

    exec_unless = extract("execute!")
    exec_if = extract("execute")

    param = param:gsub("^%s*(.-)%s*$", "%1")

    return exec_if, exec_unless, param

end

--------------------------------------------------
-- EXECUTE RUNNER
--------------------------------------------------

local function run_conditional_command(name, cmd)

    if not cmd then
        return
    end

    for single in cmd:gmatch("[^,]+") do

        single = single:gsub("^%s*(.-)%s*$", "%1")

        if single:sub(1, 1) == "/" then
            single = single:sub(2)
        end

        local args = single:split(" ")

        local command = args[1]
        table.remove(args, 1)

        local def = minetest.registered_chatcommands[command]

        if def then
            def.func(name, table.concat(args, " "))
        end

    end

end

--------------------------------------------------
-- COORD PARSER
--------------------------------------------------

local function parse_coord(str, current)

    if not str then
        return current
    end

    if str:sub(1, 1) == "~" then

        local offset = tonumber(str:sub(2)) or 0
        return current + offset

    end

    return tonumber(str) or current

end

local function get_pos_from_args(args, player)

    local pos = player:get_pos()

    local x = parse_coord(args[1], pos.x)
    local y = parse_coord(args[2], pos.y)
    local z = parse_coord(args[3], pos.z)

    table.remove(args, 1)
    table.remove(args, 1)
    table.remove(args, 1)

    return vector.round({
        x = x,
        y = y,
        z = z
    }), args

end

--------------------------------------------------
-- ENTITY MATCH
--------------------------------------------------

local function entity_matches(obj, filters)

    local is_player = obj:is_player()

    local lua = obj:get_luaentity()

    if not is_player and not lua then
        return false
    end

    if filters.only_players and not is_player then
        return false
    end

    if filters.type then

        local name = is_player and "player" or lua.name

        if name ~= filters.type then

            local short = name:match(":(.+)")

            if short ~= filters.type then
                return false
            end

        end

    end

    return true

end

--------------------------------------------------
-- /TESTFOR
--------------------------------------------------

minetest.register_chatcommand("testfor", {

    params = "<selector>",
    privs = {
        server = true
    },

    func = function(name, param)

        local player = minetest.get_player_by_name(name)

        local exec_if, exec_unless, param = extract_conditional_commands(param)

        local selector = param

        local filters = {}

        if selector:find("@a") then
            filters.only_players = true
        end

        local type = selector:match("type=([^%]]+)")

        if type then
            filters.type = type
        end

        local center = player:get_pos()

        local objects = minetest.get_objects_inside_radius(center, 32768)

        local count = 0

        for _, obj in ipairs(objects) do

            if entity_matches(obj, filters) then
                count = count + 1
            end

        end

        local success = count > 0

        set_commandblock_result(success)

        if success then
            run_conditional_command(name, exec_if)
        else
            run_conditional_command(name, exec_unless)
        end

        return success, success and ("Encontrado " .. count) or "Nenhum encontrado"

    end

})

--------------------------------------------------
-- /TESTFORBLOCK
--------------------------------------------------

minetest.register_chatcommand("testforblock", {

    params = "<x> <y> <z> <node>",

    privs = {
        server = true
    },

    func = function(name, param)

        local player = minetest.get_player_by_name(name)

        local exec_if, exec_unless, param = extract_conditional_commands(param)

        local args = param:split(" ")

        local pos, args = get_pos_from_args(args, player)

        local node = args[1]

        if not node then
            return false
        end

        if not node:find(":") then

            local full = "mcl_core:" .. node

            if minetest.registered_nodes[full] then
                node = full
            end

        end

        local current = minetest.get_node(pos)

        local success = current.name == node

        set_commandblock_result(success)

        if success then
            run_conditional_command(name, exec_if)
        else
            run_conditional_command(name, exec_unless)
        end

        return success, success and "Bloco correto" or "Bloco diferente"

    end

})

--------------------------------------------------
-- /TESTFORBLOCKS
--------------------------------------------------

minetest.register_chatcommand("testforblocks", {

    params = "<area1> <area2> destiny execute=<command>",

    privs = {
        server = true
    },

    func = function(name, param)

        local player = minetest.get_player_by_name(name)

        local exec_if, exec_unless, param = extract_conditional_commands(param)

        local args = param:split(" ")

        local pos1, args = get_pos_from_args(args, player)

        local pos2, args = get_pos_from_args(args, player)

        local pos3, args = get_pos_from_args(args, player)

        local minx = math.min(pos1.x, pos2.x)
        local miny = math.min(pos1.y, pos2.y)
        local minz = math.min(pos1.z, pos2.z)

        local maxx = math.max(pos1.x, pos2.x)
        local maxy = math.max(pos1.y, pos2.y)
        local maxz = math.max(pos1.z, pos2.z)

        local success = true

        for x = minx, maxx do
            for y = miny, maxy do
                for z = minz, maxz do

                    local offset = {
                        x = x - minx,
                        y = y - miny,
                        z = z - minz
                    }

                    local src = minetest.get_node({
                        x = x,
                        y = y,
                        z = z
                    })

                    local dst = minetest.get_node({

                        x = pos3.x + offset.x,
                        y = pos3.y + offset.y,
                        z = pos3.z + offset.z

                    })

                    if src.name ~= dst.name then
                        success = false
                        break
                    end

                end
            end
        end

        set_commandblock_result(success)

        if success then
            run_conditional_command(name, exec_if)
        else
            run_conditional_command(name, exec_unless)
        end

        return success, success and "Áreas iguais" or "Áreas diferentes"

    end

})

--------------------------------------------------
minetest.log("action", "[Mineclonia] testfor carregado")
--------------------------------------------------
