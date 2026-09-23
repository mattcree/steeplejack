"""The steeplejack: model, rig and animations, built in Blender from this script.

    make character        # runs Blender headless and writes godot/assets/characters/steeplejack.glb

Run inside Blender (`blender --background --factory-startup --python build_character.py -- OUT.glb`).
This script is the source; the .glb is its output. Nothing here is hand-modelled, so a change to
the character is a diff someone can read, and it can be rebuilt from nothing.

The brief (13-art-direction.md, ART-020): a Northern English steeplejack in his sixties. Flat cap,
collarless shirt, waistcoat, heavy boots, a leather tool belt, a coil of rope over one shoulder.
Readable in silhouette. **Designed from that description alone** — no reference to any real
person (docs/05-legal/ip-and-likeness.md): the face is a generic older man built from primitives.

Contracts with the game, which must not drift:
  * Bone names and hierarchy are the ones the game uses: pelvis, spine_01, spine_02, neck_01, head,
    clavicle/upperarm/lowerarm/hand .l/.r, thigh/calf/foot/ball .l/.r. rung_grip.gd solves the
    limbs by those names, climb_clip.gd aims the hammer arm, player.gd hangs the hammer off hand.r
    and the carried ladder off spine_02.
  * Proportions match what the game's reach numbers assume: hips ~0.95 m, shoulders ~1.45 m
    (climberShoulderAboveFeetMetres), about 1.78 m tall, feet at the origin.
  * Facing -Y in Blender, which the glTF exporter turns into +Z, the way the game faces a model.
  * The armature object is named "root", so the game finds Body/root/Skeleton3D.
  * Clips: idle and run (looping) and air_jump. `run` covers RUN_STRIDE_M per cycle; player.gd's
    RUN_CLIP_SPEED is that divided by its length, so the feet do not skate.
"""
from __future__ import annotations

import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

FPS = 30
RUN_FRAMES = 19          # 0.633 s, the length the game already paces
RUN_STRIDE_M = 1.50      # ground covered in one run cycle (two steps), measured from the leg swing

# --------------------------------------------------------------------------------------- skeleton
# name: (head, tail, parent). Blender coordinates: Z up, the character faces -Y, his left is +X.
ARM_DIR = Vector((math.sin(math.radians(40)), 0.0, -math.cos(math.radians(40))))   # the A-pose


def _arm(side: float):
    s = Vector((side, 1.0, 1.0))
    sh = Vector((0.175 * side, 0.01, 1.45))
    d = Vector((ARM_DIR.x * side, ARM_DIR.y, ARM_DIR.z))
    elbow = sh + d * 0.27
    wrist = elbow + d * 0.25 + Vector((0.0, -0.02, 0.0))
    tip = wrist + d * 0.17
    n = "l" if side > 0 else "r"
    return {
        f"clavicle.{n}": (Vector((0.025 * side, 0.0, 1.42)), sh, "spine_02"),
        f"upperarm.{n}": (sh, elbow, f"clavicle.{n}"),
        f"lowerarm.{n}": (elbow, wrist, f"upperarm.{n}"),
        f"hand.{n}": (wrist, tip, f"lowerarm.{n}"),
    }


def _leg(side: float):
    x = 0.10 * side
    n = "l" if side > 0 else "r"
    hip = Vector((x, 0.0, 0.93))
    knee = Vector((x, -0.012, 0.51))
    ankle = Vector((x, 0.015, 0.095))
    ball = Vector((x, -0.12, 0.025))
    toe = Vector((x, -0.21, 0.025))
    return {
        f"thigh.{n}": (hip, knee, "pelvis"),
        f"calf.{n}": (knee, ankle, f"thigh.{n}"),
        f"foot.{n}": (ankle, ball, f"calf.{n}"),
        f"ball.{n}": (ball, toe, f"foot.{n}"),
    }


BONES = {
    "pelvis": (Vector((0.0, 0.0, 0.95)), Vector((0.0, 0.0, 1.05)), None),
    "spine_01": (Vector((0.0, 0.0, 1.05)), Vector((0.0, 0.005, 1.25)), "pelvis"),
    "spine_02": (Vector((0.0, 0.005, 1.25)), Vector((0.0, 0.005, 1.47)), "spine_01"),
    "neck_01": (Vector((0.0, 0.005, 1.47)), Vector((0.0, -0.005, 1.56)), "spine_02"),
    "head": (Vector((0.0, -0.005, 1.56)), Vector((0.0, -0.005, 1.78)), "neck_01"),
    **_arm(1.0), **_arm(-1.0), **_leg(1.0), **_leg(-1.0),
}
ORDER = ["pelvis", "spine_01", "spine_02", "neck_01", "head",
         "clavicle.l", "upperarm.l", "lowerarm.l", "hand.l",
         "clavicle.r", "upperarm.r", "lowerarm.r", "hand.r",
         "thigh.l", "calf.l", "foot.l", "ball.l",
         "thigh.r", "calf.r", "foot.r", "ball.r"]

# ----------------------------------------------------------------------------------------- colours
PALETTE = {
    "skin": (0.72, 0.54, 0.44), "shirt": (0.82, 0.79, 0.70), "waistcoat": (0.16, 0.15, 0.15),
    "trousers": (0.24, 0.21, 0.18), "boots": (0.10, 0.07, 0.05), "cap": (0.30, 0.27, 0.23),
    "leather": (0.33, 0.19, 0.09), "rope": (0.62, 0.51, 0.33), "hair": (0.66, 0.65, 0.63),
    "button": (0.55, 0.50, 0.40),
    # The neckerchief. The only colour on him, and deliberately so: a man who is a silhouette
    # against a bright sky for most of the game needs one thing that is not grey or brown.
    "scarf": (0.45, 0.13, 0.11),
}


def _linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name: str):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        # The palette is written in sRGB, as a colour picker gives it; Blender's inputs (and glTF's
        # baseColorFactor) are linear. Passed straight through, every colour came out washed pale:
        # the waistcoat light grey, the rope white.
        bsdf.inputs["Base Color"].default_value = (*(_linear(c) for c in PALETTE[name]), 1.0)
        bsdf.inputs["Roughness"].default_value = 0.35 if name == "button" else 0.85
    return m


# ------------------------------------------------------------------------------------------ meshes
# Every part is a mesh plus the bones it may bend with. Weights are worked out from distance to
# those bones' segments (below), so a sleeve bends at the elbow and a trouser leg at the knee
# without hand-painted weights — deterministic, and rebuilt identically every run.
PARTS: list[tuple[bpy.types.Object, list[str]]] = []


def _obj(name: str, bm: bmesh.types.BMesh, mat: str, bones: list[str], smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(material(mat))
    bpy.context.collection.objects.link(ob)
    PARTS.append((ob, bones))
    return ob


def tube(name, a: Vector, b: Vector, ra: float, rb: float, mat, bones, segs=12, rings=6,
         squash=(1.0, 1.0), caps=True):
    """A tapered tube from a to b, elliptical by `squash` (x, y of its cross-section)."""
    bm = bmesh.new()
    axis = (b - a).normalized()
    ref = Vector((0, -1, 0)) if abs(axis.y) < 0.9 else Vector((0, 0, 1))
    u = axis.cross(ref).normalized()
    v = axis.cross(u).normalized()
    rows = []
    for i in range(rings + 1):
        t = i / rings
        c = a.lerp(b, t)
        r = ra + (rb - ra) * t
        row = []
        for k in range(segs):
            ang = 2 * math.pi * k / segs
            p = c + u * math.cos(ang) * r * squash[0] + v * math.sin(ang) * r * squash[1]
            row.append(bm.verts.new(p))
        rows.append(row)
    for i in range(rings):
        for k in range(segs):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % segs], rows[i + 1][(k + 1) % segs], rows[i + 1][k]))
    if caps:
        bm.faces.new(list(reversed(rows[0])))
        bm.faces.new(rows[-1])
    return _obj(name, bm, mat, bones)


def blob(name, centre: Vector, size: Vector, mat, bones, segs=16, rings=10):
    """An ellipsoid: heads, hands, boots, the cap's crown."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    for vert in bm.verts:
        vert.co = Vector((vert.co.x * size.x, vert.co.y * size.y, vert.co.z * size.z)) + centre
    return _obj(name, bm, mat, bones)


def box(name, centre: Vector, size: Vector, mat, bones, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for vert in bm.verts:
        vert.co = Vector((vert.co.x * size.x, vert.co.y * size.y, vert.co.z * size.z)) + centre
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect="EDGES")
    return _obj(name, bm, mat, bones, smooth=bevel > 0)


def torus(name, centre: Vector, major: float, minor: float, rot: Matrix, mat, bones, squash=(1, 1),
          segs=24, sides=8):
    bm = bmesh.new()
    rows = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        ring_c = Vector((math.cos(a) * major * squash[0], math.sin(a) * major * squash[1], 0.0))
        out = Vector((math.cos(a), math.sin(a), 0.0))
        row = []
        for k in range(sides):
            b = 2 * math.pi * k / sides
            p = ring_c + out * math.cos(b) * minor + Vector((0, 0, 1)) * math.sin(b) * minor
            row.append(bm.verts.new(rot @ p + centre))
        rows.append(row)
    for i in range(segs):
        for k in range(sides):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % sides], rows[(i + 1) % segs][(k + 1) % sides],
                          rows[(i + 1) % segs][k]))
    return _obj(name, bm, mat, bones)


def build_body():
    for side, n in ((1.0, "l"), (-1.0, "r")):
        x = 0.10 * side
        # Heavy boots: longer than the foot, a thick sole, laced up over the ankle.
        box(f"boot.{n}", Vector((x, -0.055, 0.055)), Vector((0.115, 0.29, 0.11)), "boots",
            [f"foot.{n}", f"ball.{n}"], bevel=0.02)
        tube(f"bootleg.{n}", Vector((x, 0.012, 0.09)), Vector((x, 0.01, 0.20)), 0.062, 0.058,
             "boots", [f"calf.{n}", f"foot.{n}"], rings=2)
        # Trousers: wool, loose, turned over the boot.
        tube(f"trouser.{n}", Vector((x, 0.0, 0.97)), Vector((x, 0.012, 0.16)), 0.092, 0.066,
             "trousers", [f"thigh.{n}", f"calf.{n}", "pelvis"], rings=10)
        # Shirt sleeves rolled to the elbow, then forearm.
        d = Vector((ARM_DIR.x * side, 0.0, ARM_DIR.z))
        sh = Vector((0.175 * side, 0.01, 1.45))
        elbow = sh + d * 0.27
        wrist = elbow + d * 0.25 + Vector((0.0, -0.02, 0.0))
        tube(f"sleeve.{n}", sh - d * 0.03, elbow + d * 0.025, 0.063, 0.052, "shirt",
             [f"upperarm.{n}", f"clavicle.{n}", f"lowerarm.{n}"], rings=6)
        tube(f"cuff.{n}", elbow - d * 0.005, elbow + d * 0.04, 0.056, 0.054, "shirt",
             [f"lowerarm.{n}"], rings=1)
        tube(f"forearm.{n}", elbow, wrist, 0.045, 0.034, "skin", [f"lowerarm.{n}", f"upperarm.{n}"],
             rings=5)
        # Big working hands, a mitt shape, thumb along the front.
        blob(f"hand.{n}", wrist + d * 0.075, Vector((0.045, 0.028, 0.065)), "skin", [f"hand.{n}"],
             segs=12, rings=8)
        blob(f"thumb.{n}", wrist + d * 0.04 + Vector((0.0, -0.035, 0.0)), Vector((0.017, 0.017, 0.04)),
             "skin", [f"hand.{n}"], segs=8, rings=6)
        # Fingers. They were one mitt, and a mitt is fine on a character you watch from twenty
        # feet — this one spends the whole game closed round a rung about a metre from the camera.
        # Four of them, curled, because a hand on a ladder is never flat.
        for f_i in range(4):
            across = (f_i - 1.5) * 0.023
            knuckle = wrist + d * 0.115 + Vector((across * side, 0.0, 0.0))
            tip = knuckle + d * 0.045 + Vector((0.0, -0.030, -0.012))
            tube(f"finger{f_i}.{n}", knuckle, tip, 0.0115, 0.0095, "skin", [f"hand.{n}"],
                 segs=6, rings=2)

        # Boots: a welted sole and a toe cap, which is what you look at for most of a climb —
        # the camera is over his shoulder and his feet are on the rung below him.
        box(f"sole.{n}", Vector((x, -0.055, 0.016)), Vector((0.125, 0.30, 0.028)), "leather",
            [f"foot.{n}", f"ball.{n}"], bevel=0.008)
        box(f"toecap.{n}", Vector((x, -0.155, 0.055)), Vector((0.112, 0.085, 0.085)), "boots",
            [f"ball.{n}"], bevel=0.022)
        for lace in range(3):
            box(f"lace{lace}.{n}", Vector((x, -0.02, 0.105 + 0.032 * lace)),
                Vector((0.085, 0.012, 0.007)), "button", [f"foot.{n}"], bevel=0.003)

    # Knees and elbows. A limb built as one smooth cone reads as a pipe; a joint is a lump, and
    # the lump is most of what tells you a leg is a leg when it bends.
    for side, n in ((1.0, "l"), (-1.0, "r")):
        x = 0.10 * side
        blob(f"knee.{n}", Vector((x, -0.012, 0.50)), Vector((0.072, 0.070, 0.075)), "trousers",
             [f"thigh.{n}", f"calf.{n}"], segs=10, rings=7)
        d = Vector((ARM_DIR.x * side, 0.0, ARM_DIR.z))
        sh = Vector((0.175 * side, 0.01, 1.45))
        blob(f"elbow.{n}", sh + d * 0.275, Vector((0.054, 0.054, 0.056)), "shirt",
             [f"upperarm.{n}", f"lowerarm.{n}"], segs=10, rings=7)
        # Turn-ups over the boot, which is the detail that dates a pair of working trousers.
        tube(f"turnup.{n}", Vector((x, 0.012, 0.155)), Vector((x, 0.012, 0.225)), 0.070, 0.068,
             "trousers", [f"calf.{n}", f"foot.{n}"], rings=1)

    # Hips and seat of the trousers.
    tube("seat", Vector((0.0, 0.0, 0.84)), Vector((0.0, 0.0, 1.07)), 0.175, 0.17, "trousers",
         ["pelvis", "thigh.l", "thigh.r", "spine_01"], squash=(1.0, 0.72), rings=4)
    # Shirt body, then the waistcoat over it, a size bigger, open at the neck.
    tube("shirt", Vector((0.0, 0.0, 1.02)), Vector((0.0, 0.005, 1.47)), 0.168, 0.155, "shirt",
         ["pelvis", "spine_01", "spine_02"], squash=(1.0, 0.68), rings=8)
    tube("waistcoat", Vector((0.0, 0.0, 1.00)), Vector((0.0, 0.005, 1.42)), 0.178, 0.172, "waistcoat",
         ["pelvis", "spine_01", "spine_02"], squash=(1.0, 0.70), rings=8, caps=False)
    for i in range(4):
        blob(f"button{i}", Vector((0.0, -0.125, 1.08 + 0.075 * i)), Vector((0.009, 0.006, 0.009)),
             "button", ["spine_01" if i < 2 else "spine_02"], segs=8, rings=5)
    # Braces. Period-correct, and the single most useful thing that can be added to a man you
    # follow up a ladder: two hard diagonals across the back, which is the view the player has of
    # him for the entire game.
    for side, n in ((1.0, "l"), (-1.0, "r")):
        front = Vector((0.062 * side, -0.150, 1.03))
        over = Vector((0.115 * side, -0.010, 1.455))
        back = Vector((0.090 * side, 0.146, 1.04))
        tube(f"brace.front.{n}", front, over, 0.017, 0.017, "leather",
             ["spine_01", "spine_02", f"clavicle.{n}"], segs=6, rings=4)
        tube(f"brace.back.{n}", over, back, 0.017, 0.017, "leather",
             ["spine_02", "spine_01", "pelvis"], segs=6, rings=4)
        box(f"brace.clip.{n}", front + Vector((0.0, 0.006, -0.012)),
            Vector((0.026, 0.016, 0.026)), "button", ["pelvis", "spine_01"], bevel=0.004)

    # A watch pocket and its chain, and the hammer loop the tool belt needs to explain the hammer.
    box("watchpocket", Vector((0.085, -0.150, 1.19)), Vector((0.052, 0.014, 0.046)), "waistcoat",
        ["spine_01"], bevel=0.006)
    tube("chain", Vector((0.060, -0.156, 1.175)), Vector((-0.010, -0.150, 1.130)), 0.004, 0.004,
         "button", ["spine_01"], segs=5, rings=3)
    torus("hammerloop", Vector((0.155, 0.02, 0.995)), 0.036, 0.011,
          Matrix.Rotation(math.radians(90), 3, "X"), "leather", ["pelvis"], segs=12)

    # Shoulders: round the top of the torso into the sleeves.
    for side, n in ((1.0, "l"), (-1.0, "r")):
        blob(f"shoulder.{n}", Vector((0.15 * side, 0.005, 1.425)), Vector((0.08, 0.075, 0.07)), "shirt",
             ["spine_02", f"clavicle.{n}", f"upperarm.{n}"], segs=12, rings=8)
    # Collarless shirt: a band at the neck, no collar.
    tube("band", Vector((0.0, 0.004, 1.46)), Vector((0.0, 0.0, 1.50)), 0.068, 0.062, "shirt",
         ["spine_02", "neck_01"], rings=1)
    tube("neck", Vector((0.0, 0.0, 1.46)), Vector((0.0, -0.005, 1.60)), 0.055, 0.052, "skin",
         ["neck_01", "head"], rings=3)

    # A neckerchief, knotted at the throat. Every man who worked outdoors in this trade wore one,
    # it is the one spot of colour on him, and it is exactly at the height the camera sits when
    # you are below him on a ladder looking up.
    torus("scarf", Vector((0.0, -0.004, 1.478)), 0.066, 0.019, Matrix.Identity(3), "scarf",
          ["neck_01", "spine_02"], squash=(1.0, 0.92), segs=18)
    blob("scarfknot", Vector((0.0, -0.062, 1.462)), Vector((0.026, 0.024, 0.022)), "scarf",
         ["neck_01"], segs=8, rings=6)

    # Head: an older man's, broad in the jaw. No features beyond the shapes a silhouette and a
    # face at 4 m read by: nose, ears, grey hair at the back and sides, a moustache.
    blob("head", Vector((0.0, -0.012, 1.665)), Vector((0.093, 0.105, 0.118)), "skin", ["head"])
    blob("jaw", Vector((0.0, -0.035, 1.605)), Vector((0.078, 0.07, 0.055)), "skin", ["head"])
    blob("nose", Vector((0.0, -0.118, 1.655)), Vector((0.018, 0.028, 0.03)), "skin", ["head"],
         segs=8, rings=6)
    for side in (1.0, -1.0):
        blob(f"ear{side:+.0f}", Vector((0.092 * side, 0.0, 1.665)), Vector((0.012, 0.024, 0.032)), "skin",
             ["head"], segs=8, rings=6)
    blob("hair", Vector((0.0, 0.03, 1.665)), Vector((0.097, 0.09, 0.1)), "hair", ["head"])
    box("moustache", Vector((0.0, -0.112, 1.622)), Vector((0.055, 0.02, 0.014)), "hair", ["head"],
        bevel=0.006)
    # Sixty-odd years of weather: a heavy brow, cheekbones, and the hollow under them. Shapes,
    # not features — at three metres a face is light and shadow and the shape is all of it.
    for side in (1.0, -1.0):
        blob(f"cheek{side:+.0f}", Vector((0.058 * side, -0.072, 1.640)),
             Vector((0.030, 0.026, 0.024)), "skin", ["head"], segs=8, rings=6)
        # Sideburns, which is what the hair does on a man of his age under a cap.
        blob(f"burn{side:+.0f}", Vector((0.084 * side, -0.012, 1.628)),
             Vector((0.014, 0.030, 0.040)), "hair", ["head"], segs=8, rings=6)
    # A working chin, and the soft throat of a man in his sixties.
    blob("chin", Vector((0.0, -0.082, 1.578)), Vector((0.042, 0.038, 0.030)), "skin", ["head"],
         segs=10, rings=7)
    blob("throat", Vector((0.0, -0.040, 1.520)), Vector((0.044, 0.038, 0.040)), "skin",
         ["neck_01", "head"], segs=10, rings=7)

    # Brow and eye sockets. Not eyes — a face at three metres is shadow and shape, and two shiny
    # spheres on a man this size read as a doll. A ridge and a hollow under it is all it takes.
    blob("brow", Vector((0.0, -0.088, 1.700)), Vector((0.082, 0.030, 0.020)), "skin", ["head"],
         segs=12, rings=6)
    for side in (1.0, -1.0):
        blob(f"socket{side:+.0f}", Vector((0.038 * side, -0.082, 1.674)),
             Vector((0.026, 0.016, 0.016)), "hair", ["head"], segs=8, rings=6)

    # The flat cap: a soft crown pulled forward, and a short stiff peak.
    blob("cap", Vector((0.0, -0.02, 1.745)), Vector((0.108, 0.125, 0.045)), "cap", ["head"])
    box("peak", Vector((0.0, -0.13, 1.728)), Vector((0.16, 0.08, 0.012)), "cap", ["head"], bevel=0.005)
    # The button on the crown, and the seam round it. A flat cap is eight panels sewn to a button
    # and it is the one piece of him that is above the camera on a ladder.
    blob("capbutton", Vector((0.0, -0.02, 1.788)), Vector((0.016, 0.016, 0.008)), "cap", ["head"],
         segs=8, rings=5)

    # Leather tool belt, a pouch on the right hip, and the rope coil over the left shoulder.
    torus("belt", Vector((0.0, 0.0, 1.01)), 0.176, 0.02, Matrix.Identity(3), "leather", ["pelvis"],
          squash=(1.0, 0.72))
    box("pouch", Vector((-0.16, -0.05, 0.96)), Vector((0.06, 0.1, 0.12)), "leather", ["pelvis"],
        bevel=0.012)
    # A second pouch for dogs, and a bolster in a loop. He is carrying a trade's worth of iron and
    # up to now the belt had one bag on it.
    box("dogbag", Vector((0.17, 0.045, 0.955)), Vector((0.055, 0.085, 0.115)), "leather",
        ["pelvis"], bevel=0.012)
    tube("bolster", Vector((-0.175, 0.09, 1.05)), Vector((-0.175, 0.10, 0.90)), 0.014, 0.011,
         "button", ["pelvis"], segs=8, rings=2)
    box("buckle", Vector((0.0, -0.13, 1.01)), Vector((0.05, 0.012, 0.04)), "button", ["pelvis"])
    tilt = Matrix.Rotation(math.radians(90), 3, "Y") @ Matrix.Rotation(math.radians(-38), 3, "X")
    torus("rope", Vector((0.03, 0.0, 1.26)), 0.27, 0.028, Matrix.Rotation(math.radians(-50), 3, "Y"),
          "rope", ["spine_02", "spine_01"], squash=(0.95, 0.62), segs=32)


# ------------------------------------------------------------------------------------------- rig
def build_armature() -> bpy.types.Object:
    arm = bpy.data.armatures.new("root")
    ob = bpy.data.objects.new("root", arm)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for name in ORDER:
        head, tail, parent = BONES[name]
        eb = arm.edit_bones.new(name)
        eb.head = head
        eb.tail = tail
        # Z forward (-Y) wherever the bone is not itself pointing forward, so +X rotation bends a
        # limb or the spine forward — the same convention for every bone.
        forwardish = abs((tail - head).normalized().y) > 0.7
        eb.align_roll(Vector((0, 0, 1)) if forwardish else Vector((0, -1, 0)))
        if parent:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def _seg_dist(p: Vector, a: Vector, b: Vector) -> float:
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.dot(ab), 1e-9)))
    return (a + ab * t - p).length


def skin(armature: bpy.types.Object):
    """Join every part into one mesh, weighted to its allowed bones by distance to each bone.

    Inverse sixth power of the distance to the bone's segment, the best two kept and normalised:
    near a joint a vertex splits between the two bones either side, away from it one bone owns it.
    """
    for ob, bones in PARTS:
        groups = {name: ob.vertex_groups.new(name=name) for name in bones}
        for v in ob.data.vertices:
            ws = []
            for name in bones:
                head, tail, _ = BONES[name]
                d = _seg_dist(v.co, head, tail)
                ws.append((1.0 / (d ** 6 + 1e-7), name))
            ws.sort(reverse=True)
            ws = ws[:2]
            total = sum(w for w, _ in ws)
            for w, name in ws:
                groups[name].add([v.index], w / total, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    for ob, _ in PARTS:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0][0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "body"
    body.parent = armature
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = armature
    return body


# ------------------------------------------------------------------------------------- animation
def _aim(arm_ob, name: str, direction: Vector):
    """Point a bone along `direction` (armature space) from wherever its parent has put it."""
    pb = arm_ob.pose.bones[name]
    bpy.context.view_layer.update()
    cur = pb.matrix.copy()
    have = (cur.to_3x3() @ Vector((0, 1, 0))).normalized()
    q = have.rotation_difference(direction.normalized())
    head = cur.translation
    pb.matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ cur
    bpy.context.view_layer.update()


def pose(arm_ob, aims: dict[str, tuple], frame: int, pelvis_z: float = 0.0, pelvis_y: float = 0.0):
    for pb in arm_ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    arm_ob.pose.bones["pelvis"].location = Vector((0.0, pelvis_z, -pelvis_y))   # bone-local: Y is up
    for name in ORDER:
        if name in aims:
            _aim(arm_ob, name, Vector(aims[name]))
    for pb in arm_ob.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        if pb.name == "pelvis":
            pb.keyframe_insert("location", frame=frame)


def _mirror(d: dict) -> dict:
    out = {}
    for k, v in d.items():
        k2 = k.replace(".l", ".R").replace(".r", ".l").replace(".R", ".r")
        out[k2] = (-v[0], v[1], v[2])
    return out


ARMS_DOWN = {"upperarm.l": (0.14, 0.0, -1.0), "lowerarm.l": (0.08, -0.12, -1.0), "hand.l": (0.06, -0.1, -1.0),
             "upperarm.r": (-0.14, 0.0, -1.0), "lowerarm.r": (-0.08, -0.12, -1.0), "hand.r": (-0.06, -0.1, -1.0)}
STAND = {"thigh.l": (0.0, 0.0, -1.0), "calf.l": (0.0, 0.03, -1.0), "foot.l": (0.0, -1.0, -0.3), "ball.l": (0.0, -1.0, 0.0),
         "thigh.r": (0.0, 0.0, -1.0), "calf.r": (0.0, 0.03, -1.0), "foot.r": (0.0, -1.0, -0.3), "ball.r": (0.0, -1.0, 0.0)}


def action(arm_ob, name: str, keys: list[tuple[int, dict, float]], loop_end: int | None):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm_ob.animation_data_create()
    arm_ob.animation_data.action = act
    for frame, aims, bob in keys:
        pose(arm_ob, aims, frame, pelvis_z=bob)
    if loop_end is not None:
        pose(arm_ob, keys[0][1], loop_end, pelvis_z=keys[0][2])
    # Stash it on the NLA so the exporter sees it as its own clip.
    track = arm_ob.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, act)
    arm_ob.animation_data.action = None


def build_animations(arm_ob):
    bpy.context.scene.render.fps = FPS
    spine_up = {"spine_01": (0.0, -0.02, 1.0), "spine_02": (0.0, 0.0, 1.0), "neck_01": (0.0, -0.08, 1.0),
                "head": (0.0, -0.02, 1.0)}
    # idle — standing easy, breathing: the chest lifts and the arms follow a touch.
    breathe_in = {**spine_up, "spine_02": (0.0, 0.03, 1.0), **ARMS_DOWN, **STAND}
    breathe_out = {**spine_up, "spine_02": (0.0, -0.01, 1.0), **ARMS_DOWN, **STAND}
    action(arm_ob, "idle", [(0, breathe_out, 0.0), (21, breathe_in, 0.008)], loop_end=42)

    # run — a heavy jog: contact, passing, contact (mirrored), passing. Legs swing ±27° at the hip,
    # which covers RUN_STRIDE_M over the cycle; arms swing against the legs; the body leans in.
    lean = {"spine_01": (0.0, -0.12, 1.0), "spine_02": (0.0, -0.06, 1.0), "neck_01": (0.0, -0.02, 1.0),
            "head": (0.0, 0.03, 1.0)}
    contact = {**lean,
               "thigh.l": (0.0, -0.46, -0.89), "calf.l": (0.0, -0.1, -1.0), "foot.l": (0.0, -1.0, -0.1),
               "thigh.r": (0.0, 0.40, -0.92), "calf.r": (0.0, 0.85, -0.55), "foot.r": (0.0, -0.3, -1.0),
               "upperarm.l": (0.12, 0.35, -0.93), "lowerarm.l": (0.08, -0.35, -0.94),
               "upperarm.r": (-0.12, -0.42, -0.9), "lowerarm.r": (-0.1, -0.95, -0.3)}
    passing = {**lean,
               "thigh.l": (0.0, 0.02, -1.0), "calf.l": (0.0, 0.15, -1.0), "foot.l": (0.0, -1.0, -0.2),
               "thigh.r": (0.0, -0.45, -0.89), "calf.r": (0.0, 0.55, -0.83), "foot.r": (0.0, -0.8, -0.6),
               "upperarm.l": (0.12, 0.0, -1.0), "lowerarm.l": (0.08, -0.6, -0.8),
               "upperarm.r": (-0.12, 0.0, -1.0), "lowerarm.r": (-0.08, -0.6, -0.8)}
    q = RUN_FRAMES / 4.0
    action(arm_ob, "run", [(0, contact, -0.03), (round(q), passing, 0.02),
                           (round(2 * q), _mirror(contact), -0.03), (round(3 * q), _mirror(passing), 0.02)],
           loop_end=RUN_FRAMES)

    # air_jump — in the air: arms up and out for balance, knees drawn up.
    air = {**spine_up, "upperarm.l": (0.8, -0.2, 0.3), "lowerarm.l": (0.5, -0.4, 0.6),
           "upperarm.r": (-0.8, -0.2, 0.3), "lowerarm.r": (-0.5, -0.4, 0.6),
           "thigh.l": (0.0, -0.6, -0.8), "calf.l": (0.0, 0.5, -0.87), "thigh.r": (0.0, -0.35, -0.94),
           "calf.r": (0.0, 0.6, -0.8)}
    action(arm_ob, "air_jump", [(0, air, 0.0), (8, air, 0.0)], loop_end=None)


# ------------------------------------------------------------------------------------------- main
def main():
    out = sys.argv[sys.argv.index("--") + 1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = build_armature()
    build_body()
    skin(armature)
    build_animations(armature)
    # Rest pose for export; the clips carry the poses.
    for pb in armature.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    tris = sum(len(p.vertices) - 2 for p in bpy.data.objects["body"].data.polygons)
    print(f"STEEPLEJACK: {len(armature.data.bones)} bones, {tris} triangles, "
          f"{len(bpy.data.actions)} clips, run stride {RUN_STRIDE_M} m over {RUN_FRAMES / FPS:.3f} s")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_skins=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_apply=False)
    print(f"STEEPLEJACK: wrote {out}")


main()
