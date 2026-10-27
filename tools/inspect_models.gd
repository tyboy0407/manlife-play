extends SceneTree
## 印出匯入後模型場景的結構(節點、網格 AABB、材質、骨架、動畫),接新模型時用來確認格式。
## 跑法:godot --headless --path . --script tools/inspect_models.gd -- res://assets/models/game/characters/character-male-a.glb ...


func _init() -> void:
    var paths := []
    for a in OS.get_cmdline_user_args():   # `--` 之後的參數(get_cmdline_args 不含它們)
        paths.append(a)
    if paths.is_empty():
        paths = ["res://assets/models/game/characters/character-male-a.glb", "res://assets/models/game/props/fish.glb",
                "res://assets/models/game/fish/Fish1.fbx"]
    for p in paths:
        _inspect(str(p))
    quit(0)


func _inspect(path: String) -> void:
    print("=== %s" % path)
    var res := load(path)
    if res == null:
        print("  (load failed)")
        return
    if res is Mesh:
        _print_mesh("  ", res as Mesh)
        return
    if not (res is PackedScene):
        print("  loaded %s" % res.get_class())
        return
    var inst := (res as PackedScene).instantiate()
    _print_node(inst, "  ")
    var aabb := _scene_aabb(inst)
    print("  scene AABB: pos=%s size=%s" % [aabb.position, aabb.size])
    inst.free()


func _print_node(n: Node, indent: String) -> void:
    var extra := ""
    if n is MeshInstance3D:
        var mi := n as MeshInstance3D
        extra = " skeleton=%s" % str(mi.skeleton)
    if n is Node3D:
        var n3 := n as Node3D
        extra += " xform=(pos %s rot %s scale %s)" % [n3.position, n3.rotation_degrees, n3.scale]
    print("%s%s [%s]%s" % [indent, n.name, n.get_class(), extra])
    if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
        _print_mesh(indent + "    ", (n as MeshInstance3D).mesh)
    if n is Skeleton3D:
        var sk := n as Skeleton3D
        var names := []
        for i in sk.get_bone_count():
            names.append(sk.get_bone_name(i))
        print("%s    bones(%d): %s" % [indent, sk.get_bone_count(), ", ".join(names)])
        for i in sk.get_bone_count():
            print("%s      rest %s: %s" % [indent, sk.get_bone_name(i), sk.get_bone_global_rest(i).origin])
    if n is AnimationPlayer:
        var ap := n as AnimationPlayer
        for a in ap.get_animation_list():
            var anim := ap.get_animation(a)
            print("%s    anim %s: %.2fs loop=%d tracks=%d" % [indent, a, anim.length, anim.loop_mode, anim.get_track_count()])
    for c in n.get_children():
        _print_node(c, indent + "  ")


func _print_mesh(indent: String, m: Mesh) -> void:
    var aabb := m.get_aabb()
    print("%smesh %s surfaces=%d aabb pos=%s size=%s" % [indent, m.get_class(), m.get_surface_count(), aabb.position, aabb.size])
    for s in m.get_surface_count():
        var mat := m.surface_get_material(s)
        var desc := "null"
        if mat is StandardMaterial3D:
            var sm := mat as StandardMaterial3D
            desc = "StandardMaterial3D albedo=%s tex=%s" % [sm.albedo_color, str(sm.albedo_texture)]
        elif mat != null:
            desc = mat.get_class()
        print("%s  surface %d: %d verts, material %s" % [indent, s, m.surface_get_array_len(s), desc])


func _scene_aabb(n: Node) -> AABB:
    var out := AABB()
    var first := true
    var stack := [n]
    while not stack.is_empty():
        var cur: Node = stack.pop_back()
        if cur is MeshInstance3D and (cur as MeshInstance3D).mesh != null:
            var mi := cur as MeshInstance3D
            var local := mi.mesh.get_aabb()
            var xf := mi.transform
            var p := mi.get_parent()
            while p != null and p != n and p is Node3D:
                xf = (p as Node3D).transform * xf
                p = p.get_parent()
            var box := xf * local
            if first:
                out = box
                first = false
            else:
                out = out.merge(box)
        for c in cur.get_children():
            stack.append(c)
    return out
