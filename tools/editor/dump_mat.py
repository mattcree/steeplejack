import unreal
m = unreal.load_asset("/Game/Materials/M_Band")
unreal.log("SJMAT: asset=%s" % m)
MEL = unreal.MaterialEditingLibrary
try:
    names = MEL.get_vector_parameter_names(m)
    unreal.log("SJMAT: vector params = %s" % [str(n) for n in names])
except Exception as e:
    unreal.log("SJMAT: get_vector_parameter_names failed: %s" % e)
try:
    unreal.log("SJMAT: base colour connected = %s" %
               MEL.get_material_property_input_node(m, unreal.MaterialProperty.MP_BASE_COLOR))
except Exception as e:
    unreal.log("SJMAT: cannot query base colour: %s" % e)
for ex in m.get_editor_property("expressions") if hasattr(m, "get_editor_property") else []:
    unreal.log("SJMAT: expr %s" % ex)
