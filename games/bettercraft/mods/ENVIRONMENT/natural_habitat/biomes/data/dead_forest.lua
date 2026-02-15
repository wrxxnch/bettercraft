local def = {
    name = "dead_forest", 

    depth_top = 1,
    depth_filler = 3,
    depth_riverbed = 2,

    vertical_blend = 3,

    heat_point = 45,
    humidity_point = 20,
}


if natural_habitat.is_minetest() then
    def.name = "dead_forest";

    def.node_top = "natural_habitat:ash";
    def.node_top_underground = "default:stone";
    def.node_top_deep_underground = "default:stone";

    def.node_filler = "default:dirt";
    def.node_filler_underground = "default:stone";
    def.node_filler_deep_underground = "default:stone";

    def.node_riverbed = "default:sand";

    def.node_dungeon = "default:cobble";
    def.node_dungeon_alt = "default:mossycobble";
    def.node_dungeon_stair = "stairs:stair_cobble";
    
elseif natural_habitat.is_mineclonia() then
    def.name = "DeadForest";

    def.node_top = "natural_habitat:ash";
    def.node_top_underground = "mcl_core:stone";
    def.node_top_deep_underground = "mcl_deepslate:deepslate";

    def.node_filler = "mcl_core:dirt";
    def.node_filler_underground = "mcl_core:stone";
    def.node_filler_deep_underground = "mcl_deepslate:deepslate";

    def.node_riverbed = "mcl_core:sand";

    def._mcl_biome_type = "hot";
    def._mcl_palette_index = 17;
    def._mcl_skycolor = "#6EB1FF";
    def._mcl_fogcolor = overworld_fogcolor;
    def._mcl_groups = { is_overworld=true, };
end;

natural_habitat.register_biome(def);