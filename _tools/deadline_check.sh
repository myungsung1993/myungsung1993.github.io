#!/usr/bin/env bash
# 신청 마감 점검 — 글 머리말의 deadline(이번 회차 마감일)을 오늘 날짜와 비교해 할 일을 알려 준다.
#
# 사용법: bash _tools/deadline_check.sh [남은 일수, 기본 14]
#
# 보여 주는 것
#   마감 지남  : 블로그 카드 "신청기간 만료" 도장(_tools/card.html expired)이 없으면 [도장 필요]
#                인스타·쓰레드에 올린 글인데 마감 안내 댓글을 안 달았으면 [인스타 안내 필요] [쓰레드 안내 필요]
#   곧 마감    : N일 안에 마감되는 글 (SNS에 한 번 더 알릴지 판단용)
# 블로그 본문의 마감 안내 상자·홈 배지는 deadline 값으로 자동 표시되므로(_layouts/post.html) 따로 할 일이 없다.
#
# 기록: SNS에 단 마감 안내는 ~/.policy-blog/deadline_marks.txt 에 "insta|threads <슬러그> <날짜> <링크>" 한 줄씩 남긴다.
# 규칙: CLAUDE.md "신청기간 만료 표시" — 안내 댓글도 fact-checker 검토 후 게시한다.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DAYS="${1:-14}"
MARKS="$HOME/.policy-blog/deadline_marks.txt"; touch "$MARKS"
INSTA_LOG="$HOME/.policy-blog/insta_log.txt"

# 쓰레드에 올린 글 슬러그 (토큰이 있으면 API로, 없으면 빈 목록)
threads=""
if [ -s "$HOME/.policy-blog/threads.token" ]; then
  T="$(tr -d ' \r\n' < "$HOME/.policy-blog/threads.token")"
  threads="$(curl -s -m 30 -G "https://graph.threads.com/v1.0/me/threads" --data-urlencode "fields=link_attachment_url" \
             --data-urlencode "limit=100" --data-urlencode "access_token=$T" | grep -o 'link_attachment_url":"[^"]*' | sed 's#\\/#/#g; s#.*/\([a-z0-9-]*\)/$#\1#' | sort -u | tr '\n' ' ')"
fi
insta="$(grep -o '\(성공\|게시 확인([^)]*)\) [a-z0-9-]*' "$INSTA_LOG" 2>/dev/null | awk '{print $NF}' | sort -u | tr '\n' ' ')"

ROOT="$ROOT" DAYS="$DAYS" MARKS="$MARKS" INSTA="$insta" THREADS="$threads" node -e '
const fs = require("fs"), path = require("path"), root = process.env.ROOT;
const card = fs.readFileSync(path.join(root, "_tools/card.html"), "utf8");
const cards = eval("(" + card.split("<script>")[1].match(/const cards = (\{[\s\S]*?\n\});/)[1] + ")");
const marks = fs.readFileSync(process.env.MARKS, "utf8");
const insta = process.env.INSTA.split(" "), threads = process.env.THREADS.split(" ");
const today = new Date(); today.setHours(0, 0, 0, 0);
const rows = [];
for (const f of fs.readdirSync(path.join(root, "_posts")).sort()) {
  const fm = fs.readFileSync(path.join(root, "_posts", f), "utf8").split("---")[1] || "";
  const m = fm.match(/^deadline:\s*(\d{4}-\d{2}-\d{2})/m); if (!m) continue;
  const slug = f.slice(11, -3), note = (fm.match(/^deadline_note:\s*"?([^"\n]*)/m) || [])[1] || "";
  const days = Math.round((new Date(m[1] + "T00:00:00") - today) / 86400000);
  const todo = [];
  if (days < 0) {
    if (!(cards[slug] && cards[slug].expired)) todo.push("[도장 필요]");
    if (insta.includes(slug) && !marks.includes("insta " + slug + " ")) todo.push("[인스타 안내 필요]");
    if (threads.includes(slug) && !marks.includes("threads " + slug + " ")) todo.push("[쓰레드 안내 필요]");
  }
  const state = days < 0 ? "마감 지남" : days <= +process.env.DAYS ? `곧 마감(${days}일 남음)` : `${days}일 남음`;
  rows.push(`${m[1]}  ${state.padEnd(12)}  ${slug} (${note})  ${todo.join(" ") || (days < 0 ? "표시 완료" : "")}`);
}
console.log(rows.join("\n") || "deadline이 있는 글이 없습니다.");
'
