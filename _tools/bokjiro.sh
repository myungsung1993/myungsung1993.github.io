#!/usr/bin/env bash
# 복지로 중앙부처 복지서비스 조회 (한국사회보장정보원 OpenAPI, data.go.kr 15090532)
#
# 인증키는 저장소 밖 파일에 둔다: ~/.policy-blog/bokjiro.key (공공데이터포털 '일반 인증키(Decoding)' 한 줄)
# 이 스크립트는 키를 화면에 출력하지 않는다. 개발계정은 하루 100회까지 호출할 수 있다.
#
# 사용법
#   bash _tools/bokjiro.sh list "검색어" [개수]   # 제목+내용 검색, 인기순 (개수 기본 20, 최대 500)
#   bash _tools/bokjiro.sh detail 서비스ID        # 대상자·선정기준·급여내용·신청방법·근거법령
#
# 주의: API 내용은 요약본이고 갱신이 늦을 수 있다. 주제 찾기와 교차 확인용으로 쓰고,
#       글의 금액·기간·조건은 공고문·보도자료 원문으로 확정한다(CLAUDE.md).

set -euo pipefail

KEY_FILE="${BOKJIRO_KEY_FILE:-$HOME/.policy-blog/bokjiro.key}"
BASE="https://apis.data.go.kr/B554287/NationalWelfareInformationsV001"

if [ ! -s "$KEY_FILE" ]; then
  echo "인증키 파일이 비어 있거나 없습니다: $KEY_FILE" >&2
  exit 1
fi
KEY="$(tr -d ' \r\n' < "$KEY_FILE")"

# 윈도우용 curl은 --data-urlencode로 넘긴 한글을 다른 인코딩으로 바꿔 버려 검색이 안 된다.
# 그래서 UTF-8 바이트를 직접 %XX로 바꿔서 -d로 넘긴다.
urlenc() { printf '%s' "$1" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g'; }

# XML 태그를 '이름: 값' 줄로 바꾼다. 빈 값과 래퍼 태그는 뺀다.
pretty() {
  sed -e 's/<\([A-Za-z]*\)>\([^<]*\)<\/\1>/\n\1: \2\n/g' \
      -e 's/&lt;/</g; s/&gt;/>/g; s/&amp;/\&/g; s/&quot;/"/g' \
    | grep -E '^[A-Za-z]+: ' \
    | grep -vE '^[A-Za-z]+: $'
}

check() {
  local body="$1"
  local code
  code="$(printf '%s' "$body" | grep -o '<resultCode>[^<]*' | head -1 | sed 's/<resultCode>//')"
  if [ -n "$code" ] && [ "$code" != "0" ] && [ "$code" != "00" ]; then
    echo "API 오류 (resultCode=$code): $(printf '%s' "$body" | grep -o '<resultMessage>[^<]*' | sed 's/<resultMessage>//')" >&2
    exit 1
  fi
  if printf '%s' "$body" | grep -q 'SERVICE_KEY_IS_NOT_REGISTERED\|returnAuthMsg'; then
    echo "인증 오류: $(printf '%s' "$body" | grep -o '<returnAuthMsg>[^<]*' | sed 's/<returnAuthMsg>//')" >&2
    echo "(키를 막 발급받았다면 반영까지 1시간쯤 걸릴 수 있습니다)" >&2
    exit 1
  fi
}

case "${1:-}" in
  list)
    word="${2:?검색어를 넣어 주세요}"
    rows="${3:-20}"
    body="$(curl -sG -m 30 "$BASE/NationalWelfarelistV001" \
      --data-urlencode "serviceKey=$KEY" \
      --data-urlencode "callTp=L" --data-urlencode "pageNo=1" \
      --data-urlencode "numOfRows=$rows" --data-urlencode "srchKeyCode=003" \
      -d "searchWrd=$(urlenc "$word")" --data-urlencode "orderBy=popular")"
    check "$body"
    echo "전체 결과: $(printf '%s' "$body" | grep -o '<totalCount>[^<]*' | sed 's/<totalCount>//')건"
    printf '%s' "$body" | sed 's/<servList>/<sep>----------<\/sep>/g' | pretty \
      | grep -E '^(sep|servNm|servId|jurMnofNm|servDgst|sprtCycNm|srvPvsnNm|onapPsbltYn): ' | sed 's/^sep: //' || true
    ;;
  detail)
    id="${2:?서비스ID를 넣어 주세요 (예: WLF00004661)}"
    body="$(curl -sG -m 30 "$BASE/NationalWelfaredetailedV001" \
      --data-urlencode "serviceKey=$KEY" \
      --data-urlencode "callTp=D" --data-urlencode "servId=$id")"
    check "$body"
    printf '%s' "$body" | sed 's/&#13;/ /g; s/&#9;/ /g' | pretty
    ;;
  *)
    sed -n '2,13p' "$0"
    exit 1
    ;;
esac
