"""
Anime VFX textures for Steal a Donut, made in Blender: the particle textures behind the donuts'
and Domers' anime effects (power-up auras, sword slashes, impact frames, speed lines, sparkles...).

    PYTHONPATH=<folder with bpy> python3 anime_vfx.py [out_dir] [sheet.png] [only,these]

Cel-shaded like an anime: solid shapes in three tones (a dark band, a mid tone, a white core) with
a bold dark ink outline - no soft glow, so they stay crisp and don't turn into a white blur under
the game's bloom. They are white, grey and black on purpose: Roblox multiplies a particle's texture
by its colour, so one texture works for every colour (a pink donut's aura is pink, a fire donut's
orange) and the outline stays dark.

Flipbooks are 4 x 4 grids of 16 frames (Roblox ParticleEmitter FlipbookLayout Grid4x4), the
others single images. Upload them (Studio: View > Asset Manager > Bulk Import) and paste each
image id into Config.AnimeFX.Textures; until then the effects use Roblox's own particle textures.

Each shape is drawn as flat 2D curves (filled) with an emission material, seen from above by an
orthographic camera, rendered in Cycles; the ink outline is added afterwards (numpy).
"""

import math
import os
import random
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
TILE = 256  # pixels per flipbook frame (4 x 4 -> 1024 x 1024)
GREY = 0.62  # the mid tone's brightness (the core is white)
DARK = 0.36  # the dark band round the edge
INK = 0.05  # the outline


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


def tongues(spec, p, wobble, scale=1.0, lift=0.0):
    """Several flame tongues side by side: spec = [(x, height, width, phase offset)]."""
    out = []
    for dx, h, w, k in spec:
        poly = flame_outline(w * scale, (h + 0.07 * math.sin(p * 2 + k)) * scale - 0.82 * (1 - scale) + lift, p + k, wobble, lean=0.12 * math.sin(p + k) * dx)
        out.append([(x * scale + dx * scale, y) for x, y in poly])
    return out


def aura(t):
    """A spiky power-up aura: a fan of sharp energy tongues round a tall middle one."""
    p = t * 2 * math.pi
    outer = [(-0.5, 0.42, 0.22, 0.0), (-0.27, 0.72, 0.25, 1.3), (0.0, 0.95, 0.3, 2.6), (0.27, 0.68, 0.25, 3.9), (0.5, 0.38, 0.22, 5.2)]
    mid = [(-0.24, 0.5, 0.2, 0.7), (0.0, 0.72, 0.24, 1.9), (0.24, 0.46, 0.2, 3.1)]
    core = [(0.0, 0.42, 0.17, 2.3)]
    return [
        (DARK, 1.0, tongues(outer, p, 0.1)),
        (GREY, 1.0, tongues(mid, p, 0.08, 0.92, -0.04)),
        (1.0, 1.0, tongues(core, p, 0.06, 0.85, -0.1)),
    ]


def toon_fire(t):
    """Cartoon flames: three fat round-bottomed tongues, a lighter middle and a white heart."""
    p = t * 2 * math.pi
    outer = []
    for k, (dx, h, w) in enumerate(((-0.32, 0.45, 0.3), (0.0, 0.92, 0.42), (0.32, 0.55, 0.3))):
        poly = flame_outline(w, h + 0.06 * math.sin(p * 2 + k), p + k * 1.7, 0.14, lean=0.1 * math.sin(p + k))
        outer.append([(x + dx, y) for x, y in poly])
    mid = [[(x * 0.75, y * 0.82 - 0.12) for x, y in flame_outline(0.42, 0.7, p + 0.3, 0.12)]]
    core = [[(x * 0.5, y * 0.62 - 0.28) for x, y in flame_outline(0.42, 0.45, p + 0.5, 0.1)]]
    return [(DARK, 1.0, outer), (GREY, 1.0, mid), (1.0, 1.0, core)]


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
    if not any(gone):
        runs = [(0, math.pi + 0.01), (math.pi, 2 * math.pi + 0.01)]  # (a polygon can't have a hole in it)
    outer = [arc(r - th, r + th, a0, a1) for a0, a1 in runs]
    mid = [arc(r - th * 0.6, r + th * 0.6, a0, a1) for a0, a1 in runs]
    core = [arc(r - th * 0.25, r + th * 0.25, a0, a1) for a0, a1 in runs]
    # chunks of debris thrown out ahead of it
    debris = []
    for i in range(10):
        a = 2 * math.pi * (i + rng.random() * 0.6) / 10
        d = r + th + 0.05 + 0.18 * e * (0.6 + rng.random())
        size = 0.05 * (1 - t) + 0.012
        if d < 0.95 and size > 0.015:
            ca, sa = math.cos(a), math.sin(a)
            debris.append([(ca * d - sa * size, sa * d + ca * size), (ca * (d + size * 2.2), sa * (d + size * 2.2)), (ca * d + sa * size, sa * d - ca * size)])
    return [(DARK, 1.0, outer + debris), (GREY, 1.0, mid), (1.0, 1.0, core)]


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
    lens = [rng.uniform(0.55, 1.0) if i % 2 == 0 else rng.uniform(0.35, 0.6) for i in range(14)]
    grow = min(1, t * 5)
    fade = max(0, (t - 0.25) / 0.75)
    scale = (0.35 + 0.55 * grow + 0.05 * t) * 0.92
    inner = (0.24 - 0.18 * fade) * scale
    body = star(14, inner, [l * scale for l in lens], 0.1)
    mid = star(14, inner * 0.75, [l * scale * (0.72 - 0.35 * fade) for l in lens], 0.1)
    core = star(14, inner * 0.5, [l * scale * (0.45 - 0.3 * fade) for l in lens], 0.1)
    layers = [(DARK, 1.0, [body]), (GREY, 1.0, [mid]), (1.0, 1.0, [core])]
    if t < 0.2:
        layers.append((1.0, 1.0, [circle(0, 0, 0.26 * scale)]))  # the flash at the start
    return layers


def toon_smoke(t):
    """A cel-shaded smoke puff: a cluster of round blobs that swells, drifts up and thins out."""
    rng = random.Random(2)
    blobs = [(rng.uniform(-0.35, 0.35), rng.uniform(-0.3, 0.25), rng.uniform(0.22, 0.38)) for _ in range(6)]
    grow = 0.55 + 0.5 * (1 - (1 - t) ** 2)
    shrink = 1 - max(0, (t - 0.45) / 0.55) ** 1.4
    up = 0.25 * t
    body, mid, shine = [], [], []
    for (x, y, r) in blobs:
        rr = r * grow * shrink
        if rr > 0.02:
            body.append(circle(x * grow, y * grow + up, rr))
            mid.append(circle(x * grow - rr * 0.12, y * grow + up + rr * 0.12, rr * 0.78))
            shine.append(circle(x * grow - rr * 0.3, y * grow + up + rr * 0.3, rr * 0.35))
    return [(DARK, 1.0, body), (GREY, 1.0, mid), (1.0, 1.0, shine)]


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
    return [(DARK, 1.0, [body]), (GREY, 1.0, [[(x + 0.015, y * 0.985) for x, y in crescent(0.9, 0.22, 0.96)]]), (1.0, 1.0, [core]), (1.0, 0.8, streaks)]


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
    return [(GREY, 0.8, cross), (GREY, 1.0, [big, small]), (1.0, 1.0, [core])]


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
    return [(DARK, 1.0, [thick(main, 0.085), thick(branch, 0.055)]), (GREY, 1.0, [thick(main, 0.05), thick(branch, 0.032)]), (1.0, 1.0, [thick(main, 0.02), thick(branch, 0.013)])]


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
    return [(GREY + 0.1, 1.0, [pts]), (1.0, 1.0, [core])]


# -----------------------------------------------------------------------------------------------
# The hellfire set: glowing chains that hold down the hell donuts, the seal under them, and more
# -----------------------------------------------------------------------------------------------
def stroke(path, w):
    """A line of even width `w` along `path` (a list of points)."""
    left, right = [], []
    for i, (x, y) in enumerate(path):
        a = path[max(0, i - 1)]
        b = path[min(len(path) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy) or 1
        nx, ny = -dy / n, dx / n
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    return left + list(reversed(right))


def ring(r, w, steps=96):
    """A thin ring (two halves: a polygon can't have a hole in it)."""
    return [arc(r - w, r + w, 0, math.pi + 0.02, steps), arc(r - w, r + w, math.pi, 2 * math.pi + 0.02, steps)]


def lineart(pieces, w):
    """Glowing line art in three tones: a dark band, a grey glow and a white-hot core.
    pieces = [("path", points) | ("ring", r)], all drawn `w` thick."""
    out = []
    for tone, k in ((DARK, 2.2), (GREY, 1.4), (1.0, 0.6)):
        polys = []
        for kind, data in pieces:
            if kind == "ring":
                polys += ring(data, w * k)
            else:
                polys.append(stroke(data, w * k))
        out.append((tone, 1.0, polys))
    return out


def superellipse(cx, cy, a, b, theta, n=4.0):
    c, s = math.cos(theta), math.sin(theta)
    return (cx + a * math.copysign(abs(c) ** (2 / n), c), cy + b * math.copysign(abs(s) ** (2 / n), s))


def chain(_t):
    """Chain links for a Beam (a 4 x 1 strip that tiles end to end): links seen face on - a
    rounded ring - with links seen edge on threaded through them. Tinted hot orange in game."""
    def link_ring(cx, a, b, a2, b2, t0=0.0, t1=2 * math.pi, steps=64):
        polys = []
        for i in range(steps):
            th0 = t0 + (t1 - t0) * i / steps
            th1 = t0 + (t1 - t0) * (i + 1) / steps
            polys.append([superellipse(cx, 0, a, b, th0), superellipse(cx, 0, a, b, th1), superellipse(cx, 0, a2, b2, th1), superellipse(cx, 0, a2, b2, th0)])
        return polys
    face, side = [], []
    for cx in (-0.5, 0.5):
        face.append((DARK, 1.0, link_ring(cx, 0.37, 0.2, 0.22, 0.075)))
        face.append((GREY, 1.0, link_ring(cx, 0.335, 0.175, 0.245, 0.095)))
        face.append((1.0, 1.0, link_ring(cx, 0.31, 0.16, 0.27, 0.115, math.pi * 0.15, math.pi * 0.85, 24)))
    for cx in (-1.0, 0.0, 1.0):
        bar = [superellipse(cx, 0, 0.33, 0.058, 2 * math.pi * i / 64, 6) for i in range(64)]
        mid = [superellipse(cx, 0.004, 0.31, 0.038, 2 * math.pi * i / 64, 6) for i in range(64)]
        hot = [(cx - 0.24, 0.022), (cx + 0.24, 0.022), (cx + 0.24, 0.032), (cx - 0.24, 0.032)]
        side += [(DARK, 1.0, [bar]), (GREY, 1.0, [mid]), (1.0, 1.0, [hot])]
    layers = []
    for tone in (DARK, GREY, 1.0):
        for layer in face:
            if layer[0] == tone:
                layers.append(layer)
    for tone in (DARK, GREY, 1.0):
        for layer in side:
            if layer[0] == tone:
                layers.append(layer)
    return layers


# Made-up decorative marks for the seal (a crescent and a dot, a curl, a diamond with a bar, a
# double wave), in a -1..1 box. Deliberately not letters, runes or any real symbol.
def _arc_path(cx, cy, r, a0, a1, n=16):
    return [(cx + r * math.cos(a0 + (a1 - a0) * i / n), cy + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


RUNE_SHAPES = [
    [_arc_path(0, 0, 0.65, math.pi * 0.35, math.pi * 1.65), _arc_path(0.15, 0, 0.12, 0, math.pi * 1.0), _arc_path(0.15, 0, 0.12, math.pi, math.pi * 2.0)],
    [[(0.6 * (1 - i / 40) * math.cos(i / 40 * math.pi * 3.2), 0.6 * (1 - i / 40) * math.sin(i / 40 * math.pi * 3.2)) for i in range(41)]],
    [[(-0.6, 0.0), (0.0, 0.7), (0.6, 0.0)], [(0.6, 0.0), (0.0, -0.7), (-0.6, 0.0)], [(-0.22, 0.0), (0.22, 0.0)]],
    [[(-0.7 + 1.4 * i / 30, 0.25 + 0.18 * math.sin(i / 30 * math.pi * 2)) for i in range(31)], [(-0.7 + 1.4 * i / 30, -0.25 + 0.18 * math.sin(i / 30 * math.pi * 2)) for i in range(31)]],
]


def seal(_t):
    """A glowing sealing circle for the ground under a chained donut: rings, a band of made-up
    marks, a donut in the middle, and little rings round it."""
    pieces = [("ring", 0.94), ("ring", 0.85), ("ring", 0.64), ("ring", 0.3)]
    rng = random.Random(13)
    for i in range(18):
        a = 2 * math.pi * i / 18
        shape = RUNE_SHAPES[rng.randrange(len(RUNE_SHAPES))]
        r0 = 0.745
        ca, sa = math.cos(a), math.sin(a)
        for path in shape:
            pts = []
            for (u, v) in path:
                # (u along the circle, v towards the middle)
                x = ca * (r0 + v * 0.065) - sa * u * 0.065
                y = sa * (r0 + v * 0.065) + ca * u * 0.065
                pts.append((x, y))
            pieces.append(("path", pts))
    # a donut in the middle: its hole, and sprinkles round it
    pieces.append(("ring", 0.16))
    for i in range(9):
        a = 2 * math.pi * (i + 0.3) / 9
        r = 0.23
        d = (math.cos(a + 1.1), math.sin(a + 1.1))
        c = (math.cos(a) * r, math.sin(a) * r)
        pieces.append(("path", [(c[0] - d[0] * 0.035, c[1] - d[1] * 0.035), (c[0] + d[0] * 0.035, c[1] + d[1] * 0.035)]))
    out = lineart(pieces, 0.011)
    # little rings at the triangle's corners, and dots round the outer band
    extra = []
    for k in range(3):
        a = math.pi / 2 + 2 * math.pi * k / 3
        extra += [[(x + 0.64 * math.cos(a), y + 0.64 * math.sin(a)) for x, y in poly] for poly in ring(0.08, 0.012)]
    dots = [circle(0.895 * math.cos(2 * math.pi * (i + 0.5) / 12), 0.895 * math.sin(2 * math.pi * (i + 0.5) / 12), 0.022, 16) for i in range(12)]
    out.append((GREY, 1.0, extra))
    out.append((1.0, 1.0, dots))
    return out


def runes(t):
    """Four glowing rune marks (a 2 x 2 set) that drift up from the seal."""
    shape = RUNE_SHAPES[min(3, int(round(t * 3)))]
    return lineart([("path", [(x * 0.75, y * 0.75) for x, y in path]) for path in shape], 0.06)


def crack(_t):
    """Glowing cracks in the ground, branching out from a bright spot in the middle."""
    rng = random.Random(21)
    pieces = []
    for i in range(7):
        a = 2 * math.pi * i / 7 + rng.uniform(-0.25, 0.25)
        pts = [(0.0, 0.0)]
        r = 0.0
        while r < 0.92:
            r += rng.uniform(0.08, 0.16)
            a += rng.uniform(-0.35, 0.35)
            pts.append((math.cos(a) * min(r, 0.95), math.sin(a) * min(r, 0.95)))
        pieces.append(pts)
        for _ in range(rng.randint(1, 2)):
            k = rng.randrange(2, len(pts) - 1)
            b = a + rng.choice((-1, 1)) * rng.uniform(0.6, 1.0)
            sub = [pts[k]]
            for _ in range(rng.randint(2, 4)):
                b += rng.uniform(-0.3, 0.3)
                x, y = sub[-1]
                sub.append((x + math.cos(b) * 0.1, y + math.sin(b) * 0.1))
            pieces.append(sub)
    layers = []
    for tone, w in ((DARK, 0.045), (GREY, 0.026), (1.0, 0.01)):
        layers.append((tone, 1.0, [thick(p, w) for p in pieces]))
    layers.append((1.0, 1.0, [star(9, 0.06, [rng.uniform(0.1, 0.17) for _ in range(9)])]))
    return layers


def dark_flame(t):
    """Hellfire: flame tongues with a white-hot rim round a dark heart (tinted red in game, it's a
    bright red edge round a nearly black flame)."""
    p = t * 2 * math.pi
    outer = [(-0.4, 0.55, 0.24, 0.0), (-0.15, 0.92, 0.27, 1.6), (0.15, 0.78, 0.26, 3.1), (0.42, 0.5, 0.22, 4.4)]
    return [
        (1.0, 1.0, tongues(outer, p, 0.13)),
        (0.22, 1.0, tongues(outer, p, 0.13, 0.86, -0.06)),
        (0.1, 1.0, tongues([(0.0, 0.62, 0.3, 2.2)], p, 0.09, 0.7, -0.18)),
    ]


def ember(_t):
    """A rising ember: a bright head and a tapering streak behind it."""
    head = circle(0, 0.45, 0.2, 40)
    tail = [(-0.17, 0.42), (0.0, -0.85), (0.17, 0.42)]
    return [(DARK, 1.0, [head, tail]), (GREY, 1.0, [circle(0, 0.47, 0.14, 32), [(-0.1, 0.45), (0.0, -0.45), (0.1, 0.45)]]), (1.0, 1.0, [circle(0.02, 0.5, 0.075, 24)])]


def wisp(t):
    """A curling tendril of smoke that rises, curls over at the top and thins away."""
    grow = 0.25 + 0.75 * min(1.0, t * 1.6)
    thin = 1 - max(0.0, (t - 0.55) / 0.45)
    n = 40
    path = []
    for i in range(n + 1):
        s = i / n * grow
        x = 0.28 * math.sin(3.4 * s + 0.6) * s + 0.1 * s
        y = -0.85 + 1.5 * s
        if s > 0.75:
            k = (s - 0.75) / 0.25
            x += 0.25 * math.sin(k * 2.2)
            y -= 0.18 * k * k
        path.append((x, y))
    w = 0.2 * thin + 0.03
    def tapered(path, w):
        left, right = [], []
        for i, (x, y) in enumerate(path):
            a = path[max(0, i - 1)]
            b = path[min(len(path) - 1, i + 1)]
            dx, dy = b[0] - a[0], b[1] - a[1]
            m = math.hypot(dx, dy) or 1
            nx, ny = -dy / m, dx / m
            ww = w * math.sin(math.pi * min(1, (i + 1) / (len(path)))) ** 0.6
            left.append((x + nx * ww, y + ny * ww))
            right.append((x - nx * ww, y - ny * ww))
        return left + list(reversed(right))
    return [(DARK, 1.0, [tapered(path, w)]), (GREY, 1.0, [tapered(path, w * 0.62)]), (1.0, 1.0, [tapered([(x - w * 0.15, y) for x, y in path], w * 0.22)])]


def burst(t):
    """An anime power-up burst: a crown of spikes shooting out round an empty middle, then
    thinning away."""
    rng = random.Random(31)
    e = 1 - (1 - t) ** 2
    inner = 0.18 + 0.42 * e
    fade = max(0.0, (t - 0.35) / 0.65)
    layers = []
    for tone, k in ((DARK, 1.0), (GREY, 0.66), (1.0, 0.33)):
        spikes = []
        for i in range(18):
            a = 2 * math.pi * i / 18 + rng.uniform(-0.05, 0.05)
            length = (0.18 + 0.32 * rng.random()) * (1 - fade) * (0.5 + 0.5 * e)
            half = 0.11 * k * (1 - 0.7 * fade)
            ca, sa = math.cos(a), math.sin(a)
            tip = inner + length * (1.0 if tone == DARK else 0.85)
            spikes.append([(math.cos(a - half) * inner, math.sin(a - half) * inner), (ca * min(tip, 0.97), sa * min(tip, 0.97)), (math.cos(a + half) * inner, math.sin(a + half) * inner)])
        layers.append((tone, 1.0, spikes))
        rng = random.Random(31)
    layers.append((1.0, 1.0, ring(inner, 0.02 * (1 - fade) + 0.004)))
    return layers


TEXTURES = {
    # name: (draw, frames (16 = a 4 x 4 flipbook, 4 = a 2 x 2 set, 1 = one image), pixels per frame,
    #        ink outline width in pixels (0 = none))
    "Aura": (aura, 16, TILE, 5),
    "ToonFire": (toon_fire, 16, TILE, 5),
    "ShockRing": (shock_ring, 16, TILE, 4),
    "Impact": (impact, 16, TILE, 5),
    "ToonSmoke": (toon_smoke, 16, TILE, 5),
    "Lightning": (lightning, 4, 256, 4),
    "Slash": (slash, 1, 512, 8),
    "SpeedLines": (speed_lines, 1, 1024, 0),
    "Kira": (kira, 1, 256, 3),
    "Petal": (petal, 1, 256, 4),
    # the hellfire set
    "Chain": (chain, 1, (1024, 256), 5),
    "Seal": (seal, 1, 1024, 6),
    "Runes": (runes, 4, 256, 4),
    "Crack": (crack, 1, 1024, 6),
    "DarkFlame": (dark_flame, 16, TILE, 5),
    "Ember": (ember, 1, 256, 3),
    "Wisp": (wisp, 16, TILE, 4),
    "Burst": (burst, 16, TILE, 4),
}
LOOPING = ("Aura", "ToonFire", "DarkFlame")


# -----------------------------------------------------------------------------------------------
# Blender
# -----------------------------------------------------------------------------------------------
def setup(bpy, size):
    """`size`: pixels (square) or (width, height); the drawing space is -1..1 across the longer side."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.cycles.device = "CPU"
    w, h = size if isinstance(size, tuple) else (size, size)
    scene.render.resolution_x, scene.render.resolution_y = w, h
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


def ink(px, width):
    """A bold dark outline round the shape, under it (the shape grown by `width` pixels)."""
    if width <= 0:
        return px
    a = px[..., 3]
    grown = a.copy()
    h, w = a.shape
    for dy in range(-width, width + 1):
        for dx in range(-width, width + 1):
            if dx * dx + dy * dy <= width * width:
                shifted = np.zeros_like(a)
                shifted[max(0, dy):h + min(0, dy), max(0, dx):w + min(0, dx)] = a[max(0, -dy):h - max(0, dy), max(0, -dx):w - max(0, dx)]
                grown = np.maximum(grown, shifted)
    grown = np.clip(blur(grown, 1), 0, 1)  # (a softer, anti-aliased edge)
    out_a = a + grown * (1 - a)
    rgb = (px[..., :3] * a[..., None] + INK * (grown * (1 - a))[..., None]) / np.maximum(out_a, 1e-6)[..., None]
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
    fn, frames, size, outline = TEXTURES[name]
    scene = setup(bpy, size)
    tmp = os.path.join(out_dir, "_frame.png")
    if frames == 1:
        sheet = ink(render_frame(bpy, scene, fn(0.0), tmp), outline)
    else:
        side = int(math.sqrt(frames))
        sheet = np.zeros((size * side, size * side, 4))
        for i in range(frames):
            t = i / frames if name in LOOPING else i / (frames - 1)
            tile = ink(render_frame(bpy, scene, fn(t), tmp), outline)
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
    out[..., :3] = np.array([0.55, 0.72, 0.88])  # (a daytime sky, like the game)
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
