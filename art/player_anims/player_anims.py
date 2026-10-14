# Player cutscene animations: the moves YOUR character makes in the opening scene and the Mythic box
# opening, keyframed in Blender on a blocky R15 avatar (every joint: waist, neck, shoulders,
# elbows, wrists, hips, knees and ankles), with Blender's smooth (Bezier) in-betweens.
#
#   python3 player_anims.py [export.luau] [--render out.mp4] [--blend out.blend]
#   e.g. python3 player_anims.py ../../src/shared/PlayerAnimData.luau --render preview.mp4
#
# The rig is a tree of joints (empties) standing where a Roblox R15 avatar's joints are, each at
# rest with no rotation, like a Roblox rig's Motor6Ds - so a joint's rotation here IS its
# Motor6D.Transform in the game. The export samples every animation 20 times a second and writes
# each joint's rotation (in Roblox's axes) to src/shared/PlayerAnimData.luau: client/PlayerAnims
# plays them on your real avatar (R15 as they are; R6 avatars get the same moves on their six
# joints). To change a move: change its keys here, run this again.
# Needs Blender's Python module (pip install bpy). The render needs ffmpeg (imageio-ffmpeg, or the
# FFMPEG environment variable pointing at it); it renders with Cycles on the CPU (a few minutes).
import math, os, sys, json, subprocess, tempfile, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
FPS = 30  # Blender's timeline
SAMPLE = 20  # samples a second in the export

# ---- the rig ---------------------------------------------------------------------------------
# Blender axes: the avatar faces +Y, +Z is up, +X is its right (Roblox: faces -Z, +Y up, +X right).
# Each joint: (name, parent, pivot (x, y, z) in studs, box centre, box size, colour)
YELLOW, BLUE, GREEN, DARK = (1.0, 0.82, 0.25), (0.13, 0.42, 0.85), (0.35, 0.68, 0.24), (0.18, 0.18, 0.22)
JOINTS = [
    ("LowerTorso", None, (0, 0, 2.2), (0, 0, 2.2), (2, 1, 0.4), BLUE),
    ("UpperTorso", "LowerTorso", (0, 0, 2.4), (0, 0, 3.2), (2, 1, 1.6), BLUE),
    ("Head", "UpperTorso", (0, 0, 4.0), (0, 0, 4.6), (1.2, 1.2, 1.2), YELLOW),
    ("RightUpperArm", "UpperTorso", (1.5, 0, 3.8), (1.5, 0, 3.3), (1, 1, 1.1), YELLOW),
    ("RightLowerArm", "RightUpperArm", (1.5, 0, 2.75), (1.5, 0, 2.3), (0.95, 0.95, 1.0), YELLOW),
    ("RightHand", "RightLowerArm", (1.5, 0, 1.8), (1.5, 0, 1.65), (0.9, 0.9, 0.3), YELLOW),
    ("LeftUpperArm", "UpperTorso", (-1.5, 0, 3.8), (-1.5, 0, 3.3), (1, 1, 1.1), YELLOW),
    ("LeftLowerArm", "LeftUpperArm", (-1.5, 0, 2.75), (-1.5, 0, 2.3), (0.95, 0.95, 1.0), YELLOW),
    ("LeftHand", "LeftLowerArm", (-1.5, 0, 1.8), (-1.5, 0, 1.65), (0.9, 0.9, 0.3), YELLOW),
    ("RightUpperLeg", "LowerTorso", (0.5, 0, 2.0), (0.5, 0, 1.45), (1, 1, 1.1), GREEN),
    ("RightLowerLeg", "RightUpperLeg", (0.5, 0, 0.9), (0.5, 0, 0.5), (0.95, 0.95, 0.8), GREEN),
    ("RightFoot", "RightLowerLeg", (0.5, 0, 0.2), (0.5, 0.12, 0.1), (0.95, 1.2, 0.2), DARK),
    ("LeftUpperLeg", "LowerTorso", (-0.5, 0, 2.0), (-0.5, 0, 1.45), (1, 1, 1.1), GREEN),
    ("LeftLowerLeg", "LeftUpperLeg", (-0.5, 0, 0.9), (-0.5, 0, 0.5), (0.95, 0.95, 0.8), GREEN),
    ("LeftFoot", "LeftLowerLeg", (-0.5, 0, 0.2), (-0.5, 0.12, 0.1), (0.95, 1.2, 0.2), DARK),
]
NAMES = [j[0] for j in JOINTS]

# How to read the angles below (degrees, Blender's X / Y / Z):
#   arms and legs:  X+ swings the limb up in front of you; Y swings it out to the side (right
#                   side: Y-, left side: Y+); elbows X+ bend the forearm up, knees X- bend the shin
#                   back, feet X+ lift the toes
#   torso and head: X- leans / nods FORWARD, X+ leans back (looks up); Z+ turns to your left
def mirror(pose):
    """Copy every Right* joint's angles to its Left* twin (side-to-side angles flipped)."""
    out = dict(pose)
    for name, (x, y, z) in pose.items():
        if name.startswith("Right"):
            out["Left" + name[5:]] = (x, -y, -z)
    return out


# ---- the animations ---------------------------------------------------------------------------
# name: (loop, [(time, {joint: (x, y, z)}), ...]); joints left out are at rest at that key.
REST = {"RightUpperArm": (4, -2, 0), "LeftUpperArm": (4, 2, 0)}

ANIMS = {}

# Asking the baker for a box: lean in a little, a friendly open hand, a nod
ANIMS["Ask"] = (False, [
    (0.0, dict(REST)),
    (0.3, {**REST, "UpperTorso": (-6, 0, 0), "Head": (-8, 0, 0), "RightUpperArm": (52, 8, 0), "RightLowerArm": (55, 0, 0), "RightHand": (-15, 0, 0)}),
    (0.6, {**REST, "UpperTorso": (-4, 0, 2), "Head": (4, 0, 4), "RightUpperArm": (40, 4, 0), "RightLowerArm": (38, 0, 0), "RightHand": (-10, 0, 0), "LeftUpperArm": (10, 4, 0)}),
    (0.95, {**REST, "UpperTorso": (-7, 0, 0), "Head": (-10, 0, 0), "RightUpperArm": (58, 10, 0), "RightLowerArm": (58, 0, 0), "RightHand": (-18, 0, 0)}),
    (1.3, {**REST, "Head": (-2, 0, 0), "RightUpperArm": (24, 4, 0), "RightLowerArm": (22, 0, 0)}),
    (1.6, dict(REST)),
])

# Furious: hunched over, fists clenched out at your sides, stamping one foot then the other,
# shaking your head
_fists = mirror({"UpperTorso": (-10, 0, 0), "RightUpperArm": (14, -22, 0), "RightLowerArm": (40, 0, 0), "RightHand": (12, 0, 0)})
ANIMS["Angry"] = (True, [
    (0.0, {**_fists, "Head": (-12, 0, 0)}),
    (0.22, {**mirror({"UpperTorso": (-12, 0, 0), "RightUpperArm": (24, -20, 0), "RightLowerArm": (52, 0, 0), "RightHand": (12, 0, 0)}), "Head": (-14, 0, 10), "LowerTorso": (-3, 0, 0), "RightUpperLeg": (42, 0, 0), "RightLowerLeg": (-50, 0, 0), "RightFoot": (12, 0, 0)}),
    (0.42, {**_fists, "Head": (-14, 0, -10), "LowerTorso": (-1, 0, 0)}),
    (0.5, {**_fists, "Head": (-12, 0, 8)}),
    (0.72, {**mirror({"UpperTorso": (-12, 0, 0), "RightUpperArm": (24, -20, 0), "RightLowerArm": (52, 0, 0), "RightHand": (12, 0, 0)}), "Head": (-14, 0, -10), "LowerTorso": (-3, 0, 0), "LeftUpperLeg": (42, 0, 0), "LeftLowerLeg": (-50, 0, 0), "LeftFoot": (12, 0, 0)}),
    (0.92, {**_fists, "Head": (-14, 0, 8), "LowerTorso": (-1, 0, 0)}),
    (1.0, {**_fists, "Head": (-12, 0, 0)}),
])

# Yelling after Domer: leaning in, one fist up in the air shaking, the other arm back, chin up
_yell = {"UpperTorso": (-14, 0, -6), "Head": (12, 0, 0), "LeftUpperArm": (-28, 22, 0), "LeftLowerArm": (30, 0, 0), "LeftHand": (10, 0, 0), "LeftUpperLeg": (16, 0, 0), "LeftLowerLeg": (-10, 0, 0), "RightUpperLeg": (-12, 0, 0), "RightFoot": (8, 0, 0)}
ANIMS["Yell"] = (True, [
    (0.0, {**_yell, "RightUpperArm": (166, -10, 0), "RightLowerArm": (18, 0, 0)}),
    (0.15, {**_yell, "Head": (16, 0, 4), "RightUpperArm": (148, -12, 0), "RightLowerArm": (52, 0, 0)}),
    (0.3, {**_yell, "RightUpperArm": (168, -8, 0), "RightLowerArm": (14, 0, 0)}),
    (0.45, {**_yell, "Head": (16, 0, -4), "RightUpperArm": (148, -12, 0), "RightLowerArm": (52, 0, 0)}),
    (0.6, {**_yell, "RightUpperArm": (166, -10, 0), "RightLowerArm": (18, 0, 0)}),
])

# Out of puff: bent right over, hands on your knees, chest heaving, looking up
def _pant(rise):
    return mirror({
        "LowerTorso": (-15, 0, 0),
        "UpperTorso": (-30 + rise, 0, 0),
        "RightUpperArm": (52 - rise * 0.5, 4, 0), "RightLowerArm": (14, 0, 0), "RightHand": (-10, 0, 0),
        "RightUpperLeg": (34, 0, 0), "RightLowerLeg": (-32, 0, 0), "RightFoot": (13, 0, 0),
    }) | {"Head": (26 - rise * 0.4, 0, 0)}
ANIMS["Pant"] = (True, [(0.0, _pant(0)), (0.4, _pant(9)), (0.9, _pant(0))])

# Standing back up: straightening, a little stretch back, arms down
ANIMS["StandUp"] = (False, [
    (0.0, _pant(0)),
    (0.45, {**REST, "UpperTorso": (8, 0, 0), "Head": (-4, 0, 0), "RightUpperArm": (10, -6, 0), "LeftUpperArm": (10, 6, 0), "RightLowerArm": (10, 0, 0), "LeftLowerArm": (10, 0, 0)}),
    (0.9, dict(REST)),
])

# Seeing the treadmill: a little start (leaning back, hands up), then pointing at it
ANIMS["Look"] = (False, [
    (0.0, dict(REST)),
    (0.35, {**mirror({"RightUpperArm": (30, -14, 0), "RightLowerArm": (40, 0, 0)}), "UpperTorso": (7, 0, 0), "Head": (9, 0, 0)}),
    (0.8, {**REST, "UpperTorso": (-4, 0, 0), "Head": (-2, 0, 0), "RightUpperArm": (86, 6, 0), "RightLowerArm": (6, 0, 0), "RightHand": (0, 0, 0), "LeftUpperArm": (8, 4, 0)}),
    (1.6, {**REST, "UpperTorso": (-5, 0, 0), "Head": (-3, 0, 0), "RightUpperArm": (88, 6, 0), "RightLowerArm": (4, 0, 0), "LeftUpperArm": (8, 4, 0)}),
])

# Mythic box: leaning in to watch it rattle, hands half up (itching to open it), knees soft,
# bobbing a little
def _watch(k):
    return {**mirror({"RightUpperArm": (22 + 4 * k, 6, 0), "RightLowerArm": (34 + 6 * k, 0, 0), "RightHand": (-8, 0, 0), "RightUpperLeg": (6 + 4 * k, 0, 0), "RightLowerLeg": (-8 - 6 * k, 0, 0), "RightFoot": (2 + 2 * k, 0, 0)}), "UpperTorso": (-8 - 2 * k, 0, 0), "Head": (-16 - 2 * k, 0, 5 * k)}
ANIMS["Watch"] = (True, [(0.0, _watch(0)), (0.6, _watch(1)), (1.2, _watch(0))])

# Mythic box: bending down to the lid, both hands on it
_reach = {**mirror({"RightUpperArm": (72, 10, 0), "RightLowerArm": (24, 0, 0), "RightHand": (-10, 0, 0), "RightUpperLeg": (14, 0, 0), "RightLowerLeg": (-24, 0, 0), "RightFoot": (10, 0, 0)}), "LowerTorso": (-8, 0, 0), "UpperTorso": (-22, 0, 0), "Head": (-14, 0, 0)}
ANIMS["Reach"] = (False, [(0.0, dict(REST)), (0.45, _reach)])

# The light bursts out: flinching back, arms crossed in front of your face, trembling
def _shield(k):
    # (upper arms out in front, level with your chest; forearms up and crossed in front of your face)
    return {**mirror({"RightUpperArm": (78 + 3 * k, 30, 0), "RightLowerArm": (96 - 4 * k, 0, 0), "RightHand": (-8, 0, 0)}), "UpperTorso": (13 + k, 0, 0), "Head": (-8, 0, 14), "RightUpperLeg": (-9, 0, 0), "RightFoot": (6, 0, 0)}
ANIMS["Shield"] = (True, [(0.0, _shield(0)), (0.15, _shield(1)), (0.3, _shield(-1)), (0.45, _shield(1)), (0.6, _shield(0))])

# The donut leaps out: knocked back, arms flailing, legs up, landing sitting on the ground
# (the game moves you down and back; this is the body), leaning back on your hands
_sit = {**mirror({"RightUpperArm": (-36, -16, 0), "RightLowerArm": (-4, 0, 0), "RightHand": (-20, 0, 0), "RightUpperLeg": (70, -6, 0), "RightLowerLeg": (-12, 0, 0), "RightFoot": (-62, 0, 0)}), "LowerTorso": (20, 0, 0), "UpperTorso": (0, 0, 0), "Head": (-16, 0, 0)}
ANIMS["Fall"] = (False, [
    (0.0, _shield(0)),
    (0.14, {**mirror({"RightUpperArm": (158, -38, 0), "RightLowerArm": (24, 0, 0)}), "UpperTorso": (26, 0, 0), "Head": (14, 0, 0), "RightUpperLeg": (34, 0, 0), "RightLowerLeg": (-20, 0, 0), "LeftUpperLeg": (-12, 0, 0)}),
    (0.34, {**mirror({"RightUpperArm": (60, -46, 0), "RightLowerArm": (30, 0, 0), "RightUpperLeg": (66, 0, 0), "RightLowerLeg": (-8, 0, 0), "RightFoot": (-30, 0, 0)}), "LowerTorso": (12, 0, 0), "UpperTorso": (24, 0, 0), "Head": (8, 0, 0)}),
    (0.55, _sit),
])

# Sitting there, staring at the donut: breathing, a little tilt of the head
ANIMS["Sit"] = (True, [
    (0.0, _sit),
    (1.0, {**_sit, "UpperTorso": (-3, 0, 0), "Head": (-12, 0, 6), "RightUpperArm": (-33, -16, 0), "LeftUpperArm": (-33, 16, 0)}),
    (2.0, _sit),
])

ORDER = ["Ask", "Angry", "Yell", "Pant", "StandUp", "Look", "Watch", "Reach", "Shield", "Fall", "Sit"]


# ---- building it in Blender -------------------------------------------------------------------
def build():
    import bpy
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    objs = {}
    for name, parent, pivot, centre, size, colour in JOINTS:
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = "PLAIN_AXES"
        e.empty_display_size = 0.3
        scene.collection.objects.link(e)
        e.rotation_mode = "XYZ"
        if parent:
            e.parent = objs[parent]
            pp = [j for j in JOINTS if j[0] == parent][0][2]
            e.location = tuple(pivot[i] - pp[i] for i in range(3))
        else:
            e.location = pivot
        e["rest"] = list(e.location)
        # the block (a child of the joint, so it moves with it)
        bpy.ops.mesh.primitive_cube_add(size=1)
        block = bpy.context.active_object
        block.name = name + "_Block"
        block.scale = size
        block.parent = e
        block.location = tuple(centre[i] - pivot[i] for i in range(3))
        mat = bpy.data.materials.new(name + "_Mat")
        mat.diffuse_color = (*colour, 1)
        block.data.materials.append(mat)
        objs[name] = e
    # the animations, one after another on the timeline (a second's gap between them)
    ranges = {}
    frame = 1
    for anim in ORDER:
        loop, keys = ANIMS[anim]
        length = keys[-1][0]
        start = frame
        for t, pose in keys:
            f = start + t * FPS
            for name in NAMES:
                x, y, z = pose.get(name, (0, 0, 0))
                e = objs[name]
                e.rotation_euler = (math.radians(x), math.radians(y), math.radians(z))
                e.keyframe_insert("rotation_euler", frame=f)
        ranges[anim] = (start, length, loop)
        frame = start + length * FPS + FPS
    # smooth in-betweens: Bezier, eased in and out of every key
    for e in objs.values():
        ad = e.animation_data
        if ad and ad.action:
            curves = getattr(ad.action, "fcurves", None)
            if curves is None:  # (Blender 4.4+: layered actions)
                curves = [c for layer in ad.action.layers for strip in layer.strips for bag in strip.channelbags for c in bag.fcurves]
            for c in curves:
                for k in c.keyframe_points:
                    k.interpolation = "BEZIER"
                    k.handle_left_type = "AUTO_CLAMPED"
                    k.handle_right_type = "AUTO_CLAMPED"
    scene.frame_start, scene.frame_end = 1, int(frame)
    return objs, ranges


# Blender -> Roblox: (x, y, z) -> (x, z, -y); a rotation quaternion (w, x, y, z) -> (w, x, z, -y)
def to_roblox_quat(q):
    return (q.x, q.z, -q.y, q.w)


def sample(objs, ranges):
    import bpy
    scene = bpy.context.scene
    out = {}
    for anim in ORDER:
        start, length, loop = ranges[anim]
        count = max(2, int(round(length * SAMPLE)) + 1)
        frames = []
        for i in range(count):
            t = min(length, i / SAMPLE)
            f = start + t * FPS
            scene.frame_set(int(math.floor(f)), subframe=f - math.floor(f))
            row = []
            for name in NAMES:
                q = objs[name].rotation_euler.to_quaternion()
                row.append([round(v, 4) for v in to_roblox_quat(q)])
            frames.append(row)
        out[anim] = {"Length": length, "Loop": loop, "Frames": frames}
    return out


def export_luau(data, path):
    lines = [
        "--[[",
        "\tPlayerAnimData: your character's cutscene moves (the opening scene, the Mythic box opening),",
        "\tkeyframed in Blender: art/player_anims/player_anims.py writes this file - change them there",
        "\tand run it again, don't edit by hand.",
        "",
        "\tAnims[name] = { Length (seconds), Loop, Frames }: Frames are sampled " + str(SAMPLE) + " times a second; each",
        "\tframe is every R15 joint's rotation (in Joints order) as a quaternion { x, y, z, w } in Roblox's",
        "\taxes - its Motor6D.Transform (client/PlayerAnims plays them).",
        "]]",
        "",
        "local PlayerAnimData = {}",
        "",
        "PlayerAnimData.Rate = " + str(SAMPLE),
        "PlayerAnimData.Joints = { " + ", ".join('"%s"' % n for n in NAMES) + " }",
        "PlayerAnimData.Parents = { " + ", ".join('%s = %s' % (n, '"%s"' % p if p else "false") for n, p, *_ in JOINTS) + " }",
        "",
        "export type Anim = { Length: number, Loop: boolean, Frames: { { { number } } } }",
        "PlayerAnimData.Anims = {} :: { [string]: Anim }",
        "",
    ]
    for anim in ORDER:
        a = data[anim]
        lines.append("PlayerAnimData.Anims.%s = {" % anim)
        lines.append("\tLength = %s," % a["Length"])
        lines.append("\tLoop = %s," % ("true" if a["Loop"] else "false"))
        lines.append("\tFrames = {")
        for row in a["Frames"]:
            lines.append("\t\t{ " + ", ".join("{ %s }" % ", ".join(("%g" % v) for v in q) for q in row) + " },")
        lines.append("\t},")
        lines.append("}")
        lines.append("")
    lines.append("return PlayerAnimData")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def render(objs, ranges, path):
    """A preview: every animation in turn, the avatar seen from the front-left, its name below."""
    import bpy
    scene = bpy.context.scene
    bpy.ops.mesh.primitive_plane_add(size=40)
    floor = bpy.context.active_object
    mat = bpy.data.materials.new("Floor")
    mat.diffuse_color = (0.55, 0.8, 0.45, 1)
    floor.data.materials.append(mat)
    # (Cycles on the CPU: runs anywhere, no graphics card needed)
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 8
    scene.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y = 560, 420
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.78, 0.86, 0.95, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(50), math.radians(-20), math.radians(-35))
    scene.collection.objects.link(sun)
    for m in bpy.data.materials:
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = m.diffuse_color
            bsdf.inputs["Roughness"].default_value = 0.6
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (-7.5, 9.5, 4.6)
    target = bpy.data.objects.new("Target", None)
    scene.collection.objects.link(target)
    target.location = (0, 0, 2.2)
    c = cam.constraints.new("TRACK_TO")
    c.target = target
    c.track_axis = "TRACK_NEGATIVE_Z"
    c.up_axis = "UP_Y"
    tmp = tempfile.mkdtemp()
    n = 0
    for anim in ORDER:
        start, length, loop = ranges[anim]
        plays = 2 if loop else 1
        frames = int(length * FPS)
        for p in range(plays):
            for i in range(0, frames + (0 if loop else 12), 2):
                scene.frame_set(int(start + min(i, frames)))
                scene.render.filepath = os.path.join(tmp, "f%05d.png" % n)
                bpy.ops.render.render(write_still=True)
                label(os.path.join(tmp, "f%05d.png" % n), anim)
                n += 1
    ffmpeg = find_ffmpeg()
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-framerate", str(FPS // 2), "-i", os.path.join(tmp, "f%05d.png"), "-pix_fmt", "yuv420p", "-vf", "scale=640:-2", path], check=True)
    shutil.rmtree(tmp)


def label(png, text):
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        return
    im = Image.open(png).convert("RGB")
    d = ImageDraw.Draw(im)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 30)
    except OSError:
        font = ImageFont.load_default()
    w = d.textlength(text, font=font)
    x, y = (im.width - w) / 2, im.height - 50
    for dx in (-2, 0, 2):
        for dy in (-2, 0, 2):
            d.text((x + dx, y + dy), text, font=font, fill=(20, 20, 30))
    d.text((x, y), text, font=font, fill=(255, 255, 255))
    im.save(png)


def find_ffmpeg():
    if os.environ.get("FFMPEG"):
        return os.environ["FFMPEG"]
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return "ffmpeg"


if __name__ == "__main__":
    args = sys.argv[1:]
    export = None
    render_to = None
    blend_to = None
    i = 0
    while i < len(args):
        if args[i] == "--render":
            render_to = args[i + 1]
            i += 2
        elif args[i] == "--blend":
            blend_to = args[i + 1]
            i += 2
        else:
            export = args[i]
            i += 1
    objs, ranges = build()
    data = sample(objs, ranges)
    if export:
        export_luau(data, export)
        print("wrote", export)
    if blend_to:
        import bpy
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(blend_to))
        print("saved", blend_to)
    if render_to:
        render(objs, ranges, render_to)
        print("rendered", render_to)
