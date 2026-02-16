local S = core.get_translator(core.get_current_modname())
local F = core.formspec_escape

-- =========================================================
-- SETTING
-- =========================================================

local msg_not_activated = S("Command blocks are disabled")

local function commandblocks_enabled()
    return core.settings:get_bool("mcl_enable_commandblocks", true)
end

-- =========================================================
-- VECTOR HELPERS
-- =========================================================

local vector_sub = vector.subtract or function(p1, p2)
    return {
        x = p1.x - p2.x,
        y = p1.y - p2.y,
        z = p1.z - p2.z
    }
end

local vector_add = vector.add or function(p1, p2)
    return {
        x = p1.x + p2.x,
        y = p1.y + p2.y,
        z = p1.z + p2.z
    }
end

-- =========================================================
-- SAFE REDSTONE
-- =========================================================

local function safe_get_power(pos)

    if not mcl_redstone or not mcl_redstone.get_power then
        return false
    end

    local ok, power = pcall(mcl_redstone.get_power, pos)

    if ok then
        return (power or 0) > 0
    end

    return false
end

-- =========================================================
-- CONDITIONAL CHECK
-- =========================================================

local function get_success_behind(pos)

    local node = core.get_node(pos)
    local dir = core.facedir_to_dir(node.param2)

    local behind = vector_sub(pos, dir)

    local meta = core.get_meta(behind)

    return meta:get_int("success_count") > 0
end

-- =========================================================
-- SELECTOR RESOLUTION
-- =========================================================

local function resolve_commands(commands, pos)

    local players = core.get_connected_players()
    local meta = core.get_meta(pos)

    local commander = meta:get_string("commander")

    local SUBSTITUTE = "\26"

    if #players == 0 then

        commands = commands:gsub("[^\r\n]+", function(line)

            line = line:gsub("@@", SUBSTITUTE)

            if line:find("@p")
            or line:find("@r")
            or line:find("@f")
            or line:find("@n")
            then
                return ""
            end

            line = line:gsub("@c", commander)
            line = line:gsub(SUBSTITUTE, "@")

            return line

        end)

        return commands
    end

    local nearest, farthest
    local min = math.huge
    local max = -1

    for _,player in pairs(players) do

        local dist = vector.distance(pos, player:get_pos())

        if dist < min then
            min = dist
            nearest = player:get_player_name()
        end

        if dist > max then
            max = dist
            farthest = player:get_player_name()
        end

    end

    local random = players[math.random(#players)]:get_player_name()

    commands = commands:gsub("@@", SUBSTITUTE)
    commands = commands:gsub("@p", nearest)
    commands = commands:gsub("@n", nearest)
    commands = commands:gsub("@f", farthest)
    commands = commands:gsub("@r", random)
    commands = commands:gsub("@c", commander)
    commands = commands:gsub(SUBSTITUTE, "@")

    return commands
end

-- =========================================================
-- RELATIVE COORDS
-- =========================================================

local function resolve_relative_coords(param, pos)

    local axis = {"x","y","z"}
    local index = 1

    return param:gsub("~([%-]?[%d%.]*)", function(offset)

        local a = axis[index]

        index = index + 1
        if index > 3 then index = 1 end

        local base = pos[a]

        if offset == "" then
            return tostring(base)
        end

        return tostring(base + tonumber(offset))
    end)
end

-- =========================================================
-- EXECUTION (DISABLED VIA SETTING)
-- =========================================================

local function execute_commandblock(pos)

    local meta = core.get_meta(pos)

    -- setting desativada → não executa
    if not commandblocks_enabled() then

        meta:set_int("success_count", 0)

        return
    end

    local node = core.get_node(pos)

    if meta:get_int("conditional") == 1 then

        if not get_success_behind(pos) then

            meta:set_int("success_count",0)

            return
        end

    end

    local commander = meta:get_string("commander")

    local commands = resolve_commands(
        meta:get_string("commands"),
        pos
    )

    local success_count = 0

    for _,command in pairs(commands:split("\n")) do

        if command ~= "" then

            local cpos = command:find(" ")

            local cmd =
                cpos and command:sub(1,cpos-1)
                or command

            local param =
                cpos and command:sub(cpos+1)
                or ""

            local def = core.chatcommands[cmd]

            if def then

                if meta:get_int("exec_mode") == 1 then
                    param = resolve_relative_coords(param,pos)
                end

                local ok,msg =
                    def.func(commander,param)

                if ok ~= false then
                    success_count = success_count + 1
                end

            end

        end

    end

    meta:set_int("success_count", success_count)

    local dir = core.facedir_to_dir(node.param2)

    local front = vector_add(pos,dir)

    local front_node = core.get_node(front)

    if front_node and front_node.name:find("chain") then

        local front_meta = core.get_meta(front)

        if front_meta:get_int("auto")==1
        or safe_get_power(front)
        then
            execute_commandblock(front)
        end

    end

end

-- =========================================================
-- UPDATE
-- =========================================================

local function update_commandblock(pos)

    local meta = core.get_meta(pos)

    local auto = meta:get_int("auto")==1
    local powered = safe_get_power(pos)

    local node = core.get_node(pos)

    if node.name:find("repeating") then

        if auto or powered then

            if not core.get_node_timer(pos):is_started() then
                core.get_node_timer(pos):start(0.1)
            end

        else
            core.get_node_timer(pos):stop()
        end

    elseif node.name:find("chain") then

        if auto or powered then
            execute_commandblock(pos)
        end

    else

        if (auto or powered)
        and meta:get_int("was_powered")==0 then

            execute_commandblock(pos)

        end

        meta:set_int(
            "was_powered",
            (auto or powered) and 1 or 0
        )

    end

end
