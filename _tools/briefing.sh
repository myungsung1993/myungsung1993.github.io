#!/usr/bin/env bash
# 정책브리핑 정책뉴스 조회 (문화체육관광부 OpenAPI, data.go.kr 15095335)
#
# 인증키는 저장소 밖 파일에 둔다: ~/.policy-blog/briefing.key (공공데이터포털 '일반 인증키(Decoding)' 한 줄)
# 이 스크립트는 키를 화면에 출력하지 않는다.
#
# 사용법
#   bash _tools/briefing.sh list [일수] ["검색어"]   # 최근 N일(기본 7) 정책뉴스. 검색어는 제목·부제·본문에서 찾음
#   bash _tools/briefing.sh read 기사ID [일수]        # 그 기사 본문(태그 제거)을 보여 줌 (기본 최근 14일 안에서 찾음)
#
# 주의: API는 한 번에 3일치까지만 준다. 그래서 3일씩 나눠서 부른다.
#       정책뉴스는 정책브리핑 기자가 쓴 기사다. 글의 금액·기간은 부처 보도자료·공고 원문으로 확정한다(CLAUDE.md).

set -euo pipefail

KEY_FILE="${BRIEFING_KEY_FILE:-$HOME/.policy-blog/briefing.key}"
URL="https://apis.data.go.kr/1371000/policyNewsService2/policyNewsList2"

if [ ! -s "$KEY_FILE" ]; then
  echo "인증키 파일이 비어 있거나 없습니다: $KEY_FILE" >&2
  exit 1
fi
KEY="$(tr -d ' \r\n\357\273\277' < "$KEY_FILE")"

# 최근 N일을 3일씩 끊어 받아 하나의 XML 덩어리로 출력
fetch() {
  local days="$1" end start
  local i=0
  while [ "$i" -lt "$days" ]; do
    end="$(date -d "-$i day" +%Y%m%d)"
    local span=$(( days - i < 3 ? days - i : 3 ))
    start="$(date -d "-$(( i + span - 1 )) day" +%Y%m%d)"
    curl -s -m 60 --retry 2 -G "$URL" --data-urlencode "serviceKey=$KEY" \
      --data-urlencode "startDate=$start" --data-urlencode "endDate=$end" \
      | grep -v '<?xml' || true
    i=$(( i + span ))
  done
}

case "${1:-}" in
  list)
    days="${2:-7}"; q="${3:-}"
    fetch "$days" | awk -v q="$q" '
      BEGIN { RS="<NewsItem>"; n=0 }
      NR > 1 {
        id=$0; sub(/.*<NewsItemId>/, "", id); sub(/<.*/, "", id)
        dt=$0; sub(/.*<ApproveDate>/, "", dt); sub(/<.*/, "", dt)
        split(dt, a, /[\/ ]/); dt=a[3] "-" a[1] "-" a[2]
        mi=$0; if (mi ~ /<MinisterCode>/) { sub(/.*<MinisterCode>/, "", mi); sub(/<.*/, "", mi) } else mi="-"
        t=$0; sub(/.*<Title><!\[CDATA\[/, "", t); sub(/\]\]>.*/, "", t)
        u=$0; sub(/.*<OriginalUrl><!\[CDATA\[/, "", u); sub(/\]\]>.*/, "", u)
        if (u ~ /</) { u=$0; sub(/.*<OriginalUrl>/, "", u); sub(/<.*/, "", u) }
        if (q != "" && index($0, q) == 0) next
        if (seen[id]++) next
        print dt " | " mi " | " t " | ID " id " | " u; n++
      }
      END { print "---- " n "건" > "/dev/stderr" }' | sort -r
    ;;
  read)
    id="${2:?기사ID를 넣어 주세요}"; days="${3:-14}"
    fetch "$days" | awk -v id="$id" '
      BEGIN { RS="<NewsItem>" }
      index($0, "<NewsItemId>" id "</NewsItemId>") {
        t=$0; sub(/.*<Title><!\[CDATA\[/, "", t); sub(/\]\]>.*/, "", t)
        c=$0; sub(/.*<DataContents><!\[CDATA\[/, "", c); sub(/\]\]>.*/, "", c)
        gsub(/<br[^>]*>|<\/p>/, "\n", c); gsub(/<[^>]*>/, "", c); gsub(/&nbsp;/, " ", c)
        gsub(/\n[ \t]*\n+/, "\n", c)
        print "# " t; print c; found=1; exit
      }
      END { if (!found) print "최근 기간에서 기사를 찾지 못했습니다. 일수를 늘려 보세요." > "/dev/stderr" }'
    ;;
  *)
    sed -n '2,13p' "$0"; exit 1 ;;
esac
