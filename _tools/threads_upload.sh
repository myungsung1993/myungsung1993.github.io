#!/usr/bin/env bash
# 쓰레드(Threads) 글 업로드 도구 — Threads API (graph.threads.com)
#
# 준비: 토큰은 저장소 밖 ~/.policy-blog/threads.token (한 줄). 인스타 토큰과 다른 별도 토큰이다.
#       이 스크립트는 토큰을 출력하지 않는다.
#       글 내용은 assets/threads/<슬러그>/post.txt (500자 이내, 이모지는 바이트 단위로 셈)
#       주제 태그(선택, 1개만): assets/threads/<슬러그>/topic.txt (1~50자, 마침표·& 금지)
#       블로그 글 링크는 _posts/에서 슬러그로 찾아 미리보기 카드(link_attachment)로 붙인다.
#
# 사용법
#   bash _tools/threads_upload.sh check            # 계정·게시 가능 횟수 확인 (게시하지 않음)
#   bash _tools/threads_upload.sh preview <슬러그>  # 보낼 글·링크·글자 수만 보여 줌 (게시하지 않음)
#   bash _tools/threads_upload.sh post <슬러그>     # 글 + 블로그 링크 카드 게시 (팩트체크 반영 후)
#   bash _tools/threads_upload.sh comments [개수]   # 최근 게시물(기본 10개)에 달린 남의 댓글 (답글 안 단 것에 * 표시)
#   bash _tools/threads_upload.sh reply <댓글ID>    # ~/.policy-blog/threads_replies/<댓글ID>.txt 를 답글로 게시 (팩트체크 반영 후)
#   bash _tools/threads_upload.sh refresh          # 장기 토큰 갱신 (60일 만료 전, 발급 24시간 뒤부터 가능)
#
# 규칙: CLAUDE.md — 글·답글 모두 독립 팩트체크(fact-checker)를 거친 뒤 게시한다. (2026-10-24부터 사용자 확인 없이 게시)
#       댓글 원문은 남의 글이라 저장소에 넣지 않는다. 답글 초안·게시 기록은 ~/.policy-blog/threads_replies/ 에 둔다.

set -euo pipefail

TOKEN_FILE="${THREADS_TOKEN_FILE:-$HOME/.policy-blog/threads.token}"
API="https://graph.threads.com/v1.0"
SITE="https://jiwongil.kr"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cr() { curl --retry 4 --retry-delay 3 --retry-all-errors "$@"; }
jget() { grep -o "\"$1\":\"[^\"]*\"" | head -1 | sed "s/\"$1\":\"//; s/\"$//"; }
fail_if_error() { if printf '%s' "$1" | grep -q '"error"'; then echo "API 오류: $1" >&2; exit 1; fi; }

load_token() {
  [ -s "$TOKEN_FILE" ] || { echo "토큰 파일이 비어 있거나 없습니다: $TOKEN_FILE" >&2; exit 1; }
  TOKEN="$(tr -d ' \r\n' < "$TOKEN_FILE")"
}

# 슬러그로 블로그 글 주소 만들기: _posts/YYYY-MM-DD-슬러그.md → https://jiwongil.kr/YYYY/MM/DD/슬러그/
post_url() {
  local f; f="$(ls "$ROOT/_posts/" | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}-$1\.md$" | head -1)"
  [ -n "$f" ] || { echo "글을 찾지 못했습니다: _posts/*-$1.md" >&2; exit 1; }
  printf '%s/%s/%s/%s/%s/' "$SITE" "${f:0:4}" "${f:5:2}" "${f:8:2}" "$1"
}

# 글 파일 확인: 500자 제한. 이모지는 API가 바이트로 세므로 글에는 이모지를 거의 쓰지 않는다.
check_text() {
  local txt="$1" n
  [ -s "$txt" ] || { echo "글 파일이 없습니다: $txt" >&2; exit 1; }
  n="$(LC_ALL=C.UTF-8 wc -m < "$txt" | tr -d ' ')"
  echo "글자 수: $n / 500"
  [ "$n" -le 500 ] || { echo "500자를 넘습니다. 줄여 주세요." >&2; exit 1; }
}

case "${1:-}" in
  check)
    load_token
    r="$(cr -s -m 30 -G "$API/me" --data-urlencode "fields=id,username" --data-urlencode "access_token=$TOKEN")"
    fail_if_error "$r"; echo "계정: @$(printf '%s' "$r" | jget username)"
    id="$(printf '%s' "$r" | jget id)"
    cr -s -m 30 -G "$API/$id/threads_publishing_limit" --data-urlencode "fields=quota_usage,config" --data-urlencode "access_token=$TOKEN"; echo
    ;;
  preview|post)
    slug="${2:?슬러그를 넣어 주세요 (예: unemployment-benefit-2026)}"
    dir="$ROOT/assets/threads/$slug"
    txt="$dir/post.txt"
    check_text "$txt"
    link="$(post_url "$slug")"
    c="$(curl -s -o /dev/null -w '%{http_code}' -m 30 "$link")"
    [ "$c" = 200 ] || { echo "블로그 글이 아직 사이트에 없습니다($c): $link" >&2; exit 1; }
    topic=""; [ -s "$dir/topic.txt" ] && topic="$(head -1 "$dir/topic.txt" | tr -d '\r')"
    if [ "$1" = preview ]; then
      echo "링크 카드: $link"; echo "주제 태그: ${topic:-(없음)}"; echo "----"; cat "$txt"; echo "----"
      exit 0
    fi
    load_token
    r="$(cr -s -m 30 -G "$API/me" --data-urlencode "fields=id" --data-urlencode "access_token=$TOKEN")"
    fail_if_error "$r"; id="$(printf '%s' "$r" | jget id)"
    # 윈도우 curl은 한글 인자·한글 경로를 깨뜨리므로 영문 경로로 복사해서 파일로 넘긴다.
    tcopy="$HOME/.policy-blog/threads_upload.txt"; cp "$txt" "$tcopy"
    tw="$(cygpath -m "$tcopy" 2>/dev/null || echo "$tcopy")"
    args=( --data-urlencode "media_type=TEXT" --data-urlencode "text@$tw" --data-urlencode "link_attachment=$link" )
    if [ -n "$topic" ]; then
      pcopy="$HOME/.policy-blog/threads_topic.txt"; printf '%s' "$topic" > "$pcopy"
      args+=( --data-urlencode "topic_tag@$(cygpath -m "$pcopy" 2>/dev/null || echo "$pcopy")" )
    fi
    r="$(cr -s -m 60 -X POST "$API/$id/threads" "${args[@]}" --data-urlencode "access_token=$TOKEN")"
    fail_if_error "$r"; cid="$(printf '%s' "$r" | jget id)"
    [ -n "$cid" ] || { echo "컨테이너를 만들지 못했습니다: $r" >&2; exit 1; }
    echo "컨테이너 준비 중... (공식 권장 약 30초 대기)"; sleep 30
    # 게시 단계는 중복 게시를 막기 위해 재시도하지 않는다.
    r="$(curl -s -m 60 -X POST "$API/$id/threads_publish" --data-urlencode "creation_id=$cid" --data-urlencode "access_token=$TOKEN")"
    fail_if_error "$r"; mid="$(printf '%s' "$r" | jget id)"
    plink="$(curl -s -m 30 -G "$API/$mid" --data-urlencode "fields=permalink" --data-urlencode "access_token=$TOKEN" | jget permalink | sed 's#\\/#/#g')"
    echo "게시 완료: ${plink:-$mid}"
    ;;
  comments)
    load_token
    n="${2:-10}"; done_dir="$HOME/.policy-blog/threads_replies"; mkdir -p "$done_dir"
    r="$(cr -s -m 30 -G "$API/me" --data-urlencode "fields=id,username" --data-urlencode "access_token=$TOKEN")"
    fail_if_error "$r"; me="$(printf '%s' "$r" | jget username)"
    r="$(cr -s -m 30 -G "$API/me/threads" --data-urlencode "fields=id" --data-urlencode "limit=$n" --data-urlencode "access_token=$TOKEN")"
    fail_if_error "$r"
    for pid in $(printf '%s' "$r" | grep -o '"id":"[0-9]*"' | cut -d'"' -f4); do
      cr -s -m 30 -G "$API/$pid/replies" --data-urlencode "fields=id,text,username,timestamp" --data-urlencode "access_token=$TOKEN" |
        PID="$pid" ME="$me" DONE="$done_dir" node "$ROOT/_tools/threads_comments.js"
    done
    ;;
  reply)
    rid="${2:?댓글 ID를 넣어 주세요}"; dir="$HOME/.policy-blog/threads_replies"; txt="$dir/$rid.txt"
    [ -f "$dir/$rid.posted" ] && { echo "이미 답글을 단 댓글입니다: $(cat "$dir/$rid.posted")" >&2; exit 1; }
    check_text "$txt"
    load_token
    tw="$(cygpath -m "$txt" 2>/dev/null || echo "$txt")"
    r="$(cr -s -m 60 -X POST "$API/me/threads" --data-urlencode "media_type=TEXT" --data-urlencode "text@$tw" --data-urlencode "reply_to_id=$rid" --data-urlencode "access_token=$TOKEN")"
    fail_if_error "$r"; cid="$(printf '%s' "$r" | jget id)"
    [ -n "$cid" ] || { echo "컨테이너를 만들지 못했습니다: $r" >&2; exit 1; }
    echo "답글 준비 중... (약 30초 대기)"; sleep 30
    # 게시 단계는 중복 게시를 막기 위해 재시도하지 않는다.
    r="$(curl -s -m 60 -X POST "$API/me/threads_publish" --data-urlencode "creation_id=$cid" --data-urlencode "access_token=$TOKEN")"
    fail_if_error "$r"; mid="$(printf '%s' "$r" | jget id)"
    plink="$(curl -s -m 30 -G "$API/$mid" --data-urlencode "fields=permalink" --data-urlencode "access_token=$TOKEN" | jget permalink | sed 's#\\/#/#g')"
    echo "$(date '+%Y-%m-%d %H:%M') ${plink:-$mid}" > "$dir/$rid.posted"
    echo "답글 완료: ${plink:-$mid}"
    ;;
  refresh)
    load_token
    r="$(curl -s -m 30 -G "https://graph.threads.com/refresh_access_token" --data-urlencode "grant_type=th_refresh_token" --data-urlencode "access_token=$TOKEN")"
    fail_if_error "$r"
    new="$(printf '%s' "$r" | jget access_token)"
    [ -n "$new" ] || { echo "새 토큰을 받지 못했습니다" >&2; exit 1; }
    printf '%s\n' "$new" > "$TOKEN_FILE"
    echo "토큰 갱신 완료 (만료까지 초: $(printf '%s' "$r" | grep -o '"expires_in":[0-9]*' | cut -d: -f2))"
    ;;
  *)
    sed -n '2,17p' "$0"; exit 1 ;;
esac
