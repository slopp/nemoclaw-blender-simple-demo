#!/usr/bin/env python3
"""Load Blender MCP into the current visible Blender process and start it."""

from __future__ import annotations

import os
import sys
import types
from pathlib import Path

import bpy


def _load_addon_namespace(addon_path: Path) -> dict:
    module_name = "blendermcp_addon_embedded"
    module = types.ModuleType(module_name)
    module.__file__ = str(addon_path)
    sys.modules[module_name] = module
    namespace = module.__dict__
    source = addon_path.read_text(encoding="utf-8")
    exec(compile(source, str(addon_path), "exec"), namespace)
    return namespace


def main() -> None:
    addon_value = os.environ.get("BLENDER_MCP_ADDON")
    if not addon_value:
        raise SystemExit("BLENDER_MCP_ADDON must point to blender_mcp_addon.py")

    addon_path = Path(addon_value).expanduser()
    host = os.environ.get("BLENDER_MCP_HOST", "localhost")
    port = int(os.environ.get("BLENDER_MCP_PORT", "9876"))

    if not addon_path.exists():
        raise SystemExit(f"Blender MCP add-on not found: {addon_path}")

    namespace = _load_addon_namespace(addon_path)
    register = namespace["register"]
    server_class = namespace["BlenderMCPServer"]

    try:
        register()
    except ValueError as exc:
        if "already registered" not in str(exc):
            raise

    scene = bpy.context.scene
    scene.blendermcp_port = port

    current = getattr(bpy.types, "blendermcp_server", None)
    if current and (getattr(current, "port", port) != port or getattr(current, "host", host) != host):
        current.stop()
        bpy.types.blendermcp_server = None
        current = None

    if not current:
        current = server_class(host=host, port=port)
        bpy.types.blendermcp_server = current

    if not current.running:
        current.start()

    scene.blendermcp_server_running = current.running
    if not current.running:
        raise SystemExit(f"Blender MCP server did not start on {host}:{port}")

    print(f"BLENDER_MCP_READY host={host} port={port}", flush=True)


if __name__ == "__main__":
    main()
