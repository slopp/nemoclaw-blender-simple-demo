---
name: coordinate-nemoclaw-blender
description: Delegate Blender, OVRTX, OVPhysX, USD, rendering, and simulation tasks from Codex to the specialized NemoClaw Hermes agent running in an OpenShell sandbox. Use when Codex is the user entry point but visible Blender or an Omniverse Library must perform the work.
---

# Coordinate NemoClaw Blender

Use Codex for overall planning, repository work, diagnostics, and evidence
review. Delegate Blender and Omniverse execution to Hermes, which owns the
specialized skills, Blender MCP connection, and sandbox policy.

## Preconditions

Expect the primary project guide to have created:

- sandbox `${NEMOCLAW_SANDBOX_NAME:-ov-blender-hermes}`;
- a healthy local vLLM endpoint and running Hermes agent;
- the specialized OV skills inside the sandbox;
- a visible Blender process with Blender MCP and the OV runtimes serving.

Check status before delegating:

```bash
export PATH="$HOME/.local/bin:$PATH"
export NEMOCLAW_SANDBOX_NAME="${NEMOCLAW_SANDBOX_NAME:-ov-blender-hermes}"
nemohermes "$NEMOCLAW_SANDBOX_NAME" status
```

If status or Blender preflight fails, diagnose the failed layer and report the
blocker. Do not silently replace OVRTX or OVPhysX with Blender-native behavior.

## Delegate

Turn the user's goal into a short, outcome-oriented Hermes prompt. Preserve
requirements about OVRTX, native OVPhysX, visible Blender, evidence, and output
paths. Do not send repository-management or unrelated host tasks to Hermes.

Use the validated NemoClaw wrapper:

```bash
nemohermes "$NEMOCLAW_SANDBOX_NAME" exec --timeout 1200 -- \
  hermes chat -Q --max-turns 15 -q "$HERMES_PROMPT"
```

The equivalent lower-level OpenShell form is:

```bash
openshell sandbox exec \
  --name "$NEMOCLAW_SANDBOX_NAME" \
  --timeout 1200 --no-tty -- \
  hermes chat -Q --max-turns 15 -q "$HERMES_PROMPT"
```

Prefer a fresh non-interactive Hermes request for each discrete task. Increase
the timeout for long renders, but do not restart vLLM, Blender, Hermes, or the
OpenShell gateway merely because a request is still running.

## Validate

Read Hermes's final response and validate the host artifacts it names. For
OVPhysX work require native receipts such as `native_status: pass-real` and
`physics_source: native-ovphysx-readback`. Treat a rendered replay as visual
evidence, not as the physics authority.

Use the installed upstream OV skills for domain-specific planning and
acceptance criteria. In this deployment, their execution steps are carried out
by Hermes through Blender MCP unless the user explicitly requests direct host
diagnostics.

Report separately:

- what Codex planned, inspected, or changed;
- what Hermes asked Blender or the OV runtime to execute;
- which host artifacts and native receipts were verified;
- any blocker or unverified claim.
