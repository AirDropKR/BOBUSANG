# BOBUSANG (보부상)

지게에 짐을 쌓아 고개를 넘고, 떨어지는 짐을 붙잡아 장터에서 파는 조선 보부상 물리 로그라이크.
설계는 [DESIGN.md](DESIGN.md), 작업 규칙은 [CLAUDE.md](CLAUDE.md).

## 실행
- Godot 4.7.2 이상으로 이 폴더를 열고 F5: M2 한 구간 (광주장에서 사서 -> 안성장에서 팔기, `game/leg_scene.tscn`)
- 물리 손맛 확인: `debug/m1_sandbox.tscn` 을 열고 F6 (상품 10개 전부, 돈 없음)
- 조작: 마우스 왼쪽 끌기(잡기), Q/E 회전, A/D 기울이기, 스페이스 걸음 늦추기, F1 조정 패널 (두 씬 공통)

## 테스트
```bash
tools/run_tests.sh
```
- 데이터 검증만: `godot --headless --path . -s res://tools/validate_data.gd`
- 화면 없이 한 번 걸어 보기: `godot --headless --path . -s res://tools/smoke_walk.gd -- m1 road_m1_rocks` (M2: `-- m2`)
