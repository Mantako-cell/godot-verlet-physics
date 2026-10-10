@echo off
title Verlet Dynamics - 3D Showcase
cd /d "%~dp0"
echo Starting Verlet Dynamics 3D Showcase World in Godot 4.7...
"C:\Users\HomePC\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe" --rendering-method gl_compatibility --path . "res://demo/scenes/showcase_world.tscn"
