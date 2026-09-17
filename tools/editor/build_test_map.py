# Generate a test map, headless. No hand-built content: rule 3.
#
#   UnrealEditor-Cmd <project> -run=pythonscript -script=tools/editor/build_test_map.py
#
# Writes /Game/Maps/ShotTest. Screenshotting it is a separate pass (`make play`), because a
# commandlet has no renderer and segfaults if you ask it for a frame.
import unreal, math

LOG = unreal.log

def movable(actor):
    """Dynamic lighting, so no lightmap build is needed. A headless pass cannot Build Lighting,
    and a stationary light without a lightmap renders the scene black with
    'LIGHTING NEEDS TO BE REBUILT' over it — which is exactly what the first frame out of this
    pipeline looked like."""
    root = actor.root_component
    if root:
        root.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    return actor

try:
    les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)

    MAP = "/Game/Maps/ShotTest"
    # new_level() on a path that already exists returns False and leaves you on an untitled map,
    # and the save afterwards then reports success while writing nothing. The old .umap stays on
    # disk looking freshly generated. Delete first, and check the return value.
    if unreal.EditorAssetLibrary.does_asset_exist(MAP):
        unreal.EditorAssetLibrary.delete_asset(MAP)
        LOG("SJMAP: deleted existing %s" % MAP)
    if not les.new_level(MAP):
        raise RuntimeError("new_level(%s) failed" % MAP)
    LOG("SJMAP: new level %s" % MAP)

    M = 100.0                      # unreal units per metre
    HEIGHT_M, BASE_R, TOP_R = 70.0, 3.2, 1.9      # 06-waterside.json
    COURSES = 28
    course_h = HEIGHT_M / COURSES

    cyl = unreal.load_asset("/Engine/BasicShapes/Cylinder.Cylinder")
    for i in range(COURSES):
        t = (i + 0.5) / COURSES
        r = BASE_R * (1.0 - t) + TOP_R * t
        a = movable(eas.spawn_actor_from_class(
            unreal.StaticMeshActor, unreal.Vector(0, 0, (i * course_h + course_h * 0.5) * M),
            unreal.Rotator(0, 0, 0)))
        a.set_actor_label("Course_%02d" % i)
        a.static_mesh_component.set_static_mesh(cyl)
        a.set_actor_scale3d(unreal.Vector(r * 2.0, r * 2.0, course_h))
    LOG("SJMAP: %d courses, %.0fm" % (COURSES, HEIGHT_M))

    plane = unreal.load_asset("/Engine/BasicShapes/Plane.Plane")
    g = movable(eas.spawn_actor_from_class(unreal.StaticMeshActor, unreal.Vector(0, 0, 0),
                                           unreal.Rotator(0, 0, 0)))
    g.set_actor_label("Ground")
    g.static_mesh_component.set_static_mesh(plane)
    g.set_actor_scale3d(unreal.Vector(400, 400, 1))

    sun = movable(eas.spawn_actor_from_class(unreal.DirectionalLight,
                                             unreal.Vector(0, 0, 50 * M), unreal.Rotator(0, -38, 55)))
    sun.set_actor_label("Sun")
    sc = sun.get_component_by_class(unreal.DirectionalLightComponent)
    if sc:
        sc.set_intensity(6.0)

    sky = movable(eas.spawn_actor_from_class(unreal.SkyLight, unreal.Vector(0, 0, 30 * M),
                                             unreal.Rotator(0, 0, 0)))
    sky.set_actor_label("Sky")
    kc = sky.get_component_by_class(unreal.SkyLightComponent)
    if kc:
        kc.set_intensity(1.5)

    for cls, label in ((unreal.SkyAtmosphere, "Atmosphere"), (unreal.ExponentialHeightFog, "Fog")):
        try:
            movable(eas.spawn_actor_from_class(cls, unreal.Vector(0, 0, 0),
                                               unreal.Rotator(0, 0, 0))).set_actor_label(label)
        except Exception as e:
            LOG("SJMAP: skipped %s (%s)" % (label, e))
    LOG("SJMAP: lighting")

    # Where the camera stands. A PlayerStart, because `-game` ignores the editor viewport camera
    # and drops the default pawn at the origin — inside the chimney, looking at black.
    eye = unreal.Vector(-95 * M, -60 * M, 22 * M)
    look = unreal.Vector(0, 0, HEIGHT_M * 0.45 * M)
    d = unreal.Vector(look.x - eye.x, look.y - eye.y, look.z - eye.z)
    yaw = math.degrees(math.atan2(d.y, d.x))
    pitch = math.degrees(math.atan2(d.z, math.sqrt(d.x * d.x + d.y * d.y)))
    rot = unreal.Rotator(0.0, pitch, yaw)

    start = eas.spawn_actor_from_class(unreal.PlayerStart, eye, rot)
    start.set_actor_label("ViewPoint")

    cam = eas.spawn_actor_from_class(unreal.CameraActor, eye, rot)
    cam.set_actor_label("ShotCamera")

    unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem) \
          .set_level_viewport_camera_info(eye, rot)
    LOG("SJMAP: viewpoint at %.0f,%.0f,%.0f yaw=%.1f pitch=%.1f" % (eye.x, eye.y, eye.z, yaw, pitch))

    if not les.save_current_level():
        raise RuntimeError("save_current_level() failed")
    world = unreal.EditorLevelLibrary.get_editor_world() if hasattr(unreal, "EditorLevelLibrary") else None
    LOG("SJMAP: saved, world=%s, actors=%d"
        % (world.get_path_name() if world else MAP, len(eas.get_all_level_actors())))
except Exception as exc:
    import traceback
    unreal.log_error("SJMAP: FAILED %s\n%s" % (exc, traceback.format_exc()))
