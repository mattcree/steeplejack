import unreal
les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
les.load_level("/Game/Maps/ShotTest")
actors = eas.get_all_level_actors()
unreal.log("SJDUMP: %d actors" % len(actors))
kinds = {}
for a in actors:
    k = a.get_class().get_name()
    kinds[k] = kinds.get(k, 0) + 1
for k, n in sorted(kinds.items()):
    unreal.log("SJDUMP:   %-28s %d" % (k, n))
for a in actors:
    if "Light" in a.get_class().get_name() or "PlayerStart" in a.get_class().get_name():
        rc = a.root_component
        mob = rc.get_editor_property("mobility") if rc else "?"
        unreal.log("SJDUMP:   %s mobility=%s loc=%s" % (a.get_actor_label(), mob, a.get_actor_location()))
