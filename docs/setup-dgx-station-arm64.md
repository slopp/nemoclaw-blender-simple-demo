# DGX Station ARM64 Setup Guide

This guide installs a local NemoClaw Hermes agent that controls a visible
Blender session, renders with OVRTX, and runs native OVPhysX simulations. It was
validated on an NVIDIA DGX Station running Ubuntu 24.04 ARM64 with one GB300 and
one RTX PRO 6000 Blackwell GPU.

## Process Summary

1. Clone this project and the NVIDIA OVRTX/OVPhysX Blender example.
2. Install Blender, the OV add-on, and its native runtime bundle.
3. Start Nemotron 3 Ultra locally with vLLM on the GB300.
4. Install NemoClaw, OpenShell, and the Hermes agent sandbox.
5. Install the specialized OV skills and permit Blender MCP access.
6. Start one visible Blender session from the NoMachine desktop.
7. Ask Hermes to render a scene or run the native OVPhysX stair-drop demo.

Commands run on the DGX Station unless a quoted **Human step** says otherwise.
Keep the environment variables from the first section in the same shell.

## Prerequisites

### Hardware and system

- NVIDIA DGX Station with Ubuntu 24.04 ARM64 (`aarch64`).
- One GB300 for Nemotron 3 Ultra and one RTX-capable GPU for OVRTX. The
  validated system uses an RTX PRO 6000 Blackwell as GPU 0 and GB300 as GPU 1.
- At least 600 GiB free for the model cache, build workspace, runtime artifacts,
  and outputs. A Blender source build can use another 100 GiB temporarily.
- An OS account with `sudo` access and permission to use Docker.
- A NoMachine client on the operator workstation and network access to the DGX
  Station desktop.

### Accounts and credentials

- A GitHub token accepted by `gh auth login`, with read access to
  `NVIDIA-Omniverse/ov-blender-example-internal` and its release assets. The
  repository currently returns `404` to unauthenticated requests.
- A Hugging Face read token with access to
  `nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B-NVFP4`.
- Internet access to GitHub, Hugging Face, NVIDIA, Ubuntu package repositories,
  Blender, and the NoMachine download service.

No hosted LLM API key is required. Hermes uses the local vLLM endpoint.

## 1. Install Host Packages

### Command

```bash
sudo apt-get update
sudo apt-get install -y \
  ca-certificates curl git git-lfs gh jq unzip zip xz-utils file \
  python3 python3-pip python3-venv ffmpeg \
  nvidia-container-toolkit

if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get install -y docker.io
fi

sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
git lfs install
```

Log out and back in if the `docker` group was newly added.

### Validation

```bash
uname -m | grep -Eq '^(aarch64|arm64)$'
nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv,noheader
id -nG | tr ' ' '\n' | grep -x docker
docker info >/dev/null && echo docker-ok
ffmpeg -version | head -1
```

## 2. Define Paths and Clone Repositories

### Command

```bash
mkdir -p "$HOME/work"
cd "$HOME/work"

git clone https://github.com/slopp/nemoclaw-blender-simple-demo.git
export GUIDE_REPO="$HOME/work/nemoclaw-blender-simple-demo"
export DEMO_ROOT="$HOME/work/ov-blender-hermes-demo"
export OV_REPO="$DEMO_ROOT/ov-blender-example-internal"
export OV_ARTIFACT_DIR="$DEMO_ROOT/ov-artifacts"
export OV_GITHUB_REPO="NVIDIA-Omniverse/ov-blender-example-internal"
export NEMOCLAW_SANDBOX_NAME="ov-blender-hermes"
export NEMOCLAW_GATEWAY_PORT="18081"

mkdir -p "$DEMO_ROOT" "$OV_ARTIFACT_DIR" "$DEMO_ROOT/out" "$DEMO_ROOT/scenes"
```

> **Human step: authenticate GitHub.** Run `gh auth login` and provide the
> GitHub token described in Prerequisites. Select GitHub.com and HTTPS.

```bash
gh auth status
git clone https://github.com/NVIDIA-Omniverse/ov-blender-example-internal.git "$OV_REPO"
git -C "$OV_REPO" checkout main
git -C "$OV_REPO" pull --ff-only origin main
```

### Validation

```bash
test -f "$GUIDE_REPO/README.md"
test -f "$OV_REPO/public/addon/ovrtx_blender_example/__init__.py"
test -f "$OV_REPO/public/skills/manifest.json"
git -C "$OV_REPO" rev-parse HEAD
```

## 3. Install Blender 5.1

The OV add-on requires Blender 5.1.x. Blender does not publish an official
Blender ARM64 binary, so the primary setup path builds Blender 5.1.2.

### Command

```bash
sudo apt-get install -y \
  build-essential cmake pkg-config ninja-build patchelf yasm autoconf automake \
  libtool gettext gcc-14 g++-14 libnuma-dev libffi-dev libglib2.0-dev \
  libcairo2-dev libasound2-dev libdbus-1-dev libdecor-0-dev libdrm-dev \
  libevdev-dev libice-dev libinput-dev libpciaccess-dev libpixman-1-dev \
  libpulse-dev libsm-dev libudev-dev libwayland-dev wayland-protocols \
  libxcb-randr0-dev libxcb-render0-dev libxcursor-dev libxi-dev \
  libxinerama-dev libxkbcommon-dev libxrandr-dev libxt-dev libxxf86vm-dev

cd "$GUIDE_REPO"
./scripts/build_blender_5_1_2_arm64.sh
```

> **Temporary patch:** the source build applies
> `patches/blender-5.1.2-arm64-dgx.patch`. Remove this project patch when
> upstream Blender builds cleanly for the DGX Station ARM64 target.

The latest end-to-end validation reused an existing native ARM64 Blender 5.1.0
binary and skipped compilation. See Troubleshooting for the temporary binary
fallback when a source build cannot be completed.

### Validation

```bash
blender --version | head -3
file "$(readlink -f "$(command -v blender)")" | grep -E 'ARM aarch64|ARM64'
"$GUIDE_REPO/scripts/verify_dgx_blender.sh" "$(command -v blender)"
```

## 4. Install NoMachine and Download the Demo Scene

### Command

> **Human step: download NoMachine.** Download the current NoMachine Linux
> ARM64 DEB from the [official NoMachine download page](https://www.nomachine.com/download)
> into `$HOME/Downloads`. The validated package is NoMachine 9.7.3.

Install it and download the Blender scene:

```bash
sudo apt-get install -y "$HOME/Downloads"/nomachine_*_arm64.deb
sudo /usr/NX/bin/nxserver --restart

curl -fL \
  https://download.blender.org/demo-files/archives/art-gallery/blender-splash-screens/blender-2-81/thejunkshopsplashscreen-35a35553b3dd4f8c8fb5a6ccc5065ff1.blend \
  -o "$DEMO_ROOT/scenes/thejunkshopsplashscreen.blend"
```

### Validation

```bash
sudo /usr/NX/bin/nxserver --status
/usr/NX/bin/nxserver --version
test -s "$DEMO_ROOT/scenes/thejunkshopsplashscreen.blend"
```

Do not start Blender yet. There is one visible Blender launch in section 10.

## 5. Download and Install the OV Add-on Runtime

### Command

```bash
export OV_RELEASE_TAG="linux-aarch64-dev"
export OV_PLATFORM="linux-aarch64"

gh release view "$OV_RELEASE_TAG" \
  --repo "$OV_GITHUB_REPO" \
  --json tagName,publishedAt,isPrerelease,assets \
  --jq '{tagName,publishedAt,isPrerelease,assets:[.assets[].name]}'

gh release download "$OV_RELEASE_TAG" \
  --repo "$OV_GITHUB_REPO" \
  --pattern 'runtime-bundle-manifest.json' \
  --pattern "ov-blender-example-${OV_PLATFORM}.zip" \
  --pattern "ovrtx-*-${OV_PLATFORM}.zip" \
  --pattern "ovphysx-*-${OV_PLATFORM}.zip" \
  --dir "$OV_ARTIFACT_DIR"

export OV_ADDON_ZIP="$OV_ARTIFACT_DIR/ov-blender-example-${OV_PLATFORM}.zip"
export OV_ADDON_ZIP_PATCHED="$OV_ARTIFACT_DIR/ov-blender-example-linux-arm64-blender.zip"

python3 "$GUIDE_REPO/scripts/patch_arm64_extension_zip.py" \
  "$OV_ADDON_ZIP" "$OV_ADDON_ZIP_PATCHED"
export OV_ADDON_ZIP="$OV_ADDON_ZIP_PATCHED"

blender --factory-startup --background \
  --command extension install-file -r user_default --enable "$OV_ADDON_ZIP"
```

> **Temporary patch:** `patch_arm64_extension_zip.py` adds Blender's
> `linux-arm64` platform token when an ARM64 release artifact only declares the
> runtime's `linux-aarch64` spelling. It is harmless when the token is already
> present and should be removed after all release add-ons publish the Blender
> platform token.

Materialize the release runtime beside the installed extension:

```bash
export OV_EXTENSION_ROOT="$HOME/.config/blender/5.1/extensions/.user/user_default/ovrtx_blender_example"
export OV_RUNTIME_ROOT="$OV_EXTENSION_ROOT/runtimes/$OV_PLATFORM/current"

python3 "$GUIDE_REPO/scripts/materialize_runtime_from_artifacts.py" \
  --repo "$OV_REPO" \
  --addon-zip "$OV_ADDON_ZIP" \
  --artifact-dir "$OV_ARTIFACT_DIR" \
  --storage-root "$OV_EXTENSION_ROOT"
```

> **Temporary patch:** the materializer supplies a local artifact directory to
> the add-on's runtime API. Replace it with the add-on's native local-artifact
> install workflow when that interface is released for this platform.

Current ARM64 client archives can contain x86-64 `grpcio` or protobuf native
extensions. Repair them only when the architecture check detects x86-64:

```bash
export OV_NATIVE_DIR="$OV_RUNTIME_ROOT/native"
file "$OV_NATIVE_DIR/grpc/_cython"/cygrpc*.so
file "$OV_NATIVE_DIR/google/_upb"/_message*.so

if file \
  "$OV_NATIVE_DIR/grpc/_cython"/cygrpc*.so \
  "$OV_NATIVE_DIR/google/_upb"/_message*.so | grep -q 'x86-64'; then
  export BLENDER_PY="$(
    blender --background --factory-startup \
      --python-expr 'import sys; print("BLENDER_PY=" + sys.executable)' 2>/dev/null |
      sed -n 's/^BLENDER_PY=//p' | tail -1
  )"
  "$BLENDER_PY" -m ensurepip --upgrade
  "$BLENDER_PY" -m pip install \
    --target "$OV_NATIVE_DIR" \
    --upgrade --force-reinstall --only-binary=:all: \
    grpcio==1.81.1 protobuf
fi
```

> **Temporary patch:** reinstalling the ARM64 Python wheels is mandatory only
> for release archives containing x86-64 native dependencies. Remove this block
> after the ARM64 client artifact is rebuilt with AArch64 wheels.

Install this project's additive host helper:

```bash
cd "$GUIDE_REPO"
./scripts/install_ovphysx_helpers.sh
```

### Validation

```bash
test -f "$HOME/.config/blender/5.1/extensions/user_default/ovrtx_blender_example/blender_manifest.toml"
grep -E '^version|^platforms' \
  "$HOME/.config/blender/5.1/extensions/user_default/ovrtx_blender_example/blender_manifest.toml"
test -x "$OV_RUNTIME_ROOT/bin/ovrtx-bridge-server"
test -x "$OV_RUNTIME_ROOT/bin/ovphysx_grpc_server"
file "$OV_NATIVE_DIR/grpc/_cython"/cygrpc*.so | grep -E 'ARM aarch64|ARM64'
file "$OV_NATIVE_DIR/google/_upb"/_message*.so | grep -E 'ARM aarch64|ARM64'
test -x "$HOME/.local/share/nemoclaw-blender/ovphysx_host_helper.py"
cat "$HOME/.config/nemoclaw-blender/ovphysx-helper.json" | jq .
```

## 6. Start Nemotron 3 Ultra with vLLM

Initial startup can download roughly 328 GiB and then load, compile, and warm
the model. Allow at least 20 minutes for a cold start. The launcher follows the
[NVIDIA Nemotron 3 Ultra DGX Station deployment](https://docs.nvidia.com/nemotron/nightly/deployment-guides.html)
pattern with CPU expert offload and an NVFP4 inference backend.

> **Human step: provide Hugging Face access.** Export your read token in the
> host shell. Do not commit it or add it to this repository.

### Command

```bash
export HF_TOKEN='hf_...'
nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader

# Validated topology: RTX PRO is GPU 0 and GB300 is GPU 1.
export VLLM_GPU_DEVICE=1
export VLLM_IMAGE='vllm/vllm-openai:v0.22.0'

docker pull "$VLLM_IMAGE"
"$GUIDE_REPO/scripts/start_nemotron_ultra_vllm_station.sh"
docker logs -f nemotron-ultra-vllm
```

Stop following logs with `Ctrl-C`; that does not stop the container.

### Validation

```bash
curl -fsS http://127.0.0.1:8000/v1/models | jq \
  '.data[] | {id, root, max_model_len}'
docker ps --filter name=nemotron-ultra-vllm
```

Expected model ID: `nemotron-ultra`.

## 7. Install NemoClaw, OpenShell, and Hermes

The vLLM endpoint must be healthy before running the stock NemoClaw installer.
The installer performs Hermes onboarding on DGX Station.

### Command

```bash
export NEMOCLAW_AGENT=hermes
export NEMOCLAW_SANDBOX_NAME="ov-blender-hermes"
export NEMOCLAW_GATEWAY_PORT="18081"
export NEMOCLAW_PROVIDER=vllm
export NEMOCLAW_VLLM_LOCAL_TOKEN=none_needed
export NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE=1
unset NEMOCLAW_VLLM_MODEL

curl -fsSL https://www.nvidia.com/nemoclaw.sh | \
  NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE=1 bash

export PATH="$HOME/.local/bin:$PATH"
```

Use a login shell or explicitly export `~/.local/bin` for every later
non-interactive SSH command. Do not add a systemd override during normal setup.

### Validation

```bash
bash -lc 'command -v nemohermes; nemohermes --version'
bash -lc 'command -v openshell; openshell --version'
bash -lc 'nemohermes ov-blender-hermes status'
curl -fsS http://127.0.0.1:8000/v1/models >/dev/null
```

The sandbox status must report `Hermes Agent: running`.

## 8. Install Specialized Skills and Network Policy

### Command

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "$GUIDE_REPO"
./scripts/install_public_skills.sh "$NEMOCLAW_SANDBOX_NAME" "$OV_REPO"

export HOST_IP="$(hostname -I | awk '{print $1}')"
sed "s/HOST_IP_PLACEHOLDER/$HOST_IP/g" \
  "$GUIDE_REPO/policies/blender-mcp-host.yaml" \
  > "$DEMO_ROOT/blender-mcp-host.yaml"

nemohermes "$NEMOCLAW_SANDBOX_NAME" policy-add \
  --from-file "$DEMO_ROOT/blender-mcp-host.yaml" --yes
```

Skill installation messages may suggest restarting the agent gateway. A new
Hermes chat session loads the skills; do not restart the OpenShell gateway.

### Validation

```bash
nemohermes "$NEMOCLAW_SANDBOX_NAME" status
nemohermes "$NEMOCLAW_SANDBOX_NAME" exec --timeout 30 -- \
  test -f /sandbox/.hermes/skills/ovphysx-host-runtime-boundary/SKILL.md
```

## 9. Prepare Blender MCP

### Command

```bash
mkdir -p "$DEMO_ROOT/blender-mcp" "$DEMO_ROOT/venvs"
curl -fL https://raw.githubusercontent.com/ahujasid/blender-mcp/main/addon.py \
  -o "$DEMO_ROOT/blender-mcp/blender_mcp_addon.py"

python3 -m venv "$DEMO_ROOT/venvs/host-tools"
. "$DEMO_ROOT/venvs/host-tools/bin/activate"
pip install --upgrade pip uv
export PATH="$DEMO_ROOT/venvs/host-tools/bin:$PATH"

nohup uvx mcp-proxy --host 0.0.0.0 --port 9877 uvx blender-mcp \
  > "$DEMO_ROOT/out/blender-mcp-proxy.log" 2>&1 </dev/null &
echo $! > "$DEMO_ROOT/out/blender-mcp-proxy.pid"
sleep 5
```

Register the Streamable HTTP endpoint with Hermes:

```bash
export PATH="$HOME/.local/bin:$PATH"
nemohermes "$NEMOCLAW_SANDBOX_NAME" exec --timeout 120 -- sh -lc \
  "printf 'n\ny\n' | hermes mcp add blender --url http://$HOST_IP:9877/mcp"
```

### Validation

```bash
kill -0 "$(cat "$DEMO_ROOT/out/blender-mcp-proxy.pid")"
curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 \
  http://127.0.0.1:9877/mcp
nemohermes "$NEMOCLAW_SANDBOX_NAME" exec --timeout 30 -- hermes mcp list
```

An unauthenticated `GET /mcp` normally returns HTTP `406`, which confirms the
proxy is listening. The Hermes MCP entry must show `enabled`.

## 10. Start the Visible Blender Session

> **Human step: launch Blender from the NoMachine desktop.** Connect with the
> NoMachine client, select the GDM or local physical desktop, log in as the OS
> user, and open a terminal inside that desktop. Run the command below there.
> Keep this single Blender window open while using Hermes.

### Command

```bash
export GUIDE_REPO="$HOME/work/nemoclaw-blender-simple-demo"
export DEMO_ROOT="$HOME/work/ov-blender-hermes-demo"
rm -rf /tmp/ov-blender-example

env \
  BLENDER_MCP_ADDON="$DEMO_ROOT/blender-mcp/blender_mcp_addon.py" \
  BLENDER_MCP_HOST=127.0.0.1 \
  BLENDER_MCP_PORT=9876 \
  CUDA_VISIBLE_DEVICES=0 \
  SRTX_ACTIVE_CUDA_GPUS=0 \
  blender "$DEMO_ROOT/scenes/thejunkshopsplashscreen.blend" \
  --python "$GUIDE_REPO/scripts/start_visible_blender_mcp.py" \
  > "$DEMO_ROOT/out/visible-blender-mcp.log" 2>&1 &
```

### Validation

Run these from any host shell:

```bash
grep -q BLENDER_MCP_READY "$DEMO_ROOT/out/visible-blender-mcp.log"
python3 "$GUIDE_REPO/scripts/verify_visible_blender_ovrtx.py" --wait 120
python3 "$GUIDE_REPO/scripts/render_visible_blender_ovrtx_smoke.py" \
  --output "$DEMO_ROOT/out/ovrtx-render-smoke.png" --timeout 900
file "$DEMO_ROOT/out/ovrtx-render-smoke.png"
```

Expected results are `Runtime is installed`, OVRTX and OVPhysX `SERVING`,
preflight `pass`, and a non-empty PNG.

## 11. Run the Demo

### Command

Start a new Hermes request with the one-shot physics prompt:

```bash
export PATH="$HOME/.local/bin:$PATH"
nemohermes "$NEMOCLAW_SANDBOX_NAME" exec --timeout 1200 -- \
  hermes chat -Q --max-turns 15 -q \
  "Use ovphysx-host-runtime-boundary. Run the configured native OVPhysX stair-drop demo: prepare and preview the starting scene, simulate it with authoritative pose sampling, replay those poses in visible Blender, and create a GIF. Report the native simulation status and host artifact paths. Do not substitute Blender physics or generated motion."
```

For render-only and multi-step physics prompts, see
[`prompts/demo-prompts.md`](../prompts/demo-prompts.md).

> **Human step: optional Hermes dashboard.** Run
> `nemohermes ov-blender-hermes dashboard-url --quiet`, open the reported URL,
> and paste a prompt from `prompts/demo-prompts.md`.

### Validation

```bash
jq . "$DEMO_ROOT/out/stair-drop/status.json"
jq . "$DEMO_ROOT/out/stair-drop/replay-status.json"
file "$DEMO_ROOT/out/stair-drop/starting-scene.png"
file "$DEMO_ROOT/out/stair-drop/ovphysx-replay.gif"
pgrep -af '^blender '
```

Required evidence:

- `native_status` is `pass-real`.
- `physics_source` is `native-ovphysx-readback`.
- `render_class` is `blender-replay`.
- The GIF exists and Blender remains running.

## Troubleshooting

### Blender ARM64 source build cannot complete

The exact end-to-end validation used the native community Blender 5.1.0 binary.
Use it only as a temporary fallback when the preferred 5.1.2 source build is
blocked:

```bash
BLENDER_ALLOW_COMMUNITY_ARM64=1 "$GUIDE_REPO/scripts/install_blender_5_1.sh"
```

If only the external OSL dependency fails because its pinned OptiX support is
older than the host CUDA toolkit, rebuild that dependency without OptiX and
resume the source build:

```bash
export BLENDER_ARM64_WORK_ROOT="${BLENDER_ARM64_WORK_ROOT:-$HOME/work/blender-5.1.2-arm64}"
export BLENDER_DEPS_BUILD="$BLENDER_ARM64_WORK_ROOT/blender-deps-build"

cmake -S "$BLENDER_DEPS_BUILD/build/osl/src/external_osl" \
  -B "$BLENDER_DEPS_BUILD/build/osl/src/external_osl-build" \
  -DOSL_USE_OPTIX=OFF
cmake --build "$BLENDER_DEPS_BUILD" --target external_osl
"$GUIDE_REPO/scripts/build_blender_5_1_2_arm64.sh"
```

### GitHub clone or release download returns 404

The OV repository and release assets require authenticated access. Verify the
active account and scopes:

```bash
gh auth status
gh api "repos/$OV_GITHUB_REPO/releases/tags/linux-aarch64-dev" \
  --jq '.assets[].name'
```

### Docker access fails

Check the login session's groups. A shell created before `usermod` will not see
the new membership:

```bash
id -nG
docker info
```

Log out of both SSH and the desktop, then log back in. For a short-lived
diagnostic only, `sudo setfacl -m u:"$USER":rw /var/run/docker.sock` can prove
that socket access is the blocker.

### OpenShell differs between login and non-login shells

Run the diagnostic below before modifying services:

```bash
echo "non-login: $(command -v openshell)"
openshell --version
bash -lc 'echo "login: $(command -v openshell)"; openshell --version'
systemctl --user is-system-running || true
docker info >/dev/null && echo docker-ok
```

The validated host had `/usr/bin/openshell` `0.0.82` and
`~/.local/bin/openshell` `0.0.72`. Both could communicate with the active
standalone `0.0.82` gateway. Use `bash -lc` or explicitly prepend
`~/.local/bin`; do not assume this mismatch is a protocol failure.

If onboarding stopped after installing the CLI, preserve the partial sandbox
and resume:

```bash
export PATH="$HOME/.local/bin:$PATH"
nemohermes onboard --resume --non-interactive \
  --yes --yes-i-accept-third-party-software
```

Only inspect or override `openshell-gateway.service` when logs prove that a
user service, rather than NemoClaw's standalone gateway, is active. The normal
guide does not require a systemd override.

### User systemd reports degraded

Identify the failed unit before associating it with OpenShell:

```bash
systemctl --user --failed --no-pager
systemctl --user status openshell-gateway.service --no-pager
```

On the validated host, `update-notifier-crash.service` caused the degraded
state and was unrelated to NemoClaw.

### vLLM does not become ready

```bash
docker ps -a --filter name=nemotron-ultra-vllm
docker logs --tail 300 nemotron-ultra-vllm
nvidia-smi
df -h "$HOME/.cache/huggingface"
```

Model loading and CUDA graph capture are long-running. Do not restart or remove
the container while weights are still loading.

### Blender MCP reports 502 or disabled

```bash
pgrep -af '^blender '
ss -ltnp | grep -E ':(9876|9877)'
tail -100 "$DEMO_ROOT/out/blender-mcp-proxy.log"
tail -100 "$DEMO_ROOT/out/visible-blender-mcp.log"
```

Restart the detached proxy if port 9877 is absent. If registration occurred
while the proxy was down, rerun it and answer the overwrite prompt:

```bash
nemohermes "$NEMOCLAW_SANDBOX_NAME" exec --timeout 120 -- sh -lc \
  "printf 'y\nn\ny\n' | hermes mcp add blender --url http://$HOST_IP:9877/mcp"
```

### OVRTX render reports an invalid USD export context

Current validated add-on source does not require a context patch. Only for the
specific error `bpy.ops.wm.usd_export.poll() failed, context is incorrect`,
apply the fallback to the installed add-on and restart Blender:

```bash
python3 "$GUIDE_REPO/scripts/patch_ovrtx_render_context.py" \
  --extension-package \
  "$HOME/.config/blender/5.1/extensions/user_default/ovrtx_blender_example/ovrtx_blender_example"
```

> **Temporary patch:** this fallback is for older add-on builds. Do not patch
> the upstream checkout, and remove this workaround when all supported releases
> carry the corrected export context.

### Repeated physics runs or renders fail

Use a new Hermes chat request so it loads the current specialized skill. The
project helper uses a dedicated fixture scene and restores its imported
transforms between runs. Do not manually delete all scene objects or re-import
the fixture between `preview` and `replay`.

For retained OVRTX state, restart the single visible Blender process and rerun
the scripted smoke render before starting another Hermes request.

## Validated Component Matrix

The following versions completed scene rendering and three consecutive native
OVPhysX workflows on the same visible Blender process on July 15, 2026.

| Component | Validated version or identity |
| --- | --- |
| Platform | NVIDIA DGX Station, Ubuntu 24.04.4 LTS, ARM64 |
| Kernel | `6.17.0-1014-nvidia-64k` |
| RTX GPU | NVIDIA RTX PRO 6000 Blackwell Max-Q, 97,887 MiB, GPU 0 |
| LLM GPU | NVIDIA GB300, 256,703 MiB, GPU 1 |
| NVIDIA driver | `595.58.03` |
| Blender | `5.1.0`, native AArch64, embedded Python 3.13 |
| OV add-on | `ovrtx Blender Example 0.1.0` |
| OV source | commit `b1675b588e6d619dfe15f06eeb6282fff8a429ea` |
| OV runtime platform | `linux-aarch64` |
| OV runtime manifest SHA-256 | `f8f90d308635a95278f59904a25d67fcf54fc7ef122e84f7e3fb8aa6d5ee0a2c` |
| vLLM | `vllm/vllm-openai:v0.22.0` |
| Model | `nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B-NVFP4`, served as `nemotron-ultra` |
| Model context | 262,144 tokens |
| NemoHermes | `0.0.81` |
| Hermes Agent | `0.18.0` (`2026.7.1`) |
| Active OpenShell gateway | `0.0.82` |
| NemoClaw-local OpenShell CLI | `0.0.72` |
| Docker | `29.2.1` |
| NoMachine | `9.7.3` |
| FFmpeg | `6.1.1` |

The Blender 5.1.2 source-build command and project patch are included as the
preferred fresh ARM64 installation path, but that compilation was intentionally
skipped during the latest full clean-run validation. The post-install Blender,
OVRTX, OVPhysX, vLLM, NemoClaw, MCP, rendering, and repeated-physics workflows
were all exercised end to end.
