#!/usr/bin/env bash
# 인스타 예약 게시 — 윈도우 작업 스케줄러가 하루 2번(08:30, 19:30) 실행한다.
#
# 대기열: ~/.policy-blog/insta_queue.txt  (한 줄에 슬러그 하나, 위에서부터 차례로 게시)
# 기록  : ~/.policy-blog/insta_log.txt     (게시 결과·오류)
# 토큰  : 30일마다 자동 갱신 (~/.policy-blog/insta_token_refreshed 에 마지막 갱신일)
#
# 대기열에는 독립 팩트체크를 통과하고 사용자가 게시를 승인한 슬러그만 넣는다.
# 실행 1번에 최대 1개만 올린다. 실패하면 대기열에서 빼지 않고 다음 실행 때 다시 시도한다.

set -uo pipefail

DIR="$HOME/.policy-blog"
QUEUE="$DIR/insta_queue.txt"
LOG="$DIR/insta_log.txt"
STAMP="$DIR/insta_token_refreshed"
TOOL="$(cd "$(dirname "$0")" && pwd)/insta_upload.sh"
now() { date "+%Y-%m-%d %H:%M"; }

# 1) 토큰 갱신 (마지막 갱신 후 30일 이상 지났으면)
last="$(cat "$STAMP" 2>/dev/null || echo 0)"
if [ $(( $(date +%s) - last )) -ge $(( 30 * 86400 )) ]; then
  if out="$(bash "$TOOL" refresh 2>&1)"; then
    date +%s > "$STAMP"; echo "$(now) 토큰 갱신: $out" >> "$LOG"
  else
    echo "$(now) 토큰 갱신 실패: $out" >> "$LOG"
  fi
fi

# 2) 대기열 맨 앞 1개 게시
[ -s "$QUEUE" ] || { echo "$(now) 대기열 비어 있음" >> "$LOG"; exit 0; }
slug="$(grep -m1 -v '^\s*$' "$QUEUE" | tr -d '\r ')"
[ -n "$slug" ] || exit 0

if out="$(bash "$TOOL" post "$slug" 2>&1)"; then
  link="$(printf '%s\n' "$out" | grep '게시 완료' | sed 's/.*게시 완료: //')"
  echo "$(now) 게시 성공 $slug $link" >> "$LOG"
  # 게시한 슬러그만 대기열에서 뺀다
  grep -v -x "$slug" "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"
else
  echo "$(now) 게시 실패 $slug :: $(printf '%s' "$out" | tail -3 | tr '\n' ' ')" >> "$LOG"
  exit 1
fi
