#!/usr/bin/env bash
# 인스타그램 카드뉴스(캐러셀) 업로드 도구 — Instagram API (Instagram 로그인 방식, graph.instagram.com)
#
# 준비: 토큰은 저장소 밖 ~/.policy-blog/instagram.token (한 줄). 이 스크립트는 토큰을 출력하지 않는다.
#       이미지는 먼저 사이트에 올라가 있어야 한다: https://jiwongil.kr/assets/insta/<슬러그>/<번호>.png
#       캡션은 assets/insta/<슬러그>/caption.txt
#
# 사용법
#   bash _tools/insta_upload.sh check            # 계정·게시 가능 횟수 확인 (게시하지 않음)
#   bash _tools/insta_upload.sh post <슬러그>     # 캐러셀 게시 (반드시 사용자 확인 후 실행)
#   bash _tools/insta_upload.sh reel <슬러그> [nofeed]  # 릴스 게시: assets/insta/<슬러그>/reel.mp4 (_tools/insta_reel.sh로 만듦, 사용자 확인 후 실행)
#                                    nofeed: 프로필 격자에는 안 보이고 릴스 탭에만 (같은 세트 슬라이드와 겹치지 않게)
#                                    표지는 영상 첫 장면(thumb_offset=0). 카드 이미지(4:5)를 표지로 주면 세로 화면에서 잘려 보인다.
#   bash _tools/insta_upload.sh refresh          # 장기 토큰 갱신 (60일 만료 전에 실행)
#
# 규칙: CLAUDE.md — 카드뉴스는 독립 팩트체크를 거치고, 사용자가 "올려"라고 한 뒤에만 post 를 실행한다.

set -euo pipefail

TOKEN_FILE="${INSTA_TOKEN_FILE:-$HOME/.policy-blog/instagram.token}"
API="https://graph.instagram.com"
SITE="https://jiwongil.kr"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[ -s "$TOKEN_FILE" ] || { echo "토큰 파일이 비어 있거나 없습니다: $TOKEN_FILE" >&2; exit 1; }
TOKEN="$(tr -d ' \r\n' < "$TOKEN_FILE")"

# 일시적인 네트워크 끊김(curl 56 등)에 대비해 재시도한다. 게시 단계는 중복 게시를 막기 위해 재시도하지 않는다.
cr() { curl --retry 4 --retry-delay 3 --retry-all-errors "$@"; }

# JSON에서 "키":"값" 하나 꺼내기 (jq 없이)
jget() { grep -o "\"$1\":\"[^\"]*\"" | head -1 | sed "s/\"$1\":\"//; s/\"$//"; }
fail_if_error() { if printf '%s' "$1" | grep -q '"error"'; then echo "API 오류: $1" >&2; exit 1; fi; }

ig_id() {
  local r; r="$(cr -s -m 30 -G "$API/me" --data-urlencode "fields=user_id,username" --data-urlencode "access_token=$TOKEN")"
  fail_if_error "$r"; printf '%s' "$r" | jget user_id
}

wait_ready() {  # 컨테이너 처리 완료까지 대기 (두 번째 인자: 확인 횟수, 3초 간격)
  local id="$1" r s
  for _ in $(seq 1 "${2:-30}"); do
    r="$(cr -s -m 30 -G "$API/$id" --data-urlencode "fields=status_code" --data-urlencode "access_token=$TOKEN")"
    s="$(printf '%s' "$r" | jget status_code)"
    [ "$s" = "FINISHED" ] && return 0
    [ "$s" = "ERROR" ] || [ "$s" = "EXPIRED" ] && { echo "컨테이너 처리 실패($id): $r" >&2; exit 1; }
    sleep 3
  done
  echo "컨테이너 처리 시간 초과: $id" >&2; exit 1
}

# 게시하고 media id 출력. 인스타가 오류(2207051 "행동 차단")를 돌려줘도 실제로는 게시되는 경우가 있어서
# (2026-10-24 기초연금, 10-25 출산지원금: 실패로 기록됐지만 올라감 → 릴스 누락·중복 게시), 오류면 다시 확인한다.
# 컨테이너 상태는 ERROR로 나와도 게시된 적이 있어(10-25), 최신 게시물의 캡션 첫 줄·시각(15분 안)으로 판단한다.
publish() {
  local ig="$1" cid="$2" capf="$3" r s m
  r="$(curl -s -m 60 -X POST "$API/$ig/media_publish" --data-urlencode "creation_id=$cid" --data-urlencode "access_token=$TOKEN")"
  if ! printf '%s' "$r" | grep -q '"error"'; then printf '%s' "$r" | jget id; return 0; fi
  sleep 15
  s="$(cr -s -m 30 -G "$API/$cid" --data-urlencode "fields=status_code" --data-urlencode "access_token=$TOKEN" | jget status_code)"
  m="$(cr -s -m 30 -G "$API/$ig/media" --data-urlencode "fields=id,caption,timestamp" --data-urlencode "limit=1" --data-urlencode "access_token=$TOKEN" |
       CAPF="$capf" node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{
         const p=JSON.parse(d).data[0],first=require("fs").readFileSync(process.env.CAPF,"utf8").split("\n")[0].trim();
         const recent=Date.now()-Date.parse(p.timestamp)<15*60*1000;
         if(recent&&(p.caption||"").split("\n")[0].trim()===first)console.log(p.id)}catch(e){}})')"
  if [ "$s" = "PUBLISHED" ] || [ -n "$m" ]; then
    echo "오류 응답을 받았지만 실제로 게시됨(컨테이너 상태: ${s:-알 수 없음}): $r" >&2
    if [ -n "$m" ]; then echo "$m"; else cr -s -m 30 -G "$API/$ig/media" --data-urlencode "fields=id" --data-urlencode "limit=1" --data-urlencode "access_token=$TOKEN" | jget id; fi
    return 0
  fi
  echo "API 오류: $r (컨테이너 상태: ${s:-알 수 없음})" >&2; exit 1
}

case "${1:-}" in
  check)
    r="$(curl -s -m 30 -G "$API/me" --data-urlencode "fields=user_id,username,account_type" --data-urlencode "access_token=$TOKEN")"
    fail_if_error "$r"; echo "계정: @$(printf '%s' "$r" | jget username) ($(printf '%s' "$r" | jget account_type))"
    id="$(printf '%s' "$r" | jget user_id)"
    curl -s -m 30 -G "$API/$id/content_publishing_limit" --data-urlencode "fields=config,quota_usage" --data-urlencode "access_token=$TOKEN"; echo
    ;;
  post)
    slug="${2:?슬러그를 넣어 주세요 (예: culture-nuri-card-2026)}"
    dir="$ROOT/assets/insta/$slug"
    cap="$dir/caption.txt"
    [ -s "$cap" ] || { echo "캡션 파일이 없습니다: $cap" >&2; exit 1; }
    imgs=( $(ls "$dir" | grep -E '^[0-9]+\.png$' | sort -n) )
    [ "${#imgs[@]}" -ge 2 ] && [ "${#imgs[@]}" -le 10 ] || { echo "이미지는 2~10장이어야 합니다 (지금 ${#imgs[@]}장)" >&2; exit 1; }
    for f in "${imgs[@]}"; do   # 사이트에 실제로 올라가 있는지 먼저 확인
      c="$(curl -s -o /dev/null -w '%{http_code}' -m 30 "$SITE/assets/insta/$slug/$f")"
      [ "$c" = 200 ] || { echo "사이트에 이미지가 없습니다($c): $SITE/assets/insta/$slug/$f" >&2; exit 1; }
    done
    id="$(ig_id)"
    children=""
    for f in "${imgs[@]}"; do
      r="$(cr -s -m 60 -X POST "$API/$id/media" --data-urlencode "image_url=$SITE/assets/insta/$slug/$f" \
            --data-urlencode "is_carousel_item=true" --data-urlencode "access_token=$TOKEN")"
      fail_if_error "$r"; cid="$(printf '%s' "$r" | jget id)"; wait_ready "$cid"
      children="${children:+$children,}$cid"; echo "이미지 준비 완료: $f"
    done
    # 캡션은 파일에서 바로 읽어 보낸다(윈도우 curl의 한글 인자 인코딩 문제 회피).
    # 윈도우 curl은 한글이 들어간 파일 경로도 못 읽으므로 영문 경로로 복사해서 넘긴다.
    capcopy="$HOME/.policy-blog/caption_upload.txt"; cp "$cap" "$capcopy"
    capw="$(cygpath -m "$capcopy" 2>/dev/null || echo "$capcopy")"
    r="$(cr -s -m 60 -X POST "$API/$id/media" --data-urlencode "media_type=CAROUSEL" \
          --data-urlencode "children=$children" --data-urlencode "caption@$capw" --data-urlencode "access_token=$TOKEN")"
    fail_if_error "$r"; carousel="$(printf '%s' "$r" | jget id)"; wait_ready "$carousel"
    mid="$(publish "$id" "$carousel" "$capw")"
    link="$(curl -s -m 30 -G "$API/$mid" --data-urlencode "fields=permalink" --data-urlencode "access_token=$TOKEN" | jget permalink | sed 's#\\/#/#g')"
    echo "게시 완료: $link"
    ;;
  reel)
    slug="${2:?슬러그를 넣어 주세요 (예: youth-housing-support-2026)}"
    dir="$ROOT/assets/insta/$slug"
    cap="$dir/caption.txt"
    [ -s "$cap" ] || { echo "캡션 파일이 없습니다: $cap" >&2; exit 1; }
    [ -s "$dir/reel.mp4" ] || { echo "영상이 없습니다: $dir/reel.mp4 (bash _tools/insta_reel.sh $slug)" >&2; exit 1; }
    feed=true; [ "${3:-}" = nofeed ] && feed=false
    for f in reel.mp4; do   # 영상이 사이트에 올라가 있는지 먼저 확인
      c="$(curl -s -o /dev/null -w '%{http_code}' -m 30 "$SITE/assets/insta/$slug/$f")"
      [ "$c" = 200 ] || { echo "사이트에 파일이 없습니다($c): $SITE/assets/insta/$slug/$f" >&2; exit 1; }
    done
    id="$(ig_id)"
    capcopy="$HOME/.policy-blog/caption_upload.txt"; cp "$cap" "$capcopy"
    capw="$(cygpath -m "$capcopy" 2>/dev/null || echo "$capcopy")"
    r="$(cr -s -m 60 -X POST "$API/$id/media" --data-urlencode "media_type=REELS" \
          --data-urlencode "video_url=$SITE/assets/insta/$slug/reel.mp4" --data-urlencode "thumb_offset=0" \
          --data-urlencode "share_to_feed=$feed" --data-urlencode "caption@$capw" --data-urlencode "access_token=$TOKEN")"
    fail_if_error "$r"; cid="$(printf '%s' "$r" | jget id)"; echo "영상 처리 중..."; wait_ready "$cid" 100
    mid="$(publish "$id" "$cid" "$capw")"
    link="$(curl -s -m 30 -G "$API/$mid" --data-urlencode "fields=permalink" --data-urlencode "access_token=$TOKEN" | jget permalink | sed 's#\\/#/#g')"
    echo "게시 완료: $link"
    ;;
  refresh)
    r="$(curl -s -m 30 -G "$API/refresh_access_token" --data-urlencode "grant_type=ig_refresh_token" --data-urlencode "access_token=$TOKEN")"
    fail_if_error "$r"
    new="$(printf '%s' "$r" | jget access_token)"
    [ -n "$new" ] || { echo "새 토큰을 받지 못했습니다" >&2; exit 1; }
    printf '%s\n' "$new" > "$TOKEN_FILE"
    echo "토큰 갱신 완료 (만료까지 초: $(printf '%s' "$r" | grep -o '"expires_in":[0-9]*' | cut -d: -f2))"
    ;;
  *)
    sed -n '2,14p' "$0"; exit 1 ;;
esac
