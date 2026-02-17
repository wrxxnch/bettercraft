-- =========================
-- GIVE_POINTED COMMAND
-- Copia item/node com metadata completo
-- incluindo Command Block
-- =========================


local last_search = {}

-- =========================
-- PARSE PARAMS
-- =========================

local function parse_params(param)

    local args = {}

    for k, v in param:gmatch("(%w+)=([^\n]+)") do
        args[k] = v:gsub("^\"", ""):gsub("\"$", "")
    end

    return args
end


-- =========================
-- APPLY META
-- =========================

local function apply_meta(stack, params)

    local meta = stack:get_meta()

    if params.name then
        meta:set_string("description", params.name)
    end

    if params.enchant then
        meta:set_string("enchantments", params.enchant)
    end

    if params.hiteffect then
        meta:set_string("hit_effect", params.hiteffect)
    end

    if params.holdeffect then
        meta:set_string("hold_effect", params.holdeffect)
    end

    return stack
end


-- =========================
-- GET POINTED ITEM
-- =========================

local function get_pointed_stack(player, use_meta)

    local pointed = player:get_pointed_thing()

    if not pointed then
        return nil
    end


    -- NODE
    if pointed.type == "node" then

        local pos = pointed.under
        local node = core.get_node(pos)

        local stack = ItemStack(node.name)

        if use_meta then

            local meta = core.get_meta(pos)

            stack:get_meta():from_table(meta:to_table())

        end

        return stack
    end


    -- OBJECT
    if pointed.type == "object" then

        local obj = pointed.ref

        if obj and obj:is_player() then

            return obj:get_wielded_item()

        end

        if obj and obj:get_luaentity() then

            local ent = obj:get_luaentity()

            if ent.itemstring then
                return ItemStack(ent.itemstring)
            end

        end

    end

    return nil

end



-- =========================
-- COMMAND
-- =========================

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


        -- =========================
        -- SEARCH
        -- =========================

        if cmd == "give_search" then

            local search = words[2] or ""

            last_search[name] = {}

            for item, def in pairs(core.registered_items) do

                if item:lower():find(search:lower()) then
                    table.insert(last_search[name], item)
                end

            end

            return true, "Found "..#last_search[name].." items"

        end


        -- =========================
        -- PICK
        -- =========================

        if cmd == "give_pick" then

            local index = tonumber(words[2] or "1")

            if not last_search[name] or not last_search[name][index] then
                return false, "Invalid pick"
            end

            local stack = ItemStack(last_search[name][index])

            player:get_inventory():add_item("main", stack)

            return true, "Given "..stack:get_name()

        end


        -- =========================
        -- POINTED (old)
        -- =========================

        if cmd == "pointed" then

            local params = parse_params(param)

            local use_meta = true

            if params.meta == "false" then
                use_meta = false
            end

            local stack = get_pointed_stack(player, use_meta)

            if not stack then
                return false, "Nothing pointed"
            end

            stack = apply_meta(stack, params)

            player:get_inventory():add_item("main", stack)

            return true, "Given pointed item"

        end



        -- =========================
        -- NEW: GIVE_POINTED
        -- =========================

        if cmd == "give_pointed" then

            local params = parse_params(param)

            local use_meta = true

            if params.meta == "false" then
                use_meta = false
            end

            local stack = get_pointed_stack(player, use_meta)

            if not stack then
                return false, "Nothing pointed"
            end

            stack = apply_meta(stack, params)

            player:get_inventory():add_item("main", stack)

            return true, "Given pointed item via give_pointed"

        end



        -- =========================
        -- NORMAL GIVE
        -- =========================

        local params = parse_params(param)

        local itemname = words[1]

        if not itemname then
            return false, "No item specified"
        end

        local count = tonumber(words[2] or "1")

        local stack = ItemStack(itemname.." "..count)

        stack = apply_meta(stack, params)

        player:get_inventory():add_item("main", stack)

        return true, "Given "..stack:get_name()

    end

})


core.register_chatcommand("give_pointed", {
    params = "[meta=false]",
    description = "Give pointed node with full metadata",
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


        -- raycast
        local pos = player:get_pos()
        pos.y = pos.y + 1.5

        local dir = player:get_look_dir()

        local ray = core.raycast(
            pos,
            vector.add(pos, vector.multiply(dir, 10)),
            false,
            false
        )

        local pointed
        for hit in ray do
            pointed = hit
            break
        end

        if not pointed or pointed.type ~= "node" then
            return false, "No node pointed"
        end


        local node = core.get_node(pointed.under)

        if not node then
            return false, "Invalid node"
        end


        local stack = ItemStack(node.name)


        if use_meta then

            local node_meta = core.get_meta(pointed.under)
            local stack_meta = stack:get_meta()

            local meta_table = node_meta:to_table()

            if meta_table and meta_table.fields then

                -- copiar TODOS os campos
                for k, v in pairs(meta_table.fields) do
                    stack_meta:set_string(k, v)
                end

            end

        end


        player:get_inventory():add_item("main", stack)


        -- debug
        local cmd = stack:get_meta():get_string("commands")

        if cmd and cmd ~= "" then
            -- core.chat_send_player(name, "Command copied: " .. cmd)
        else
            -- core.chat_send_player(name, "No command metadata found")
        end


        return true, "Given: "..node.name

    end
})
