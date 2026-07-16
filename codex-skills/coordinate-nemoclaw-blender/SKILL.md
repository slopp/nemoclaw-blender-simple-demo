---
name: coordinate-nemoclaw-blender
description: Delegate Blender, OVRTX, OVPhysX, USD, rendering, and simulation tasks from Codex to the specialized NemoClaw Hermes agent running in an OpenShell sandbox. Use when Codex is the user entry point but visible Blender or an Omniverse Library must perform the work.
---

# Coordinate NemoClaw Blender

Use Codex as the coach: decompose the goal, establish file ownership, give
Hermes one measurable milestone at a time, inspect each receipt, and issue the
next milestone. Hermes owns the specialized skills and Blender MCP execution;
Codex owns host transfers, cross-milestone state, and final validation.

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

Before starting a request, check for another Hermes task targeting this
sandbox. Serialize tasks that share visible Blender or its OV services. Do not
launch a duplicate because a long request has not printed a final response.

```bash
pgrep -af 'nemohermes .* exec.*hermes chat|openshell sandbox exec.*hermes chat' || true
```

## Filesystem ownership

Keep these environments distinct:

- **Codex host:** sees `/home/nvidia`, the guide checkout, and host outputs.
- **Hermes sandbox:** terminal and file tools see `/sandbox`, not host paths.
- **Blender MCP:** executes inside visible host Blender and therefore sees the
  host filesystem. A host path is valid only inside an MCP/Blender operation.

Choose an execution topology before prompting Hermes:

- **MCP-only:** inspect or modify visible Blender and write host artifacts
  through Blender Python. No transfer is needed unless Hermes must subsequently
  read those files with sandbox tools.
- **Sandbox-only:** upload all inputs first; tell Hermes only sandbox paths;
  download all outputs afterward.
- **Hybrid:** have Hermes inspect/export through Blender MCP to a task-owned
  host directory, upload those files to a task-owned sandbox directory, let
  Hermes process them there, then download the result.

Use explicit transfer commands for every host/sandbox crossing:

```bash
export TASK_ID="task-$(date -u +%Y%m%dT%H%M%SZ)"
export HOST_TASK_ROOT="$HOME/$TASK_ID"
export SANDBOX_TASK_ROOT="/sandbox/tasks/$TASK_ID"

nemohermes sandbox upload "$NEMOCLAW_SANDBOX_NAME" \
  "$HOST_TASK_ROOT/input" "$SANDBOX_TASK_ROOT/input"
nemohermes sandbox download "$NEMOCLAW_SANDBOX_NAME" \
  "$SANDBOX_TASK_ROOT/output" "$HOST_TASK_ROOT/output"
```

Never tell Hermes terminal or file tools to use `/home/nvidia/...`. Never
assume a file written under `/sandbox` exists on the host. Verify both sides
after each transfer with file counts and hashes.

## Coach and delegate

For a simple render or inspection, send one outcome-oriented request. For a
task that crosses filesystems or has several acceptance gates, use milestones:

1. inspect and return a factual receipt without mutation;
2. export or prepare task-owned inputs through the correct execution surface;
3. transfer files when the next milestone uses sandbox tools;
4. author, simulate, render, or package;
5. validate and return a machine-readable receipt;
6. download sandbox outputs and independently verify them on the host.

Each Hermes prompt must state:

- the single milestone and its completion marker;
- the relevant installed skill names to read and follow;
- which paths are host-only and which are sandbox-visible;
- allowed execution surfaces for that milestone;
- required artifacts, evidence, and blockers;
- enough tool-call turns to iterate rather than merely plan.

Carry receipts and exact transferred paths into the next prompt because a new
`hermes chat -q` request is a fresh conversation. Do not send repository
management or unrelated host tasks to Hermes.

Use the validated NemoClaw wrapper:

```bash
nemohermes "$NEMOCLAW_SANDBOX_NAME" exec --timeout 1200 -- \
  hermes chat -Q --max-turns 30 -q "$HERMES_PROMPT"
```

The equivalent lower-level OpenShell form is:

```bash
openshell sandbox exec \
  --name "$NEMOCLAW_SANDBOX_NAME" \
  --timeout 1200 --no-tty -- \
  hermes chat -Q --max-turns 30 -q "$HERMES_PROMPT"
```

Prefer a fresh non-interactive Hermes request for each discrete task. Increase
the timeout and turn budget for long or tool-heavy milestones. If command
execution returns a running session identifier, poll that same session until it
exits. Agent logs are progress evidence, not a completion receipt. Do not start
an overlapping request, restart services, or kill a healthy run merely because
it is quiet or slow.

Avoid blanket tool bans. Restrict Hermes to Blender MCP for a host-inspection
milestone, but allow sandbox file and terminal tools after inputs have been
uploaded. If a prompt used the wrong filesystem or execution surface, stop that
specific pass, confirm its processes exited, correct the boundary, and then
retry once.

## Validate

Read Hermes's final response and validate the host artifacts it names. For
OVPhysX work require native receipts such as `native_status: pass-real` and
`physics_source: native-ovphysx-readback`. Treat a rendered replay as visual
evidence, not as the physics authority.

For transferred artifacts, compare sandbox receipt hashes with downloaded host
hashes. A path in Hermes's response is not evidence that the file crossed the
sandbox boundary.

Use the installed upstream OV skills for domain-specific planning and
acceptance criteria. In this deployment, their execution steps are carried out
by Hermes through Blender MCP unless the user explicitly requests direct host
diagnostics.

Report separately:

- what Codex planned, inspected, or changed;
- what Hermes asked Blender or the OV runtime to execute;
- which host artifacts and native receipts were verified;
- any blocker or unverified claim.
