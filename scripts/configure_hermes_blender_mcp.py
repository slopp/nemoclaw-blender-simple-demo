#!/usr/bin/env python3
"""Add or update a Blender MCP Streamable HTTP server in Hermes config."""

from __future__ import annotations

from pathlib import Path
import sys

import yaml


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: configure_hermes_blender_mcp.py <host-ip>", file=sys.stderr)
        return 2
    host = sys.argv[1]
    config_path = Path("/sandbox/.hermes/config.yaml")
    cfg = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
    cfg.setdefault("mcp_servers", {})["blender"] = {
        "url": f"http://{host}:9877/mcp",
        "enabled": True,
    }
    config_path.write_text(yaml.safe_dump(cfg, sort_keys=False), encoding="utf-8")
    print(f"configured Blender MCP server at http://{host}:9877/mcp")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
