# Number Drop Clone - 개발 진행 상황

## 프로젝트 개요
- **게임명**: Number Drop Clone (Drop The Number: Merge Puzzle 클론)
- **플랫폼**: Flutter Web
- **배포 URL**: https://jflakeee.github.io/number_drop_clone/
- **GitHub**: https://github.com/jflakeee/number_drop_clone

---

## 완료된 기능

### 핵심 게임 로직
- [x] 5x8 게임 보드
- [x] 블록 드롭 기능
- [x] BFS 기반 인접 블록 병합 (2+2=4, 4+4=8, ...)
- [x] 중력 효과 (병합 후 블록 낙하)
- [x] 연쇄 병합 (Chain reaction)
- [x] 게임 오버 판정 (상단 행 블록)
- [x] 아래쪽 블록 병합 시 특별 처리

### 애니메이션
- [x] 드롭 애니메이션 제거 (즉시 착지)
- [x] 병합 애니메이션 (주변 블록 → 타겟으로 이동)
- [x] 중력 애니메이션 (AnimatedPositioned)
- [x] 애니메이션 순서: 병합 → 타겟 제거 → 중력 → 새 블록 배치
- [x] 아래쪽 블록 병합 애니메이션 (절반 이동 후 페이드아웃)
- [x] 콤보 팝업 애니메이션 (반투명, 작은 크기)

### UI/UX
- [x] 블록 색상 (2~2048 각각 고유 색상)
- [x] 512+ 블록 왕관/스파클 효과
- [x] 상단 UI (코인, 점수, 하이스코어, 액션 버튼)
- [x] 하단 툴바 (돼지 저금통, 광고 보상, 스왑, 해머)
- [x] 컬럼 하이라이트 (드롭 위치 미리보기)
- [x] 드롭 섀도우 프리뷰
- [x] 콤보 표시 (반투명, 작은 크기)

### 시스템
- [x] Provider 상태 관리
- [x] 콤보 시스템 및 코인 보상
- [x] 타겟 블록 달성 시스템 (512, 1024, 2048...)
- [x] 해머 아이템 (블록 제거)

### 배포
- [x] GitHub Actions CI/CD 파이프라인
- [x] GitHub Pages 자동 배포
- [x] Flutter 3.27.0 (Dart SDK 3.5.4+)

---

## 기술 스택

| 카테고리 | 기술 |
|---------|------|
| 프레임워크 | Flutter 3.27.0 |
| 언어 | Dart |
| 상태관리 | Provider + ChangeNotifier |
| 애니메이션 | TweenAnimationBuilder, AnimatedPositioned |
| 배포 | GitHub Actions + GitHub Pages |

---

## 주요 파일 구조

```
app/
├── lib/
│   ├── main.dart              # 앱 진입점
│   ├── config/
│   │   ├── colors.dart        # 블록 색상 정의
│   │   └── constants.dart     # 게임 상수
│   ├── models/
│   │   ├── block.dart         # 블록 모델
│   │   └── game_state.dart    # 게임 상태 관리
│   ├── screens/
│   │   └── game_screen.dart   # 메인 게임 화면
│   └── widgets/
│       ├── animated_block_widget.dart  # 블록 위젯
│       ├── animated_game_board.dart    # 게임 보드
│       ├── score_popup.dart            # 점수/콤보 팝업
│       ├── score_display.dart          # 상단 점수 UI
│       └── bottom_toolbar.dart         # 하단 툴바
└── pubspec.yaml
```

---

## 버그 수정 이력

### 병합 애니메이션 문제
- **문제**: AnimatedPositioned가 병합 시 애니메이션 안됨
- **해결**: TweenAnimationBuilder로 명시적 위치 애니메이션 구현

### 상단 UI 오버플로우
- **문제**: Row 위젯 88px 오버플로우
- **해결**: 아이콘 크기 축소 (16px→14px), Spacer 사용

### 아래 블록과 병합 시 위치 오류
- **문제**: 병합 후 블록 위치가 잘못됨
- **해결**: 중력 먼저 적용 후 착지 위치 계산

### GitHub Pages 배포 실패
- **문제**: Dart SDK 버전 불일치 (3.5.0 vs ^3.5.4)
- **해결**: Flutter 3.24.0 → 3.27.0 업그레이드

### 아래쪽 블록 병합 애니메이션 개선
- **문제**: 아래 블록과 병합 시 애니메이션이 부자연스러움
- **해결**:
  - 아래 블록은 위로 절반만 이동 후 페이드아웃
  - 위쪽 블록(병합된 값)은 계속 중력으로 떨어짐
  - MergeAnimationData에 isBelowMerge, mergedValue 필드 추가

### 콤보 표시 크기 조정
- **문제**: 콤보 팝업이 너무 크고 눈에 띔
- **해결**: 반투명(70%), 크기 축소 (아이콘 16px, 텍스트 14px)

---

## 최근 커밋 이력

| 커밋 | 설명 |
|------|------|
| 8d89be8 | 아래쪽 블록 병합 애니메이션 개선 |
| e958804 | 콤보 팝업 반투명/작게 수정 |
| 5bcda6a | 진행상황 문서 추가 |
| 4435da9 | Flutter 3.27.0으로 업그레이드 |
| 788c1c0 | 배포 트리거 |
| b999cf6 | GitHub Actions 워크플로우 추가 |
| c4f8050 | 병합 애니메이션 순서 수정 |
| 2ac3a56 | docs/, res/ gitignore 추가, 병합 버그 수정 |

---

## 향후 개발 예정

### 기능
- [ ] 사운드 효과 및 BGM
- [ ] 진동 피드백 (모바일)
- [ ] Undo 기능 구현
- [ ] 일시정지 메뉴
- [ ] 리더보드
- [ ] 공유 기능

### 수익화
- [ ] Google AdMob 광고
- [ ] 인앱 결제 (코인 구매)

### 저장
- [ ] 로컬 스토리지 (하이스코어, 코인)
- [ ] 게임 상태 저장/불러오기

---

## 최종 업데이트
- **날짜**: 2026-01-21
- **버전**: 1.0.1
