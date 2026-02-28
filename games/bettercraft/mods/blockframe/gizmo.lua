
--------------------------------------------------
-- GIZMOS FOR BLOCKFRAME
--------------------------------------------------

blockframe.gizmos_active = {} -- [player_name] = true/false
blockframe.gizmo_entities = {} -- [parent_id] = {list of gizmo objects}

local GIZMO_RADIUS = 15
local MOVE_STEP = 0.1
local ROT_STEP = 15
local SCALE_STEP = 0.1

-- Helper to find a gizmo's parent
local function get_parent(self)
    if not self.parent_id then return nil end
    for _, obj in ipairs(minetest.get_objects_inside_radius(self.object:get_pos(), 2)) do
        local ent = obj:get_luaentity()
        if ent and ent.name == "blockframe:placed" and tostring(obj) == self.parent_id then
            return obj, ent
        end
    end
    return nil
end

-- Update all gizmos position relative to parent
local function update_gizmos_pos(parent_obj)
    local parent_id = tostring(parent_obj)
    local gizmos = blockframe.gizmo_entities[parent_id]
    if not gizmos then return end
    
    local pos = parent_obj:get_pos()
    for _, g_obj in ipairs(gizmos) do
        local g_ent = g_obj:get_luaentity()
        if g_ent then
            local offset = g_ent.offset or {x=0,y=0,z=0}
            g_obj:set_pos(vector.add(pos, offset))
        end
    end
end

-- Base Gizmo Entity
local function register_gizmo(name, color, offset, axis, type)
    minetest.register_entity("blockframe:gizmo_" .. name, {
        initial_properties = {
            visual = "cube",
            visual_size = {x=0.1, y=0.1, z=0.1},
            textures = {color, color, color, color, color, color},
            physical = false,
            pointable = true,
            glow = 14,
            static_save = false,
        },
        on_activate = function(self, staticdata)
            local data = minetest.deserialize(staticdata) or {}
            self.parent_id = data.parent_id
            self.offset = offset
            self.axis = axis
            self.type = type -- "move", "rotate", "scale"
        end,
        on_punch = function(self, puncher)
            local p_obj, p_ent = get_parent(self)
            if not p_ent then return end
            
            local args = p_ent.args
            if self.type == "move" then
                local pos = p_obj:get_pos()
                pos[self.axis] = pos[self.axis] + MOVE_STEP
                p_obj:set_pos(pos)
                args.pos = pos
            elseif self.type == "rotate" then
                local rot = parse_vec(args.rotate, {x=0,y=0,z=0})
                rot[self.axis] = (rot[self.axis] or 0) + ROT_STEP
                args.rotate = rot.x..","..rot.y..","..rot.z
            elseif self.type == "scale" then
                local size = parse_vec(args.size, {x=0.5,y=0.5,z=0.5})
                size[self.axis] = (size[self.axis] or 0.5) + SCALE_STEP
                args.size = size
            end
            
            update_entity_properties(p_ent)
            update_gizmos_pos(p_obj)
        end,
        on_rightclick = function(self, clicker)
            local p_obj, p_ent = get_parent(self)
            if not p_ent then return end
            
            local args = p_ent.args
            if self.type == "move" then
                local pos = p_obj:get_pos()
                pos[self.axis] = pos[self.axis] - MOVE_STEP
                p_obj:set_pos(pos)
                args.pos = pos
            elseif self.type == "rotate" then
                local rot = parse_vec(args.rotate, {x=0,y=0,z=0})
                rot[self.axis] = (rot[self.axis] or 0) - ROT_STEP
                args.rotate = rot.x..","..rot.y..","..rot.z
            elseif self.type == "scale" then
                local size = parse_vec(args.size, {x=0.5,y=0.5,z=0.5})
                size[self.axis] = math.max(0.1, (size[self.axis] or 0.5) - SCALE_STEP)
                args.size = size
            end
            
            update_entity_properties(p_ent)
            update_gizmos_pos(p_obj)
        end
    })
end

-- Register X, Y, Z gizmos for each type
local colors = {x="red", y="green", z="blue"}
for axis, color in pairs(colors) do
    -- Move (Arrows/Cubes further out)
    local move_off = {x=0, y=0, z=0}
    move_off[axis] = 1.2
    register_gizmo("move_"..axis, color, move_off, axis, "move")
    
    -- Rotate (Closer)
    local rot_off = {x=0, y=0, z=0}
    rot_off[axis] = 0.8
    register_gizmo("rotate_"..axis, "yellow", rot_off, axis, "rotate")
    
    -- Scale (Opposite or different offset)
    local scale_off = {x=0, y=0, z=0}
    scale_off[axis] = -1.2
    register_gizmo("scale_"..axis, "purple", scale_off, axis, "scale")
end

function blockframe.remove_gizmos(parent_id)
    if blockframe.gizmo_entities[parent_id] then
        for _, obj in ipairs(blockframe.gizmo_entities[parent_id]) do
            obj:remove()
        end
        blockframe.gizmo_entities[parent_id] = nil
    end
end

function blockframe.spawn_gizmos_for(obj)
    local parent_id = tostring(obj)
    blockframe.remove_gizmos(parent_id)
    
    local pos = obj:get_pos()
    local entities = {}
    
    local axes = {"x", "y", "z"}
    for _, axis in ipairs(axes) do
        -- Spawn Move
        local m = minetest.add_entity(pos, "blockframe:gizmo_move_"..axis, minetest.serialize({parent_id = parent_id}))
        table.insert(entities, m)
        -- Spawn Rotate
        local r = minetest.add_entity(pos, "blockframe:gizmo_rotate_"..axis, minetest.serialize({parent_id = parent_id}))
        table.insert(entities, r)
        -- Spawn Scale
        local s = minetest.add_entity(pos, "blockframe:gizmo_scale_"..axis, minetest.serialize({parent_id = parent_id}))
        table.insert(entities, s)
    end
    
    blockframe.gizmo_entities[parent_id] = entities
    update_gizmos_pos(obj)
end

minetest.register_chatcommand("blockframe_gizmos", {
    description = "Ativa/Desativa gizmos de edição para blockframes próximos",
    func = function(name)
        if blockframe.gizmos_active[name] then
            blockframe.gizmos_active[name] = false
            -- Clean up all gizmos
            for p_id, _ in pairs(blockframe.gizmo_entities) do
                blockframe.remove_gizmos(p_id)
            end
            return true, "Gizmos desativados."
        else
            blockframe.gizmos_active[name] = true
            local player = minetest.get_player_by_name(name)
            local pos = player:get_pos()
            local objects = minetest.get_objects_inside_radius(pos, GIZMO_RADIUS)
            local count = 0
            for _, obj in ipairs(objects) do
                local ent = obj:get_luaentity()
                if ent and ent.name == "blockframe:placed" then
                    blockframe.spawn_gizmos_for(obj)
                    count = count + 1
                end
            end
            return true, "Gizmos ativados para " .. count .. " blockframes."
        end
    end
})
