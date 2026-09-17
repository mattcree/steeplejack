# Build the band material. Run once; `make build-map` depends on it existing.
#
# The bands were coming out pastel because the engine's BasicShapeMaterial does not expose base
# colour the way I assumed — setting its "Color" parameter tints something else, so soot-black
# brick rendered as pale tan. This makes a real material with a VectorParameter wired straight to
# Base Color, which is what the band colours actually need.
import unreal

LOG = unreal.log
PKG = "/Game/Materials"
NAME = "M_Band"

try:
    tools = unreal.AssetToolsHelpers.get_asset_tools()
    path = "%s/%s" % (PKG, NAME)
    if unreal.EditorAssetLibrary.does_asset_exist(path):
        unreal.EditorAssetLibrary.delete_asset(path)

    mat = tools.create_asset(NAME, PKG, unreal.Material, unreal.MaterialFactoryNew())
    MEL = unreal.MaterialEditingLibrary

    colour = MEL.create_material_expression(mat, unreal.MaterialExpressionVectorParameter, -500, 0)
    colour.set_editor_property("parameter_name", "Color")
    colour.set_editor_property("default_value", unreal.LinearColor(0.35, 0.30, 0.27, 1.0))
    MEL.connect_material_property(colour, "", unreal.MaterialProperty.MP_BASE_COLOR)

    rough = MEL.create_material_expression(mat, unreal.MaterialExpressionScalarParameter, -500, 220)
    rough.set_editor_property("parameter_name", "Roughness")
    rough.set_editor_property("default_value", 0.92)      # brickwork, not porcelain
    MEL.connect_material_property(rough, "", unreal.MaterialProperty.MP_ROUGHNESS)

    # Usage flags. Without bUsedWithInstancedStaticMeshes, UE silently substitutes the default
    # grey material when the thing is drawn on an InstancedStaticMeshComponent — while
    # GetMaterial(0) keeps reporting yours. That is the whole reason the bands rendered pale no
    # matter what colour they were given; the log said so once, quietly:
    #   "Material /Game/Materials/MI_Plain needed to set usage flag InstancedStaticMeshes"
    mat.set_editor_property("used_with_instanced_static_meshes", True)
    mat.set_editor_property("used_with_static_lighting", True)

    MEL.recompile_material(mat)
    unreal.EditorAssetLibrary.save_asset(path)
    LOG("SJMAT: built %s" % path)

    # One material instance asset per band type. Assets rather than dynamic instances created at
    # runtime: a MID made in Rebuild() has to survive the actor being saved into a map and loaded
    # again, and it did not — every band reported "material=set" while rendering the previous
    # build's colour. An asset is just an asset.
    BANDS = {
        "Plain":        (0.23, 0.11, 0.07),   # soot-dulled red brick
        "Ivy":          (0.07, 0.14, 0.05),
        "ExistingBand": (0.13, 0.09, 0.08),   # iron banding, near black
        "WindBand":     (0.42, 0.33, 0.26),   # weather-bleached up top
        "Internal":     (0.10, 0.10, 0.12),
        "Timber":       (0.20, 0.13, 0.07),   # ladders
        "Plank":        (0.26, 0.18, 0.10),   # staging
        "Default":      (0.35, 0.30, 0.27),
    }
    factory = unreal.MaterialInstanceConstantFactoryNew()
    for name, (r, g, b) in BANDS.items():
        inst_path = "%s/MI_%s" % (PKG, name)
        if unreal.EditorAssetLibrary.does_asset_exist(inst_path):
            unreal.EditorAssetLibrary.delete_asset(inst_path)
        inst = tools.create_asset("MI_%s" % name, PKG, unreal.MaterialInstanceConstant, factory)
        MEL.set_material_instance_parent(inst, mat)
        MEL.set_material_instance_vector_parameter_value(
            inst, "Color", unreal.LinearColor(r, g, b, 1.0))
        unreal.EditorAssetLibrary.save_asset(inst_path)
        LOG("SJMAT: built %s = (%.2f %.2f %.2f)" % (inst_path, r, g, b))
except Exception as exc:
    import traceback
    unreal.log_error("SJMAT: FAILED %s\n%s" % (exc, traceback.format_exc()))
