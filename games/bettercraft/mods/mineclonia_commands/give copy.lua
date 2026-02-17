local S = core.get_translator(core.get_current_modname())

local give_search_cache = {}

--------------------------------------------------
-- PARSER DE PARAMETROS
--------------------------------------------------

local function parse_params(param)

    local args = {}
    local extras = {}

    for token in param:gmatch("%S+") do

        local key, value = token:match("(%w+)%=(.+)")

        if key then
            extras[key] = value:gsub("^\"", ""):gsub("\"$", "")
        else
            table.insert(args, token)
        end

    end

    return args, extras

end

--------------------------------------------------
-- APLICAR META
--------------------------------------------------

local function apply_meta(stack, extras)

    local meta = stack:get_meta()

    if extras.name then
        meta:set_string("description", extras.name)
    end

    if extras.enchant then
        meta:set_string("enchants", extras.enchant)
    end

    if extras.hiteffect then
        meta:set_string("hit_effect", extras.hiteffect)
    end

    if extras.holdeffect then
        meta:set_string("hold_effect", extras.holdeffect)
    end

    return stack

end

--------------------------------------------------
-- GIVE CORE
--------------------------------------------------

local function give_item(playername, itemname, count, extras)

    local player = core.get_player_by_name(playername)

    if not player then
        return false, "Player not found"
    end

    if not core.registered_items[itemname] then
        return false, "Item does not exist"
    end

    local stack = ItemStack(itemname.." "..count)

    stack = apply_meta(stack, extras)

    local inv = player:get_inventory()

    inv:add_item("main", stack)

    return true, "Given "..itemname

end

--------------------------------------------------
-- GIVE COMMAND
--------------------------------------------------

core.register_chatcommand("give", {

    params = "<player> <item> [count] [name=...] [enchant=...]",

    privs = {give=true},

    func = function(name, param)

        local args, extras = parse_params(param)

        local player = args[1]
        local item = args[2]
        local count = tonumber(args[3]) or 1

        if not player or not item then
            return false, "/give <player> <item>"
        end

        return give_item(player, item, count, extras)

    end

})

--------------------------------------------------
-- GIVEME COMMAND
--------------------------------------------------

core.register_chatcommand("giveme", {

    params = "<item> [count] ...",

    privs = {give=true},

    func = function(name, param)

        local args, extras = parse_params(param)

        local item = args[1]
        local count = tonumber(args[2]) or 1

        if not item then
            return false, "/giveme <item>"
        end

        return give_item(name, item, count, extras)

    end

})

--------------------------------------------------
-- SEARCH
--------------------------------------------------

core.register_chatcommand("give_search", {

    params = "<text>",

    func = function(name, param)

        give_search_cache[name] = {}

        local i = 1

        for item,_ in pairs(core.registered_items) do

            if item:lower():find(param:lower(), 1, true) then

                table.insert(give_search_cache[name], item)

                core.chat_send_player(name,
                    i..": "..item)

                i = i + 1

            end

        end

        return true, "Found "..#give_search_cache[name]

    end

})

--------------------------------------------------
-- PICK
--------------------------------------------------

core.register_chatcommand("give_pick", {

    params = "<num>",

    func = function(name, param)

        local num = tonumber(param)

        local list = give_search_cache[name]

        if not list or not list[num] then
            return false, "Invalid number"
        end

        return give_item(name, list[num], 1, {})

    end

})
