extends Node3D

var player: CharacterBody3D
var camera: Camera3D
var joystick_vector := Vector2.ZERO
var joystick_origin := Vector2(105, 590)
var joystick_active := false
var chat_timer: Timer
var bubble: Label3D
var chat_input: LineEdit
var status_label: Label
var speed := 5.0
var yaw := 0.0
var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var house_entries: Array[Dictionary] = []
var inside_house_index := -1
var outside_position := Vector3.ZERO
var enter_house_button: Button
var exit_house_button: Button
var light_switch_button: Button
var chat_log_panel: PanelContainer
var chat_history_box: VBoxContainer
var chat_history: Array[String] = []
var chat_socket: WebSocketPeer
var chat_join_sent := false
var player_name := "Babito"
var avatar_style := 0
var player_name_tag: Label3D
var arabic_font: FontFile
var arabic_theme: Theme


func apply_arabic_theme(node: Node) -> void:
    if node is Control:
        (node as Control).theme = arabic_theme
    for child in node.get_children():
        apply_arabic_theme(child)


func _ready() -> void:
    arabic_font = load("res://fonts/NotoSansArabic-Regular.ttf") as FontFile
    arabic_theme = Theme.new()
    arabic_theme.default_font = arabic_font
    arabic_theme.default_font_size = 18

    load_profile()
    if not profile_complete:
        make_profile_screen()
        apply_arabic_theme(self)
        return
    make_world()
    make_player()
    make_ui()
    apply_arabic_theme(self)
    load_chat_history()
    connect_chat_server()
    show_message("هلا بيك بعالم بابيتو! 💗")

func make_world() -> void:
    world_environment = WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.12, 0.42, 0.78)
    sky_mat.sky_horizon_color = Color(0.72, 0.86, 0.96)
    sky_mat.ground_bottom_color = Color(0.32, 0.35, 0.29)
    sky_mat.ground_horizon_color = Color(0.77, 0.82, 0.73)
    sky_mat.sun_angle_max = 8.0
    sky_mat.sun_curve = 0.15
    env.sky.sky_material = sky_mat
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.72, 0.78, 0.84)
    env.ambient_light_energy = 0.65
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world_environment.environment = env
    add_child(world_environment)

    sun_light = DirectionalLight3D.new()
    sun_light.rotation_degrees = Vector3(-43, -28, 0)
    sun_light.light_energy = 1.15
    sun_light.shadow_enabled = true
    add_child(sun_light)

    var visible_sun := MeshInstance3D.new()
    visible_sun.name = "VisibleSun"
    var sun_mesh := SphereMesh.new()
    sun_mesh.radius = 2.2
    sun_mesh.height = 4.4
    visible_sun.mesh = sun_mesh
    visible_sun.position = Vector3(-18, 24, -55)
    var sun_mat := StandardMaterial3D.new()
    sun_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sun_mat.albedo_color = Color(1.0, 0.88, 0.57)
    sun_mat.emission_enabled = true
    sun_mat.emission = Color(1.0, 0.72, 0.32)
    sun_mat.emission_energy_multiplier = 1.5
    visible_sun.material_override = sun_mat
    add_child(visible_sun)

    var ground := StaticBody3D.new()
    ground.name = "NaturalGround"
    add_child(ground)

    var ground_mesh := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(120, 120)
    ground_mesh.mesh = plane
    var grass := StandardMaterial3D.new()
    grass.albedo_color = Color(0.30, 0.43, 0.25)
    grass.roughness = 1.0
    ground_mesh.material_override = grass
    ground.add_child(ground_mesh)

    var ground_collision := CollisionShape3D.new()
    var ground_shape := BoxShape3D.new()
    ground_shape.size = Vector3(120, 0.3, 120)
    ground_collision.shape = ground_shape
    ground_collision.position.y = -0.15
    ground.add_child(ground_collision)

    # Main stone walkway
    create_box("MainStonePath", self, Vector3(4.2, 0.08, 42),
        Vector3(0, 0.025, -2), Color(0.48, 0.47, 0.42))
    create_box("CrossStonePath", self, Vector3(34, 0.085, 3.5),
        Vector3(0, 0.03, 1), Color(0.57, 0.55, 0.49))

    make_pond(Vector3(-3.8, 0, -16.0))

    # Small stone paving details
    for i in range(18):
        var z := -19.0 + float(i) * 2.0
        create_box("PathStone", self, Vector3(3.8, 0.012, 0.035),
            Vector3(0, 0.075, z), Color(0.38, 0.38, 0.35))

    # Houses around the central path
    make_house(Vector3(7, 0, -7), Color(0.72, 0.63, 0.50))
    make_house(Vector3(-8, 0, -10), Color(0.66, 0.70, 0.63))
    make_house(Vector3(12, 0, 8), Color(0.72, 0.57, 0.45))

    # Trees with layered foliage
    for i in range(26):
        var tree := Node3D.new()
        var side := -1.0 if i % 2 == 0 else 1.0
        var row := float(i / 2)
        tree.position = Vector3(
            side * (7.0 + float((i * 7) % 5)),
            0,
            -22.0 + row * 3.4
        )
        var tree_xz := Vector2(tree.position.x, tree.position.z)
        if tree_xz.distance_to(Vector2(7, -7)) < 5.0:
            continue
        if tree_xz.distance_to(Vector2(-8, -10)) < 5.0:
            continue
        if tree_xz.distance_to(Vector2(12, 8)) < 5.0:
            continue
        if tree_xz.distance_to(Vector2(-3.8, -16.0)) < 4.5:
            continue
        add_child(tree)

        var trunk := MeshInstance3D.new()
        var trunk_mesh := CylinderMesh.new()
        trunk_mesh.top_radius = 0.16
        trunk_mesh.bottom_radius = 0.27
        trunk_mesh.height = 2.3
        trunk.mesh = trunk_mesh
        trunk.position.y = 1.15
        var trunk_mat := StandardMaterial3D.new()
        trunk_mat.albedo_color = Color(0.29, 0.20, 0.13)
        trunk_mat.roughness = 1.0
        trunk.material_override = trunk_mat
        tree.add_child(trunk)

        for j in range(3):
            var crown := MeshInstance3D.new()
            var crown_mesh := SphereMesh.new()
            crown_mesh.radius = 1.05 - float(j) * 0.12
            crown_mesh.height = 1.9 - float(j) * 0.2
            crown.mesh = crown_mesh
            crown.position = Vector3(
                0.22 * sin(float(j) * 2.0),
                2.5 + float(j) * 0.52,
                0.18 * cos(float(j) * 2.0)
            )
            var leaf_mat := StandardMaterial3D.new()
            leaf_mat.albedo_color = [
                Color(0.15, 0.31, 0.16),
                Color(0.22, 0.39, 0.19),
                Color(0.29, 0.44, 0.22)
            ][j]
            leaf_mat.roughness = 1.0
            crown.material_override = leaf_mat
            tree.add_child(crown)

    # Shrubs and flower beds beside the walkway
    for i in range(24):
        var side := -1.0 if i % 2 == 0 else 1.0
        var z := -20.0 + float(i) * 1.65
        var bush := MeshInstance3D.new()
        var bush_mesh := SphereMesh.new()
        bush_mesh.radius = 0.42
        bush_mesh.height = 0.7
        bush.mesh = bush_mesh
        bush.position = Vector3(side * 3.2, 0.32, z)
        var bush_mat := StandardMaterial3D.new()
        bush_mat.albedo_color = Color(0.20, 0.37, 0.17)
        bush_mat.roughness = 1.0
        bush.material_override = bush_mat
        add_child(bush)

        if i % 2 == 0:
            var flower := MeshInstance3D.new()
            var flower_mesh := SphereMesh.new()
            flower_mesh.radius = 0.12
            flower_mesh.height = 0.16
            flower.mesh = flower_mesh
            flower.position = Vector3(side * 3.2, 0.68, z)
            var flower_mat := StandardMaterial3D.new()
            flower_mat.albedo_color = Color(0.88, 0.76, 0.53)
            flower.material_override = flower_mat
            add_child(flower)


func create_box(
    object_name: String,
    parent: Node,
    box_size: Vector3,
    box_position: Vector3,
    tint: Color
) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = object_name
    var box_mesh := BoxMesh.new()
    box_mesh.size = box_size
    mesh_instance.mesh = box_mesh
    mesh_instance.position = box_position
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.roughness = 0.9
    mesh_instance.material_override = material
    parent.add_child(mesh_instance)
    return mesh_instance


func make_house(pos: Vector3, color: Color) -> void:
    var house := Node3D.new()
    house.name = "InteractiveHouse"
    house.position = pos
    add_child(house)

    create_box("HouseWalls", house, Vector3(4.4, 3.0, 3.8),
        Vector3(0, 1.5, 0), color)

    var roof := MeshInstance3D.new()
    var roof_mesh := PrismMesh.new()
    roof_mesh.size = Vector3(4.9, 1.55, 4.3)
    roof.mesh = roof_mesh
    roof.position = Vector3(0, 3.75, 0)
    var roof_mat := StandardMaterial3D.new()
    roof_mat.albedo_color = Color(0.25, 0.22, 0.19)
    roof_mat.roughness = 0.9
    roof.material_override = roof_mat
    house.add_child(roof)

    create_box("FrontDoor", house, Vector3(0.95, 1.95, 0.10),
        Vector3(0, 0.98, 1.96), Color(0.29, 0.19, 0.13))

    for x in [-1.35, 1.35]:
        create_box("WindowFrame", house, Vector3(0.95, 0.9, 0.12),
            Vector3(x, 1.85, 1.97), Color(0.90, 0.85, 0.72))
        create_box("WindowGlass", house, Vector3(0.72, 0.68, 0.05),
            Vector3(x, 1.85, 2.045), Color(0.24, 0.39, 0.47))
        create_box("WindowDivider", house, Vector3(0.055, 0.72, 0.06),
            Vector3(x, 1.85, 2.08), Color(0.88, 0.82, 0.68))
        create_box("WindowCrossbar", house, Vector3(0.76, 0.05, 0.06),
            Vector3(x, 1.85, 2.08), Color(0.88, 0.82, 0.68))

    create_box("Doorstep", house, Vector3(1.4, 0.14, 0.48),
        Vector3(0, 0.08, 2.12), Color(0.48, 0.46, 0.41))

    make_house_interior(pos, color)


func make_solid_box(parent: Node, object_name: String,
        box_size: Vector3, box_position: Vector3, tint: Color) -> void:
    var body := StaticBody3D.new()
    body.name = object_name
    body.position = box_position
    parent.add_child(body)

    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = box_size
    visual.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 0.95
    visual.material_override = mat
    body.add_child(visual)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = box_size
    collision.shape = shape
    body.add_child(collision)


func make_house_interior(exterior_pos: Vector3, wall_color: Color) -> void:
    var index := house_entries.size()
    var interior_pos := Vector3(200.0 + float(index) * 30.0, 0, 0)

    var room := Node3D.new()
    room.name = "HouseInterior" + str(index + 1)
    room.position = interior_pos
    add_child(room)

    make_solid_box(room, "Floor", Vector3(8, 0.2, 8),
        Vector3(0, -0.1, 0), Color(0.57, 0.43, 0.31))

    var inside_wall := wall_color.lightened(0.25)
    make_solid_box(room, "BackWall", Vector3(8, 3, 0.2),
        Vector3(0, 1.5, -4), inside_wall)
    make_solid_box(room, "LeftWall", Vector3(0.2, 3, 8),
        Vector3(-4, 1.5, 0), inside_wall)
    make_solid_box(room, "RightWall", Vector3(0.2, 3, 8),
        Vector3(4, 1.5, 0), inside_wall)

    # Open doorway at the front.
    make_solid_box(room, "FrontWallLeft", Vector3(1.8, 3, 0.2),
        Vector3(-3.1, 1.5, 4), inside_wall)
    make_solid_box(room, "FrontWallRight", Vector3(1.8, 3, 0.2),
        Vector3(3.1, 1.5, 4), inside_wall)
    make_solid_box(room, "DoorHeader", Vector3(3, 0.6, 0.2),
        Vector3(0, 2.7, 4), inside_wall)


    create_box("Rug", room, Vector3(3.2, 0.025, 2.0),
        Vector3(0, 0.025, -0.3), Color(0.65, 0.39, 0.42))
    create_box("SofaBase", room, Vector3(2.5, 0.48, 0.8),
        Vector3(0, 0.38, -2.5), Color(0.48, 0.29, 0.26))
    create_box("SofaBack", room, Vector3(2.5, 0.9, 0.22),
        Vector3(0, 0.9, -2.85), Color(0.54, 0.34, 0.30))
    create_box("TableTop", room, Vector3(1.5, 0.12, 0.8),
        Vector3(0, 0.55, -0.8), Color(0.35, 0.22, 0.14))
    for x in [-0.6, 0.6]:
        for z in [-0.25, 0.25]:
            create_box("TableLeg", room, Vector3(0.09, 0.48, 0.09),
                Vector3(x, 0.27, -0.8 + z), Color(0.28, 0.18, 0.12))

    var lamp := MeshInstance3D.new()
    var lamp_mesh := SphereMesh.new()
    lamp_mesh.radius = 0.20
    lamp_mesh.height = 0.28
    lamp.mesh = lamp_mesh
    lamp.position = Vector3(0, 2.72, 0)
    var lamp_mat := StandardMaterial3D.new()
    lamp_mat.albedo_color = Color(1.0, 0.84, 0.52)
    lamp_mat.emission_enabled = true
    lamp_mat.emission = Color(1.0, 0.68, 0.28)
    lamp_mat.emission_energy_multiplier = 1.0
    lamp.material_override = lamp_mat
    room.add_child(lamp)

    var light := OmniLight3D.new()
    light.name = "HouseLight"
    light.position = Vector3(0, 2.55, 0)
    light.light_color = Color(1.0, 0.78, 0.48)
    light.light_energy = 3.0
    light.omni_range = 8.0
    light.shadow_enabled = true
    room.add_child(light)

    house_entries.append({
        "exterior": exterior_pos,
        "interior": interior_pos,
        "light": light,
        "lamp": lamp,
        "light_on": true
    })

func make_player() -> void:
    player = CharacterBody3D.new()
    player.name = "BabitoPlayer"
    player.position = Vector3(0, 0.95, 0)
    add_child(player)

    # Legs
    for side in [-1.0, 1.0]:
        var leg := MeshInstance3D.new()
        var leg_mesh := CapsuleMesh.new()
        leg_mesh.radius = 0.115
        leg_mesh.height = 0.62
        leg.mesh = leg_mesh
        leg.position = Vector3(side * 0.16, 0.37, 0)
        var leg_mat := StandardMaterial3D.new()
        leg_mat.albedo_color = Color(0.25, 0.30, 0.42)
        leg.material_override = leg_mat
        player.add_child(leg)

        var shoe := MeshInstance3D.new()
        var shoe_mesh := SphereMesh.new()
        shoe_mesh.radius = 0.16
        shoe_mesh.height = 0.16
        shoe.mesh = shoe_mesh
        shoe.scale = Vector3(1.0, 0.7, 1.35)
        shoe.position = Vector3(side * 0.16, 0.12, 0.055)
        var shoe_mat := StandardMaterial3D.new()
        shoe_mat.albedo_color = Color(0.91, 0.89, 0.82)
        shoe.material_override = shoe_mat
        player.add_child(shoe)

    # Skirt
    var skirt := MeshInstance3D.new()
    var skirt_mesh := CylinderMesh.new()
    skirt_mesh.top_radius = 0.23
    skirt_mesh.bottom_radius = 0.39
    skirt_mesh.height = 0.43
    skirt.mesh = skirt_mesh
    skirt.position.y = 0.83
    var skirt_mat := StandardMaterial3D.new()
    skirt_mat.albedo_color = [
        Color(0.88, 0.36, 0.58),
        Color(0.34, 0.58, 0.39),
        Color(0.30, 0.48, 0.82)
    ][avatar_style]
    skirt.material_override = skirt_mat
    player.add_child(skirt)

    # Shirt / torso
    var torso := MeshInstance3D.new()
    var torso_mesh := CapsuleMesh.new()
    torso_mesh.radius = 0.27
    torso_mesh.height = 0.86
    torso.mesh = torso_mesh
    torso.position.y = 1.35
    var shirt_mat := StandardMaterial3D.new()
    shirt_mat.albedo_color = [
        Color(1.0, 0.78, 0.86),
        Color(0.91, 0.86, 0.75),
        Color(0.72, 0.86, 1.0)
    ][avatar_style]
    torso.material_override = shirt_mat
    player.add_child(torso)

    # Arms
    for side in [-1.0, 1.0]:
        var arm := MeshInstance3D.new()
        var arm_mesh := CapsuleMesh.new()
        arm_mesh.radius = 0.095
        arm_mesh.height = 0.62
        arm.mesh = arm_mesh
        arm.position = Vector3(side * 0.36, 1.31, 0)
        arm.rotation.z = side * -0.16
        var arm_mat := StandardMaterial3D.new()
        arm_mat.albedo_color = Color(0.91, 0.70, 0.57)
        arm.material_override = arm_mat
        player.add_child(arm)

    # Hair behind the head
    var back_hair := MeshInstance3D.new()
    var back_mesh := SphereMesh.new()
    back_mesh.radius = 0.40
    back_mesh.height = 0.95
    back_hair.mesh = back_mesh
    back_hair.position = Vector3(0, 2.13, -0.07)
    back_hair.scale = Vector3(1.0, 1.05, 0.92)
    var hair_mat := StandardMaterial3D.new()
    hair_mat.albedo_color = [
        Color(0.25, 0.12, 0.08),
        Color(0.40, 0.22, 0.10),
        Color(0.16, 0.12, 0.20)
    ][avatar_style]
    back_hair.material_override = hair_mat
    player.add_child(back_hair)

    # Face
    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.34
    head_mesh.height = 0.72
    head.mesh = head_mesh
    head.position = Vector3(0, 2.12, 0.11)
    var skin_mat := StandardMaterial3D.new()
    skin_mat.albedo_color = Color(0.91, 0.70, 0.56)
    head.material_override = skin_mat
    player.add_child(head)

    # Front fringe
    for i in range(5):
        var fringe := MeshInstance3D.new()
        var fringe_mesh := SphereMesh.new()
        fringe_mesh.radius = 0.14
        fringe_mesh.height = 0.22
        fringe.mesh = fringe_mesh
        fringe.scale = Vector3(1.0, 0.8, 0.7)
        fringe.position = Vector3(-0.23 + float(i) * 0.115, 2.39, 0.19)
        fringe.material_override = hair_mat
        player.add_child(fringe)

    # Eyes, facing the forward direction (+Z)
    for side in [-1.0, 1.0]:
        var eye := MeshInstance3D.new()
        var eye_mesh := SphereMesh.new()
        eye_mesh.radius = 0.052
        eye_mesh.height = 0.065
        eye.mesh = eye_mesh
        eye.position = Vector3(side * 0.12, 2.15, 0.423)
        var eye_mat := StandardMaterial3D.new()
        eye_mat.albedo_color = Color(0.10, 0.075, 0.06)
        eye.material_override = eye_mat
        player.add_child(eye)

        var cheek := MeshInstance3D.new()
        var cheek_mesh := SphereMesh.new()
        cheek_mesh.radius = 0.055
        cheek_mesh.height = 0.035
        cheek.mesh = cheek_mesh
        cheek.scale = Vector3(1.4, 0.65, 0.5)
        cheek.position = Vector3(side * 0.19, 2.02, 0.405)
        var cheek_mat := StandardMaterial3D.new()
        cheek_mat.albedo_color = Color(0.94, 0.53, 0.48)
        cheek.material_override = cheek_mat
        player.add_child(cheek)

    # Small hair bow
    var bow := MeshInstance3D.new()
    var bow_mesh := SphereMesh.new()
    bow_mesh.radius = 0.12
    bow_mesh.height = 0.13
    bow.mesh = bow_mesh
    bow.scale = Vector3(1.4, 0.7, 0.6)
    bow.position = Vector3(0.29, 2.43, 0.0)
    var bow_mat := StandardMaterial3D.new()
    bow_mat.albedo_color = [
        Color(0.95, 0.24, 0.53),
        Color(0.98, 0.75, 0.28),
        Color(0.35, 0.72, 0.98)
    ][avatar_style]
    bow.material_override = bow_mat
    player.add_child(bow)

    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.36
    shape.height = 1.9
    collision.shape = shape
    collision.position.y = 0.95
    player.add_child(collision)

    bubble = Label3D.new()
    bubble.font = arabic_font
    player_name_tag = Label3D.new()
    player_name_tag.font = arabic_font
    player_name_tag.name = "PlayerNameTag"
    player_name_tag.text = player_name
    player_name_tag.position = Vector3(0, 3.45, 0)
    player_name_tag.font_size = 28
    player_name_tag.pixel_size = 0.006
    player_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    player_name_tag.modulate = Color(0.0, 0.0, 0.0, 1.0)
    player_name_tag.outline_size = 12
    player.add_child(player_name_tag)

    bubble.position = Vector3(0, 2.9, 0)
    bubble.font_size = 48
    bubble.pixel_size = 0.008
    bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    bubble.modulate = Color(1.0, 0.72, 0.82)
    player.add_child(bubble)

    camera = Camera3D.new()
    camera.position = player.position + Vector3(0, 7.5, 9.5)
    add_child(camera)
    camera.current = true
    camera.look_at(player.position + Vector3(0, 1.0, 0), Vector3.UP)


func make_pond(pos: Vector3) -> void:
    var pond := Node3D.new()
    pond.name = "GardenPond"
    pond.position = pos
    add_child(pond)

    # Rounded stone rim
    var rim := MeshInstance3D.new()
    var rim_mesh := CylinderMesh.new()
    rim_mesh.top_radius = 1.0
    rim_mesh.bottom_radius = 1.0
    rim_mesh.height = 0.30
    rim.mesh = rim_mesh
    rim.scale = Vector3(3.1, 1.0, 2.25)
    rim.position.y = 0.15
    var rim_mat := StandardMaterial3D.new()
    rim_mat.albedo_color = Color(0.48, 0.47, 0.42)
    rim_mat.roughness = 0.95
    rim.material_override = rim_mat
    pond.add_child(rim)

    # Blue water surface
    var water := MeshInstance3D.new()
    var water_mesh := CylinderMesh.new()
    water_mesh.top_radius = 1.0
    water_mesh.bottom_radius = 1.0
    water_mesh.height = 0.045
    water.mesh = water_mesh
    water.scale = Vector3(2.82, 1.0, 1.98)
    water.position.y = 0.315
    var water_mat := StandardMaterial3D.new()
    water_mat.albedo_color = Color(0.12, 0.48, 0.66)
    water_mat.roughness = 0.16
    water_mat.metallic = 0.18
    water.material_override = water_mat
    pond.add_child(water)

    # Small pale stones around the edge
    for i in range(18):
        var angle := TAU * float(i) / 18.0
        var stone := MeshInstance3D.new()
        var stone_mesh := SphereMesh.new()
        stone_mesh.radius = 0.22
        stone_mesh.height = 0.16
        stone.mesh = stone_mesh
        stone.scale = Vector3(1.2, 0.7, 0.85)
        stone.position = Vector3(
            cos(angle) * 2.95,
            0.24,
            sin(angle) * 2.12
        )
        var stone_mat := StandardMaterial3D.new()
        stone_mat.albedo_color = Color(0.70, 0.67, 0.58)
        stone.material_override = stone_mat
        pond.add_child(stone)

    # Reeds at two edges
    for i in range(4):
        var reed := MeshInstance3D.new()
        var reed_mesh := CylinderMesh.new()
        reed_mesh.top_radius = 0.025
        reed_mesh.bottom_radius = 0.045
        reed_mesh.height = 0.65
        reed.mesh = reed_mesh
        reed.position = Vector3(-1.8 + float(i) * 0.18, 0.55, -1.45)
        var reed_mat := StandardMaterial3D.new()
        reed_mat.albedo_color = Color(0.30, 0.43, 0.20)
        reed.material_override = reed_mat
        pond.add_child(reed)


func make_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var title := Label.new()
    title.text = "♡ BABITO 3D ♡"
    title.position = Vector2(20, 18)
    title.add_theme_font_size_override("font_size", 28)
    title.add_theme_color_override("font_color", Color(0.22, 0.38, 0.25))
    layer.add_child(title)

    status_label = Label.new()
    status_label.text = "عالمك الكيوت 💗"
    status_label.position = Vector2(22, 58)
    status_label.add_theme_font_size_override("font_size", 18)
    layer.add_child(status_label)


    var stick := Control.new()
    stick.position = Vector2(28, 500)
    stick.size = Vector2(160, 160)
    stick.mouse_filter = Control.MOUSE_FILTER_STOP
    layer.add_child(stick)
    stick.draw.connect(func():
        stick.draw_circle(Vector2(80, 80), 65, Color(0.20, 0.28, 0.22, 0.30))
        stick.draw_arc(Vector2(80, 80), 65, 0, TAU, 64, Color(0.30, 0.42, 0.32, 0.85), 4)
        var knob := Vector2(80, 80) + joystick_vector * 42
        stick.draw_circle(knob, 28, Color(0.86, 0.88, 0.80, 0.95))
        stick.draw_arc(knob, 28, 0, TAU, 48, Color(0.30, 0.42, 0.32), 3)
    )

    stick.gui_input.connect(func(event: InputEvent):
        if event is InputEventScreenTouch:
            joystick_active = event.pressed
            if not joystick_active:
                joystick_vector = Vector2.ZERO
                stick.queue_redraw()
        elif event is InputEventScreenDrag and joystick_active:
            var touch_pos: Vector2 = event.position
            joystick_vector = (touch_pos - Vector2(80, 80)).limit_length(55) / 55.0
            stick.queue_redraw()
        elif event is InputEventMouseButton:
            joystick_active = event.pressed
            if not joystick_active:
                joystick_vector = Vector2.ZERO
                stick.queue_redraw()
        elif event is InputEventMouseMotion and joystick_active:
            joystick_vector = (event.position - Vector2(80, 80)).limit_length(55) / 55.0
            stick.queue_redraw()
    )

    chat_input = LineEdit.new()
    chat_input.position = Vector2(220, 645)
    chat_input.size = Vector2(820, 44)
    chat_input.placeholder_text = "اكتب رسالة واضغط Enter 💬"
    chat_input.virtual_keyboard_enabled = true
    chat_input.focus_mode = Control.FOCUS_ALL
    chat_input.add_theme_font_size_override("font_size", 20)
    layer.add_child(chat_input)
    chat_input.gui_input.connect(func(event: InputEvent):
        if event is InputEventMouseButton and event.pressed:
            chat_input.grab_focus()
        elif event is InputEventScreenTouch and event.pressed:
            chat_input.grab_focus()
    )
    chat_input.text_submitted.connect(func(message: String):
        var clean_message := message.strip_edges()
        if not clean_message.is_empty():
            if send_shared_chat(clean_message):
                chat_input.clear()
    )
    if OS.has_feature("web"):
        chat_input.visible = false
        _setup_web_chat_input()

    var emote_button := Button.new()
    emote_button.text = "💗 إيماءات"
    emote_button.position = Vector2(1060, 620)
    emote_button.size = Vector2(170, 48)
    layer.add_child(emote_button)
    emote_button.pressed.connect(show_emotes)

    enter_house_button = Button.new()
    enter_house_button.text = "🏠 ادخل البيت"
    enter_house_button.position = Vector2(1010, 120)
    enter_house_button.size = Vector2(220, 48)
    enter_house_button.visible = false
    layer.add_child(enter_house_button)
    enter_house_button.pressed.connect(try_enter_nearby_house)

    exit_house_button = Button.new()
    exit_house_button.text = "🚪 اطلع من البيت"
    exit_house_button.position = Vector2(1010, 174)
    exit_house_button.size = Vector2(220, 48)
    exit_house_button.visible = false
    layer.add_child(exit_house_button)
    exit_house_button.pressed.connect(leave_house)

    light_switch_button = Button.new()
    light_switch_button.text = "💡 إطفاء الأنوار"
    light_switch_button.position = Vector2(1010, 228)
    light_switch_button.size = Vector2(220, 48)
    light_switch_button.visible = false
    layer.add_child(light_switch_button)
    light_switch_button.pressed.connect(toggle_house_light)

    var chat_log_button := Button.new()
    chat_log_button.text = "📜 سجل الشات"
    chat_log_button.position = Vector2(1060, 565)
    chat_log_button.size = Vector2(170, 45)
    layer.add_child(chat_log_button)

    chat_log_panel = PanelContainer.new()
    chat_log_panel.position = Vector2(760, 80)
    chat_log_panel.size = Vector2(470, 440)
    chat_log_panel.visible = false
    layer.add_child(chat_log_panel)

    var chat_column := VBoxContainer.new()
    chat_log_panel.add_child(chat_column)

    var chat_heading := Label.new()
    chat_heading.text = "سجل الرسائل 💬"
    chat_heading.add_theme_font_size_override("font_size", 22)
    chat_column.add_child(chat_heading)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    chat_column.add_child(scroll)

    chat_history_box = VBoxContainer.new()
    chat_history_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(chat_history_box)

    chat_log_button.pressed.connect(func():
        chat_log_panel.visible = not chat_log_panel.visible
        if chat_log_panel.visible:
            refresh_chat_history()
    )

    enter_house_button = Button.new()
    enter_house_button.text = "🏠 ادخل البيت"
    enter_house_button.position = Vector2(1010, 120)
    enter_house_button.size = Vector2(220, 48)
    enter_house_button.visible = false
    layer.add_child(enter_house_button)
    enter_house_button.pressed.connect(try_enter_nearby_house)

    exit_house_button = Button.new()
    exit_house_button.text = "🚪 اطلع من البيت"
    exit_house_button.position = Vector2(1010, 174)
    exit_house_button.size = Vector2(220, 48)
    exit_house_button.visible = false
    layer.add_child(exit_house_button)
    exit_house_button.pressed.connect(leave_house)

    light_switch_button = Button.new()
    light_switch_button.text = "💡 إطفاء الأنوار"
    light_switch_button.position = Vector2(1010, 228)
    light_switch_button.size = Vector2(220, 48)
    light_switch_button.visible = false
    layer.add_child(light_switch_button)
    light_switch_button.pressed.connect(toggle_house_light)

    var help := Label.new()
    help.text = "حرّك العصا للمشي • اكتب رسالة للشات"
    help.position = Vector2(220, 605)
    help.add_theme_font_size_override("font_size", 16)
    layer.add_child(help)

func connect_chat_server() -> void:
    chat_socket = WebSocketPeer.new()
    chat_join_sent = false
    var err := chat_socket.connect_to_url("wss://superworld-chat.onrender.com")
    if err != OK:
        push_warning("تعذر بدء اتصال شات بابيتو: " + str(err))


func send_shared_chat(message: String) -> bool:
    if chat_socket == null:
        push_warning("اتصال الشات غير جاهز.")
        return false

    if chat_socket.get_ready_state() != WebSocketPeer.STATE_OPEN or not chat_join_sent:
        push_warning("انتظر اتصال الشات بالسيرفر ثم جرّب إرسال الرسالة.")
        return false

    var payload := {
        "type": "chat",
        "message": message
    }
    return chat_socket.send_text(JSON.stringify(payload)) == OK


func poll_chat_server() -> void:
    if chat_socket == null:
        return

    chat_socket.poll()
    var state := chat_socket.get_ready_state()

    if state == WebSocketPeer.STATE_OPEN and not chat_join_sent:
        var join_payload := {
            "type": "join",
            "name": player_name
        }
        if chat_socket.send_text(JSON.stringify(join_payload)) == OK:
            chat_join_sent = true

    while chat_socket.get_available_packet_count() > 0:
        var raw := chat_socket.get_packet().get_string_from_utf8()
        var data: Variant = JSON.parse_string(raw)

        if not data is Dictionary:
            continue

        match str(data.get("type", "")):
            "chat":
                var sender := str(data.get("name", ""))
                var message := str(data.get("message", "")).strip_edges()
                if sender.is_empty() or message.is_empty():
                    continue

                var stamp := Time.get_time_string_from_system()
                chat_history.append("[" + stamp + "] " + sender + ": " + message)
                while chat_history.size() > 200:
                    chat_history.pop_front()
                save_chat_history()
                refresh_chat_history()

                if sender == player_name:
                    show_message(message)

            "name_error":
                push_warning("السيرفر رفض اسم اللاعب: " + str(data.get("message", "")))

            "joined":
                print("💗 اتصل بابيتو بالشات المشترك بنجاح.")

            "welcome":
                print("🌐 تم الاتصال بسيرفر شات بابيتو.")

            "player_joined":
                print("👤 انضم للشات: " + str(data.get("name", "")))


func show_message(message: String) -> void:
    bubble.text = "♡ " + message + " ♡"
    if chat_timer:
        chat_timer.queue_free()
    chat_timer = Timer.new()
    chat_timer.wait_time = 5.0
    chat_timer.one_shot = true
    add_child(chat_timer)
    chat_timer.timeout.connect(func():
        bubble.text = ""
        chat_timer.queue_free()
        chat_timer = null
    )
    chat_timer.start()

func show_emotes() -> void:
    var popup := AcceptDialog.new()
    popup.title = "اختار إيماءة 💗"
    popup.dialog_text = "اضغط إيماءة حتى تطلع رسالتها فوق شخصيتك."
    add_child(popup)
    popup.add_cancel_button("إغلاق")
    popup.confirmed.connect(func():
        show_message("💗 يرسل قلباً!")
    )
    popup.popup_centered()

func load_chat_history() -> void:
    var file_path := "user://chat_history.json"
    if not FileAccess.file_exists(file_path):
        refresh_chat_history()
        return
    var file := FileAccess.open(file_path, FileAccess.READ)
    if file == null:
        refresh_chat_history()
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Array:
        chat_history.clear()
        for item in parsed:
            chat_history.append(str(item))
        while chat_history.size() > 200:
            chat_history.pop_front()
    refresh_chat_history()


func save_chat_history() -> void:
    var file := FileAccess.open("user://chat_history.json", FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(chat_history))


func add_chat_message(message: String) -> void:
    var stamp := Time.get_time_string_from_system()
    chat_history.append("[" + stamp + "] " + player_name + ": " + message)
    while chat_history.size() > 200:
        chat_history.pop_front()
    save_chat_history()
    refresh_chat_history()


func refresh_chat_history() -> void:
    if chat_history_box == null:
        return
    for child in chat_history_box.get_children():
        child.free()
    for message in chat_history:
        var label := Label.new()
        label.text = message
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.custom_minimum_size.y = 34
        label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
        label.add_theme_font_size_override("font_size", 20)
        chat_history_box.add_child(label)


func _process(_delta: float) -> void:
    if not profile_complete or player == null or camera == null:
        return

    poll_chat_server()
    if inside_house_index >= 0:
        enter_house_button.visible = false
        exit_house_button.visible = true
        light_switch_button.visible = true
        return

    exit_house_button.visible = false
    light_switch_button.visible = false
    var nearby := false
    for entry in house_entries:
        var door_pos: Vector3 = entry["exterior"] + Vector3(0, 0, 2.2)
        var player_xz := Vector2(player.global_position.x, player.global_position.z)
        var door_xz := Vector2(door_pos.x, door_pos.z)
        if player_xz.distance_to(door_xz) < 3.2:
            nearby = true
            break
    enter_house_button.visible = nearby


func try_enter_nearby_house() -> void:
    if inside_house_index >= 0:
        return
    var best_index := -1
    var best_distance := 3.2
    for i in range(house_entries.size()):
        var door_pos: Vector3 = house_entries[i]["exterior"] + Vector3(0, 0, 2.2)
        var player_xz := Vector2(player.global_position.x, player.global_position.z)
        var door_xz := Vector2(door_pos.x, door_pos.z)
        var distance := player_xz.distance_to(door_xz)
        if distance < best_distance:
            best_distance = distance
            best_index = i
    if best_index < 0:
        return

    inside_house_index = best_index
    var entry: Dictionary = house_entries[best_index]
    # Always return outside the front door at ground level.
    outside_position = entry["exterior"] + Vector3(0, 1.0, 3.2)
    player.global_position = entry["interior"] + Vector3(0, 0.03, 1.2)
    player.velocity = Vector3.ZERO

    sun_light.light_energy = 0.0
    world_environment.environment.ambient_light_energy = 0.18 if entry["light_on"] else 0.035

    camera.global_position = player.global_position + Vector3(0, 6.5, 7.5)
    camera.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)
    status_label.text = "داخل البيت 🏠"
    light_switch_button.text = "💡 إطفاء الأنوار" if entry["light_on"] else "💡 تشغيل الأنوار"


func leave_house() -> void:
    if inside_house_index < 0:
        return
    player.global_position = outside_position
    player.velocity = Vector3.ZERO
    inside_house_index = -1

    sun_light.light_energy = 1.15
    world_environment.environment.ambient_light_energy = 0.65
    camera.global_position = player.global_position + Vector3(0, 7.5, 9.5)
    camera.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)

    status_label.text = "رجعت للحديقة 🌳"
    enter_house_button.visible = false
    exit_house_button.visible = false
    light_switch_button.visible = false


func toggle_house_light() -> void:
    if inside_house_index < 0:
        return
    var entry: Dictionary = house_entries[inside_house_index]
    var new_state := not bool(entry["light_on"])
    entry["light_on"] = new_state
    house_entries[inside_house_index] = entry

    var light: OmniLight3D = entry["light"]
    light.visible = new_state
    var lamp: MeshInstance3D = entry["lamp"]
    lamp.visible = new_state

    world_environment.environment.ambient_light_energy = 0.18 if new_state else 0.035
    light_switch_button.text = "💡 إطفاء الأنوار" if new_state else "💡 تشغيل الأنوار"
    status_label.text = "الأنوار اشتغلت 💡" if new_state else "الأنوار انطفت 🌙"


func _physics_process(delta: float) -> void:
    if not profile_complete or player == null or camera == null:
        return

    var direction := Vector3(joystick_vector.x, 0, joystick_vector.y)
    if direction.length() > 0.1:
        direction = direction.normalized()
        player.velocity.x = direction.x * speed
        player.velocity.z = direction.z * speed
        player.rotation.y = atan2(direction.x, direction.z)
    else:
        player.velocity.x = move_toward(player.velocity.x, 0, speed * 5 * delta)
        player.velocity.z = move_toward(player.velocity.z, 0, speed * 5 * delta)

    player.velocity.y -= 20.0 * delta
    player.move_and_slide()

    # الخروج تلقائياً عند الوصول إلى باب البيت من الداخل
    if inside_house_index >= 0 and inside_house_index < house_entries.size():
        var entry: Dictionary = house_entries[inside_house_index]
        var interior_door: Vector3 = entry["interior"] + Vector3(0.0, 0.0, 3.2)
        var near_door_x: bool = absf(player.global_position.x - interior_door.x) < 1.35

        if near_door_x and player.global_position.z >= interior_door.z - 0.2:
            leave_house()

    var camera_target: Vector3 = player.global_position + Vector3(0, 7.5, 9.5)
    camera.global_position = camera.global_position.lerp(camera_target, min(1.0, delta * 4.0))
    camera.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)


var profile_complete := false


func load_profile() -> void:
    profile_complete = false
    var config := ConfigFile.new()
    if config.load("user://player_profile.cfg") == OK:
        var saved_name := str(config.get_value("profile", "name", "")).strip_edges()
        var saved_avatar := int(config.get_value("profile", "avatar", -1))
        if not saved_name.is_empty() and saved_avatar >= 0 and saved_avatar <= 2:
            player_name = saved_name
            avatar_style = saved_avatar
            profile_complete = true
    if not profile_complete:
        player_name = ""
        avatar_style = 0


func save_profile() -> void:
    var config := ConfigFile.new()
    config.set_value("profile", "name", player_name)
    config.set_value("profile", "avatar", avatar_style)
    var result := config.save("user://player_profile.cfg")
    if result != OK:
        push_error("تعذر حفظ ملف الشخصية.")


func make_profile_screen() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var backdrop := ColorRect.new()
    backdrop.color = Color(0.98, 0.90, 0.95)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(backdrop)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(420, 390)
    center.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 14)
    panel.add_child(content)

    var title := Label.new()
    title.text = "♡ أهلاً بيك بعالم BABITO ♡"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 25)
    content.add_child(title)

    var description := Label.new()
    description.text = "قبل لا تدخل العالم، اختار اسمك وشخصيتك 💗"
    description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(description)

    var name_label := Label.new()
    name_label.text = "اكتب اسم اللاعب:"
    content.add_child(name_label)

    var name_input := LineEdit.new()
    name_input.placeholder_text = "اسمك هنا..."
    name_input.max_length = 24
    name_input.custom_minimum_size = Vector2(0, 42)
    content.add_child(name_input)

    var avatar_label := Label.new()
    avatar_label.text = "اختار شكل شخصيتك:"
    content.add_child(avatar_label)

    var avatar_picker := OptionButton.new()
    avatar_picker.add_item("🌸 الشخصية الوردية")
    avatar_picker.add_item("🌿 الشخصية الخضراء")
    avatar_picker.add_item("💙 الشخصية الزرقاء")
    avatar_picker.custom_minimum_size = Vector2(0, 42)
    content.add_child(avatar_picker)

    var hint := Label.new()
    hint.text = "لازم تكتب الاسم وتختار الشخصية حتى تدخل."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(hint)

    var enter_button := Button.new()
    enter_button.text = "دخول العالم ✨"
    enter_button.custom_minimum_size = Vector2(0, 48)
    enter_button.disabled = true
    content.add_child(enter_button)

    var update_button_state := func(_value = null) -> void:
        enter_button.disabled = (
            name_input.text.strip_edges().is_empty()
            or avatar_picker.selected < 0
        )

    name_input.text_changed.connect(func(_new_text: String) -> void:
        update_button_state.call()
    )
    avatar_picker.item_selected.connect(func(_index: int) -> void:
        update_button_state.call()
    )

    enter_button.pressed.connect(func() -> void:
        var chosen_name := name_input.text.strip_edges()
        if chosen_name.is_empty() or avatar_picker.selected < 0:
            return
        player_name = chosen_name
        avatar_style = avatar_picker.selected
        save_profile()
        get_tree().reload_current_scene()
    )


func _setup_web_chat_input() -> void:
    var callback = JavaScriptBridge.create_callback(_on_web_chat_submit)
    JavaScriptBridge.get_interface("window").set("babitoChatSubmit", callback)
    JavaScriptBridge.eval("""
    (() => {
        if (document.getElementById('babito-web-chat')) return;
        const form = document.createElement('form');
        form.id = 'babito-web-chat';
        form.style.cssText =
            'position:fixed;left:14%;bottom:calc(12px + env(safe-area-inset-bottom));' +
            'width:70%;z-index:2147483647;display:flex;gap:6px;direction:rtl;' +
            'box-sizing:border-box;font-family:Arial,sans-serif;';
        const input = document.createElement('input');
        input.type = 'text';
        input.id = 'babito-web-chat-text';
        input.placeholder = 'اكتب رسالتك هنا 💬';
        input.autocomplete = 'off';
        input.enterKeyHint = 'send';
        input.style.cssText =
            'flex:1;min-width:0;height:44px;box-sizing:border-box;' +
            'font-size:16px;padding:8px 12px;border:2px solid #f09acb;' +
            'border-radius:12px;background:#fff;color:#222;';
        const button = document.createElement('button');
        button.type = 'submit';
        button.textContent = 'إرسال';
        button.style.cssText =
            'height:44px;padding:0 14px;font-size:16px;border:0;' +
            'border-radius:12px;background:#f09acb;color:#222;';
        form.append(input, button);
        document.body.appendChild(form);
        form.addEventListener('submit', (event) => {
            event.preventDefault();
            const message = input.value.trim();
            if (!message || !window.babitoChatSubmit) return;
            window.babitoChatSubmit(message);
            input.value = '';
            input.focus();
        });
    })();
    """, true)


func _on_web_chat_submit(args: Array) -> void:
    if args.is_empty():
        return
    var message := str(args[0]).strip_edges()
    if not message.is_empty():
        send_shared_chat(message)
