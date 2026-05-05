#!/usr/bin/env bash
set -euo pipefail

# ── 환경 설정 ──────────────────────────────────────────
THEOS_PATH="${THEOS:-$GITHUB_WORKSPACE/theos}"
export PATH="$HOME/.local/bin:$THEOS_PATH/bin:$PATH"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# 빌드에 필요한 경로 (GitHub runner 환경 기준)
IPA_PATH="$GITHUB_WORKSPACE/youtube.ipa"
OUTPUT_DIR="$GITHUB_WORKSPACE/output"
mkdir -p "$OUTPUT_DIR"

# ── 트윅 컴파일 로직 (자동화) ──────────────────────────
log "Starting Tweak Compilation"

# Makefile이 있는 모든 디렉토리를 찾아 빌드
# yml에서 이미 필요한 트윅만 클론했으므로 전체 루프를 돌아도 안전함
for dir in "$GITHUB_WORKSPACE"/*/; do
    dir=${dir%*/}
    if [[ -f "$dir/Makefile" ]]; then
        log "Building: ${dir##*/}"
        cd "$dir"
        
        # YTUHD의 경우 이미 yml에서 libvpx 처리가 끝났으므로 바로 빌드 가능
        make clean package DEBUG=0 FINALPACKAGE=1 SIDELOAD=1
        
        # 생성된 .deb 파일을 루트로 이동하여 인젝션 준비
        if [[ -d "packages" ]]; then
            mv packages/*.deb "$GITHUB_WORKSPACE/"
        fi
        cd "$GITHUB_WORKSPACE"
    fi
done

# ── 최종 인젝션 (Cyan) ───────────────────────────────
log "Injecting tweaks into IPA"

# 1. 메인 패치 파일 확인 (사용자 저장소 내부 경로)
MAIN_TWEAK="$GITHUB_WORKSPACE/tweaks/com.dvntm.ytlite_5.2.1_iphoneos-arm_patch_zarzel.deb"
[[ -f "$MAIN_TWEAK" ]] || die "Main tweak not found at $MAIN_TWEAK"

# 2. 빌드된 부속 트윅들 수집
EXTRA_TWEAKS=()
for deb in "$GITHUB_WORKSPACE"/*.deb; do
    [[ -f "$deb" ]] || continue
    # 메인 패치가 중복 포함되지 않도록 필터링
    [[ "$(basename "$deb")" == "$(basename "$MAIN_TWEAK")" ]] && continue
    EXTRA_TWEAKS+=("$deb")
done

# 3. Cyan 실행
cyan -i "$IPA_PATH" \
     -o "$OUTPUT_DIR/${OUTPUT_NAME:-YouTubePlus.ipa}" \
     -uwef "$MAIN_TWEAK" "${EXTRA_TWEAKS[@]}" \
     -n "${DISPLAY_NAME:-YouTube}" \
     -b "${BUNDLE_ID:-com.google.ios.youtube}"

log "Build Completed: $OUTPUT_DIR/${OUTPUT_NAME:-YouTubePlus.ipa}"
