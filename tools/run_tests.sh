#!/usr/bin/env bash
# 테스트 실행: 데이터 검증 후 GUT 전체 테스트. GODOT 환경 변수로 실행 파일을 바꿀 수 있다.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . -s res://tools/validate_data.gd
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
