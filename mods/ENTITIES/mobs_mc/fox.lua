-- License for code WTFPL and otherwise stated in readmes

local S = core.get_translator("mobs_mc")

local mob_class = mcl_mobs.mob_class
local is_valid = mcl_util.is_valid_objectref

------------------------------------------------------------------------
-- Fox.
------------------------------------------------------------------------

local fox = {
	description = S("Fox"),
	type = "animal",
	_spawn_category = "creature",
	can_despawn = true,

	hp_min = 10,
	hp_max = 10,
	xp_min = 1,
	xp_max = 2,

	passive = false,

	collisionbox = {-0.35, 0.0, -0.35, 0.35, 0.5, 0.35},
	visual_size = { x = 10, y = 10, },

	visual = "mesh",
	mesh = "fox.b3d",

	textures = {
		"fox.png",
	},

	makes_footstep_sound = false,

	bone_eye_height = 0.45,
	head_eye_height = 0.45,

	floats = 1,

	movement_speed = 4.0,
	damage = 2,
	reach = 1.5,
	attack_type = "melee",

	animation = {
		stand_start = 0,
		stand_end = 38,

		walk_start = 40,
		walk_end = 58,
		walk_speed = 30,

		run_start = 40,
		run_end = 58,
		run_speed = 45,
	},

	-- The fox hunts chickens and rabbits.
	specific_attack = {
		"mobs_mc:chicken",
		"mobs_mc:rabbit",
	},

	-- Food which the fox follows.
	follow = {
		"mcl_mobitems:chicken",
		"mcl_mobitems:rabbit",
		"mcl_mobitems:mutton",
		"mcl_mobitems:beef",
		"mcl_mobitems:porkchop",
	},

	-- Foxes run away when punched.
	runaway_from = {
		"mobs_mc:player",
	},

	run_bonus = 1.5,

	-- sounds = {
	-- 	attack = "mobs_mc_fox_bite",
	-- 	war_cry = "mobs_mc_fox_screech",
	-- 	damage = {
	-- 		name = "mobs_mc_fox_hurt",
	-- 		gain = 0.7,
	-- 	},
	-- 	death = {
	-- 		name = "mobs_mc_fox_death",
	-- 		gain = 0.7,
	-- 	},
	-- 	eat = "mobs_mc_animal_eat_generic",
	-- 	distance = 16,
	-- },
}

------------------------------------------------------------------------
-- Fox AI.
------------------------------------------------------------------------

function fox:ai_step(dtime)
	local self_pos = self.object:get_pos()

	if not self_pos then
		return
	end

	mob_class.ai_step(self, dtime)
end

function fox:should_runaway_from_mob(entity)
	return entity.name == "mobs_mc:player"
end

function fox:attack_custom(self_pos, dtime)
	local attack = self:attack_default(self_pos, dtime, self.esp)

	if attack then
		self:do_attack(attack)
		return true
	end

	return false
end

fox.ai_functions = {
	mob_class.check_frightened,
	mob_class.check_avoid,
	mob_class.check_attack,
	mob_class.check_breeding,
	mob_class.check_pace,
}

------------------------------------------------------------------------
-- Register fox.
------------------------------------------------------------------------



------------------------------------------------------------------------
-- Fox spawn egg.
------------------------------------------------------------------------



------------------------------------------------------------------------
-- Fox spawning.
------------------------------------------------------------------------

local fox_spawner = table.merge(mobs_mc.animal_spawner, {
	name = "mobs_mc:fox",
	weight = 8,
	pack_min = 2,
	pack_max = 4,

	biomes = {
		"#is_taiga",
	},
})

function fox_spawner:test_supporting_node(node)
	return core.get_item_group(node.name, "grass_block") > 0
		or node.name == "mcl_core:snowblock"
		or node.name == "mcl_core:podzol"
end

function fox_spawner:describe_supporting_nodes()
	return S("on grass, snow blocks, or podzol")
end


mcl_mobs.register_egg(
	"mobs_mc:fox",
	S("Fox"),
	"#d0602d",
	"#c9c9c9",
	0
)

mcl_mobs.register_mob("mobs_mc:fox", fox)