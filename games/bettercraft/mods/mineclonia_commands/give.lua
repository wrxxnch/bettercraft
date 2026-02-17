local give_search_cache = {}

local S = core.get_translator(core.get_current_modname())

--------------------------------------------------
-- PARSE PARAMS
--------------------------------------------------

local function parse_params(param)

    local args = {}

    for k, v in param:gmatch("(%w+)=([^\n]+)") do
        args[k] = v:gsub("^\"", ""):gsub("\"$", "")
    end

    return args

end

--------------------------------------------------
-- APPLY META
--------------------------------------------------

local function apply_meta(stack, params)

    local meta = stack:get_meta()

    if params.name then
        meta:set_string("description", params.name)
    end

    return stack

end

--------------------------------------------------
-- GET POINTED NODE VIA RAYCAST
--------------------------------------------------

local function get_pointed_node(player)

    local pos = player:get_pos()
    pos.y = pos.y + 1.5

    local dir = player:get_look_dir()

    local ray = core.raycast(
        pos,
        vector.add(pos, vector.multiply(dir, 10)),
        false,
        false
    )

    for hit in ray do

        if hit.type == "node" then
            return hit.under
        end

    end

    return nil

end

--------------------------------------------------
-- COPY NODE TO STACK WITH META
--------------------------------------------------

local function node_to_stack(pos, use_meta)

    local node = core.get_node(pos)

    if not node then return nil end

    local stack = ItemStack(node.name)

    if use_meta then

        local node_meta = core.get_meta(pos)
        local stack_meta = stack:get_meta()

        local meta_table = node_meta:to_table()

        if meta_table and meta_table.fields then

            for k, v in pairs(meta_table.fields) do
                stack_meta:set_string(k, v)
            end

        end

    end

    return stack

end

--------------------------------------------------
-- GIVE ITEM FUNCTION
--------------------------------------------------

local function give_item(playername, itemname, count, params)

    local player = core.get_player_by_name(playername)

    if not player then
        return false, "Player not found"
    end

    local stack = ItemStack(itemname .. " " .. count)

    stack = apply_meta(stack, params or {})

    player:get_inventory():add_item("main", stack)

    return true, "Given " .. stack:get_name()

end

--------------------------------------------------
-- GIVEME COMMAND
--------------------------------------------------

core.register_chatcommand("giveme", {

    params = "",
    description = "Advanced give command",
    privs = {give = true},

    func = function(name, param)

        local player = core.get_player_by_name(name)

        if not player then
            return false
        end

        local words = {}

        for w in param:gmatch("%S+") do
            table.insert(words, w)
        end

        local cmd = words[1]

        --------------------------------------------------
        -- give_search
        --------------------------------------------------

        if cmd == "give_search" then

            local search = words[2] or ""

            give_search_cache[name] = {}

            local i = 1

            for item,_ in pairs(core.registered_items) do

                if item:lower():find(search:lower(), 1, true) then

                    table.insert(give_search_cache[name], item)

                    core.chat_send_player(name,
                        i..": "..item)

                    i = i + 1

                end

            end

            return true, "Found "..#give_search_cache[name]

        end

        --------------------------------------------------
        -- give_pick
        --------------------------------------------------

        if cmd == "give_pick" then

            local index = tonumber(words[2] or "1")

            local list = give_search_cache[name]

            if not list or not list[index] then
                return false, "Invalid pick"
            end

            return give_item(name, list[index], 1, {})

        end

        --------------------------------------------------
        -- give_pointed
        --------------------------------------------------

        if cmd == "give_pointed" then

            local use_meta = true

            if param:find("meta=false") then
                use_meta = false
            end

            local pos = get_pointed_node(player)

            if not pos then
                return false, "No node pointed"
            end

            local stack = node_to_stack(pos, use_meta)

            if not stack then
                return false, "Failed to copy node"
            end

            player:get_inventory():add_item("main", stack)

            return true, "Given pointed node"

        end

        --------------------------------------------------
        -- NORMAL GIVE
        --------------------------------------------------

        local params = parse_params(param)

        local itemname = words[1]

        if not itemname then
            return false, "No item specified"
        end

        local count = tonumber(words[2] or "1")

        return give_item(name, itemname, count, params)

    end

})

--------------------------------------------------
-- SEPARATE give_search
--------------------------------------------------

core.register_chatcommand("give_search", {

    params = "<text>",
    privs = {give = true},

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
-- give_pick
--------------------------------------------------

core.register_chatcommand("give_pick", {

    params = "<num>",
    privs = {give = true},

    func = function(name, param)

        local num = tonumber(param)

        local list = give_search_cache[name]

        if not list or not list[num] then
            return false, "Invalid number"
        end

        return give_item(name, list[num], 1, {})

    end

})

--------------------------------------------------
-- give_pointed SEPARATE
--------------------------------------------------

core.register_chatcommand("give_pointed", {

    params = "[meta=false]",
    description = "Copy pointed node with metadata",
    privs = {give = true},

    func = function(name, param)

        local player = core.get_player_by_name(name)

        if not player then
            return false, "Player not found"
        end

        local use_meta = true

        if param == "meta=false" then
            use_meta = false
        end

        local pos = get_pointed_node(player)

        if not pos then
            return false, "No node pointed"
        end

        local stack = node_to_stack(pos, use_meta)

        if not stack then
            return false, "Copy failed"
        end

        player:get_inventory():add_item("main", stack)

        return true, "Given pointed node"

    end

})

--------------------------------------------------
-- COMMAND BLOCK META RESTORE
--------------------------------------------------

local function restore_meta(pos, stack)

    local meta = stack:get_meta():to_table()

    if meta and meta.fields then

        local node_meta = core.get_meta(pos)

        for k, v in pairs(meta.fields) do
            node_meta:set_string(k, v)
        end

    end

end

local function override_cb(name)

    core.override_item(name, {

        after_place_node = function(pos, placer, itemstack)

            restore_meta(pos, itemstack)

        end

    })

end

override_cb("mcl_commandblock:commandblock_off")
override_cb("mcl_commandblock:chain_commandblock")
override_cb("mcl_commandblock:repeating_commandblock")
