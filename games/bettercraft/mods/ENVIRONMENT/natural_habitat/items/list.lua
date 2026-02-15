local S = core.get_translator(core.get_current_modname());
local modpath = core.get_modpath(core.get_current_modname());
local get_item = natural_habitat.get_item;

-- DEFAULT ITEMS/NODES
natural_habitat.stick = get_item("default:stick", "mcl_core:stick");
natural_habitat.trees = {
    apple   = get_item("default:tree", nil);
    jungle  = get_item("default:jungletree", "mcl_trees:tree_jungle");
    pine    = get_item("default:pine_tree", "mcl_trees:tree_spruce");
    acacia  = get_item("default:acacia_tree", "mcl_trees:tree_acacia");
    aspen   = get_item("default:aspen_tree", "mcl_trees:tree_birch");
    
    oak         = get_item(nil, "mcl_trees:tree_oak");
    oak_dark    = get_item(nil, "mcl_trees:tree_dark_oak");
    oak_pale    = get_item(nil, "mcl_trees:tree_pale_oak");
    mangrove    = get_item(nil, "mcl_trees:tree_mangrove");
    sakura      = get_item(nil, "mcl_trees:tree_cherry_blossom");
    warped      = get_item(nil, "mcl_trees:tree_warped");
    crimson     = get_item(nil, "mcl_trees:tree_crimson");
    
    burnt_tree = "natural_habitat:burnt_log",
};

-- IMPORTS
dofile(modpath.."/items/plants/burnt_tree.lua");
dofile(modpath.."/items/plants/glow_mushroom.lua"); --WIP
dofile(modpath.."/items/plants/cave_vines.lua"); --WIP
dofile(modpath.."/items/plants/coconut_palmtree.lua"); -- WIP

dofile(modpath.."/items/data/ash.lua");
dofile(modpath.."/items/data/stick.lua");
dofile(modpath.."/items/data/rubble.lua");
dofile(modpath.."/items/data/branch.lua");

dofile(modpath.."/items/override.lua");