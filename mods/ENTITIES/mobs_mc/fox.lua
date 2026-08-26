-- License for code WTFPL and otherwise stated in readmes

local S = core.get_translator("mobs_mc")
local mob_class = mcl_mobs.mob_class

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

	------------------------------------------------------------------------
	-- Physical properties.
	------------------------------------------------------------------------

	collisionbox = {
		-0.35, 0.0, -0.35,
		 0.35, 0.5,  0.35
	},

	visual = "mesh",
	mesh = "fox.b3d",

	visual_size = {
		x = 10,
		y = 10,
	},

	textures = {
		"fox.png",
	},

	makes_footstep_sound = false,

	bone_eye_height = 0.45,
	head_eye_height = 0.45,

	floats = 1,
	fall_damage = 0,

	------------------------------------------------------------------------
	-- Skin Logic (Snow Fox)
	------------------------------------------------------------------------

	-- Variável interna para salvar o tipo de skin
	_skin_type = "orange",

	on_spawn = function(self)
		local pos = self.object:get_pos()
		if not pos then return true end

		-- Verifica o bloco nos pés e o bloco logo abaixo
		local node_at = core.get_node(pos).name
		local node_below = core.get_node({x = pos.x, y = pos.y - 1, z = pos.z}).name

		-- Se houver neve, muda para a skin branca
		if node_at:find("snow") or node_below:find("snow") then
			self._skin_type = "white"
			self.textures = {"whitefox.png"}
			self.object:set_properties({textures = self.textures})
		end
		return true
	end,

	on_activate = function(self, staticdata, dtime_s)
		-- Executa a ativação padrão da API de mobs
		if mcl_mobs.mob_class.on_activate then
			mcl_mobs.mob_class.on_activate(self, staticdata, dtime_s)
		end

		-- Se o staticdata ou a variável interna indicar que é branca, mantém a skin
		if self._skin_type == "white" then
			self.textures = {"whitefox.png"}
			self.object:set_properties({textures = self.textures})
		end
	end,

	------------------------------------------------------------------------
	-- Movement.
	------------------------------------------------------------------------

	movement_speed = 4.0,

	damage = 2,
	reach = 1.5,

	attack_type = "melee",

	------------------------------------------------------------------------
	-- Ocelot-like fleeing.
	------------------------------------------------------------------------

	runaway_from = {
		"players",
	},

	-- Run much faster when the player is close.
	runaway_bonus_near = 1.33,
	runaway_bonus_far = 0.8,

	run_bonus = 1.5,

	------------------------------------------------------------------------
	-- Animation.
	------------------------------------------------------------------------

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

	------------------------------------------------------------------------
	-- Food follow.
	------------------------------------------------------------------------

	follow = {
		"mcl_mobitems:chicken",
		"mcl_mobitems:rabbit",
		"mcl_mobitems:mutton",
		"mcl_mobitems:beef",
		"mcl_mobitems:porkchop",

		"mcl_mobitems:cooked_chicken",
		"mcl_mobitems:cooked_rabbit",
		"mcl_mobitems:cooked_mutton",
		"mcl_mobitems:cooked_beef",
		"mcl_mobitems:cooked_porkchop",
	},

	------------------------------------------------------------------------
	-- Hunting.
	------------------------------------------------------------------------

	specific_attack = {
		"mobs_mc:chicken",
		"mobs_mc:rabbit",
	},
}

------------------------------------------------------------------------
-- Fox interaction / breeding.
------------------------------------------------------------------------

function fox:on_rightclick(clicker)
	if not clicker or not clicker:is_player() then
		return
	end

	if self.child then
		return
	end

	-- Feed / breed.
	if self:follow_holding(clicker)
		and self:feed_tame(clicker, 4, true, false) then
		return
	end
end

------------------------------------------------------------------------
-- Fox attack.
------------------------------------------------------------------------

function fox:attack_custom(self_pos, dtime, esp)
	local attack = self:attack_default(self_pos, dtime, esp)

	if attack then
		self:do_attack(attack)
		return true
	end

	return false
end

------------------------------------------------------------------------
-- Fox AI.
------------------------------------------------------------------------

fox.ai_functions = {
	mob_class.check_frightened,
	mob_class.check_following,
	mob_class.check_attack,
	mob_class.check_breeding,
	mob_class.follow_herd,
	mob_class.check_pace,
}

------------------------------------------------------------------------
-- Fox breeding (Modified to inherit skin).
------------------------------------------------------------------------

function fox:on_breed(parent1, parent2)
	local pos = parent1.object:get_pos()

	local child = mcl_mobs.spawn_child(
		pos,
		parent1.name
	)

	if child then
		local ent_c = child:get_luaentity()
		ent_c.persistent = true

		-- Genética: Se um dos pais for branco, o filho nasce branco
		if parent1._skin_type == "white" or parent2._skin_type == "white" then
			ent_c._skin_type = "white"
			ent_c.textures = {"whitefox.png"}
			ent_c.object:set_properties({textures = ent_c.textures})
		end

		return false
	end
end

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
		"#is_snowy", -- Adicionado biomas de neve explicitamente no spawner
	},
})

function fox_spawner:test_supporting_node(node)
	return core.get_item_group(node.name, "grass_block") > 0
		or node.name == "mcl_core:snowblock"
		or node.name == "mcl_core:snow"
		or node.name == "mcl_core:podzol"
end

function fox_spawner:describe_supporting_nodes()
	return S("on grass, snow blocks, or podzol")
end

------------------------------------------------------------------------
-- Register.
------------------------------------------------------------------------

mcl_mobs.register_mob(
	"mobs_mc:fox",
	fox
)

mcl_mobs.register_egg(
	"mobs_mc:fox",
	S("Fox"),
	"#d0602d",
	"#c9c9c9",
	0
)

mcl_mobs.register_spawner(
	fox_spawner
)