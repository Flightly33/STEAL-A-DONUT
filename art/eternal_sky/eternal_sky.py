# The Eternal Storm's cosmic sky, made in Blender (Cycles, procedural shaders - no image inputs):
#   sky      the six skybox faces (SkyboxFt/Bk/Lf/Rt/Up/Dn.png, 1024x1024): a deep purple space full of
#            stars, a galaxy band arching over the sky with dust lanes and a glowing core, nebulae
#   disk     disk.png: the black hole's accretion disk from above (spiral streaks, white-hot inside to
#            purple outside, see-through hole and edge) - the game spins it
#   halo     halo.png: the light bent round the black hole (photon ring and lensed arcs), always
#            turned to face the camera
#   galaxy   galaxy.png: a spiral galaxy from above, for the other side of the sky - the game spins it
#   preview  preview frames: all of it put together over a lane, as the game would show it (and
#   back     preview_back.png: turned round, the galaxy)
#   python3 eternal_sky.py <out_dir> <sky|disk|halo|galaxy|preview|back|all> [preview frames] [first frame]
# Needs Blender's Python module (pip install bpy), and Pillow for the skybox faces. The skybox faces follow Roblox's layout as
# measured in Studio: SkyboxFt looks along -Z, SkyboxLf along +X, SkyboxRt along -X, and the Up and
# Dn images are turned a quarter (Up counter-clockwise, Dn clockwise) to undo how Studio shows them.
import bpy, math, os, sys
from mathutils import Matrix, Vector

OUT = sys.argv[1]
WHAT = sys.argv[2] if len(sys.argv) > 2 else "all"
os.makedirs(OUT, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.view_settings.view_transform = "Standard"
    sc.render.image_settings.file_format = "PNG"
    return sc


class Nodes:
    """A small helper for building shader node maths in a node tree."""

    def __init__(self, tree):
        self.t = tree
        self.n = tree.nodes
        self.l = tree.links

    def _plug(self, sock, x):
        if x is None:
            return
        if isinstance(x, (int, float)):
            if hasattr(sock, "default_value") and not isinstance(sock.default_value, float):
                sock.default_value = (x,) * len(sock.default_value)
            else:
                sock.default_value = x
        elif isinstance(x, (tuple, list)):
            sock.default_value = x
        else:
            self.l.new(x, sock)

    def m(self, op, a, b=None, c=None, clamp=False):
        node = self.n.new("ShaderNodeMath")
        node.operation = op
        node.use_clamp = clamp
        for i, x in enumerate((a, b, c)):
            self._plug(node.inputs[i], x)
        return node.outputs[0]

    def v(self, op, a, b=None, scale=None):
        node = self.n.new("ShaderNodeVectorMath")
        node.operation = op
        self._plug(node.inputs[0], a)
        if b is not None:
            self._plug(node.inputs[1], b)
        if scale is not None:
            self._plug(node.inputs["Scale"], scale)
        return node.outputs["Value"] if op in ("DOT_PRODUCT", "LENGTH", "DISTANCE") else node.outputs["Vector"]

    def scale(self, vec, s):
        return self.v("SCALE", vec, scale=s)

    def add(self, *vecs):
        out = vecs[0]
        for x in vecs[1:]:
            out = self.v("ADD", out, x)
        return out

    def mix(self, a, b, t):
        # a + (b - a) * t, for vectors / colours
        return self.v("ADD", a, self.scale(self.v("SUBTRACT", b, a), t))

    def remap(self, x, a, b, c=0.0, d=1.0):
        node = self.n.new("ShaderNodeMapRange")
        node.clamp = True
        self._plug(node.inputs["Value"], x)
        node.inputs["From Min"].default_value = a
        node.inputs["From Max"].default_value = b
        node.inputs["To Min"].default_value = c
        node.inputs["To Max"].default_value = d
        return node.outputs["Result"]

    def noise(self, vec, scale, detail=6.0, rough=0.6, offset=None):
        node = self.n.new("ShaderNodeTexNoise")
        node.noise_dimensions = "3D"
        if offset is not None:
            vec = self.v("ADD", vec, offset)
        self._plug(node.inputs["Vector"], vec)
        node.inputs["Scale"].default_value = scale
        node.inputs["Detail"].default_value = detail
        node.inputs["Roughness"].default_value = rough
        return node.outputs["Fac"]

    def voronoi(self, vec, scale):
        node = self.n.new("ShaderNodeTexVoronoi")
        node.voronoi_dimensions = "3D"
        node.feature = "F1"
        self._plug(node.inputs["Vector"], vec)
        node.inputs["Scale"].default_value = scale
        node.inputs["Randomness"].default_value = 1.0
        return node.outputs["Distance"], node.outputs["Color"]

    def sep(self, vec):
        node = self.n.new("ShaderNodeSeparateXYZ")
        self.l.new(vec, node.inputs[0])
        return node.outputs["X"], node.outputs["Y"], node.outputs["Z"]

    def comb(self, x, y, z):
        node = self.n.new("ShaderNodeCombineXYZ")
        for i, s in enumerate((x, y, z)):
            self._plug(node.inputs[i], s)
        return node.outputs[0]

    def gauss(self, x, width):
        # exp(-(x / width)^2)
        q = self.m("DIVIDE", x, width)
        return self.m("EXPONENT", self.m("MULTIPLY", self.m("MULTIPLY", q, q), -1.0))


def norm(*v):
    length = math.sqrt(sum(c * c for c in v))
    return tuple(c / length for c in v)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


# ---------------------------------------------------------------------------------------------
# The sky: a colour for every direction D (Blender space, Z up)
# ---------------------------------------------------------------------------------------------
BAND_N = norm(0.78, 0.30, 0.55)  # the galaxy band is the great circle at right angles to this


def _on_band(v):
    d = sum(a * b for a, b in zip(v, BAND_N))
    return norm(*[a - d * b for a, b in zip(v, BAND_N)])


BULGE = _on_band((0.2, -0.55, 0.55))  # the band's bright core, well above the horizon


def sky_color(N, D):
    # deep space: nearly black, purple
    base = (0.014, 0.006, 0.034)
    # the galaxy band: a wide glow and a narrow bright middle, clumpy, cut by dark dust lanes
    d = N.v("DOT_PRODUCT", D, BAND_N)
    wide = N.gauss(d, 0.5)
    core = N.gauss(d, 0.16)
    clump = N.remap(N.noise(D, 3.6, 6, 0.6), 0.3, 0.72, 0.35, 1.35)
    fine = N.remap(N.noise(D, 13.0, 8, 0.66, (5.1, 1.7, 3.3)), 0.25, 0.75, 0.45, 1.25)
    dust = N.remap(N.noise(D, 5.0, 10, 0.7, (9.4, 2.2, 7.7)), 0.45, 0.62, 1.0, 0.08)
    lanes = N.m("ADD", 1.0, N.m("MULTIPLY", core, N.m("SUBTRACT", dust, 1.0)))  # 1 outside the core
    glow = N.m("MULTIPLY", N.m("MULTIPLY", N.m("ADD", N.m("MULTIPLY", wide, 0.42), N.m("MULTIPLY", core, 0.8)), clump), N.m("MULTIPLY", fine, lanes))
    toward_bulge = N.v("DOT_PRODUCT", D, BULGE)
    # (stretched along the band: closeness to the core direction, squeezed across the band)
    bulge = N.m("MULTIPLY", N.m("EXPONENT", N.m("MULTIPLY", N.m("SUBTRACT", 1.0, toward_bulge), -9.0)), N.m("MULTIPLY", lanes, core))
    # colour drifts along the band: blue-violet, pink, teal
    drift = N.remap(N.noise(D, 1.2, 3, 0.5, (2.0, 4.0, 6.0)), 0.35, 0.65)
    band_color = N.mix(N.mix((0.4, 0.36, 1.0), (0.95, 0.4, 0.95), drift), (0.3, 0.75, 1.0), N.m("MULTIPLY", N.m("SUBTRACT", 1.0, drift), 0.4))
    band = N.add(
        N.scale(band_color, glow),
        N.scale((1.0, 0.75, 0.95), N.m("MULTIPLY", core, N.m("MULTIPLY", fine, N.m("MULTIPLY", lanes, 0.3)))),
        N.scale((1.0, 0.8, 0.6), N.m("MULTIPLY", bulge, 1.1)),
    )
    # nebulae: big soft clouds, magenta to teal
    cloud = N.remap(N.noise(D, 1.4, 8, 0.62, (3.3, 8.8, 1.2)), 0.44, 0.78)
    cloud = N.m("MULTIPLY", cloud, cloud)
    hue = N.remap(N.noise(D, 2.4, 4, 0.5, (7.0, 3.0, 9.0)), 0.36, 0.64)
    wisps = N.remap(N.noise(D, 7.0, 10, 0.72, (1.0, 6.0, 4.0)), 0.3, 0.75, 0.3, 1.2)
    nebula = N.scale(N.mix((0.95, 0.18, 0.75), (0.12, 0.62, 0.95), hue), N.m("MULTIPLY", N.m("MULTIPLY", cloud, wisps), 0.85))
    # stars: three layers (many faint ones, fewer bright ones, a few big sparkly ones)
    stars = None
    for scale, radius, share, bright in ((150.0, 0.2, 0.32, 0.55), (60.0, 0.13, 0.42, 1.2), (22.0, 0.085, 0.22, 3.0)):
        dist, cell = N.voronoi(D, scale)
        r_, g_, b_ = N.sep(cell)
        shown = N.m("GREATER_THAN", r_, 1.0 - share)
        point = N.remap(dist, radius, 0.0)
        level = N.m("MULTIPLY", N.m("MULTIPLY", point, shown), N.m("MULTIPLY", N.m("ADD", g_, 0.35), bright))
        tint = N.mix(N.mix((0.72, 0.8, 1.0), (1.0, 0.86, 0.7), b_), (1.0, 1.0, 1.0), 0.45)
        layer = N.scale(tint, level)
        stars = layer if stars is None else N.add(stars, layer)
    return N.add(base, band, nebula, stars)


def world_sky(rotate_z=0.0):
    sc = bpy.context.scene
    w = bpy.data.worlds.new("CosmicSky")
    sc.world = w
    w.use_nodes = True
    N = Nodes(w.node_tree)
    coords = N.n.new("ShaderNodeTexCoord")
    mapping = N.n.new("ShaderNodeMapping")
    mapping.vector_type = "VECTOR"
    N.l.new(coords.outputs["Generated"], mapping.inputs["Vector"])
    mapping.inputs["Rotation"].default_value = (0.0, 0.0, rotate_z)
    color = sky_color(N, mapping.outputs["Vector"])
    N.l.new(color, N.n["Background"].inputs["Color"])
    N.n["Background"].inputs["Strength"].default_value = 1.0
    return mapping


# Roblox's six faces: (forward, right, up) in Roblox space (Y up, the camera starts facing -Z),
# then the quarter turns (counter-clockwise) the image gets after rendering.
FACES = {
    "SkyboxFt": ((0, 0, -1), (1, 0, 0), (0, 1, 0), 0),
    "SkyboxBk": ((0, 0, 1), (-1, 0, 0), (0, 1, 0), 0),
    "SkyboxLf": ((1, 0, 0), (0, 0, 1), (0, 1, 0), 0),
    "SkyboxRt": ((-1, 0, 0), (0, 0, -1), (0, 1, 0), 0),
    "SkyboxUp": ((0, 1, 0), (1, 0, 0), (0, 0, 1), 1),
    "SkyboxDn": ((0, -1, 0), (1, 0, 0), (0, 0, -1), -1),
}


def r2b(v):
    # Roblox (x, y, z) -> Blender (x, -z, y)
    return Vector((v[0], -v[2], v[1]))


def render_sky():
    sc = reset()
    world_sky()
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.angle = math.pi / 2
    sc.render.resolution_x = sc.render.resolution_y = 1024
    sc.cycles.samples = 48
    sc.cycles.use_denoising = False  # (it would smear the stars)
    for name, (fwd, right, up, turns) in FACES.items():
        f, r, u = r2b(fwd), r2b(right), r2b(up)
        cam.matrix_world = Matrix((
            (r.x, u.x, -f.x, 0), (r.y, u.y, -f.y, 0), (r.z, u.z, -f.z, 0), (0, 0, 0, 1),
        ))
        raw = os.path.join(OUT, f"_raw_{name}.png")
        sc.render.filepath = raw
        bpy.ops.render.render(write_still=True)
        print("FACE", name, turns)
    finish_sky()


def finish_sky():
    # Check the faces meet (each edge against its neighbour's, before turning), then turn Up and Dn
    import numpy as np
    from PIL import Image

    raw = {name: np.asarray(Image.open(os.path.join(OUT, f"_raw_{name}.png")).convert("RGB"), dtype=np.float32) for name in FACES}
    pairs = [
        ("Ft right / Lf left", raw["SkyboxFt"][:, -1], raw["SkyboxLf"][:, 0]),
        ("Lf right / Bk left", raw["SkyboxLf"][:, -1], raw["SkyboxBk"][:, 0]),
        ("Bk right / Rt left", raw["SkyboxBk"][:, -1], raw["SkyboxRt"][:, 0]),
        ("Rt right / Ft left", raw["SkyboxRt"][:, -1], raw["SkyboxFt"][:, 0]),
        ("Ft top / Up bottom", raw["SkyboxFt"][0], raw["SkyboxUp"][-1]),
        ("Ft bottom / Dn top", raw["SkyboxFt"][-1], raw["SkyboxDn"][0]),
    ]
    for label, a, b in pairs:
        # blur a little (stars are a pixel wide, and neighbours' pixels sit half a pixel apart)
        k = np.ones(9) / 9
        sa = np.stack([np.convolve(a[:, c], k, "same") for c in range(3)], 1)
        sb = np.stack([np.convolve(b[:, c], k, "same") for c in range(3)], 1)
        seam = float(np.abs(sa - sb).mean())
        unrelated = float(np.abs(sa - sb[::-1]).mean())
        print(f"SEAM {label}: {seam:.2f} (flipped {unrelated:.2f})")
        assert seam < unrelated * 0.5, "faces don't meet: " + label
    for name, (_, _, _, turns) in FACES.items():
        Image.fromarray(np.rot90(raw[name], turns).astype(np.uint8)).save(os.path.join(OUT, f"{name}.png"))
        os.remove(os.path.join(OUT, f"_raw_{name}.png"))


# ---------------------------------------------------------------------------------------------
# Flat textures: an emission plane seen straight from above, with a see-through background
# ---------------------------------------------------------------------------------------------
def flat_texture(name, build, size=1024):
    sc = reset()
    sc.render.film_transparent = True
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.cycles.samples = 24
    sc.cycles.use_denoising = False
    bpy.ops.mesh.primitive_plane_add(size=2)
    plane = bpy.context.active_object
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    N = Nodes(mat.node_tree)
    for node in list(N.n):
        N.n.remove(node)
    coords = N.n.new("ShaderNodeTexCoord")
    # p in [-1, 1] across the plane
    p = N.v("SUBTRACT", N.scale(coords.outputs["Generated"], 2.0), (1.0, 1.0, 0.0))
    x, y, _ = N.sep(p)
    color, alpha = build(N, x, y)
    emission = N.n.new("ShaderNodeEmission")
    N.l.new(color, emission.inputs["Color"])
    emission.inputs["Strength"].default_value = 1.0
    clear = N.n.new("ShaderNodeBsdfTransparent")
    mix = N.n.new("ShaderNodeMixShader")
    N.l.new(alpha, mix.inputs["Fac"])
    N.l.new(clear.outputs[0], mix.inputs[1])
    N.l.new(emission.outputs[0], mix.inputs[2])
    out = N.n.new("ShaderNodeOutputMaterial")
    N.l.new(mix.outputs[0], out.inputs["Surface"])
    plane.data.materials.append(mat)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.0
    cam.location = (0, 0, 5)
    sc.render.filepath = os.path.join(OUT, f"{name}.png")
    bpy.ops.render.render(write_still=True)
    print("TEXTURE", name)


def polar(N, x, y):
    r = N.m("SQRT", N.m("ADD", N.m("MULTIPLY", x, x), N.m("MULTIPLY", y, y)))
    a = N.m("ARCTAN2", y, x)
    return r, a


def ramp(N, t, stops):
    # piecewise-linear colour ramp over t in [0, 1]: stops = [(t, (r, g, b)), ...]
    color = N.comb(*stops[0][1])
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        k = N.remap(t, t0, t1)
        color = N.mix(color, N.comb(*c1), k)
    return color


DISK_STOPS = [
    (0.0, (1.0, 1.0, 1.0)), (0.07, (1.0, 0.96, 0.82)), (0.22, (1.0, 0.8, 0.38)), (0.4, (1.0, 0.5, 0.2)),
    (0.6, (0.98, 0.26, 0.5)), (0.8, (0.62, 0.2, 0.98)), (1.0, (0.32, 0.12, 0.7)),
]


def build_disk(N, x, y):
    # streaks wound round in a spiral (seamless: noise on cos/sin of the spiral angle), white-hot
    # inside to purple outside, a see-through hole in the middle and a soft outer edge
    r, a = polar(N, x, y)
    R_IN, R_OUT = 0.15, 0.98
    t = N.remap(r, R_IN, R_OUT)
    spiral = N.m("ADD", a, N.m("MULTIPLY", N.m("LOGARITHM", N.m("MAXIMUM", r, 0.01), math.e), 3.2))
    swirl = N.comb(N.m("COSINE", spiral), N.m("SINE", spiral), N.m("MULTIPLY", r, 9.0))
    streaks = N.remap(N.noise(swirl, 2.2, 8, 0.62), 0.32, 0.72, 0.35, 1.15)
    fine = N.remap(N.noise(N.comb(N.m("COSINE", spiral), N.m("SINE", spiral), N.m("MULTIPLY", r, 40.0)), 3.0, 4, 0.5, (4.0, 1.0, 2.0)), 0.3, 0.7, 0.7, 1.15)
    arms = N.m("ADD", 0.5, N.m("MULTIPLY", N.m("POWER", N.m("ADD", 0.5, N.m("MULTIPLY", N.m("COSINE", N.m("MULTIPLY", spiral, 3.0)), 0.5)), 3.0), 0.95))
    light = N.m("MULTIPLY", N.m("MULTIPLY", streaks, fine), arms)
    color = N.scale(ramp(N, t, DISK_STOPS), N.m("MINIMUM", N.m("MULTIPLY", light, 1.3), 1.7))
    inner = N.remap(r, R_IN, R_IN + 0.025)
    outer = N.m("POWER", N.remap(r, R_OUT, R_IN), 0.9)
    alpha = N.m("MINIMUM", N.m("MULTIPLY", N.m("MULTIPLY", inner, outer), N.m("MULTIPLY", N.m("MINIMUM", light, 1.0), 1.7)), 1.0)
    return color, alpha


HALO_RING = 0.3  # the photon ring's radius (the game sizes the halo so this sits just outside the shadow)


def build_halo(N, x, y):
    # the photon ring: thin and white-hot, with the light from the far side of the disk bent up over
    # the top and under the bottom in a broad band, and a soft purple glow round it all
    r, a = polar(N, x, y)
    ring = N.gauss(N.m("SUBTRACT", r, HALO_RING), 0.012)
    s = N.m("ABSOLUTE", N.m("SINE", a))  # 1 at the top and bottom
    band_r = N.m("ADD", HALO_RING + 0.05, N.m("MULTIPLY", s, 0.035))
    band = N.m("MULTIPLY", N.gauss(N.m("SUBTRACT", r, band_r), N.m("ADD", 0.02, N.m("MULTIPLY", s, 0.05))), N.m("ADD", 0.25, N.m("MULTIPLY", s, 0.75)))
    flow = N.remap(N.noise(N.comb(N.m("COSINE", a), N.m("SINE", a), N.m("MULTIPLY", r, 14.0)), 3.0, 8, 0.6), 0.3, 0.7, 0.45, 1.2)
    band = N.m("MULTIPLY", band, flow)
    glow = N.m("MULTIPLY", N.gauss(N.m("MAXIMUM", N.m("SUBTRACT", r, HALO_RING), 0.0), 0.22), 0.4)
    t = N.remap(r, HALO_RING, HALO_RING + 0.2)
    band_color = ramp(N, t, DISK_STOPS)
    color = N.add(N.scale((1.0, 0.97, 0.9), ring), N.scale(band_color, band), N.scale((0.62, 0.32, 1.0), glow))
    alpha = N.m("MINIMUM", N.m("ADD", N.m("ADD", ring, band), glow), 1.0)
    # nothing inside the shadow (the black core covers it in the game)
    alpha = N.m("MULTIPLY", alpha, N.remap(r, HALO_RING - 0.03, HALO_RING - 0.01))
    return color, alpha


def build_galaxy(N, x, y):
    # a two-armed spiral galaxy: a warm bright bulge, blue-purple arms with dark dust lanes along
    # their inner edges, pink star-forming knots, everything fading out at the rim
    r, a = polar(N, x, y)
    rr = N.m("MAXIMUM", r, 0.01)
    psi = N.m("SUBTRACT", a, N.m("MULTIPLY", N.m("LOGARITHM", rr, math.e), 2.6))
    arm = N.m("POWER", N.m("ADD", 0.5, N.m("MULTIPLY", N.m("COSINE", N.m("MULTIPLY", psi, 2.0)), 0.5)), 1.8)
    lane = N.m("POWER", N.m("ADD", 0.5, N.m("MULTIPLY", N.m("COSINE", N.m("MULTIPLY", N.m("ADD", psi, 0.45), 2.0)), 0.5)), 6.0)
    clumps = N.remap(N.noise(N.comb(x, y, 0.0), 9.0, 8, 0.65), 0.3, 0.75, 0.4, 1.3)
    falloff = N.m("EXPONENT", N.m("MULTIPLY", r, -2.1))
    edge = N.remap(r, 0.98, 0.7)
    disk = N.m("MULTIPLY", N.m("MULTIPLY", N.m("ADD", 0.12, N.m("MULTIPLY", arm, 0.95)), clumps), N.m("MULTIPLY", falloff, edge))
    disk = N.m("MULTIPLY", disk, N.m("SUBTRACT", 1.0, N.m("MULTIPLY", lane, 0.7)))
    bulge = N.gauss(r, 0.13)
    dist, cell = N.voronoi(N.comb(x, y, 0.0), 70.0)
    cr, _, _ = N.sep(cell)
    knots = N.m("MULTIPLY", N.m("MULTIPLY", N.remap(dist, 0.16, 0.0), N.m("GREATER_THAN", cr, 0.72)), N.m("MULTIPLY", arm, edge))
    arm_color = N.mix((0.45, 0.62, 1.0), (0.85, 0.4, 1.0), N.remap(r, 0.2, 0.8))  # blue inside, violet out
    color = N.add(
        N.scale(arm_color, N.m("MULTIPLY", disk, 2.6)),
        N.scale((1.0, 0.86, 0.62), N.m("MULTIPLY", bulge, 1.3)),
        N.scale((1.0, 0.5, 0.85), N.m("MULTIPLY", knots, 1.4)),
    )
    alpha = N.m("MINIMUM", N.m("ADD", N.m("ADD", N.m("MULTIPLY", disk, 2.4), bulge), knots), 1.0)
    return color, alpha


# ---------------------------------------------------------------------------------------------
# Preview: the storm sky over a lane, as the game puts it together (the hole spins, the sky turns)
# ---------------------------------------------------------------------------------------------
def textured_plane(name, image_path, size, glow=2.0):
    bpy.ops.mesh.primitive_plane_add(size=size)
    plane = bpy.context.active_object
    plane.name = name
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    N = Nodes(mat.node_tree)
    for node in list(N.n):
        N.n.remove(node)
    tex = N.n.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(image_path)
    emission = N.n.new("ShaderNodeEmission")
    N.l.new(tex.outputs["Color"], emission.inputs["Color"])
    emission.inputs["Strength"].default_value = glow
    clear = N.n.new("ShaderNodeBsdfTransparent")
    mix = N.n.new("ShaderNodeMixShader")
    N.l.new(tex.outputs["Alpha"], mix.inputs["Fac"])
    N.l.new(clear.outputs[0], mix.inputs[1])
    N.l.new(emission.outputs[0], mix.inputs[2])
    out = N.n.new("ShaderNodeOutputMaterial")
    N.l.new(mix.outputs[0], out.inputs["Surface"])
    plane.data.materials.append(mat)
    return plane


def look_rotation(forward, up=Vector((0, 0, 1))):
    # a rotation whose local -Z looks along `forward` (Blender cameras and our planes' normals)
    f = forward.normalized()
    r = f.cross(up).normalized()
    u = r.cross(f).normalized()
    return Matrix(((r.x, u.x, -f.x), (r.y, u.y, -f.y), (r.z, u.z, -f.z))).to_4x4()


def render_preview(frames, size, back=False, start=0):
    sc = reset()
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.cycles.samples = 16
    sc.cycles.use_denoising = True
    mapping = world_sky()
    # a lane: grass with dark walls running away from you, the way you run out of the lobby
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0))
    ground = bpy.context.active_object
    ground.scale = (90, 4000, 1)
    gmat = bpy.data.materials.new("Grass")
    gmat.use_nodes = True
    gb = gmat.node_tree.nodes["Principled BSDF"]
    gb.inputs["Base Color"].default_value = (0.09, 0.32, 0.05, 1)
    gb.inputs["Roughness"].default_value = 0.9
    ground.data.materials.append(gmat)
    for side in (-1, 1):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(side * 50, 0, 9))
        wall = bpy.context.active_object
        wall.scale = (10, 4000, 18)
        wmat = bpy.data.materials.new("Wall")
        wmat.use_nodes = True
        wb = wmat.node_tree.nodes["Principled BSDF"]
        wb.inputs["Base Color"].default_value = (0.12, 0.05, 0.1, 1)
        wall.data.materials.append(wmat)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 0.6
    sun.data.color = (0.75, 0.6, 1.0)
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    sc.collection.objects.link(sun)

    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens_unit = "FOV"
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle = math.radians(70)  # (Roblox's camera: 70 degrees top to bottom)
    cam.data.clip_end = 20000
    eye = Vector((0, 0, 8))
    # the hole hangs ahead of you (down the lane = Blender -Y) and up in the sky, where the game
    # puts it (client/StormFX: HOLE_DISTANCE studs away, HOLE_ELEVATION degrees up, CORE_RADIUS)
    elev = math.radians(28)
    ahead = Vector((0, -math.cos(elev), math.sin(elev)))
    center = eye + ahead * 1250
    cam.matrix_world = Matrix.Translation(eye) @ look_rotation(Vector((0, -1, math.tan(math.radians(16)))))
    # black core, disk (nearly edge-on, leaning towards you), halo facing you
    bpy.ops.mesh.primitive_uv_sphere_add(radius=190, location=center, segments=48, ring_count=24)
    core = bpy.context.active_object
    cmat = bpy.data.materials.new("Core")
    cmat.use_nodes = True
    cb = cmat.node_tree.nodes["Principled BSDF"]
    cb.inputs["Base Color"].default_value = (0, 0, 0, 1)
    cb.inputs["Roughness"].default_value = 1
    cb.inputs["Specular IOR Level"].default_value = 0
    core.data.materials.append(cmat)
    disk = textured_plane("Disk", os.path.join(OUT, "disk.png"), 2048, glow=1.6)
    halo = textured_plane("Halo", os.path.join(OUT, "halo.png"), 2 * 190 * 1.04 / HALO_RING, glow=1.8)
    to_eye = (eye - center).normalized()
    # tipped so you see it from 12 degrees above its edge (DISK_VIEW): its top faces you
    tip = math.radians(28 + 12)
    disk_up = Vector((0, math.sin(tip), math.cos(tip)))
    disk_base = Matrix.Translation(center) @ look_rotation(-disk_up, Vector((0, -1, 0)))
    halo.matrix_world = Matrix.Translation(center) @ look_rotation(-to_eye)
    # the galaxy behind you (GALAXY_DISTANCE, GALAXY_ELEVATION, seen 50 degrees from edge-on)
    up = math.radians(35)
    lean = math.radians(35 + 50)
    galaxy = textured_plane("Galaxy", os.path.join(OUT, "galaxy.png"), 1600, glow=1.4)
    galaxy.matrix_world = Matrix.Translation(eye + Vector((0, math.cos(up), math.sin(up))) * 1700) @ look_rotation(-Vector((0, -math.sin(lean), math.cos(lean))))
    if back:
        cam.matrix_world = Matrix.Translation(eye) @ look_rotation(Vector((0, 1, math.tan(math.radians(20)))))
        sc.render.filepath = os.path.join(OUT, "preview_back.png")
        bpy.ops.render.render(write_still=True)
        print("PREVIEW back")
        return
    os.makedirs(os.path.join(OUT, "preview"), exist_ok=True)
    # one loop: the disk turns a third of a turn (its three spiral arms line up again)
    for f in range(start, frames):
        t = f / frames
        disk.matrix_world = disk_base @ Matrix.Rotation(-t * 2 * math.pi / 3, 4, "Z")
        sc.render.filepath = os.path.join(OUT, "preview", f"f{f:03d}.png")
        bpy.ops.render.render(write_still=True)
    print("PREVIEW", frames)


if WHAT in ("sky", "all"):
    render_sky()
if WHAT in ("disk", "all"):
    flat_texture("disk", build_disk)
if WHAT in ("halo", "all"):
    flat_texture("halo", build_halo)
if WHAT in ("galaxy", "all"):
    flat_texture("galaxy", build_galaxy)
if WHAT in ("preview", "all"):
    render_preview(int(sys.argv[3]) if len(sys.argv) > 3 else 24, (960, 540), start=int(sys.argv[4]) if len(sys.argv) > 4 else 0)
if WHAT in ("back", "all"):
    render_preview(1, (960, 540), back=True)
