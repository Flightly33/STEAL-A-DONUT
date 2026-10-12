"""
Anime VFX textures for Steal a Donut, made in Blender: the particle textures behind the donuts'
and Domers' anime effects (power-up auras, sword slashes, impact frames, speed lines, sparkles...).

    PYTHONPATH=<folder with bpy> python3 anime_vfx.py [out_dir] [sheet.png] [only,these]

Cel-shaded like an anime: hard edges, a white core inside a grey band, a faint glow round it. They
are white and grey on purpose: Roblox multiplies a particle's texture by its colour, so one texture
works for every colour (a pink donut's aura is pink, a fire donut's orange).

Flipbooks are 4 x 4 grids of 16 frames (Roblox ParticleEmitter FlipbookLayout Grid4x4), the
others single images. Upload them (Studio: View > Asset Manager > Bulk Import) and paste each
image id into Config.AnimeFX.Textures; until then the effects use Roblox's own particle textures.

Each shape is drawn as flat 2D curves (filled) with an emission material, seen from above by an
orthographic camera, rendered in Cycles; the glow is added afterwards (numpy).
"""

import math
import os
import random
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
TILE = 256  # pixels per flipbook frame (4 x 4 -> 1024 x 1024)
GREY = 0.62  # the outer band's brightness (the core is white)


# -----------------------------------------------------------------------------------------------
# Shapes: lists of layers, each layer = (brightness, alpha, [polygons]); polygons are [(x, y)] in
# a -1..1 square. Later layers are drawn on top.
# -----------------------------------------------------------------------------------------------
def flame_outline(width, top, phase, wobble, steps=48, lean=0.0):
    """A flame tongue: round at the bottom, licking up to a point, its sides waving."""
    left, right = [], []
    for i in range(steps + 1):
        s = i / steps
        y = -0.82 + (top + 0.82) * s
        w = width * math.sin(math.pi * min(1, s ** 0.75)) ** 0.85 * (1 - s) ** 0.45
        if s < 0.12:
            w = max(w, width * 0.55 * math.sqrt(s / 0.12))
        cx = wobble * math.sin(3.2 * s * math.pi - phase) * s + lean * s * s
        edge = 0.05 * wobble / 0.12 * math.sin(9 * s - 2 * phase) * s
        left.append((cx - w - edge, y))
        right.append((cx + w + edge, y))
    return left + list(reversed(right))


def aura(t):
    p = t * 2 * math.pi
    return [
        (GREY, 0.85, [flame_outline(0.46, 0.96 + 0.04 * math.sin(p * 2), p, 0.12)]),
        (1.0, 1.0, [flame_outline(0.22, 0.55 + 0.05 * math.sin(p * 2 + 1), p + 0.6, 0.08)]),
    ]


def toon_fire(t):
    p = t * 2 * math.pi
    outer = []
    for k, (dx, h, w) in enumerate(((-0.32, 0.45, 0.3), (0.0, 0.92, 0.42), (0.32, 0.55, 0.3))):
        poly = flame_outline(w, h + 0.06 * math.sin(p * 2 + k), p + k * 1.7, 0.14, lean=0.1 * math.sin(p + k))
        outer.append([(x + dx, y) for x, y in poly])
    core = [[(x * 0.55, y * 0.7 - 0.22) for x, y in flame_outline(0.42, 0.5, p + 0.5, 0.1)]]
    return [(GREY, 0.9, outer), (1.0, 1.0, core)]


def circle(cx, cy, r, n=40):
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def arc(r0, r1, a0, a1, steps=48):
    n = max(4, int(steps * (a1 - a0) / (2 * math.pi)) + 2)
    outer = [(r1 * math.cos(a0 + (a1 - a0) * i / n), r1 * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
    inner = [(r0 * math.cos(a1 - (a1 - a0) * i / n), r0 * math.sin(a1 - (a1 - a0) * i / n)) for i in range(n + 1)]
    return outer + inner


def shock_ring(t):
    """A ring bursting outwards: whole at first, then thinning and breaking up into pieces."""
    rng = random.Random(4)
    e = 1 - (1 - t) ** 2.2
    r = 0.22 + 0.72 * e
    th = 0.2 * (1 - t) + 0.025
    pieces = 24
    gone = [rng.random() < t * 0.75 for _ in range(pieces)]
    # runs of pieces still there, each drawn as one smooth arc
    runs = []
    if not any(gone):
        runs = [(0.0, 2 * math.pi)]
    else:
        start = gone.index(True)
        k = 0
        while k < pieces:
            i = (start + k) % pieces
            if gone[i]:
                k += 1
                continue
            first = i
            length = 0
            while k < pieces and not gone[(start + k) % pieces]:
                length += 1
                k += 1
            a0 = 2 * math.pi * first / pieces
            runs.append((a0, a0 + 2 * math.pi * length / pieces - 0.03))
    outer = [arc(r - th, r + th, a0, a1) for a0, a1 in runs]
    core = [arc(r - th * 0.35, r + th * 0.35, a0, a1) for a0, a1 in runs]
    if not any(gone):
        # a full ring: two halves (a polygon can't have a hole in it)
        outer = [arc(r - th, r + th, 0, math.pi + 0.01), arc(r - th, r + th, math.pi, 2 * math.pi + 0.01)]
        core = [arc(r - th * 0.35, r + th * 0.35, 0, math.pi + 0.01), arc(r - th * 0.35, r + th * 0.35, math.pi, 2 * math.pi + 0.01)]
    return [(GREY, 0.85 * (1 - t * 0.5), outer), (1.0, 1.0, core)]


def star(n, inner, lengths, rot=0.0):
    pts = []
    for i in range(n):
        a = rot + 2 * math.pi * i / n
        pts.append((math.cos(a) * lengths[i], math.sin(a) * lengths[i]))
        b = a + math.pi / n
        pts.append((math.cos(b) * inner, math.sin(b) * inner))
    return pts


def impact(t):
    """An anime hit spark: a spiky burst that flashes out, then its spikes thin and break off."""
    rng = random.Random(9)
    lens = [rng.uniform(0.6, 1.0) for _ in range(12)]
    grow = min(1, t * 5)
    fade = max(0, (t - 0.25) / 0.75)
    scale = 0.35 + 0.6 * grow + 0.05 * t
    inner = (0.32 - 0.25 * fade) * scale
    body = star(12, inner, [l * scale for l in lens], 0.1)
    core = star(12, inner * 0.55, [l * scale * (0.7 - 0.5 * fade) for l in lens], 0.1)
    layers = [(GREY, 0.9 * (1 - fade * 0.6), [body]), (1.0, 1.0 - fade * 0.4, [core])]
    if t < 0.2:
        layers.append((1.0, 1.0, [circle(0, 0, 0.3 * scale)]))  # the white flash at the start
    return layers


def toon_smoke(t):
    """A cel-shaded smoke puff: a cluster of round blobs that swells, drifts up and thins out."""
    rng = random.Random(2)
    blobs = [(rng.uniform(-0.35, 0.35), rng.uniform(-0.3, 0.25), rng.uniform(0.22, 0.38)) for _ in range(6)]
    grow = 0.55 + 0.5 * (1 - (1 - t) ** 2)
    shrink = 1 - max(0, (t - 0.45) / 0.55) ** 1.4
    up = 0.25 * t
    body, shine = [], []
    for (x, y, r) in blobs:
        rr = r * grow * shrink
        if rr > 0.02:
            body.append(circle(x * grow, y * grow + up, rr))
            shine.append(circle(x * grow - rr * 0.25, y * grow + up + rr * 0.25, rr * 0.5))
    return [(GREY, 0.8, body), (1.0, 0.95, shine)]


def slash(_t):
    """A crescent sword slash with sharp tips, a white edge and two thin trailing streaks."""
    def crescent(R, d, R2, a=1.95):
        outer = [(R * math.cos(-a + 2 * a * i / 40), R * math.sin(-a + 2 * a * i / 40)) for i in range(41)]
        # inner edge: a circle shifted left, between the two tips
        tip1, tip2 = outer[0], outer[-1]
        inner = []
        for i in range(41):
            s = 1 - i / 40
            y = tip1[1] + (tip2[1] - tip1[1]) * s
            x = -d + math.sqrt(max(0, R2 * R2 - y * y))
            inner.append((min(x, R * math.cos(math.asin(max(-1, min(1, y / R)))) - 0.005), y))
        return outer + inner
    body = crescent(0.9, 0.34, 1.0)
    core = [(x + 0.03, y * 0.97) for x, y in crescent(0.9, 0.12, 0.92)]
    streaks = []
    for (r, a0, a1, w) in ((0.62, -1.3, 1.1, 0.018), (0.52, -0.9, 0.7, 0.012)):
        streaks.append([(r * math.cos(a0 + (a1 - a0) * i / 30), r * math.sin(a0 + (a1 - a0) * i / 30)) for i in range(31)] + [((r - w) * math.cos(a1 - (a1 - a0) * i / 30), (r - w) * math.sin(a1 - (a1 - a0) * i / 30)) for i in range(31)])
    return [(GREY, 0.85, [body]), (1.0, 1.0, [core]), (1.0, 0.7, streaks)]


def speed_lines(_t):
    """Anime focus lines: thin spikes pointing in from the edge, leaving the middle clear."""
    rng = random.Random(6)
    lines = []
    for i in range(70):
        a = 2 * math.pi * i / 70 + rng.uniform(-0.03, 0.03)
        inner = rng.uniform(0.42, 0.7)
        w = rng.uniform(0.003, 0.011)
        ca, sa = math.cos(a), math.sin(a)
        px, py = -sa, ca
        lines.append([(ca * inner, sa * inner), (ca * 1.0 + px * w * 3, sa * 1.0 + py * w * 3), (ca * 1.0 - px * w * 3, sa * 1.0 - py * w * 3)])
    return [(1.0, 1.0, lines)]


def kira(_t):
    """A four-pointed anime sparkle with a long thin cross and a small star beside it."""
    big = star(4, 0.12, [0.95, 0.6, 0.95, 0.6], math.pi / 2)
    core = star(4, 0.06, [0.55, 0.35, 0.55, 0.35], math.pi / 2)
    small = [(x * 0.3 + 0.55, y * 0.3 + 0.55) for x, y in star(4, 0.15, [1, 1, 1, 1], math.pi / 4)]
    cross = [[(-1, -0.012), (1, -0.012), (1, 0.012), (-1, 0.012)], [(-0.012, -1), (0.012, -1), (0.012, 1), (-0.012, 1)]]
    return [(GREY, 0.6, cross), (GREY, 0.9, [big, small]), (1.0, 1.0, [core])]


def bolt_path(rng):
    pts = [(rng.uniform(-0.2, 0.2), 0.95)]
    y = 0.95
    while y > -0.9:
        y -= rng.uniform(0.12, 0.25)
        pts.append((pts[-1][0] * 0.4 + rng.uniform(-0.35, 0.35), max(y, -0.95)))
    return pts


def thick(path, w):
    left, right = [], []
    for i, (x, y) in enumerate(path):
        a = path[max(0, i - 1)]
        b = path[min(len(path) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy) or 1
        nx, ny = -dy / n, dx / n
        ww = w * (1 - 0.6 * i / len(path))
        left.append((x + nx * ww, y + ny * ww))
        right.append((x - nx * ww, y - ny * ww))
    return left + list(reversed(right))


def lightning(t):
    """A jagged anime bolt with a branch (four different ones: a 2 x 2 grid, shown at random)."""
    rng = random.Random(int(t * 100) + 3)
    main = bolt_path(rng)
    k = rng.randrange(2, len(main) - 2)
    branch = [main[k]]
    for _ in range(3):
        branch.append((branch[-1][0] + rng.uniform(0.15, 0.3) * rng.choice((-1, 1)), branch[-1][1] - rng.uniform(0.15, 0.25)))
    return [(GREY, 0.9, [thick(main, 0.075), thick(branch, 0.05)]), (1.0, 1.0, [thick(main, 0.028), thick(branch, 0.018)])]


def petal(_t):
    """A cherry blossom petal (a notch at its tip), with a lighter middle."""
    pts = []
    for i in range(60):
        a = 2 * math.pi * i / 60
        r = 0.85 * (0.55 + 0.45 * math.cos(a / 2) ** 2)
        x, y = 0.55 * r * math.sin(a), r * math.cos(a) * 0.95 - 0.1
        if y > 0.55 and abs(x) < 0.12:
            y = 0.55 + (abs(x) / 0.12) * 0.15
        pts.append((x, y))
    core = [(x * 0.45, y * 0.55 - 0.15) for x, y in pts]
    return [(GREY + 0.15, 0.95, [pts]), (1.0, 1.0, [core])]


TEXTURES = {
    # name: (draw, frames (16 = a 4 x 4 flipbook, 4 = a 2 x 2 set, 1 = one image), pixels per frame)
    "Aura": (aura, 16, TILE),
    "ToonFire": (toon_fire, 16, TILE),
    "ShockRing": (shock_ring, 16, TILE),
    "Impact": (impact, 16, TILE),
    "ToonSmoke": (toon_smoke, 16, TILE),
    "Lightning": (lightning, 4, 256),
    "Slash": (slash, 1, 512),
    "SpeedLines": (speed_lines, 1, 1024),
    "Kira": (kira, 1, 256),
    "Petal": (petal, 1, 256),
}


# -----------------------------------------------------------------------------------------------
# Blender
# -----------------------------------------------------------------------------------------------
def setup(bpy, size):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.cycles.device = "CPU"
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.0
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = (0, 0, 10)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene


def material(bpy, brightness, alpha, cache):
    key = (round(brightness, 3), round(alpha, 3))
    if key in cache:
        return cache[key]
    m = bpy.data.materials.new("M%d" % len(cache))
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    emit = nodes.new("ShaderNodeEmission")
    v = brightness ** 2.2  # (linear: shows as `brightness` on screen)
    emit.inputs["Color"].default_value = (v, v, v, 1)
    emit.inputs["Strength"].default_value = 1.0
    clear = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    mix.inputs["Fac"].default_value = alpha
    links.new(clear.outputs[0], mix.inputs[1])
    links.new(emit.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], out.inputs["Surface"])
    m.blend_method = "BLEND" if hasattr(m, "blend_method") else None
    cache[key] = m
    return m


def draw(bpy, scene, layers):
    """Put the layers in the scene as filled 2D curves (one object per polygon, so overlapping
    polygons add up instead of cutting holes), later layers higher up (nearer the camera)."""
    for ob in list(scene.collection.objects):
        if ob.type == "CURVE":
            bpy.data.objects.remove(ob, do_unlink=True)
    cache = {}
    for depth, (brightness, alpha, polygons) in enumerate(layers):
        mat = material(bpy, brightness, alpha, cache)
        for polygon in polygons:
            if len(polygon) < 3:
                continue
            cu = bpy.data.curves.new("Shape", "CURVE")
            cu.dimensions = "2D"
            cu.fill_mode = "BOTH"
            sp = cu.splines.new("POLY")
            sp.points.add(len(polygon) - 1)
            for p, (x, y) in zip(sp.points, polygon):
                p.co = (x, y, 0, 1)
            sp.use_cyclic_u = True
            ob = bpy.data.objects.new("Shape", cu)
            ob.location = (0, 0, depth * 0.01)
            cu.materials.append(mat)
            scene.collection.objects.link(ob)


def render_frame(bpy, scene, layers, path):
    draw(bpy, scene, layers)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float64).reshape(h, w, 4)[::-1]
    bpy.data.images.remove(img)
    os.remove(path)
    return px


def blur(a, radius):
    for _ in range(2):
        for axis in (0, 1):
            c = np.cumsum(np.pad(a, [(radius + 1, radius) if i == axis else (0, 0) for i in range(2)]), axis=axis)
            a = (c[2 * radius + 1:, :] - c[:-2 * radius - 1, :]) / (2 * radius + 1) if axis == 0 else (c[:, 2 * radius + 1:] - c[:, :-2 * radius - 1]) / (2 * radius + 1)
    return a


def glow(px):
    """A faint glow round the shape, under it (white, so it takes the particle's colour too)."""
    a = px[..., 3]
    halo = np.clip(blur(a, max(2, px.shape[0] // 40)) * 0.45, 0, 1)
    out_a = a + halo * (1 - a)
    rgb = (px[..., :3] * a[..., None] + np.ones(3) * 0.85 * (halo * (1 - a))[..., None]) / np.maximum(out_a, 1e-6)[..., None]
    out = np.zeros_like(px)
    out[..., :3] = np.clip(rgb, 0, 1)
    out[..., 3] = np.clip(out_a, 0, 1)
    return out


def save(bpy, rgba, path):
    h, w = rgba.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.pixels[:] = rgba[::-1].astype(np.float32).ravel()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def make(bpy, name, out_dir):
    fn, frames, size = TEXTURES[name]
    scene = setup(bpy, size)
    tmp = os.path.join(out_dir, "_frame.png")
    if frames == 1:
        sheet = glow(render_frame(bpy, scene, fn(0.0), tmp))
    else:
        side = int(math.sqrt(frames))
        sheet = np.zeros((size * side, size * side, 4))
        for i in range(frames):
            t = i / frames if name in ("Aura", "ToonFire") else i / (frames - 1)
            tile = glow(render_frame(bpy, scene, fn(t), tmp))
            r, c = divmod(i, side)
            sheet[r * size:(r + 1) * size, c * size:(c + 1) * size] = tile
    save(bpy, sheet, os.path.join(out_dir, name + ".png"))
    print("texture", name, sheet.shape[1], "x", sheet.shape[0])
    return sheet


def contact_sheet(bpy, made, path):
    """Every texture, tinted with a sample colour, on a dark background (512 px each)."""
    tints = [(1, 0.55, 0.85), (1, 0.6, 0.2), (0.5, 0.85, 1), (1, 0.95, 0.4), (0.8, 0.8, 0.9), (0.7, 0.6, 1), (0.5, 1, 0.7), (1, 1, 1), (1, 0.9, 0.5), (1, 0.6, 0.75)]
    cell = 512
    cols = 5
    rows = (len(made) + cols - 1) // cols
    out = np.zeros((rows * cell, cols * cell, 4))
    out[..., :3] = np.array([0.1, 0.07, 0.16])
    out[..., 3] = 1
    for i, (name, tex) in enumerate(made):
        h, w = tex.shape[:2]
        step_y, step_x = max(1, h // cell), max(1, w // cell)
        small = tex[: cell * step_y: step_y, : cell * step_x: step_x]
        sh, sw = small.shape[:2]
        r, c = divmod(i, cols)
        y, x = r * cell + (cell - sh) // 2, c * cell + (cell - sw) // 2
        a = small[..., 3:4]
        col = small[..., :3] * np.array(tints[i % len(tints)])
        region = out[y:y + sh, x:x + sw, :3]
        out[y:y + sh, x:x + sw, :3] = col * a + region * (1 - a)
    save(bpy, out, path)
    print("sheet", path)


def main():
    import bpy

    out_dir = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(HERE, "png")
    sheet = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "sheet.png")
    only = sys.argv[3].split(",") if len(sys.argv) > 3 else list(TEXTURES)
    os.makedirs(out_dir, exist_ok=True)
    made = [(name, make(bpy, name, out_dir)) for name in only]
    if sheet != "-":
        contact_sheet(bpy, made, os.path.abspath(sheet))


if __name__ == "__main__":
    main()
