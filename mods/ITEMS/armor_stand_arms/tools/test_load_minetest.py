#!/usr/bin/env python3
"""Stub-execute the Minetest Game init.lua under lupa.

Mocks the Minetest Game + 3d_armor surface (armor global, chest-style
inventory callbacks) and exercises: place, armor auto-slotting, weapon and
shield acceptance/rejection, entity displays, rotation, dig rules, blast
drops and the LBM. Run: python3 tools/test_load_minetest.py
"""
import os
from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
INIT = os.path.join(HERE, "..", "init.lua")

HARNESS = r"""
local checks = {}
local function check(name, cond)
    checks[#checks+1] = name
    if not cond then error("CHECK FAILED: " .. name, 2) end
end

-- ========== vector ==========
local vmeta
local function vnew(x, y, z) return setmetatable({x=x, y=y, z=z}, vmeta) end
vmeta = {
    __add = function(a, b) return vnew(a.x+b.x, a.y+b.y, a.z+b.z) end,
    __sub = function(a, b) return vnew(a.x-b.x, a.y-b.y, a.z-b.z) end,
    __mul = function(a, s) return vnew(a.x*s, a.y*s, a.z*s) end,
}
vector = {
    new = function(x, y, z) return vnew(x or 0, y or 0, z or 0) end,
    add = function(a, b) return vnew(a.x+b.x, a.y+b.y, a.z+b.z) end,
    offset = function(v, x, y, z) return vnew(v.x+x, v.y+y, v.z+z) end,
    round = function(v)
        return vnew(math.floor(v.x+0.5), math.floor(v.y+0.5), math.floor(v.z+0.5))
    end,
    equals = function(a, b) return a.x==b.x and a.y==b.y and a.z==b.z end,
    distance = function(a, b)
        local dx, dy, dz = a.x-b.x, a.y-b.y, a.z-b.z
        return math.sqrt(dx*dx + dy*dy + dz*dz)
    end,
    rotate = function(v, rot)
        local c, s = math.cos(rot.y), math.sin(rot.y)
        return vnew(v.x*c - v.z*s, v.y, v.x*s + v.z*c)
    end,
}

-- ========== ItemStack ==========
local registered_items = {
    ["default:sword_steel"] = {groups = {sword = 1}},
    ["default:axe_steel"] = {groups = {axe = 1}},
    ["shields:shield_steel"] = {groups = {armor_shield = 1, armor_heal = 0}},
    ["3d_armor:helmet_steel"] = {groups = {armor_head = 1}, texture = "helmet_steel.png"},
    ["3d_armor:chestplate_steel"] = {groups = {armor_torso = 1}},
    ["default:apple"] = {groups = {food_apple = 1}},
    -- a hypothetical ranged/charge weapon: must be rejected even though
    -- it carries the weapon group (see the Mineclonia/VoxeLibre variant)
    ["mymod:bow"] = {groups = {weapon = 1, weapon_ranged = 1}},
}
local StackMeta
local function ItemStack(init)
    local name, count = "", 0
    if type(init) == "table" then name, count = init.name or "", init.count or 0
    elseif type(init) == "string" and init ~= "" then
        name = init:match("^(%S+)")
        count = tonumber(init:match("%s(%d+)")) or 1
    end
    return setmetatable({_name = name, _count = count}, StackMeta)
end
StackMeta = {__index = {
    get_name = function(self) return self._name end,
    get_count = function(self) return self._count end,
    is_empty = function(self) return self._name == "" or self._count == 0 end,
    get_definition = function(self) return registered_items[self._name] end,
    copy = function(self) return ItemStack({name = self._name, count = self._count}) end,
}}
_G.ItemStack = ItemStack

-- ========== inventory / meta / world ==========
local function Inventory()
    local lists = {}
    return {
        set_size = function(_, l, size)
            lists[l] = lists[l] or {}
            for i = 1, size do lists[l][i] = lists[l][i] or ItemStack() end
        end,
        get_size = function(_, l) return lists[l] and #lists[l] or 0 end,
        get_stack = function(_, l, i) return (lists[l] and lists[l][i] or ItemStack()):copy() end,
        set_stack = function(_, l, i, stack)
            if stack == nil then stack = ItemStack() end
            if type(stack) ~= "table" then stack = ItemStack(stack) end
            lists[l][i] = stack:copy()
        end,
        is_empty = function(_, l)
            for _, s in ipairs(lists[l] or {}) do
                if not s:is_empty() then return false end
            end
            return true
        end,
    }
end

local nodes, metas, objects, drops = {}, {}, {}, {}
local function poskey(p) return p.x .. "," .. p.y .. "," .. p.z end
local registered_nodes, registered_entities, registered_lbms, registered_crafts = {}, {}, {}, {}

local aliases = {}
-- Minetest Game with 3d_armor installed (a later scenario removes 3d_armor
-- to exercise the mod's soft-fail path)
local INSTALLED_MODS = {["default"] = true, ["3d_armor"] = true,
    ["3d_armor_stand"] = true, ["shields"] = true}
local join_callbacks, chat_msgs = {}, {}
local node_reg_count = 0

core = {
    get_current_modname = function() return "armor_stand_arms" end,
    get_translator = function() return function(s) return s end end,
    -- the mod's own path must be real, init.lua dofiles the game file from it
    get_modpath = function(name)
        if name == "armor_stand_arms" then return MOD_ROOT end
        return INSTALLED_MODS[name] and ("/mods/" .. name) or nil
    end,
    register_alias = function(old, new) aliases[old] = new end,
    register_on_joinplayer = function(fn) join_callbacks[#join_callbacks+1] = fn end,
    after = function(_, fn) fn() end,
    chat_send_player = function(name, msg) chat_msgs[#chat_msgs+1] = msg end,
    colorize = function(_, str) return str end,
    register_node = function(name, def)
        registered_nodes[name] = def
        node_reg_count = node_reg_count + 1
    end,
    register_entity = function(name, def) registered_entities[name] = def end,
    register_lbm = function(def) registered_lbms[#registered_lbms+1] = def end,
    register_craft = function(def) registered_crafts[#registered_crafts+1] = def end,
    get_node = function(pos)
        return nodes[poskey(vector.round(pos))] or {name = "air", param2 = 0}
    end,
    set_node = function(pos, node) nodes[poskey(vector.round(pos))] = node end,
    swap_node = function(pos, node) nodes[poskey(vector.round(pos))] = node end,
    remove_node = function(pos) nodes[poskey(vector.round(pos))] = nil end,
    get_meta = function(pos)
        local k = poskey(vector.round(pos))
        if not metas[k] then metas[k] = {inv = Inventory(), fields = {}} end
        local m = metas[k]
        return {
            get_inventory = function() return m.inv end,
            set_string = function(_, key, v) m.fields[key] = v end,
            get_string = function(_, key) return m.fields[key] or "" end,
        }
    end,
    is_protected = function() return false end,
    facedir_to_dir = function(fd)
        local dirs = {[0]=vnew(0,0,1), [1]=vnew(1,0,0), [2]=vnew(0,0,-1), [3]=vnew(-1,0,0)}
        return dirs[fd % 4]
    end,
    dir_to_yaw = function(dir) return math.atan(-dir.x, dir.z) end,
    pos_to_string = function(p) return "(" .. p.x .. "," .. p.y .. "," .. p.z .. ")" end,
    string_to_pos = function(s)
        local x, y, z = s:match("%((%-?%d+),(%-?%d+),(%-?%d+)%)")
        if x then return vnew(tonumber(x), tonumber(y), tonumber(z)) end
    end,
    get_objects_inside_radius = function(pos, radius)
        local found = {}
        for _, obj in ipairs(objects) do
            if not obj._removed and vector.distance(obj._pos, pos) <= radius + 1e-9 then
                found[#found+1] = obj
            end
        end
        return found
    end,
    add_entity = function(pos, name, staticdata)
        local def = registered_entities[name]
        if not def then error("no such entity " .. name) end
        local obj
        obj = {
            _pos = vnew(pos.x, pos.y, pos.z),
            _removed = false,
            _properties = {},
            _yaw = 0,
            is_player = function() return false end,
            get_pos = function(self) return self._pos end,
            set_pos = function(self, p) self._pos = vnew(p.x, p.y, p.z) end,
            set_yaw = function(self, yaw) self._yaw = yaw end,
            set_rotation = function(self, r) self._yaw = r.y end,
            set_properties = function(self, props)
                for k, v in pairs(props) do self._properties[k] = v end
            end,
            set_armor_groups = function() end,
            remove = function(self) self._removed = true end,
        }
        local luaentity = setmetatable({object = obj, name = name}, {__index = def})
        obj.get_luaentity = function() return luaentity end
        objects[#objects+1] = obj
        if def.on_activate then luaentity:on_activate(staticdata or "") end
        return obj
    end,
    add_item = function(pos, stack)
        if type(stack) == "string" then stack = ItemStack(stack) end
        if stack and not stack:is_empty() then
            drops[#drops+1] = stack:get_name()
        end
    end,
    log = function() end,
}

-- ========== 3d_armor stubs ==========
armor = {
    add_formspec_list = function() return "" end,
    sounds = {wood = {}},
    drop_armor = function() end,
}
screwdriver = {ROTATE_FACE = 1, ROTATE_AXIS = 2}

-- ========== load ==========
dofile(INIT_PATH)

local NODE = "armor_stand_arms:armor_stand"
local nodedef = registered_nodes[NODE]
check("node registered", nodedef ~= nil)
check("legacy armor_stand_arms_minetest node aliased",
    aliases["armor_stand_arms_minetest:armor_stand"] == NODE)
check("armor entity registered", registered_entities["armor_stand_arms:armor_entity"] ~= nil)
check("item entity registered", registered_entities["armor_stand_arms:item_entity"] ~= nil)
check("recipe uses default:stick and stairs:slab_stone", (function()
    local sticks, slabs = 0, 0
    for _, row in ipairs(registered_crafts[1].recipe) do
        for _, it in ipairs(row) do
            if it == "default:stick" then sticks = sticks + 1 end
            if it == "stairs:slab_stone" then slabs = slabs + 1 end
        end
    end
    return sticks == 8 and slabs == 1
end)())

local pos = vnew(10, 5, 10)
nodes[poskey(pos)] = {name = NODE, param2 = 0}
nodedef.on_construct(pos)
local meta = core.get_meta(pos)
check("formspec set on construct", meta:get_string("formspec"):find("list%[current_name;hand") ~= nil)
local inv = meta:get_inventory()
check("inventory sizes", inv:get_size("main") == 4 and inv:get_size("hand") == 1 and inv:get_size("offhand") == 1)

local player = {
    is_player = function() return true end,
    get_player_name = function() return "nando" end,
}
nodedef.after_place_node(pos, player)
local function live(name)
    local n = 0
    for _, o in ipairs(objects) do
        if not o._removed and o:get_luaentity().name == name then n = n + 1 end
    end
    return n
end
check("armor entity spawned on place", live("armor_stand_arms:armor_entity") == 1)
check("hidden top node placed", core.get_node(vnew(10, 6, 10)).name == "3d_armor_stand:top")

-- acceptance rules
local allow = nodedef.allow_metadata_inventory_put
check("helmet allowed in main", allow(pos, "main", 1, ItemStack("3d_armor:helmet_steel"), player) == 1)
check("sword refused in main", allow(pos, "main", 1, ItemStack("default:sword_steel"), player) == 0)
check("sword allowed in hand", allow(pos, "hand", 1, ItemStack("default:sword_steel"), player) == 1)
check("axe allowed in hand", allow(pos, "hand", 1, ItemStack("default:axe_steel"), player) == 1)
check("shield refused in hand", allow(pos, "hand", 1, ItemStack("shields:shield_steel"), player) == 0)
check("shield allowed in offhand", allow(pos, "offhand", 1, ItemStack("shields:shield_steel"), player) == 1)
check("sword refused in offhand", allow(pos, "offhand", 1, ItemStack("default:sword_steel"), player) == 0)
check("ranged weapon refused in hand despite weapon group",
    allow(pos, "hand", 1, ItemStack("mymod:bow"), player) == 0)
check("apple refused everywhere",
    allow(pos, "main", 1, ItemStack("default:apple"), player) == 0
    and allow(pos, "hand", 1, ItemStack("default:apple"), player) == 0
    and allow(pos, "offhand", 1, ItemStack("default:apple"), player) == 0)

-- armor auto-slotting: chestplate dropped into slot 1 relocates to slot 2
inv:set_stack("main", 1, ItemStack("3d_armor:chestplate_steel"))
nodedef.on_metadata_inventory_put(pos, "main", 1, ItemStack("3d_armor:chestplate_steel"))
check("chestplate relocated to torso slot",
    inv:get_stack("main", 1):is_empty()
    and inv:get_stack("main", 2):get_name() == "3d_armor:chestplate_steel")

-- helmet uses def.texture in the composited entity skin
inv:set_stack("main", 1, ItemStack("3d_armor:helmet_steel"))
nodedef.on_metadata_inventory_put(pos, "main", 1, ItemStack("3d_armor:helmet_steel"))
local stand_obj
for _, o in ipairs(objects) do
    if not o._removed and o:get_luaentity().name == "armor_stand_arms:armor_entity" then stand_obj = o end
end
check("entity texture composited",
    stand_obj._properties.textures[1]:find("helmet_steel.png", 1, true) ~= nil
    and stand_obj._properties.textures[1]:find("3d_armor_chestplate_steel.png", 1, true) ~= nil)

-- weapon + shield displays
inv:set_stack("hand", 1, ItemStack("default:sword_steel"))
nodedef.on_metadata_inventory_put(pos, "hand", 1, ItemStack("default:sword_steel"))
inv:set_stack("offhand", 1, ItemStack("shields:shield_steel"))
nodedef.on_metadata_inventory_put(pos, "offhand", 1, ItemStack("shields:shield_steel"))
check("two item entities", live("armor_stand_arms:item_entity") == 2)
local sword_obj, shield_obj
for _, o in ipairs(objects) do
    local le = o:get_luaentity()
    if not o._removed and le.name == "armor_stand_arms:item_entity" then
        if le.slot == "main" then sword_obj = o else shield_obj = o end
    end
end
check("sword shown", sword_obj._properties.textures[1] == "default:sword_steel")
check("shield shown", shield_obj._properties.textures[1] == "shields:shield_steel")
check("opposite arms", (sword_obj._pos.x - pos.x) * (shield_obj._pos.x - pos.x) < 0)

-- staticdata-less orphan finds its node (y offset compensated)
local orphan = core.add_entity(sword_obj._pos, "armor_stand_arms:item_entity")
check("orphan finds node", vector.equals(orphan:get_luaentity().node_pos, pos))
orphan:remove()

-- rotation moves the hands
local old = vnew(sword_obj._pos.x, sword_obj._pos.y, sword_obj._pos.z)
check("rotate handled", nodedef.on_rotate(pos, {name = NODE, param2 = 0}, nil, 1) == true)
check("sword moved with rotation", not vector.equals(sword_obj._pos, old))

-- dig rules
check("cannot dig while loaded", nodedef.can_dig(pos) == false)

-- take the weapon: entity goes away
inv:set_stack("hand", 1, nil)
nodedef.on_metadata_inventory_take(pos)
check("weapon entity removed on take", live("armor_stand_arms:item_entity") == 1)

-- blast drops the rest
nodedef.on_blast(pos)
local dropped = table.concat(drops, ";")
check("blast drops armor", dropped:find("helmet_steel", 1, true) ~= nil)
check("blast drops shield", dropped:find("shields:shield_steel", 1, true) ~= nil)
check("node removed by blast", core.get_node(pos).name == "air")

-- entities clean themselves up once the node is gone
for _, o in ipairs(objects) do
    local le = o:get_luaentity()
    if not o._removed and le.on_step then le:on_step(0.1) end
end
check("all entities self-removed", live("armor_stand_arms:armor_entity") == 0
    and live("armor_stand_arms:item_entity") == 0)

-- LBM respawn on a fresh stand
local pos2 = vnew(20, 5, 20)
nodes[poskey(pos2)] = {name = NODE, param2 = 2}
nodedef.on_construct(pos2)
core.get_meta(pos2):get_inventory():set_stack("hand", 1, ItemStack("default:axe_steel"))
registered_lbms[1].action(pos2)
check("LBM spawns armor entity", live("armor_stand_arms:armor_entity") == 1)
check("LBM spawns hand item entity", live("armor_stand_arms:item_entity") == 1)

-- Minetest Game WITHOUT 3d_armor: the mod must not crash the world.
-- It registers nothing and instead tells joining players what to install.
INSTALLED_MODS["3d_armor"] = nil
INSTALLED_MODS["3d_armor_stand"] = nil
INSTALLED_MODS["shields"] = nil
local regs_before = node_reg_count
dofile(INIT_PATH)
check("no 3d_armor: loads without error, registers no nodes",
    node_reg_count == regs_before)
check("no 3d_armor: join-time warning registered", #join_callbacks == 1)
join_callbacks[1]({get_player_name = function() return "newplayer" end})
check("no 3d_armor: chat message names the missing modpack",
    #chat_msgs == 1 and chat_msgs[1]:find("3d_armor") ~= nil)

return #checks
"""


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals()["INIT_PATH"] = os.path.abspath(INIT)
    lua.globals()["MOD_ROOT"] = os.path.abspath(os.path.join(HERE, ".."))
    n = lua.execute(HARNESS)
    print("OK: %d checks passed" % n)


if __name__ == "__main__":
    main()
