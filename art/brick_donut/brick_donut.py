# Brick donut: a donut built from studded cubes in layers (baked base, dough, glaze, raised crown),
# with a flat-tile face, sprinkle-coloured studs, drips, legs and shoes. Two shapes: "round" (a ring
# of cubes) and "square" (a square ring with cut corners).
#   python3 brick_donut.py <shape> <out.png | out_dir_for_frames | -> [still|breathe|none] [export_dir]
# Renders with a transparent background (the ground is a shadow catcher); composite afterwards.
# export_dir gets brick_donut_<shape>.blend (the breathing loop keyframed, 24 fps) and .obj/.mtl.
# Needs Blender's Python module (pip install bpy).
import bpy, bmesh, math, random, sys, os

shape = sys.argv[1]
out = sys.argv[2]
mode = sys.argv[3] if len(sys.argv) > 3 else "still"
export_dir = sys.argv[4] if len(sys.argv) > 4 else None
rng = random.Random(11)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def mat(name, hexcolor, rough=0.45, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*srgb(hexcolor), 1)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*srgb(hexcolor), 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


MATS = {
    "baked": mat("Baked", "#b06a32", 0.65),
    "dough": mat("Dough", "#e09d58", 0.6),
    "glaze": mat("Glaze", "#ff6fa3", 0.25),
    "crown": mat("Crown", "#fff4fa", 0.3),
    "shoe": mat("Shoe", "#38c96a", 0.4),
    "sole": mat("Sole", "#f4f4f4", 0.5),
}
FACE_MATS = {
    "white": mat("EyeWhite", "#ffffff", 0.3),
    "pupil": mat("Pupil", "#1e1418", 0.2),
    "glint": mat("Glint", "#ffffff", 0.2, emit=2.5),
    "mouth": mat("Mouth", "#5a1f2a", 0.4),
    "tongue": mat("Tongue", "#ff5f7e", 0.4),
    "cheek": mat("Cheek", "#ff8fb4", 0.6),
}
SPRINKLES = [mat(f"Sprinkle{i}", c, 0.35) for i, c in enumerate(["#ffd23f", "#4fb8ff", "#8b5cf6", "#3ddc84", "#ff8a3d"])]

# ---- the voxels: (x, y, z) -> material key. x, y in cells (ring in XY, y up), z in half cells
#      (front = +z: baked z 0, dough 1..4, glaze 5..6, crown 7) ----------------------------------
vox = {}
H = 0.5  # height of one z step
DOUGH_TOP = 4  # last dough z


def in_ring(x, y, rin, rout, cut):
    if shape == "round":
        r = math.hypot(x, y)
        return rin <= r <= rout
    d = max(abs(x), abs(y))  # square ring with its corners cut off
    return rin <= d <= rout and abs(x) + abs(y) <= cut


N = 7
for x in range(-N, N + 1):
    for y in range(-N, N + 1):
        if shape == "round":
            dough, glaze, crown = in_ring(x, y, 2.6, 6.5, 0), in_ring(x, y, 3.0, 5.7, 0), in_ring(x, y, 3.6, 5.0, 0)
        else:
            dough, glaze, crown = in_ring(x, y, 2, 6, 10), in_ring(x, y, 2, 5, 8), in_ring(x, y, 3, 4, 6)
        if dough:
            vox[x, y, 0] = "baked"
            for z in range(1, DOUGH_TOP + 1):
                vox[x, y, z] = "dough"
        if glaze:
            for z in (DOUGH_TOP + 1, DOUGH_TOP + 2):
                vox[x, y, z] = "glaze"
        if crown:
            vox[x, y, DOUGH_TOP + 3] = "crown"

# drips: glaze running down the dough's front from the bottom of the glaze; some stop on the
# dough, the rest hang one cube past the rim (always touching the cube above)
drip_cols = [-5, -3, 0, 4]
for x in drip_cols:
    ys = sorted(y for (vx, y, z), m in vox.items() if vx == x and m == "glaze" and y < 0)
    if not ys:
        continue
    length = rng.choice([1, 2, 3])
    for k in range(1, length + 1):
        y = ys[0] - k
        on_dough = (x, y, 0) in vox
        for z in (DOUGH_TOP, DOUGH_TOP + 1):
            vox[x, y, z] = "glaze"
        if not on_dough:
            break

# legs and shoes (below the ring, in the middle of the dough's depth)
for sx in (-1, 1):
    x = sx * 2
    bottom = min(y for (vx, y, z) in vox if vx == x and z == 0)
    for y in range(bottom - 3, bottom):
        for z in (1, 2, 3):
            vox[x, y, z] = "dough"
    for dx in (0, sx):
        for z in range(0, 6):
            vox[x + dx, bottom - 4, z] = "shoe"
            vox[x + dx, bottom - 5, z] = "sole"
FEET_Y = min(y for (_, y, _) in vox) - 0.5

# ---- the face: flat tiles (no studs under them), in cell units, laid on the ring's top ---------
def top_of(x, y):
    zs = [z for (vx, vy, z) in vox if vx == x and vy == y]
    return (max(zs) + 1) * H if zs else None


def cells_under(x0, x1, y0, y1):
    e = 1e-3
    return [(cx, cy) for cx in range(math.floor(x0 + 0.5 + e), math.floor(x1 + 0.5 - e) + 1)
            for cy in range(math.floor(y0 + 0.5 + e), math.floor(y1 + 0.5 - e) + 1)]


TILE = 0.2
face_boxes = []  # (part, material, x0, x1, y0, y1, z0, z1)


def tile(part, m, x0, x1, y0, y1, on=None, t=TILE):
    if on is None:
        tops = [top_of(cx, cy) for cx, cy in cells_under(x0, x1, y0, y1)]
        tops = [t_ for t_ in tops if t_ is not None]
        z0, z1 = min(tops) - 0.05, max(tops) + t
    else:
        z0, z1 = on - 0.02, on + t
    face_boxes.append((part, m, x0, x1, y0, y1, z0, z1))
    return z1


EYE_Y0, EYE_Y1 = 2.85, 4.5
for sx in (-1, 1):
    # big shiny dark eyes (they read on any glaze colour), a shine in the top-left corner of each
    ix, ox = 1.85, 3.15  # inner and outer edge
    xa, xb = sorted((sx * ix, sx * ox))
    etop = tile(f"Eye{sx}", "pupil", xa, xb, EYE_Y0, EYE_Y1)
    tile(f"Eye{sx}", "glint", xa + 0.17, xa + 0.6, EYE_Y1 - 0.62, EYE_Y1 - 0.19, on=etop, t=0.05)
    tile(f"Eye{sx}", "glint", xb - 0.42, xb - 0.2, EYE_Y0 + 0.22, EYE_Y0 + 0.44, on=etop, t=0.05)
    ca, cb = sorted((sx * 3.5, sx * 4.45))
    tile("Face", "cheek", ca, cb, 2.9, 3.4)
# a little smile: a bar with turned-up corners, a tongue in the middle
mtop = tile("Face", "mouth", -0.8, 0.8, 2.8, 3.3)
for sx in (-1, 1):
    a, b = sorted((sx * 0.8, sx * 1.22))
    tile("Face", "mouth", a, b, 3.1, 3.58)
tile("Face", "tongue", -0.4, 0.4, 2.8, 3.08, on=mtop, t=0.04)


def under_face(x, y):
    r = 0.32
    return any(b[2] < x + r and b[3] > x - r and b[4] < y + r and b[5] > y - r for b in face_boxes)


# ---- meshing: one face per exposed cube side, grouped into one object per material ----------
FACE_DIRS = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]


def cube_face(x, y, z, d):
    cx, cy, cz = x, y, z * H + H / 2
    hx, hy, hz = 0.5, 0.5, H / 2
    dx, dy, dz = d
    if dx:
        X = cx + dx * hx
        return [(X, cy - hy, cz - hz), (X, cy + hy, cz - hz), (X, cy + hy, cz + hz), (X, cy - hy, cz + hz)][:: (1 if dx > 0 else -1)]
    if dy:
        Y = cy + dy * hy
        return [(cx - hx, Y, cz - hz), (cx - hx, Y, cz + hz), (cx + hx, Y, cz + hz), (cx + hx, Y, cz - hz)][:: (1 if dy > 0 else -1)]
    Z = cz + dz * hz
    return [(cx - hx, cy - hy, Z), (cx + hx, cy - hy, Z), (cx + hx, cy + hy, Z), (cx - hx, cy + hy, Z)][:: (1 if dz > 0 else -1)]


groups = {}
for (x, y, z), m in vox.items():
    for d in FACE_DIRS:
        if (x + d[0], y + d[1], z + d[2]) not in vox:
            groups.setdefault(m, []).append(cube_face(x, y, z, d))

STUD_R, STUD_H, STUD_SIDES = 0.3, 0.18, 12


def add_stud(bm, x, y, ztop):
    # a stud: a short cylinder standing on the cube's top (front) face
    ring_lo, ring_hi = [], []
    for i in range(STUD_SIDES):
        a = 2 * math.pi * i / STUD_SIDES
        px, py = x + STUD_R * math.cos(a), y + STUD_R * math.sin(a)
        ring_lo.append(bm.verts.new((px, py, ztop)))
        ring_hi.append(bm.verts.new((px, py, ztop + STUD_H)))
    for i in range(STUD_SIDES):
        j = (i + 1) % STUD_SIDES
        bm.faces.new((ring_lo[i], ring_lo[j], ring_hi[j], ring_hi[i]))
    bm.faces.new(ring_hi)


meshes = {}
for m, faces in groups.items():
    bm = bmesh.new()
    for f in faces:
        bm.faces.new([bm.verts.new(v) for v in f])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    meshes[m] = bm

# studs on every exposed front-facing top of the dough / glaze / crown / shoes, except under the
# face tiles; some glaze studs are sprinkle coloured
sprinkle_bms = [bmesh.new() for _ in SPRINKLES]
for (x, y, z), m in sorted(vox.items()):
    if m in ("dough", "glaze", "crown", "shoe") and (x, y, z + 1) not in vox and not under_face(x, y):
        ztop = (z + 1) * H
        if m == "glaze" and rng.random() < 0.3:
            add_stud(sprinkle_bms[rng.randrange(len(SPRINKLES))], x, y, ztop)
        else:
            add_stud(meshes[m], x, y, ztop)

pivot = bpy.data.objects.new("Pivot", None)  # at the feet, so breathing squashes toward the ground
scene.collection.objects.link(pivot)
root = bpy.data.objects.new("BrickDonut", None)
scene.collection.objects.link(root)
root.parent = pivot


def finish(name, bm, materials, bevel=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    for m in materials:
        ob.data.materials.append(m)
    ob.parent = root
    if bevel:
        b = ob.modifiers.new("Bevel", "BEVEL")
        b.width = 0.05
        b.segments = 1
        b.limit_method = "ANGLE"
    return ob


parts = {}
for m, bm in meshes.items():
    parts[m] = finish(m.capitalize(), bm, [MATS[m]])
for i, bm in enumerate(sprinkle_bms):
    parts[f"sprinkle{i}"] = finish(f"Sprinkles{i}", bm, [SPRINKLES[i]])

# face parts: one object per eye (its origin in the eye's middle, so it can blink) and the rest
fkeys = list(FACE_MATS)
for part in sorted({b[0] for b in face_boxes}):
    boxes = [b for b in face_boxes if b[0] == part]
    ox = (min(b[2] for b in boxes) + max(b[3] for b in boxes)) / 2 if part.startswith("Eye") else 0
    oy = (min(b[4] for b in boxes) + max(b[5] for b in boxes)) / 2 if part.startswith("Eye") else 0
    bm = bmesh.new()
    for _, m, x0, x1, y0, y1, z0, z1 in boxes:
        x0, x1, y0, y1 = x0 - ox, x1 - ox, y0 - oy, y1 - oy
        v = [bm.verts.new(p) for p in [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                                        (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]]
        for idx in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
            bm.faces.new([v[i] for i in idx]).material_index = fkeys.index(m)
    ob = finish(part, bm, [FACE_MATS[k] for k in fkeys])
    ob.modifiers["Bevel"].width = 0.03
    ob.location = (ox, oy, 0)
    parts[part] = ob

# stand it up like a wheel, face to the camera; scale cells to the game's donut size (~4.6 studs)
CELL = 4.6 / 13
FEET_Z = FEET_Y * CELL
root.rotation_euler = (math.radians(90), 0, 0)
root.scale = (CELL, CELL, CELL)
root.location = (0, 0, -FEET_Z)
pivot.location = (0, 0, FEET_Z)

# ---- effects: glowing cube sparkles circling it, a soft pink glow --------------------------
spark_mat = mat("Spark", "#fff3a0", 0.2, emit=8.0)
sparks = []
for i in range(10):
    bpy.ops.mesh.primitive_cube_add(size=0.13)
    sp = bpy.context.active_object
    sp.data.materials.append(spark_mat)
    sparks.append(sp)
glow = bpy.data.objects.new("Glow", bpy.data.lights.new("Glow", "POINT"))
glow.data.color = srgb("#ffd6ea")
glow.location = (0, -1.6, 0.3)
scene.collection.objects.link(glow)

# ground: catches the shadow only
bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, FEET_Z))
ground = bpy.context.active_object
ground.is_shadow_catcher = True

# ---- camera (three-quarter view, a little above), lights, world ---------------------------
YAW, PITCH, DIST = math.radians(28), math.radians(8), 15.5
target = (0, 0, -0.85)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 60
cam.location = (target[0] + DIST * math.sin(YAW) * math.cos(PITCH), target[1] - DIST * math.cos(YAW) * math.cos(PITCH),
                target[2] + DIST * math.sin(PITCH))
cam.rotation_euler = (math.radians(90) - PITCH, 0, YAW)
scene.collection.objects.link(cam)
scene.camera = cam
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.2
sun.data.angle = math.radians(8)
sun.rotation_euler = (math.radians(40), math.radians(-20), math.radians(-40))
scene.collection.objects.link(sun)
fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "AREA"))
fill.data.energy = 260
fill.data.size = 6
fill.location = (-3, -6, 2)
fill.rotation_euler = (math.radians(65), 0, math.radians(-25))
scene.collection.objects.link(fill)
world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (*srgb("#9ccaf0"), 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
scene.world = world

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"

LOOP = 2.5  # seconds; everything below repeats exactly every loop


def pose(t):
    # breathing: a slow squash and stretch from the feet, the glow pulsing with it, a blink once a
    # loop, sparkles circling and twinkling
    w = 2 * math.pi * t / LOOP
    b = math.sin(w)
    pivot.scale = (1 - 0.03 * b, 1 - 0.03 * b, 1 + 0.05 * b)
    glow.data.energy = 55 + 25 * (0.5 + 0.5 * b)
    blink = 0.1 if 0.82 < (t / LOOP) % 1 < 0.9 else 1.0
    for key in ("Eye-1", "Eye1"):
        parts[key].scale = (1, blink, 1)
    for i, sp in enumerate(sparks):
        a = 2 * math.pi * i / len(sparks) + 2 * w / len(sparks)
        rad = 2.95 + 0.25 * math.sin(w + i)
        sp.location = (rad * math.cos(a), -0.4 + 0.7 * math.sin(a * 2), rad * math.sin(a) * 0.95 - 0.35)
        sp.rotation_euler = (w + i, w * 2, i)
        s = 0.55 + 0.6 * (0.5 + 0.5 * math.sin(2 * w + i * 1.7))
        sp.scale = (s, s, s)


if mode == "breathe":
    os.makedirs(out, exist_ok=True)
    scene.cycles.samples = 24
    scene.render.resolution_x = 480
    scene.render.resolution_y = 480
    frames = 30
    for f in range(frames):
        pose(f / frames * LOOP)
        scene.render.filepath = os.path.join(out, f"f{f:03d}.png")
        bpy.ops.render.render(write_still=True)
elif mode == "still":
    pose(0.0)
    scene.cycles.samples = 64
    scene.render.resolution_x = 700
    scene.render.resolution_y = 700
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)

dg = bpy.context.evaluated_depsgraph_get()
tris = {}
for ob in root.children:
    me = ob.evaluated_get(dg).to_mesh()
    me.calc_loop_triangles()
    tris[ob.name] = len(me.loop_triangles)
    ob.evaluated_get(dg).to_mesh_clear()
print("TRIANGLES", sum(tris.values()), "OBJECTS", len(tris), tris)

if export_dir:
    os.makedirs(export_dir, exist_ok=True)
    # key the loop into the timeline so it plays in Blender (frame 1 .. 60 at 24 fps = 2.5 s)
    scene.render.fps = 24
    scene.frame_start, scene.frame_end = 1, int(LOOP * 24)
    for f in range(scene.frame_start, scene.frame_end + 2):
        pose((f - 1) / 24)
        pivot.keyframe_insert("scale", frame=f)
        glow.data.keyframe_insert("energy", frame=f)
        for key in ("Eye-1", "Eye1"):
            parts[key].keyframe_insert("scale", frame=f)
        for sp in sparks:
            for path in ("location", "rotation_euler", "scale"):
                sp.keyframe_insert(path, frame=f)
    scene.frame_set(1)
    scene.render.film_transparent = False
    scene.cycles.samples = 64
    scene.render.resolution_x = scene.render.resolution_y = 1080
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(os.path.join(export_dir, f"brick_donut_{shape}.blend")))
    for ob in sparks + [ground]:
        bpy.data.objects.remove(ob)
    bpy.ops.wm.obj_export(filepath=os.path.join(export_dir, f"brick_donut_{shape}.obj"), apply_modifiers=True)
