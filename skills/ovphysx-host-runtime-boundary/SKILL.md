---
name: ovphysx-host-runtime-boundary
description: Route OVPhysX work correctly when Hermes runs in an OpenShell sandbox while the native OVRTX/OVPhysX runtime is installed beside a visible host Blender process.
license: Apache-2.0
metadata:
  version: "0.1"
  domain: physical-ai
---
# OVPhysX Host Runtime Boundary

Use this skill together with `ovphysx-simulation-workflow` and
`ovphysx-drop-contact-acceptance` for this guide's split deployment.

## Topology

- Hermes and a source-only copy of `ov-blender-example` run inside the
  OpenShell sandbox.
- Visible Blender, the installed add-on, `ovphysx_grpc_server`, and the
  `ovphysx_bridge_client` native extension run on the host.
- Blender MCP is the approved control path from Hermes to host Blender.

The native OVPhysX binary and extension are not expected under `/sandbox`.
Their absence there does not prove that OVPhysX is unavailable. Do not run the
standalone native probe directly with sandbox Python and do not ask the user to
copy native runtime libraries into the sandbox.

## Preflight

Use Blender MCP to inspect the installed runtime from the already-open Blender
process. Import the installed extension's `bundled_runtime` and
`runtime_services` modules, then report:

- `bundled_runtime.defaults()`;
- `runtime_services.owner.diagnostics()`; and
- whether the resolved OVPhysX server and native-client paths exist on the
  host.

Treat the host preflight as blocked only when Blender reports that its installed
runtime is absent, unhealthy, or incompatible. A missing sandbox-local binary
or `.so` is not a blocker in this topology.

## Execution

When the prompt supplies host checkout and runtime paths, use Blender MCP to
launch the host checkout's documented OVPhysX probe with Blender's
`sys.executable`. Pass the installed runtime's server, native-client,
`ovphysx`, and `ovruntime` paths explicitly. Use a unique loopback service port
and a caller-selected host output directory. Poll the host result through
Blender MCP and preserve its native status and evidence.

Do not substitute Blender rigid bodies, keyframes, or inferred motion for a
failed native run. Render or encode a GIF only from authoritative OVPhysX pose
readback, and label the rendering path accurately.
