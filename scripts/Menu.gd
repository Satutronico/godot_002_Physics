extends Node2D

func _ready() -> void:
    print("[Menu._ready] Menu loaded, building UI")
    var bg = ColorRect.new()
    bg.color = Color(0.08, 0.13, 0.19)
    bg.size = get_viewport_rect().size
    add_child(bg)

    var title = Label.new()
    title.text = "Godot Physics MVP"
    title.position = Vector2(240, 160)
    title.add_theme_font_size_override("font_size", 36)
    title.modulate = Color(0.96, 0.97, 0.9)
    add_child(title)

    var help = Label.new()
    help.text = "Arrow keys / A/D to move, Space to jump"
    help.position = Vector2(200, 240)
    help.add_theme_font_size_override("font_size", 20)
    help.modulate = Color(0.83, 0.89, 0.92)
    add_child(help)

    var start = Label.new()
    start.text = "Press Enter or Space to Start"
    start.position = Vector2(220, 300)
    start.add_theme_font_size_override("font_size", 24)
    start.modulate = Color(0.84, 0.95, 0.98)
    add_child(start)
    print("[Menu._ready] Menu UI complete")

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or Input.is_action_pressed("ui_accept"):
            print("[Menu._input] Starting game...")
            get_tree().change_scene_to_file("res://scenes/Game.tscn")
        elif event.keycode == KEY_ESCAPE:
            get_tree().quit()

