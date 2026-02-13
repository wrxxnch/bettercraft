mcl_mobs.register_mob("mobs_mc:sniffer", {
	type = "animal",
	spawn_class = "passive",
	attack_type = "dogfight",
	damage = 3,
	hp_min = 14,
	hp_max = 14,
	xp_min = 1,
	xp_max = 3,
	double_melee_attack = false,
	reach = 2,
	armor = 5,
	collisionbox = { -0.7, 0, -0.7, 0.7, 1.6, 0.7 },
	visual = "mesh",
	mesh = "mobs_mc_sniffer.b3d",
	visual_size = { x = 1, y = 1},
	textures = { "mobs_mc_sniffer.png" },
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
	drops = {
	   -- {name = "sniffer:sniffer", min = 1, max = 2},
	},
	animation = {
				-- Stand Normal = 1 , 20
				-- Sniffing = 180 , 240
				-- Digging =  260,330
		stand_start = 140, stand_end = 150, stand_speed = 10,
		walk_start = 40, walk_end = 120, speed_normal = 10,
		--run_start = 40, run_end = 120, speed_run = 10,
		--punch_start = 0, punch_end = 0, punch_speed =0,
		--die_start = 0, die_end = 0, die_speed = 0,--die_loop = 0,
	},
	--[[
	do_custom = function(self,dtime)
	end,
	on_spawn = function(self, pos)
		   --local pos = self.object:get_pos()
		end
	  on_die = function(self, pos)
		   --
	end

	]]
})

mcl_mobs.register_egg("mobs_mc:sniffer", "Sniffer", "#872618", "#254017", 0)
