"""
Loading screen art for Steal a Donut, made in Blender.

    PYTHONPATH=<folder with bpy> python3 loading_screen.py [key_art.jpg] [LoadingScene.luau] [samples] [width]

One scene, used two ways:
  * exported as blocks (src/first/LoadingScene.luau) that the loading screen builds in a
    ViewportFrame: the 3D bandit donut you see while the game loads, nothing to upload;
  * rendered with Cycles into key_art.jpg (1920x1080): the same scene with soft light, shadows and
    a glowing stage behind it. Upload it and paste its id into KEY_ART_IMAGE in LoadingUI to show
    the picture instead.

The scene is built in the game's space (y up, the camera looking down -z from CAMERA), out of
blocks and studs like the game's square brick donuts (art/brick_donut): a donut in a bandit mask
and a crown, sneaking off with a box of donuts under his arm, on a little brick podium, with six
little donuts in the rarity colours floating behind him. Everything above the title (the top 40% of the screen) is the scene; the title,
"Loading..." and the progress donuts are the loading screen's own text on top.
"""

import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
SCREEN = (1280, 720)  # the loading screen's design size (the camera is set up for it)
# The camera: a little above the donut, looking down past it so the donut sits in the top of the
# screen, above the title (Target is solved for that below). fov = vertical field of view.
CAMERA = {"pos": (0.0, 9.0, 96.0), "fov": 30.0, "target": None}
TOP_SCREEN_Y = 30  # where the top of his crown sits on the 1280 x 720 screen (the podium ends just above the title)
RARITY_GLAZE = [(85, 225, 90), (55, 150, 255), (190, 70, 255), (255, 190, 25), (255, 110, 255), (255, 60, 60)]

BAKED = (176, 106, 50)
DOUGH = (224, 157, 88)
GLAZE = (255, 111, 163)
GLOSS = (255, 236, 246)
MASK = (30, 22, 28)
WHITE = (255, 255, 255)
GOLD = (255, 196, 48)
RUBY = (230, 40, 70)
SHOE = (56, 201, 106)


# -----------------------------------------------------------------------------------------------
# Blocks. A block is in its group's space; a group has a pivot (position + turn). Turns are
# Roblox's CFrame.Angles(rx, ry, rz) in degrees: the matrix Rx * Ry * Rz.
# -----------------------------------------------------------------------------------------------
def rot(rx, ry, rz):
    rx, ry, rz = math.radians(rx), math.radians(ry), math.radians(rz)
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    mx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    my = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    mz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return mx @ my @ mz


class Group:
    def __init__(self, name, pos=(0, 0, 0), turn=(0, 0, 0)):
        self.name, self.pos, self.turn = name, tuple(float(v) for v in pos), turn
        self.blocks = []

    def add(self, shape, size, pos, color, material="Plastic", turn=(0, 0, 0)):
        self.blocks.append({"shape": shape, "size": tuple(float(v) for v in size), "pos": tuple(float(v) for v in pos), "color": color, "material": material, "turn": turn})

    def box(self, x0, y0, z0, x1, y1, z1, color, material="Plastic", turn=(0, 0, 0)):
        self.add("Block", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, material, turn)

    def stud(self, x, y, z, color, material="Plastic", d=0.62, h=0.2):
        # a stud on a front face at depth z (Roblox cylinders lie along x: turned to face the camera)
        self.add("Cylinder", (h, d, d), (x, y, z + h / 2), color, material, (0, 90, 0))

    def world(self, block):
        g = rot(*self.turn)
        m = g @ rot(*block["turn"])
        p = np.array(self.pos) + g @ np.array(block["pos"])
        return p, m


def greedy(cells):
    """Merge a set of (x, y) cells into rectangles (x0, y0, x1, y1), inclusive."""
    left = set(cells)
    rects = []
    for (x, y) in sorted(cells, key=lambda c: (-c[1], c[0])):
        if (x, y) not in left:
            continue
        x1 = x
        while (x1 + 1, y) in left:
            x1 += 1
        y0 = y
        while all((cx, y0 - 1) in left for cx in range(x, x1 + 1)):
            y0 -= 1
        for cy in range(y0, y + 1):
            for cx in range(x, x1 + 1):
                left.discard((cx, cy))
        rects.append((x, y0, x1, y))
    return rects


def slab(group, cells, z0, z1, color, material="Plastic"):
    for (x0, y0, x1, y1) in greedy(cells):
        group.box(x0 - 0.5, y0 - 0.5, z0, x1 + 0.5, y1 + 0.5, z1, color, material)


# -----------------------------------------------------------------------------------------------
# The bandit donut. Designed like the game's own brick donuts: studs on the dough only, the icing
# smooth and glossy with a wavy edge and a few drips, sprinkles laid on top by hand. Cells are
# 1 x 1: the ring is 13 cells across with rounded (cut) corners and a 5 x 5 hole. He's sneaking
# off with a box of donuts under his arm, glancing sideways, on a little brick podium.
# -----------------------------------------------------------------------------------------------
ICING_TOP = 3.2  # the front of the icing
HIP = -6.6  # the body turns round this height (the legs stay put)


def ring_cell(x, y):
    m = max(abs(x), abs(y))
    return 2 < m <= 6 and abs(x) + abs(y) <= 9


# the icing's lowest row in each column: a wavy edge with three drips (at -4, 0 and 4)
ICING_BOTTOM = {-6: -1, -5: -2, -4: -4, -3: -3, -2: -2, -1: -2, 0: -4, 1: -3, 2: -2, 3: -2, 4: -5, 5: -3, 6: -1}
MASK_ROWS = (3, 4)
HIGHLIGHT = {(-4, 5), (-3, 6), (-2, 6), (-5, 1), (-5, 0)}  # one light streak, top left
# sprinkles: (x, y, angle), placed by hand on the icing (never on the mask or the highlight)
SPRINKLE_SPOTS = [
    (-3.6, 5.5, 35), (-1.0, 5.4, -25), (0.9, 6.2, 70), (2.7, 5.5, 10), (3.9, 6.0, -55),
    (-5.4, -1.2, 80), (-3.7, 1.4, -30), (-3.4, -1.6, 50), (-5.1, 2.1, 5),
    (3.7, 1.6, 20), (5.3, 0.4, -70), (4.1, -1.3, 40), (5.5, -2.2, 95), (-0.4, -2.6, 30),
]
SPRINKLE_COLORS = [WHITE, (255, 214, 72), (110, 200, 255), (130, 230, 160)]


def iced(x, y):
    return ring_cell(x, y) and y >= ICING_BOTTOM[x] and y not in MASK_ROWS


def hero():
    """The body (Hero, turned at the hips) and the legs (Legs)."""
    body = Group("Hero", (0, HIP, 0), (0, -12, -3))
    legs = Group("Legs", (0, 0, 0), (0, -12, 0))

    def at(x, y):  # (a body position in the donut's own space, relative to the hips)
        return x, y - HIP

    def bbox(x0, y0, z0, x1, y1, z1, color, material="Plastic", turn=(0, 0, 0)):
        body.box(x0, y0 - HIP, z0, x1, y1 - HIP, z1, color, material, turn)

    def bslab(cells, z0, z1, color, material="Plastic"):
        for (x0, y0, x1, y1) in greedy(cells):
            bbox(x0 - 0.5, y0 - 0.5, z0, x1 + 0.5, y1 + 0.5, z1, color, material)

    cells = [(x, y) for x in range(-6, 7) for y in range(-6, 7) if ring_cell(x, y)]
    icing = [c for c in cells if iced(*c)]
    # the icing pours over the outside edge and into the hole a little (deeper there)
    edge = [c for c in icing if max(abs(c[0]), abs(c[1])) in (3, 6) or abs(c[0]) + abs(c[1]) == 9]
    bslab(cells, -1.0, 0.0, BAKED)
    bslab(cells, 0.0, 2.4, DOUGH)
    bslab([c for c in icing if c not in edge], 2.4, ICING_TOP, GLAZE, "SmoothPlastic")
    bslab(edge, 1.3, ICING_TOP, GLAZE, "SmoothPlastic")
    bslab([c for c in icing if c in HIGHLIGHT], ICING_TOP, ICING_TOP + 0.22, GLOSS, "SmoothPlastic")
    for i, (x, y, angle) in enumerate(SPRINKLE_SPOTS):
        px, py = at(x, y)
        body.add("Block", (0.95, 0.3, 0.26), (px, py, ICING_TOP + 0.13), SPRINKLE_COLORS[i % len(SPRINKLE_COLORS)], "SmoothPlastic", (0, 0, angle))
    # studs on the dough (the bottom of the ring, below the icing)
    for (x, y) in cells:
        if not iced(x, y) and y not in MASK_ROWS:
            px, py = at(x, y)
            body.stud(px, py, 2.4, DOUGH)

    # the mask: a band round the top of the ring, knotted on the right with two loose ends
    bslab([(x, y) for x in range(-6, 7) for y in MASK_ROWS if ring_cell(x, y)], -1.1, ICING_TOP + 0.2, MASK, "SmoothPlastic")
    bbox(-6.7, 2.5, -1.1, -6.0, 4.5, ICING_TOP + 0.2, MASK, "SmoothPlastic")
    bbox(6.0, 2.5, -1.1, 6.7, 4.5, ICING_TOP + 0.2, MASK, "SmoothPlastic")
    for (x, y, w, angle) in ((7.6, 4.2, 1.9, 24), (7.4, 2.6, 1.7, -30)):
        px, py = at(x, y)
        body.add("Block", (w, 0.75, 0.6), (px, py, 1.0), MASK, "SmoothPlastic", (0, 0, angle))
    # round eyes, glancing to the right, and sly eyebrows (one down, one up)
    front = ICING_TOP + 0.2
    for ex, brow_y, brow_turn in ((-2.9, 5.35, -14), (2.9, 5.55, 8)):
        px, py = at(ex, 3.55)
        body.stud(px, py, front, WHITE, "SmoothPlastic", d=2.35, h=0.3)
        px, py = at(ex + 0.55, 3.35)
        body.stud(px, py, front + 0.3, MASK, "SmoothPlastic", d=1.1, h=0.2)
        px, py = at(ex + 0.8, 3.7)
        body.stud(px, py, front + 0.5, WHITE, "SmoothPlastic", d=0.36, h=0.08)
        px, py = at(ex, brow_y)
        body.add("Block", (2.1, 0.45, 0.3), (px, py, ICING_TOP + 0.15), MASK, "SmoothPlastic", (0, 0, brow_turn))
    # a small crown, knocked to one side
    crown = [((0, 0), (3.4, 0.9)), ((-1.25, 0.85), (0.75, 0.9)), ((0, 1.0), (0.75, 1.2)), ((1.25, 0.85), (0.75, 0.9))]
    cx, cy, tilt = 1.5, 7.05, -14
    c, s_ = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
    for ((dx, dy), (w, h)) in crown:
        px, py = at(cx + dx * c - dy * s_, cy + dx * s_ + dy * c)
        body.add("Block", (w, h, 1.4), (px, py, 1.2), GOLD, "SmoothPlastic", (0, 0, tilt))
    px, py = at(cx, cy)
    body.add("Block", (0.6, 0.5, 0.3), (px, py, 2.0), RUBY, "SmoothPlastic", (0, 0, tilt))
    # arms: the left one swinging back, the right one round a stolen box of donuts
    for (x, y, h, angle) in ((-7.0, -1.0, 2.6, -28), (6.9, -0.9, 2.4, 24)):
        px, py = at(x, y)
        body.add("Block", (0.85, h, 0.85), (px, py, 1.2), DOUGH, "Plastic", (0, 0, angle))
    px, py = at(-7.75, -2.25)
    body.add("Block", (1.0, 1.0, 1.0), (px, py, 1.2), DOUGH)
    bbox(6.6, -4.4, -0.3, 9.6, -2.2, 2.9, (255, 150, 190), "SmoothPlastic")  # the box (pink, white lid)
    bbox(6.5, -2.4, -0.4, 9.7, -1.9, 3.0, WHITE, "SmoothPlastic")
    bbox(7.6, -4.4, 2.9, 8.6, -2.4, 3.0, WHITE, "SmoothPlastic")  # a white stripe down the front
    px, py = at(7.4, -2.0)
    body.add("Block", (1.0, 1.0, 1.0), (px, py, 3.0), DOUGH)  # the hand on top of it

    # legs apart, feet turned out a little, white soles; studs on the legs
    for lx, turn in ((-2.4, 14), (2.4, -14)):
        legs.box(lx - 0.9, -10.0, 0.2, lx + 0.9, HIP + 0.4, 2.0, DOUGH)
        for y in (-7.4, -8.6):
            legs.stud(lx - 0.45, y, 2.0, DOUGH)
            legs.stud(lx + 0.45, y, 2.0, DOUGH)
        legs.add("Block", (3.2, 1.0, 3.8), (lx, -10.4, 1.4), SHOE, "SmoothPlastic", (0, turn, 0))
        legs.add("Block", (3.3, 0.45, 3.9), (lx, -11.1, 1.4), WHITE, "Plastic", (0, turn, 0))
        legs.add("Block", (1.4, 0.3, 0.9), (lx, -9.8, 2.95), WHITE, "SmoothPlastic", (0, turn, 0))  # laces
    return [body, legs]


def podium():
    """A round brick podium under his feet: a dark disc, a lighter rim and studs round the edge."""
    g = Group("Podium", (0, -12.0, 1.0), (0, 0, 90))  # (Roblox cylinders lie along x: stood up)
    g.add("Cylinder", (1.6, 15.0, 15.0), (0, 0, 0), (74, 54, 112), "Plastic")
    g.add("Cylinder", (0.25, 15.6, 15.6), (0.85, 0, 0), (122, 98, 170), "SmoothPlastic")
    for i in range(18):
        a = 2 * math.pi * i / 18
        g.add("Cylinder", (0.22, 0.75, 0.75), (1.08, 6.7 * math.cos(a), 6.7 * math.sin(a)), (122, 98, 170), "SmoothPlastic")
    return g


# -----------------------------------------------------------------------------------------------
# The camera, and little donuts in the rarity colours floating round
# -----------------------------------------------------------------------------------------------
def basis(target):
    """The camera's right, up and forward directions when it looks at `target`."""
    eye = np.array(CAMERA["pos"])
    f = np.array(target) - eye
    f = f / np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0])
    r = r / np.linalg.norm(r)
    return r, np.cross(r, f), f


def project(p, target=None):
    r, u, f = basis(target or CAMERA["target"])
    d = np.array(p) - np.array(CAMERA["pos"])
    depth = d @ f
    t = math.tan(math.radians(CAMERA["fov"] / 2))
    aspect = SCREEN[0] / SCREEN[1]
    nx, ny = (d @ r) / (depth * t * aspect), (d @ u) / (depth * t)
    return (SCREEN[0] / 2 + nx * SCREEN[0] / 2, SCREEN[1] / 2 - ny * SCREEN[1] / 2)


def unproject(sx, sy, z):
    """The point at depth z (the game's z) that the camera shows at (sx, sy) on the 1280 x 720 screen."""
    r, u, f = basis(CAMERA["target"])
    t = math.tan(math.radians(CAMERA["fov"] / 2))
    aspect = SCREEN[0] / SCREEN[1]
    nx, ny = (sx - SCREEN[0] / 2) / (SCREEN[0] / 2), (SCREEN[1] / 2 - sy) / (SCREEN[1] / 2)
    ray = f + r * nx * t * aspect + u * ny * t
    eye = np.array(CAMERA["pos"])
    k = (z - eye[2]) / ray[2]
    return tuple((eye + ray * k).tolist())


def aim():
    """Point the camera so the top of the crown shows TOP_SCREEN_Y down the screen."""
    lo, hi = -80.0, 0.0
    for _ in range(60):
        mid = (lo + hi) / 2
        y = project((0, 9.0, 0), (0, mid, 0))[1]
        if y < TOP_SCREEN_Y:
            lo = mid  # the donut is too high up the screen: look less far down
        else:
            hi = mid
    CAMERA["target"] = (0.0, (lo + hi) / 2, 0.0)


def mini(name, screen_xy, z, turn, glaze, size=1.5):
    g = Group(name, unproject(screen_xy[0], screen_xy[1], z), turn)
    s = size
    cells = [(x, y) for x in range(-2, 2) for y in range(-2, 2) if not (x in (-1, 0) and y in (-1, 0))]

    def slab_s(cs, z0, z1, color, material="Plastic"):
        for (x0, y0, x1, y1) in greedy(cs):
            g.box((x0) * s, (y0) * s, z0 * s, (x1 + 1) * s, (y1 + 1) * s, z1 * s, color, material)

    slab_s(cells, -0.5, 0.45, DOUGH)
    slab_s([c for c in cells if c[1] > -2 or c[0] == -1], 0.45, 0.8, glaze, "SmoothPlastic")
    g.box(-2 * s, 1 * s, 0.8 * s, -1 * s, 2 * s, 1.0 * s, WHITE, "SmoothPlastic")  # a shine
    return g


def scene():
    aim()
    groups = hero() + [podium()]
    spots = [((210, 105), -22, (12, 30, 18)), ((95, 262), -6, (-10, 40, -12)), ((385, 240), -34, (20, -25, 10)),
             ((1070, 105), -22, (12, -30, -18)), ((1185, 262), -6, (-10, -40, 12)), ((895, 240), -34, (20, 25, -10))]
    for i, ((sx, sy), z, turn) in enumerate(spots):
        groups.append(mini("Mini%d" % (i + 1), (sx, sy), z, turn, RARITY_GLAZE[i]))
    return groups


# -----------------------------------------------------------------------------------------------
# Export for the game
# -----------------------------------------------------------------------------------------------
def fmt(v):
    s = "%.3f" % v
    s = s.rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def export(groups, path):
    lines = [
        "--!strict",
        "--[[",
        "\tLoadingScene: the 3D scene on the loading screen, made in Blender (art/loading_screen/loading_screen.py",
        "\tbuilds it and writes this file - don't edit it by hand). The bandit donut on his podium and six little",
        "\tdonuts in the rarity colours, as blocks and studs; LoadingUI builds them in a ViewportFrame.",
        "",
        "\tCamera: where the camera sits, the point it looks at, and its vertical field of view.",
        "\tGroups: each group's pivot (Position + Turn, degrees: CFrame.Angles) and its blocks, placed",
        "\trelative to the pivot (Offset). Shape is \"Block\" or \"Cylinder\" (a stud).",
        "]]",
        "",
        "export type Block = { Shape: string, Size: Vector3, Offset: CFrame, Color: Color3, Material: Enum.Material }",
        "export type Group = { Name: string, Pivot: CFrame, Blocks: { Block } }",
        "",
        "local LoadingScene = {}",
        "",
        "local function block(shape: string, sx: number, sy: number, sz: number, x: number, y: number, z: number, color: number, material: Enum.Material, rx: number?, ry: number?, rz: number?): Block",
        "\tlocal offset = CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))",
        "\treturn { Shape = shape, Size = Vector3.new(sx, sy, sz), Offset = offset, Color = Color3.fromHex(string.format(\"%06x\", color)), Material = material }",
        "end",
        "",
        "local function group(name: string, x: number, y: number, z: number, rx: number, ry: number, rz: number, blocks: { Block }): Group",
        "\treturn { Name = name, Pivot = CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz)), Blocks = blocks }",
        "end",
        "",
        "local B, C = \"Block\", \"Cylinder\"",
        "local P, S = Enum.Material.Plastic, Enum.Material.SmoothPlastic",
        "",
        "LoadingScene.Camera = { Position = Vector3.new(%s, %s, %s), Target = Vector3.new(%s, %s, %s), FieldOfView = %s }"
        % (*(fmt(v) for v in CAMERA["pos"]), *(fmt(v) for v in CAMERA["target"]), fmt(CAMERA["fov"])),
        "",
        "LoadingScene.Groups = {",
    ]
    count = 0
    for g in groups:
        lines.append("\tgroup(\"%s\", %s, %s, %s, %s, %s, %s, {" % (g.name, *(fmt(v) for v in g.pos), *(fmt(v) for v in g.turn)))
        for b in g.blocks:
            color = "0x%02x%02x%02x" % b["color"]
            args = [("B" if b["shape"] == "Block" else "C")] + [fmt(v) for v in b["size"]] + [fmt(v) for v in b["pos"]] + [color, "S" if b["material"] == "SmoothPlastic" else "P"]
            if any(abs(t) > 1e-9 for t in b["turn"]):
                args += [fmt(t) for t in b["turn"]]
            lines.append("\t\tblock(%s)," % ", ".join(args))
            count += 1
        lines.append("\t}),")
    lines += ["}", "", "return LoadingScene", ""]
    with open(path, "w") as f:
        f.write("\n".join(lines))
    print("exported", count, "blocks to", path)


# -----------------------------------------------------------------------------------------------
# Key art: the same scene rendered with Cycles over a glowing stage (numpy), 1920 x 1080
# -----------------------------------------------------------------------------------------------
def lin(c):
    c = c / 255
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


def blender_scene(groups, samples, width, height):
    import bpy
    import bmesh
    from mathutils import Matrix, Vector

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    mats = {}

    def material(rgb, kind):
        key = (rgb, kind)
        if key not in mats:
            m = bpy.data.materials.new("M%d" % len(mats))
            m.use_nodes = True
            b = m.node_tree.nodes["Principled BSDF"]
            b.inputs["Base Color"].default_value = (lin(rgb[0]), lin(rgb[1]), lin(rgb[2]), 1)
            b.inputs["Roughness"].default_value = 0.22 if kind == "SmoothPlastic" else 0.5
            b.inputs["Coat Weight"].default_value = 0.5 if kind == "SmoothPlastic" else 0.0
            b.inputs["Coat Roughness"].default_value = 0.08
            mats[key] = m
        return mats[key]

    P = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]])  # game (y up, z front) -> Blender (z up, -y front)
    for g in groups:
        for i, b in enumerate(g.blocks):
            p, m = g.world(b)
            bm = bmesh.new()
            sx, sy, sz = b["size"]
            if b["shape"] == "Block":
                bmesh.ops.create_cube(bm, size=1)
                for v in bm.verts:
                    v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
                bevel = min(sx, sy, sz) * 0.16
            else:
                # Roblox cylinders lie along x
                bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=sy / 2, radius2=sy / 2, depth=sx)
                for v in bm.verts:
                    v.co = Vector((v.co.z, v.co.y, -v.co.x))
                bevel = min(sx, sy) * 0.25
            for v in bm.verts:
                local = np.array(v.co[:])
                w = P @ (p + m @ local)
                v.co = Vector(w.tolist())
            me = bpy.data.meshes.new(g.name)
            bm.to_mesh(me)
            bm.free()
            for poly in me.polygons:
                poly.use_smooth = True
            ob = bpy.data.objects.new("%s%d" % (g.name, i), me)
            me.materials.append(material(b["color"], b["material"]))
            mod = ob.modifiers.new("Bevel", "BEVEL")
            mod.width = bevel
            mod.segments = 3
            mod.limit_method = "ANGLE"
            mod.harden_normals = True
            scene.collection.objects.link(ob)

    def light(name, energy, size, loc, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.size, data.color = energy, size, color
        ob = bpy.data.objects.new(name, data)
        ob.location = loc
        ob.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(ob)

    light("Key", 52000, 40, (-45, -70, 55), (1, 0.97, 0.93))
    light("Fill", 14000, 50, (60, -60, 5), (0.85, 0.9, 1))
    light("RimPink", 30000, 25, (35, 45, 30), (1, 0.45, 0.75))
    light("RimBlue", 26000, 25, (-40, 45, 20), (0.45, 0.65, 1))
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.25, 0.5, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.35
    scene.world = world

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.sensor_fit = "VERTICAL"
    cam_data.angle = math.radians(CAMERA["fov"])
    cam_data.dof.use_dof = True
    cam_data.dof.focus_distance = CAMERA["pos"][2] - 1.5
    cam_data.dof.aperture_fstop = 2.2
    cam = bpy.data.objects.new("Cam", cam_data)
    cx, cy, cz = CAMERA["pos"]
    cam.location = (cx, -cz, cy)
    tx, ty, tz = CAMERA["target"]
    cam.rotation_euler = (Vector((tx, -tz, ty)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam

    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    return scene


def stage(width, height):
    """The stage behind the scene: a purple glow and soft spotlights fanning down."""
    ys, xs = np.mgrid[0:height, 0:width].astype(np.float64)
    u, v = xs / width, ys / height
    aspect = width / height
    # a deep purple, brightest behind the donut
    d = np.sqrt(((u - 0.5) * aspect) ** 2 + (v - 0.27) ** 2)
    inner, outer = np.array([96, 44, 132]) / 255, np.array([16, 10, 30]) / 255
    t = np.clip(d / 1.05, 0, 1)[..., None] ** 0.8
    img = inner * (1 - t) + outer * t
    # spotlights from above the donut
    ax, ay = 0.5 * width, -0.12 * height
    ang = np.degrees(np.arctan2(xs - ax, ys - ay))
    dist = np.sqrt((xs - ax) ** 2 + (ys - ay) ** 2) / height
    for a, w, s in ((-38, 5.5, 0.07), (-22, 4.0, 0.09), (-8, 3.0, 0.11), (8, 3.0, 0.11), (22, 4.0, 0.09), (38, 5.5, 0.07)):
        beam = np.exp(-((ang - a) / w) ** 2) * np.clip(1.15 - dist, 0, 1) ** 1.6 * s
        img = img + beam[..., None] * np.array([1.0, 0.92, 1.0])
    # a pink glow right behind the donut
    g = np.exp(-(d / 0.23) ** 2) * 0.22
    img = img + g[..., None] * np.array([1.0, 0.45, 0.75])
    # darker at the edges and the bottom (where the loading screen's text goes)
    vig = np.clip(1 - (((u - 0.5) * 1.3) ** 2 + ((v - 0.4) * 1.1) ** 2) * 0.9, 0.25, 1)
    img = img * vig[..., None]
    img = img * (1 - 0.45 * np.clip((v - 0.6) / 0.4, 0, 1))[..., None]
    return np.clip(img, 0, 1)


def key_art(groups, path, samples=96, width=1920, height=1080):
    import bpy

    scene = blender_scene(groups, samples, width, height)
    raw = path + ".raw.png"
    scene.render.filepath = raw
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(raw)
    px = np.array(img.pixels[:], dtype=np.float64).reshape(height, width, 4)[::-1]
    bpy.data.images.remove(img)
    os.remove(raw)
    back = stage(width, height)
    a = px[..., 3:4]
    out = px[..., :3] * a + back * (1 - a)
    result = bpy.data.images.new("KeyArt", width, height, alpha=False)
    rgba = np.concatenate([out, np.ones((height, width, 1))], axis=2)
    result.pixels[:] = rgba[::-1].astype(np.float32).ravel()
    result.filepath_raw = path
    result.file_format = "JPEG"
    bpy.context.scene.render.image_settings.quality = 92
    result.save()
    print("key art", path)


def main():
    art = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "key_art.jpg")
    module = sys.argv[2] if len(sys.argv) > 2 else os.path.join(REPO, "src", "first", "LoadingScreen", "LoadingScene.luau")
    samples = int(sys.argv[3]) if len(sys.argv) > 3 else 96
    width = int(sys.argv[4]) if len(sys.argv) > 4 else 1920  # (smaller for a quick test)
    groups = scene()
    if module != "-":
        export(groups, module)
    if art != "-":
        key_art(groups, os.path.abspath(art), samples, width, width * 9 // 16)


if __name__ == "__main__":
    main()
