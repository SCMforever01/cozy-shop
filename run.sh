#!/usr/bin/env bash
# 启动 Cozy Shop（需要图形界面）
cd "$(dirname "$0")"
exec godot "$@"
