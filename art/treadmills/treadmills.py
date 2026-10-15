# Treadmills: every treadmill in the game (all 16 tiers), designed here and rendered in Blender.
#
#   python3 treadmills.py <sheet.png | closeups-folder/ | -> [export.luau] [names, comma separated]
#   e.g. python3 treadmills.py renders/ ../../src/shared/TreadmillModels.luau   (renders/sheet.png: preview.jpg)
#   (VFX=0: without the effects; RENDER=0 with a sheet name: just save treadmills.blend)
#
# Each treadmill is built from the same kinds of pieces Roblox parts are (blocks, cylinders, balls
# and wedges), so the export IS the model: src/shared/TreadmillModels.luau is written from here,
# and TreadmillService builds every treadmill in the game from that file (no meshes to upload).
# To change a treadmill: change it here and run this again. The render lays all of them out on a
# sheet with their names, the way the game builds them.
# Needs Blender's Python module (pip install bpy).
#
# Treadmill space (studs): x across the belt, y up (0 = the ground), z along the belt; the console
# is at the front (-z), the runner faces it, and steps on and off at the back (+z). The belt is
# always 6 x 13 studs, its top at y = 1.5, centred on z = 0.5 (the game finds it by name: "Belt").
import math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ORDER = ["Rusty", "Basic", "Sporty", "Pro", "Turbo", "Neon", "Thunder", "Diamond",
         "Magma", "Plasma", "Quantum", "Cosmic", "Void", "Dragon", "Supernova", "Heavenly"]


# ---- a tiny CFrame -----------------------------------------------------------------------------
def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def mat_vec(a, v):
    return tuple(sum(a[i][k] * v[k] for k in range(3)) for i in range(3))


def rot_x(d):
    c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def rot_y(d):
    c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rot_z(d):
    c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


IDENTITY = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


class CF:
    def __init__(self, pos=(0, 0, 0), R=None):
        self.p = tuple(float(x) for x in pos)
        self.R = R or IDENTITY

    @staticmethod
    def angles(rx=0, ry=0, rz=0, pos=(0, 0, 0)):
        # like Roblox's CFrame.Angles: X, then Y, then Z (R = Rx * Ry * Rz)
        return CF(pos, mat_mul(mat_mul(rot_x(rx), rot_y(ry)), rot_z(rz)))

    def __mul__(self, other):
        if isinstance(other, CF):
            p = mat_vec(self.R, other.p)
            return CF((self.p[0] + p[0], self.p[1] + p[1], self.p[2] + p[2]), mat_mul(self.R, other.R))
        p = mat_vec(self.R, other)
        return (self.p[0] + p[0], self.p[1] + p[1], self.p[2] + p[2])

    def euler(self):
        R = self.R
        ry = math.asin(max(-1.0, min(1.0, R[0][2])))
        if abs(R[0][2]) < 0.99999:
            rx = math.atan2(-R[1][2], R[2][2])
            rz = math.atan2(-R[0][1], R[0][0])
        else:
            rx = math.atan2(R[2][1], R[1][1])
            rz = 0.0
        return tuple(math.degrees(a) for a in (rx, ry, rz))


def T(x, y, z):
    return CF((x, y, z))


def along(a, b):
    # a frame at the middle of a -> b whose Z axis runs along it
    d = [b[i] - a[i] for i in range(3)]
    length = math.sqrt(sum(x * x for x in d))
    z = [-x / length for x in d]  # (Roblox's look is -Z; either way a box is symmetric)
    up = [0, 1, 0] if abs(z[1]) < 0.95 else [1, 0, 0]
    x = [up[1] * z[2] - up[2] * z[1], up[2] * z[0] - up[0] * z[2], up[0] * z[1] - up[1] * z[0]]
    n = math.sqrt(sum(v * v for v in x))
    x = [v / n for v in x]
    y = [z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0]]
    R = [[x[0], y[0], z[0]], [x[1], y[1], z[1]], [x[2], y[2], z[2]]]
    mid = tuple((a[i] + b[i]) / 2 for i in range(3))
    return CF(mid, R), length


# ---- parts -------------------------------------------------------------------------------------
class Model:
    def __init__(self, name):
        self.name = name
        self.parts = []
        self.groups = {}
        self.effects = []  # effects (particles, beams, lights, pulses): see vfx()
        self.group = None  # parts added now go in this spinning group
        self.frame = CF()  # ...and are placed in this frame

    def add(self, shape, cf, size, col, mat="SmoothPlastic", alpha=0, name=None, collide=False, tag=None, index=None, refl=0):
        cf = self.frame * cf
        self.parts.append(dict(shape=shape, cf=cf, size=tuple(size), col=tuple(int(c) for c in col), mat=mat, alpha=alpha,
                               name=name, collide=collide, tag=tag, index=index, group=self.group, refl=refl))
        return self.parts[-1]

    def box(self, c, s, col, mat="SmoothPlastic", r=(0, 0, 0), **kw):
        cf = c if isinstance(c, CF) else CF.angles(*r, pos=c)
        return self.add("Block", cf, s, col, mat, **kw)

    def wedge(self, c, s, col, mat="SmoothPlastic", r=(0, 0, 0), **kw):
        # a Roblox wedge: tall at its back (+z), sloping down to its front (-z)
        cf = c if isinstance(c, CF) else CF.angles(*r, pos=c)
        return self.add("Wedge", cf, s, col, mat, **kw)

    def ball(self, c, d, col, mat="SmoothPlastic", **kw):
        return self.add("Ball", CF(c), (d, d, d), col, mat, **kw)

    def cyl(self, c, length, d, col, mat="SmoothPlastic", axis="x", r=None, **kw):
        # a Roblox cylinder runs along its X; axis "y" / "z" turns it
        if isinstance(c, CF):
            cf = c
        else:
            base = {"x": CF(), "y": CF.angles(0, 0, 90), "z": CF.angles(0, 90, 0)}[axis]
            cf = (CF.angles(*r, pos=c) if r else CF(c)) * base
        return self.add("Cylinder", cf, (length, d, d), col, mat, **kw)

    def rod(self, a, b, t, col, mat="SmoothPlastic", round_=False, **kw):
        cf, length = along(a, b)
        if round_:
            return self.add("Cylinder", cf * CF.angles(0, 90, 0), (length, t, t), col, mat, **kw)
        return self.add("Block", cf, (t, t, length), col, mat, **kw)

    def tri(self, a, b, c, thick, col, mat="SmoothPlastic", **kw):
        # a flat triangle a-b-c: two wedges (how Roblox games draw triangles)
        def sub(u, v): return [u[i] - v[i] for i in range(3)]
        def dot(u, v): return sum(u[i] * v[i] for i in range(3))
        def cross(u, v): return [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
        def unit(u):
            n = math.sqrt(dot(u, u))
            return [x / n for x in u]
        ab, ac, bc = sub(b, a), sub(c, a), sub(c, b)
        abd, acd, bcd = dot(ab, ab), dot(ac, ac), dot(bc, bc)
        if abd > acd and abd > bcd:
            c, a = a, c
        elif acd > bcd and acd > abd:
            a, b = b, a
        ab, ac, bc = sub(b, a), sub(c, a), sub(c, b)
        right = unit(cross(ac, ab))
        up = unit(cross(bc, right))
        back = unit(bc)
        h = abs(dot(ab, up))
        for (p, q, sgn) in ((a, b, 1), (a, c, -1)):
            R = [[right[i] * sgn, up[i], back[i] * sgn] for i in range(3)]
            mid = tuple((p[i] + q[i]) / 2 for i in range(3))
            d = abs(dot(sub(q, p), back))
            if h > 1e-3 and d > 1e-3:
                self.add("Wedge", CF(mid, R), (thick, h, d), col, mat, **kw)

    def ring(self, center_cf, radius, count, d, col, mat="Neon", **kw):
        # balls round a circle in center_cf's XZ plane
        for i in range(count):
            a = i / count * math.pi * 2
            self.add("Ball", center_cf * CF((math.cos(a) * radius, 0, math.sin(a) * radius)), (d, d, d), col, mat, **kw)

    def spin(self, name, pivot, axis="Y", idle=0.5, run=2.0, mode="Spin", amp=0, dir=1):
        # a group of parts the client moves round `pivot`'s axis: Spin turns (idle / run: radians a
        # second), Swing rocks to and fro (amp degrees; idle / run: how fast), Wobble rattles
        self.groups[name] = dict(pivot=pivot, axis=axis, idle=idle, run=run, mode=mode, amp=amp, dir=dir)
        self.group = name

    def join(self, name):
        self.group = name  # (add more parts to a group made earlier)

    def done(self):
        self.group = None

    # ---- effects. idle / run: how strong standing still and while the owner runs (0 = off) ----
    def vfx(self, kind, **kw):
        kw["kind"] = kind
        if "group" not in kw:
            kw["group"] = self.group
        self.effects.append(kw)
        return kw

    def emit(self, preset, pos, area=(1, 1, 1), colors=((255, 255, 255),), size=1.0, idle=0.0, run=0.0, dir="Top",
             shape="Box", every=None, every_idle=None, boost=False):
        # particles (a preset: TreadmillFX.Presets in the game) from a box (or sphere) `area` at `pos`
        return self.vfx("Emit", preset=preset, pos=tuple(pos), area=tuple(area), colors=[tuple(int(x) for x in c) for c in colors],
                        size=size, idle=idle, run=run, dir=dir, shape=shape, every=every, every_idle=every_idle, boost=boost)

    def beam(self, a, b, colors, width=0.3, width1=None, style="Ray", alpha=0.0, every=None):
        # Ray: a soft shaft of light; Arc: crackling electricity; Strike: a lightning bolt now and then
        return self.vfx("Beam", a=tuple(a), b=tuple(b), colors=[tuple(int(x) for x in c) for c in colors], width=width,
                        width1=width if width1 is None else width1, style=style, alpha=alpha, every=every)

    def light(self, pos, col, rng=12, idle=1.0, run=None, flicker=False, spot=False, angle=45):
        return self.vfx("Light", pos=tuple(pos), col=tuple(int(x) for x in col), range=rng, idle=idle, run=idle if run is None else run,
                        flicker=flicker, spot=spot, angle=angle)

    def pulse(self, pos, col, radius=8, idle=2.0, run=0.8, phase=0.0):
        # a ring of light spreading out over the ground and fading (idle / run: seconds each; 0 = off)
        return self.vfx("Pulse", pos=tuple(pos), col=tuple(int(x) for x in col), radius=radius, idle=idle, run=run, phase=phase)

    def fire(self, pos, col, idle=2.0, run=None):
        return self.vfx("Fire", pos=tuple(pos), col=tuple(int(x) for x in col), idle=idle, run=idle if run is None else run)

    def sparkles(self, pos, col):
        return self.vfx("Sparkles", pos=tuple(pos), col=tuple(int(x) for x in col))


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def dark(c, t=0.35):
    return mix(c, (10, 10, 14), t)


def light(c, t=0.35):
    return mix(c, (255, 255, 255), t)


BLACK = (24, 24, 28)
RUBBER = (34, 34, 38)
WHITE = (245, 245, 245)
CHROME = (205, 210, 220)
GOLD = (255, 200, 60)

# The console sits on the uprights, tilted back towards the runner: its frame's +z face is the
# screen side.
CONSOLE = CF((0, 6.35, -6.9)) * CF.angles(-25, 0, 0)


# ---- the chassis every treadmill shares (dressed by its theme) ---------------------------------
def chassis(m, t):
    fr, frm = t["frame"]
    sd, sdm = t.get("side", t["frame"])
    st, stm = t["step"]
    hd, hdm = t.get("hood", t["frame"])
    tr, trm = t.get("trim", (CHROME, "Metal"))
    ac = t["accent"]
    glow = t.get("glow", True)
    leds = t.get("leds", "on")  # on: glowing strips that chase; dead: plain dull bulbs
    # what you stand on and bump into: one smooth invisible deck (nothing to snag on)
    m.box((0, 0.75, 0.5), (8, 1.5, 15.4), (128, 128, 128), alpha=1, name="Base", collide=True)
    m.box((0, 1.35, 0.5), (6, 0.3, 13), t.get("belt", RUBBER), "Rubber", name="Belt", collide=True, tag="Belt")
    for i in range(6):
        m.box((0, 1.53, 0.5 - 6.5 + i * 13 / 6), (5.8, 0.06, 0.35), t.get("slat", (85, 85, 95)), name="Slat", tag="Slat", index=i)
    # under-tray and deck sides
    m.box((0, 0.42, 0.5), (6.4, 0.3, 14.2), dark(fr, 0.5), frm)
    for side in (-1, 1):
        x = side * 3.6
        m.box((x, 0.92, 0.5), (1.2, 1.3, 14.8), sd, sdm, name="DeckSide")
        m.box((x, 1.62, 0.6), (1.04, 0.14, 13.4), st, stm, name="Step")
        m.box((side * 4.22, 0.92, 0.5), (0.06, 0.5, 13.8), ac if glow else dark(tr, 0.2), "Neon" if glow else trm, name="SideLine")
        # trim along the deck's top outer edge
        m.box((side * 4.16, 1.6, 0.5), (0.16, 0.16, 14.8), tr, trm)
        for k in range(10):
            z = -5.0 + k * (12.2 / 9)
            if leds == "on":
                m.box((side * 3.16, 1.7, z), (0.16, 0.06, 0.85), t.get("led", ac), "Neon", name="LED", tag="LED", index=k)
            elif k % 3 != 2:  # (dead ones: dull, and some missing)
                m.box((side * 3.16, 1.68, z), (0.16, 0.05, 0.85), t.get("led", (70, 70, 68)), "SmoothPlastic", name="DeadLED")
        # bolts down each side
        for k in range(5):
            m.ball((side * 4.21, 1.25, -5.2 + k * 2.9), 0.24, tr, trm)
    # rollers at both ends, with end caps
    for z, d in ((-6.35, 1.05), (7.15, 1.05)):
        m.cyl((0, 1.0, z), 6.6, d, (120, 120, 128), "Metal")
        for side in (-1, 1):
            m.cyl((side * 3.45, 1.0, z), 0.3, d + 0.35, tr, trm)
    # rear end cap and bumper
    m.box((0, 0.85, 7.75), (7.6, 1.1, 0.5), sd, sdm)
    m.box((0, 0.62, 8.05), (7.0, 0.36, 0.25), BLACK, "Rubber")
    m.box((0, 1.15, 8.03), (5.5, 0.12, 0.08), ac if glow else dark(tr, 0.2), "Neon" if glow else trm)
    # feet
    for x in (-3.3, 3.3):
        for z in (-7.9, 7.5):
            m.cyl((x, 0.15, z), 0.3, 1.1, RUBBER, "Rubber", axis="y")
    # motor hood at the front, its top sloping down towards the belt
    m.box((0, 1.0, -7.75), (7.8, 1.5, 2.6), hd, hdm, name="Hood")
    m.wedge((0, 2.15, -7.75), (7.8, 0.8, 2.6), hd, hdm, r=(0, 180, 0))
    m.box((0, 1.0, -9.07), (6.2, 0.9, 0.06), dark(hd, 0.6), "SmoothPlastic")  # vent panel
    for k in range(5):
        m.box((0, 0.68 + k * 0.16, -9.11), (5.8, 0.05, 0.04), ac if glow else dark(tr, 0.3), "Neon" if glow else trm)
    m.box((0, 1.95, -9.06), (2.4, 0.5, 0.08), ac if glow else tr, "Neon" if glow else trm, name="Badge")
    # uprights (leaning back a little), handlebars with grips, a cross bar
    for side in (-1, 1):
        x = side * 3.45
        m.rod((x, 1.9, -7.55), (x, 5.75, -6.75), 0.6, t.get("post", (fr, frm))[0], t.get("post", (fr, frm))[1], name="Upright")
        m.rod((x, 4.75, -7.0), (x, 4.75, -2.6), 0.42, tr, trm, round_=True, name="Handlebar")
        m.cyl((x, 4.75, -3.9), 2.0, 0.6, t.get("grip", (RUBBER, "Rubber"))[0], t.get("grip", (RUBBER, "Rubber"))[1], axis="z", name="Grip")
        m.ball((x, 4.75, -2.6), 0.5, tr, trm)
        # heart-rate pads
        m.box((x, 4.75, -5.6), (0.5, 0.5, 1.0), CHROME, "Metal")
    m.rod((-3.45, 5.25, -6.85), (3.45, 5.25, -6.85), 0.36, tr, trm, round_=True)
    # the console: body, screen (the game writes on it), bezel, buttons, speakers, a strip of light
    # (a junk one rattles while you run: its parts are a group)
    if t.get("rattle"):
        m.spin("Console", CF((0, 5.0, -6.9)), axis="Z", idle=0, run=17, mode="Wobble", amp=2.5)
    cs, csm = t.get("console", (fr, frm))
    m.box(CONSOLE, (7.6, 3.0, 0.7), cs, csm, name="ConsoleBody")
    m.box(CONSOLE * T(0, 0, -0.4), (7.2, 2.6, 0.2), dark(cs, 0.4), csm)
    m.box(CONSOLE * T(0, 0.3, 0.37), (5.6, 2.05, 0.06), BLACK, "SmoothPlastic")
    m.box(CONSOLE * T(0, 0.3, 0.42), (5.0, 1.75, 0.06), t.get("screen", (15, 15, 20)), "SmoothPlastic", name="Screen", tag="Screen")
    m.box(CONSOLE * T(0, 1.42, 0.3), (6.4, 0.12, 0.2), ac if glow else tr, "Neon" if glow else trm)
    colors = t.get("buttons", [(70, 210, 90), (255, 200, 40), (90, 160, 255), (255, 80, 80)])
    for i, col in enumerate(colors):
        x = -1.5 + i * (3.0 / max(len(colors) - 1, 1))
        m.cyl(CONSOLE * T(x, -1.05, 0.4) * CF.angles(0, 90, 0), 0.12, 0.42, col, "Neon" if glow else "SmoothPlastic")
    for side in (-1, 1):
        m.cyl(CONSOLE * T(side * 3.3, 0.3, 0.37) * CF.angles(0, 90, 0), 0.08, 0.95, BLACK, "Fabric")
        m.cyl(CONSOLE * T(side * 3.3, 0.3, 0.36) * CF.angles(0, 90, 0), 0.06, 1.15, tr, trm)
    m.done()
    # the fan under the console, in its ring (spins; faster while someone runs)
    hub = (0, 3.35, -6.95)
    m.cyl(hub, 0.5, 3.3, t.get("fanring", (dark(fr, 0.2), frm))[0], t.get("fanring", (dark(fr, 0.2), frm))[1], axis="z")
    m.cyl((0, 3.35, -6.7), 0.06, 2.9, BLACK, "SmoothPlastic", axis="z")
    fan_idle, fan_run = t.get("fan", (3, 22))
    m.spin("Fan", CF(hub), axis="Z", idle=fan_idle, run=fan_run)
    m.cyl(hub, 0.6, 0.7, ac if glow else tr, "Neon" if glow else trm, axis="z")
    for i in t.get("blades", (0, 1, 2, 3, 4)):
        m.box(CF(hub) * CF.angles(0, 0, i * 72) * T(0, 0.75, 0.15), (0.5, 1.2, 0.08), light(fr, 0.5), "Metal", r=None)
    m.done()


def screen_glow(m, t, idle=1.2, run=1.6, rng=12):
    m.light(CONSOLE * (0, 0.3, 0.6), t["accent"], rng=rng, idle=idle, run=run)


# Where things come out, in treadmill space
MOTOR = (0, 1.05, -9.35)  # the vent at the front of the hood
REAR = (0, 0.95, 7.6)  # the back roller, where the belt comes round
FEET = (0, 1.62, 0.5)  # under the runner's feet (an aura round them)


def runner_aura(m, colors, size, rate):
    # the runner powers up while they run: an aura of flames round them
    m.emit("Ki", FEET, area=(2.6, 0.2, 2.6), colors=colors, size=size, idle=0, run=rate, boost=True)


def streaks(m, colors, rate, size=1.0):
    # speed lines flying off the back of the belt while they run
    m.emit("Streaks", (0, 2.6, 8.0), area=(5.0, 3.0, 0.2), colors=colors, size=size, idle=0, run=rate, dir="Back")


# ---- themes ------------------------------------------------------------------------------------
THEMES = {}


def theme(name, **t):
    def deco(fn):
        THEMES[name] = (t, fn)
        return fn
    return deco


@theme("Rusty", frame=((124, 76, 50), "CorrodedMetal"), side=((92, 108, 100), "CorrodedMetal"), step=((128, 88, 54), "WoodPlanks"),
       hood=((150, 138, 112), "CorrodedMetal"), trim=((140, 134, 120), "CorrodedMetal"),
       console=((206, 194, 160), "SmoothPlastic"), screen=(30, 70, 34), accent=(255, 170, 60), led=(64, 60, 54), glow=False,
       leds="dead", rattle=True, fan=(0.4, 3.5), blades=(0, 1, 3), belt=(52, 44, 36), slat=(96, 84, 66),
       grip=((70, 66, 60), "Fabric"), buttons=[(110, 50, 44), (110, 104, 56), (80, 80, 80)])
def rusty(m, t):
    # an old CRT box of a console, with rabbit-ear antennas (it all rattles while you run)
    m.join("Console")
    m.box(CONSOLE * T(0, 0, -0.95), (6.6, 2.7, 1.4), (190, 178, 146), "SmoothPlastic")
    m.box(CONSOLE * T(0, 0.3, 0.47), (4.6, 1.6, 0.06), (52, 110, 56), "SmoothPlastic", alpha=0.35)
    # (the screen's cracked)
    for (x, y, l, a) in ((-0.9, 0.6, 1.6, 35), (-0.3, 0.1, 1.1, -50), (0.5, 0.35, 1.3, 15), (1.2, -0.1, 0.9, -70)):
        m.box(CONSOLE * T(x, y, 0.51) * CF.angles(0, 0, a), (0.05, l, 0.02), (200, 205, 200), "SmoothPlastic")
    for side in (-1, 1):
        a = CONSOLE * (side * 0.6, 1.5, -0.6)
        b = CONSOLE * (side * 2.2 - (0.9 if side > 0 else 0), 3.6 - (1.1 if side > 0 else 0), -1.0)  # (one's bent)
        m.rod(a, b, 0.1, (170, 170, 175), "Metal", round_=True)
        m.ball(b, 0.26, (170, 170, 175), "Metal")
    m.ball(CONSOLE * (2.6, 1.55, 0.0), 0.4, (255, 190, 90), "Neon", tag="Flicker")
    m.done()
    # grime: dark smudges all over, a cobweb in the corner, a puddle of oil under the motor
    import random
    rng = random.Random(5)
    for side in (-1, 1):
        for k in range(5):
            z = rng.uniform(-6, 7)
            m.box((side * 4.24, rng.uniform(0.5, 1.3), z), (0.04, rng.uniform(0.3, 0.7), rng.uniform(0.6, 1.6)), (40, 34, 28), "SmoothPlastic", alpha=0.35)
    for k in range(4):
        m.box((rng.uniform(-3, 3), rng.uniform(0.5, 1.6), -9.13), (rng.uniform(0.5, 1.2), rng.uniform(0.3, 0.6), 0.03), (40, 34, 28), "SmoothPlastic", alpha=0.3)
    for (a, b) in (((-3.45, 3.1, -7.4), (-2.2, 1.9, -7.2)), ((-3.45, 2.6, -7.45), (-2.6, 1.9, -7.0)), ((-2.9, 2.6, -7.35), (-2.4, 2.0, -7.1))):
        m.rod(a, b, 0.03, (235, 235, 230), "SmoothPlastic", alpha=0.4)
    m.cyl((0.8, 0.02, -9.0), 0.04, 2.2, (24, 20, 18), "Glass", axis="y", alpha=0.2)
    # duct tape round the left upright and the right grip, patches bolted on, a brick for a foot
    for k in range(3):
        y = 2.6 + k * 0.42
        m.cyl((-3.45, y, -7.55 + (y - 1.9) / 3.85 * 0.8), 0.32, 0.72, (170, 170, 168), "Fabric", axis="y", r=(-12, 0, 0))
    for k in range(2):
        m.cyl((3.45, 4.75, -4.4 + k * 0.9), 0.35, 0.68, (170, 170, 168), "Fabric", axis="z")
    for side, z in ((-1, -2.5), (1, 3.4), (-1, 5.2)):
        m.box((side * 4.23, 0.95, z), (0.06, 0.8, 1.3), (120, 124, 120), "DiamondPlate")
        for dz in (-0.5, 0.5):
            for dy in (-0.28, 0.28):
                m.ball((side * 4.27, 0.95 + dy, z + dz), 0.14, (90, 90, 90), "Metal")
    m.box((-3.3, 0.3, 7.5), (1.6, 0.6, 1.0), (160, 72, 52), "Brick")
    m.box((0.4, 2.7, -8.2), (1.6, 0.18, 0.34), (110, 110, 115), "Metal", r=(0, 25, 0))  # a wrench on the hood
    m.ball((-0.35, 2.72, -8.55), 0.34, (110, 110, 115), "Metal")
    # rust streaks and a spring poking out of the hood
    for x in (-2.4, 1.6, 2.8):
        m.box((x, 0.95, -9.12), (0.25, 0.9, 0.04), (150, 70, 40), "CorrodedMetal")
    for k in range(5):
        m.cyl((-2.6, 2.75 + k * 0.14, -7.2), 0.06, 0.5, (150, 150, 150), "Metal", axis="y")
    # effects: it sputters black smoke, grinds sparks out the back, coughs dust - and the bulb flickers
    m.emit("Smoke", MOTOR, area=(3, 0.6, 0.3), colors=[(70, 64, 58), (35, 32, 30)], size=2.4, idle=1.0, run=11)
    m.emit("Smoke", (-2.6, 3.5, -7.2), area=(0.4, 0.2, 0.4), colors=[(90, 85, 80), (50, 48, 46)], size=1.0, idle=0.5, run=5)
    m.emit("Sparks", REAR, area=(5.5, 0.2, 0.3), colors=[(255, 240, 180), (255, 140, 40)], size=1.0, idle=0, run=18, dir="Back")
    m.emit("Dust", (0, 0.4, 8.0), area=(6, 0.2, 0.4), colors=[(150, 135, 115)], size=1.3, idle=0, run=5, dir="Back")
    m.light(CONSOLE * (2.6, 1.55, 0.3), (255, 180, 90), rng=8, idle=0.7, run=0.9, flicker=True)


@theme("Basic", frame=((236, 236, 240), "SmoothPlastic"), side=((70, 72, 80), "SmoothPlastic"), step=((52, 54, 60), "Rubber"),
       hood=((236, 236, 240), "SmoothPlastic"), trim=((190, 192, 200), "Metal"), console=((240, 240, 244), "SmoothPlastic"),
       screen=(18, 30, 52), accent=(80, 170, 255), led=(200, 205, 212), glow=False, leds="dead", fan=(1.5, 10))
def basic(m, t):
    # a cup holder with a water bottle, a towel over the left handlebar, a red stop button and key
    m.cyl((3.45, 4.75, -2.0), 0.9, 1.0, (70, 72, 80), "SmoothPlastic", axis="y")
    m.cyl((3.45, 5.5, -2.0), 1.3, 0.8, (90, 170, 255), "Glass", axis="y", alpha=0.35)
    m.cyl((3.45, 6.25, -2.0), 0.3, 0.6, WHITE, "SmoothPlastic", axis="y")
    m.box((-3.45, 4.95, -4.0), (0.1, 0.12, 1.6), WHITE, "Fabric")
    for side in (-1, 1):
        m.box((-3.45 + side * 0.3, 4.4, -4.0), (0.1, 0.9, 1.6), WHITE, "Fabric", r=(0, 0, side * 8))
    m.box((-3.45, 3.98, -4.0), (0.7, 0.08, 1.6), (90, 170, 255), "Fabric")
    m.cyl(CONSOLE * T(2.7, -1.05, 0.42) * CF.angles(0, 90, 0), 0.2, 0.7, (230, 40, 40), "SmoothPlastic")
    m.ball(CONSOLE * (-2.7, -1.05, 0.55), 0.4, (230, 40, 40), "SmoothPlastic")
    m.rod(CONSOLE * (-2.7, -1.05, 0.55), (-2.9, 4.2, -5.6), 0.06, (230, 40, 40), round_=True)
    # a blue stripe round the hood
    m.box((0, 1.6, -9.08), (7.7, 0.18, 0.05), (80, 170, 255), "SmoothPlastic")
    # effects: just a puff of dust off the belt while you run
    m.emit("Dust", (0, 0.5, 8.0), area=(6, 0.2, 0.4), colors=[(205, 205, 200)], size=0.9, idle=0, run=4, dir="Back")
    screen_glow(m, t, idle=0.5, run=0.6, rng=8)


@theme("Sporty", frame=((214, 30, 36), "SmoothPlastic"), side=((214, 30, 36), "SmoothPlastic"), step=((40, 40, 46), "DiamondPlate"),
       hood=((214, 30, 36), "SmoothPlastic"), trim=((235, 235, 240), "Metal"), console=((36, 36, 42), "SmoothPlastic"),
       screen=(20, 20, 26), accent=(255, 255, 255), led=(255, 60, 60), grip=((214, 30, 36), "Rubber"))
def sporty(m, t):
    # racing stripes over the hood and down the deck
    for x in (-0.55, 0.55):
        m.box((x, 2.19, -7.75), (0.42, 0.06, 2.72), WHITE, "SmoothPlastic", r=(17.1, 0, 0))
        m.box((x, 1.76, -9.06), (0.42, 1.6, 0.06), WHITE, "SmoothPlastic")
    for side in (-1, 1):
        m.box((side * 4.22, 1.2, 0.5), (0.05, 0.22, 14.6), WHITE, "SmoothPlastic")
        m.box((side * 4.22, 0.75, 0.5), (0.05, 0.1, 14.6), WHITE, "SmoothPlastic")
    # wheels on the rollers, a rear spoiler on two struts, twin chrome exhausts
    for z in (-6.35, 7.15):
        for side in (-1, 1):
            m.cyl((side * 4.3, 1.0, z), 0.35, 1.8, BLACK, "Rubber")
            m.cyl((side * 4.42, 1.0, z), 0.12, 1.1, CHROME, "Metal")
    for side in (-1, 1):
        m.rod((side * 2.6, 1.3, 7.7), (side * 2.6, 3.4, 8.4), 0.32, BLACK, "Metal")
        m.box((side * 3.85, 3.55, 8.45), (0.12, 0.9, 1.7), (214, 30, 36), "SmoothPlastic")
        m.cyl((side * 1.7, 0.62, 8.2), 0.9, 0.55, CHROME, "Metal", axis="z")
        m.cyl((side * 1.7, 0.62, 8.62), 0.06, 0.4, BLACK, "SmoothPlastic", axis="z")
    m.wedge((0, 3.75, 8.45), (7.6, 0.3, 1.8), BLACK, "SmoothPlastic", r=(0, 180, 0))
    m.box((0, 3.62, 8.45), (7.6, 0.06, 1.8), (214, 30, 36), "SmoothPlastic")
    # a checkered band on the hood, a speedometer dial on the console
    for i in range(12):
        for j in range(2):
            m.box((-3.3 + i * 0.6, 0.55 + j * 0.3, -9.12), (0.6, 0.3, 0.04), WHITE if (i + j) % 2 == 0 else BLACK, "SmoothPlastic")
    m.cyl(CONSOLE * T(0, 1.75, -0.1) * CF.angles(0, 90, 0), 0.3, 1.6, WHITE, "SmoothPlastic")
    m.box(CONSOLE * T(0.25, 1.85, 0.08) * CF.angles(0, 0, -50), (0.08, 0.7, 0.05), (230, 30, 30), "Neon")
    # red tail lights on the back
    for side in (-1, 1):
        m.box((side * 2.9, 0.95, 8.03), (1.1, 0.35, 0.1), (255, 40, 40), "Neon")
    # effects: exhaust puffing from the chrome pipes, speed lines when you run
    for side in (-1, 1):
        m.emit("Exhaust", (side * 1.7, 0.62, 8.75), area=(0.3, 0.3, 0.1), colors=[(190, 190, 195), (120, 120, 125)], size=0.7, idle=0.8, run=6, dir="Back")
    streaks(m, [(255, 255, 255)], 10)
    m.light((0, 1.2, 8.4), (255, 50, 50), rng=8, idle=0.8, run=1.4)
    screen_glow(m, t)


@theme("Pro", frame=((32, 72, 170), "Metal"), side=((26, 40, 80), "Metal"), step=((150, 160, 175), "DiamondPlate"),
       hood=((32, 72, 170), "Metal"), trim=((200, 210, 225), "Metal"), console=((22, 30, 56), "SmoothPlastic"),
       screen=(8, 20, 40), accent=(0, 220, 255), led=(0, 220, 255))
def pro(m, t):
    ac = t["accent"]
    # two side screens on arms, big speakers with lit rings, fins on the hood, an underglow
    for side in (-1, 1):
        arm = CONSOLE * T(side * 4.35, 0.3, 0) * CF.angles(0, side * -25, 0)
        m.box(arm, (1.6, 2.2, 0.4), t["console"][0], "SmoothPlastic")
        m.box(arm * T(0, 0, 0.21), (1.3, 1.8, 0.04), (0, 60, 90), "Neon", alpha=0.2)
        m.cyl(CONSOLE * T(side * 2.6, -0.95, 0.38) * CF.angles(0, 90, 0), 0.08, 0.9, BLACK, "Fabric")
        m.cyl(CONSOLE * T(side * 2.6, -0.95, 0.37) * CF.angles(0, 90, 0), 0.06, 1.1, ac, "Neon")
        m.wedge((side * 3.6, 2.85, -7.9), (0.3, 1.0, 2.2), (200, 210, 225), "Metal", r=(0, 180, 0))
        for k in range(3):
            m.box((side * 4.24, 0.62 + k * 0.28, 0.5), (0.05, 0.08, 14.0), ac, "Neon")
    m.box((0, 0.06, 0.5), (8.4, 0.1, 15.8), ac, "Neon", alpha=0.6)
    m.box((0, 2.2, -7.75), (5.0, 0.08, 0.9), ac, "Neon", r=(17.1, 0, 0))
    # effects: cyan wind streaming down both sides and off the back when you run
    for side in (-1, 1):
        m.emit("Streaks", (side * 4.5, 1.3, 0.5), area=(0.2, 0.9, 12), colors=[ac, (255, 255, 255)], size=0.6, idle=0, run=8, dir="Back")
    streaks(m, [ac, (255, 255, 255)], 12)
    m.emit("Kira", (0, 1.1, 0.5), area=(8.6, 0.6, 15), colors=[ac], size=0.6, idle=1.5, run=4)
    m.light((0, 0.6, 0.5), ac, rng=14, idle=1.0, run=1.6)
    screen_glow(m, t)


@theme("Turbo", frame=((255, 128, 0), "Metal"), side=((40, 40, 44), "Metal"), step=((60, 60, 66), "DiamondPlate"),
       hood=((255, 128, 0), "Metal"), trim=((60, 60, 66), "Metal"), console=((40, 40, 44), "Metal"),
       screen=(30, 16, 0), accent=(255, 230, 0), led=(255, 200, 0))
def turbo(m, t):
    # hazard stripes down the deck
    for side in (-1, 1):
        for k in range(16):
            m.box((side * 4.23, 0.95, -6.4 + k * 0.92), (0.05, 0.6, 0.46), (255, 220, 0), "SmoothPlastic", r=(30, 0, 0))
    # twin jet turbines at the back corners: housing, chrome intake, spinning blades, a hot nozzle
    for side in (-1, 1):
        x = side * 4.9
        m.cyl((x, 2.2, 6.0), 3.4, 2.6, (255, 128, 0), "Metal", axis="z")
        m.cyl((x, 2.2, 4.25), 0.25, 2.9, CHROME, "Metal", axis="z")
        m.cyl((x, 2.2, 4.1), 0.06, 2.3, BLACK, "SmoothPlastic", axis="z")
        m.cyl((x, 2.2, 7.9), 0.6, 2.0, (70, 70, 74), "Metal", axis="z")
        m.cyl((x, 2.2, 8.23), 0.06, 1.6, (255, 120, 20), "Neon", axis="z")
        m.rod((x, 0.2, 6.0), (x, 1.0, 6.0), 0.5, (60, 60, 66), "Metal")
        m.spin("Turbine%d" % (side + 1), CF((x, 2.2, 4.22)), axis="Z", idle=4, run=30)
        m.cyl((x, 2.2, 4.22), 0.3, 0.6, CHROME, "Metal", axis="z")
        for i in range(8):
            m.box(CF((x, 2.2, 4.22)) * CF.angles(0, 0, i * 45) * T(0, 0.62, 0) * CF.angles(0, 25, 0), (0.42, 0.9, 0.06), (200, 200, 205), "Metal")
        m.done()
        nozzle = (x, 2.2, 8.5)
        m.emit("Flame", nozzle, area=(1.3, 1.3, 0.2), colors=[(255, 245, 170), (255, 150, 30), (200, 60, 10)], size=1.4, idle=4, run=20, dir="Back", boost=True)
        m.emit("Exhaust", (x, 2.2, 9.2), area=(1.0, 1.0, 0.2), colors=[(110, 105, 100), (60, 58, 56)], size=1.4, idle=0, run=7, dir="Back")
        m.emit("Sparks", nozzle, area=(1.0, 1.0, 0.2), colors=[(255, 230, 150), (255, 120, 20)], size=0.8, idle=0, run=10, dir="Back")
        m.fire(nozzle, (255, 140, 30), idle=2, run=5)
        m.light(nozzle, (255, 140, 40), rng=10, idle=0.8, run=2.2, flicker=True)
    # a roll bar over the back and a turbo snail on the hood
    for side in (-1, 1):
        m.rod((side * 3.9, 1.6, 6.6), (side * 3.0, 5.4, 6.6), 0.36, (40, 40, 44), "Metal", round_=True)
    m.rod((-3.0, 5.4, 6.6), (3.0, 5.4, 6.6), 0.36, (40, 40, 44), "Metal", round_=True)
    m.box((0, 5.4, 6.6), (4.4, 0.5, 0.2), (255, 230, 0), "Neon")
    m.cyl((2.2, 2.9, -7.9), 1.0, 1.5, CHROME, "Metal")
    m.cyl((2.2, 2.9, -7.9), 1.1, 0.7, (40, 40, 44), "Metal")
    # a hazard beacon on the roll bar: its lamp turns, sweeping light round
    m.cyl((0, 5.72, 6.6), 0.18, 0.9, (40, 40, 44), "Metal", axis="y")
    m.spin("Beacon", CF((0, 6.1, 6.6)), axis="Y", idle=3, run=9)
    m.ball((0, 6.1, 6.6), 0.75, (255, 160, 0), "Neon", alpha=0.25)
    m.box((0, 6.1, 6.6), (0.6, 0.3, 0.12), (255, 255, 200), "Neon")
    m.light((0, 6.1, 6.25), (255, 170, 30), rng=18, idle=1.2, run=2.5, spot=True, angle=50)
    m.done()
    streaks(m, [(255, 230, 0), (255, 140, 0)], 12)
    screen_glow(m, t)


@theme("Neon", frame=((16, 16, 24), "SmoothPlastic"), side=((16, 16, 24), "SmoothPlastic"), step=((28, 28, 40), "SmoothPlastic"),
       hood=((16, 16, 24), "SmoothPlastic"), trim=((0, 255, 120), "Neon"), console=((16, 16, 24), "SmoothPlastic"),
       screen=(4, 20, 10), accent=(0, 255, 120), led=(0, 255, 120), post=((16, 16, 24), "SmoothPlastic"))
def neon(m, t):
    g, p = (0, 255, 120), (255, 40, 200)
    # neon tubes along every edge
    for side in (-1, 1):
        m.box((side * 4.22, 0.3, 0.5), (0.12, 0.12, 14.8), g, "Neon")
        m.box((side * 4.22, 1.56, 0.5), (0.12, 0.12, 14.8), p, "Neon")
        for z in (-6.9, 7.9):
            m.box((side * 4.22, 0.92, z), (0.12, 1.3, 0.12), g, "Neon")
        m.rod((side * 3.82, 1.9, -7.5), (side * 3.82, 5.75, -6.7), 0.12, p, "Neon")
    m.box((0, 0.3, -9.1), (7.8, 0.12, 0.12), g, "Neon")
    m.box((0, 1.75, -9.1), (7.8, 0.12, 0.12), g, "Neon")
    m.box(CONSOLE * T(0, -1.55, 0.3), (7.6, 0.12, 0.12), p, "Neon")
    m.box(CONSOLE * T(0, 1.55, 0.3), (7.6, 0.12, 0.12), p, "Neon")
    # a glowing grid under it
    for k in range(9):
        m.box((-4.4 + k * 1.1, 0.04, 0.5), (0.08, 0.05, 16.5), g, "Neon", alpha=0.35)
    for k in range(11):
        m.box((0, 0.04, -7.5 + k * 1.6), (9.0, 0.05, 0.08), g, "Neon", alpha=0.35)
    # a spinning neon triangle over the console
    c = CONSOLE * (0, 3.0, -0.4)
    m.spin("Triangle", CF(c), axis="Y", idle=1.2, run=4)
    pts = [(math.cos(a) * 1.3 + c[0], c[1] + math.sin(a) * 1.3, c[2]) for a in (math.pi / 2, math.pi / 2 + 2.094, math.pi / 2 + 4.189)]
    for i in range(3):
        m.rod(pts[i], pts[(i + 1) % 3], 0.16, p if i == 0 else g, "Neon")
    m.done()
    # effects: rings of light ripple out over the grid; beams shoot up from the corners
    m.pulse((0, 0.12, 0.5), g, radius=9, idle=2.2, run=0.9)
    m.pulse((0, 0.14, 0.5), p, radius=9, idle=2.2, run=0.9, phase=0.5)
    for (x, z, col) in ((-4.3, -7.6, p), (4.3, -7.6, g), (-4.3, 8.0, g), (4.3, 8.0, p)):
        m.beam((x, 0.3, z), (x, 16, z), [col], width=0.6, width1=0.2, style="Ray", alpha=0.35)
    streaks(m, [g, p], 14)
    m.emit("Kira", (0, 3, 0.5), area=(9, 5, 16), colors=[g, p], size=0.7, idle=2, run=6)
    m.light((0, 2, 0.5), g, rng=16, idle=1.4, run=2.2)


def bolt(m, cf, size, col, mat="Neon", **kw):
    # a lightning bolt (three slanted strokes) in cf's XY plane
    s = size
    for (x, y, l, a) in ((0.18, 0.55, 0.75, -28), (0, 0.05, 0.62, 52), (-0.2, -0.45, 0.75, -28)):
        m.box(cf * T(x * s, y * s, 0) * CF.angles(0, 0, a), (0.2 * s, l * s, 0.06), col, mat, **kw)


@theme("Thunder", frame=((30, 40, 82), "Metal"), side=((22, 28, 60), "Metal"), step=((60, 70, 100), "DiamondPlate"),
       hood=((30, 40, 82), "Metal"), trim=((255, 220, 40), "Metal"), console=((22, 28, 60), "Metal"),
       screen=(10, 12, 30), accent=(255, 225, 40), led=(255, 225, 40))
def thunder(m, t):
    y = (255, 225, 40)
    # lightning bolts down both sides and on the hood
    for side in (-1, 1):
        for z in (-4.0, 0.5, 5.0):
            bolt(m, CF((side * 4.25, 0.92, z)) * CF.angles(0, side * 90, 0), 1.3, y)
    bolt(m, CF((0, 1.05, -9.12)), 1.5, y)
    # two tesla coils at the back corners: a base, a copper coil, a big chrome ball on top
    tops = []
    for side in (-1, 1):
        x = side * 4.9
        m.cyl((x, 0.6, 7.0), 1.2, 1.9, (40, 40, 48), "Metal", axis="y")
        m.cyl((x, 1.5, 7.0), 0.6, 1.2, (230, 230, 235), "SmoothPlastic", axis="y")
        for k in range(9):
            m.cyl((x, 2.0 + k * 0.38, 7.0), 0.22, 0.9 if k % 2 == 0 else 0.82, (205, 110, 50), "Foil", axis="y")
        m.cyl((x, 5.6, 7.0), 0.4, 1.6, (180, 180, 190), "Metal", axis="y")
        m.ball((x, 6.4, 7.0), 1.6, CHROME, "Metal")
        m.cyl((x, 6.3, 7.0), 0.25, 2.3, (180, 180, 190), "Metal", axis="y")
        tops.append((x, 6.4, 7.0))
        m.sparkles((x, 6.4, 7.0), (140, 210, 255))
    # electricity crackling between them (two arcs, flickering), and round the balls
    for k in range(2):
        m.beam(tops[0], tops[1], [(190, 235, 255), (120, 190, 255)], width=0.28 - k * 0.1, style="Arc")
    for top in tops:
        m.emit("Zaps", top, area=(2.4, 2.4, 2.4), shape="Sphere", colors=[(170, 225, 255)], size=1.2, idle=3, run=12, boost=True)
    # a storm cloud over the console, with a bolt hanging from it
    c = CONSOLE * (0, 3.2, -0.6)
    for (dx, dy, dz, d) in ((0, 0, 0, 1.8), (-1.1, -0.2, 0.1, 1.4), (1.1, -0.15, -0.1, 1.5), (-0.5, 0.5, -0.2, 1.3), (0.6, 0.45, 0.2, 1.2), (-1.9, -0.35, 0, 0.9), (1.9, -0.3, 0, 0.95)):
        m.ball((c[0] + dx, c[1] + dy, c[2] + dz), d, (90, 96, 120) if dy < 0.3 else (120, 126, 150), "SmoothPlastic")
    bolt(m, CF((c[0] + 0.3, c[1] - 1.4, c[2] + 0.4)), 1.0, y, tag="Flicker")
    # rain from the cloud; while you run, lightning strikes the treadmill every couple of seconds
    m.emit("Rain", (c[0], c[1] - 0.9, c[2]), area=(4.2, 0.2, 1.6), colors=[(170, 200, 255)], size=0.6, idle=8, run=18, dir="Bottom")
    m.beam((c[0], c[1] - 0.6, c[2]), (0, 1.7, 2.5), [(255, 250, 200), (200, 230, 255)], width=0.45, style="Strike", every=2.2)
    m.emit("Impact", (0, 1.8, 2.5), colors=[(255, 240, 120)], size=0.9, every=2.2)
    streaks(m, [(255, 225, 40), (190, 235, 255)], 14)
    m.light((0, 4, 4), (150, 210, 255), rng=16, idle=1.2, run=2.0, flicker=True)


def crystal(m, base, height, width, col, tilt=(0, 0, 0), mat="Glass", alpha=0.25, tip=True):
    # an elongated gem: a square column with a pointed (turned) top
    cf = CF(base) * CF.angles(*tilt)
    m.box(cf * T(0, height / 2, 0) * CF.angles(0, 45, 0), (width, height, width), col, mat, alpha=alpha)
    if tip:
        m.box(cf * T(0, height, 0) * CF.angles(45, 45, 0), (width * 0.7, width * 0.7, width * 0.7), light(col, 0.3), mat, alpha=alpha)


@theme("Diamond", frame=((170, 225, 255), "Glass"), side=((230, 245, 255), "Marble"), step=((200, 235, 255), "Ice"),
       hood=((200, 235, 255), "Glass"), trim=((255, 255, 255), "Metal"), console=((230, 245, 255), "Marble"),
       screen=(20, 50, 80), accent=(140, 230, 255), led=(200, 245, 255), post=((170, 225, 255), "Glass"))
def diamond(m, t):
    ice = (150, 225, 255)
    # crystal clusters on the hood and at the back corners
    pink = (255, 190, 235)
    for side in (-1, 1):
        x = side * 3.4
        crystal(m, (x, 1.9, -8.0), 3.4, 0.85, ice, (8, 0, side * -12))
        crystal(m, (x - side * 0.9, 1.9, -8.3), 2.3, 0.6, light(ice, 0.25), (-4, 0, side * -25))
        crystal(m, (x + side * 0.4, 1.9, -7.4), 1.6, 0.5, pink, (20, 0, side * -10))
        crystal(m, (x - side * 1.7, 2.0, -7.9), 1.2, 0.42, ice, (8, 0, side * 18))
        crystal(m, (side * 4.4, 0, 7.6), 4.0, 0.95, ice, (6, 0, side * -10))
        crystal(m, (side * 4.9, 0, 6.3), 2.6, 0.65, light(ice, 0.25), (-12, 0, side * -24))
        crystal(m, (side * 3.8, 0, 8.6), 1.9, 0.55, pink, (25, 0, side * -6))
        crystal(m, (side * 5.2, 0, 8.2), 1.4, 0.45, ice, (10, 0, side * -35))
        # little shards set along the deck
        for k in range(4):
            crystal(m, (side * 4.3, 0.4, -4.5 + k * 3.2), 0.9, 0.3, ice if k % 2 else pink, (0, 0, side * -30), tip=False)
    # a big cut diamond floating over the console, turning
    c = (0, 9.1, -7.4)  # (over the console)
    m.spin("Gem", CF(c), axis="Y", idle=0.8, run=3)
    m.box(CF(c) * CF.angles(45, 0, 45), (2.1, 2.1, 2.1), (190, 240, 255), "Glass", alpha=0.15)
    m.box(CF(c) * CF.angles(45, 45, 0), (1.4, 1.4, 1.4), (240, 252, 255), "Neon", alpha=0.35)
    m.ring(CF(c), 2.0, 10, 0.22, (200, 245, 255))
    m.done()
    # effects: twinkles flashing on every crystal, icy mist rolling round the bottom, rainbow rays
    for side in (-1, 1):
        m.emit("Kira", (side * 3.4, 3.4, -8.0), area=(2.6, 3.2, 1.8), shape="Sphere", colors=[(255, 255, 255), (170, 230, 255)], size=0.9, idle=3, run=8, boost=True)
        m.emit("Kira", (side * 4.5, 2.0, 7.5), area=(2.4, 4.0, 2.4), shape="Sphere", colors=[(255, 255, 255), (255, 200, 240)], size=0.9, idle=3, run=8, boost=True)
    m.emit("Mist", (0, 0.3, 0.5), area=(9.5, 0.3, 16), colors=[(225, 245, 255)], size=2.6, idle=3, run=5)
    for k, col in enumerate(((255, 160, 200), (255, 230, 150), (160, 255, 200), (150, 210, 255), (210, 170, 255))):
        a = k / 5 * math.pi * 2
        m.beam(c, (math.cos(a) * 6.5, 0.2, 0.5 + math.sin(a) * 8.5), [col], width=0.3, width1=1.6, style="Ray", alpha=0.45)
    m.sparkles(c, (200, 245, 255))
    streaks(m, [(255, 255, 255), (170, 230, 255)], 12)
    m.light(c, (170, 230, 255), rng=16, idle=1.4, run=2.2)


@theme("Magma", frame=((46, 36, 34), "Basalt"), side=((60, 40, 32), "CrackedLava"), step=((40, 32, 30), "Basalt"),
       hood=((46, 36, 34), "Basalt"), trim=((70, 56, 50), "Basalt"), console=((40, 32, 30), "Basalt"),
       screen=(30, 8, 0), accent=(255, 110, 20), led=(255, 120, 20), post=((50, 40, 36), "Basalt"), grip=((30, 26, 24), "Rubber"))
def magma(m, t):
    lava = (255, 110, 20)
    # glowing lava channels down the sides and drips over the hood
    for side in (-1, 1):
        m.box((side * 4.24, 0.62, 0.5), (0.06, 0.16, 14.6), lava, "Neon")
        for k in range(6):
            m.box((side * 4.25, 1.15, -5.5 + k * 2.4), (0.06, 0.5 + (k % 3) * 0.2, 0.18), lava, "Neon")
    for x in (-2.5, -0.9, 1.1, 2.7):
        m.box((x, 1.3, -9.11), (0.22, 1.2 + abs(x) * 0.2, 0.05), lava, "Neon")
    # cracks of lava zig-zagging along both sides
    import random
    rng = random.Random(11)
    for side in (-1, 1):
        y, z = 1.0, -6.4
        while z < 7.4:
            nz = z + rng.uniform(0.9, 1.6)
            ny = min(1.45, max(0.4, y + rng.uniform(-0.45, 0.45)))
            m.rod((side * 4.235, y, z), (side * 4.235, ny, nz), 0.1, (255, 170, 60), "Neon")
            if rng.random() < 0.4:
                m.rod((side * 4.235, ny, nz), (side * 4.235, ny + rng.uniform(-0.35, 0.35), nz + 0.6), 0.07, lava, "Neon")
            y, z = ny, nz
    # rock pillars at the front corners, lava glowing on top
    for side in (-1, 1):
        x = side * 4.9
        for k in range(4):
            m.box((x, 0.5 + k * 0.95, -8.2 + (k % 2) * 0.15), (1.5 - k * 0.2, 1.0, 1.5 - k * 0.2), (56 - k * 4, 44, 40), "Basalt", r=(k * 8, k * 25, -k * 6))
        m.cyl((x, 4.15, -8.1), 0.18, 0.8, lava, "Neon", axis="y")
        m.fire((x, 4.4, -8.1), lava, idle=2, run=4)
    # obsidian spikes along the hood, rocky lumps on the uprights
    for i, x in enumerate((-3.2, -1.6, 0, 1.6, 3.2)):
        h = 1.4 + (i % 2) * 0.6
        m.wedge((x, 2.4 + h / 2, -8.6), (0.8, h, 0.7), (20, 16, 22), "Glass", alpha=0.1, r=(0, 0, 0))
        m.wedge((x, 2.4 + h / 2, -8.95), (0.8, h, 0.7), (20, 16, 22), "Glass", alpha=0.1, r=(0, 180, 0))
    for side in (-1, 1):
        for k in range(3):
            m.box((side * 3.45, 2.5 + k * 1.1, -7.4 + k * 0.22), (0.95, 0.7, 0.95), (56, 44, 40), "Basalt", r=(k * 20, k * 35, 10))
    # a little volcano on the hood, smoking, with lava at its top
    for k in range(5):
        m.cyl((-2.2, 2.6 + k * 0.36, -8.0), 0.38, 2.4 - k * 0.42, (56, 44, 40) if k < 4 else lava, "Basalt" if k < 4 else "Neon", axis="y")
    for k in range(3):
        m.rod((-2.2 + (k - 1) * 0.5, 4.2, -8.0 + (k - 1) * 0.3), (-2.2 + (k - 1) * 0.75, 2.6, -9.0 + k * 0.4), 0.16, lava, "Neon")
    # the volcano: flames, smoke, and an eruption every few seconds while you run
    vent = (-2.2, 4.4, -8.0)
    m.emit("Flame", vent, area=(0.7, 0.2, 0.7), colors=[(255, 230, 120), (255, 110, 20), (160, 30, 10)], size=1.4, idle=5, run=14, boost=True)
    m.emit("Wisps", (-2.2, 5.2, -8.0), area=(0.6, 0.2, 0.6), colors=[(70, 58, 56)], size=1.5, idle=2, run=5)
    m.emit("Burst", vent, colors=[(255, 220, 120), (255, 90, 20)], size=1.3, every=2.8)
    m.emit("Embers", vent, area=(0.6, 0.2, 0.6), colors=[(255, 220, 120), (255, 90, 20)], size=0.6, idle=0, run=10, boost=True)
    # a lava pool behind the belt
    for side in (-1, 1):
        m.cyl((side * 5.0, 0.08, 6.6), 0.16, 2.2, lava, "Neon", axis="y")
        m.cyl((side * 5.0, 0.05, 6.6), 0.1, 2.9, (40, 30, 28), "Basalt", axis="y")
        m.emit("Bubbles", (side * 5.0, 0.2, 6.6), area=(1.6, 0.1, 1.6), colors=[(255, 200, 80), (255, 90, 20)], size=0.7, idle=3, run=6)
        m.fire((side * 5.0, 0.5, 6.6), lava, idle=2.5, run=5)
    # embers rising off everything, hotter while you run
    m.emit("Embers", (0, 1.0, 0.5), area=(9, 0.5, 15), colors=[(255, 220, 120), (255, 110, 20), (180, 40, 10)], size=0.5, idle=6, run=18, boost=True)
    streaks(m, [(255, 160, 40), (255, 80, 20)], 12)
    m.light((0, 2, 0.5), lava, rng=18, idle=1.6, run=2.6, flicker=True)


@theme("Plasma", frame=((56, 12, 86), "SmoothPlastic"), side=((40, 8, 60), "SmoothPlastic"), step=((70, 30, 100), "DiamondPlate"),
       hood=((56, 12, 86), "SmoothPlastic"), trim=((210, 160, 255), "Metal"), console=((40, 8, 60), "SmoothPlastic"),
       screen=(20, 4, 30), accent=(200, 60, 255), led=(220, 120, 255))
def plasma(m, t):
    p = (200, 60, 255)
    # glass tubes down both sides with plasma glowing inside
    for side in (-1, 1):
        x = side * 4.55
        m.cyl((x, 1.0, 0.5), 13.0, 0.75, (220, 200, 255), "Glass", axis="z", alpha=0.55)
        m.cyl((x, 1.0, 0.5), 12.6, 0.32, (255, 120, 255), "Neon", axis="z")
        for z in (-6.3, 7.3):
            m.cyl((x, 1.0, z), 0.4, 0.95, (210, 160, 255), "Metal", axis="z")
        # coils round the uprights
        for k in range(4):
            y = 2.6 + k * 0.6
            m.cyl((side * 3.45, y, -7.55 + (y - 1.9) / 3.85 * 0.8), 0.18, 0.78, (210, 160, 255), "Foil", axis="y", r=(-12, 0, 0))
    # a plasma orb over the console, in two turning containment rings
    c = CONSOLE * (0, 2.9, -0.5)
    m.cyl((c[0], c[1] - 1.45, c[2]), 0.5, 0.9, (210, 160, 255), "Metal", axis="y")
    m.ball(c, 1.3, (255, 140, 255), "Neon")
    m.ball(c, 2.0, (220, 190, 255), "Glass", alpha=0.6)
    m.spin("Rings", CF(c), axis="Y", idle=1, run=4)
    m.ring(CF(c) * CF.angles(90, 0, 0), 1.45, 14, 0.24, p)
    m.ring(CF(c) * CF.angles(90, 60, 0), 1.6, 14, 0.2, (255, 140, 255))
    m.done()
    # effects: an aura of plasma licking round the orb, sparks crackling on it, energy tethered to
    # the coils on the uprights; while you run, you power up in a purple aura of your own
    m.emit("Ki", (c[0], c[1] - 1.0, c[2]), area=(1.6, 0.2, 1.6), colors=[(255, 160, 255), (200, 60, 255), (90, 20, 160)], size=2.2, idle=10, run=22, boost=True)
    m.emit("Zaps", c, area=(2.4, 2.4, 2.4), shape="Sphere", colors=[(255, 180, 255)], size=1.0, idle=4, run=12, boost=True)
    for side in (-1, 1):
        m.beam(c, (side * 3.45, 4.0, -7.2), [(255, 160, 255), (200, 60, 255)], width=0.22, style="Arc")
    m.emit("Impact", c, colors=[(230, 120, 255)], size=1.2, every=3.0)
    runner_aura(m, [(255, 160, 255), (200, 60, 255), (90, 20, 160)], 3.0, 18)
    m.pulse((0, 0.12, 0.5), p, radius=9, idle=0, run=1.2)
    streaks(m, [(255, 160, 255), (200, 60, 255)], 14)
    m.light(c, p, rng=18, idle=1.6, run=2.6)


RAINBOW = [(255, 60, 60), (255, 170, 0), (255, 240, 0), (60, 230, 90), (0, 200, 255), (130, 90, 255), (255, 80, 220)]


@theme("Quantum", frame=((12, 12, 16), "Glass"), side=((8, 8, 12), "SmoothPlastic"), step=((22, 22, 30), "SmoothPlastic"),
       hood=((12, 12, 16), "Glass"), trim=((60, 60, 70), "Metal"), console=((10, 10, 14), "Glass"),
       screen=(10, 4, 16), accent=(255, 0, 170), led=(255, 0, 170))
def quantum(m, t):
    # rainbow strips down the sides (they cycle colour in the game)
    for side in (-1, 1):
        for k, col in enumerate(RAINBOW):
            m.box((side * 4.24, 0.45 + k * 0.13, 0.5), (0.05, 0.1, 14.4), col, "Neon", tag="Rainbow" if k == 0 else None)
    # an atom on the hood: a nucleus and three tilted orbits of electrons
    c = (0, 4.0, -8.2)
    m.cyl((0, 2.75, -8.2), 0.5, 1.2, (60, 60, 70), "Metal", axis="y")
    m.ball(c, 1.0, (255, 0, 170), "Neon")
    m.spin("Atom", CF(c), axis="Y", idle=1.5, run=6)
    for k, tilt in enumerate((0, 60, 120)):
        f = CF(c) * CF.angles(70, tilt, 0)
        m.ring(f, 1.6, 16, 0.14, (0, 220, 255) if k != 1 else (255, 240, 0))
        m.add("Ball", f * CF((1.6, 0, 0)), (0.42, 0.42, 0.42), WHITE, "Neon")
    m.done()
    # cubes orbiting the console, and a hologram panel over it
    c2 = CONSOLE * (0, 1.0, -0.3)
    m.spin("Cubes", CF(c2), axis="Y", idle=0.8, run=3)
    for i in range(6):
        a = i / 6 * math.pi * 2
        m.box(CF((c2[0] + math.cos(a) * 4.6, c2[1] + (0.5 if i % 2 else -0.3), c2[2] + math.sin(a) * 2.2)) * CF.angles(45, i * 30, 45),
              (0.55, 0.55, 0.55), RAINBOW[i], "Neon")
    m.done()
    holo = CONSOLE * T(0, 2.75, 0.1)
    m.box(holo, (3.6, 1.5, 0.04), (0, 200, 255), "Neon", alpha=0.85)
    for (dx, dy, sx, sy) in ((0, 0.75, 3.7, 0.08), (0, -0.75, 3.7, 0.08), (1.82, 0, 0.08, 1.5), (-1.82, 0, 0.08, 1.5)):
        m.box(holo * T(dx, dy, 0), (sx, sy, 0.06), (0, 230, 255), "Neon")
    for k in range(4):
        m.box(holo * T(-1.2 + k * 0.8, -0.2 + (k % 2) * 0.3, 0.03), (0.5, 0.5 + (k % 2) * 0.4, 0.03), RAINBOW[k + 2], "Neon", alpha=0.3)
    m.rod(CONSOLE * (0, 1.5, 0.1), holo * (0, -0.75, 0), 0.08, (0, 230, 255), "Neon", alpha=0.5)
    # effects: glitching squares flicker round it, twinkles round the atom, a rainbow aura and
    # rainbow speed lines while you run
    m.emit("Glitch", (0, 6.5, -6.4), area=(8, 5, 2), colors=RAINBOW, size=0.7, idle=6, run=16, boost=True)
    m.emit("Kira", c, area=(3.6, 3.6, 3.6), shape="Sphere", colors=[(255, 255, 255), (0, 220, 255)], size=0.8, idle=4, run=10, boost=True)
    m.beam(c, (0, 18, -8.2), [(0, 230, 255), (255, 80, 220)], width=0.6, width1=0.15, style="Ray", alpha=0.3)
    m.emit("Impact", c, colors=[(0, 220, 255)], size=1.2, every=3.0)
    runner_aura(m, [(255, 80, 220), (0, 200, 255), (130, 90, 255)], 3.1, 18)
    m.pulse((0, 0.12, 0.5), (255, 0, 170), radius=9.5, idle=0, run=1.0)
    streaks(m, RAINBOW, 16, 1.2)
    m.light((0, 3, 0), (255, 0, 170), rng=18, idle=1.4, run=2.6)


@theme("Cosmic", frame=((44, 22, 96), "Glass"), side=((30, 14, 70), "SmoothPlastic"), step=((60, 40, 120), "SmoothPlastic"),
       hood=((44, 22, 96), "Glass"), trim=((150, 200, 255), "Metal"), console=((30, 14, 70), "SmoothPlastic"),
       screen=(10, 6, 30), accent=(120, 200, 255), led=(150, 210, 255))
def cosmic(m, t):
    # stars set into the sides and the hood
    import random
    rng = random.Random(7)
    for side in (-1, 1):
        for k in range(14):
            m.ball((side * 4.23, rng.uniform(0.4, 1.45), rng.uniform(-6.6, 7.6)), rng.uniform(0.1, 0.2), WHITE, "Neon")
    for k in range(10):
        m.ball((rng.uniform(-3.6, 3.6), rng.uniform(0.5, 1.6), -9.1), rng.uniform(0.1, 0.18), WHITE, "Neon")
    # a little solar system turning over the console: a sun and three planets, one with a ring
    c = (0, 9.9, -5.9)  # (over the console, nearer the runner so the orbits stay in its spot)
    m.ball(c, 1.5, (255, 220, 90), "Neon")
    m.ball(c, 2.1, (255, 170, 60), "Neon", alpha=0.7)
    m.spin("Planets", CF(c), axis="Y", idle=0.6, run=2.5)
    for (r, a, d, col) in ((1.9, 0.0, 0.7, (90, 170, 255)), (2.7, 2.1, 0.95, (255, 120, 90)), (3.5, 4.0, 1.15, (120, 230, 160))):
        p = (c[0] + math.cos(a) * r, c[1], c[2] + math.sin(a) * r)
        m.ball(p, d, col, "SmoothPlastic")
        if d > 1.0:
            m.cyl(CF(p) * CF.angles(0, 0, 90) * CF.angles(25, 0, 0), 0.05, d * 2.0, (230, 210, 255), "Neon", alpha=0.3)
        m.ring(CF(c), r, int(r * 10), 0.07, (180, 160, 255), alpha=0.5)
    m.done()
    # nebula clouds behind the console
    for (dx, dy, d, col) in ((-2.4, 1.6, 2.8, (255, 90, 200)), (2.2, 1.9, 3.2, (90, 160, 255)), (0, 2.8, 2.4, (170, 90, 255))):
        m.ball(CONSOLE * (dx, dy - 0.4, -0.5), d * 0.85, col, "Neon", alpha=0.82)
    # effects: a field of twinkling stars all round it, shooting stars, drifting nebula clouds, and
    # a galaxy swirling under your feet while you run
    m.emit("Stars", (0, 6, 0.5), area=(14, 10, 18), colors=[(255, 255, 255), (190, 210, 255)], size=0.5, idle=10, run=18, boost=True)
    m.emit("Shooting", (0, 13, 0.5), area=(14, 0.5, 16), colors=[(255, 255, 255), (120, 200, 255)], size=1.0, idle=0.6, run=2.5, dir="Bottom")
    m.emit("Nebula", (0, 8.5, -5.5), area=(8, 3, 4), colors=[(255, 90, 200), (90, 160, 255), (170, 90, 255)], size=3.0, idle=2, run=3)
    m.emit("Vortex", (0, 0.25, 0.5), area=(1, 0.1, 1), colors=[(150, 120, 255), (90, 200, 255)], size=10, idle=0.4, run=1.5)
    m.emit("Burst", c, colors=[(255, 255, 255), (150, 190, 255)], size=2.0, every=3.0, every_idle=7)
    m.pulse((0, 0.12, 0.5), (150, 190, 255), radius=10, idle=2.6, run=1.0)
    runner_aura(m, [(150, 190, 255), (120, 90, 255), (40, 20, 120)], 3.2, 18)
    streaks(m, [(255, 255, 255), (150, 190, 255)], 14)
    m.light(c, (150, 190, 255), rng=18, idle=1.4, run=2.6)


@theme("Void", frame=((6, 6, 12), "Glass"), side=((6, 6, 12), "SmoothPlastic"), step=((20, 14, 34), "SmoothPlastic"),
       hood=((6, 6, 12), "Glass"), trim=((150, 90, 255), "Neon"), console=((6, 6, 12), "SmoothPlastic"),
       screen=(8, 4, 16), accent=(150, 90, 255), led=(170, 110, 255), post=((6, 6, 12), "SmoothPlastic"))
def void(m, t):
    v = (150, 90, 255)
    # a black hole behind the console, its glowing disk turning round it
    c = (0, 9.2, -7.2)  # (over the console)
    m.ball(c, 2.2, (2, 2, 4), "SmoothPlastic")
    m.ball(c, 2.7, v, "Neon", alpha=0.75)
    disk = CF(c) * CF.angles(-20, 0, 0)
    m.spin("Disk", disk, axis="Y", idle=1.2, run=5)
    for k, (r, col) in enumerate(((1.8, (255, 180, 90)), (2.2, (255, 120, 200)), (2.6, v), (3.0, (90, 60, 200)))):
        m.ring(disk, r, 18 + k * 4, 0.34 - k * 0.04, col, "Neon")
    m.done()
    # a halo of light over the whole treadmill, and bits of space rock drifting round it
    m.spin("Halo", CF((0, 9.6, 0.5)), axis="Y", idle=0.4, run=1.5)
    m.ring(CF((0, 9.6, 0.5)), 3.6, 28, 0.42, v)
    m.ring(CF((0, 9.6, 0.5)), 3.6, 7, 0.75, (230, 210, 255))
    m.done()
    m.spin("Rocks", CF((0, 3.2, 0.5)), axis="Y", idle=0.3, run=1.2)
    for i in range(7):
        a = i / 7 * math.pi * 2
        m.box((math.cos(a) * 5.4, 3.2 + math.sin(i * 1.7) * 1.2, 0.5 + math.sin(a) * 7.6), (0.7, 0.55, 0.6), (36, 30, 46), "Slate", r=(i * 30, i * 50, i * 20))
        m.ball((math.cos(a) * 5.4, 3.2 + math.sin(i * 1.7) * 1.2 + 0.35, 0.5 + math.sin(a) * 7.6), 0.2, v, "Neon")
    m.done()
    # effects: everything gets pulled into the black hole (sparks sucked inwards from all round),
    # dark flames lick round it, and while you run it sends out a shockwave every few seconds
    m.emit("Suck", c, area=(9, 9, 9), shape="Sphere", colors=[(220, 180, 255), (150, 90, 255)], size=0.8, idle=12, run=24, boost=True)
    m.emit("DarkFlame", (c[0], c[1] - 1.2, c[2]), area=(2.4, 0.2, 2.4), colors=[(190, 120, 255), (70, 20, 140)], size=2.0, idle=6, run=14, boost=True)
    m.emit("Impact", c, colors=[(190, 120, 255)], size=1.4, every=2.5)
    m.emit("Vortex", (0, 0.25, 0.5), area=(1, 0.1, 1), colors=[(150, 90, 255), (40, 10, 80)], size=11, idle=0.8, run=1.6)
    for (x, y, z) in ((-8, 1, 8), (8, 1, 8), (-8, 14, -2), (8, 14, -2)):
        m.beam((x, y, z), c, [(90, 40, 180), (220, 180, 255)], width=2.2, width1=0.2, style="Ray", alpha=0.45)
    m.emit("Burst", c, colors=[(220, 180, 255), (110, 50, 220)], size=2.0, every=2.5, every_idle=6)
    runner_aura(m, [(190, 120, 255), (110, 50, 220), (30, 10, 60)], 3.3, 20)
    m.pulse((0, 0.12, 0.5), v, radius=10, idle=2.5, run=1.0)
    streaks(m, [(220, 180, 255), (150, 90, 255)], 16)
    m.light(c, v, rng=20, idle=2.0, run=3.0)


@theme("Dragon", frame=((24, 120, 72), "SmoothPlastic"), side=((18, 96, 58), "SmoothPlastic"), step=((40, 70, 50), "Slate"),
       hood=((24, 120, 72), "SmoothPlastic"), trim=((255, 200, 50), "Foil"), console=((16, 80, 48), "SmoothPlastic"),
       screen=(6, 26, 14), accent=(255, 200, 50), led=(255, 200, 50), grip=((120, 60, 30), "Fabric"))
def dragon(m, t):
    g, gd, gold = (24, 120, 72), (14, 84, 50), (255, 200, 50)
    # rows of scales down both sides
    for side in (-1, 1):
        for row in range(3):
            for k in range(11):
                z = -6.3 + k * 1.35 + (0.67 if row % 2 else 0)
                if z > 7.6:
                    continue
                m.wedge((side * 4.25, 0.6 + row * 0.38, z), (0.08, 0.45, 1.3), gd if (k + row) % 2 else light(g, 0.15), "SmoothPlastic")
    # the dragon's head on the front of the hood: snout, jaw, gold horns, glowing eyes, smoking nostrils
    h = CF((0, 2.35, -8.3))
    # (kept within z > -10.8 so it never reaches into the pen beside it)
    m.box(h * T(0, 0, 0), (2.8, 1.5, 1.6), g, "SmoothPlastic")
    m.box(h * T(0, -0.35, -1.25), (2.1, 0.95, 1.1), g, "SmoothPlastic")
    m.box(h * T(0, -0.95, -0.95), (1.9, 0.35, 1.6), gd, "SmoothPlastic")
    for side in (-1, 1):
        m.wedge(h * T(side * 0.45, -0.85, -1.62) * CF.angles(180, 0, 0), (0.22, 0.4, 0.3), WHITE, "SmoothPlastic")
        m.box(h * T(side * 0.85, 0.42, -0.82), (0.55, 0.38, 0.1), (255, 230, 60), "Neon")
        m.box(h * T(side * 0.85, 0.42, -0.85), (0.14, 0.34, 0.1), BLACK, "SmoothPlastic")
        m.box(h * T(side * 0.5, 0.0, -1.82), (0.3, 0.25, 0.1), BLACK, "SmoothPlastic")
        m.rod(h * (side * 1.0, 0.7, 0.4), h * (side * 1.6, 2.0, 1.6), 0.38, gold, "Foil")
        m.rod(h * (side * 1.6, 2.0, 1.6), h * (side * 1.7, 2.5, 2.6), 0.24, gold, "Foil")
        m.box(h * T(side * 1.55, 0.1, 0.2), (0.12, 0.9, 1.2), gd, "SmoothPlastic", r=(0, 0, side * 25))
        m.emit("Wisps", h * (side * 0.5, 0.0, -1.95), area=(0.2, 0.2, 0.2), colors=[(200, 200, 200)], size=0.6, idle=1.5, run=3)
    for k in range(4):
        m.wedge(h * T(0, 0.95, 0.6 - k * 0.55), (0.12, 0.5 - k * 0.07, 0.5), gold, "Foil", r=(0, 180, 0))
    # wings spread up and out: a gold arm, finger bones, and membranes stretched between them
    membrane = (60, 190, 110)
    for side in (-1, 1):
        root = (side * 4.25, 2.2, 0.8)
        elbow = (side * 6.0, 5.6, 0.2)
        m.spin("Wing%s" % ("L" if side < 0 else "R"), CF(root), axis="Z", idle=1.6, run=5, mode="Swing", amp=14, dir=side)
        tips = [(side * 7.0, 8.0, -1.6), (side * 8.4, 6.4, 0.6), (side * 8.2, 4.2, 2.6), (side * 6.6, 2.4, 4.2)]
        m.rod(root, elbow, 0.42, gold, "Foil")
        m.ball(elbow, 0.55, gold, "Foil")
        for tip in tips:
            m.rod(elbow, tip, 0.2, gold, "Foil")
            m.ball(tip, 0.3, gold, "Foil")
        m.wedge((elbow[0], elbow[1] + 0.6, elbow[2]), (0.2, 0.9, 0.5), gold, "Foil")  # the claw at the elbow
        for i in range(len(tips) - 1):
            m.tri(elbow, tips[i], tips[i + 1], 0.12, membrane if i % 2 == 0 else (40, 160, 90), "SmoothPlastic", alpha=0.15)
        m.tri(elbow, tips[-1], root, 0.12, (40, 160, 90), "SmoothPlastic", alpha=0.15)
        m.tri(elbow, root, tips[0], 0.12, (40, 160, 90), "SmoothPlastic", alpha=0.15)
        m.done()
        # spikes along its back (the top of the deck sides)
        for k in range(6):
            m.wedge((side * 4.0, 1.95, -5.2 + k * 2.4), (0.18, 0.55, 0.9), gold, "Foil")
    # a tail curling off the back, ending in a spade
    pts = [(2.6, 1.0, 7.9), (3.6, 0.9, 8.6), (4.8, 0.8, 8.8), (5.8, 0.75, 8.3), (6.3, 0.85, 7.3), (6.2, 1.05, 6.2)]
    for i in range(len(pts) - 1):
        m.rod(pts[i], pts[i + 1], 0.95 - i * 0.12, g if i % 2 == 0 else gd, "SmoothPlastic", round_=True)
        m.ball(pts[i + 1], 0.95 - i * 0.12, g, "SmoothPlastic")
    m.wedge((6.15, 1.2, 5.4), (0.2, 1.0, 1.2), gold, "Foil", r=(0, 180, 0))
    # gold claws on the feet
    for x in (-3.3, 3.3):
        for z in (-7.9, 7.5):
            for dx in (-0.35, 0, 0.35):
                m.wedge((x + dx, 0.15, z - 0.75), (0.22, 0.3, 0.5), gold, "Foil")
    # effects: little flames at its mouth - and while you run it breathes a jet of fire; embers swirl
    # all round, and you power up in a fiery aura
    mouth = h * (0, -0.45, -1.95)
    m.emit("Breath", mouth, area=(0.7, 0.4, 0.2), colors=[(255, 250, 190), (255, 150, 30), (210, 40, 10)], size=1.6, idle=2, run=26, dir="Front", boost=True)
    m.fire(mouth, (255, 140, 40), idle=1.2, run=3)
    m.emit("Embers", (0, 2.0, 0.5), area=(11, 1, 15), colors=[(255, 220, 120), (255, 120, 30)], size=0.45, idle=5, run=14, boost=True)
    m.emit("Burst", mouth, colors=[(255, 230, 120), (255, 110, 20)], size=1.8, every=2.4)
    m.emit("Impact", (0, 1.8, 0.5), colors=[(255, 150, 40)], size=1.5, every=4.8)
    runner_aura(m, [(255, 210, 90), (255, 120, 30), (150, 40, 10)], 3.3, 20)
    m.pulse((0, 0.12, 0.5), (255, 160, 40), radius=10, idle=0, run=1.1)
    streaks(m, [(255, 210, 90), (255, 120, 30)], 16)
    m.light((0, 3, -8), (255, 190, 80), rng=18, idle=1.6, run=2.8, flicker=True)


@theme("Supernova", frame=((255, 248, 236), "SmoothPlastic"), side=((255, 150, 40), "SmoothPlastic"), step=((255, 230, 190), "SmoothPlastic"),
       hood=((255, 248, 236), "SmoothPlastic"), trim=((255, 200, 70), "Foil"), console=((60, 30, 10), "SmoothPlastic"),
       screen=(30, 12, 0), accent=(255, 250, 210), led=(255, 230, 120))
def supernova(m, t):
    o = (255, 150, 40)
    # a blazing star over the console: white-hot core, orange shells, rays turning round it
    c = CONSOLE * (0, 3.4, 0.2)
    m.ball(c, 2.0, (255, 252, 230), "Neon")
    m.ball(c, 2.9, (255, 190, 80), "Neon", alpha=0.55)
    m.ball(c, 4.0, o, "Neon", alpha=0.85)
    face = CF(c) * CF.angles(-25, 0, 0)
    m.spin("Rays", face, axis="Z", idle=0.6, run=3)
    for i in range(12):
        long_ = i % 2 == 0
        m.box(face * CF.angles(0, 0, i * 30) * T(0, 2.5 if long_ else 2.15, 0), (0.22, 1.6 if long_ else 0.9, 0.1), (255, 220, 120) if long_ else o, "Neon")
    m.done()
    # a shockwave ring round the base, and flares licking up the uprights
    m.spin("Shockwave", CF((0, 0.25, 0.5)), axis="Y", idle=0.5, run=2)
    for i in range(28):
        a = i / 28 * math.pi * 2
        m.ball((math.cos(a) * 5.4, 0.25, 0.5 + math.sin(a) * 8.9), 0.5, (255, 200, 90) if i % 2 else o, "Neon")
    m.done()
    for side in (-1, 1):
        for k in range(4):
            y = 2.3 + k * 0.85
            m.wedge((side * 3.95, y, -7.45 + (y - 1.9) / 3.85 * 0.8), (0.12, 0.8, 0.5), o if k % 2 else (255, 220, 120), "Neon")
        # gold sunburst panels down the sides
        for k in range(5):
            m.cyl((side * 4.24, 1.0, -5.0 + k * 2.9), 0.06, 0.9, (255, 200, 70), "Foil")
    # effects: the star blazes - an aura of fire, flares bursting off it, a power-up burst every
    # couple of seconds (and a shockwave while you run), rays of light shining out, rings of light
    # rolling over the ground, and a golden aura round you as you run
    m.emit("Ki", (c[0], c[1] - 1.2, c[2]), area=(2.6, 0.2, 2.6), colors=[(255, 250, 220), (255, 190, 60), (255, 110, 20)], size=3.0, idle=12, run=24, boost=True)
    m.emit("Flame", c, area=(3, 3, 3), shape="Sphere", colors=[(255, 240, 160), (255, 140, 30), (200, 60, 10)], size=1.3, idle=6, run=14, boost=True)
    m.emit("Burst", c, colors=[(255, 250, 220), (255, 170, 40)], size=2.2, every=1.8, every_idle=5)
    m.emit("Impact", c, colors=[(255, 220, 120)], size=1.6, every=3.6)
    for k in range(8):
        a = k / 8 * math.pi * 2
        m.beam(c, (c[0] + math.cos(a) * 8.5, c[1] + math.sin(a) * 4.5 - 1.5, c[2] + 1.5), [(255, 240, 180), (255, 170, 60)], width=0.5, width1=2.4, style="Ray", alpha=0.5)
    m.emit("Kira", (0, 5, 0.5), area=(10, 8, 16), colors=[(255, 240, 160), (255, 200, 80)], size=1.0, idle=6, run=12, boost=True)
    m.pulse((0, 0.12, 0.5), (255, 190, 70), radius=11, idle=2.0, run=0.7)
    m.pulse((0, 0.14, 0.5), (255, 250, 220), radius=11, idle=2.0, run=0.7, phase=0.5)
    runner_aura(m, [(255, 250, 220), (255, 200, 80), (255, 120, 30)], 3.4, 22)
    streaks(m, [(255, 250, 220), (255, 190, 70)], 18)
    m.sparkles(c, (255, 230, 150))
    m.light(c, (255, 190, 90), rng=28, idle=2.5, run=3.5)


@theme("Heavenly", frame=((255, 252, 244), "Marble"), side=((255, 252, 244), "Marble"), step=((255, 236, 170), "Foil"),
       hood=((255, 252, 244), "Marble"), trim=((255, 210, 90), "Foil"), console=((255, 250, 238), "Marble"),
       screen=(40, 34, 20), accent=(255, 215, 90), led=(255, 225, 130), post=((255, 252, 244), "Marble"))
def heavenly(m, t):
    gold, marble = (255, 210, 90), (255, 252, 244)
    # marble and gold steps under it (only to look at), and soft clouds round the bottom
    for i in range(3):
        m.box((0, 0.1 - i * 0.01, 0.0), (10.6 - i * 1.2, 0.2 + i * 0.002, 19.2 - i * 1.2), marble if i % 2 == 0 else gold, "Marble" if i % 2 == 0 else "Foil")
    import random
    rng = random.Random(3)
    for k in range(16):
        a = k / 16 * math.pi * 2
        m.ball((math.cos(a) * 5.6, 0.4, 0.0 + math.sin(a) * 8.8), rng.uniform(1.0, 1.5), WHITE, "SmoothPlastic", alpha=0.1)
    # gold capitals on the uprights
    for side in (-1, 1):
        m.box((side * 3.45, 1.95, -7.55), (1.0, 0.3, 1.0), gold, "Foil")
        m.box((side * 3.4, 5.75, -6.75), (1.0, 0.3, 1.0), gold, "Foil")
    # big feathered wings behind the console
    for side in (-1, 1):
        base = CONSOLE * (side * 3.0, 0.4, -0.9)
        m.spin("Wing%s" % ("L" if side < 0 else "R"), CF(base), axis="Z", idle=1.0, run=3, mode="Swing", amp=9, dir=side)
        # three rows of feathers, longest at the back; each feather a long flat point
        for row, (n, length, width, col) in enumerate(((9, 5.4, 1.25, WHITE), (8, 3.8, 1.05, (255, 246, 225)), (7, 2.4, 0.9, (255, 228, 160)))):
            for f in range(n):
                a = math.radians(-18 + f * (118 / n))
                d = (math.cos(a) * side, math.sin(a), 0.0)
                n_ = (-math.sin(a) * side, math.cos(a), 0.0)
                start = (base[0], base[1], base[2] + 0.18 * row)
                end = (start[0] + d[0] * length, start[1] + d[1] * length, start[2] - 0.25)
                w = width / 2
                a1 = (start[0] + n_[0] * w, start[1] + n_[1] * w, start[2])
                a2 = (start[0] - n_[0] * w, start[1] - n_[1] * w, start[2])
                mid = tuple(start[i] + (end[i] - start[i]) * 0.82 for i in range(3))
                b1 = (mid[0] + n_[0] * w * 1.1, mid[1] + n_[1] * w * 1.1, mid[2])
                b2 = (mid[0] - n_[0] * w * 1.1, mid[1] - n_[1] * w * 1.1, mid[2])
                m.tri(a1, b1, b2, 0.14, col, "SmoothPlastic")
                m.tri(a1, b2, a2, 0.14, col, "SmoothPlastic")
                m.tri(b1, end, b2, 0.14, col, "SmoothPlastic")
        m.rod(base, (base[0] + side * 0.6, base[1] + 0.3, base[2]), 0.9, gold, "Foil")
        m.done()
    # a golden halo turning over it, and a column of light
    m.spin("Halo", CF((0, 10.2, 0.5)), axis="Y", idle=0.4, run=1.5)
    m.ring(CF((0, 10.2, 0.5)), 4.0, 18, 0.8, gold)
    m.done()
    m.cyl((0, 31, 0.5), 60, 7, (255, 245, 200), "Neon", axis="y", alpha=0.9, name="LightColumn")
    # effects: rays of light from the sky, white feathers drifting down, golden twinkles everywhere;
    # while you run a holy aura surrounds you and light bursts out every couple of seconds
    for (x, z, w) in ((-6, -4, 5), (5, 3, 6), (0, 9, 4.5)):
        m.beam((x, 46, z), (0, 1.0, 0.5), [(255, 250, 225), (255, 225, 150)], width=w * 0.6, width1=w * 1.3, style="Ray", alpha=0.72)
    m.emit("Feathers", (0, 13, 0.5), area=(12, 1, 16), colors=[(255, 255, 255), (255, 240, 205)], size=0.9, idle=4, run=9, dir="Bottom")
    m.emit("Kira", (0, 5, 0.5), area=(12, 9, 18), colors=[(255, 245, 190), (255, 210, 90)], size=1.1, idle=8, run=16, boost=True)
    m.emit("Burst", (0, 3, 0.5), colors=[(255, 225, 120), (255, 170, 40)], size=2.4, every=2.2)
    m.emit("Impact", (0, 2, 0.5), colors=[(255, 240, 180)], size=1.8, every=4.4)
    # (gold, so it stands out against the white marble and the light)
    runner_aura(m, [(255, 225, 120), (255, 185, 50), (235, 130, 20)], 3.3, 24)
    m.pulse((0, 0.22, 0.5), gold, radius=12, idle=2.5, run=1.0)
    m.pulse((0, 0.24, 0.5), (255, 255, 240), radius=12, idle=2.5, run=1.0, phase=0.5)
    streaks(m, [(255, 255, 240), (255, 215, 90)], 18)
    m.sparkles((0, 6, 0.5), (255, 240, 180))
    m.light((0, 8, 0.5), (255, 240, 190), rng=30, idle=2.5, run=3.5)


REACH = 10.2  # (studs along the belt either way; the game keeps pens and podiums clear of this)


def extents(m):
    lo, hi = [1e9] * 3, [-1e9] * 3
    for p in m.parts:
        if p["name"] == "LightColumn" or p["alpha"] >= 0.99:
            continue
        sx, sy, sz = p["size"]
        if p["shape"] == "Ball":
            r, c = min(p["size"]) / 2, p["cf"].p
            for i in range(3):
                lo[i], hi[i] = min(lo[i], c[i] - r), max(hi[i], c[i] + r)
            continue
        for dx in (-.5, .5):
            for dy in (-.5, .5):
                for dz in (-.5, .5):
                    q = p["cf"] * (dx * sx, dy * sy, dz * sz)
                    for i in range(3):
                        lo[i], hi[i] = min(lo[i], q[i]), max(hi[i], q[i])
    return lo, hi


def build(name):
    t, fn = THEMES[name]
    m = Model(name)
    chassis(m, t)
    fn(m, t)
    lo, hi = extents(m)
    assert lo[2] >= -REACH and hi[2] <= REACH, "%s reaches z %.2f..%.2f" % (name, lo[2], hi[2])
    assert lo[0] >= -10 and hi[0] <= 10, "%s reaches x %.2f..%.2f" % (name, lo[0], hi[0])
    return m


# ---- export to the game ------------------------------------------------------------------------
def num(x, places=2):
    s = ("%%.%df" % places % x).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def v3(v, places=2):
    return "V(%s, %s, %s)" % tuple(num(x, places) for x in v)


def lua_part(p):
    f = []
    if p["shape"] != "Block":
        f.append('Shape = "%s"' % p["shape"])
    if p["name"]:
        f.append('Name = "%s"' % p["name"])
    f.append("Pos = " + v3(p["cf"].p))
    f.append("Size = " + v3(p["size"]))
    rot = p["cf"].euler()
    if any(abs(a) > 1e-3 for a in rot):
        f.append("Rot = " + v3(rot, 1))
    f.append("Color = C(%d, %d, %d)" % p["col"])
    if p["mat"] != "SmoothPlastic":
        f.append('Material = "%s"' % p["mat"])
    if p["alpha"]:
        f.append("Transparency = %s" % num(p["alpha"]))
    if p["collide"]:
        f.append("Collide = true")
    if p["tag"]:
        f.append('Tag = "%s"' % p["tag"])
    if p["index"] is not None:
        f.append("Index = %d" % p["index"])
    if p["group"]:
        f.append('Group = "%s"' % p["group"])
    return "{ " + ", ".join(f) + " }"


def lua_colors(cols):
    return "{ " + ", ".join("C(%d, %d, %d)" % tuple(int(x) for x in c) for c in cols) + " }"


def lua_vfx(e):
    k = e["kind"]
    f = ['Kind = "%s"' % k]
    if k == "Emit":
        f += ['Preset = "%s"' % e["preset"], "Pos = " + v3(e["pos"]), "Area = " + v3(e["area"]), "Colors = " + lua_colors(e["colors"]),
              "Size = " + num(e["size"]), "Idle = " + num(e["idle"]), "Run = " + num(e["run"])]
        if e["dir"] != "Top":
            f.append('Dir = "%s"' % e["dir"])
        if e["shape"] != "Box":
            f.append('Shape = "%s"' % e["shape"])
        if e["boost"]:
            f.append("Boost = true")
        if e["every"]:
            f.append("Every = " + num(e["every"]))
        if e["every_idle"]:
            f.append("EveryIdle = " + num(e["every_idle"]))
    elif k == "Beam":
        f += ['Style = "%s"' % e["style"], "From = " + v3(e["a"]), "To = " + v3(e["b"]), "Colors = " + lua_colors(e["colors"]),
              "Width = " + num(e["width"]), "Width1 = " + num(e["width1"])]
        if e["alpha"]:
            f.append("Transparency = " + num(e["alpha"]))
        if e["every"]:
            f.append("Every = " + num(e["every"]))
    elif k == "Light":
        f += ["Pos = " + v3(e["pos"]), "Color = C(%d, %d, %d)" % e["col"], "Range = " + num(e["range"]), "Idle = " + num(e["idle"]), "Run = " + num(e["run"])]
        if e["flicker"]:
            f.append("Flicker = true")
        if e["spot"]:
            f += ["Spot = true", "Angle = " + num(e["angle"])]
    elif k == "Pulse":
        f += ["Pos = " + v3(e["pos"]), "Color = C(%d, %d, %d)" % e["col"], "Radius = " + num(e["radius"]), "Idle = " + num(e["idle"]), "Run = " + num(e["run"])]
        if e["phase"]:
            f.append("Phase = " + num(e["phase"]))
    elif k == "Fire":
        f += ["Pos = " + v3(e["pos"]), "Color = C(%d, %d, %d)" % e["col"], "Idle = " + num(e["idle"]), "Run = " + num(e["run"])]
    elif k == "Sparkles":
        f += ["Pos = " + v3(e["pos"]), "Color = C(%d, %d, %d)" % e["col"]]
    if e.get("group"):
        f.append('Group = "%s"' % e["group"])
    return "{ " + ", ".join(f) + " }"


def export(path, names):
    lines = [
        "--[[",
        "\tTreadmillModels: what every treadmill is made of - GENERATED by art/treadmills/treadmills.py (a",
        "\tBlender script that also renders them all). Don't edit this file: change the treadmills there and",
        "\trun it again.",
        "",
        "\tModels[tier name] = { Parts, Groups, Vfx }, in treadmill space (studs; y up from the ground, the",
        "\tconsole at -z, the belt 6 x 13 with its top at 1.5, centred on z = 0.5).",
        "\tA part: Shape (Block unless said: Cylinder runs along X, Ball, Wedge), Pos, Size, Rot (degrees, like",
        "\tCFrame.Angles), Color, Material (an Enum.Material name; SmoothPlastic unless said), Transparency,",
        "\tCollide (only the deck and belt), Tag (Belt, Slat, LED, Screen, Rainbow, Flicker), Index (slats and",
        "\tLEDs, in order), Group (it turns with that group).",
        "\tGroups[name] = { Pivot, Axis (X / Y / Z of the pivot), Idle, Run (how fast, standing / while someone",
        "\truns), Mode (Spin: turns, radians a second; Swing: rocks Amp degrees to and fro; Wobble: rattles),",
        "\tAmp, Dir (+1 / -1: which way a swing goes first) }.",
        "\tVfx: the effects (built by server/TreadmillFX, animated by client/Treadmill). Idle / Run: how strong",
        "\tstanding still / while the owner runs (particles a second, brightness, size, seconds; 0 = off).",
        "\t  Emit: Preset (TreadmillFX.Presets), Pos, Area (a box, or a sphere with Shape = Sphere), Colors,",
        "\t        Size, Dir (the way they fly: Top, Bottom, Front, Back...), Boost (allowed more particles),",
        "\t        Every / EveryIdle (bursts: seconds between them, running / standing)",
        "\t  Beam: From, To, Colors, Width, Width1, Style (Ray: a soft shaft of light; Arc: crackling",
        "\t        electricity; Strike: a lightning bolt every Every seconds while running), Transparency",
        "\t  Light: Pos, Color, Range, Idle, Run, Flicker, Spot (a turning spotlight, Angle)",
        "\t  Pulse: Pos, Color, Radius, Idle, Run (seconds a ring takes to spread; 0 = off), Phase",
        "\t  Fire: Pos, Color, Idle, Run (its size);  Sparkles: Pos, Color",
        "]]",
        "",
        "export type Part = {",
        "\tShape: string?,",
        "\tName: string?,",
        "\tPos: Vector3,",
        "\tSize: Vector3,",
        "\tRot: Vector3?,",
        "\tColor: Color3,",
        "\tMaterial: string?,",
        "\tTransparency: number?,",
        "\tCollide: boolean?,",
        "\tTag: string?,",
        "\tIndex: number?,",
        "\tGroup: string?,",
        "}",
        "export type Group = { Pivot: CFrame, Axis: string, Idle: number, Run: number, Mode: string?, Amp: number?, Dir: number? }",
        "export type Vfx = {",
        "\tKind: string,",
        "\tPreset: string?,",
        "\tPos: Vector3?,",
        "\tArea: Vector3?,",
        "\tShape: string?,",
        "\tColors: { Color3 }?,",
        "\tColor: Color3?,",
        "\tSize: number?,",
        "\tIdle: number?,",
        "\tRun: number?,",
        "\tDir: string?,",
        "\tBoost: boolean?,",
        "\tEvery: number?,",
        "\tEveryIdle: number?,",
        "\tFrom: Vector3?,",
        "\tTo: Vector3?,",
        "\tWidth: number?,",
        "\tWidth1: number?,",
        "\tStyle: string?,",
        "\tTransparency: number?,",
        "\tRange: number?,",
        "\tFlicker: boolean?,",
        "\tSpot: boolean?,",
        "\tAngle: number?,",
        "\tRadius: number?,",
        "\tPhase: number?,",
        "\tGroup: string?,",
        "}",
        "export type Model = { Parts: { Part }, Groups: { [string]: Group }, Vfx: { Vfx } }",
        "",
        "local V, C = Vector3.new, Color3.fromRGB",
        "local TreadmillModels: { [string]: Model } = {}",
        "",
    ]
    total = 0
    for name in names:
        m = build(name)
        total += len(m.parts)
        lines.append("-- %s: %d parts" % (name, len(m.parts)))
        lines.append("TreadmillModels.%s = {" % name)
        lines.append("\tParts = {")
        lines += ["\t\t" + lua_part(p) + "," for p in m.parts]
        lines.append("\t},")
        lines.append("\tGroups = {")
        for g, d in m.groups.items():
            rx, ry, rz = d["pivot"].euler()
            pivot = "CFrame.new(%s, %s, %s)" % tuple(num(x) for x in d["pivot"].p)
            if any(abs(a) > 1e-3 for a in (rx, ry, rz)):
                pivot += " * CFrame.Angles(math.rad(%s), math.rad(%s), math.rad(%s))" % (num(rx), num(ry), num(rz))
            extra = ""
            if d["mode"] != "Spin":
                extra = ', Mode = "%s", Amp = %s, Dir = %d' % (d["mode"], num(d["amp"]), d["dir"])
            lines.append('\t\t%s = { Pivot = %s, Axis = "%s", Idle = %s, Run = %s%s },' % (g, pivot, d["axis"], num(d["idle"]), num(d["run"]), extra))
        lines.append("\t},")
        lines.append("\tVfx = {")
        lines += ["\t\t" + lua_vfx(e) + "," for e in m.effects]
        lines.append("\t},")
        lines.append("}")
        lines.append("")
    lines.append("return TreadmillModels")
    open(path, "w").write("\n".join(lines) + "\n")
    print("exported", path, total, "parts")


# ---- render ------------------------------------------------------------------------------------
MATS = {
    # Roblox material -> (roughness, metallic, emission, transmission, tint)
    "SmoothPlastic": (0.38, 0.0, 0, 0, 1.0), "Plastic": (0.5, 0.0, 0, 0, 1.0), "Metal": (0.3, 0.85, 0, 0, 1.0),
    "DiamondPlate": (0.45, 0.8, 0, 0, 0.9), "CorrodedMetal": (0.85, 0.4, 0, 0, 0.85), "Neon": (0.4, 0.0, 3.0, 0, 1.0),
    "Glass": (0.05, 0.0, 0, 0.85, 1.0), "Ice": (0.12, 0.0, 0, 0.5, 1.0), "Marble": (0.22, 0.0, 0, 0, 1.0),
    "Foil": (0.18, 1.0, 0, 0, 1.0), "Wood": (0.7, 0.0, 0, 0, 1.0), "WoodPlanks": (0.75, 0.0, 0, 0, 0.95),
    "Basalt": (0.9, 0.0, 0, 0, 0.9), "CrackedLava": (0.8, 0.0, 0.8, 0, 1.0), "Slate": (0.85, 0.0, 0, 0, 0.95),
    "Fabric": (0.95, 0.0, 0, 0, 1.0), "Rubber": (0.9, 0.0, 0, 0, 1.0), "Brick": (0.9, 0.0, 0, 0, 1.0),
    "ForceField": (0.2, 0.0, 1.5, 0, 1.0),
}


# ---- the effects, roughly, for the renders ------------------------------------------------------
# The game's effects are Roblox particles, beams and lights (server/TreadmillFX); a still render
# can't run them, so this draws a snapshot of each the way it looks mid-run: a puff of geometry
# per particle (as many as the game's particle budget lets through), glowing rods for sparks,
# streaks and lightning, crossed planes for rays of light, rings for pulses, real lamps for lights.
DIRS = {"Top": (0, 1, 0), "Bottom": (0, -1, 0), "Front": (0, 0, -1), "Back": (0, 0, 1), "Left": (-1, 0, 0), "Right": (1, 0, 0)}


def _add(a, b, k=1.0):
    return tuple(a[i] + b[i] * k for i in range(3))


def _unit(v):
    n = math.sqrt(sum(x * x for x in v)) or 1.0
    return tuple(x / n for x in v)


def _spread(rnd, d, degrees):
    # d turned a random amount up to `degrees` off
    t = math.tan(math.radians(degrees))
    return _unit(_add(d, (rnd.uniform(-1, 1) * t, rnd.uniform(-1, 1) * t, rnd.uniform(-1, 1) * t)))


def _colour(cols, t):
    if len(cols) == 1:
        return tuple(cols[0])
    x = t * (len(cols) - 1)
    i = min(int(x), len(cols) - 2)
    return mix(cols[i], cols[i + 1], x - i)


FX_GLOW = 0.6  # (how bright the glowing bits are next to the game's Brightness)

# preset: (seconds a particle lives, how it's drawn)
PRESET_LOOK = {
    "Smoke": (1.4, "puff"), "Dust": (0.85, "puff"), "Exhaust": (1.1, "puff"), "Mist": (2.5, "mist"), "Nebula": (4.0, "nebula"),
    "Wisps": (1.2, "wisp"), "Sparks": (0.45, "spark"), "Streaks": (0.18, "streak"), "Shooting": (0.35, "shooting"),
    "Rain": (0.32, "rain"), "Flame": (0.6, "flame"), "Breath": (0.55, "breath"), "Ki": (0.9, "ki"), "DarkFlame": (0.9, "ki"),
    "Kira": (0.6, "star"), "Stars": (1.5, "star"), "Zaps": (0.25, "zap"), "Embers": (1.6, "ember"), "Bubbles": (0.7, "bubble"),
    "Glitch": (0.14, "glitch"), "Feathers": (5.0, "feather"), "Suck": (0.5, "suck"), "Vortex": (1.9, "vortex"),
    "Burst": (0.4, "burst"), "Impact": (0.4, "impact"),
}


def fx_shapes(m):
    """Primitives (in treadmill space) for a snapshot of m's effects while someone runs on it."""
    import random
    out = []

    def ball(c, r, col, glow, alpha=0.0, flat=1.0):
        out.append(("ball", c, r, (col, glow * FX_GLOW, alpha), flat))

    def rod(a, b, t, col, glow, alpha=0.0):
        out.append(("rod", a, b, t, (col, glow * FX_GLOW, alpha)))

    def lick(base, h, r, col, glow, alpha):
        # a lick of flame: a tall soft blob
        ball(_add(base, (0, 1, 0), h / 2), r, col, glow, alpha, h / (2 * r))

    def star(c, r, col, glow):
        rod(_add(c, (-r, 0, 0)), _add(c, (r, 0, 0)), r * 0.12, col, glow)
        rod(_add(c, (0, -r, 0)), _add(c, (0, r, 0)), r * 0.12, col, glow)
        rod(_add(c, (0, 0, -r * 0.7)), _add(c, (0, 0, r * 0.7)), r * 0.1, col, glow)

    def ring(c, radius, t, col, glow, alpha=0.0, seg=36):
        for i in range(seg):
            a0, a1 = i / seg * math.tau, (i + 1) / seg * math.tau
            rod(_add(c, (math.cos(a0) * radius, 0, math.sin(a0) * radius)), _add(c, (math.cos(a1) * radius, 0, math.sin(a1) * radius)), t, col, glow, alpha)

    def jagged(a, b, reach, rnd, width, col):
        pts = []
        d = _unit(tuple(b[i] - a[i] for i in range(3)))
        side = _unit((d[2], 0, -d[0])) if abs(d[1]) < 0.9 else (1, 0, 0)
        up = _unit((d[1] * side[2] - d[2] * side[1], d[2] * side[0] - d[0] * side[2], d[0] * side[1] - d[1] * side[0]))
        for i in range(7):
            f = i / 6
            p = tuple(a[k] + (b[k] - a[k]) * f for k in range(3))
            mid = math.sin(math.pi * f)
            pts.append(_add(_add(p, side, rnd.uniform(-1, 1) * reach * mid), up, rnd.uniform(-1, 1) * reach * mid))
        for i in range(6):
            rod(pts[i], pts[i + 1], width, light(col, 0.5), 7)
            rod(pts[i], pts[i + 1], width * 3, col, 1.5, 0.88)

    for index, e in enumerate(m.effects):
        rnd = random.Random("%s:%d" % (m.name, index))
        kind = e["kind"]
        if kind == "Emit":
            life, look = PRESET_LOOK[e["preset"]]
            size, cols = e["size"], e["colors"]
            rate = e["run"] or e["idle"]
            burst = e.get("every") or e.get("every_idle")
            # (the game's particle budget: 40% of the rate, at most 20 a second; 85% / 40 for the big ones)
            rate = min(rate * 0.85, 40) if e.get("boost") else min(rate * 0.4, 20)
            n = 1 if burst else max(3, min(48, round(rate * life)))
            pos, area = e["pos"], e["area"]
            d = DIRS.get(e["dir"], (0, 1, 0))
            sphere = e.get("shape") == "Sphere"

            def spawn():
                if sphere or look == "suck":
                    v = _unit((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1)))
                    r = min(area) / 2 * (1 if look == "suck" else rnd.random() ** 0.33)
                    return _add(pos, v, r)
                return tuple(pos[i] + rnd.uniform(-0.5, 0.5) * area[i] for i in range(3))

            for _ in range(n):
                t = rnd.random()  # how far through its life this particle is
                age = t * life
                col = _colour(cols, t)
                p = spawn()
                if look == "puff":
                    speed = {"Smoke": size * 2.2, "Dust": 3.5, "Exhaust": 5.5}[e["preset"]]
                    q = _add(_add(p, _spread(rnd, d, 25 if e["preset"] != "Dust" else 50), speed * age * (1 - 0.35 * t)), (0, 1, 0), size * 0.6 * age * age)
                    ball(q, size * (0.22 + 0.6 * t), col, 0, 0.3 + 0.55 * t)
                elif look == "mist":
                    ball(p, size * (0.8 + 0.6 * t), col, 0.2, 0.86, 0.45)
                elif look == "nebula":
                    ball(p, size * (1.0 + 0.6 * t), col, 1.6, 0.86)
                elif look == "wisp":
                    ball(_add(p, (0, 1, 0), 1.5 * age), size * (0.2 + 0.4 * t), col, 1.5, 0.55)
                elif look == "spark":
                    v = _spread(rnd, d, 35)
                    sp = size * rnd.uniform(8, 16)
                    q = _add(_add(p, v, sp * age), (0, -1, 0), 22 * age * age)
                    rod(q, _add(q, v, -sp * 0.035), size * 0.06, col, 12)
                elif look in ("streak", "shooting"):
                    v = _spread(rnd, d, 3 if look == "streak" else 35)
                    sp = size * 37 if look == "streak" else 55
                    q = _add(p, v, sp * age)
                    rod(q, _add(q, v, -(size * 2.2 if look == "streak" else 4.5)), size * 0.07 if look == "streak" else 0.09, col, 7, 0.25)
                elif look == "rain":
                    q = _add(p, d, 35 * age)
                    rod(q, _add(q, d, -1.4), 0.04, col, 1.5, 0.45)
                elif look in ("flame", "breath"):
                    if look == "breath" or e["dir"] != "Top":
                        v = _spread(rnd, d, 10 if look == "breath" else 8)
                        q = _add(_add(p, v, size * (13 if look == "breath" else 7) * age), (0, 1, 0), size * 0.7 * age * age)
                    else:
                        q = _add(p, _spread(rnd, (0, 1, 0), 15), size * 2.2 * age)
                    ball(q, size * (0.25 + 0.6 * t) * (1.3 if look == "breath" else 0.9), col, 7, 0.15 + 0.5 * t)
                elif look == "ki":
                    q = _add(p, (0, 1, 0), size * 1.2 * t)
                    lick(q, size * (0.5 + 0.4 * rnd.random()), size * 0.12 * (1 - 0.5 * t), col, 4 if e["preset"] == "Ki" else 2, 0.4 + 0.45 * t)
                elif look == "star":
                    star(p, size * 0.35 * math.sin(math.pi * t) + 0.08, light(col, 0.2), 14)
                elif look == "zap":
                    a = p
                    for _ in range(3):
                        b = _add(a, _unit((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))), size * 0.5)
                        rod(a, b, size * 0.05, light(col, 0.5), 14)
                        a = b
                elif look == "ember":
                    ball(_add(p, _spread(rnd, (0, 1, 0), 40), 2.5 * age), size * 0.07, col, 10)
                elif look == "bubble":
                    ball(p, size * 0.3 * t, col, 7)
                elif look == "glitch":
                    out.append(("box", p, (size * 0.7, size * 0.35, 0.04), (0, rnd.uniform(0, 180), 0), (col, 9 * FX_GLOW, 0.2)))
                elif look == "feather":
                    q = _add(p, (rnd.uniform(-1, 1), -1, rnd.uniform(-1, 1)), 1.4 * age)
                    out.append(("box", q, (size * 0.18, 0.03, size * 0.55), (rnd.uniform(-50, 50), rnd.uniform(0, 180), rnd.uniform(-50, 50)), (col, 0.6 * FX_GLOW, 0.0)))
                elif look == "suck":
                    v = _unit(tuple(pos[i] - p[i] for i in range(3)))
                    q = _add(p, v, min(area) / 2 * t * 0.9)
                    rod(q, _add(q, v, -size * 0.9), size * 0.06, col, 10)
                elif look == "vortex":
                    for arm in range(3):
                        for j in range(14):
                            f = j / 13
                            a = arm / 3 * math.tau + f * 4.0
                            r = size * (0.15 + 0.85 * f)
                            ball(_add(pos, (math.cos(a) * r, 0, math.sin(a) * r)), size * 0.07 * (1.2 - f * 0.5), _colour(cols, f), 6, 0.2)
                    break
                elif look == "burst":
                    for _ in range(16):
                        v = _unit((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1)))
                        rod(_add(pos, v, size * 0.5), _add(pos, v, size * rnd.uniform(2.2, 3.6)), size * 0.1, _colour(cols, rnd.random()), 9, 0.15)
                    break
                elif look == "impact":
                    ring(pos, size * 1.8, size * 0.1, cols[0], 7, 0.25)
                    for _ in range(6):
                        v = _unit((rnd.uniform(-1, 1), rnd.uniform(-0.3, 0.6), rnd.uniform(-1, 1)))
                        rod(pos, _add(pos, v, size * 2.4), size * 0.12, light(cols[0], 0.5), 11, 0.1)
                    break
        elif kind == "Beam":
            a, b, cols = e["a"], e["b"], e["colors"]
            if e["style"] == "Ray":
                # (two crossed planes, each about half as strong as the beam)
                out.append(("ray", a, b, e["width"], e["width1"], (cols[0], 1.4, 1 - (1 - e["alpha"]) * 0.6)))
            else:
                length = math.dist(a, b)
                jagged(a, b, length * (0.11 if e["style"] == "Strike" else 0.08), rnd, e["width"] * 0.45, cols[0])
        elif kind == "Pulse":
            ring(e["pos"], e["radius"] * 0.55, 0.22, e["col"], 6, 0.35)
        elif kind == "Fire":
            size = e["run"] or e["idle"]
            for _ in range(6):
                base = _add(e["pos"], (rnd.uniform(-0.3, 0.3), 0, rnd.uniform(-0.3, 0.3)))
                lick(base, size * rnd.uniform(0.35, 0.7), size * 0.12, mix(e["col"], (255, 240, 150), rnd.random() * 0.6), 5, 0.35)
        elif kind == "Sparkles":
            for _ in range(6):
                star(_add(e["pos"], _unit((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1))), rnd.uniform(0.6, 1.6)), 0.18, e["col"], 12)
        elif kind == "Light":
            bright = (e["run"] or e["idle"]) * (0.55 if e["flicker"] else 1.0)
            out.append(("light", e["pos"], e["col"], bright, e["range"], e["spot"], e["angle"]))
    return out


def render(out, names, tile=None):
    # tile: (width, height) - one close-up of names[0] instead of the sheet
    import bpy, bmesh
    from mathutils import Matrix, Vector

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    P = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # game (y up) -> Blender (z up)

    def lin(c):
        return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92

    mats = {}

    def material(rgb, mat, alpha):
        key = (rgb, mat, alpha)
        if key in mats:
            return mats[key]
        rough, metal, emit, trans, tint = MATS.get(mat, MATS["SmoothPlastic"])
        m = bpy.data.materials.new("M%d" % len(mats))
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        color = (*[lin(v / 255 * tint) for v in rgb], 1)
        b.inputs["Base Color"].default_value = color
        b.inputs["Roughness"].default_value = rough
        b.inputs["Metallic"].default_value = metal
        if emit:
            b.inputs["Emission Color"].default_value = color
            b.inputs["Emission Strength"].default_value = emit * (1 - alpha) ** 1.5
        if trans:
            b.inputs["Transmission Weight"].default_value = trans
        if alpha:
            b.inputs["Alpha"].default_value = max(0.0, 1 - alpha)
        mats[key] = m
        return m

    def matrix_of(p, place):
        cf = p["cf"]
        R = cf.R
        M = Matrix(((R[0][0], R[0][1], R[0][2], cf.p[0]), (R[1][0], R[1][1], R[1][2], cf.p[1]), (R[2][0], R[2][1], R[2][2], cf.p[2]), (0, 0, 0, 1)))
        return P @ place @ M

    show_fx = os.environ.get("VFX", "1") == "1"
    fx_mats = {}

    def fx_material(col, glow, alpha):
        key = (tuple(col), round(glow, 2), round(alpha, 2))
        if key not in fx_mats:
            mm = bpy.data.materials.new("FX%d" % len(fx_mats))
            mm.use_nodes = True
            b = mm.node_tree.nodes["Principled BSDF"]
            color = (*[lin(v / 255) for v in col], 1)
            b.inputs["Base Color"].default_value = color
            b.inputs["Roughness"].default_value = 0.8
            if glow:
                b.inputs["Emission Color"].default_value = color
                b.inputs["Emission Strength"].default_value = glow
            if alpha:
                b.inputs["Alpha"].default_value = max(0.02, 1 - alpha)
            fx_mats[key] = mm
        return fx_mats[key]

    def add_fx(m, place):
        # a snapshot of its effects mid-run (fx_shapes), as one shadowless object, plus its lamps
        bm = bmesh.new()
        slots = []

        def paint(geom_verts, look):
            mm = fx_material(*look)
            if mm not in slots:
                slots.append(mm)
            idx = slots.index(mm)
            for f in {f for v in geom_verts for f in v.link_faces}:
                f.material_index = idx

        W = P @ place
        for shape in fx_shapes(m):
            kind = shape[0]
            if kind == "ball":
                _, c, r, look, flat = shape
                M = W @ Matrix.Translation(c) @ Matrix.Diagonal((1, flat, 1, 1))
                paint(bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=max(r, 0.02), matrix=M)["verts"], look)
            elif kind == "rod":
                _, a, b, t, look = shape
                if math.dist(a, b) < 1e-3:
                    continue
                cf, length = along(a, b)
                M = matrix_of({"cf": cf}, place) @ Matrix.Diagonal((t, t, length, 1))
                paint(bmesh.ops.create_cube(bm, size=1.0, matrix=M)["verts"], look)
            elif kind == "box":
                _, c, size, rot, look = shape
                M = matrix_of({"cf": CF.angles(*rot, pos=c)}, place) @ Matrix.Diagonal((*size, 1))
                paint(bmesh.ops.create_cube(bm, size=1.0, matrix=M)["verts"], look)
            elif kind == "ray":
                _, a, b, w0, w1, look = shape
                d = _unit(tuple(b[i] - a[i] for i in range(3)))
                s1 = _unit((d[2], 0, -d[0])) if abs(d[1]) < 0.95 else (1, 0, 0)
                s2 = _unit((d[1] * s1[2] - d[2] * s1[1], d[2] * s1[0] - d[0] * s1[2], d[0] * s1[1] - d[1] * s1[0]))
                for side in (s1, s2):
                    vs = [bm.verts.new(W @ Vector(q)) for q in (_add(a, side, -w0 / 2), _add(a, side, w0 / 2), _add(b, side, w1 / 2), _add(b, side, -w1 / 2))]
                    bm.faces.new(vs)
                    paint(vs, look)
            elif kind == "light":
                _, pos, col, bright, rng, spot, angle = shape
                lamp = bpy.data.lights.new("FXLight", "SPOT" if spot else "POINT")
                lamp.color = tuple(lin(v / 255) for v in col)
                lamp.energy = bright * 60 * rng / 12  # (a Roblox light stops at its Range; a lamp fades for ever)
                lamp.shadow_soft_size = 0.4
                if spot:
                    lamp.spot_size = math.radians(min(angle * 2, 170))
                lamp_obj = bpy.data.objects.new("FXLight", lamp)
                lamp_obj.location = W @ Vector(pos)
                if spot:
                    lamp_obj.rotation_euler = (math.radians(90), 0, 0)  # (facing the front: -z in the game)
                scene.collection.objects.link(lamp_obj)
        mesh = bpy.data.meshes.new(m.name + "FX")
        bm.normal_update()
        bm.to_mesh(mesh)
        bm.free()
        for mm in slots:
            mesh.materials.append(mm)
        obj = bpy.data.objects.new(m.name + "FX", mesh)
        obj.visible_shadow = False
        scene.collection.objects.link(obj)

    cols = 4 if not tile else 1
    gap_x, gap_z = 26.0, 30.0
    for index, name in enumerate(names):
        m = build(name)
        ox = (index % cols - (cols - 1) / 2) * gap_x
        oz = (index // cols) * gap_z
        place = Matrix.Translation((ox, 0, oz))
        bm = bmesh.new()
        slots = []

        def slot(mm):
            if mm not in slots:
                slots.append(mm)
            return slots.index(mm)

        for p in m.parts:
            if p["alpha"] >= 0.99:
                continue
            sx, sy, sz = p["size"]
            M = matrix_of(p, place)
            if p["shape"] == "Block":
                geom = bmesh.ops.create_cube(bm, size=1.0, matrix=M @ Matrix.Diagonal((sx, sy, sz, 1)))
            elif p["shape"] == "Ball":
                d = min(sx, sy, sz)
                geom = bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=d / 2, matrix=M)
            elif p["shape"] == "Cylinder":
                d = min(sy, sz)
                geom = bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=d / 2, radius2=d / 2, depth=sx,
                                             matrix=M @ Matrix.Rotation(math.radians(90), 4, "Y"))
            else:  # Wedge: tall at +z, sloping to -z
                verts = [bm.verts.new(M @ Vector(v)) for v in (
                    (-sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, sz / 2), (-sx / 2, -sy / 2, sz / 2),
                    (-sx / 2, sy / 2, sz / 2), (sx / 2, sy / 2, sz / 2))]
                faces = [bm.faces.new((verts[0], verts[1], verts[2], verts[3])), bm.faces.new((verts[3], verts[2], verts[5], verts[4])),
                         bm.faces.new((verts[0], verts[4], verts[5], verts[1])), bm.faces.new((verts[0], verts[3], verts[4])),
                         bm.faces.new((verts[1], verts[5], verts[2]))]
                geom = {"verts": verts}
                for f in faces:
                    f.material_index = slot(material(p["col"], p["mat"], p["alpha"]))
                continue
            idx = slot(material(p["col"], p["mat"], p["alpha"]))
            for f in {f for v in geom["verts"] for f in v.link_faces}:
                f.material_index = idx
        mesh = bpy.data.meshes.new(name)
        bm.normal_update()
        bm.to_mesh(mesh)
        bm.free()
        for mm in slots:
            mesh.materials.append(mm)
        for poly in mesh.polygons:
            poly.use_smooth = False
        obj = bpy.data.objects.new(name, mesh)
        scene.collection.objects.link(obj)
        if show_fx:
            add_fx(m, place)
        if tile:
            bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, -0.01))
            floor = bpy.context.object
            floor.scale = (3000, 3000, 1)
            floor_mat = material((70, 76, 90), "SmoothPlastic", 0).copy()
            floor_mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85
            floor.data.materials.append(floor_mat)
            continue
        # its name in front of it, and a floor tile under it
        bpy.ops.object.text_add(location=(ox, -(oz + 12.6), 0.05))
        label = bpy.context.object
        label.data.body = "%d  %s" % (ORDER.index(name) + 1, name.upper())
        label.data.align_x = "CENTER"
        label.data.size = 1.7
        label.data.materials.append(material((250, 250, 255), "Neon", 0))
        bpy.ops.mesh.primitive_plane_add(size=1, location=(ox, -(oz + 1.0), -0.01))
        pad = bpy.context.object
        pad.scale = (24.5, 28.5, 1)
        pad.data.materials.append(material((58, 62, 74) if index % 2 == 0 else (64, 68, 80), "SmoothPlastic", 0))
    rows = (len(names) + cols - 1) // cols
    # lights and camera: from behind and above on the runner's right (the side you walk up to)
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 2.2 if show_fx else 3.0
    sun.angle = math.radians(6)
    sun_obj = bpy.data.objects.new("Sun", sun)
    sun_obj.rotation_euler = (math.radians(40), math.radians(15), math.radians(35))
    scene.collection.objects.link(sun_obj)
    fill = bpy.data.lights.new("Fill", "SUN")
    fill.energy = 0.8
    fill_obj = bpy.data.objects.new("Fill", fill)
    fill_obj.rotation_euler = (math.radians(65), 0, math.radians(-140))
    scene.collection.objects.link(fill_obj)
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.26, 0.3, 0.38, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.55 if show_fx else 0.8
    scene.world = world
    if show_fx:
        # bloom round anything glowing (Roblox's Bloom, roughly)
        scene.use_nodes = True
        tree = scene.node_tree
        layers = tree.nodes.get("Render Layers") or tree.nodes.new("CompositorNodeRLayers")
        composite = tree.nodes.get("Composite") or tree.nodes.new("CompositorNodeComposite")
        glare = tree.nodes.new("CompositorNodeGlare")
        glare.glare_type = "BLOOM"
        for socket, value in (("Threshold", 1.0), ("Strength", 0.55), ("Size", 0.6)):
            if socket in glare.inputs:
                glare.inputs[socket].default_value = value
        tree.links.new(layers.outputs["Image"], glare.inputs["Image"])
        tree.links.new(glare.outputs["Image"], composite.inputs["Image"])
    if os.environ.get("THREADS"):
        scene.render.threads_mode = "FIXED"
        scene.render.threads = int(os.environ["THREADS"])
    if tile:
        # frame everything but see-through glows (a light column)
        pts = []
        for p in build(names[0]).parts:
            if p["alpha"] < 0.6 and p["name"] != "LightColumn":
                pts.append(p["cf"].p)
        lo = [min(q[i] for q in pts) for i in range(3)]
        hi = [max(q[i] for q in pts) for i in range(3)]
        mid = Vector([(lo[i] + hi[i]) / 2 for i in range(3)])
        radius = max((Vector(q) - mid).length for q in pts) + 1.0
        cam_data = bpy.data.cameras.new("Cam")
        cam_data.lens = 35
        cam = bpy.data.objects.new("Cam", cam_data)
        fov = 2 * math.atan(36 / 2 / cam_data.lens) * tile[1] / tile[0]
        target = P @ mid
        cam.location = P @ (mid + Vector((1.0, 0.62, 0.62)).normalized() * radius / math.sin(fov / 2) * 0.95)
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(cam)
        scene.camera = cam
        scene.render.engine = "CYCLES"
        scene.cycles.samples = int(os.environ.get("SAMPLES", "48"))
        scene.cycles.use_denoising = True
        scene.render.resolution_x, scene.render.resolution_y = tile
        scene.view_settings.view_transform = "Standard"
        scene.render.filepath = out
        bpy.ops.render.render(write_still=True)
        return
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    width = cols * gap_x
    height = rows * gap_z
    cam_data.ortho_scale = max(width, height) * 1.02
    cam = bpy.data.objects.new("Cam", cam_data)
    center = Vector((0, -((rows - 1) * gap_z / 2 + 2.0), 3.0))
    direction = Vector((0.55, -0.62, 0.62)).normalized()
    cam.location = center + direction * 200
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "CYCLES"
    scene.cycles.samples = int(os.environ.get("SAMPLES", "48"))
    scene.cycles.use_denoising = True
    scene.render.resolution_x = int(os.environ.get("RES", "2400"))
    scene.render.resolution_y = int(int(os.environ.get("RES", "2400")) * (height / width if height > width else 1) * 0.85)
    scene.view_settings.view_transform = "Standard"
    scene.render.filepath = out
    if os.environ.get("RENDER", "1") == "1":
        bpy.ops.render.render(write_still=True)
        print("rendered", out)
    if os.environ.get("SAVE_BLEND", "1") == "1":
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "treadmills.blend"), compress=True)
        print("saved treadmills.blend")


def make_sheet(out, names):
    # the close-ups in `out` on one sheet, four across, with their names
    from PIL import Image, ImageDraw, ImageFont
    w, h, cols = 800, 620, 4
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols, h * rows), (40, 44, 54))
    draw = ImageDraw.Draw(sheet)
    font = None
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",):
        if os.path.exists(path):
            font = ImageFont.truetype(path, 38)
    for i, n in enumerate(names):
        x, y = (i % cols) * w, (i // cols) * h
        sheet.paste(Image.open(os.path.join(out, n + ".png")).convert("RGB").resize((w, h)), (x, y))
        text = "%d  %s" % (ORDER.index(n) + 1, n.upper())
        draw.text((x + 22, y + 16), text, fill=(0, 0, 0), font=font, stroke_width=0)
        draw.text((x + 20, y + 14), text, fill=(255, 255, 255), font=font)
    sheet.save(os.path.join(out, "sheet.png"))
    print("sheet", os.path.join(out, "sheet.png"))


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "-"
    export_path = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != "-" else None
    names = sys.argv[3].split(",") if len(sys.argv) > 3 else ORDER
    for n in names:
        print(n, len(build(n).parts), "parts")
    if export_path:
        export(export_path, ORDER)
    if out.endswith("/"):
        # one close-up each, then a sheet of them with their names (needs PIL)
        os.makedirs(out, exist_ok=True)
        for n in names:
            render(os.path.join(out, n + ".png"), [n], tile=(800, 620))
        try:
            make_sheet(out, ORDER if all(os.path.exists(os.path.join(out, n + ".png")) for n in ORDER) else names)
        except ImportError:
            print("(no PIL: no sheet)")
    elif out != "-":
        render(out, names)
