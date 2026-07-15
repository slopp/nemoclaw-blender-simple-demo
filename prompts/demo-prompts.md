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

Report whether the active render engine is OVRTX_EXAMPLE and whether the output
file exists. Do not label a Cycles or Eevee render as OVRTX. If Blender writes
a different extension than `.png`, report the actual path.
```

## Native OVPhysX Stair Drop and GIF

```text
Use ovphysx-simulation-workflow and ovphysx-drop-contact-acceptance. Run the
real OVPhysX stair-drop fixture from the ov-blender-example public tests. The
ov-blender-example checkout is available inside the sandbox at:

OV_REPO_SANDBOX

Use fixtures, tests, and helper scripts from that checkout. Save all evidence
under:

OUTPUT_DIR/stair-drop

Required outputs:
- ovphysx-report.json with pass, blocked, or fail status
- pose timeline/readback evidence from native OVPhysX
- replay frames rendered through Blender or OVRTX, clearly labeled
- stair-drop.gif assembled from those frames with ffmpeg

If native OVPhysX is unavailable, stop with a blocked report. Do not substitute
Blender rigid bodies, hand-authored keyframes, or ballistic math and call that
native OVPhysX. If OV_REPO_SANDBOX or the expected public test fixture is
missing, stop with a blocked report that names the missing path.
```
