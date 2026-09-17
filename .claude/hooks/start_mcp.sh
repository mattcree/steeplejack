#!/usr/bin/env bash
# Bring up the in-editor MCP server if it is not already listening.
#
# UE 5.8 runs an MCP server inside the editor process (see AGENTS.md, "Driving the editor"). It has
# to be up before Claude Code connects, or the unreal tools in .mcp.json are simply absent for the
# whole session. Starting it here means that is never something anyone has to remember.
#
# Deliberately quiet and non-blocking: it backgrounds the editor and returns immediately. A session
# must never be held up waiting on a shader compile, and a machine without Unreal installed must
# still get a working session.
set -u

cd "$(dirname "$0")/../.." || exit 0
PORT=8000

if ss -ltn 2>/dev/null | grep -q ":${PORT}"; then
  echo "unreal MCP already listening on 127.0.0.1:${PORT}"
  exit 0
fi

UE_ROOT="${UE_ROOT:-$(make -s ue-root 2>/dev/null | sed 's/^UE_ROOT = //')}"
if [ -z "${UE_ROOT}" ] || [ ! -d "${UE_ROOT}" ]; then
  echo "no Unreal install found — unreal MCP tools will be unavailable (see \`make ue-root\`)"
  exit 0
fi

if [ ! -f "Binaries/Linux/libUnrealEditor-SteeplejackGame.so" ]; then
  echo "game module not built — run \`make mcp\` once (it builds first). Skipping autostart."
  exit 0
fi

mkdir -p Saved/Logs
nohup "${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor" \
  "${PWD}/Steeplejack.uproject" /Game/Maps/ShotTest \
  -RenderOffscreen -nosplash -NoSound > Saved/Logs/mcp-editor.log 2>&1 &

echo "starting unreal MCP editor in the background; tools land on 127.0.0.1:${PORT} shortly"
exit 0
