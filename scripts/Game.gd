extends Node2D

const GRAVITY := 1600.0
const JUMP_SPEED := -600.0
const MOVE_SPEED := 280.0
const PLAYER_SIZE := Vector2(34, 64)
const BARREL_RADIUS := 16.0
const BARREL_SPAWN_Y := -20.0
const LEVEL_LIVING_TIME := [20.0, 30.0, 40.0]

var level := 1
var time_alive := 0.0
var spawn_timer := 0.0
var barrels := []
var game_over := false
var win := false

var player := {
    "pos": Vector2(120, 420),
    "vel": Vector2.ZERO,
    "on_ground": false
}

var ground_segments := []
var fixed_platforms := []
var moving_platforms := []

var hud: Label

func _ready() -> void:
    print("[Game._ready] START - Level=", level)
    set_process(true)
    _build_hud()
    print("[Game._ready] HUD built")
    _reset_level(level)
    print("[Game._ready] Level reset, player pos=", player.pos)
    queue_redraw()
    print("[Game._ready] END")

func _build_hud() -> void:
    hud = Label.new()
    hud.position = Vector2(12, 8)
    hud.add_theme_font_size_override("font_size", 18)
    add_child(hud)

    var hint = Label.new()
    hint.text = "A/D or Left/Right: move  Space: jump  R: restart  N: next level  Esc: menu"
    hint.position = Vector2(12, 34)
    hint.add_theme_font_size_override("font_size", 14)
    add_child(hint)

func _reset_level(l:int) -> void:
    level = clamp(l, 1, 3)
    time_alive = 0.0
    spawn_timer = 0.0
    barrels.clear()
    game_over = false
    win = false

    player.pos = Vector2(120, 420)
    player.vel = Vector2.ZERO
    player.on_ground = false

    fixed_platforms.clear()
    moving_platforms.clear()
    ground_segments.clear()

    match level:
        1:
            # Slope down from right to left, barrels roll left naturally
            ground_segments.append({"from": Vector2(960, 400), "to": Vector2(0, 520)})
        2:
            # Sloped ground from right to left for barrels to roll left across screen
            ground_segments.append({"from": Vector2(960, 400), "to": Vector2(0, 520)})
            fixed_platforms.append({"pos": Vector2(340, 420), "size": Vector2(160, 20)})
            fixed_platforms.append({"pos": Vector2(620, 360), "size": Vector2(170, 20)})
        3:
            # Slopes with moving platforms, slope from right to left for barrels
            ground_segments.append({"from": Vector2(0, 520), "to": Vector2(500, 520)})
            ground_segments.append({"from": Vector2(880, 420), "to": Vector2(500, 520)})
            ground_segments.append({"from": Vector2(880, 420), "to": Vector2(960, 400)})
            moving_platforms.append({"pos": Vector2(320, 380), "size": Vector2(140, 16), "dir": Vector2(0, 1), "range": Vector2(340, 460), "speed": 100.0})
            moving_platforms.append({"pos": Vector2(620, 300), "size": Vector2(170, 16), "dir": Vector2(1, 0), "range": Vector2(520, 760), "speed": 130.0})
    queue_redraw()

func _process(delta: float) -> void:
    if game_over or win:
        return

    _process_player(delta)
    _process_barrels(delta)
    _process_platforms(delta)

    time_alive += delta
    spawn_timer -= delta
    if spawn_timer <= 0.0:
        _spawn_barrel()
        spawn_timer = 1.6 - (level - 1) * 0.4
        spawn_timer = max(0.7, spawn_timer)

    if time_alive >= LEVEL_LIVING_TIME[level-1]:
        win = true
        SaveData.best_level = max(SaveData.best_level, level)

    if !game_over and !win:
        SaveData.best_score = max(SaveData.best_score, int(time_alive))

    _update_hud()
    if int(time_alive * 10) % 10 == 0:
        print("[Game._process] time=", "%.1f" % time_alive, " barrels=", barrels.size(), " player.pos=", player.pos)
    queue_redraw()

func _process_player(delta: float) -> void:
    var input_x = 0.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        input_x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        input_x += 1.0

    # Movement along ground direction when on ground
    if player.on_ground:
        var floor = _floor_info_at_x(player.pos.x)
        if floor and abs(floor.angle) > 0.01:
            # On sloped ground, move along slope
            var slope_dir = Vector2(cos(floor.angle), sin(floor.angle)).normalized()
            var move_dir = slope_dir if cos(floor.angle) > 0 else -slope_dir
            player.pos += move_dir * input_x * MOVE_SPEED * delta
        else:
            # On flat ground or platform, move horizontally
            player.pos.x += input_x * MOVE_SPEED * delta
    else:
        # In air, move horizontally
        player.pos.x += input_x * MOVE_SPEED * delta

    # Jump logic: only jump when on ground
    if Input.is_key_pressed(KEY_SPACE) and player.on_ground:
        player.vel.y = JUMP_SPEED
        player.on_ground = false

    # Apply gravity only for jump/fall (not on ground)
    if not player.on_ground:
        player.vel.y += GRAVITY * delta
    else:
        player.vel.y = 0.0

    # Update Y position with velocity (for jump arc)
    player.pos.y += player.vel.y * delta

    _apply_ground_collision()
    _apply_platform_collision()

func _apply_ground_collision() -> void:
    var floor = _floor_info_at_x(player.pos.x)
    var player_bottom = 26  # stick figure feet are ~26 pixels below player.pos
    if floor != null:
        var floor_y = floor.y
        if player.pos.y + player_bottom >= floor_y:
            player.pos.y = floor_y - player_bottom
            player.vel.y = 0.0
            player.on_ground = true
            var slope = floor.angle
            if abs(slope) > 0.01:
                var down = Vector2(cos(slope), sin(slope))
                player.vel += down * 48
        elif player.vel.y > 0:
            player.on_ground = false
    else:
        player.on_ground = false

    if player.pos.x < 0:
        player.pos.x = 0
        player.vel.x = 0
    elif player.pos.x > 940:
        player.pos.x = 940
        player.vel.x = 0

    if player.pos.y > 700:
        game_over = true

func _apply_platform_collision() -> void:
    var player_bottom = 26
    for platform in fixed_platforms + moving_platforms:
        var r = Rect2(platform.pos - Vector2(0, player_bottom), platform.size)
        if r.has_point(player.pos) and player.vel.y >= 0.0:
            player.pos.y = platform.pos.y - player_bottom
            player.vel.y = 0.0
            player.on_ground = true

func _process_barrels(delta: float) -> void:
    for barrel in barrels:
        barrel.pos += barrel.vel * delta
        barrel.vel.y += GRAVITY * delta * 0.24

        var floor = _floor_info_at_x(barrel.pos.x)
        if floor != null:
            var floor_y = floor.y - BARREL_RADIUS
            if barrel.pos.y >= floor_y:
                barrel.pos.y = floor_y
                var angle = floor.angle
                # Slide removes vertical component, leaving only horizontal
                barrel.vel = barrel.vel.slide(Vector2(0, 1))
                # Apply gravity component along slope direction
                var slope_dir = Vector2(cos(angle), sin(angle))
                var gravity_component = GRAVITY * sin(angle) * delta * 0.24
                barrel.vel += slope_dir * gravity_component
                # Reduced friction damping for easier rolling
                barrel.vel *= 0.994

        # Platform collision for barrels
        for platform in fixed_platforms + moving_platforms:
            var platform_top = platform.pos.y
            var barrel_bottom = barrel.pos.y + BARREL_RADIUS
            var barrel_left = barrel.pos.x - BARREL_RADIUS
            var barrel_right = barrel.pos.x + BARREL_RADIUS
            if barrel_right > platform.pos.x and barrel_left < platform.pos.x + platform.size.x and barrel_bottom >= platform_top and barrel.pos.y < platform_top and barrel.vel.y >= 0:
                barrel.pos.y = platform_top - BARREL_RADIUS
                barrel.vel.y = 0
                # Apply friction for rolling on platform
                barrel.vel *= 0.995
                break  # Only collide with one platform

        if barrel.pos.y > 780 or barrel.pos.x < -40 or barrel.pos.x > 1000:
            barrel.dead = true

        # Player hitbox: roughly 12 px wide, 26 px tall; barrel radius 16
        var player_hitbox_radius = 20.0
        if player.pos.distance_to(barrel.pos) < BARREL_RADIUS + player_hitbox_radius:
            game_over = true

    barrels = barrels.filter(func(x): return not x.dead)

func _process_platforms(delta: float) -> void:
    for p in moving_platforms:
        p.pos += p.dir * p.speed * delta
        if p.dir.x != 0:
            if p.pos.x < p.range.x:
                p.pos.x = p.range.x
                p.dir.x = 1
            elif p.pos.x > p.range.y:
                p.pos.x = p.range.y
                p.dir.x = -1
        else:
            if p.pos.y < p.range.x:
                p.pos.y = p.range.x
                p.dir.y = 1
            elif p.pos.y > p.range.y:
                p.pos.y = p.range.y
                p.dir.y = -1

func _floor_info_at_x(x: float) -> Variant:
    var found = null
    for seg in ground_segments:
        var x1 = seg.from.x
        var x2 = seg.to.x
        if x1 <= x and x <= x2 or x2 <= x and x <= x1:
            var t = 0.0
            if abs(x2 - x1) > 0.001:
                t = (x - x1) / (x2 - x1)
            var y = lerp(seg.from.y, seg.to.y, t)
            var ang = atan2(seg.to.y - seg.from.y, seg.to.x - seg.from.x)
            found = {"y": y, "angle": ang}
            break
    return found

func _spawn_barrel() -> void:
    var start_x = 960
    var start_y = BARREL_SPAWN_Y
    var vel = Vector2(-90 - level * 40, 60)
    barrels.append({"pos": Vector2(start_x, start_y), "vel": vel, "dead": false})

func _update_hud() -> void:
    hud.text = "Level: %d  Time: %.1f / %.1f  Barrels: %d  Best Score: %d  Best Level: %d" % [level, time_alive, LEVEL_LIVING_TIME[level-1], barrels.size(), SaveData.best_score, SaveData.best_level]
    if game_over:
        hud.text += "    GAME OVER - R to retry, Esc for menu"
    elif win:
        hud.text += "    LEVEL COMPLETE! N for next, R to retry"

func _draw() -> void:
    print("[Game._draw] START - ground_segs=", ground_segments.size(), " barrels=", barrels.size())
    var vp = get_viewport_rect()
    print("[Game._draw] viewport size=", vp.size)
    draw_rect(Rect2(Vector2.ZERO, vp.size), Color(0.07, 0.12, 0.19))

    for seg in ground_segments:
        draw_line(seg.from, seg.to, Color(0.66, 0.40, 0.12), 8)

    for p in fixed_platforms:
        draw_rect(Rect2(p.pos, p.size), Color(0.22, 0.50, 0.24))

    for p in moving_platforms:
        draw_rect(Rect2(p.pos, p.size), Color(0.18, 0.34, 0.68))

    # Draw stick figure player
    var player_head_pos = player.pos - Vector2(0, 20)
    draw_circle(player_head_pos, 8, Color(0.98, 0.82, 0.71))  # head (skin tone)

    var body_top = player.pos
    var body_bottom = player.pos + Vector2(0, 16)
    draw_line(body_top, body_bottom, Color(0.29, 0.88, 0.45), 6)  # body (green)

    var shoulder_left = player.pos + Vector2(-10, 2)
    var shoulder_right = player.pos + Vector2(10, 2)
    draw_line(shoulder_left - Vector2(12, 0), shoulder_left, Color(0.98, 0.82, 0.71), 4)  # left arm
    draw_line(shoulder_right, shoulder_right + Vector2(12, 0), Color(0.98, 0.82, 0.71), 4)  # right arm

    var foot_left = body_bottom + Vector2(-6, 10)
    var foot_right = body_bottom + Vector2(6, 10)
    draw_line(body_bottom, foot_left, Color(0.2, 0.2, 0.2), 4)  # left leg
    draw_line(body_bottom, foot_right, Color(0.2, 0.2, 0.2), 4)  # right leg

    for barrel in barrels:
        draw_circle(barrel.pos, BARREL_RADIUS, Color(0.79, 0.58, 0.18))

    if game_over:
        # draw_string requires explicit font resources; use HUD text instead via Label
        pass
    elif win:
        pass

func _input(event):
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_R:
            _reset_level(level)
        elif event.keycode == KEY_N:
            _reset_level(min(3, level + 1))
        elif event.keycode == KEY_ESCAPE:
            get_tree().change_scene_to_file("res://scenes/Menu.tscn")
