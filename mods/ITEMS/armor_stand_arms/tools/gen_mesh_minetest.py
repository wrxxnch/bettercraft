#!/usr/bin/env python3
"""Generate models/armor_stand_arms_minetest.obj from 3d_armor's armor stand mesh.

Same arm geometry as the Mineclonia version (the two meshes have identical
vertices), but 3d_armor's mesh UV-maps onto a single 64x64 texture atlas
(3d_armor_stand.png) instead of tiled materials. Rather than hardcode atlas
coordinates, the arm faces reuse ("steal") the UVs of existing faces: a leg
side face for the four tall arm faces and a horizontal end-cap face for the
top/bottom, so the arms are guaranteed to land on wood pixels.

Re-run after a 3d_armor update if its mesh changes:
    python3 tools/gen_mesh_minetest.py
"""
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
VANILLA = os.path.expanduser(
    "~/.var/app/org.luanti.luanti/.minetest/mods/3d_armor/"
    "3d_armor_stand/models/3d_armor_stand.obj"
)
OUT = os.path.join(HERE, "..", "models", "armor_stand_arms_minetest.obj")

# Arm cuboids: 2x10x2 px hanging from the shoulder-bar ends, both tilted
# outward, the authored +X arm (renders as the stand's right hand; the OBJ
# importer mirrors X) also tilted toward the visual front at -Z. Identical
# geometry to the sibling armor_stand_arms mod for Mineclonia/VoxeLibre --
# the two games' stand meshes share the same vertices, only the UVs differ.
OUTWARD_DEG = 8
FORWARD_DEG = 12
ARMS = [
    # (x0, x1, y0, y1, z0, z1, rot_z_deg, rot_x_deg)
    (0.25, 0.375, 0.1875, 0.8125, -0.0625, 0.0625, OUTWARD_DEG, FORWARD_DEG),  # weapon arm
    (-0.375, -0.25, 0.1875, 0.8125, -0.0625, 0.0625, -OUTWARD_DEG, 0),         # other arm
]


def cuboid_faces(x0, x1, y0, y1, z0, z1):
    """8 verts and 6 quads (local indices + side/cap tag), wound CCW seen
    from outside."""
    v = [
        (x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1),
        (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1),
    ]
    quads = [
        ([0, 1, 2, 3], "cap"),
        ([4, 5, 6, 7], "cap"),
        ([0, 1, 5, 4], "side"),
        ([3, 2, 6, 7], "side"),
        ([0, 3, 7, 4], "side"),
        ([1, 2, 6, 5], "side"),
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
    """Rotate arm verts about the shoulder pivot (top center). rot_x > 0
    tilts the hand toward the visual front (-Z); rot_z > 0 toward +X."""
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


def parse(path):
    verts, vts, faces = [], [], []
    material = None
    for line in open(path):
        p = line.split()
        if not p:
            continue
        if p[0] == "v":
            verts.append(tuple(float(t) for t in p[1:4]))
        elif p[0] == "vt":
            vts.append(tuple(float(t) for t in p[1:3]))
        elif p[0] == "usemtl":
            material = p[1]
        elif p[0] == "f":
            corners = [tuple(int(t) for t in w.split("/")[:2]) for w in p[1:]]
            faces.append((material, corners))
    return verts, vts, faces


def donor_uvs(verts, faces):
    """Pick UV donors from the Stand (wood) material:
    - side donor: a quad spanning a tall y range with a narrow footprint
      (a leg side face); returns [(ti_bottom, ti_bottom, ti_top, ti_top)]
      classified by corner height so arm faces keep the grain upright.
    - cap donor: a horizontal quad with zero y span (an end cap)."""
    side, cap = None, None
    for material, corners in faces:
        if material != "Stand" or len(corners) != 4:
            continue
        ys = [verts[vi - 1][1] for vi, _ in corners]
        yspan = max(ys) - min(ys)
        if side is None and yspan > 0.5:
            mid = (max(ys) + min(ys)) / 2
            bottom = [ti for (vi, ti) in corners if verts[vi - 1][1] < mid]
            top = [ti for (vi, ti) in corners if verts[vi - 1][1] >= mid]
            if len(bottom) == 2 and len(top) == 2:
                side = {"bottom": bottom, "top": top}
        if cap is None and yspan < 1e-6:
            cap = [ti for (_, ti) in corners]
        if side and cap:
            break
    if not (side and cap):
        raise SystemExit("could not find UV donor faces in the Stand material")
    return side, cap


def main():
    with open(VANILLA) as f:
        lines = f.read().splitlines()
    verts, vts, faces = parse(VANILLA)
    side, cap = donor_uvs(verts, faces)

    n_v = len(verts)
    last_v = max(i for i, l in enumerate(lines) if l.startswith("v "))
    # append arm faces at the end of the file, in a fresh Stand block
    new_v, new_f = [], []
    vbase = n_v
    for box in ARMS:
        x0, x1, y0, y1, z0, z1, rot_z, rot_x = box
        cube, quads = cuboid_faces(x0, x1, y0, y1, z0, z1)
        rotated = rotate_arm(cube, x0, x1, y1, rot_z, rot_x)
        for x, y, z in rotated:
            new_v.append("v %.6f %.6f %.6f" % (x, y, z))
        ymid = (y0 + y1) / 2
        for idx, tag in quads:
            if tag == "cap":
                tis = cap
            else:
                # keep the wood grain upright: bottom corners get the
                # donor's bottom UVs, top corners the top UVs
                tis, b_used, t_used = [], 0, 0
                for i in idx:
                    if cube[i][1] < ymid:
                        tis.append(side["bottom"][b_used % 2]); b_used += 1
                    else:
                        tis.append(side["top"][t_used % 2]); t_used += 1
            new_f.append("f " + " ".join(
                "%d/%d" % (vbase + i + 1, ti) for i, ti in zip(idx, tis)
            ))
        vbase += len(cube)

    out = (
        lines[: last_v + 1] + new_v + lines[last_v + 1 :]
        + ["usemtl Stand"] + new_f
    )
    with open(OUT, "w") as f:
        f.write("\n".join(out) + "\n")
    print("wrote %s (+%d v, +%d f, side-UV donor %s / cap donor %s)"
          % (OUT, len(new_v), len(new_f), side, cap))


if __name__ == "__main__":
    main()
