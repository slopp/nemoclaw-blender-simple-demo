# Demo Prompts

Use these from the Hermes dashboard or `hermes` CLI after the guide is complete.
Replace paths with the values printed by your shell.

## Blender Control Smoke Test

```text
Use blender-mcp-setup. Connect to the configured Blender MCP server. Do not
clear the scene. Report the Blender version, current file path, render engine,
active camera, and object count. Then create one small non-destructive marker
object named nemoclaw_control_marker so I can confirm live desktop control.
```

## Load the Blender 2.81 Splash Scene

```text
Use blender-mcp-setup and ovrtx-current-scene-workflow. Load this scene in the
already-open Blender desktop session:

SCENE_PATH

Preserve the scene contents. Set or create a camera that frames the scene, set
the render output path to:

OUTPUT_DIR/splash-ovrtx.png

Run an OVRTX smoke render at low samples. Use
`bpy.context.scene.render.engine = "OVRTX_EXAMPLE"`,
`bpy.context.scene.render.image_settings.file_format = "PNG"`, and if you touch
the OVRTX color setting use
`bpy.context.scene.ovrtx_example.color_presentation_mode =
"ldr_rgba8_display_passthrough"`. Do not use a property named
`color_presentation`.

Before calling `bpy.ops.render.render`, clear OVRTX state for this visible
Blender process. In Blender Python, import
`bl_ext.user_default.ovrtx_blender_example.ovrtx_blender_example.scene_generation_sessions`
and call `close()`. Then use the OVRTX control plane on `127.0.0.1:50051` to
delete any listed simulation IDs that start with `ovrtx-blender-` and end with
the current Blender process PID. The guide script
`scripts/render_visible_blender_ovrtx_smoke.py` is the reference behavior.

Report whether the active render engine is OVRTX_EXAMPLE and whether the output
file exists. Do not label a Cycles or Eevee render as OVRTX. If Blender writes
a different extension than `.png`, report the actual path.
```

## Native OVPhysX Stair Drop and GIF

The normal human prompt is:

```text
Use ovphysx-host-runtime-boundary. Run the configured native OVPhysX stair-drop
demo: prepare and preview the starting scene, simulate it with authoritative
pose sampling, replay those poses in visible Blender, and create a GIF. Report
the native simulation status and host artifact paths. Do not substitute Blender
physics or generated motion.
```

For easier observation or troubleshooting, use three prompts:

```text
Use ovphysx-host-runtime-boundary. Prepare the configured OVPhysX demo and show
me the starting scene in visible Blender. Do not run the simulation yet.
```

```text
Use ovphysx-host-runtime-boundary. Run the configured scene with native OVPhysX,
record authoritative pose samples, and report the validation result. Do not
render the replay yet.
```

```text
Use ovphysx-host-runtime-boundary. Replay the recorded native OVPhysX poses in
visible Blender and create a GIF. Report the render class and host artifact
paths.
```

For another prepared USD task, state the host USD path, body prim paths, output
directory, and any bounded simulation settings. The helper uses those as
overrides without changing the installed demo defaults.
