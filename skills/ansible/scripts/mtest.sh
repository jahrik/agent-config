#!/usr/bin/env bash
# Portable molecule wrapper — run from an ansible role's repo root.
#
# Source: https://github.com/jahrik/agent-config (skills/ansible/scripts/mtest.sh).
# Solves the two things agents kept hand-assembling per machine:
#   1. Podman-backed Docker: if no Docker socket answers but a podman user
#      socket exists, point molecule's Docker driver at it via DOCKER_HOST.
#   2. Stale role cache: molecule symlinks the role under ~/.ansible/roles;
#      a real directory left there (e.g. by galaxy) shadows the local role.
#
# Usage: scripts/mtest.sh [molecule args]   # defaults to `test`
#        e.g. mtest.sh converge | mtest.sh destroy
set -euo pipefail

if [[ -z ${DOCKER_HOST:-} && ! -S /var/run/docker.sock ]]; then
  podman_sock="/run/user/$(id -u)/podman/podman.sock"
  if [[ -S $podman_sock ]]; then
    export DOCKER_HOST="unix://$podman_sock"
  fi
fi

role_name=$(basename "$PWD")
role_cache="$HOME/.ansible/roles/$role_name"
if [[ -e $role_cache && ! -L $role_cache ]]; then
  echo "Clearing stale role cache: $role_cache" >&2
  rm -rf "$role_cache"
fi

# Prefer the repo-pinned toolchain over whatever is on PATH.
if [[ -f pyproject.toml ]] && command -v uv >/dev/null 2>&1; then
  exec uv run molecule "${@:-test}"
fi
exec molecule "${@:-test}"
