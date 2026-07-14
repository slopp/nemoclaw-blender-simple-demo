# NemoClaw Blender Simple Demo

This repo is a simplified setup guide for a NemoClaw Hermes agent controlling a
visible Blender desktop session with the public `ov-blender-example` add-on,
OVRTX rendering, OVPhysX validation, and the public Blender/OV skills.

The target outcome is:

- Blender is open in the logged-in desktop session so you can watch changes live.
- OVRTX/OVPhysX runtime files are installed for the Blender add-on.
- A NemoClaw Hermes sandbox is running through OpenShell.
- Hermes has the public Blender/OV skills installed.
- Hermes can reach a host-side Blender MCP proxy through an explicit policy.
- You can ask Hermes to load the Blender 2.81 splash scene, render a PNG, and
  run the native OVPhysX stair-drop validation plus GIF capture.

## Execution Model

Most steps are intentionally scriptable so a human operator or an agent can run
them over SSH. Required human checkpoints are called out in bold.

- **Scriptable:** run in a host shell or SSH session.
- **Human checkpoint:** run from the logged-in NoMachine desktop or complete a
  required credential/login step when called out in bold.
- **Human desktop:** run from the logged-in NoMachine desktop when the visible
  Blender UI must exist.
- **Hermes prompt:** send to Hermes after the sandbox and Blender MCP are
  configured.

Keep one visible Blender process running for the demo. The only visible Blender
launch is the bold human desktop checkpoint in section A; it opens the splash
scene and starts the MCP socket server in that same process.

## Known Workarounds

- Official Blender 5.1 Linux downloads are x64. Linux ARM64 builds Blender
  `v5.1.2` from source using `scripts/build_blender_5_1_2_arm64.sh` and the
  DGX ARM64 patch in this repo. The community Blender 5.1.0 binary is
  fallback-only.
- OVRTX/OVPhysX Linux release artifacts are published as GitHub prerelease
  tags: `linux-x64-dev` and `linux-aarch64-dev`.

## Start Here

Run these scriptable commands on the target machine.

```bash
mkdir -p "$HOME/work"
cd "$HOME/work"

git clone https://github.com/slopp/nemoclaw-blender-simple-demo.git nemoclaw-blender-simple-demo
cd nemoclaw-blender-simple-demo

export GUIDE_REPO="$PWD"
export DEMO_ROOT="$HOME/work/ov-blender-hermes-demo"
export OV_REPO="$DEMO_ROOT/ov-blender-example-internal"
export OV_REPO_SANDBOX="/sandbox/ov-blender-example-internal"
export OV_ARTIFACT_DIR="$DEMO_ROOT/ov-artifacts"
export OV_SOURCE_REPO_URL="${OV_SOURCE_REPO_URL:-https://github.com/NVIDIA-Omniverse/ov-blender-example-internal.git}"
export OV_GITHUB_REPO="${OV_GITHUB_REPO:-NVIDIA-Omniverse/ov-blender-example-internal}"
export NEMOCLAW_SANDBOX_NAME="ov-blender-hermes"
mkdir -p "$DEMO_ROOT" "$OV_ARTIFACT_DIR" "$DEMO_ROOT/out" "$DEMO_ROOT/scenes"
```

Clone the OVRTX/OVPhysX Blender example repository.

**Human credential checkpoint: GitHub access.** If `gh auth status` fails,
complete `gh auth login` in the terminal, then rerun the clone commands.

```bash
gh auth status || gh auth login
git clone "$OV_SOURCE_REPO_URL" "$OV_REPO"
cd "$OV_REPO"
git fetch origin main
git checkout main
```

The add-on, runtime helpers, and public agent skills live under `public/` on
`main`. If the public source repo is split from the internal repo, set
`OV_SOURCE_REPO_URL` and `OV_GITHUB_REPO` before starting and keep the same
`public/` layout.

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

On Linux ARM64, install the additional native Blender build dependencies before
building Blender from source:

```bash
if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
  sudo apt-get install -y \
    build-essential cmake pkg-config ninja-build patchelf yasm autoconf automake \
    libtool gettext gcc-14 g++-14 libnuma-dev libffi-dev libglib2.0-dev \
    libcairo2-dev libasound2-dev libdbus-1-dev libdecor-0-dev libdrm-dev \
    libevdev-dev libice-dev libinput-dev libpciaccess-dev libpixman-1-dev \
    libpulse-dev libsm-dev libudev-dev libwayland-dev wayland-protocols \
    libxcb-randr0-dev libxcb-render0-dev libxcursor-dev libxi-dev \
    libxinerama-dev libxkbcommon-dev libxrandr-dev libxt-dev libxxf86vm-dev

  command -v gcc-14
  command -v g++-14
fi
```

If `gcc-14` and `g++-14` are unavailable from the configured Ubuntu package
repositories, use approved Ubuntu 24.04 ARM64 GCC 14 packages. Do not use x64
packages on ARM64.

If Docker group membership changed, open a new login shell or run:

```bash
newgrp docker
```

Install Blender 5.1. Run only the command for your architecture.

```bash
cd "$GUIDE_REPO"

# Linux x64: official Blender build.
./scripts/install_blender_5_1.sh

# Linux ARM64: native Blender 5.1.2 source build.
./scripts/build_blender_5_1_2_arm64.sh

blender --version
```

The ARM64 build can take hours and needs roughly 100 GiB of free disk for
source, dependencies, build trees, and install outputs. It uses:

- Blender tag `v5.1.2`, commit `ec6e62d40fa9e9d1bea33ad5d00148c99a4f0832`
- GCC/G++ 14
- native Blender dependency bundle under `lib/linux_arm64`
- embedded Python 3.13
- the ARM64 DGX patch in
  `patches/blender-5.1.2-arm64-dgx.patch`

If a native source build is temporarily impossible and you only need a quick UI
smoke test, the older community binary is still available as an explicit
fallback:

```bash
BLENDER_ALLOW_COMMUNITY_ARM64=1 ./scripts/install_blender_5_1.sh
```

If the ARM64 dependency build fails in the OSL dependency because the host CUDA
toolkit is newer than the pinned OSL OptiX bitcode support, disable OptiX only
for that external OSL build and rerun the Blender source-build script:

```bash
export BLENDER_ARM64_WORK_ROOT="${BLENDER_ARM64_WORK_ROOT:-$HOME/work/blender-5.1.2-arm64}"
export TOOLING_VENV="$BLENDER_ARM64_WORK_ROOT/tooling-venv"
export BLENDER_DEPS_BUILD="$BLENDER_ARM64_WORK_ROOT/blender-deps-build"

cmake -S "$BLENDER_DEPS_BUILD/build/osl/src/external_osl" \
  -B "$BLENDER_DEPS_BUILD/build/osl/src/external_osl-build" \
  -DOSL_USE_OPTIX=OFF
cmake --build "$BLENDER_DEPS_BUILD" --target external_osl

cd "$GUIDE_REPO"
./scripts/build_blender_5_1_2_arm64.sh
```

On DGX-style Linux ARM64 hosts, verify that Blender is native AArch64 before
installing OVRTX. The helper accepts Blender 5.1.x, warns when it is not the
native-source 5.1.2 reference build, and prints the GPU launch pin to use when
GPU 0 is the RTX PRO device:

```bash
if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
  "$GUIDE_REPO/scripts/verify_dgx_blender.sh" "$(command -v blender)"
fi
```

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

Do not start Blender from the desktop yet. The single human desktop checkpoint
below connects through NoMachine and starts the one visible Blender process used
for the demo.

Download the Blender 2.81 splash scene.

```bash
curl -fL \
  https://download.blender.org/demo-files/archives/art-gallery/blender-splash-screens/blender-2-81/thejunkshopsplashscreen-35a35553b3dd4f8c8fb5a6ccc5065ff1.blend \
  -o "$DEMO_ROOT/scenes/thejunkshopsplashscreen.blend"
```

Download OVRTX/OVPhysX release artifacts. These are GitHub release assets, not
workflow artifacts. If the repository still requires access for your account,
keep the `gh auth login` session from the clone step.

```bash
case "$(uname -m)" in
  x86_64|amd64)
    export OV_RELEASE_TAG=linux-x64-dev
    export OV_PLATFORM=linux-x64
    ;;
  aarch64|arm64)
    export OV_RELEASE_TAG=linux-aarch64-dev
    export OV_PLATFORM=linux-aarch64
    ;;
  *)
    echo "Unsupported platform: $(uname -m)" >&2
    exit 2
    ;;
esac

gh api "repos/$OV_GITHUB_REPO/releases/tags/$OV_RELEASE_TAG" \
  --jq '{tag_name, prerelease, published_at, assets: [.assets[].name]}'
gh release download "$OV_RELEASE_TAG" \
  --repo "$OV_GITHUB_REPO" \
  --pattern "ov-blender-example-${OV_PLATFORM}.zip" \
  --pattern "ovrtx-*-${OV_PLATFORM}.zip" \
  --pattern "ovphysx-*-${OV_PLATFORM}.zip" \
  --dir "$OV_ARTIFACT_DIR"
```

```bash
export OV_ADDON_ZIP="$OV_ARTIFACT_DIR/ov-blender-example-${OV_PLATFORM}.zip"
```

Install and enable the Blender extension headlessly from the command line. This
does not start the visible desktop Blender session.

```bash
blender --factory-startup --background \
  --command extension install-file -r user_default --enable "$OV_ADDON_ZIP"
```

Install the native runtime bundle from the release artifacts. Use this
scriptable path by default:

```bash
python3 "$GUIDE_REPO/scripts/materialize_runtime_from_artifacts.py" \
  --repo "$OV_REPO" \
  --addon-zip "$OV_ADDON_ZIP" \
  --artifact-dir "$OV_ARTIFACT_DIR" \
  --storage-root "$HOME/.config/blender/5.1/extensions/.user/user_default/ovrtx_blender_example"
```

OVPhysX is included in the OVRTX runtime component graph. Do not install a
separate unrelated OVPhysX build; validate the runtime-installed
`ovphysx_grpc_server` through the demo's OVPhysX checks.

Prepare Blender MCP on the host. This guide uses the public `blender-mcp`
pattern: a Blender-side TCP server plus a host HTTP proxy that the sandbox can
reach. Downloading the add-on and starting the proxy are scriptable.

```bash
mkdir -p "$DEMO_ROOT/blender-mcp"
curl -fL https://raw.githubusercontent.com/ahujasid/blender-mcp/main/addon.py \
  -o "$DEMO_ROOT/blender-mcp/blender_mcp_addon.py"

python3 -m venv "$DEMO_ROOT/venvs/host-tools"
. "$DEMO_ROOT/venvs/host-tools/bin/activate"
pip install --upgrade pip uv
export PATH="$DEMO_ROOT/venvs/host-tools/bin:$PATH"
```

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

**Human desktop checkpoint: start the one visible Blender session.** Connect
with the NoMachine client, choose the GDM/local physical desktop, log in as the
OS user, open a terminal inside that desktop, then run this command. It opens
the splash scene and starts Blender MCP on `127.0.0.1:9876`; leave this Blender
window open for the rest of the guide.

```bash
gpu_env=()
if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
  # DGX ARM64 validation used GPU 0 as the RTX PRO render device.
  gpu_env=(CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}" SRTX_ACTIVE_CUDA_GPUS="${SRTX_ACTIVE_CUDA_GPUS:-0}")
fi

env \
  BLENDER_MCP_ADDON="$DEMO_ROOT/blender-mcp/blender_mcp_addon.py" \
  BLENDER_MCP_HOST=127.0.0.1 \
  BLENDER_MCP_PORT=9876 \
  "${gpu_env[@]}" \
  blender "$DEMO_ROOT/scenes/thejunkshopsplashscreen.blend" \
  --python "$GUIDE_REPO/scripts/start_visible_blender_mcp.py" \
  > "$DEMO_ROOT/out/visible-blender-mcp.log" 2>&1 &
```

Optional UI check inside the same desktop session: open
`Edit > Preferences > Add-ons > ovrtx Blender Example` and confirm
`Runtime: ready` and `Preflight: pass`.

Scriptable verification from any host shell:

```bash
tail -n 50 "$DEMO_ROOT/out/visible-blender-mcp.log"
grep -q "BLENDER_MCP_READY" "$DEMO_ROOT/out/visible-blender-mcp.log"
```

## B. Start Local Ultra with vLLM

Start a local OpenAI-compatible vLLM server. This is a long-running prerequisite
for Hermes. This guide uses the NVIDIA Nemotron 3 Ultra DGX Station deployment
path: `vllm/vllm-openai:v0.22.0` serving
`nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B-NVFP4` as `nemotron-ultra`. The
launcher also enables the Nemotron v3 reasoning parser and Qwen3 Coder tool
parser required for agent use.

```bash
docker pull vllm/vllm-openai:v0.22.0
```

**Human credential checkpoint: Hugging Face access.** Set `HF_TOKEN` if the
model is gated for your account. Leave it unset only when the model is already
accessible.

```bash
export HF_TOKEN="hf_..."

# Pick the GB300. On the validated two-GPU station it is GPU 1; on a single-GPU
# DGX Station, use `all`.
nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader
export VLLM_GPU_DEVICE=1

"$GUIDE_REPO/scripts/start_nemotron_ultra_vllm_station.sh"
```

Initial startup downloads about 328 GiB of checkpoint data, then loads weights,
compiles, warms up kernels, and captures CUDA graphs. On the validated GB300
station this took about 20 minutes the first time. Watch startup with:

```bash
docker logs -f nemotron-ultra-vllm
```

Verify the OpenAI-compatible endpoint from another terminal:

```bash
curl -fsS http://127.0.0.1:8000/v1/models | jq .
```

The script starts a container named `nemotron-ultra-vllm`. Inspect or stop it with:

```bash
docker logs -f nemotron-ultra-vllm
docker rm -f nemotron-ultra-vllm
```

## C. NemoClaw, OpenShell, and Hermes

Install NemoClaw for Hermes.

```bash
export NEMOCLAW_AGENT=hermes
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
export PATH="$HOME/.local/bin:$PATH"

nemohermes --version
openshell --version
```

If `nemohermes` is not found in a non-interactive SSH command, run the command
from a login shell or export the same PATH first:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Create the Hermes sandbox, then point it at the running local vLLM server. If
you are validating beside an existing NemoClaw sandbox on the same host, set a
separate gateway port before onboarding and keep that environment variable on
every later `nemohermes` command:

```bash
export NEMOCLAW_SANDBOX_NAME="${NEMOCLAW_SANDBOX_NAME:-ov-blender-hermes}"
export NEMOCLAW_GATEWAY_PORT="${NEMOCLAW_GATEWAY_PORT:-18081}"
export NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE=1
export NEMOCLAW_VLLM_LOCAL_TOKEN="${NEMOCLAW_VLLM_LOCAL_TOKEN:-none_needed}"
export NEMOCLAW_PROVIDER=vllm
unset NEMOCLAW_VLLM_MODEL

nemohermes onboard \
  --non-interactive \
  --agent hermes \
  --name "$NEMOCLAW_SANDBOX_NAME" \
  --sandbox-gpu \
  --no-ollama-autostart \
  --yes \
  --yes-i-accept-third-party-software
nemohermes "$NEMOCLAW_SANDBOX_NAME" status
```

`NEMOCLAW_PROVIDER=vllm` selects the running local vLLM server in unattended
mode. Do not set `NEMOCLAW_VLLM_MODEL` for this externally started vLLM server;
that variable is reserved for NemoClaw's managed-vLLM install path.

Install the public Blender/OV skills from the checked-out `main` branch into
Hermes:

```bash
cd "$GUIDE_REPO"
./scripts/install_public_skills.sh "$NEMOCLAW_SANDBOX_NAME" "$OV_REPO"
```

Upload the checked-out repo into the sandbox. This is separate from skill
installation: Hermes needs the repo source, public tests, fixtures, and helper
files when a prompt asks it to run the real OVPhysX validation.

```bash
export OV_REPO_SANDBOX="${OV_REPO_SANDBOX:-/sandbox/ov-blender-example-internal}"
./scripts/upload_ov_repo_to_sandbox.sh \
  "$NEMOCLAW_SANDBOX_NAME" \
  "$OV_REPO" \
  "$OV_REPO_SANDBOX"
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

Register the local Blender MCP proxy with Hermes. Use the Streamable HTTP
endpoint at `/mcp`, not the legacy SSE endpoint at `/sse`; Hermes probes the
server with POST requests and `/sse` returns `405 Method Not Allowed`.

```bash
nemohermes "$NEMOCLAW_SANDBOX_NAME" exec --timeout 120 -- sh -lc \
  "printf 'n\ny\n' | hermes mcp add blender --url http://$HOST_IP:9877/mcp"
```

The first answer says the local server does not require authentication. The
second answer enables all discovered Blender tools. Do not restart the gateway
just for this MCP registration; start a new Hermes session/request after adding
the server.

Validate the Hermes-native MCP entry from inside the sandbox:

```bash
nemohermes "$NEMOCLAW_SANDBOX_NAME" exec --timeout 30 -- hermes mcp list
```

**Human checkpoint: open the Hermes dashboard.** This is the human UI for
sending prompts to Hermes:

```bash
nemohermes "$NEMOCLAW_SANDBOX_NAME" dashboard-url --quiet
```

For remote use, forward the dashboard and API from your laptop:

```bash
ssh -L 18789:127.0.0.1:18789 -L 8642:127.0.0.1:8642 <user>@<host>
```

## D. Run the Demo

Keep the NoMachine desktop open with the single Blender process started in
section A. Set the visible scene to the OVRTX render engine through MCP instead
of clicking Blender UI:

```bash
nemohermes "$NEMOCLAW_SANDBOX_NAME" agent \
  "Use the configured Blender MCP server. Run Python in Blender to set bpy.context.scene.render.engine = 'OVRTX_EXAMPLE' and report the current render engine."
```

Hermes prompt: first run the Blender control smoke test from
`prompts/demo-prompts.md`. This should make a harmless visible change in the
already-open Blender desktop.

Then render the splash scene. Replace placeholders before sending:

```bash
SCENE_PATH="$DEMO_ROOT/scenes/thejunkshopsplashscreen.blend"
OUTPUT_DIR="$DEMO_ROOT/out"
OV_REPO_SANDBOX="${OV_REPO_SANDBOX:-/sandbox/ov-blender-example-internal}"
sed \
  -e "s|SCENE_PATH|$SCENE_PATH|g" \
  -e "s|OUTPUT_DIR|$OUTPUT_DIR|g" \
  -e "s|OV_REPO_SANDBOX|$OV_REPO_SANDBOX|g" \
  "$GUIDE_REPO/prompts/demo-prompts.md"
```

Hermes prompt: for the OVPhysX validation, ask Hermes to run the native
stair-drop prompt from
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

If Hermes saves an output inside the sandbox, download it to the host with
NemoHermes or OpenShell:

```bash
nemohermes "$NEMOCLAW_SANDBOX_NAME" download \
  /sandbox/renders/rendered_beauty_shot.png \
  "$DEMO_ROOT/out/rendered_beauty_shot.png"

openshell --gateway "nemoclaw-${NEMOCLAW_GATEWAY_PORT:-18081}" sandbox download \
  "$NEMOCLAW_SANDBOX_NAME" \
  /sandbox/renders/rendered_beauty_shot.png \
  "$DEMO_ROOT/out/rendered_beauty_shot.png"
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
