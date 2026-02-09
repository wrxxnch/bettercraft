-- Mineclonia Trap API and Nodes
-- Implementation of register_trap for fragile blocks that break when stepped on.

local S = minetest.get_translator(minetest.get_current_modname())
local modname = minetest.get_current_modname()

-- Global table for the API
mcl_traps = {}

-- Function to register a trap node
-- @param base_node: the node to copy properties from (e.g., "mcl_core:dirt")
function mcl_traps.register_trap(base_node)
    -- Extract the name after the colon (e.g., "dirt" from "mcl_core:dirt")
    local base_name = base_node:match(":(.*)") or base_node
    local node_name = modname .. ":fragile_" .. base_name
    
    -- Get the definition of the base node
    local base_def = minetest.registered_nodes[base_node]
    if not base_def then
        minetest.log("warning", "[mcl_traps] Base node " .. base_node .. " not found, skipping.")
        return
    end

    -- Extract texture (Top face)
    local texture = "default_dirt.png"
    if base_def.tiles then
        if type(base_def.tiles[1]) == "string" then
            texture = base_def.tiles[1]
        elseif type(base_def.tiles[1]) == "table" then
            texture = base_def.tiles[1].name or base_def.tiles[1]
        end
    end

    -- Prepare node definition
    local node_groups = table.copy(base_def.groups or {})
    -- Ensure the trap NEVER falls, even if the base node (sand/gravel) does
    node_groups.falling_node = nil
    node_groups.falling = nil -- Some mods use 'falling' instead of 'falling_node'

    local node_def = {
        description = S("Fragile @1", base_def.description or base_name),
        tiles = {texture},
        groups = node_groups,
        sounds = base_def.sounds or mcl_sounds.node_sound_stone_defaults(),
        walkable = false, -- Disable physical collision
        
        -- Logic to destroy when stepped on/entered
        on_construct = function(pos)
            local timer = minetest.get_node_timer(pos)
            timer:start(0.1)
        end,

        on_timer = function(pos, elapsed)
            -- Detection box now covers the block itself since walkable is false
            local radius_xz = 0.5
            local minp = {x = pos.x - radius_xz, y = pos.y - 0.1, z = pos.z - radius_xz}
            local maxp = {x = pos.x + radius_xz, y = pos.y + 1.0, z = pos.z + radius_xz}
            
            local objs = minetest.get_objects_in_area(minp, maxp)
            local triggered = false
            
            for _, obj in ipairs(objs) do
                if obj:is_player() or (obj:get_luaentity() and obj:get_luaentity().is_mob) then
                    triggered = true
                    break
                end
            end

            if triggered then
                minetest.set_node(pos, {name = "air"})
                local sound = "default_break_glass"
                if minetest.registered_nodes["mcl_core:stone"] then
                    sound = "mcl_core_node_break"
                end
                minetest.sound_play(sound, {pos = pos, gain = 1.0}, true)
                return false
            end
            return true
        end,
    }

    -- Add specific groups for traps
    node_def.groups.dig_immediate = 3
    node_def.groups.trap_block = 1

    -- Handle coloring (Grass, Leaves, etc.)
    if base_def.palette then
        node_def.palette = base_def.palette
        node_def.color = base_def.color
        node_def.paramtype2 = base_def.paramtype2 or "color"
        node_def.on_place = function(itemstack, placer, pointed_thing)
            return minetest.item_place(itemstack, placer, pointed_thing)
        end
    end

    -- Register the node
    minetest.register_node(node_name, node_def)

    -- Crafting recipe: xx / ss (x = base_node, s = stick)
    minetest.register_craft({
        output = node_name,
        recipe = {
            {base_node, base_node, ""},
            {"mcl_core:stick", "mcl_core:stick", ""},
            {"", "", ""},
        }
    })
end

-- ==========================================
-- LIST OF BLOCKS TO REGISTER
-- ==========================================

local blocks_to_trap = {
    "mcl_core:dirt",
    "mcl_core:dirt_with_grass",
    "mcl_core:stone",
    "mcl_core:sand",
    "mcl_core:gravel",
    "mcl_core:cobble",
    "mcl_core:mossycobble",
    "mcl_core:oak_planks",
    "mcl_core:birch_planks",
    "mcl_core:spruce_planks",
    "mcl_core:jungle_planks",
    "mcl_core:acacia_planks",
    "mcl_core:dark_oak_planks",
    "mcl_core:acacia_planks",
    "mcl_pale_oak:pale_oak_planks",
    --blossom
    "mcl_blossom:blossom_planks",
    -- Add more blocks here as needed
}

-- Register all blocks in the list
for _, block in ipairs(blocks_to_trap) do
    mcl_traps.register_trap(block)
end
