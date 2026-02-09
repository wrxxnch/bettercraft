mcl_mobs.register_mob("mobs_mc:camel", {
	type = "animal",
	spawn_class = "passive",
	attack_type = "dogfight",
	damage = 3,
	hp_min = 32,
	hp_max = 32,
	xp_min = 1,
	xp_max = 3,
	double_melee_attack = false,
	reach = 2,
	armor = 5,
	collisionbox = { -0.6, 0, -0.6, 0.6, 1.8, 0.6 },
	visual = "mesh",
	mesh = "mobs_mc_camel.b3d",
	visual_size = { x = 1, y = 1},
	textures = { "mobs_mc_camel.png" },
	--glow = 4,
	makes_footstep_sound = true,
	walk_velocity = 1,
    pace_bonus = 0.3,
	run_velocity = 4,
	view_range = 16,
	stepheight = 1.1,
	jump = true,
	jump_height = 10,
	suffocation = true,
	fear_height = 4,
	sounds = {
	   -- random = "",
	},
	------
	drops = {
	   -- {name = "camel:camel", min = 1, max = 2},
	},
   -----
   animation = {
				-- Sit =  110 ,120
		stand_start = 1, stand_end = 40, stand_speed = 10,
		walk_start = 70, walk_end = 100, speed_normal = 10,
		run_start = 130, run_end = 146, speed_run = 10,
	},
	--[[
	do_custom = function(self,dtime)
	  --
	end,

	on_spawn = function(self, pos)

		   --local pos = self.object:get_pos()
		end
	  on_die = function(self, pos)
		   --
	end

	]]
})

mcl_mobs.register_egg("mobs_mc:camel", "camel", "#b5844c", "#553722", 0)
