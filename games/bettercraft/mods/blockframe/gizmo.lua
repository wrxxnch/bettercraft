--------------------------------------------------
-- GIZMOS FOR BLOCKFRAME (STABLE NO-CENTER VERSION)
--------------------------------------------------
local function get_parse_vec()
    return blockframe.parse_vec or _G.parse_vec or function(str, def)
        return def
    end
end

local function get_update_props()
    return blockframe.update_entity_properties or _G.update_entity_properties or function()
    end
end

blockframe.gizmos_active = {}
blockframe.gizmo_entities = {}

local GIZMO_RADIUS = 15
local MOVE_STEP = 0.1
local ROT_STEP = 15
local SCALE_STEP = 0.1

--------------------------------------------------
-- SAFE GET PARENT
--------------------------------------------------

local function get_parent(self)
    if not self.parent_id then
        return nil
    end
    if not self.object then
        return nil
    end

    local pos = self.object:get_pos()
    if not pos then
        return nil
    end

    for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 2)) do
        local ent = obj:get_luaentity()
        if ent and ent.name == "blockframe:placed" and tostring(obj) == self.parent_id then
            return obj, ent
        end
    end

    return nil
end

--------------------------------------------------
-- UPDATE GIZMO POSITIONS
--------------------------------------------------

local function update_gizmos_pos(parent_obj)
    local parent_id = tostring(parent_obj)
    local gizmos = blockframe.gizmo_entities[parent_id]
    if not gizmos then
        return
    end

    local pos = parent_obj:get_pos()
    if not pos then
        return
    end

    for _, g_obj in ipairs(gizmos) do
        if g_obj and g_obj:get_luaentity() then
            local g_ent = g_obj:get_luaentity()
            local offset = g_ent.offset or {
                x = 0,
                y = 0,
                z = 0
            }
            g_obj:set_pos(vector.add(pos, offset))
        end
    end
end

--------------------------------------------------
-- REGISTER GIZMO
--------------------------------------------------

local function register_gizmo(name, texture, offset, axis, type, visual_size)

    minetest.register_entity("blockframe:gizmo_" .. name, {

        initial_properties = {
            visual = "sprite",
            textures = {texture},
            visual_size = visual_size or {
                x = 0.6,
                y = 0.6
            },
            physical = false,
            pointable = true,
            glow = 10,
            collisionbox = {-0.2, -0.2, -0.2, 0.2, 0.2, 0.2},
            static_save = false
        },

        on_activate = function(self, staticdata)
            local data = minetest.deserialize(staticdata) or {}
            self.parent_id = data.parent_id
            self.offset = offset
            self.axis = axis
            self.type = type
        end,

        on_step = function(self)
            if not get_parent(self) then
                self.object:remove()
            end
        end,

        on_punch = function(self, puncher)

            local p_obj, p_ent = get_parent(self)
            if not p_ent then
                return
            end

            local parse_vec = get_parse_vec()
            local update_props = get_update_props()

            local args = p_ent.args or {}
            local current_pos = p_obj:get_pos()

            if self.type == "move" then
                current_pos[self.axis] = current_pos[self.axis] + MOVE_STEP
                p_obj:set_pos(current_pos)
                args.pos = current_pos

            elseif self.type == "rotate" then
                local rot = parse_vec(args.rotate, {
                    x = 0,
                    y = 0,
                    z = 0
                })
                rot[self.axis] = (rot[self.axis] or 0) + ROT_STEP
                args.rotate = rot.x .. "," .. rot.y .. "," .. rot.z

            elseif self.type == "scale" then
                local size = parse_vec(args.size, {
                    x = 0.5,
                    y = 0.5,
                    z = 0.5
                })
                size[self.axis] = (size[self.axis] or 0.5) + SCALE_STEP
                args.size = size
            end

            p_ent.args = args
            update_props(p_ent)
            update_gizmos_pos(p_obj)
        end,

        on_rightclick = function(self, clicker)

            local p_obj, p_ent = get_parent(self)
            if not p_ent then
                return
            end

            local parse_vec = get_parse_vec()
            local update_props = get_update_props()

            local args = p_ent.args or {}
            local current_pos = p_obj:get_pos()

            if self.type == "move" then
                current_pos[self.axis] = current_pos[self.axis] - MOVE_STEP
                p_obj:set_pos(current_pos)
                args.pos = current_pos

            elseif self.type == "rotate" then
                local rot = parse_vec(args.rotate, {
                    x = 0,
                    y = 0,
                    z = 0
                })
                rot[self.axis] = (rot[self.axis] or 0) - ROT_STEP
                args.rotate = rot.x .. "," .. rot.y .. "," .. rot.z

            elseif self.type == "scale" then
                local size = parse_vec(args.size, {
                    x = 0.5,
                    y = 0.5,
                    z = 0.5
                })
                size[self.axis] = math.max(0.1, (size[self.axis] or 0.5) - SCALE_STEP)
                args.size = size
            end

            p_ent.args = args
            update_props(p_ent)
            update_gizmos_pos(p_obj)
        end
    })
end

--------------------------------------------------
-- REGISTER AXIS GIZMOS (NO CENTER)
--------------------------------------------------

local axes_textures = {
    x = "blockframe_gizmo_move_x.png",
    y = "blockframe_gizmo_move_y.png",
    z = "blockframe_gizmo_move_z.png"
}

for axis, texture_name in pairs(axes_textures) do

    local move_off = {
        x = 0,
        y = 0,
        z = 0
    }
    move_off[axis] = 1.2
    register_gizmo("move_" .. axis, texture_name, move_off, axis, "move")

    local rot_off = {
        x = 0,
        y = 0,
        z = 0
    }
    rot_off[axis] = 0.8
    register_gizmo("rotate_" .. axis, "blockframe_gizmo_rotate.png", rot_off, axis, "rotate")

    local scale_off = {
        x = 0,
        y = 0,
        z = 0
    }
    scale_off[axis] = -1.2
    register_gizmo("scale_" .. axis, "blockframe_gizmo_scale.png", scale_off, axis, "scale")
end

--------------------------------------------------
-- REMOVE GIZMOS
--------------------------------------------------

function blockframe.remove_gizmos(parent_id)
    if blockframe.gizmo_entities[parent_id] then
        for _, obj in ipairs(blockframe.gizmo_entities[parent_id]) do
            if obj and obj:get_luaentity() then
                obj:remove()
            end
        end
        blockframe.gizmo_entities[parent_id] = nil
    end
end

--------------------------------------------------
-- SPAWN GIZMOS
--------------------------------------------------

function blockframe.spawn_gizmos_for(obj)
    local parent_id = tostring(obj)
    blockframe.remove_gizmos(parent_id)

    local pos = obj:get_pos()
    local entities = {}

    for _, axis in ipairs({"x", "y", "z"}) do
        local m = minetest.add_entity(pos, "blockframe:gizmo_move_" .. axis, minetest.serialize({
            parent_id = parent_id
        }))
        if m then
            table.insert(entities, m)
        end

        local r = minetest.add_entity(pos, "blockframe:gizmo_rotate_" .. axis, minetest.serialize({
            parent_id = parent_id
        }))
        if r then
            table.insert(entities, r)
        end

        local s = minetest.add_entity(pos, "blockframe:gizmo_scale_" .. axis, minetest.serialize({
            parent_id = parent_id
        }))
        if s then
            table.insert(entities, s)
        end
    end

    blockframe.gizmo_entities[parent_id] = entities
    update_gizmos_pos(obj)
end
--------------------------------------------------
-- CHAT COMMAND
--------------------------------------------------

minetest.register_chatcommand("blockframe_gizmos", {
    description = "Enable/Disable blockframe editing gizmos",
    func = function(name)
        if blockframe.gizmos_active[name] then
            blockframe.gizmos_active[name] = false
            for p_id, _ in pairs(blockframe.gizmo_entities) do
                blockframe.remove_gizmos(p_id)
            end
            return true, "Gizmos disabled."
        else
            blockframe.gizmos_active[name] = true
            local player = minetest.get_player_by_name(name)
            if not player then
                return false
            end

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

            return true, "Gizmos enabled for " .. count .. " blockframes."
        end
    end
})
