--------------------------------------------------
-- BLOCKFRAME GIZMO SYSTEM (FULL WORKING)
--------------------------------------------------
blockframe.gizmo_entities = {}
blockframe.active_parent = nil

local MOVE_STEP = 0.1
local ROTATE_STEP = math.rad(15)
local SCALE_STEP = 0.1

--------------------------------------------------
-- SAFE GET PARENT
--------------------------------------------------

local function get_parent(self)
    if self.parent and self.parent:get_luaentity() then
        return self.parent
    end
    return nil
end

--------------------------------------------------
-- REMOVE GIZMOS
--------------------------------------------------

function blockframe.remove_gizmos(parent_obj)

    if not parent_obj then
        return
    end

    local list = blockframe.gizmo_entities[parent_obj]
    if list then
        for _, obj in ipairs(list) do
            if obj and obj:get_luaentity() then
                obj:remove()
            end
        end
    end

    blockframe.gizmo_entities[parent_obj] = nil

    if blockframe.active_parent == parent_obj then
        blockframe.active_parent = nil
    end
end

--------------------------------------------------
-- REMOVE ALL GIZMOS
--------------------------------------------------

local function remove_all_gizmos()

    for parent, _ in pairs(blockframe.gizmo_entities) do
        blockframe.remove_gizmos(parent)
    end
end

--------------------------------------------------
-- SPAWN AXIS GIZMOS
--------------------------------------------------

local function spawn_axis_gizmos(parent_obj)

    remove_all_gizmos()
    blockframe.active_parent = parent_obj

    local pos = parent_obj:get_pos()
    local entities = {}

    local gizmos = { -- MOVE
    {
        type = "move",
        axis = "x",
        tex = "blockframe_gizmo_move_x.png",
        off = {
            x = 1.5,
            y = 0,
            z = 0
        }
    }, {
        type = "move",
        axis = "y",
        tex = "blockframe_gizmo_move_y.png",
        off = {
            x = 0,
            y = 1.5,
            z = 0
        }
    }, {
        type = "move",
        axis = "z",
        tex = "blockframe_gizmo_move_z.png",
        off = {
            x = 0,
            y = 0,
            z = 1.5
        }
    }, -- ROTATE
    {
        type = "rotate",
        axis = "x",
        tex = "blockframe_gizmo_rotate.png",
        off = {
            x = -1.5,
            y = 0,
            z = 0
        }
    }, {
        type = "rotate",
        axis = "y",
        tex = "blockframe_gizmo_rotate.png",
        off = {
            x = 0,
            y = -1.5,
            z = 0
        }
    }, {
        type = "rotate",
        axis = "z",
        tex = "blockframe_gizmo_rotate.png",
        off = {
            x = 0,
            y = 0,
            z = -1.5
        }
    }, -- SCALE
    {
        type = "scale",
        axis = "x",
        tex = "blockframe_gizmo_scale.png",
        off = {
            x = 2.5,
            y = 0,
            z = 0
        }
    }, {
        type = "scale",
        axis = "y",
        tex = "blockframe_gizmo_scale.png",
        off = {
            x = 0,
            y = 2.5,
            z = 0
        }
    }, {
        type = "scale",
        axis = "z",
        tex = "blockframe_gizmo_scale.png",
        off = {
            x = 0,
            y = 0,
            z = 2.5
        }
    }}

    for _, data in ipairs(gizmos) do

        local obj = minetest.add_entity(vector.add(pos, data.off), "blockframe:gizmo_axis")

        if obj then

            local ent = obj:get_luaentity()
            ent.parent = parent_obj
            ent.gizmo_type = data.type
            ent.axis = data.axis
            ent.offset = data.off

            obj:set_properties({
                visual = "sprite",
                textures = {data.tex},
                visual_size = {
                    x = 0.7,
                    y = 0.7
                },
                glow = 10,
                physical = false,
                pointable = true,
                use_texture_alpha = true
            })

            table.insert(entities, obj)
        end
    end

    blockframe.gizmo_entities[parent_obj] = entities
end

--------------------------------------------------
-- CENTER GIZMO
--------------------------------------------------

function blockframe.spawn_center(parent_obj)

    if not parent_obj then
        return
    end

    blockframe.remove_gizmos(parent_obj)

    local pos = parent_obj:get_pos()
    local entities = {}

    local center = minetest.add_entity(pos, "blockframe:gizmo_center")
    if center then
        center:get_luaentity().parent = parent_obj
        table.insert(entities, center)
    end

    blockframe.gizmo_entities[parent_obj] = entities
end

minetest.register_entity("blockframe:gizmo_center", {

    initial_properties = {
        visual = "sprite",
        textures = {"blockframe_gizmo_center.png"},
        visual_size = {
            x = 0.3,
            y = 0.3
        },
        glow = 8,
        physical = false,
        pointable = true,
        use_texture_alpha = true
    },

    on_punch = function(self)

        local parent = get_parent(self)
        if not parent then
            return
        end

        if blockframe.active_parent == parent then
            blockframe.remove_gizmos(parent)
        else
            spawn_axis_gizmos(parent)
        end
    end,

    on_step = function(self)

        local parent = get_parent(self)
        if not parent then
            self.object:remove()
            return
        end

        self.object:set_pos(parent:get_pos())
    end
})

--------------------------------------------------
-- AXIS GIZMO
--------------------------------------------------

minetest.register_entity("blockframe:gizmo_axis", {

    on_punch = function(self)
        self.object:set_hp(1000)

        local parent = get_parent(self)
        if not parent then
            return
        end

        --------------------------------------------------
        -- MOVE
        --------------------------------------------------
        if self.gizmo_type == "move" then

            local pos = parent:get_pos()
            pos[self.axis] = pos[self.axis] + MOVE_STEP
            parent:set_pos(pos)

            local ent = parent:get_luaentity()
            if ent then
                ent.args = ent.args or {}
                ent.args.pos = pos
            end

            --------------------------------------------------
            -- ROTATE
            --------------------------------------------------
        elseif self.gizmo_type == "rotate" then

            local rot = parent:get_rotation() or {
                x = 0,
                y = 0,
                z = 0
            }

            if self.axis == "x" then
                rot.x = rot.x + ROTATE_STEP
            elseif self.axis == "y" then
                rot.y = rot.y + ROTATE_STEP
            elseif self.axis == "z" then
                rot.z = rot.z + ROTATE_STEP
            end

            parent:set_rotation(rot)

            local ent = parent:get_luaentity()
            if ent then
                ent.args = ent.args or {}
                ent.args.rotate = {
                    x = math.deg(rot.x),
                    y = math.deg(rot.y),
                    z = math.deg(rot.z)
                }
            end

            --------------------------------------------------
            -- SCALE
            --------------------------------------------------
        elseif self.gizmo_type == "scale" then

            local props = parent:get_properties()
            local size = props.visual_size or {
                x = 1,
                y = 1
            }

            if self.axis == "x" then
                size.x = size.x + SCALE_STEP
            elseif self.axis == "y" then
                size.y = size.y + SCALE_STEP
            elseif self.axis == "z" then
                size.x = size.x + SCALE_STEP
                size.y = size.y + SCALE_STEP
            end

            parent:set_properties({
                visual_size = size
            })

            local ent = parent:get_luaentity()
            if ent then
                ent.args = ent.args or {}
                ent.args.size = {
                    x = size.x / 2,
                    y = size.y / 2,
                    z = size.x / 2
                }
            end
        end
    end,

    on_rightclick = function(self)

        local parent = get_parent(self)
        if not parent then
            return
        end

        --------------------------------------------------
        -- MOVE
        --------------------------------------------------
        if self.gizmo_type == "move" then

            local pos = parent:get_pos()
            pos[self.axis] = pos[self.axis] - MOVE_STEP
            parent:set_pos(pos)

            local ent = parent:get_luaentity()
            if ent then
                ent.args = ent.args or {}
                ent.args.pos = pos
            end

            --------------------------------------------------
            -- ROTATE
            --------------------------------------------------
        elseif self.gizmo_type == "rotate" then

            local rot = parent:get_rotation() or {
                x = 0,
                y = 0,
                z = 0
            }

            if self.axis == "x" then
                rot.x = rot.x - ROTATE_STEP
            elseif self.axis == "y" then
                rot.y = rot.y - ROTATE_STEP
            elseif self.axis == "z" then
                rot.z = rot.z - ROTATE_STEP
            end

            parent:set_rotation(rot)

            local ent = parent:get_luaentity()
            if ent then
                ent.args = ent.args or {}
                ent.args.rotate = {
                    x = math.deg(rot.x),
                    y = math.deg(rot.y),
                    z = math.deg(rot.z)
                }
            end

            --------------------------------------------------
            -- SCALE
            --------------------------------------------------
        elseif self.gizmo_type == "scale" then

            local props = parent:get_properties()
            local size = props.visual_size or {
                x = 1,
                y = 1
            }

            if self.axis == "x" then
                size.x = math.max(0.1, size.x - SCALE_STEP)
            elseif self.axis == "y" then
                size.y = math.max(0.1, size.y - SCALE_STEP)
            elseif self.axis == "z" then
                size.x = math.max(0.1, size.x - SCALE_STEP)
                size.y = math.max(0.1, size.y - SCALE_STEP)
            end

            parent:set_properties({
                visual_size = size
            })

            local ent = parent:get_luaentity()
            if ent then
                ent.args = ent.args or {}
                ent.args.size = {
                    x = size.x / 2,
                    y = size.y / 2,
                    z = size.x / 2
                }
            end
        end
    end,

    on_step = function(self)

        local parent = get_parent(self)
        if not parent then
            self.object:remove()
            return
        end

        local base = parent:get_pos()
        self.object:set_pos(vector.add(base, self.offset))
    end
})

--------------------------------------------------
-- SPAWN CENTER
--------------------------------------------------

function blockframe.spawn_gizmos_for(obj)

    local pos = obj:get_pos()

    local center = minetest.add_entity(pos, "blockframe:gizmo_center")
    if center then
        local ent = center:get_luaentity()
        ent.parent = obj
    end
end
--------------------------------------------------
-- CHAT COMMAND
--------------------------------------------------

--------------------------------------------------
-- CHAT COMMAND (TOGGLE)
--------------------------------------------------

minetest.register_chatcommand("blockframe_gizmos", {
    description = "Toggle ALL gizmos (remove or show centers)",
    func = function(name)

        local player = minetest.get_player_by_name(name)
        if not player then
            return false
        end

        local pos = player:get_pos()
        local objects = minetest.get_objects_inside_radius(pos, 15)

        --------------------------------------------------
        -- VERIFICA SE EXISTE ALGUM GIZMO ATIVO
        --------------------------------------------------

        local any_active = false
        for parent, _ in pairs(blockframe.gizmo_entities) do
            any_active = true
            break
        end

        --------------------------------------------------
        -- SE EXISTE → REMOVE TODOS
        --------------------------------------------------

        if any_active then

            for parent, _ in pairs(blockframe.gizmo_entities) do
                blockframe.remove_gizmos(parent)
            end

            blockframe.gizmo_entities = {}
            blockframe.active_parent = nil

            return true, "Todos os gizmos removidos."

        end

        --------------------------------------------------
        -- SE NÃO EXISTE → MOSTRA APENAS CENTERS
        --------------------------------------------------

        local shown = 0

        for _, obj in ipairs(objects) do
            local ent = obj:get_luaentity()

            if ent and ent.name == "blockframe:placed" then
                blockframe.spawn_center(obj)
                shown = shown + 1
            end
        end

        return true, "Centers mostrados: " .. shown
    end
})