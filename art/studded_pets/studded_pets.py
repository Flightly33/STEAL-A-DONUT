# Studded pets: every pet in the game as a little brick creature - chunky blocks with studs on
# top, square eyes with a white glint and pink cheeks, in the same style as Domer and the brick
# donuts. Six body plans (Quad, Dragon, Bird, Blob, Whale, Crab) and every feature a pet can have
# (ears, horns, wings, tails, crowns...), each one a list of blocks.
#
#   python3 studded_pets.py <lineup.jpg | lineup.png | -> [export.luau] [pet ids, comma separated]
#   e.g. python3 studded_pets.py lineup.jpg ../../src/shared/PetBlocks.luau
#
# The blocks here ARE the pets: the export writes them to src/shared/PetBlocks.luau, and
# PetModel.BuildPet builds every pet in the game from that file (no meshes to upload). So to change
# a pet: change it here, run this again, and the game's pets change too. The render shows them
# all in a row with their names (a transparent background, studs drawn the way the game adds them).
# Needs Blender's Python module (pip install bpy).
import math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
PITCH = 0.42  # one stud every PITCH (pet units ~ studs) on the top of a studded block
STUD_D, STUD_H = 0.24, 0.1  # a stud's diameter and height

INK = "#141419"  # eyes, noses
MOUTH = "#46282d"
PINK = "#ff8fb4"
ORANGE = "#ffa028"
CREAM = "#fff0d2"
GOLD = "#ffd23c"


# ---- blocks --------------------------------------------------------------------------------
# A block: a box (centre c, size s, rotation r in degrees like CFrame.Angles) or a rod (from a to
# b, t thick). col: a colour role ("Body", "Accent", "Pale", "Shade", "AccentLight", "Snout",
# "ShellPlate") or "#rrggbb". mat: Smooth | Neon | Glow (Neon on Glow pets) | Foil | Wood |
# WoodPlanks | Metal | Slate | Fabric. studs: studs on its top. limb: (kind, side, pivot) - the
# client swings it round pivot. eye / pupil: blinks shut / hides when blinking. only / unless:
# a feature the pet must have / must not have.
def B(c, s, col, name="Part", r=None, mat="Smooth", studs=False, limb=None, eye=False, pupil=False, alpha=0, only=None, unless=None):
    return dict(kind="box", c=tuple(c), s=tuple(s), r=tuple(r) if r else (0, 0, 0), col=col, name=name, mat=mat, studs=studs, limb=limb, eye=eye, pupil=pupil, alpha=alpha, only=only, unless=unless)


def R(a, b, t, col, name="Part", mat="Smooth", limb=None, only=None, unless=None):
    return dict(kind="rod", a=tuple(a), b=tuple(b), t=t, col=col, name=name, mat=mat, studs=False, limb=limb, eye=False, pupil=False, alpha=0, only=only, unless=unless)


def add(p, q):
    return (p[0] + q[0], p[1] + q[1], p[2] + q[2])


def face(an):
    """Square black eyes with a white glint, and pink cheeks, on the front of the head."""
    out = []
    fz = an["face_z"]
    dx, ey = an["eye"]
    ew, eh = an["eye_s"]
    for s in (-1, 1):
        x = s * dx
        out.append(B((x, ey, fz - 0.025), (ew, eh, 0.06), INK, "Eye", eye=True))
        out.append(B((x + ew * 0.2, ey + eh * 0.22, fz - 0.06), (ew * 0.36, ew * 0.36, 0.03), "#ffffff", "Glint", mat="Neon", pupil=True))
        out.append(B((x - ew * 0.22, ey - eh * 0.26, fz - 0.06), (ew * 0.17, ew * 0.17, 0.03), "#ffffff", "Glint", mat="Neon", pupil=True))
        out.append(B((s * (dx + ew * 0.95), ey - eh * 0.62, fz - 0.018), (ew * 0.8, eh * 0.3, 0.04), PINK, "Cheek", alpha=0.15))
    return out


# ---- body plans ------------------------------------------------------------------------------
# Every shape: its blocks, and anchors the features hang off (the head's centre and half size,
# the body's, where the tail and wings join, and its face).
def shape_quad():
    an = dict(body_c=(0, -0.12, 0.35), body_h=(0.75, 0.58, 0.95), head_c=(0, 0.74, -0.6), head_h=(0.76, 0.64, 0.62),
              tail=(0, 0.2, 1.3), wing=(0.62, 0.42, 0.3), face_z=-1.22, eye=(0.34, 0.9), eye_s=(0.26, 0.36), spade=False)
    bl = [
        B(an["body_c"], (1.5, 1.16, 1.9), "Body", "Body", studs=True),
        B((0, -0.12, -0.615), (0.86, 0.72, 0.04), "Pale", "Chest"),
        B(an["head_c"], (1.52, 1.28, 1.24), "Body", "Body", studs=True),
        # a muzzle with a nose and a little "w" mouth
        B((0, 0.5, -1.3), (0.72, 0.44, 0.2), "Pale", "Snout"),
        B((0, 0.66, -1.415), (0.26, 0.14, 0.04), INK, "Nose"),
        B((-0.07, 0.36, -1.405), (0.13, 0.05, 0.03), MOUTH, "Mouth", r=(0, 0, 28)),
        B((0.07, 0.36, -1.405), (0.13, 0.05, 0.03), MOUTH, "Mouth", r=(0, 0, -28)),
    ]
    for x in (-0.45, 0.45):
        for z in (-0.25, 0.98):
            bl.append(B((x, -0.86, z), (0.42, 0.5, 0.42), "Body", "Body"))
            bl.append(B((x, -1.16, z - 0.04), (0.48, 0.16, 0.52), "Pale", "Paw"))
    return bl + face(an), an


def shape_dragon():
    an = dict(body_c=(0, -0.02, 0.5), body_h=(0.86, 0.68, 1.25), head_c=(0, 1.25, -1.15), head_h=(0.7, 0.6, 0.7),
              tail=(0, 0.15, 1.75), wing=(0.6, 0.55, 0.25), face_z=-1.85, eye=(0.34, 1.45), eye_s=(0.25, 0.32), spade=True)
    bl = [
        B(an["body_c"], (1.72, 1.36, 2.5), "Body", "Body", studs=True),
        B((0, 0.6, -0.7), (0.92, 1.1, 0.8), "Body", "Body"),  # neck
        B((0, 0.5, -1.115), (0.6, 0.9, 0.04), "Pale", "Scales"),
        B((0, -0.3, -0.765), (1.1, 0.9, 0.04), "Pale", "Scales"),
        B(an["head_c"], (1.4, 1.2, 1.4), "Body", "Body", studs=True),
        B((0, 1.02, -2.02), (0.96, 0.52, 0.36), "Snout", "Snout"),
        B((-0.2, 1.18, -2.205), (0.12, 0.08, 0.03), INK, "Nose"),
        B((0.2, 1.18, -2.205), (0.12, 0.08, 0.03), INK, "Nose"),
        B((0, 0.86, -2.205), (0.6, 0.05, 0.03), MOUTH, "Mouth"),
    ]
    # a spiky ridge from the top of its head down its back
    for z in (-1.0, -0.55):
        bl.append(B((0, 1.92, z), (0.08, 0.3, 0.3), "Accent", "Spike", r=(45, 0, 0), mat="Glow"))
    for z in (-0.2, 0.4, 1.0):
        bl.append(B((0, 0.78, z), (0.08, 0.36, 0.36), "Accent", "Spike", r=(45, 0, 0), mat="Glow"))
    for x in (-0.52, 0.52):
        for z in (-0.3, 1.3):
            bl.append(B((x, -0.95, z), (0.46, 0.6, 0.46), "Body", "Body"))
            bl.append(B((x, -1.29, z - 0.06), (0.52, 0.12, 0.58), "Pale", "Claw"))
    return bl + face(an), an


def shape_bird():
    an = dict(body_c=(0, -0.12, 0.1), body_h=(0.85, 0.8, 0.8), head_c=(0, 1.02, -0.15), head_h=(0.7, 0.6, 0.64),
              tail=None, wing=(0.86, 0.35, 0.05), face_z=-0.79, eye=(0.31, 1.1), eye_s=(0.26, 0.36), spade=False)
    bl = [
        B(an["body_c"], (1.7, 1.6, 1.6), "Body", "Body", studs=True),
        B((0, -0.25, -0.715), (1.1, 1.0, 0.04), "Pale", "Chest"),
        B(an["head_c"], (1.4, 1.2, 1.28), "Body", "Body", studs=True),
        B((0, 0.82, -0.805), (0.2, 0.05, 0.03), MOUTH, "Mouth", unless="Beak"),
    ]
    for s in (-1, 1):
        bl.append(B((s * 0.36, -1.0, 0.0), (0.14, 0.26, 0.14), ORANGE, "Leg"))
        bl.append(B((s * 0.36, -1.13, -0.14), (0.44, 0.1, 0.52), ORANGE, "Foot"))
        # little wings folded at its sides (unless it has big ones)
        bl.append(B((s * 0.92, -0.05, 0.15), (0.16, 0.9, 1.0), "Accent", "Wing", mat="Glow", limb=("Wing", s, (s * 0.88, 0.38, 0.1)), unless="Wings"))
    for i in (-1, 0, 1):
        bl.append(B((i * 0.25, -0.22, 0.98), (0.24, 0.12, 0.72), "Accent", "Feather", r=(-25, -i * 18, 0), mat="Glow", limb=("Tail", 0, (0, -0.3, 0.75))))
    return bl + face(an), an


def shape_blob():
    an = dict(body_c=(0, 0, 0), body_h=(1.05, 0.98, 1.0), head_c=(0, 0, 0), head_h=(1.05, 0.98, 1.0),
              tail=(0, -0.4, 0.95), wing=(0.95, 0.4, 0.3), face_z=-1.0, eye=(0.4, 0.28), eye_s=(0.32, 0.44), spade=True)
    bl = [
        B((0, -0.05, 0), (2.1, 1.66, 2.0), "Body", "Body"),
        B((0, 0.86, 0), (1.8, 0.24, 1.7), "Body", "Body", studs=True),  # (stepped edges: a softer, rounder brick)
        B((0, -0.94, 0), (1.8, 0.2, 1.7), "Body", "Body"),
        B((0, -0.14, -1.015), (0.3, 0.06, 0.03), MOUTH, "Mouth"),
    ]
    return bl + face(an), an


def shape_whale():
    an = dict(body_c=(0, 0, 0), body_h=(1.0, 0.8, 1.5), head_c=(0, 0, 0), head_h=(1.0, 0.8, 1.5),
              tail=None, wing=(0.9, 0.6, 0.2), face_z=-1.5, eye=(0.6, 0.2), eye_s=(0.3, 0.38), spade=False)
    bl = [
        B((0, 0.02, 0), (2.0, 1.56, 3.0), "Body", "Body", studs=True),
        B((0, -0.56, -0.05), (2.06, 0.5, 2.94), "Accent", "Belly"),
        B((0, -0.22, -1.515), (0.8, 0.05, 0.03), MOUTH, "Mouth"),
        # tail and flukes (they flap up and down), and side fins
        B((0, 0.22, 1.82), (0.9, 0.68, 0.8), "Body", "Body", limb=("Fluke", 0, (0, 0.15, 1.45))),
    ]
    for s in (-1, 1):
        bl.append(B((s * 0.55, 0.42, 2.3), (1.0, 0.18, 0.62), "Body", "Body", r=(0, s * 25, 0), limb=("Fluke", 0, (0, 0.15, 1.45))))
        bl.append(B((s * 1.16, -0.32, -0.3), (0.7, 0.16, 0.5), "Body", "Body", r=(0, 0, -s * 30), limb=("Fin", s, (s * 0.98, -0.25, -0.3))))
    return bl + face(an), an


def shape_crab():
    an = dict(body_c=(0, 0, 0), body_h=(1.1, 0.5, 0.85), head_c=(0, 0, 0), head_h=(1.1, 0.5, 0.85),
              tail=None, wing=(0.9, 0.4, 0.3), face_z=-0.85, eye=(0.4, 1.14), eye_s=(0.3, 0.32), spade=False)
    bl = [
        B((0, -0.02, 0), (2.2, 0.92, 1.7), "Body", "Body"),
        B((0, 0.55, 0.05), (1.9, 0.24, 1.45), "Body", "Body", studs=True),
        B((0, -0.12, -0.865), (0.3, 0.05, 0.03), MOUTH, "Mouth"),
    ]
    for s in (-1, 1):
        bl.append(B((s * 0.6, -0.02, -0.86), (0.26, 0.09, 0.03), PINK, "Cheek", alpha=0.15))
        for i in range(3):
            z = -0.2 + i * 0.4
            hip, knee, foot = (s * 0.95, -0.1, z), (s * 1.5, 0.18, z + 0.12 * (i - 1)), (s * 1.82, -0.6, z + 0.22 * (i - 1))
            bl.append(R(hip, knee, 0.16, "Body", "Body"))
            bl.append(R(knee, foot, 0.13, "Body", "Body"))
        # big claws
        bl.append(R((s * 0.9, 0.05, -0.5), (s * 1.35, 0.3, -0.95), 0.26, "Body", "Body"))
        bl.append(B((s * 1.48, 0.36, -1.28), (0.66, 0.5, 0.72), "Body", "Body", studs=True))
        bl.append(B((s * 1.36, 0.68, -1.56), (0.26, 0.18, 0.5), "Accent", "Pincer", r=(20, 0, 0)))
        bl.append(B((s * 1.6, 0.2, -1.6), (0.26, 0.16, 0.44), "Accent", "Pincer"))
        # eyes on stalks
        bl.append(R((s * 0.36, 0.4, -0.5), (s * 0.4, 1.0, -0.56), 0.14, "Body", "Body"))
        bl.append(B((s * 0.4, 1.14, -0.58), (0.3, 0.32, 0.3), INK, "Eye", eye=True))
        bl.append(B((s * 0.4 + 0.06, 1.2, -0.745), (0.1, 0.1, 0.02), "#ffffff", "Glint", mat="Neon", pupil=True))
    return bl, an


SHAPES = {"Quad": shape_quad, "Dragon": shape_dragon, "Bird": shape_bird, "Blob": shape_blob, "Whale": shape_whale, "Crab": shape_crab}


# ---- features ----------------------------------------------------------------------------------
def hsv(h, s, v):
    i = int(h * 6) % 6
    f = h * 6 - int(h * 6)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    r, g, b = [(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)][i]
    return "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))


def feature(name, shape, an):
    hc, hh = an["head_c"], an["head_h"]
    bc, bh = an["body_c"], an["body_h"]
    ht = hc[1] + hh[1]  # top of the head
    hf = hc[2] - hh[2]  # front of the head
    bt = bc[1] + bh[1]  # top of the body
    dx, ey = an["eye"]
    out = []
    sides = (-1, 1)
    if name == "PointyEars":
        for s in sides:
            c = (s * hh[0] * 0.6, ht + 0.16, hc[2] + 0.1)
            out.append(B(c, (0.5, 0.5, 0.18), "Body", "Body", r=(0, 0, 45 - s * 15)))
            out.append(B(add(c, (0, 0.02, -0.1)), (0.28, 0.28, 0.04), "Accent", "Ear", r=(0, 0, 45 - s * 15)))
    elif name == "FloppyEars":
        for s in sides:
            out.append(B((s * (hh[0] + 0.07), hc[1] + 0.12, hc[2] + 0.05), (0.16, 0.86, 0.52), "Accent", "Ear", r=(0, 0, s * 8)))
    elif name == "LongEars":
        for s in sides:
            c = (s * 0.32, ht + 0.55, hc[2] + 0.12)
            out.append(B(c, (0.3, 1.1, 0.22), "Body", "Body", r=(0, 0, -s * 8)))
            out.append(B(add(c, (0, -0.02, -0.12)), (0.14, 0.82, 0.04), PINK, "Ear", r=(0, 0, -s * 8)))
    elif name == "RoundEars":
        for s in sides:
            out.append(B((s * hh[0] * 0.72, ht + 0.15, hc[2] + 0.05), (0.42, 0.34, 0.26), "Body", "Body"))
            out.append(B((s * hh[0] * 0.72, ht + 0.13, hc[2] - 0.085), (0.22, 0.2, 0.04), "Accent", "Ear"))
    elif name == "Horns":
        for s in sides:
            base = (s * hh[0] * 0.55, ht, hc[2] + 0.15)
            out.append(B(add(base, (s * 0.06, 0.16, 0.04)), (0.22, 0.34, 0.22), CREAM, "Horn", r=(-15, 0, -s * 15)))
            out.append(B(add(base, (s * 0.16, 0.42, 0.16)), (0.14, 0.28, 0.14), CREAM, "Horn", r=(-30, 0, -s * 25)))
    elif name == "Tufts":
        for s in sides:
            out.append(B((s * hh[0] * 0.62, ht + 0.16, hc[2]), (0.18, 0.46, 0.18), "Accent", "Tuft", r=(0, 0, -s * 28)))
    elif name == "Wings":
        k = 1.3 if shape == "Dragon" else 1.0
        wx, wy, wz = an["wing"]
        for s in sides:
            root = (s * wx, wy, wz)
            limb = ("Wing", s, root)
            out.append(B(add(root, (s * 0.38 * k, 0.55 * k, 0.15 * k)), (0.14, 1.25 * k, 1.0 * k), "Accent", "Wing", r=(0, -s * 20, -s * 35), mat="Glow", limb=limb))
            out.append(B(add(root, (s * 0.46 * k, 0.36 * k, 0.42 * k)), (0.12, 0.85 * k, 0.7 * k), "AccentLight", "Wing", r=(0, -s * 20, -s * 35), mat="Glow", limb=limb))
    elif name == "Antenna":
        for s in sides:
            base = (s * 0.3, ht, hc[2])
            tip = add(base, (s * 0.22, 0.55, 0.05))
            out.append(R(base, tip, 0.07, "#46464f", "Antenna"))
            out.append(B(add(tip, (0, 0.05, 0)), (0.2, 0.2, 0.2), "Accent", "Antenna", mat="Neon"))
    elif name == "Belly":
        out.append(B((0, bc[1] - 0.12, bc[2] - bh[2] - 0.03), (1.25, 1.25, 0.05), "Accent", "Belly"))
    elif name == "Horn":
        base = (0, ht, hf + 0.25)
        out.append(B(add(base, (0, 0.14, -0.08)), (0.26, 0.3, 0.26), "#ffe678", "Horn", r=(-30, 0, 0), mat="Neon"))
        out.append(B(add(base, (0, 0.38, -0.22)), (0.18, 0.28, 0.18), "#fff0aa", "Horn", r=(-30, 45, 0), mat="Neon"))
        out.append(B(add(base, (0, 0.6, -0.35)), (0.1, 0.22, 0.1), "#fffad2", "Horn", r=(-30, 0, 0), mat="Neon"))
    elif name == "Crest":
        for i in range(3):
            out.append(B((0, ht + 0.2 - i * 0.04, hc[2] + 0.05 + i * 0.2), (0.12, 0.5, 0.28), "Accent", "Crest", r=(-15 - i * 18, 0, 0), mat="Glow"))
    elif name == "Mane":
        a0, a1 = (0, ht, hc[2] + 0.25), (0, bt, bc[2] - 0.2)
        for i in range(5):
            a = i / 4
            p = (a0[0] + (a1[0] - a0[0]) * a, a0[1] + (a1[1] - a0[1]) * a + 0.06, a0[2] + (a1[2] - a0[2]) * a + 0.2)
            out.append(B(p, (0.28, 0.5, 0.38), hsv(i / 5, 0.6, 1), "Mane", r=(28, 0, 0), mat="Neon"))
    elif name in ("Tail", "BigTail", "PuffTail"):
        root = an["tail"]
        if root is None:
            return out
        limb = ("Tail", 0, root)
        if name == "BigTail":
            out.append(B(add(root, (0, 0.42, 0.5)), (0.66, 0.66, 1.25), "Body", "Body", r=(-38, 0, 0), limb=limb))
            out.append(B(add(root, (0, 0.92, 0.95)), (0.56, 0.56, 0.56), "Accent", "Tail", r=(-38, 0, 0), limb=limb))
        elif name == "PuffTail":
            out.append(B(add(root, (0, 0.08, 0.14)), (0.5, 0.5, 0.5), "Accent", "Tail", limb=limb))
            out.append(B(add(root, (0, 0.38, 0.14)), (0.3, 0.16, 0.3), "Accent", "Tail", limb=limb))
        elif an["spade"]:
            a = add(root, (0, 0.1, 0.65))
            c = add(a, (0, 0.38, 0.5))
            out.append(R(root, a, 0.3, "Body", "Body", limb=limb, unless="BigTail"))
            out.append(R(a, c, 0.22, "Body", "Body", limb=limb, unless="BigTail"))
            out.append(B(add(c, (0, 0.12, 0.18)), (0.08, 0.44, 0.44), "Accent", "Tail", r=(45, 0, 0), mat="Glow", limb=limb, unless="BigTail"))
        else:
            out.append(B(add(root, (0, 0.14, 0.22)), (0.24, 0.24, 0.46), "Body", "Body", r=(-35, 0, 0), limb=limb, unless="BigTail"))
            out.append(B(add(root, (0, 0.5, 0.4)), (0.2, 0.44, 0.2), "Body", "Body", limb=limb, unless="BigTail"))
            out.append(B(add(root, (0, 0.8, 0.42)), (0.3, 0.3, 0.3), "Accent", "Tail", mat="Glow", limb=limb, unless="BigTail"))
    elif name == "Spikes":
        for i in range(4):
            out.append(B((0, bt + 0.06, bc[2] - bh[2] * 0.6 + i * bh[2] * 0.42), (0.08, 0.32, 0.32), "Accent", "Spike", r=(45, 0, 0), mat="Glow"))
    elif name == "Tentacles":
        for i in range(6):
            ang = i / 6 * math.tau + 0.26
            o = (math.cos(ang), 0, math.sin(ang))
            root = (bc[0] + o[0] * 0.6, bc[1] - bh[1] * 0.7, bc[2] + o[2] * 0.6)
            knee = (root[0] + o[0] * 0.15, root[1] - 0.5, root[2] + o[2] * 0.15)
            tip = (knee[0] + o[0] * 0.3, knee[1] - 0.22, knee[2] + o[2] * 0.3)
            limb = ("Tentacle", 1 if i % 2 == 0 else -1, root)
            out.append(R(root, knee, 0.3, "Accent", "Tentacle", mat="Glow", limb=limb))
            out.append(R(knee, tip, 0.22, "Accent", "Tentacle", mat="Glow", limb=limb))
            out.append(B(tip, (0.24, 0.24, 0.24), "Accent", "Tentacle", mat="Glow", limb=limb))
    elif name == "Sprinkles":
        colors = ["#ff4646", "#50c8ff", "#ffeb46", "#78e65a"]
        spots = [(-0.6, -0.55, 20), (0.1, -0.7, -40), (0.6, -0.4, 70), (-0.3, -0.1, -15), (0.45, 0.05, 35), (-0.65, 0.35, 60), (0.05, 0.4, -65), (0.6, 0.6, 10), (-0.25, 0.75, 45)]
        for i, (fx, fz, ang) in enumerate(spots):
            for glazed in (False, True):
                y = bt + (0.26 if glazed else 0.13)
                out.append(B((bc[0] + fx * bh[0], y, bc[2] + fz * bh[2]), (0.24, 0.07, 0.08), colors[i % 4], "Sprinkle", r=(0, ang, 0), mat="Neon",
                             only="GlazeDrip" if glazed else None, unless=None if glazed else "GlazeDrip"))
    elif name == "DonutRing":
        y = bc[1] - 0.08
        for (w, h, col, dy) in ((0.4, 0.36, "#dea55f", 0), (0.36, 0.14, "#ff82be", 0.2)):
            out.append(B((0, y + dy, bc[2] - bh[2] - w / 2), (2 * bh[0] + 2 * w, h, w), col, "Ring"))
            out.append(B((0, y + dy, bc[2] + bh[2] + w / 2), (2 * bh[0] + 2 * w, h, w), col, "Ring"))
            for s in sides:
                out.append(B((s * (bh[0] + w / 2), y + dy, bc[2]), (w, h, 2 * bh[2]), col, "Ring"))
    elif name == "Scarf":
        y = hc[1] - hh[1] + 0.06
        red = "#e6323c"
        out.append(B((0, y, hf - 0.07), (2 * hh[0] + 0.24, 0.26, 0.14), red, "Scarf", mat="Fabric"))
        out.append(B((0, y, hc[2] + hh[2] + 0.07), (2 * hh[0] + 0.24, 0.26, 0.14), red, "Scarf", mat="Fabric"))
        for s in sides:
            out.append(B((s * (hh[0] + 0.07), y, hc[2]), (0.14, 0.26, 2 * hh[2] + 0.24), red, "Scarf", mat="Fabric"))
        out.append(B((0.36, y - 0.32, hf - 0.09), (0.26, 0.6, 0.1), red, "Scarf", r=(0, 0, 12), mat="Fabric"))
    elif name == "Leaf":
        out.append(B((0, ht + 0.15, hc[2]), (0.08, 0.3, 0.08), "#644628", "Stem"))
        out.append(B((0.3, ht + 0.32, hc[2]), (0.8, 0.07, 0.4), "#5ac846", "Leaf", r=(0, 20, 15)))
    elif name == "Fluff":
        for fx, fz in ((-0.55, -0.55), (0.55, -0.55), (0, -0.2), (-0.55, 0.2), (0.55, 0.2), (0, 0.55), (-0.5, 0.75), (0.5, 0.75)):
            out.append(B((bc[0] + fx * bh[0], bt + 0.08, bc[2] + fz * bh[2]), (0.6, 0.4, 0.6), "Pale", "Wool", studs=True))
        for i in (-1, 0, 1):
            out.append(B((i * 0.24, ht + 0.1, hc[2] + 0.05), (0.34, 0.3, 0.34), "Pale", "Wool", studs=True))
    elif name == "Bow":
        p = (hh[0] * 0.5, ht + 0.06, hc[2] - 0.1)
        for s in sides:
            out.append(B(add(p, (s * 0.2, 0.05, 0)), (0.36, 0.3, 0.12), "Accent", "Bow", r=(0, 0, s * 20)))
        out.append(B(add(p, (0, 0.05, -0.02)), (0.16, 0.16, 0.16), "Accent", "Bow"))
    elif name == "Spout":
        out.append(B((0, bt + 0.12, bc[2] - 0.4), (0.28, 0.24, 0.28), "Accent", "Spout", mat="Neon"))
    elif name == "Crown":
        y = ht + 0.13
        for z in (-0.42, 0.42):
            out.append(B((0, y, hc[2] + z), (0.94, 0.28, 0.1), GOLD, "Crown", mat="Foil"))
        for s in sides:
            out.append(B((s * 0.42, y, hc[2]), (0.1, 0.28, 0.84), GOLD, "Crown", mat="Foil"))
            for z in (-0.42, 0.42):
                out.append(B((s * 0.42, y + 0.24, hc[2] + z), (0.14, 0.22, 0.14), GOLD, "Crown", mat="Foil"))
        out.append(B((0, y + 0.24, hc[2] - 0.42), (0.14, 0.22, 0.14), GOLD, "Crown", mat="Foil"))
        out.append(B((0, y + 0.02, hc[2] - 0.48), (0.16, 0.16, 0.04), "#ff2846", "Gem", mat="Neon"))
    elif name == "Halo":
        for crowned in (False, True):
            y = ht + (0.95 if crowned else 0.55)
            o = dict(only="Crown") if crowned else dict(unless="Crown")
            for z in (-0.38, 0.38):
                out.append(B((0, y, hc[2] + z), (0.84, 0.07, 0.08), "#fff096", "Halo", mat="Neon", **o))
            for s in sides:
                out.append(B((s * 0.38, y, hc[2]), (0.08, 0.07, 0.84), "#fff096", "Halo", mat="Neon", **o))
    elif name == "Shell":
        out.append(B((bc[0], bt + 0.12, bc[2]), (2 * bh[0] * 0.96, 0.42, 2 * bh[2] * 0.96), "Accent", "Shell", mat="Slate", studs=True))
        out.append(B((bc[0], bt + 0.42, bc[2]), (2 * bh[0] * 0.66, 0.2, 2 * bh[2] * 0.66), "Accent", "Shell", mat="Slate"))
        for fx, fz in ((-0.5, -0.5), (0.5, -0.5), (-0.5, 0.5), (0.5, 0.5)):
            out.append(B((bc[0] + fx * bh[0], bt + 0.34, bc[2] + fz * bh[2]), (0.4, 0.04, 0.4), "ShellPlate", "Plate", mat="Slate"))
    elif name == "Ghost":
        n = 8
        for i in range(n):
            t = i / n
            # around the bottom edge, every other one a little lower: a wavy hem
            if t < 0.25:
                x, z = -bh[0] + 8 * t * bh[0], -bh[2]
            elif t < 0.5:
                x, z = bh[0], -bh[2] + 8 * (t - 0.25) * bh[2]
            elif t < 0.75:
                x, z = bh[0] - 8 * (t - 0.5) * bh[0], bh[2]
            else:
                x, z = -bh[0], bh[2] - 8 * (t - 0.75) * bh[2]
            out.append(B((x * 0.82, bc[1] - bh[1] - (0.16 if i % 2 == 0 else 0.06), z * 0.82), (0.42, 0.3, 0.42), "Body", "Body"))
    elif name == "GlazeDrip":
        glaze = "#ff96c8"
        out.append(B((bc[0], bt + 0.11, bc[2]), (2 * bh[0] + 0.08, 0.24, 2 * bh[2] + 0.08), glaze, "Glaze"))
        for (x, z) in ((bh[0] + 0.03, -0.35), (-bh[0] - 0.03, 0.25), (bh[0] + 0.03, 0.55)):
            out.append(B((x, bt - 0.12, bc[2] + z * bh[2]), (0.1, 0.4, 0.22), glaze, "Glaze"))
        out.append(B((0.2, bt - 0.1, bc[2] - bh[2] - 0.03), (0.22, 0.36, 0.1), glaze, "Glaze"))
    elif name in ("ChocoDrizzle", "NeonStripes"):
        for i in (-1, 0, 1):
            z = bc[2] + i * bh[2] * 0.5
            if name == "ChocoDrizzle":
                col, mat = "#46281a", "Smooth"
            else:
                col, mat = ("#ff00c8" if i == 0 else "#00ffe6"), "Neon"
            out.append(B((0, bt + 0.12, z), (2 * bh[0] + 0.04, 0.05, 0.1), col, "Stripe", mat=mat))
            for s in sides:
                out.append(B((s * (bh[0] + 0.02), bt - 0.2, z), (0.05, 0.62, 0.1), col, "Stripe", mat=mat))
    elif name == "JesterHat":
        purple, yellow = "#c828c8", "#ffc828"
        out.append(B((0, ht + 0.14, hc[2]), (1.02, 0.28, 0.92), purple, "Hat"))
        for s, col in ((-1, purple), (1, yellow)):
            tip = (s * 0.72, ht + 0.7, hc[2])
            out.append(R((s * 0.15, ht + 0.2, hc[2]), tip, 0.3, col, "Hat"))
            out.append(B(add(tip, (s * 0.06, -0.08, 0)), (0.2, 0.2, 0.2), GOLD, "Bell", mat="Foil"))
    elif name == "TikiMask":
        wood = "#966438"
        tilt = (-20, 0, 0)
        out.append(B((0, ht + 0.02, hf + 0.2), (0.74, 0.6, 0.12), wood, "Mask", r=tilt, mat="Wood"))
        for s in sides:
            out.append(B((s * 0.17, ht + 0.1, hf + 0.13), (0.16, 0.1, 0.04), "#ffdc5a", "Mask", r=tilt, mat="Neon"))
        out.append(B((0, ht - 0.1, hf + 0.2), (0.38, 0.08, 0.04), "#3c2314", "Mask", r=tilt))
        for i in (-1, 0, 1):
            out.append(B((i * 0.2, ht + 0.42, hf + 0.32), (0.14, 0.44, 0.06), "#5ac846", "Leaf", r=(0, 0, -i * 25)))
    elif name == "Pixels":
        colors = ["#ff3cc8", "#3ce6ff", "#ffe63c"]
        spots = [(-bh[0], 0.2, -0.3), (bh[0], -0.1, 0.4), (0.35, 1, -0.4), (-0.4, 1, 0.5), (-bh[0], -0.3, 0.6), (bh[0], 0.3, -0.5)]
        for i, (x, y, z) in enumerate(spots):
            px = x if abs(x) == bh[0] else x * bh[0]
            py = bt + 0.02 if y == 1 else bc[1] + y * bh[1]
            out.append(B((px, py, bc[2] + z * bh[2]), (0.22, 0.22, 0.22), colors[i % 3], "Pixel", mat="Neon"))
        out.append(B((0, ey, an["face_z"] - 0.07), (2 * dx + 0.5, 0.2, 0.06), INK, "Shades"))
    elif name == "Rotors":
        for s in sides:
            hub = (s * 0.75, ht + 0.4, hc[2] + 0.05)
            out.append(R((s * 0.1, ht, hc[2] + 0.05), hub, 0.1, "#50505a", "Arm", mat="Metal"))
            out.append(B(hub, (0.16, 0.14, 0.16), "#3c3c46", "Hub", mat="Metal"))
            out.append(B(add(hub, (0, 0.1, 0)), (1.0, 0.04, 0.16), "#3cc8ff", "Rotor", mat="Neon", limb=("Spin", s, hub)))
    elif name == "MetalPlates":
        metal = "#aaafb9"
        for s in sides:
            out.append(B((s * (bh[0] + 0.03), bc[1] + 0.1, bc[2]), (0.05, 0.46, 0.62), metal, "Plate", mat="Metal"))
            out.append(B((s * (bh[0] + 0.06), bc[1] + 0.26, bc[2] + 0.2), (0.04, 0.08, 0.08), "#646470", "Rivet", mat="Metal"))
        out.append(B((0, bt + 0.13, bc[2] + 0.3), (0.62, 0.05, 0.5), metal, "Plate", mat="Metal"))
        out.append(B((0, ey, an["face_z"] - 0.07), (2 * dx + 0.5, 0.18, 0.06), "#00ffdc", "Visor", mat="Neon"))
    elif name == "CrateBox":
        out.append(B((0, bt + 0.4, bc[2] + 0.15), (0.75, 0.6, 0.65), "#aa6e37", "Crate", r=(0, 17, 0), mat="WoodPlanks"))
        out.append(B((0, bt + 0.5, bc[2] + 0.15), (0.78, 0.1, 0.68), GOLD, "Crate", r=(0, 17, 0), mat="Foil"))
        out.append(B((0, bt + 0.8, bc[2] + 0.15), (0.18, 0.18, 0.18), "#ffe678", "Gem", mat="Neon"))
    elif name == "Beak":
        out.append(B((0, ey - 0.26, hf - 0.12), (0.46, 0.22, 0.3), ORANGE, "Beak", r=(-10, 0, 0)))
        out.append(B((0, ey - 0.39, hf - 0.08), (0.36, 0.12, 0.22), "#e6821e", "Beak"))
    return out


FEATURES = ["PointyEars", "FloppyEars", "LongEars", "RoundEars", "Horns", "Tufts", "Wings", "Antenna", "Belly", "Horn", "Crest", "Mane",
            "Tail", "BigTail", "PuffTail", "Spikes", "Tentacles", "Sprinkles", "DonutRing", "Scarf", "Leaf", "Fluff", "Bow", "Spout",
            "Crown", "Halo", "Shell", "Ghost", "GlazeDrip", "ChocoDrizzle", "NeonStripes", "JesterHat", "TikiMask", "Pixels", "Rotors",
            "MetalPlates", "CrateBox", "Beak"]
# (Glow, Stars, Flames, Rainbow, Glitch, Claws: effects and colours the game adds itself)


# ---- the game's pets ------------------------------------------------------------------------
def read_pets():
    text = open(os.path.join(REPO, "src", "shared", "Pets.luau")).read()
    pets = []
    for line in text.splitlines():
        m = re.search(r'\{ Id = "(\w+)", Name = "([^"]+)", Rarity = "(\w+)".*?Shape = "(\w+)", Body = rgb\((\d+), (\d+), (\d+)\), Accent = rgb\((\d+), (\d+), (\d+)\), Features = \{([^}]*)\}(.*)\}', line)
        if not m:
            continue
        g = m.groups()
        scale = re.search(r"Scale = ([\d.]+)", g[11])
        pets.append(dict(id=g[0], name=g[1], rarity=g[2], shape=g[3], body=tuple(int(v) for v in g[4:7]), accent=tuple(int(v) for v in g[7:10]),
                         features=re.findall(r'"(\w+)"', g[10]), scale=float(scale.group(1)) if scale else 1.0))
    return pets


def blocks_for(pet):
    blocks, an = SHAPES[pet["shape"]]()
    for f in pet["features"]:
        if f in FEATURES:
            blocks += feature(f, pet["shape"], an)
    has = set(pet["features"])
    return [b for b in blocks if (b["only"] is None or b["only"] in has) and (b["unless"] is None or b["unless"] not in has)]


# ---- studs (the game adds them the same way: PetModel) ------------------------------------------
def unrotated(b):
    return b["kind"] == "box" and b["r"] == (0, 0, 0)


def inside(p, b, pad=0.0):
    return all(abs(p[i] - b["c"][i]) < b["s"][i] / 2 + pad for i in range(3))


def studs_for(blocks):
    out = []
    for b in blocks:
        if not (b["studs"] and unrotated(b)):
            continue
        (cx, cy, cz), (w, h, d) = b["c"], b["s"]
        nx, nz = max(1, int((w + 1e-6) // PITCH)), max(1, int((d + 1e-6) // PITCH))
        for i in range(nx):
            for j in range(nz):
                p = (cx - (nx - 1) * PITCH / 2 + i * PITCH, cy + h / 2 + STUD_H / 2, cz - (nz - 1) * PITCH / 2 + j * PITCH)
                if any(o is not b and o["kind"] == "box" and unrotated(o) and o["alpha"] < 1 and inside(p, o, 0.02) for o in blocks):
                    continue  # (hidden under something else)
                out.append((b, p))
    return out


# ---- export to the game ---------------------------------------------------------------------------
def lua_v3(v):
    return "Vector3.new(%s, %s, %s)" % tuple(("%.3f" % x).rstrip("0").rstrip(".").replace("-0", "0") if abs(x) < 5e-4 else ("%.3f" % x).rstrip("0").rstrip(".") for x in v)


def lua_color(c):
    if c.startswith("#"):
        return "Color3.fromRGB(%d, %d, %d)" % (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16))
    return '"%s"' % c


def lua_block(b):
    fields = ['Name = "%s"' % b["name"]]
    if b["kind"] == "rod":
        fields += ["From = " + lua_v3(b["a"]), "To = " + lua_v3(b["b"]), "Thick = %g" % b["t"]]
    else:
        fields += ["Pos = " + lua_v3(b["c"]), "Size = " + lua_v3(b["s"])]
        if b["r"] != (0, 0, 0):
            fields.append("Rot = " + lua_v3(b["r"]))
    fields.append("Color = " + lua_color(b["col"]))
    if b["mat"] != "Smooth":
        fields.append('Material = "%s"' % b["mat"])
    if b["studs"]:
        fields.append("Studs = true")
    if b["limb"]:
        kind, side, pivot = b["limb"]
        fields.append('Limb = { Kind = "%s", Side = %d, Pivot = %s }' % (kind, side, lua_v3(pivot)))
    if b["eye"]:
        fields.append("Eye = true")
    if b["pupil"]:
        fields.append("Pupil = true")
    if b["alpha"]:
        fields.append("Transparency = %g" % b["alpha"])
    if b["only"]:
        fields.append('Only = "%s"' % b["only"])
    if b["unless"]:
        fields.append('Unless = "%s"' % b["unless"])
    return "{ " + ", ".join(fields) + " }"


def export(path):
    lines = [
        "--[[",
        "\tPetBlocks: what every pet is made of - GENERATED by art/studded_pets/studded_pets.py (a Blender",
        "\tscript that also renders them all). Don't edit this file: change the pets there and run it again.",
        "",
        "\tShapes[body plan] = { Blocks, Anchors }; Features[feature][body plan] = blocks. A block is a box",
        "\t(Pos, Size, Rot in degrees like CFrame.Angles) or a rod (From, To, Thick). Color: a colour, or a",
        "\trole PetModel fills in from the pet (Body, Accent, Pale, Shade, AccentLight, Snout, ShellPlate).",
        "\tStuds: studs on its top (every StudPitch). Limb: the client swings it. Eye / Pupil: blinking.",
        "\tOnly / Unless: a feature the pet must / mustn't have for this block.",
        "]]",
        "",
        "export type Block = {",
        "\tName: string,",
        "\tPos: Vector3?,",
        "\tSize: Vector3?,",
        "\tRot: Vector3?,",
        "\tFrom: Vector3?,",
        "\tTo: Vector3?,",
        "\tThick: number?,",
        "\tColor: Color3 | string,",
        "\tMaterial: string?,",
        "\tStuds: boolean?,",
        "\tLimb: { Kind: string, Side: number, Pivot: Vector3 }?,",
        "\tEye: boolean?,",
        "\tPupil: boolean?,",
        "\tTransparency: number?,",
        "\tOnly: string?,",
        "\tUnless: string?,",
        "}",
        "",
        "local PetBlocks = {}",
        "",
        "PetBlocks.StudPitch = %g" % PITCH,
        "PetBlocks.StudSize = Vector3.new(%g, %g, %g) -- (a cylinder lying along X: height, diameter, diameter)" % (STUD_H, STUD_D, STUD_D),
        "",
        "local Shapes: { [string]: { Blocks: { Block } } } = {",
    ]
    for shape, fn in SHAPES.items():
        blocks, an = fn()
        lines.append("\t%s = {" % shape)
        lines.append("\t\tBlocks = {")
        lines += ["\t\t\t" + lua_block(b) + "," for b in blocks]
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    lines.append("PetBlocks.Shapes = Shapes")
    lines.append("")
    lines.append("local Features: { [string]: { [string]: { Block } } } = {")
    for f in FEATURES:
        lines.append("\t%s = {" % f)
        for shape, fn in SHAPES.items():
            _, an = fn()
            blocks = feature(f, shape, an)
            if blocks:
                lines.append("\t\t%s = {" % shape)
                lines += ["\t\t\t" + lua_block(b) + "," for b in blocks]
                lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    lines.append("PetBlocks.Features = Features")
    lines.append("")
    lines.append("return PetBlocks")
    open(path, "w").write("\n".join(lines) + "\n")
    print("exported", path)


# ---- render ----------------------------------------------------------------------------------------
def render(out, pets):
    import bpy, bmesh
    from mathutils import Matrix, Vector

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    P = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # game (y up, -z front) -> Blender (z up)

    def lin(c):
        return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92

    mats = {}

    def material(rgb, mat, alpha):
        key = (rgb, mat, alpha)
        if key in mats:
            return mats[key]
        m = bpy.data.materials.new("M%d" % len(mats))
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        color = (*[lin(v / 255) for v in rgb], 1)
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.42
        if mat == "Neon":
            bsdf.inputs["Emission Color"].default_value = color
            bsdf.inputs["Emission Strength"].default_value = 2.2
        elif mat in ("Foil", "Metal"):
            bsdf.inputs["Metallic"].default_value = 0.85
            bsdf.inputs["Roughness"].default_value = 0.25
        elif mat in ("Wood", "WoodPlanks", "Slate", "Fabric"):
            bsdf.inputs["Roughness"].default_value = 0.8
        if alpha:
            bsdf.inputs["Alpha"].default_value = 1 - alpha
        mats[key] = m
        return m

    def mix(a, b, t):
        return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

    def resolve(pet, col):
        body, accent = pet["body"], pet["accent"]
        roles = dict(Body=body, Accent=accent, Pale=mix(body, (255, 255, 255), 0.5), Shade=mix(body, (20, 20, 25), 0.25),
                     AccentLight=mix(accent, (255, 255, 255), 0.35), Snout=mix(body, accent, 0.3), ShellPlate=mix(accent, (20, 20, 25), 0.25))
        if col.startswith("#"):
            return (int(col[1:3], 16), int(col[3:5], 16), int(col[5:7], 16))
        return roles[col]

    def rot(r):
        rx, ry, rz = (math.radians(a) for a in r)
        return (Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rz, 4, "Z"))

    cols = 9
    gap_x, gap_z = 4.6, 5.2
    for index, pet in enumerate(pets):
        blocks = blocks_for(pet)
        has = set(pet["features"])
        glow = "Glow" in has
        ghost = "Ghost" in has
        k = pet["scale"]
        ox = -(index % cols - (cols - 1) / 2) * gap_x  # (the camera looks back along -Y: first pet on the left)
        oy = -(index // cols) * gap_z
        place = Matrix.Translation((ox, oy, 0)) @ Matrix.Scale(k, 4)  # (in game units, y up; then P)
        bm = bmesh.new()
        slots = []

        def slot_of(m):
            if m not in slots:
                slots.append(m)
            return slots.index(m)

        def add_box(matrix, m):
            geom = bmesh.ops.create_cube(bm, size=1.0, matrix=P @ place @ matrix)
            idx = slot_of(m)
            for f in {f for v in geom["verts"] for f in v.link_faces}:
                f.material_index = idx

        def add_stud(pos, m):
            matrix = P @ place @ Matrix.Translation(pos)
            geom = bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=STUD_D / 2, radius2=STUD_D / 2, depth=STUD_H,
                                         matrix=matrix @ Matrix.Rotation(math.radians(-90), 4, "X"))
            idx = slot_of(m)
            for f in {f for v in geom["verts"] for f in v.link_faces}:
                f.material_index = idx

        def mat_of(b):
            mat = b["mat"]
            if mat == "Glow":
                mat = "Neon" if glow else "Smooth"
            alpha = b["alpha"] or (0.25 if ghost and b["name"] == "Body" else 0)
            return material(resolve(pet, b["col"]), mat, alpha)

        for b in blocks:
            if b["kind"] == "rod":
                a, c = Vector(b["a"]), Vector(b["b"])
                d = c - a
                z = -d.normalized()
                up = Vector((1, 0, 0)) if abs(z.y) > 0.95 else Vector((0, 1, 0))
                x = up.cross(z).normalized()
                y = z.cross(x)
                m3 = Matrix((x, y, z)).transposed().to_4x4()
                matrix = Matrix.Translation((a + c) / 2) @ m3 @ Matrix.Diagonal((b["t"], b["t"], d.length + b["t"] * 0.3, 1))
            else:
                matrix = Matrix.Translation(b["c"]) @ rot(b["r"]) @ Matrix.Diagonal((*b["s"], 1))
            add_box(matrix, mat_of(b))
        for b, p in studs_for(blocks):
            add_stud(p, mat_of(b))
        mesh = bpy.data.meshes.new(pet["id"])
        bm.to_mesh(mesh)
        bm.free()
        for m in slots:
            mesh.materials.append(m)
        obj = bpy.data.objects.new(pet["id"], mesh)
        scene.collection.objects.link(obj)
        # its name under it
        bpy.ops.object.text_add(location=(ox, 0, oy - 1.95))
        label = bpy.context.object
        label.data.body = pet["name"]
        label.data.align_x = "CENTER"
        label.data.size = 0.42
        label.rotation_euler = (math.radians(90), 0, math.radians(180))
        label.data.materials.append(material((240, 240, 245), "Neon", 0))

    rows = (len(pets) + cols - 1) // cols
    # light and camera (from the front, a little to the side and above: Blender -Y is the pets' back)
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.2
    sun_obj = bpy.data.objects.new("Sun", sun)
    sun_obj.rotation_euler = (math.radians(55), math.radians(-20), math.radians(155))
    scene.collection.objects.link(sun_obj)
    fill = bpy.data.lights.new("Fill", "SUN")
    fill.energy = 1.0
    fill_obj = bpy.data.objects.new("Fill", fill)
    fill_obj.rotation_euler = (math.radians(70), 0, math.radians(-150))
    scene.collection.objects.link(fill_obj)
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.36, 0.42, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    width = cols * gap_x + 1.5
    height = rows * gap_z + 1.0
    cam_data.ortho_scale = max(width, height * 2400 / 1500)
    cam = bpy.data.objects.new("Cam", cam_data)
    center_z = -(rows - 1) * gap_z / 2 + 0.2
    cam.location = (-6.0, 40.0, center_z + 11.0)
    direction = Vector((0, 0, center_z)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 40
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 2400
    scene.render.resolution_y = 1500
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.render.filepath = out
    if out.lower().endswith((".jpg", ".jpeg")):
        scene.render.image_settings.file_format = "JPEG"
        scene.render.image_settings.quality = 90
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "studded_pets.blend"))
    print("rendered", out)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "-"
    export_path = sys.argv[2] if len(sys.argv) > 2 else None
    only = sys.argv[3].split(",") if len(sys.argv) > 3 else None
    pets = read_pets()
    if only:
        pets = [p for p in pets if p["id"] in only]
    print(len(pets), "pets")
    if export_path:
        export(export_path)
    if out != "-":
        render(out, pets)
