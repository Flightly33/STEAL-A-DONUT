"""
HUD icons for Steal a Donut, made in Blender: chunky, glossy 3D icons with a thick dark sticker
outline, like the big simulator games. One transparent PNG per icon goes into png/, named like the
game's own drawn icons (client/UI/Icons), plus a contact sheet of all of them.

    PYTHONPATH=<folder with bpy> python3 hud_icons.py [png_dir] [sheet.png] [only,these]

In the game: upload the PNGs (Studio: Asset Manager > Bulk Import, or Creator Hub > Images) and
paste each image's id into Config.IconImages. Until then the game draws its own icons from Frames.

Everything is built from simple shapes (rounded boxes, cylinders, spheres, tori and extruded
outlines), lit by three soft lights and rendered with Cycles. The outline and the soft shadow under
it are added afterwards (numpy): the icon's silhouette, grown by OUTLINE pixels.
"""

import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SIZE = 512  # pixels, square
FILL = 0.8  # how much of the picture the icon fills (the rest is room for the outline and shadow)
OUTLINE = 20  # outline thickness, pixels at SIZE
OUTLINE_COLOR = (24, 20, 36)
SHADOW = (0, 14, 10, 0.4)  # x, y offset (pixels), blur, opacity
SAMPLES = int(os.environ.get("ICON_SAMPLES", "64"))

# colours (sRGB 0-255)
RED = (236, 52, 58)
RED_DARK = (160, 24, 34)
RED_LIGHT = (255, 96, 92)
BLUE = (48, 140, 255)
BLUE_LIGHT = (120, 196, 255)
BLUE_DARK = (30, 80, 190)
CREAM = (255, 243, 215)
YELLOW = (255, 206, 36)
GOLD = (255, 186, 40)
GREEN = (72, 204, 84)
GREEN_DARK = (34, 140, 60)
GREEN_LIGHT = (175, 240, 150)
PINK = (255, 112, 186)
HOT_PINK = (255, 64, 120)
PURPLE = (176, 74, 236)
WHITE = (246, 246, 252)
STEEL = (176, 186, 204)
STEEL_DARK = (96, 106, 126)
WOOD = (226, 162, 92)
WOOD_DARK = (132, 78, 42)
DOUGH = (232, 172, 102)
ORANGE = (255, 140, 30)
INK = (52, 58, 78)


def lin(c):
    c = c / 255
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


class Kit:
    """Builds the shapes of one icon into a collection, under one empty (to tilt the whole icon)."""

    def __init__(self, bpy, bmesh, name):
        self.bpy, self.bmesh = bpy, bmesh
        self.collection = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(self.collection)
        self.root = bpy.data.objects.new(name + "Root", None)
        self.collection.objects.link(self.root)
        self.mats = {}

    # -- materials --------------------------------------------------------------------------
    def mat(self, rgb, rough=0.32, metal=0.0, coat=1.0, emit=0.0):
        key = (rgb, rough, metal, coat, emit)
        if key in self.mats:
            return self.mats[key]
        m = self.bpy.data.materials.new("M%d" % len(self.mats))
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        color = (lin(rgb[0]), lin(rgb[1]), lin(rgb[2]), 1)
        b.inputs["Base Color"].default_value = color
        b.inputs["Roughness"].default_value = rough
        b.inputs["Metallic"].default_value = metal
        b.inputs["Coat Weight"].default_value = coat
        b.inputs["Coat Roughness"].default_value = 0.06
        b.inputs["Specular IOR Level"].default_value = 0.6
        if emit:
            b.inputs["Emission Color"].default_value = color
            b.inputs["Emission Strength"].default_value = emit
        self.mats[key] = m
        return m

    # -- objects ----------------------------------------------------------------------------
    def group(self, objects, loc=(0, 0, 0), rot=(0, 0, 0)):
        """Move and turn some shapes together (they were built around the origin)."""
        pivot = self.bpy.data.objects.new("Group", None)
        pivot.parent = self.root
        pivot.location = loc
        pivot.rotation_euler = [math.radians(a) for a in rot]
        self.collection.objects.link(pivot)
        for ob in objects:
            ob.parent = pivot
        return pivot

    def _object(self, name, data, color, loc, rot, bevel, segments=6, mat=None):
        bpy = self.bpy
        ob = bpy.data.objects.new(name, data)
        ob.location = loc
        ob.rotation_euler = [math.radians(a) for a in rot]
        data.materials.append(mat or self.mat(color))
        if bevel:
            mod = ob.modifiers.new("Bevel", "BEVEL")
            mod.width = bevel
            mod.segments = segments
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(35)
            mod.harden_normals = True
        ob.parent = self.root
        self.collection.objects.link(ob)
        return ob

    def _mesh(self, name, bm, color, loc, rot, bevel, smooth=True, mat=None):
        me = self.bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = smooth
        return self._object(name, me, color, loc, rot, bevel, mat=mat)

    def box(self, size, loc=(0, 0, 0), color=WHITE, rot=(0, 0, 0), bevel=None, taper=None, mat=None):
        """A box size = (x, y, z), rounded by `bevel` (default: a fifth of its thinnest side).
        taper = (top x scale, top y scale): a box that's narrower or wider at the top."""
        bm = self.bmesh.new()
        self.bmesh.ops.create_cube(bm, size=1)
        for v in bm.verts:
            sx, sy = (taper if (taper and v.co.z > 0) else (1, 1))
            v.co.x *= size[0] * sx
            v.co.y *= size[1] * sy
            v.co.z *= size[2]
        if bevel is None:
            bevel = min(size) * 0.22
        return self._mesh("Box", bm, color, loc, rot, bevel, mat=mat)

    def cylinder(self, radius, depth, loc=(0, 0, 0), color=WHITE, rot=(0, 0, 0), bevel=None, top=None, segments=64, mat=None):
        """Along its own z axis; `top` = the top radius (a cone or a taper)."""
        bm = self.bmesh.new()
        self.bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius, radius2=radius if top is None else top, depth=depth)
        if bevel is None:
            bevel = min(radius, depth) * 0.25
        return self._mesh("Cylinder", bm, color, loc, rot, bevel, mat=mat)

    def sphere(self, radius, loc=(0, 0, 0), color=WHITE, scale=(1, 1, 1), rot=(0, 0, 0), mat=None):
        bm = self.bmesh.new()
        self.bmesh.ops.create_uvsphere(bm, u_segments=64, v_segments=32, radius=radius)
        for v in bm.verts:
            v.co.x *= scale[0]
            v.co.y *= scale[1]
            v.co.z *= scale[2]
        return self._mesh("Sphere", bm, color, loc, rot, None, mat=mat)

    def torus(self, major, minor, loc=(0, 0, 0), color=WHITE, rot=(0, 0, 0), arc=360, start=0, mat=None, squash=1.0):
        """A ring around its own z axis (or just `arc` degrees of it, from `start`)."""
        bm = self.bmesh.new()
        nu, nv = 96, 28
        full = arc >= 360
        steps = nu if full else max(8, int(nu * arc / 360))
        rings = []
        for i in range(steps if full else steps + 1):
            a = math.radians(start + arc * i / steps)
            ring = []
            for j in range(nv):
                b = 2 * math.pi * j / nv
                r = major + minor * math.cos(b)
                ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), minor * math.sin(b) * squash)))
            rings.append(ring)
        count = len(rings) if full else len(rings) - 1
        for i in range(count):
            r0, r1 = rings[i], rings[(i + 1) % len(rings)]
            for j in range(nv):
                bm.faces.new((r0[j], r1[j], r1[(j + 1) % nv], r0[(j + 1) % nv]))
        ob = self._mesh("Torus", bm, color, loc, rot, None, mat=mat)
        if not full:
            # round caps on the open ends
            for a in (start, start + arc):
                a = math.radians(a)
                cap = self.sphere(minor, (major * math.cos(a), major * math.sin(a), 0), color, scale=(1, 1, squash), mat=mat)
                cap.parent = ob
        return ob

    def tube(self, outer, inner, depth, loc=(0, 0, 0), color=WHITE, rot=(0, 0, 0), bevel=None, segments=64, mat=None):
        """A thick ring with a real hole (a washer), along its own z axis."""
        bm = self.bmesh.new()
        rings = {}
        for key, r, z in (("ot", outer, depth / 2), ("ob", outer, -depth / 2), ("it", inner, depth / 2), ("ib", inner, -depth / 2)):
            rings[key] = [bm.verts.new((r * math.cos(2 * math.pi * i / segments), r * math.sin(2 * math.pi * i / segments), z)) for i in range(segments)]
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((rings["ob"][i], rings["ob"][j], rings["ot"][j], rings["ot"][i]))  # outside
            bm.faces.new((rings["it"][i], rings["it"][j], rings["ib"][j], rings["ib"][i]))  # inside
            bm.faces.new((rings["ot"][i], rings["ot"][j], rings["it"][j], rings["it"][i]))  # top
            bm.faces.new((rings["ib"][i], rings["ib"][j], rings["ob"][j], rings["ob"][i]))  # bottom
        if bevel is None:
            bevel = min(outer - inner, depth) * 0.22
        return self._mesh("Tube", bm, color, loc, rot, bevel, mat=mat)

    def prism(self, points, depth, loc=(0, 0, 0), color=WHITE, rot=(0, 0, 0), bevel=0.05, mat=None):
        """A flat shape from (x, z) points, `depth` thick along y (for fins and roofs)."""
        bm = self.bmesh.new()
        front = [bm.verts.new((x, -depth / 2, z)) for x, z in points]
        back = [bm.verts.new((x, depth / 2, z)) for x, z in points]
        n = len(points)
        bm.faces.new(front)
        bm.faces.new(list(reversed(back)))
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((front[i], back[i], back[j], front[j]))
        self.bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self._mesh("Prism", bm, color, loc, rot, bevel, mat=mat)

    def outline(self, splines, depth, loc=(0, 0, 0), color=WHITE, rot=(0, 0, 0), round_=0.06, smooth=False, mat=None):
        """An extruded flat shape from (x, z) outlines (a second outline inside the first is a
        hole), `depth` thick along y, its edges rounded by `round_`. smooth: Bezier curves
        through the points instead of straight lines."""
        bpy = self.bpy
        cu = bpy.data.curves.new("Shape", "CURVE")
        cu.dimensions = "2D"
        cu.fill_mode = "BOTH"
        cu.extrude = max(0.0, depth / 2 - round_)
        cu.bevel_depth = round_
        cu.bevel_resolution = 6
        cu.resolution_u = 24
        cu.offset = -round_ / 2  # (keeps it about the size of the points)
        for pts in splines:
            if smooth:
                sp = cu.splines.new("BEZIER")
                sp.bezier_points.add(len(pts) - 1)
                for p, (x, y) in zip(sp.bezier_points, pts):
                    p.co = (x, y, 0)
                    p.handle_left_type = p.handle_right_type = "AUTO"
            else:
                sp = cu.splines.new("POLY")
                sp.points.add(len(pts) - 1)
                for p, (x, y) in zip(sp.points, pts):
                    p.co = (x, y, 0, 1)
            sp.use_cyclic_u = True
            sp.use_smooth = True
        # the curve is drawn in its own x/y plane: stand it up so it faces the camera (-y)
        rx, ry, rz = rot
        return self._object("Outline", cu, color, loc, (rx + 90, ry, rz), None, mat=mat)


# -----------------------------------------------------------------------------------------------
# The icons. Each builds into the kit facing the camera (-y), roughly inside x, z in [-1, 1], and
# returns how the whole icon is tilted (degrees around x, y, z) so its thickness shows.
# -----------------------------------------------------------------------------------------------
def star_points(outer, inner, n=5, turn=90):
    pts = []
    for i in range(n * 2):
        a = math.radians(turn + 180 * i / n)
        r = outer if i % 2 == 0 else inner
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


def heart_points(width):
    # a cartoon heart (Bezier, so every corner is soft): the dip at the top, round lobes, a blunt tip
    half = [(0.0, 0.5), (0.24, 0.84), (0.62, 0.86), (0.9, 0.52), (0.82, 0.02), (0.42, -0.48), (0.0, -0.86)]
    right = [(x * width / 2, y * width / 2) for x, y in half]
    left = [(-x, y) for x, y in reversed(right[1:-1])]
    return right + left


def basket(k):
    # a red shopping basket with a donut peeking out
    k.box((1.62, 1.0, 0.95), (0, 0, -0.42), RED, taper=(1.12, 1.08), bevel=0.14)
    k.box((1.92, 1.16, 0.22), (0, 0, 0.12), RED_LIGHT, bevel=0.1)
    for x in (-0.48, 0, 0.48):
        k.box((0.16, 0.12, 0.56), (x, -0.55, -0.45), RED_DARK, bevel=0.06)
    k.torus(0.66, 0.085, (0, 0.05, 0.16), RED, rot=(90, 0, 0), arc=180, start=0)
    # the donut (dough, pink icing on top, sprinkles), tipped up to face you
    donut = [k.torus(0.34, 0.17, (0, 0, 0), DOUGH), k.torus(0.34, 0.16, (0, 0, 0.07), PINK, squash=0.7)]
    for i, c in enumerate((YELLOW, BLUE_LIGHT, WHITE, GREEN, YELLOW, WHITE, BLUE_LIGHT)):
        a = 2 * math.pi * i / 7 + 0.3
        donut.append(k.box((0.11, 0.04, 0.04), (0.34 * math.cos(a), 0.34 * math.sin(a), 0.19), c, rot=(0, 0, math.degrees(a) + 60 * (i % 2)), bevel=0.018))
    k.group(donut, (0.3, -0.05, 0.38), (68, 0, -14))
    return (8, 0, 18)


def index_book(k):
    # a blue book with a gold star on the cover and a red bookmark
    k.box((1.42, 0.5, 1.74), (0.07, 0.02, -0.03), CREAM, bevel=0.06)
    k.box((1.56, 0.12, 1.86), (0, 0.27, 0), BLUE_DARK, bevel=0.05)
    k.box((1.56, 0.13, 1.86), (0, -0.27, 0), BLUE, bevel=0.06)
    k.box((0.28, 0.66, 1.86), (-0.72, 0, 0), BLUE, bevel=0.12)
    for z in (-0.6, 0.6):
        k.box((0.3, 0.68, 0.08), (-0.72, 0, z), GOLD, bevel=0.03)
    k.outline([star_points(0.46, 0.21)], 0.12, (0.1, -0.36, 0.12), GOLD, round_=0.04)
    k.box((0.2, 0.05, 0.48), (0.46, -0.06, -1.06), RED, bevel=0.03)
    return (6, 0, 24)


def paw_pink(k):
    k.sphere(0.6, (0, 0, -0.38), PINK, scale=(1.22, 0.62, 0.92))
    for x, z, tilt in ((-0.8, 0.24, 28), (-0.3, 0.68, 10), (0.3, 0.68, -10), (0.8, 0.24, -28)):
        k.sphere(0.3, (x, 0, z), PINK, scale=(0.95, 0.72, 1.22), rot=(0, tilt, 0))
    return (14, 0, 12)


def gift(k):
    # a purple present with a gold ribbon and bow
    k.box((1.5, 1.3, 1.1), (0, 0, -0.42), PURPLE, bevel=0.1)
    k.box((1.68, 1.46, 0.34), (0, 0, 0.26), (200, 110, 255), bevel=0.1)
    k.box((0.34, 1.5, 1.52), (0, 0, -0.18), YELLOW, bevel=0.05)
    k.box((1.72, 0.34, 1.52), (0, 0, -0.18), YELLOW, bevel=0.05)
    k.torus(0.3, 0.1, (-0.3, 0, 0.66), YELLOW, rot=(90, 0, 30), squash=1)
    k.torus(0.3, 0.1, (0.3, 0, 0.66), YELLOW, rot=(90, 0, -30), squash=1)
    k.sphere(0.16, (0, -0.02, 0.5), GOLD)
    return (10, 0, 22)


def house_red(k):
    k.box((1.4, 1.2, 1.06), (0, 0, -0.45), CREAM, bevel=0.08)
    k.prism([(-1.0, 0.02), (1.0, 0.02), (0, 0.9)], 1.5, (0, 0, 0), RED, bevel=0.08)
    k.box((0.24, 0.24, 0.5), (0.48, 0.25, 0.55), RED_DARK, bevel=0.05)
    k.box((0.4, 0.1, 0.64), (-0.28, -0.6, -0.66), WOOD_DARK, bevel=0.05)
    k.sphere(0.05, (-0.17, -0.67, -0.66), GOLD)
    k.box((0.42, 0.08, 0.38), (0.34, -0.6, -0.36), BLUE_LIGHT, bevel=0.04)
    k.box((0.05, 0.1, 0.38), (0.34, -0.62, -0.36), WHITE, bevel=0.015)
    k.box((0.42, 0.1, 0.05), (0.34, -0.62, -0.36), WHITE, bevel=0.015)
    return (8, 0, 22)


def globe_blue(k):
    k.sphere(0.84, (0, 0, 0), BLUE)
    # raised green land: blobs that sit on the surface
    from mathutils import Vector

    land = (
        (-0.34, 0.36, 0.3, 0.22), (-0.18, 0.2, 0.26, 0.24), (-0.42, 0.12, 0.16, 0.18), # a big one, top left
        (0.3, -0.02, 0.2, 0.3), (0.38, -0.3, 0.16, 0.22), (0.22, 0.24, 0.16, 0.14), # one down the right
        (-0.16, -0.5, 0.26, 0.12), (0.52, 0.5, 0.12, 0.09), # little ones
    )
    for (dx, dz, sx, sz) in land:
        d = Vector((dx, -math.sqrt(max(0.05, 1 - dx * dx - dz * dz)), dz)).normalized()
        e = d.to_track_quat("Y", "Z").to_euler()
        k.sphere(1, tuple(d * 0.81), GREEN, scale=(sx, 0.05, sz), rot=(math.degrees(e.x), math.degrees(e.y), math.degrees(e.z)))
    # an orbit ring around it, like a planet's (Teleport)
    k.torus(1.12, 0.065, (0, 0, 0), YELLOW, rot=(-14, 20, 0))
    return (0, 0, 0)


def rocket(k):
    k.cylinder(0.38, 1.1, (0, 0, -0.05), WHITE, bevel=0.06)
    k.sphere(0.38, (0, 0, 0.5), RED, scale=(1, 1, 1.7))
    # a round window with a metal rim, a red band round the bottom, two fins
    k.cylinder(0.17, 0.08, (0, -0.36, 0.14), BLUE_LIGHT, rot=(90, 0, 0), bevel=0.03)
    k.torus(0.19, 0.055, (0, -0.39, 0.14), STEEL, rot=(90, 0, 0))
    k.torus(0.385, 0.05, (0, 0, -0.42), RED)
    for side in (-1, 1):
        k.prism([(0.3 * side, -0.62), (0.78 * side, -0.82), (0.72 * side, -0.4), (0.3 * side, 0.05)], 0.14, (0, 0, 0), RED, bevel=0.05)
    k.cylinder(0.24, 0.5, (0, 0, -0.85), ORANGE, top=0.0, rot=(180, 0, 0), mat=k.mat(ORANGE, emit=2.5))
    k.cylinder(0.13, 0.3, (0, -0.02, -0.75), YELLOW, top=0.0, rot=(180, 0, 0), mat=k.mat(YELLOW, emit=3.0))
    return (0, -34, 0)


def palette_wood(k):
    outer = [(-0.95, 0.15), (-0.7, 0.72), (0.0, 0.88), (0.72, 0.6), (0.95, 0.0), (0.7, -0.62), (0.05, -0.8), (-0.35, -0.55), (-0.2, -0.22), (-0.62, -0.32)]
    hole = [(-0.55 + 0.17 * math.cos(a), 0.22 + 0.15 * math.sin(a)) for a in (math.radians(i * 45) for i in range(8))]
    k.outline([outer, hole], 0.16, (0, 0, 0), WOOD, round_=0.06, smooth=True)
    for x, z, c in ((-0.15, 0.48, RED), (0.32, 0.5, YELLOW), (0.6, 0.08, BLUE), (0.4, -0.4, GREEN), (-0.02, 0.06, WHITE)):
        k.sphere(0.2, (x, -0.1, z), c, scale=(1, 0.42, 0.85))
    # a brush across the bottom right: handle, metal band, then the bristles, in a line
    turn = -54  # (its tip points up and to the left)
    dx, dz = math.sin(math.radians(turn)), math.cos(math.radians(turn))
    hx, hz = 0.5, -0.66
    for (along, part) in (
        (0.0, lambda p: k.cylinder(0.065, 0.9, p, WOOD_DARK, rot=(0, turn, 0), bevel=0.03)),
        (0.54, lambda p: k.cylinder(0.085, 0.18, p, STEEL, rot=(0, turn, 0), bevel=0.02)),
        (0.74, lambda p: k.cylinder(0.09, 0.24, p, BLUE, top=0.015, rot=(0, turn, 0), bevel=0.02)),
    ):
        part((hx + dx * along, -0.22, hz + dz * along))
    return (0, 0, 12)


def heart(k):
    k.outline([heart_points(1.9)], 0.44, (0, 0, -0.05), HOT_PINK, round_=0.16, smooth=True)
    return (0, 0, 18)


def news_yellow(k):
    paper, paper_back = (255, 246, 196), (255, 228, 140)
    k.box((1.32, 0.08, 1.72), (0.16, 0.14, 0.06), paper_back, rot=(0, 9, 0), bevel=0.035)
    k.box((1.32, 0.1, 1.72), (-0.04, 0, -0.02), paper, rot=(0, -5, 0), bevel=0.04)
    k.box((1.0, 0.04, 0.2), (-0.06, -0.06, 0.6), INK, rot=(0, -5, 0), bevel=0.02)
    k.box((0.44, 0.04, 0.4), (-0.34, -0.06, 0.18), BLUE, rot=(0, -5, 0), bevel=0.02)
    for i in range(3):
        k.box((0.46, 0.04, 0.07), (0.22, -0.06, 0.32 - i * 0.14), (150, 150, 168), rot=(0, -5, 0), bevel=0.02)
    for i in range(3):
        k.box((1.0, 0.04, 0.07), (-0.08 + i * 0.01, -0.06, -0.18 - i * 0.16), (150, 150, 168), rot=(0, -5, 0), bevel=0.02)
    # a red "new!" badge in the corner
    k.cylinder(0.3, 0.12, (0.58, -0.14, 0.78), RED, rot=(90, 0, 0), bevel=0.04)
    k.box((0.08, 0.06, 0.26), (0.58, -0.22, 0.83), WHITE, bevel=0.03)
    k.sphere(0.05, (0.58, -0.22, 0.62), WHITE)
    return (6, 0, 14)


def gear_steel(k):
    steel = k.mat(STEEL, rough=0.22, metal=0.7, coat=0.6)
    k.tube(0.7, 0.27, 0.36, (0, 0, 0), rot=(90, 0, 0), mat=steel)
    for i in range(8):
        a = 2 * math.pi * i / 8
        k.box((0.36, 0.36, 0.32), (0.76 * math.cos(a), 0, 0.76 * math.sin(a)), rot=(0, -math.degrees(a), 0), bevel=0.06, mat=steel)
    k.torus(0.47, 0.04, (0, -0.19, 0), STEEL_DARK, rot=(90, 0, 0), mat=k.mat(STEEL_DARK, rough=0.3, metal=0.6, coat=0.4))
    return (14, 0, 20)


def tools_steel(k):
    steel = k.mat(STEEL, rough=0.22, metal=0.7, coat=0.6)
    # the wrench (a handle and a C-shaped head), corner to corner
    wrench = k.box((0.24, 0.14, 1.5), (0, 0, -0.1), STEEL, bevel=0.06, mat=steel)
    head = k.tube(0.32, 0.15, 0.14, (0, 0, 0.72), rot=(90, 0, 0), mat=steel)
    cut = k.box((0.26, 0.6, 0.5), (0, 0, 0.98), STEEL)
    cut.hide_render = True
    mod = head.modifiers.new("Notch", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cut
    head.modifiers.move(len(head.modifiers) - 1, 0)
    for part in (wrench, head, cut):
        part.parent = None
    pivot = k.bpy.data.objects.new("Wrench", None)
    pivot.parent = k.root
    pivot.rotation_euler = (0, math.radians(-45), 0)
    k.collection.objects.link(pivot)
    for part in (wrench, head, cut):
        part.parent = pivot
    # the hammer, the other way
    hammer = k.bpy.data.objects.new("Hammer", None)
    hammer.parent = k.root
    hammer.rotation_euler = (0, math.radians(45), 0)
    hammer.location = (0, -0.2, 0)
    k.collection.objects.link(hammer)
    handle = k.cylinder(0.1, 1.5, (0, 0, -0.15), WOOD, bevel=0.04)
    hammer_head = k.box((0.82, 0.32, 0.34), (0, 0, 0.66), STEEL_DARK, bevel=0.08, mat=k.mat(STEEL_DARK, rough=0.25, metal=0.6, coat=0.6))
    grip = k.cylinder(0.12, 0.42, (0, 0, -0.68), RED, bevel=0.05)
    for part in (handle, hammer_head, grip):
        part.parent = hammer
    return (8, 0, 14)


def building_blue(k):
    k.box((0.92, 0.84, 1.8), (-0.24, 0, 0), BLUE, bevel=0.08)
    k.box((0.66, 0.74, 1.14), (0.5, 0.06, -0.33), BLUE_LIGHT, bevel=0.08)
    window = k.mat((255, 232, 130), emit=0.6)
    for row in range(4):
        for col in range(2):
            k.box((0.2, 0.06, 0.22), (-0.43 + col * 0.38, -0.43, 0.62 - row * 0.36), mat=window, bevel=0.03)
    for row in range(2):
        k.box((0.2, 0.06, 0.2), (0.5, -0.33, 0.0 - row * 0.32), mat=window, bevel=0.03)
    k.box((0.3, 0.08, 0.36), (-0.24, -0.43, -0.74), BLUE_DARK, bevel=0.04)
    k.cylinder(0.035, 0.36, (-0.24, 0, 1.06), STEEL, bevel=0.01)
    k.sphere(0.08, (-0.24, 0, 1.26), RED, mat=k.mat(RED, emit=1.2))
    return (6, 0, 22)


def bolt(k):
    pts = [(0.3, 1.0), (-0.58, -0.08), (-0.04, -0.08), (-0.34, -1.0), (0.6, 0.14), (0.06, 0.14), (0.52, 1.0)]
    k.outline([pts], 0.36, (0, 0, 0), YELLOW, round_=0.09)
    return (0, 0, 20)


def cash(k):
    for (x, z, turn, c) in ((0.08, 0.12, 12, GREEN_DARK), (0.0, 0.02, 4, (80, 186, 80)), (-0.08, -0.1, -6, GREEN)):
        k.box((1.66, 0.06, 0.92), (x, -0.04 * turn / 6, z), c, rot=(0, turn, 0), bevel=0.025)
    front = (-0.08, -0.12, -0.1)
    k.box((1.42, 0.03, 0.7), front, GREEN_DARK, rot=(0, -6, 0), bevel=0.012)
    k.box((1.3, 0.035, 0.6), (front[0], front[1] - 0.012, front[2]), GREEN, rot=(0, -6, 0), bevel=0.012)
    k.cylinder(0.2, 0.05, (front[0], front[1] - 0.03, front[2]), GREEN_LIGHT, rot=(90, 6, 0), bevel=0.015)
    # a little stack of gold coins in front
    gold = k.mat(GOLD, rough=0.2, metal=0.8, coat=0.7)
    for i, (x, y) in enumerate(((0.5, -0.3), (0.53, -0.32), (0.49, -0.33))):
        k.cylinder(0.3, 0.1, (x, y, -0.62 + i * 0.11), mat=gold, bevel=0.035)
    k.torus(0.2, 0.028, (0.49, -0.33, -0.34), mat=gold)
    return (8, 0, 10)


ICONS = {
    "basket": basket,
    "indexBook": index_book,
    "pawPink": paw_pink,
    "gift": gift,
    "houseRed": house_red,
    "globeBlue": globe_blue,
    "rocket": rocket,
    "paletteWood": palette_wood,
    "heart": heart,
    "newsYellow": news_yellow,
    "gearSteel": gear_steel,
    "toolsSteel": tools_steel,
    "buildingBlue": building_blue,
    "bolt": bolt,
    "cash": cash,
}


# -----------------------------------------------------------------------------------------------
# Outline + shadow (numpy, on the rendered picture)
# -----------------------------------------------------------------------------------------------
def shift(a, dy, dx):
    out = np.zeros_like(a)
    h, w = a.shape
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = a[ys, xs]
    return out


def grow(alpha, radius):
    """The silhouette grown by `radius` pixels, round at the corners (a max over a disc)."""
    out = alpha.copy()
    offsets = [(dy, dx) for dy in range(-radius, radius + 1) for dx in range(-radius, radius + 1) if dy * dy + dx * dx <= radius * radius]
    for dy, dx in offsets:
        np.maximum(out, shift(alpha, dy, dx), out=out)
    return out


def blur(a, radius):
    """A box blur, twice (close to a soft Gaussian)."""
    for _ in range(2):
        for axis in (0, 1):
            c = np.cumsum(np.pad(a, [(radius + 1, radius) if i == axis else (0, 0) for i in range(2)]), axis=axis)
            if axis == 0:
                a = (c[2 * radius + 1 :, :] - c[: -2 * radius - 1, :]) / (2 * radius + 1)
            else:
                a = (c[:, 2 * radius + 1 :] - c[:, : -2 * radius - 1]) / (2 * radius + 1)
    return a


def finish(rgba):
    """rgba: float array (rows top to bottom), straight alpha. Returns it with the outline and the
    shadow under it."""
    alpha = rgba[..., 3]
    ring = grow(alpha, OUTLINE)
    sx, sy, soft, strength = SHADOW
    shadow = blur(shift(ring, sy, sx), soft) * strength
    ink = np.array([c / 255 for c in OUTLINE_COLOR])
    # back to front: shadow (black), outline, the icon itself (all premultiplied)
    color = np.zeros(rgba.shape[:2] + (3,))
    a = shadow.copy()
    color = ink * ring[..., None] + color * (1 - ring[..., None])
    a = ring + a * (1 - ring)
    color = rgba[..., :3] * alpha[..., None] + color * (1 - alpha[..., None])
    a = alpha + a * (1 - alpha)
    out = np.zeros_like(rgba)
    safe = np.maximum(a, 1e-6)[..., None]
    out[..., :3] = np.clip(color / safe, 0, 1)
    out[..., 3] = np.clip(a, 0, 1)
    return out


# -----------------------------------------------------------------------------------------------
# Blender: scene, fitting the camera, rendering
# -----------------------------------------------------------------------------------------------
def setup_scene(bpy):
    from mathutils import Vector

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.cycles.device = "CPU"
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.75, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.45
    scene.world = world

    def light(name, energy, size, loc, color=(1, 1, 1)):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.size = size
        data.color = color
        ob = bpy.data.objects.new(name, data)
        ob.location = loc
        ob.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(ob)

    light("Key", 900, 5, (-4.5, -6, 6))  # top left, in front: the big shine
    light("Fill", 260, 6, (6, -5, 0.5), (0.9, 0.95, 1))
    light("Rim", 700, 3, (2, 6, 5), (1, 0.97, 0.9))  # behind: a bright edge on top
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = (1.6, -10, 2.6)
    cam.rotation_euler = (Vector((0, 0, 0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam


def fit(bpy, scene, cam, collection):
    """Point the camera so the icon fills FILL of the picture, centred."""
    deps = bpy.context.evaluated_depsgraph_get()
    inv = cam.matrix_world.inverted()
    xs, ys = [], []
    for ob in collection.all_objects:
        if ob.hide_render or ob.type not in ("MESH", "CURVE"):
            continue
        ev = ob.evaluated_get(deps)
        mesh = ev.to_mesh()
        for v in mesh.vertices:
            p = inv @ (ev.matrix_world @ v.co)
            xs.append(p.x)
            ys.append(p.y)
        ev.to_mesh_clear()
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    scale = max(w, h) / FILL
    cam.data.ortho_scale = scale
    cam.data.shift_x = (max(xs) + min(xs)) / 2 / scale
    # (a little above centre: the shadow hangs below)
    cam.data.shift_y = (max(ys) + min(ys)) / 2 / scale - 0.012


def render_icon(bpy, bmesh, scene, cam, name, out_dir):
    k = Kit(bpy, bmesh, name)
    tilt = ICONS[name](k)
    k.root.rotation_euler = [math.radians(a) for a in tilt]
    bpy.context.view_layer.update()
    for coll in scene.collection.children:
        coll.hide_render = coll is not k.collection
    fit(bpy, scene, cam, k.collection)
    raw = os.path.join(out_dir, "_raw_" + name + ".png")
    scene.render.filepath = raw
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(raw)
    px = np.array(img.pixels[:], dtype=np.float64).reshape(SIZE, SIZE, 4)[::-1]  # rows top to bottom
    bpy.data.images.remove(img)
    os.remove(raw)
    done = finish(px)
    save_png(bpy, done, os.path.join(out_dir, name + ".png"))
    print("icon", name)
    return done


def save_png(bpy, rgba, path):
    h, w = rgba.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.pixels[:] = rgba[::-1].astype(np.float32).ravel()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def contact_sheet(bpy, icons, path, cols=5):
    """Every icon at half size on a game-green background, in rows."""
    cell = SIZE // 2
    rows = (len(icons) + cols - 1) // cols
    pad = 24
    h, w = rows * cell + pad * 2, cols * cell + pad * 2
    t = np.linspace(0, 1, h)[:, None]
    top, bottom = np.array([0.42, 0.62, 0.36]), np.array([0.16, 0.3, 0.14])
    sheet = np.ones((h, w, 4))
    sheet[..., :3] = (top * (1 - t[..., None]) + bottom * t[..., None]).repeat(w, axis=1)
    for i, (name, rgba) in enumerate(icons):
        small = rgba.reshape(cell, 2, cell, 2, 4).mean(axis=(1, 3))
        r, c = divmod(i, cols)
        y, x = pad + r * cell, pad + c * cell
        a = small[..., 3:4]
        sheet[y : y + cell, x : x + cell, :3] = small[..., :3] * a + sheet[y : y + cell, x : x + cell, :3] * (1 - a)
    save_png(bpy, sheet, path)
    print("sheet", path)


def main():
    import bpy
    import bmesh

    out_dir = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(HERE, "png")
    sheet = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "sheet.png")
    only = sys.argv[3].split(",") if len(sys.argv) > 3 else list(ICONS)
    os.makedirs(out_dir, exist_ok=True)
    done = []
    for name in only:
        scene, cam = setup_scene(bpy)
        done.append((name, render_icon(bpy, bmesh, scene, cam, name, out_dir)))
    if sheet != "-":
        contact_sheet(bpy, done, os.path.abspath(sheet))


if __name__ == "__main__":
    main()
