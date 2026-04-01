# CLAUDE.md — Godot 4 Game Dev from Scratch

Instructions for starting a new Godot 4 PC game using only CLI tools and GDScript.
No Godot editor GUI required. All files are created manually.

---

## Environment

- **Godot binary:** `C:\Godot4\Godot_v4.6.1-stable_win64_console.exe`
- **Shell:** PowerShell (Windows). Use `& "path\to\bin" --args` syntax.
- **VSCode env vars** (`.vscode/settings.json`):
  ```json
  {
      "terminal.integrated.env.windows": {
          "PATH": "C:\\Godot4;${env:PATH}",
          "GODOT": "C:\\Godot4\\Godot_v4.6.1-stable_win64_console.exe",
          "GODOT_GUI": "C:\\Godot4\\Godot_v4.6.1-stable_win64.exe"
      }
  }
  ```
- **Launch game:** `& $Env:GODOT --path "$PWD"`
- **Launch headless:** `& $Env:GODOT --path "$PWD" --headless`

---

## Project bootstrap

Minimum files to create a runnable Godot 4 project — no editor needed:

### `project.godot`
```ini
; Godot Project Configuration File

config_version=5

[application]

config/name="Your Game Name"
config/features=PackedStringArray("4.6", "Forward Plus")
run/main_scene="res://scenes/Menu.tscn"
config/icon="res://icon.svg"

[display]

window/size/viewport_width=640
window/size/viewport_height=640
window/size/resizable=false

[autoload]

SaveData="*res://scripts/SaveData.gd"

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

- Use `gl_compatibility` for 2D games — lighter, broader hardware support.
- `*` prefix on autoload path makes it a global singleton Node.
- Set `resizable=false` for fixed-pixel grid games.

### `.gitignore`
```
.godot/
export/
*.exe
```

### Minimal `.tscn` (scene file)
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Game.gd" id="1_game"]

[node name="Game" type="Node2D"]
script = ExtResource("1_game")
```

For UI scenes use `type="Control"` as root with `anchor_right=1.0` and `anchor_bottom=1.0`.

### Minimal icon (`icon.svg`)
Hand-write SVG XML — no external tool needed:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect width="128" height="128" fill="#141414"/>
  <!-- your shapes here -->
</svg>
```

---

## Folder structure convention

```
project_root/
├── project.godot
├── icon.svg
├── .gitignore
├── CLAUDE.md
├── README.md
├── scenes/
│   ├── Menu.tscn      # Entry point
│   └── Game.tscn      # Gameplay
└── scripts/
    ├── SaveData.gd    # Autoload singleton
    ├── Menu.gd        # Menu logic
    └── Game.gd        # Game logic
```

---

## GDScript patterns

### Game loop — use `_process(delta)` with a tick timer
Never use `_physics_process` for grid/turn-based games. Drive logic with a software timer:

```gdscript
var tick_timer : float = 0.0
var tick_rate  : float = 0.15  # seconds per step

func _process(delta: float) -> void:
    tick_timer += delta
    if tick_timer >= tick_rate:
        tick_timer -= tick_rate  # subtract, don't reset — avoids drift
        _step()
```

### Procedural rendering — `_draw()` + `queue_redraw()`
Attach to `Node2D`. Call `queue_redraw()` whenever state changes; Godot will invoke `_draw()` on the next frame.

```gdscript
func _draw() -> void:
    draw_rect(Rect2(x, y, w, h), color)
    draw_circle(Vector2(cx, cy), radius, color)
    draw_line(Vector2(ax, ay), Vector2(bx, by), color)
```

### Build UI programmatically — no scene editor needed
```gdscript
func _ready() -> void:
    var lbl := Label.new()
    lbl.text = "Hello"
    lbl.position = Vector2(100, 50)
    lbl.size = Vector2(200, 30)
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.add_theme_font_size_override("font_size", 24)
    lbl.modulate = Color(0.9, 0.9, 0.9)
    add_child(lbl)

    var btn := Button.new()
    btn.text = "Start"
    btn.position = Vector2(220, 300)
    btn.size = Vector2(200, 56)
    btn.pressed.connect(func() -> void: _on_start())
    add_child(btn)

    var input := LineEdit.new()
    input.placeholder_text = "Your name..."
    input.position = Vector2(220, 220)
    input.size = Vector2(200, 44)
    input.text_submitted.connect(func(_t: String) -> void: _on_start())
    add_child(input)
```

### Scene transitions
```gdscript
get_tree().change_scene_to_file("res://scenes/Menu.tscn")
```

### Input handling
```gdscript
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_right"):
        pass  # built-in: arrow keys + D-pad
    if event.is_action_pressed("ui_accept"):
        pass  # Enter / Space
```

### Persistence with ConfigFile
```gdscript
const SAVE_PATH := "user://save.cfg"  # OS user-data folder, always writable

func save_data() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("section", "key", value)
    cfg.save(SAVE_PATH)

func load_data() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return  # file doesn't exist yet — use defaults
    var val = cfg.get_value("section", "key", default_value)
```

### Autoload singleton pattern
`SaveData.gd` (registered in `project.godot` under `[autoload]`) is accessible from any script:
```gdscript
SaveData.player_name = "Alice"
SaveData.save_data()
```

### Time formatting helper
```gdscript
func _fmt_time(secs: float) -> String:
    var s := int(secs)
    return "%d:%02d" % [s / 60, s % 60]
```

### FPS display
```gdscript
fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
```

---

## GDScript gotchas

### Type inference fails on untyped Array indexing
```gdscript
# WRONG — GDScript cannot infer type from untyped Array
var e := my_array[i]

# CORRECT — declare type explicitly
var e: Dictionary = my_array[i]
```

### Custom sort with tiebreaker
```gdscript
array.sort_custom(func(a, b):
    if a.score != b.score:
        return a.score > b.score   # primary: higher score first
    return a.time < b.time         # tiebreaker: lower time first
)
```

### Subtract tick_timer instead of resetting
```gdscript
tick_timer -= tick_rate  # correct: preserves overshoot
tick_timer  = 0.0        # wrong: discards sub-frame precision
```

### `Array.back()` for last element
```gdscript
var last = my_array.back()   # Godot 4 GDScript
var last = my_array[-1]      # also valid
```

### `queue_redraw()` is Godot 4's replacement for `update()`
Godot 3 used `update()` — Godot 4 uses `queue_redraw()`.

### Typed array declaration
```gdscript
var positions : Array[Vector2i] = []   # typed — faster, safer
var records   : Array            = []  # untyped — needed for Array of Dicts
```

---

## Rendering approach for 2D games

| Approach | When to use |
|---|---|
| `_draw()` primitives | Grid games, procedural visuals, no sprites needed |
| `Sprite2D` + textures | When you have actual image assets |
| `Control` + `ColorRect` | Solid-colour UI backgrounds |

Use `Color(r, g, b)` with floats 0–1. For overlays with transparency: `Color(r, g, b, alpha)`.

---

## Ranking / leaderboard pattern

```gdscript
# In SaveData.gd
var top5 : Array = []  # [{name, score, level, time}, ...] sorted best-first

func add_result(name: String, score: int, level: int, time: float) -> bool:
    if score == 0:
        return false
    var qualifies: bool = (
        top5.size() < 5
        or score > top5.back().score
        or (score == top5.back().score and time < top5.back().time)
    )
    if not qualifies:
        return false
    top5.append({"name": name, "score": score, "level": level, "time": time})
    top5.sort_custom(func(a, b):
        if a.score != b.score:
            return a.score > b.score
        return a.time < b.time
    )
    if top5.size() > 5:
        top5.resize(5)
    save_data()
    return true  # caller can show "TOP 5!" banner
```

---

## Level progression pattern

```gdscript
const LEVELS := [
    {"score": 0,  "tick": 0.150},
    {"score": 3,  "tick": 0.120},
    # ...
]

func _check_level_up() -> void:
    var new_level := 1
    for i in LEVELS.size():
        if score >= LEVELS[i].score:
            new_level = i + 1
    if new_level > current_level:
        current_level = new_level
        tick_rate = LEVELS[current_level - 1].tick
        # optional: flash overlay
        flash_timer = 0.45
        flash_color = Color(0.30, 0.55, 1.0, 0.22)
```

---

## Version control

```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/USER/REPO.git
git branch -M main
git push -u origin main
```

If GitHub repo was created with a README (non-empty remote):
```bash
git push -u origin main --force   # safe on a brand-new repo
```

Godot regenerates `.godot/` on first open — never commit it.
