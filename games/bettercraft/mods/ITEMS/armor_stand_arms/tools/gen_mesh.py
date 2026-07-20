#!/usr/bin/env python3
"""Generate models/armor_stand_arms.obj from Mineclonia's vanilla armor stand mesh.

Takes 3d_armor_stand.obj (mcl_armor_stand) and appends two pure-voxel arm
cuboids hanging from the ends of the shoulder bar, inside the existing
"Stand" material group so they use the wood tile (tiles[1]).

Re-run after a Mineclonia update if the vanilla mesh ever changes:
    python3 tools/gen_mesh.py
"""
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
VANILLA = os.path.expanduser(
    "~/.var/app/org.luanti.luanti/.minetest/games/mineclonia/"
    "mods/ITEMS/mcl_armor_stand/models/3d_armor_stand.obj"
)
OUT = os.path.join(HERE, "..", "models", "armor_stand_arms.obj")

# Arm cuboids in node space (shoulder bar: x +-0.25..0.375, y 0.8125..0.9375).
# Each arm hangs from the underside of a shoulder-bar end, 2x10x2 px, and is
# rotated about its shoulder pivot (top center): rot_z tilts the hand
# outward (away from the body), rot_x tilts it forward.
#
# Orientation facts (pinned against engine source + in-game, Jul 7 2026):
# Luanti's OBJ importer mirrors the X axis, so authored +X renders at
# world -X; z passes through unchanged and the visual FRONT is -Z. Viewed
# from the front, the authored +X arm therefore appears on the viewer's
# LEFT = the stand's RIGHT arm: that is the weapon arm (per the reference
# pose) and gets the forward tilt (toward -Z). HAND_OFFSET in init.lua is
# in the entity-yaw frame: authored (x, y, z) renders at yaw-frame
# (-x, y, z) — negate x only.
OUTWARD_DEG = 8
FORWARD_DEG = 12
ARMS = [
    # (x0, x1, y0, y1, z0, z1, rot_z_deg, rot_x_deg)
    (0.25, 0.375, 0.1875, 0.8125, -0.0625, 0.0625, OUTWARD_DEG, FORWARD_DEG),  # weapon arm
    (-0.375, -0.25, 0.1875, 0.8125, -0.0625, 0.0625, -OUTWARD_DEG, 0),         # other arm
]

# UV rects on the wood tile: tall side faces and small end caps
VT_SIDE = [(0.0, 0.0), (0.125, 0.0), (0.125, 0.75), (0.0, 0.75)]
VT_CAP = [(0.0, 0.0), (0.125, 0.0), (0.125, 0.125), (0.0, 0.125)]


def cuboid_faces(x0, x1, y0, y1, z0, z1):
    """Return (verts, faces): 8 verts and 6 quads as local vert indices +
    'side'/'cap' uv tag, wound counterclockwise seen from outside."""
    v = [
        (x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1),  # bottom 0-3
        (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1),  # top    4-7
    ]
    quads = [
        ([0, 1, 2, 3], "cap"),   # -Y
        ([4, 5, 6, 7], "cap"),   # +Y
        ([0, 1, 5, 4], "side"),  # -Z
        ([3, 2, 6, 7], "side"),  # +Z
        ([0, 3, 7, 4], "side"),  # -X
        ([1, 2, 6, 5], "side"),  # +X
    ]
    cx, cy, cz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
    faces = []
    for idx, tag in quads:
        a, b, c = v[idx[0]], v[idx[1]], v[idx[2]]
        e1 = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
        e2 = (c[0] - b[0], c[1] - b[1], c[2] - b[2])
        n = (
            e1[1] * e2[2] - e1[2] * e2[1],
            e1[2] * e2[0] - e1[0] * e2[2],
            e1[0] * e2[1] - e1[1] * e2[0],
        )
        fc = [sum(v[i][k] for i in idx) / 4 for k in range(3)]
        out = (fc[0] - cx, fc[1] - cy, fc[2] - cz)
        if n[0] * out[0] + n[1] * out[1] + n[2] * out[2] < 0:
            idx = list(reversed(idx))
        faces.append((idx, tag))
    return v, faces


def rotate_arm(verts, x0, x1, y1, rot_z_deg, rot_x_deg):
    """Rotate arm verts about the shoulder pivot (top center of the arm).
    rot_x_deg > 0 tilts the hand forward, i.e. toward the mesh's visual
    front at -Z: down = (0,-1,0), and R_x(b) sends its z to -sin(b), so
    forward needs b = +rot_x_deg.
    rot_z_deg > 0 sends the hand toward +X (outward for the +X arm)."""
    px, py, pz = (x0 + x1) / 2, y1, 0.0
    b = math.radians(rot_x_deg)
    a = math.radians(rot_z_deg)
    out = []
    for x, y, z in verts:
        x, y, z = x - px, y - py, z - pz
        y, z = y * math.cos(b) - z * math.sin(b), y * math.sin(b) + z * math.cos(b)
        x, y = x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)
        out.append((x + px, y + py, z + pz))
    return out


def main():
    with open(VANILLA) as f:
        lines = f.read().splitlines()

    n_v = sum(1 for l in lines if l.startswith("v "))
    n_vt = sum(1 for l in lines if l.startswith("vt "))
    last_v = max(i for i, l in enumerate(lines) if l.startswith("v "))
    last_vt = max(i for i, l in enumerate(lines) if l.startswith("vt "))
    base_g = next(i for i, l in enumerate(lines) if l.strip() == "g Player_Cube_Base")

    new_v, new_vt, new_f = [], [], []
    vt_index = {}  # (u,v) -> global vt index

    def vt_id(uv):
        if uv not in vt_index:
            new_vt.append("vt %.6f %.6f" % uv)
            vt_index[uv] = n_vt + len(new_vt)
        return vt_index[uv]

    vbase = n_v
    for box in ARMS:
        x0, x1, y0, y1, z0, z1, rot_z, rot_x = box
        verts, faces = cuboid_faces(x0, x1, y0, y1, z0, z1)
        verts = rotate_arm(verts, x0, x1, y1, rot_z, rot_x)
        for x, y, z in verts:
            new_v.append("v %.6f %.6f %.6f" % (x, y, z))
        for idx, tag in faces:
            uvs = VT_SIDE if tag == "side" else VT_CAP
            new_f.append("f " + " ".join(
                "%d/%d" % (vbase + i + 1, vt_id(uvs[k]))
                for k, i in enumerate(idx)
            ))
        vbase += len(verts)

    out = (
        lines[: last_v + 1] + new_v
        + lines[last_v + 1 : last_vt + 1] + new_vt
        + lines[last_vt + 1 : base_g] + new_f
        + lines[base_g:]
    )
    with open(OUT, "w") as f:
        f.write("\n".join(out) + "\n")
    print("wrote %s (+%d v, +%d vt, +%d f)" % (OUT, len(new_v), len(new_vt), len(new_f)))


if __name__ == "__main__":
    main()
