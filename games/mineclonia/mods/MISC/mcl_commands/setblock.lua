local S = core.get_translator(core.get_current_modname())

-- =========================
-- UTILS
-- =========================
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function resolve_node_name(name)
    while core.registered_aliases[name] do
        name = core.registered_aliases[name]
    end
    if not name:find(":") then
        for regname in pairs(core.registered_nodes) do
            if regname:match(":(.+)$") == name then
                return regname
            end
        end
    end
    return name
end

-- aceita: números | ~ | pos1 | pos2
local function parse_any_pos(player, a, b, c)
    local pname = player:get_player_name()

    if a == "pos1" then
        return postick_get_pos(pname, "pos1")
    end
    if a == "pos2" then
        return postick_get_pos(pname, "pos2")
    end

    local p = vector.round(player:get_pos())
    local function r(v, base)
        if v:sub(1,1) == "~" then
            return base + tonumber(v:sub(2) ~= "" and v:sub(2) or 0)
        end
        return tonumber(v)
    end

    local x,y,z = r(a,p.x), r(b,p.y), r(c,p.z)
    if not (x and y and z) then return nil end
    return {x=x,y=y,z=z}
end

-- =========================
-- TRANSFORMS
-- =========================
local function rotate_rel(pos, size, rot)
    if rot == 90 then
        return { x = size.z-pos.z-1, y=pos.y, z=pos.x }
    elseif rot == 180 then
        return { x = size.x-pos.x-1, y=pos.y, z=size.z-pos.z-1 }
    elseif rot == 270 then
        return { x = pos.z, y=pos.y, z=size.x-pos.x-1 }
    end
    return pos
end

local function mirror_rel(pos, size, axis)
    if axis=="x" then
        return { x=size.x-pos.x-1, y=pos.y, z=pos.z }
    elseif axis=="y" then
        return { x=pos.x, y=size.y-pos.y-1, z=pos.z }
    elseif axis=="z" then
        return { x=pos.x, y=pos.y, z=size.z-pos.z-1 }
    end
    return pos
end

local function rotate_facedir(fd, rot)
    if rot==90 then return (fd+1)%4 end
    if rot==180 then return (fd+2)%4 end
    if rot==270 then return (fd+3)%4 end
    return fd
end

local function mirror_facedir(fd, axis)
    if axis=="x" then
        return ({[1]=3,[3]=1,[0]=0,[2]=2})[fd] or fd
    elseif axis=="z" then
        return ({[0]=2,[2]=0,[1]=1,[3]=3})[fd] or fd
    end
    return fd
end

-- =========================
-- /setblock
-- =========================
core.register_chatcommand("setblock", {
    params = S("<X> <Y> <Z> <block>"),
    description = S("Set node at given position"),
    privs = {
        give = true,
        interact = true
    },

    func = function(_, param)
        local x, y, z, nodestring = param:match("^([%d.-]+)[, ]*([%d.-]+)[, ]*([%d.-]+)%s+(.+)$")

        x, y, z = tonumber(x), tonumber(y), tonumber(z)

        if not (x and y and z and nodestring) then
            return false, S("Invalid parameters (see /help setblock)")
        end

        local nodename = resolve_node_name(nodestring)

        if not core.registered_nodes[nodename] then
            return false, S("Unknown block: @1", nodestring)
        end

        core.set_node({
            x = x,
            y = y,
            z = z
        }, {
            name = nodename,
            param2 = 0
        })

        return true, S("@1 placed.", nodename)
    end
})

-- =========================
-- /setblock_search (sem coordenadas)
-- =========================
core.register_chatcommand("setblock_search", {
    params = S("<search>"),
    description = S("Search block by name and cache results"),
    privs = {
        give = true,
        interact = true
    },

    func = function(name, param)
        if param == "" then
            return false, S("You must provide a search term")
        end

        local player = core.get_player_by_name(name)
        if not player then
            return false
        end

        local search = param:lower()
        local results = {}

        for nodename in pairs(core.registered_nodes) do
            if nodename:lower():find(search, 1, true) then
                results[#results + 1] = nodename
                if #results >= 10 then
                    break
                end
            end
        end

        if #results == 0 then
            return false, S("No blocks found for: @1", search)
        end

        -- salvar cache (NÃO expira)
        local meta = player:get_meta()
        meta:set_string("setblock_search_results", core.serialize(results))

        -- 1 resultado → coloca direto
        if #results == 1 then
            local pos = vector.round(player:get_pos())
            core.set_node(pos, {
                name = results[1],
                param2 = 0
            })
            return true, S("@1 placed and cached.", results[1])
        end

        -- múltiplos → listar
        local msg = S("Cached blocks:\n")
        for i, nodename in ipairs(results) do
            msg = msg .. i .. ": " .. nodename .. "\n"
        end
        msg = msg .. S("Use: /setblock_pick <number>")

        core.chat_send_player(name, msg)
        return true, S("Search cached. You can reuse /setblock_pick.")
    end
})

-- =========================
-- /setblock_pick 
-- =========================
core.register_chatcommand("setblock_pick", {
    params = S("<number>"),
    description = S("Pick cached block and place it at your position"),
    privs = {
        give = true,
        interact = true
    },

    func = function(name, param)
        local idx = tonumber(param)
        if not idx then
            return false, S("Invalid number")
        end

        local player = core.get_player_by_name(name)
        if not player then
            return false
        end

        local meta = player:get_meta()
        local results = core.deserialize(meta:get_string("setblock_search_results"))

        if not (results and results[idx]) then
            return false, S("No cached search result found")
        end

        local pos = vector.round(player:get_pos())
        core.set_node(pos, {
            name = results[idx],
            param2 = 0
        })

        return true, S("@1 placed.", results[idx])
    end
})

--- =========================
-- UNDO STORAGE
-- =========================
local fill_undo = {}
local clone_undo = {}

local function save_undo(tbl,name,pos,node)
    tbl[name]=tbl[name] or {}
    table.insert(tbl[name],{pos=vector.new(pos),node=node.name,param2=node.param2 or 0})
end

-- =========================
-- /UNDO
-- =========================
core.register_chatcommand("undo_fill",{
    func=function(name)
        local d=fill_undo[name]
        if not d or #d==0 then return false,"Nothing to undo." end
        for i=#d,1,-1 do
            core.set_node(d[i].pos,{name=d[i].node,param2=d[i].param2})
        end
        fill_undo[name]={}
        return true,"Fill undone."
    end
})

core.register_chatcommand("undo_clone",{
    func=function(name)
        local d=clone_undo[name]
        if not d or #d==0 then return false,"Nothing to undo." end
        for i=#d,1,-1 do
            core.set_node(d[i].pos,{name=d[i].node,param2=d[i].param2})
        end
        clone_undo[name]={}
        return true,"Clone undone."
    end
})

-- =========================
-- /FILL
-- =========================
core.register_chatcommand("fill",{
    func=function(name,param)
        local P={}
        for w in param:gmatch("%S+") do P[#P+1]=w end
        if #P < 3 then return false,"Invalid parameters." end

        local player = core.get_player_by_name(name)

        local p1, p2, block_i

        if P[1]=="pos1" and P[2]=="pos2" then
            p1 = postick_get_pos(name,"pos1")
            p2 = postick_get_pos(name,"pos2")
            block_i = 3
        else
            if #P < 7 then return false,"Invalid parameters." end
            p1 = parse_any_pos(player,P[1],P[2],P[3])
            p2 = parse_any_pos(player,P[4],P[5],P[6])
            block_i = 7
        end

        if not (p1 and p2) then
            return false,"pos1/pos2 not defined."
        end

        local block = resolve_node_name(P[block_i])
        local mode  = P[block_i+1] or "replace"
        local filter= P[block_i+2]

        fill_undo[name]={}

        local minp=vector.new(math.min(p1.x,p2.x),math.min(p1.y,p2.y),math.min(p1.z,p2.z))
        local maxp=vector.new(math.max(p1.x,p2.x),math.max(p1.y,p2.y),math.max(p1.z,p2.z))

        local keep,neg={},{}
        if mode=="keep" and filter then
            for p in filter:gmatch("[^,]+") do
                p=trim(p)
                if p:sub(1,1)=="!" then neg[resolve_node_name(p:sub(2))]=true
                else keep[resolve_node_name(p)]=true end
            end
        end

        for x=minp.x,maxp.x do for y=minp.y,maxp.y do for z=minp.z,maxp.z do
            local pos={x=x,y=y,z=z}
            local node=core.get_node(pos)

            if mode=="hollow" and x~=minp.x and x~=maxp.x and y~=minp.y and y~=maxp.y and z~=minp.z and z~=maxp.z then goto skip end
            if mode=="destroy" then save_undo(fill_undo,name,pos,node); core.remove_node(pos); goto skip end
            if mode=="replace" and filter and node.name~=resolve_node_name(filter) then goto skip end
            if mode=="keep" then
                if neg[node.name] then goto skip end
                if next(keep) and not keep[node.name] then goto skip end
                if not next(keep) and node.name~="air" then goto skip end
            end

            save_undo(fill_undo,name,pos,node)
            core.set_node(pos,{name=block})
            ::skip::
        end end end

        return true,"Filled."
    end
})

-- =========================
-- /CLONE
-- =========================
core.register_chatcommand("clone",{
    func=function(name,param)
        local P={}
        for w in param:gmatch("%S+") do P[#P+1]=w end
        if #P < 3 then return false,"Invalid parameters." end

        local player = core.get_player_by_name(name)
        local p1,p2,dest,i

        if P[1]=="pos1" and P[2]=="pos2" then
            p1=postick_get_pos(name,"pos1")
            p2=postick_get_pos(name,"pos2")
            dest=parse_any_pos(player,P[3],P[4],P[5])
            i=6
        else
            p1=parse_any_pos(player,P[1],P[2],P[3])
            p2=parse_any_pos(player,P[4],P[5],P[6])
            dest=parse_any_pos(player,P[7],P[8],P[9])
            i=10
        end

        if not (p1 and p2 and dest) then
            return false,"Invalid positions."
        end

        local mode=P[i] or "replace"
        local filter=P[i+1]
        local rotate,mirror

        if mode=="rotate" then rotate=tonumber(filter); mode="replace" end
        if mode=="mirror" then mirror=filter; mode="replace" end

        local minp=vector.new(math.min(p1.x,p2.x),math.min(p1.y,p2.y),math.min(p1.z,p2.z))
        local maxp=vector.new(math.max(p1.x,p2.x),math.max(p1.y,p2.y),math.max(p1.z,p2.z))
        local size=vector.add(vector.subtract(maxp,minp),1)

        clone_undo[name]={}
        local buf={}

        for x=minp.x,maxp.x do for y=minp.y,maxp.y do for z=minp.z,maxp.z do
            local pos={x=x,y=y,z=z}
            local n=core.get_node(pos)
            buf[#buf+1]={rel=vector.subtract(pos,minp),node=n.name,param2=n.param2}
        end end end

        for _,d in ipairs(buf) do
            local rel=d.rel
            if rotate then rel=rotate_rel(rel,size,rotate) end
            if mirror then rel=mirror_rel(rel,size,mirror) end

            local tgt=vector.add(dest,rel)
            local old=core.get_node(tgt)

            if mode=="masked" and d.node=="air" then goto c end
            if mode=="filtered" and d.node~=resolve_node_name(filter) then goto c end

            local p2=d.param2
            if rotate then p2=rotate_facedir(p2,rotate) end
            if mirror then p2=mirror_facedir(p2,mirror) end

            save_undo(clone_undo,name,tgt,old)
            core.set_node(tgt,{name=d.node,param2=p2})
            ::c::
        end

        if mode=="move" then
            for _,d in ipairs(buf) do
                local src=vector.add(minp,d.rel)
                save_undo(clone_undo,name,src,core.get_node(src))
                core.remove_node(src)
            end
        end

        return true,"Cloned."
    end
})