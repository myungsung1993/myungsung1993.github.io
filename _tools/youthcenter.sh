#!/usr/bin/env bash
# 온통청년 청년정책 조회 — 온통청년(youthcenter.go.kr) 청년정책 API (go/ythip/getPlcy)
# 중앙부처·지자체 청년정책(약 4천 개)의 대상 나이, 신청 기간, 담당 기관을 찾는다.
#
# 인증키는 저장소 밖 파일에 둔다: ~/.policy-blog/youthcenter.key (온통청년에서 따로 발급, 한 줄)
# 이 스크립트는 키를 화면에 출력하지 않는다.
#
# 사용법
#   bash _tools/youthcenter.sh list "검색어" [개수]   # 정책명에 검색어가 들어간 정책 (개수 기본 20)
#   bash _tools/youthcenter.sh detail 정책번호         # 지원 내용·대상·소득·신청 방법·제출 서류·참고 주소
#
# 주의: 기관이 입력한 요약이라 갱신이 늦거나 빈칸이 많다. 주제 찾기용으로 쓰고, 금액·기간·조건은 공고문 원문으로 확정한다(CLAUDE.md).
# 윈도우 curl은 한글 검색어를 깨뜨려서 node(fetch)로 호출한다.

set -euo pipefail

KEY_FILE="${YOUTHCENTER_KEY_FILE:-$HOME/.policy-blog/youthcenter.key}"
[ -s "$KEY_FILE" ] || { echo "인증키 파일이 비어 있거나 없습니다: $KEY_FILE" >&2; exit 1; }

mode="${1:-}"
case "$mode" in
  list)   [ -n "${2:-}" ] || { echo "검색어를 넣어 주세요" >&2; exit 1; } ;;
  detail) [ -n "${2:-}" ] || { echo "정책번호를 넣어 주세요" >&2; exit 1; } ;;
  *) sed -n '8,10p' "$0"; exit 1 ;;
esac

KEY_FILE="$KEY_FILE" MODE="$mode" ARG="$2" N="${3:-20}" node -e '
const fs=require("fs");
const key=fs.readFileSync(process.env.KEY_FILE,"utf8").trim();
const {MODE,ARG,N}=process.env;
const q={apiKeyNm:key,pageNum:"1",rtnType:"json"};
if(MODE==="list"){q.pageSize=N;q.plcyNm=ARG}else{q.pageSize="1";q.plcyNo=ARG}
const ymd=s=>s?s.replace(/(\d{4})(\d{2})(\d{2})/g,"$1.$2.$3."):"";
fetch("https://www.youthcenter.go.kr/go/ythip/getPlcy?"+new URLSearchParams(q)).then(r=>r.text()).then(t=>{
  let j;try{j=JSON.parse(t)}catch(e){console.error("API 오류: "+t.slice(0,300).split(key).join("***"));process.exit(1)}
  if(j.resultCode!==200){console.error("API 오류: "+(j.resultMessage||"").split(key).join("***"));process.exit(1)}
  const L=j.result.youthPolicyList||[];
  if(MODE==="list"){
    console.log(`전체 결과: ${j.result.pagging.totCount}건 (표시 ${L.length}건)`);
    for(const r of L){
      const age=r.sprtTrgtAgeLmtYn==="Y"?"나이 제한 없음":`만 ${r.sprtTrgtMinAge}~${r.sprtTrgtMaxAge}세`;
      console.log(`${r.plcyNo}  ${r.plcyNm}\n  ${r.sprvsnInstCdNm} · ${age} · 신청 ${ymd(r.aplyYmd)||"(기간 미입력)"}`);
    }
  }else{
    const r=L[0]; if(!r){console.error("해당 정책번호가 없습니다");process.exit(1)}
    const f=[["정책명",r.plcyNm],["분류",r.lclsfNm+" > "+r.mclsfNm],["담당",r.sprvsnInstCdNm],["설명",r.plcyExplnCn],["지원 내용",r.plcySprtCn],
      ["나이",r.sprtTrgtAgeLmtYn==="Y"?"제한 없음":`만 ${r.sprtTrgtMinAge}~${r.sprtTrgtMaxAge}세`],["소득",[r.earnMinAmt,r.earnMaxAmt].filter(x=>x&&x!=="0").join("~")+" "+(r.earnEtcCn||"")],
      ["추가 자격",r.addAplyQlfcCndCn],["참여 제외",r.ptcpPrpTrgtCn],["신청 기간",ymd(r.aplyYmd)],["사업 기간",ymd(r.bizPrdBgngYmd)+" ~ "+ymd(r.bizPrdEndYmd)+" "+(r.bizPrdEtcCn||"")],
      ["신청 방법",r.plcyAplyMthdCn],["심사",r.srngMthdCn],["제출 서류",r.sbmsnDcmntCn],["기타",r.etcMttrCn],["신청 주소",r.aplyUrlAddr],["참고 주소",[r.refUrlAddr1,r.refUrlAddr2].filter(Boolean).join(" ")],["최종 수정",r.lastMdfcnDt]];
    for(const [k,v] of f){const s=String(v||"").replace(/null/g,"").trim(); if(s&&s!==">"&&s!=="~") console.log(`■ ${k}: ${s}`);}
  }
});'
