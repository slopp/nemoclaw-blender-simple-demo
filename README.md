# NemoClaw Blender Simple Demo

This repo is a simplified setup guide for a NemoClaw Hermes agent controlling a
visible Blender desktop session with the public `ov-blender-example` add-on,
OVRTX rendering, OVPhysX validation, and the PR 8 public Blender/OV skills.

The target outcome is:

- Blender is open in the logged-in desktop session so you can watch changes live.
- OVRTX/OVPhysX runtime files are installed for the Blender add-on.
- A NemoClaw Hermes sandbox is running through OpenShell.
- Hermes has the public Blender/OV skills installed.
- Hermes can reach a host-side Blender MCP proxy through an explicit policy.
- You can ask Hermes to load the Blender 2.81 splash scene, render a PNG, and
  run the native OVPhysX stair-drop validation plus GIF capture.

## Known Workarounds

- Official Blender 5.1 Linux downloads are x64. Linux ARM64 uses a community
  Blender 5.1.0 build unless an official or NVIDIA-provided ARM64 build is
  available.
- Linux ARM64 OVRTX/OVPhysX add-on/runtime artifacts are not treated here as a
  released public artifact. Use a complete GitHub Actions artifact set and patch
  the extension ZIP if Blender reports `linux-arm64` is unsupported.
- Some ARM64 add-on artifacts predate the `Install Runtime From` UI field. Use
  `scripts/materialize_runtime_from_artifacts.py` to install the runtime from a
  local artifact directory.
- `nemohermes mcp add` is for authenticated HTTPS MCP servers. A local Blender
  MCP proxy is a private host service, so this guide uses a custom OpenShell
  policy preset plus a manual Hermes `mcp_servers` entry.

## Start Here

Run these commands on the target machine.

```bash
mkdir -p "$HOME/work"
cd "$HOME/work"

# Replace this URL after this standalone repo is pushed.
git clone <this-standalone-repo-url> nemoclaw-blender-simple-demo
cd nemoclaw-blender-simple-demo

export GUIDE_REPO="$PWD"
export DEMO_ROOT="$HOME/work/ov-blender-hermes-demo"
export OV_REPO="$DEMO_ROOT/ov-blender-example-internal"
export OV_ARTIFACT_DIR="$DEMO_ROOT/ov-artifacts"
export OV_SOURCE_REPO_URL="${OV_SOURCE_REPO_URL:-https://github.com/NVIDIA-Omniverse/ov-blender-example-internal.git}"
export OV_GITHUB_REPO="${OV_GITHUB_REPO:-NVIDIA-Omniverse/ov-blender-example-internal}"
export NEMOCLAW_SANDBOX_NAME="ov-blender-hermes"
mkdir -p "$DEMO_ROOT" "$OV_ARTIFACT_DIR" "$DEMO_ROOT/out" "$DEMO_ROOT/scenes"
```

Clone the OVRTX/OVPhysX Blender example repository.

```bash
gh auth status || gh auth login
git clone "$OV_SOURCE_REPO_URL" "$OV_REPO"
cd "$OV_REPO"
git fetch origin main
git checkout main
git fetch origin pull/8/head:pr8-public-skills
```

The add-on and runtime live under `public/`. PR 8 contributes the public agent
skills used later by Hermes. If the public source repo is split from the
internal repo, set `OV_SOURCE_REPO_URL` and `OV_GITHUB_REPO` before starting and
keep the same `public/` layout.

## A. Host Software Install

Install OS packages.

```bash
sudo apt-get update
sudo apt-get install -y \
  ca-certificates curl git git-lfs gh jq unzip zip xz-utils \
  python3 python3-pip python3-venv ffmpeg \
  docker.io nvidia-container-toolkit

sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
git lfs install
```

If Docker group membership changed, open a new login shell or run:

```bash
newgrp docker
```

Install Blender 5.1.

```bash
cd "$GUIDE_REPO"

# Linux x64: official Blender build.
./scripts/install_blender_5_1.sh

# Linux ARM64: community workaround used on the DGX-style host.
BLENDER_ALLOW_COMMUNITY_ARM64=1 ./scripts/install_blender_5_1.sh

blender --version
```

Run only the command for your architecture.

Set up remote desktop access. If NoMachine is already installed, just verify it.

```bash
sudo /usr/NX/bin/nxserver --status || true
```

For x64 Ubuntu, a pinned NoMachine package command is:

```bash
curl -fL https://download.nomachine.com/download/9.7/Linux/nomachine_9.7.3_1_amd64.deb \
  -o /tmp/nomachine_amd64.deb
sudo apt-get install -y /tmp/nomachine_amd64.deb
sudo /usr/NX/bin/nxserver --status
```

For ARM64, download the current Linux ARM64 DEB from the NoMachine download page
and install it:

```bash
sudo apt-get install -y "$HOME/Downloads"/nomachine_*_arm64.deb
sudo /usr/NX/bin/nxserver --status
```

Connect with the NoMachine client, choose the GDM/local physical desktop, log in
as the OS user, and start Blender from the desktop terminal:

```bash
blender &
```

Download the Blender 2.81 splash scene.

```bash
curl -fL \
  https://download.blender.org/demo-files/archives/art-gallery/blender-splash-screens/blender-2-81/thejunkshopsplashscreen-35a35553b3dd4f8c8fb5a6ccc5065ff1.blend \
  -o "$DEMO_ROOT/scenes/thejunkshopsplashscreen.blend"
```

Download OVRTX/OVPhysX artifacts.

For a released x64 build, inspect releases and download the complete artifact
set for the selected release:

```bash
gh release list --repo "$OV_GITHUB_REPO" --limit 20
gh release view linux-x64-dev --repo "$OV_GITHUB_REPO"

gh release download linux-x64-dev \
  --repo "$OV_GITHUB_REPO" \
  --pattern 'ov-blender-example-linux-x64.zip' \
  --pattern 'ovrtx-*-linux-x64.zip' \
  --pattern 'ovphysx-*-linux-x64.zip' \
  --pattern 'SHA256SUMS' \
  --dir "$OV_ARTIFACT_DIR"
```

For Linux ARM64, use a complete non-released GitHub Actions artifact set. This
requires a GitHub token/session that can read the workflow artifact.

```bash
export OV_ACTION_RUN_ID=<run-id-with-linux-aarch64-artifacts>
gh run download "$OV_ACTION_RUN_ID" \
  --repo "$OV_GITHUB_REPO" \
  --name development-artifact-set-linux-aarch64 \
  --dir "$OV_ARTIFACT_DIR"
```

If Blender rejects the ARM64 extension ZIP with a platform error, patch only the
extension manifest token:

```bash
python3 "$GUIDE_REPO/scripts/patch_arm64_extension_zip.py" \
  "$OV_ARTIFACT_DIR/ov-blender-example-linux-aarch64.zip" \
  "$OV_ARTIFACT_DIR/ov-blender-example-linux-arm64-local.zip"

export OV_ADDON_ZIP="$OV_ARTIFACT_DIR/ov-blender-example-linux-arm64-local.zip"
```

For x64:

```bash
export OV_ADDON_ZIP="$OV_ARTIFACT_DIR/ov-blender-example-linux-x64.zip"
```

Install and enable the Blender extension from the command line:

```bash
blender --factory-startup --background \
  --command extension install-file -r user_default --enable "$OV_ADDON_ZIP"
```

Install the native runtime bundle. First try the add-on UI in Blender:

1. Open `Edit > Preferences > Add-ons`.
2. Open `ovrtx Blender Example`.
3. Set `Install Runtime From` to `$OV_ARTIFACT_DIR`.
4. Select `Install Runtime`, then `Verify Runtime`.
5. Wait for `Runtime: ready` and `Preflight: pass`.

If the installed add-on does not show `Install Runtime From`, use the local
materializer workaround:

```bash
python3 "$GUIDE_REPO/scripts/materialize_runtime_from_artifacts.py" \
  --repo "$OV_REPO" \
  --addon-zip "$OV_ADDON_ZIP" \
  --artifact-dir "$OV_ARTIFACT_DIR" \
  --storage-root "$HOME/.config/blender/5.1/extensions/.user/user_default/ovrtx_blender_example"
```

Install Blender MCP on the host. This guide uses the public `blender-mcp`
pattern: a Blender add-on listening on local TCP and an HTTP/SSE proxy that the
sandbox can reach.

```bash
mkdir -p "$DEMO_ROOT/blender-mcp"
curl -fL https://raw.githubusercontent.com/ahujasid/blender-mcp/main/addon.py \
  -o "$DEMO_ROOT/blender-mcp/blender_mcp_addon.py"

python3 -m venv "$DEMO_ROOT/venvs/host-tools"
. "$DEMO_ROOT/venvs/host-tools/bin/activate"
pip install --upgrade pip uv
export PATH="$DEMO_ROOT/venvs/host-tools/bin:$PATH"
```

In the visible Blender desktop, install and enable
`$DEMO_ROOT/blender-mcp/blender_mcp_addon.py`, then start the add-on server from
its Blender side panel. Leave Blender open.

Review the public Blender MCP add-on behavior before using it on sensitive
systems. During this guide run, the proxy startup path emitted a telemetry POST
from the `blender-mcp` package.

Start the host HTTP/SSE proxy:

```bash
uvx mcp-proxy --host 0.0.0.0 --port 9877 uvx blender-mcp \
  > "$DEMO_ROOT/out/blender-mcp-proxy.log" 2>&1 &
echo $! > "$DEMO_ROOT/out/blender-mcp-proxy.pid"

curl -fsS --max-time 3 http://127.0.0.1:9877/sse >/dev/null || true
```

## B. NemoClaw, OpenShell, Hermes, and Local Ultra

Start a local vLLM server for Ultra. The official Hugging Face model id includes
`A55B`; the served model name below preserves the shorter model id already used
by the remote TME endpoint.

The 550B NVFP4 Ultra model is large. Use all available local GPUs and expect the
first model download/load to take time. If the host cannot fit or serve the
model, use the remote endpoint fallback below and return to local vLLM later.

```bash
python3 -m venv "$DEMO_ROOT/venvs/vllm"
. "$DEMO_ROOT/venvs/vllm/bin/activate"
pip install --upgrade pip
pip install vllm huggingface_hub

# Required if the model is gated for your account.
huggingface-cli login

export ULTRA_MODEL_WEIGHTS="nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B-NVFP4"
export ULTRA_SERVED_NAME="nvidia/NVIDIA-Nemotron-3-Ultra-550B-NVFP4"
export TP_SIZE="$(nvidia-smi -L | wc -l | tr -d ' ')"

vllm serve "$ULTRA_MODEL_WEIGHTS" \
  --served-model-name "$ULTRA_SERVED_NAME" \
  --host 0.0.0.0 \
  --port 8000 \
  --tensor-parallel-size "$TP_SIZE" \
  --enable-auto-tool-choice \
  --tool-call-parser hermes
```

Verify the OpenAI-compatible endpoint from another terminal:

```bash
curl -fsS http://127.0.0.1:8000/v1/models | jq .
```

If local Ultra is not ready yet, use the remote endpoint as the temporary
provider:

```bash
export ULTRA_BASE_URL="https://nemotron-ultra.apps.inference-tme.nvidia.com/v1"
export ULTRA_MODEL="nvidia/NVIDIA-Nemotron-3-Ultra-550B-NVFP4"
export ULTRA_API_KEY="none_needed"
curl -fsS --max-time 10 \
  -H "Authorization: Bearer $ULTRA_API_KEY" \
  "$ULTRA_BASE_URL/models" | jq .
```

Install NemoClaw for Hermes.

```bash
export NEMOCLAW_AGENT=hermes
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
export PATH="$HOME/.local/bin:$PATH"

nemohermes --version
openshell --version
```

Onboard a Hermes sandbox against the running local vLLM server:

```bash
export NEMOCLAW_PROVIDER=vllm
export NEMOCLAW_SANDBOX_NAME="${NEMOCLAW_SANDBOX_NAME:-ov-blender-hermes}"
export NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE=1

nemohermes onboard \
  --agent hermes \
  --name "$NEMOCLAW_SANDBOX_NAME" \
  --sandbox-gpu \
  --yes \
  --yes-i-accept-third-party-software
```

Or switch an existing Hermes sandbox to the remote Ultra endpoint:

```bash
export ULTRA_API_KEY="${ULTRA_API_KEY:-none_needed}"
nemohermes inference set \
  --sandbox "$NEMOCLAW_SANDBOX_NAME" \
  --provider compatible-endpoint \
  --model "$ULTRA_MODEL" \
  --endpoint-url "$ULTRA_BASE_URL" \
  --credential-env ULTRA_API_KEY \
  --inference-api openai-completions
```

Install the PR 8 public Blender/OV skills into Hermes:

```bash
cd "$GUIDE_REPO"
./scripts/install_public_skills.sh "$NEMOCLAW_SANDBOX_NAME" "$OV_REPO"
```

Allow the sandbox to reach the host Blender MCP proxy:

```bash
export HOST_IP="$(hostname -I | awk '{print $1}')"
sed "s/HOST_IP_PLACEHOLDER/$HOST_IP/g" \
  "$GUIDE_REPO/policies/blender-mcp-host.yaml" \
  > "$DEMO_ROOT/blender-mcp-host.yaml"

nemohermes "$NEMOCLAW_SANDBOX_NAME" policy-add \
  --from-file "$DEMO_ROOT/blender-mcp-host.yaml" \
  --yes
```

Add the local HTTP/SSE Blender MCP server to Hermes config. This is the local
MCP workaround described above; do not use `nemohermes mcp add` for this private
host endpoint.

```bash
nemohermes "$NEMOCLAW_SANDBOX_NAME" upload \
  "$GUIDE_REPO/scripts/configure_hermes_blender_mcp.py" \
  /tmp/

nemohermes "$NEMOCLAW_SANDBOX_NAME" exec --timeout 60 -- \
  python3 /tmp/configure_hermes_blender_mcp.py "$HOST_IP"

timeout 90s nemohermes "$NEMOCLAW_SANDBOX_NAME" gateway restart || {
  echo "Gateway restart did not return within 90 seconds; check status and logs."
  nemohermes "$NEMOCLAW_SANDBOX_NAME" status
}
```

Open the Hermes dashboard:

```bash
nemohermes "$NEMOCLAW_SANDBOX_NAME" dashboard-url --quiet
```

For remote use, forward the dashboard and API from your laptop:

```bash
ssh -L 18789:127.0.0.1:18789 -L 8642:127.0.0.1:8642 <user>@<host>
```

## C. Run the Demo

Keep the NoMachine desktop open with Blender visible. In Blender, open the splash
scene if it is not already open:

```bash
blender "$DEMO_ROOT/scenes/thejunkshopsplashscreen.blend" &
```

In Hermes, first run the Blender control smoke test from
`prompts/demo-prompts.md`.

Then render the splash scene. Replace placeholders before sending:

```bash
SCENE_PATH="$DEMO_ROOT/scenes/thejunkshopsplashscreen.blend"
OUTPUT_DIR="$DEMO_ROOT/out"
sed \
  -e "s|SCENE_PATH|$SCENE_PATH|g" \
  -e "s|OUTPUT_DIR|$OUTPUT_DIR|g" \
  "$GUIDE_REPO/prompts/demo-prompts.md"
```

For the OVPhysX validation, ask Hermes to run the native stair-drop prompt from
`prompts/demo-prompts.md`. If Hermes produces rendered frames, assemble the GIF:

```bash
ffmpeg -y -framerate 12 \
  -i "$DEMO_ROOT/out/stair-drop/frames/%04d.png" \
  -vf "scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
  "$DEMO_ROOT/out/stair-drop/stair-drop.gif"
```

Inspect outputs on the host:

```bash
ls -la "$DEMO_ROOT/out"
find "$DEMO_ROOT/out" -maxdepth 3 -type f | sort
```

## Success Criteria

- `nemohermes "$NEMOCLAW_SANDBOX_NAME" status` is healthy.
- Blender is visible through NoMachine.
- Hermes can inspect Blender through MCP and make a harmless visible change.
- The add-on reports `Runtime: ready` and `Preflight: pass`.
- The splash render output exists and is identified as OVRTX, not Cycles/Eevee.
- OVPhysX produces a real native pass/block/fail report. A GIF is only accepted
  when its pose source is the native OVPhysX readback or is clearly labeled as a
  diagnostic non-native fallback.
