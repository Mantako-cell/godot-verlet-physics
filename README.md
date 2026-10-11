# Verlet Dynamics for Godot 4.7+ (2D & 3D Suite)

Version: 1.4.0

A high-performance, pure GDScript 2D & 3D Verlet physics engine and node toolkit designed specifically for Godot 4.7+ (and compatible with Godot 4.x). Instant drop-in integration without C++ compilation, GDExtension binaries, external native dependencies, or .NET requirements.

---

## Overview

Verlet Dynamics provides first-class nodes with native Godot Editor integration, procedural rendering, continuous collision detection, and bidirectional physics coupling for both 2D and 3D projects:

- **2D Games:** Platformer rope swinging, suspension bridges, squishy slime monsters, wind-blown tapestries, chains, and interactive character ragdolls.
- **3D Games:** Grappling hooks, cranes, tearable banners, high-restitution trampolines, deformable volumes, and tornado vortex winds.

---

## 2D Feature Suite

### 1. VerletRope2D
- **Dynamic Anchoring:** Pin start, end, or intermediate points to static coordinates or moving `Node2D`/`RigidBody2D` nodes with custom local offsets.
- **Two-Way RigidBody2D Coupling:** Ropes transfer real physical tension directly to attached 2D physics bodies (e.g., wrecking balls, cranes, hanging lanterns, suspension bridges).
- **Continuous 2D Collisions:** Raycast-based obstacle detection using `PhysicsRayQueryParameters2D` with customizable friction and bounce.
- **Procedural 2D Rendering Modes:**
  - `SMOOTH_LINE`: Antialiased curved cord with configurable thickness and color.
  - `CAPSULE_CHAIN`: Interlocking rounded links for heavy industrial chains.
  - `SEGMENT_LINES`: Segmented cable rendering.
- **Interactive Winch API:** `winch(delta_length)` dynamically reels in or lets out rope for elevators, climbing hooks, and winches.
- **Tension Stress Heatmap:** Real-time stress color gradient (`Green -> Yellow -> Red`) indicating structural load.
- **Breakable Constraints:** Automatically snaps when tension exceeds `break_tension_threshold`, or cut dynamically via `cut_at(index)`.

### 2. VerletCloth2D
- **2D Banner & Curtain Grid:** Multi-point Verlet sheet for flags, tapestries, curtains, and banners.
- **Structural + Shear Constraints:** Realistic cloth wrinkles and diagonal shear stability without shape collapse.
- **Dynamic Wind Flutter:** Simulates natural 2D air currents with gust turbulence and harmonic ripples.
- **Dynamic Quad Mesh Rendering:** Procedurally generates textured or colored 2D quad geometry.
- **Real-Time Tearing:** Call `tear_at(x, y)` or slice across the banner to rip cloth in real time.

### 3. VerletSoftBody2D
- **Squishy Jelly / Slime Blobs:** Soft-body deformable polygon with perimeter ring particles and a central core.
- **Volume Preservation Struts:** Radial spokes and internal cross-struts keep the blob from deflating while allowing organic squishing and stretching.
- **Elastic Bouncing:** Reacts elastically when landing on 2D floors or colliding with physics objects.
- **Procedural Gloss Rendering:** Smooth filled polygon body with customizable color, border outlines, and stylized specular highlights.
- **Interactive Grabbing:** Click and drag any point on the slime to stretch it like elastic putty.

### 4. VerletRagdoll2D
- **Articulated Humanoid Skeleton:** 16 skeletal joint particles covering head, neck, torso, pelvis, shoulders, elbows, hands, hips, knees, and feet with realistic mass distribution.
- **Anti-Inversion Struts & Cross-Bracing:** Jakobsen-style distance constraints prevent unnatural joint inversions and limb hyper-extensions.
- **Continuous 2D Obstacle Collisions:** Raycast collision queries prevent limbs from penetrating floors, walls, and static platforms.
- **Procedural Capsule Limb Rendering:** Renders outlined limb capsules, clothes, skin tones, shoes, and facial visor features directly via `_draw()` without sprite sheet requirements.
- **Interactive Mouse Grabbing:** Click and drag any limb joint to toss, swing, or pin characters in real-time.

### 5. VerletWindArea2D
- **Area2D Wind Physics:**
  - `DIRECTIONAL`: Sustained directional airflow with configurable gust frequency.
  - `RADIAL_OUTWARD`: Shockwave blast originating from an explosion center.
- **Automatic Particle Discovery:** Directly affects all 2D ropes, banners, and soft bodies overlapping its collision shape.

---

## 3D Feature Suite

### 1. VerletRope3D
- **Parallel Transport Tube Mesh:** Real-time 3D cylinder mesh generation with smooth normals and texture coordinates without curve twisting.
- **MultiMesh Chain Links:** Renders alternating 3D interlocking chain links with zero draw-call overhead.
- **Continuous 3D Raycast Collisions:** Ropes wrap and slide naturally over 3D static geometry and obstacles.
- **Two-Way RigidBody3D Coupling:** Transmits physical pulling forces to 3D dynamic bodies.
- **Breakable & Spark FX:** Snaps under extreme tension and spawns particle spark embers.

### 2. VerletCloth3D
- **3D ArrayMesh Lattice:** Real-time normal recomputation for lighting and reflections on fluttering flags, sails, and trampolines.
- **Aerodynamic Lift & Drag:** Realistic billows generated from face normals and dynamic wind vectors.
- **High-Restitution Trampolines:** Launches incoming physics bodies into the air upon impact.
- **Tearable Mesh:** Supports cutting and ripping cloth along any grid coordinate.

### 3. VerletSoftVolume3D
- **3D Deformable Cube/Lattice:** 3D soft-body volume with cross-diagonal struts and surface springs.
- **Elastic Recovery:** Squishes against 3D ground geometry and bounces back to its rest shape.

### 4. VerletWindArea3D
- **Directional, Radial, and Vortex Tornado Swirl Modes:** Simulates atmospheric wind, shockwave blasts, and rotating tornadoes.

### 5. VerletAudioSynth
- **Zero-Dependency Procedural Audio:** Real-time audio synthesizer generating sound effects (rope snaps, knife slices, impact thuds, grapple releases) in pure GDScript without external audio files.

---

## Quick Start & Installation

### Method 1: Drop into an Existing Project
1. Copy the `addons/verlet_dynamics_3d/` folder into your Godot project's `addons/` directory.
2. In Godot, go to **Project -> Project Settings -> Plugins**.
3. Enable **Verlet Dynamics (2D & 3D)**.
4. All custom nodes are now available in the **Create New Node** dialog with custom icons:
   - **2D Nodes:** `VerletRope2D`, `VerletCloth2D`, `VerletSoftBody2D`, `VerletRagdoll2D`, `VerletWindArea2D`
   - **3D Nodes:** `VerletRope3D`, `VerletCloth3D`, `VerletSoftVolume3D`, `VerletWindArea3D`

### Method 2: Explore the Interactive Showcases
Open the project directory in Godot 4 and run either showcase:
- **2D Showcase:** `res://demo/scenes/showcase_world_2d.tscn` (Suspension bridge, wrecking ball, jelly slime, fluttering banner, crate stack, platform ragdoll station, particle grabber & cutter).
- **3D Showcase:** `res://demo/scenes/showcase_world.tscn` (Park with grappling hook gun, crane, trampoline, tornado vortex, and wrecking ball).
- Use the HUD buttons (`[Switch to 2D Showcase]` / `[Switch to 3D Showcase]`) or keys `2` / `3` to jump between them.

---

## Showcase Controls

### 2D Showcase Controls

| Input | Action |
|---|---|
| Left Click + Drag | Grab and pull any 2D particle (stretch ropes, pull cloth, squish slimes, swing ragdoll limbs) |
| 'Z' or Ragdoll Button | Drop tumbling 2D humanoid ragdoll at cursor |
| Right Click + Drag | Laser Slice / Cut tool (slices ropes and tears cloth under the cursor) |
| Space or 'B' | Spawn 2D Physics Ball (crashes into crate stacks) |
| 'T' | Toggle Tension Stress Heatmap (Green -> Yellow -> Red) |
| 'W' | Cycle 2D Wind Mode (Gale -> Hurricane -> Off) |
| 'R' | Reset 2D Scene |
| '3' | Switch to 3D Showcase |

### 3D Showcase Controls

| Input | Action |
|---|---|
| Right Mouse Click + Drag | Look / Fly Camera |
| W / A / S / D + Q / E | Navigate Camera in 3D space (Shift for speed boost, E=Up, Q=Down) |
| Left Mouse Click + Drag | Grab and pull any 3D particle in real space (ropes, cloth, soft volume) |
| 'G' or Grapple Button | Shoot Physics Grappling Hook to any surface |
| Scroll Wheel Up / Down | Winch In / Out (reels in rope, pulling you forward) |
| 'C' or Middle Mouse | Laser Slice rope or tear cloth with spark burst FX |
| 'P' or Profile Button | Toggle Performance Profile (iGPU 60 FPS Mode vs High Quality Mode) |
| 'T' | Toggle Tension Stress Heatmap |
| 'W' | Cycle Wind Mode (Gale -> Tornado Vortex -> Off) |
| Space or 'B' | Fire rolling physics balls |
| '2' | Switch to 2D Showcase |

---

## 2D GDScript API Examples

### Creating an Interactive 2D Rope Attached to a RigidBody2D:
```gdscript
var rope = VerletRope2D.new()
rope.length = 300.0            # 300 pixels long
rope.segment_count = 15
rope.thickness = 5.0
rope.render_mode = VerletRope2D.RenderMode.SMOOTH_LINE
rope.pin_start = true
rope.attach_start_to = ^"../AnchorStaticBody"

# Attach end to a moving physics object (e.g., wrecking ball or crate)
rope.pin_end = true
rope.attach_end_to = ^"../CrateRigidBody"
rope.apply_forces_to_rigidbodies = true

add_child(rope)
```

### Winching a 2D Rope (Elevator / Grapple):
```gdscript
# Reel in 20 pixels
rope.winch(-20.0)

# Feed out 20 pixels
rope.winch(20.0)
```

### Creating a Squishy 2D Slime / Jelly Blob:
```gdscript
var slime = VerletSoftBody2D.new()
slime.radius = 45.0
slime.point_count = 12
slime.stiffness = 0.95
slime.bounce = 0.7
slime.body_color = Color(0.2, 0.85, 0.45, 0.9)
add_child(slime)
```

### Creating a Fluttering 2D Banner:
```gdscript
var banner = VerletCloth2D.new()
banner.grid_size = Vector2i(10, 8)
banner.spacing = Vector2(16.0, 16.0)
banner.pin_top_edge = true
banner.wind_force = Vector2(200.0, -30.0)
add_child(banner)
```

### Spawning an Articulated 2D Ragdoll:
```gdscript
var ragdoll = VerletRagdoll2D.new()
ragdoll.position = Vector2(400, 200)
ragdoll.character_scale = 1.0
ragdoll.shirt_color = Color(0.2, 0.6, 0.9)
ragdoll.pants_color = Color(0.18, 0.22, 0.32)
ragdoll.apply_velocity(Vector2(120.0, -40.0)) # Initial toss velocity
add_child(ragdoll)
```


### Cutting Ropes or Tearing Cloth:
```gdscript
# Cut rope at segment 4
rope.cut_at(4)

# Tear cloth banner at grid coordinate (5, 4)
banner.tear_at(5, 4)
```

---

## Low-End Hardware & iGPU Optimization

The engine and showcase are optimized to run smoothly at 60 FPS on integrated graphics (e.g., Intel UHD Graphics, Intel Iris Xe, AMD Radeon Vega / 680M / 780M, and budget laptop APUs):

1. **OpenGL 3.3 Compatibility Renderer Enabled:** Eliminates high-overhead Vulkan Forward+ compute shader pipelines, reducing VRAM footprint to under ~60MB with instant startup.
2. **Zero-Allocation Mesh Caching:** Mesh indices and UV arrays are precalculated and cached, eliminating over 80,000 array allocations per second during dynamic cloth/rope updates.
3. **Preallocated Vertex Buffers:** Dynamic vertex and normal generation uses direct index buffer assignments (`PackedArray.resize()`), avoiding garbage collection pauses.
4. **Aerial Raycast Culling:** Raycast collisions are disabled on aerial banners and ribbons that hang in mid-air, saving over 300 unnecessary raycasts per frame.
5. **iGPU Performance Profile:**
   - Press **'P'** at any time in the 3D showcase to toggle between **iGPU High-FPS Mode** (Glow off, shadows off, solver iterations 4, bending constraints off) and **High Fidelity Mode** (Glow on, shadows on, solver iterations 10).
   - Launch directly via `launch_igpu_showcase.bat` for instant 60 FPS performance on any laptop.

---

## Performance & Optimization Guidelines

- **Solver Iterations:** Defaults to 4–6 iterations for iGPU mode, and 8–10 for high-tension chains. For decorative background cables, 4 iterations is plenty.
- **Collision Mask:** Set `collision_mask` to specific physics layers so ropes only cast rays against solid static geometry rather than trigger zones or particles.
- **Segment Count:** For standard 2D cables and ropes, 8–12 segments provides smooth curves with virtually zero CPU overhead.
- **Pure GDScript:** No native bindings required; runs smoothly across Windows, Linux, macOS, Android, iOS, and Web (HTML5/WASM).

---

## License
MIT License. Free for use in personal, educational, and commercial Godot projects.
