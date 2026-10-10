@echo off
title Verlet Dynamics - iGPU Optimized Mode
cd /d "%~dp0"
echo ========================================================
echo Launching Verlet Dynamics in iGPU Optimized Mode
echo - Renderer: OpenGL 3.3 Compatibility (Fast on Intel / AMD iGPUs)
echo - Shadows & Glow: Disabled for fill-rate efficiency
echo - Solver Iterations: 6 (Low CPU overhead)
echo ========================================================
"C:\Users\HomePC\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe" --rendering-method gl_compatibility --path . "res://demo/scenes/showcase_world.tscn"
