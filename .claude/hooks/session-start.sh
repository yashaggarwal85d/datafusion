#!/bin/bash
# SessionStart hook for Claude Code cloud sessions: installs the tooling the
# DataFusion contributor guide requires (protoc, submodule test data, pinned
# Rust toolchain) so builds, lints and tests work out of the box.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# The cloud session has a ~30GB disk allowance; a default dev build with debug
# info and incremental caches fills it. Keep accidental dev builds small.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo 'export CARGO_INCREMENTAL=0' >> "$CLAUDE_ENV_FILE"
  echo 'export CARGO_PROFILE_DEV_DEBUG=0' >> "$CLAUDE_ENV_FILE"
fi

# protoc 3.15+ is required to compile DataFusion
if ! command -v protoc >/dev/null 2>&1; then
  if ! apt-get install -y -qq protobuf-compiler >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq protobuf-compiler >/dev/null
  fi
fi

# Commits must be authored by the contributor, not the agent
git config user.name "Yash Aggarwal"
git config user.email "yashaggarwal85d@gmail.com"

# Test data used by many tests and sqllogictests
git submodule update --init --recursive

# Upstream remote, used to branch PR work from apache/datafusion main
if ! git remote get-url upstream >/dev/null 2>&1; then
  git remote add upstream https://github.com/apache/datafusion.git
fi
git fetch -q upstream main || true

# Install the toolchain pinned in rust-toolchain.toml and prefetch crates
rustup show active-toolchain >/dev/null
cargo fetch --locked -q || cargo fetch -q
