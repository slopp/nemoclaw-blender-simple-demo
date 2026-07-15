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

```text
Use ovphysx-simulation-workflow, ovphysx-drop-contact-acceptance, and
ovphysx-host-runtime-boundary. Run the real OVPhysX stair-drop fixture from the
ov-blender-example public tests.

The source-only checkout available inside the sandbox is:

OV_REPO_SANDBOX

The native runtime is not installed in the sandbox. It is installed beside the
already-open host Blender process. Do not search `/sandbox` for
`ovphysx_grpc_server` or `ovphysx_bridge_client`, and do not classify their
absence there as a blocked host preflight. Use Blender MCP for host inspection
and execution.

Host checkout:

OV_REPO_HOST

Host installed runtime root:

OV_RUNTIME_ROOT

First use Blender MCP to report `bundled_runtime.defaults()` and
`runtime_services.owner.diagnostics()` from the installed add-on. Then use
Blender MCP to launch the host checkout's
`public/scripts/run_ovphysx_drop_probe.py` with Blender's `sys.executable` and
these explicit arguments:

- `--server OV_RUNTIME_ROOT/bin/ovphysx_grpc_server`
- `--ovphysx-native-client-path OV_RUNTIME_ROOT/native`
- `--ovphysx-root OV_RUNTIME_ROOT/runtime/ovphysx`
- `--ovruntime-root OV_RUNTIME_ROOT/runtime/ovruntime`
- `--fixture OV_REPO_HOST/public/tests/fixtures/data/demo_stair_drop_1280x720/fixture/stair_drop_ovrtx_ovphysx.usda`
- `--address 127.0.0.1:50095`
- `--require-real`
- `--output-dir OUTPUT_DIR/stair-drop/native-probe`

Launch it as a host subprocess so Blender MCP remains responsive, then poll
`OUTPUT_DIR/stair-drop/native-probe/result.json` through Blender MCP. Preserve
the native result as evidence.

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
native OVPhysX. A missing native binary or extension inside the sandbox is not
evidence that the host runtime is unavailable. If either checkout or the
expected public test fixture is missing, stop with a blocked report that names
the missing path.
```
