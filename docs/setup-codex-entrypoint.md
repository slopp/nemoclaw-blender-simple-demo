# Codex Entry-Point Setup

This optional guide adds Codex CLI as a general entry point for the Blender and
Omniverse environment created by the primary
[DGX Station ARM64 setup guide](setup-dgx-station-arm64.md). Complete and
validate that guide first. Codex then delegates specialized execution to the
existing NemoClaw Hermes agent instead of replacing it.

This path is designed for NVIDIA DGX Station running Ubuntu 24.04 ARM64.

## Process Summary

1. Install and authenticate Codex CLI.
2. Link the Codex coordinator skill and upstream OV add-on skills.
3. Validate direct Hermes execution through OpenShell.
4. Start Codex and ask it to delegate a Blender or OVPhysX task to Hermes.

## Prerequisites

- The primary setup guide passes through its Blender, OVRTX, OVPhysX, vLLM,
  NemoClaw, OpenShell, Hermes, and Blender MCP validations.
- `$GUIDE_REPO`, `$OV_REPO`, and `$NEMOCLAW_SANDBOX_NAME` identify the same
  checkouts and sandbox used by the primary guide.
- An OpenAI account with Codex access, or an OpenAI Platform API key.
- Browser access for the default ChatGPT sign-in flow. Device-code or API-key
  authentication can be used on a headless system.

## 1. Restore Project Variables

### Command

```bash
export GUIDE_REPO="$HOME/work/nemoclaw-blender-simple-demo"
export DEMO_ROOT="$HOME/work/ov-blender-hermes-demo"
export OV_REPO="$DEMO_ROOT/ov-blender-example-internal"
export NEMOCLAW_SANDBOX_NAME="ov-blender-hermes"
export PATH="$HOME/.local/bin:$PATH"
```

### Validation

```bash
test -f "$GUIDE_REPO/README.md"
test -f "$OV_REPO/public/skills/manifest.json"
nemohermes "$NEMOCLAW_SANDBOX_NAME" status
```

The sandbox status must report `Hermes Agent: running`.

## 2. Install Codex CLI

### Command

Use the official Linux standalone installer. It installs `codex` under
`$HOME/.local/bin` by default and supports Linux ARM64.

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
```

For a non-interactive update after the initial installation:

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | \
  CODEX_NON_INTERACTIVE=1 sh
```

### Validation

```bash
command -v codex
codex --version
```

## 3. Authenticate Codex

> **Human step: sign in to Codex.** Run `codex login` and complete the browser
> flow with an account that has Codex access. On a headless SSH session, use
> `codex login --device-auth` instead.

API-key authentication is an alternative:

```bash
export OPENAI_API_KEY='sk-...'
printenv OPENAI_API_KEY | codex login --with-api-key
unset OPENAI_API_KEY
```

Do not commit credentials or place them in this repository.

### Validation

```bash
codex login status
```

## 4. Install the Codex and OV Skills

The installer creates symlinks in `$HOME/.agents/skills`. It links this
project's coordinator skill and every `SKILL.md` directory under the checked-out
upstream `public/skills` tree. The links keep Codex on the same OV skill source
as Hermes and automatically follow later `git pull` updates.

### Command

```bash
cd "$GUIDE_REPO"
git -C "$OV_REPO" checkout main
git -C "$OV_REPO" pull --ff-only origin main
./scripts/install_codex_skills.sh "$OV_REPO"
```

The installer refuses to overwrite an unrelated skill with the same name.

### Validation

```bash
test -L "$HOME/.agents/skills/coordinate-nemoclaw-blender"
test -f "$HOME/.agents/skills/coordinate-nemoclaw-blender/SKILL.md"
git -C "$OV_REPO" rev-parse HEAD

expected="$(find "$OV_REPO/public/skills" -mindepth 2 -maxdepth 2 \
  -name SKILL.md | wc -l)"
installed="$(find "$OV_REPO/public/skills" -mindepth 2 -maxdepth 2 \
  -name SKILL.md -printf '%h\n' | while read -r skill; do
    test -f "$HOME/.agents/skills/$(basename "$skill")/SKILL.md" && echo ok
  done | wc -l)"
test "$installed" -eq "$expected"
echo "linked $installed upstream OV skills"
```

Codex detects skill changes automatically. If an already-running Codex session
does not show them, exit and start a new session.

## 5. Validate the Delegation Path

First call Hermes directly through OpenShell. This isolates the existing
specialist path from Codex setup.

### Command

```bash
openshell sandbox exec \
  --name "$NEMOCLAW_SANDBOX_NAME" \
  --timeout 1200 --no-tty -- \
  hermes chat -Q --max-turns 15 -q \
  "Inspect the visible Blender scene and report its scene name, render engine, and OV runtime status. Do not modify the scene."
```

The validated wrapper form is equivalent:

```bash
nemohermes "$NEMOCLAW_SANDBOX_NAME" exec --timeout 1200 -- \
  hermes chat -Q --max-turns 15 -q \
  "Inspect the visible Blender scene and report its scene name, render engine, and OV runtime status. Do not modify the scene."
```

### Validation

Hermes must reach Blender MCP and report the visible scene and installed OV
runtime status. Fix this path using the primary guide's troubleshooting section
before involving Codex.

## 6. Use Codex as the Entry Point

Start Codex from the shared work directory so it can inspect the guide, OV
checkout, and host output paths.

### Command

```bash
cd "$HOME/work"
codex
```

Then send:

```text
Use $coordinate-nemoclaw-blender. Ask the specialized Hermes agent to inspect
the visible Blender scene and render it with OVRTX. Validate the resulting host
PNG and report separately what Codex verified and what Hermes executed.
```

For native physics:

```text
Use $coordinate-nemoclaw-blender and the installed OVPhysX skills. Ask Hermes
to run the configured native OVPhysX stair-drop simulation, replay its
authoritative poses in visible Blender, and create a GIF. Verify the native
receipt and host artifacts, then summarize the result.
```

Codex may ask for permission before its first `nemohermes` or `openshell`
command. Approve only the displayed command and scope needed for the task.

### Validation

For rendering, Codex must identify a non-empty host PNG produced through
Hermes. For physics, require:

- `native_status: pass-real`;
- `physics_source: native-ovphysx-readback`;
- a non-empty host GIF;
- a clear distinction between native simulation and Blender replay rendering.

Codex should report its coordination and validation separately from Hermes's
Blender and OV runtime execution.

## Troubleshooting

### Codex does not list the new skills

Confirm the links and start a new Codex process:

```bash
find "$HOME/.agents/skills" -maxdepth 2 -name SKILL.md -print
readlink -f "$HOME/.agents/skills/coordinate-nemoclaw-blender"
```

### Codex can run Hermes but Hermes cannot reach Blender

The Codex layer is working. Return to the primary guide and check the visible
Blender process, ports 9876 and 9877, Blender MCP policy, and Hermes MCP entry.

```bash
nemohermes "$NEMOCLAW_SANDBOX_NAME" status
ss -ltnp | grep -E ':(9876|9877)'
nemohermes "$NEMOCLAW_SANDBOX_NAME" exec --timeout 30 -- hermes mcp list
```

### An upstream OV skill changed

Update the OV checkout. Symlinks require no reinstall unless upstream adds or
renames a skill directory:

```bash
git -C "$OV_REPO" pull --ff-only origin main
"$GUIDE_REPO/scripts/install_codex_skills.sh" "$OV_REPO"
```
