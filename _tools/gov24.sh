#!/usr/bin/env bash
# 보조금24(정부24) 공공서비스 조회 — 행정안전부 「대한민국 공공서비스(혜택) 정보」 (data.go.kr, api.odcloud.kr/api/gov24/v3)
# 중앙부처뿐 아니라 지자체·공공기관 서비스까지 들어 있다(복지로 API는 중앙부처만).
#
# 인증키는 저장소 밖 파일에 둔다: ~/.policy-blog/gov24.key (공공데이터포털 인증키 한 줄)
# 이 스크립트는 키를 화면에 출력하지 않는다.
#
# 사용법
#   bash _tools/gov24.sh list "검색어" [개수]   # 서비스명에 검색어가 들어간 서비스 (개수 기본 20)
#   bash _tools/gov24.sh find "검색어" [개수]   # 서비스목적요약에 검색어가 들어간 서비스 (주제 찾기용)
#   bash _tools/gov24.sh detail 서비스ID        # 지원대상·선정기준·지원내용·신청기한·신청방법·구비서류·문의처·법령
#
# 주의: 요약본이고 갱신이 늦을 수 있다. 주제 찾기·교차 확인용으로 쓰고, 금액·기간·조건은 공고문·보도자료 원문으로 확정한다(CLAUDE.md).

set -euo pipefail

KEY_FILE="${GOV24_KEY_FILE:-$HOME/.policy-blog/gov24.key}"
BASE="https://api.odcloud.kr/api/gov24/v3"

[ -s "$KEY_FILE" ] || { echo "인증키 파일이 비어 있거나 없습니다: $KEY_FILE" >&2; exit 1; }
KEY="$(tr -d ' \r\n' < "$KEY_FILE")"

# 윈도우용 curl은 한글 인자 인코딩을 깨뜨리므로 UTF-8 바이트를 직접 %XX로 바꾼다(_tools/bokjiro.sh와 같은 방식).
urlenc() { printf '%s' "$1" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g'; }

# 경로, 조건 필드, 연산자(LIKE/EQ), 값, 개수
call() {
  local url="$BASE/$1?page=1&perPage=$5&returnType=JSON&$(urlenc "cond[$2::$3]")=$(urlenc "$4")&serviceKey=$(urlenc "$KEY")"
  local r; r="$(curl -s -m 30 --retry 2 "$url")"
  printf '%s' "$r" | grep -q '"data"' || { echo "API 오류: $(printf '%s' "$r" | sed "s/$KEY/***/g" | head -c 300)" >&2; exit 1; }
  printf '%s' "$r"
}

case "${1:-}" in
  list|find)
    q="${2:?검색어를 넣어 주세요}"; n="${3:-20}"
    field="서비스명"; [ "$1" = find ] && field="서비스목적요약"
    call serviceList "$field" LIKE "$q" "$n" | node -e '
      let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{const j=JSON.parse(d);
        console.log(`전체 결과: ${j.matchCount}건 (표시 ${j.currentCount}건)`);
        for(const s of j.data){console.log("----------");
          for(const k of ["서비스ID","서비스명","소관기관명","소관기관유형","지원유형","신청기한","서비스목적요약"]) if(s[k]) console.log(`${k}: ${String(s[k]).replace(/\s+/g," ").slice(0,200)}`);}})'
    ;;
  detail)
    id="${2:?서비스ID를 넣어 주세요}"
    call serviceDetail 서비스ID EQ "$id" 1 | node -e '
      let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{const s=JSON.parse(d).data[0];
        if(!s){console.log("해당 서비스가 없습니다");return}
        for(const [k,v] of Object.entries(s)) if(v!==null&&v!=="") console.log(`[${k}]\n${String(v).replace(/\r/g,"").trim()}\n`);})'
    ;;
  *)
    sed -n '2,12p' "$0"; exit 1 ;;
esac
