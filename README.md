# VerletDynamics3D for Godot 4.7+

A high-performance, pure GDScript 3D Verlet physics engine and node toolkit optimized for **Godot 4.7+** (and compatible with 4.x). Designed for instant drop-in integration without any C++ compilation, external native dependencies, or .NET setup.

---

## ✨ Features

### 🪢 1. `VerletRope3D`
- **Verlet Particle Integration**: Stable, fast relaxation solver with configurable iterations.
- **Dynamic Anchoring**: Pin start, end, or intermediate particles to static points or moving `Node3D`/`RigidBody3D` nodes with custom local offsets.
- **Two-Way RigidBody3D Coupling**: Ropes transfer real physical tension forces directly to attached `RigidBody3D` bodies (e.g. wrecking balls, swinging crates, pendulums).
- **Continuous World Collisions**: Raycast-based obstacle detection against Godot 3D collision layers with surface friction and bounce.
- **Procedural 3D Mesh Generation**:
  - `TUBE_MESH`: Real-time cylindrical 3D mesh with smooth normals and texture coordinates using parallel transport frames to avoid curve twisting.
  - `CHAIN_LINKS`: Real-time `MultiMeshInstance3D` rendering alternating interlocking chain links.
  - `DEBUG_LINE`: Lightweight immediate line renderer.
- **Breakable Constraints & Spark FX**: Automatically snaps when tension exceeds `break_tension_threshold` (spawning spark embers), or cut dynamically via `cut_at(index)`.
- **Tension Stress Heatmap**: Toggleable real-time vertex color gradient (Green -> Yellow -> Blazing Red) showing stress distribution along the rope.
- **Dynamic Winch API**: `winch(delta_length)` reels in or feeds out rope in real-time for elevators, cranes, and grappling hooks.
- **Wind & Slack Control**: Dynamic wind turbulence and catenary curve sag.

### 🚩 2. `VerletCloth3D`
- **2D Lattice in 3D Space**: Grid particle system supporting flags, banners, curtains, sails, and trampolines.
- **Triple Constraint Architecture**:
  - Structural constraints (horizontal/vertical links)
  - Shear constraints (diagonal links preventing shear distortion)
  - Bending/Flexion constraints (skip-one links to control wrinkling)
- **Aerodynamic Wind Lift & Drag**: Simulates aerodynamic normal forces across triangular faces, producing lifelike billows and flutter waves.
- **High-Restitution Trampolines**: Can act as a springy elastic trampoline, launching colliding physics bodies into the air.
- **Procedural ArrayMesh**: Dynamic vertex positions and smooth-shaded normal recomputation for lighting and reflections.
- **Collision Draping**: Renders cloth draped over tables, spheres, and characters.
- **Tearable**: Supports cutting and ripping cloth in real-time (`tear_at(x, y)`).

### 🍮 3. `VerletSoftVolume3D`
- **Deformable 3D Lattice**: 3D cube / jelly volume with surface springs and internal 3D cross-diagonal struts for volume preservation.
- **Elastic Bouncing**: Squishes and deforms upon landing on surfaces, recovering shape elastically.

### 💨 4. `VerletWindArea3D`
- **Multi-Mode Wind Physics**:
  - `DIRECTIONAL`: Uniform directional gale with turbulence noise.
  - `RADIAL_OUTWARD`: Shockwave explosion breeze with distance falloff.
  - `VORTEX_SWIRL`: Tornado whirlwind rotating ropes and cloth around an eye with updraft lift!

### 🔊 5. `VerletAudioSynth`
- **Zero-Dependency Procedural Audio**: Generates real-time sound effects (snap cracks, metallic slices, impact thuds, grapple releases) in pure GDScript without needing external `.wav` files.

---

## 🚀 Quick Start / Installation

### Method 1: Drop into an Existing Project
1. Copy the `addons/verlet_dynamics_3d/` folder into your Godot 4 project's `addons/` directory.
2. In the Godot editor, open **Project -> Project Settings -> Plugins**.
3. Enable **Verlet Dynamics 3D**.
4. The custom nodes (`VerletRope3D`, `VerletCloth3D`, `VerletSoftVolume3D`, `VerletWindArea3D`) are now available directly in the **Create New Node** dialog with custom icons!

### Method 2: Explore the Showcase Playground
Open the provided project directory (`godot-verlet-physics`) in Godot 4 and press **F5** to run the interactive showcase scene (`res://demo/scenes/showcase_world.tscn`).

---

## 🎮 Showcase Controls

| Input | Action |
|---|---|
| **Right Mouse Click + Drag** | Look / Fly Camera |
| **W / A / S / D + Q / E** | Navigate Camera in 3D space |
| **Shift** | Boost Camera Speed |
| **Left Mouse Click + Drag** | **Grab and pull any rope or cloth particle in 3D** |
| **'G' or Grapple Button** | **Shoot Physics Grappling Hook** to any surface! |
| **Scroll Wheel Up / Down** | **Winch In / Out** (reels in rope, pulling you forward) |
| **'C' or Middle Mouse** | **Laser Slice rope or tear cloth** with spark burst FX |
| **'T' or Tension Button** | **Toggle Tension Stress Heatmap** (Green -> Yellow -> Red) |
| **'W' or Wind Button** | **Cycle Wind Mode** (Gale -> Tornado Vortex -> Off) |
| **Space or 'B'** | **Fire rolling physics balls** |
| **'R'** | Reset scene and physics simulations |

---

## 💻 GDScript API Examples

### Creating a Hanging Rope in Code:
```gdscript
var rope = VerletRope3D.new()
rope.length = 5.0
rope.segment_count = 20
rope.pin_start = true
rope.attach_start_to = ^"../CeilingAnchor"
rope.pin_end = true
rope.attach_end_to = ^"../HeavyCrateBody"
rope.apply_forces_to_rigidbodies = true
add_child(rope)
```

### Cutting a Rope Segment:
```gdscript
# Snips constraint at segment index 5
rope.cut_at(5)
```

### Applying an Impulse (e.g. Explosion):
```gdscript
# Blow nearby rope particles away from an explosion epicenter
rope.apply_radial_impulse(explosion_pos, 5.0, 30.0)
```

### Creating Fluttering Cloth:
```gdscript
var cloth = VerletCloth3D.new()
cloth.resolution = Vector2i(16, 16)
cloth.cloth_size = Vector2(3.0, 3.0)
cloth.pin_preset = VerletCloth3D.PinPreset.TOP_EDGE
cloth.wind_vector = Vector3(8.0, 1.0, 0.0)
add_child(cloth)
```

### Tearing Cloth at Coordinates:
```gdscript
cloth.tear_at(8, 8)
```

---

## ⚡ Performance & Optimization Tips

- **Solver Iterations**: Defaults to 8–12 iterations. For background decorative cables, 4–6 iterations is plenty. For rigid chains under extreme tension, use 16–20 iterations.
- **Collision Mask**: Set `collision_mask` to specific physics layers to prevent unnecessary raycasts against complex foliage or trigger areas.
- **Segment Count**: For standard game cables, 10–16 segments provides smooth curves with virtually zero CPU overhead.
