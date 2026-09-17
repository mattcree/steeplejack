#!/usr/bin/env python3
"""Call the editor's MCP server from the command line.

UE 5.8 runs an MCP server inside the editor process. This is a thin client so the same tools an
agent uses are usable by a human, and so `make mcp-status` can prove the thing is actually serving
rather than merely listening on a port.

    python3 tools/mcp_call.py list_toolsets
    python3 tools/mcp_call.py DescribeStack
    python3 tools/mcp_call.py SimulateGrip Stance=belted bWet=true
    python3 tools/mcp_call.py SetBandColour BandType=ivy R=0.07 G=0.14 B=0.05
"""
from __future__ import annotations

import json
import sys
import urllib.request

URL = "http://127.0.0.1:8000/mcp"
TOOLSET = "SteeplejackGame.SteeplejackToolset"
TOP_LEVEL = {"list_toolsets", "describe_toolset", "call_tool"}


def post(body: dict, session: str | None = None) -> tuple[dict, str | None]:
    req = urllib.request.Request(
        URL, data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json",
                 "Accept": "application/json, text/event-stream",
                 **({"Mcp-Session-Id": session} if session else {})})
    with urllib.request.urlopen(req, timeout=30) as r:
        sid = r.headers.get("Mcp-Session-Id") or session
        raw = r.read().decode().strip()
    return (json.loads(raw) if raw else {}), sid


def typed(value: str):
    """Arguments arrive as text; the tools want real types."""
    low = value.lower()
    if low in ("true", "false"):
        return low == "true"
    try:
        return int(value)
    except ValueError:
        pass
    try:
        return float(value)
    except ValueError:
        return value


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2

    tool = sys.argv[1]
    args = {k: typed(v) for k, v in (a.split("=", 1) for a in sys.argv[2:] if "=" in a)}

    _, sid = post({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                   "params": {"protocolVersion": "2025-06-18", "capabilities": {},
                              "clientInfo": {"name": "mcp_call", "version": "1"}}})
    post({"jsonrpc": "2.0", "method": "notifications/initialized"}, sid)

    if tool in TOP_LEVEL:
        params = {"name": tool, "arguments": args}
    else:
        params = {"name": "call_tool",
                  "arguments": {"toolset_name": TOOLSET, "tool_name": tool, "arguments": args}}

    reply, _ = post({"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": params}, sid)

    if "error" in reply:
        print(json.dumps(reply["error"], indent=2))
        return 1
    for block in reply.get("result", {}).get("content", []):
        text = block.get("text", "")
        try:                                   # tool returns are wrapped in {"returnValue": ...}
            print(json.loads(text).get("returnValue", text))
        except (ValueError, AttributeError):
            print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
