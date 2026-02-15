-- PARTICLE PUNCH
function natural_habitat.particle_punch(pos, texture, texpool, radius, size, amount)
    core.add_particlespawner({
        amount = amount or 8, time = 0.001,
        minpos = vector.add(pos, 
            vector.new(math.random(-0.1, 0), -0.5, math.random(-0.1, 0))
        ), 
        maxpos = vector.add(pos, 
            vector.new(math.random(0, 0.1), 0, math.random(0, 0.1))
        ),
        minvel = vector.new(-radius, radius*4, -radius),
        maxvel = vector.new(radius, radius*4, radius),
        minacc = {x=0, y=-15, z=0},
        maxacc = {x=0, y=-20, z=0},
        minsize = (size or 0)+0.8, maxsize = (size or 0)+1.5,
        minexptime = 0.9,
        maxexptime = 1.1,
        texture = texture,
        texpool = texpool,
    });
end;

function natural_habitat.particle_explode(pos, texture, texpool, radius, size, amount)
    core.add_particlespawner({
        amount = amount or 8, time = 0.0002,
        minpos = vector.add(pos, 
            vector.new(math.random(-0.1, 0), -0.5, math.random(-0.1, 0))
        ), 
        maxpos = vector.add(pos, 
            vector.new(math.random(0, 0.1), 0, math.random(0, 0.1))
        ),
        minvel = vector.new(-radius, -radius, -radius),
        maxvel = vector.new(radius, radius, radius),
        minacc = {x=0, y=-0.1, z=0},
        maxacc = {x=0, y=-5, z=0},
        minsize = (size or 0)+0.8, maxsize = (size or 0)+1.5,
        minexptime = 0.5,
        maxexptime = 0.9,
        texture = texture,
        texpool = texpool,
    });
end;