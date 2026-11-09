#!/usr/bin/env bash
# LH 분양·임대 공고 조회 — 한국토지주택공사_분양임대공고문 조회 서비스 (data.go.kr, B552555/lhLeaseNoticeInfo1)
# 신혼희망타운, 행복주택, 국민·영구·통합공공임대, 매입임대, 공공분양 공고와 접수 마감일을 찾는다.
#
# 인증키는 저장소 밖 파일에 둔다: ~/.policy-blog/gov24.key (같은 공공데이터포털 계정 키를 함께 쓴다)
# 이 스크립트는 키를 화면에 출력하지 않는다.
#
# 사용법
#   bash _tools/lh.sh list ["검색어"]   # 최근 약 2달 공고 중 공고명에 검색어가 들어간 것 (토지·상가 제외)
#   bash _tools/lh.sh all ["검색어"]    # 토지·상가까지 포함
#   예) bash _tools/lh.sh list 신혼희망   /   bash _tools/lh.sh list 행복주택
#
# 주의: 공고 목록일 뿐이다. 자격·금액·일정은 DTL_URL(LH청약플러스 공고문) 원문으로 확정한다(CLAUDE.md).

set -euo pipefail

KEY_FILE="${LH_KEY_FILE:-$HOME/.policy-blog/gov24.key}"
URL="https://apis.data.go.kr/B552555/lhLeaseNoticeInfo1/lhLeaseNoticeInfo1"

[ -s "$KEY_FILE" ] || { echo "인증키 파일이 비어 있거나 없습니다: $KEY_FILE" >&2; exit 1; }
KEY="$(tr -d ' \r\n' < "$KEY_FILE")"

mode="${1:-}"; q="${2:-}"
case "$mode" in list|all) ;; *) sed -n '9,12p' "$0"; exit 1 ;; esac

r="$(curl -s -m 60 --retry 2 -G "$URL" --data-urlencode "serviceKey=$KEY" --data-urlencode "PG_SZ=1000" --data-urlencode "PAGE=1")"
printf '%s' "$r" | grep -q '"dsList"' || { echo "API 오류: $(printf '%s' "$r" | sed "s/$KEY/***/g" | head -c 300)" >&2; exit 1; }

# 검색어는 환경변수로 넘긴다(윈도우에서 한글 인자 깨짐 방지)
printf '%s' "$r" | Q="$q" MODE="$mode" node -e '
  let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
    const j=JSON.parse(d); const s=j[0].dsSch[0]; let L=j[1].dsList||[];
    if(process.env.MODE==="list") L=L.filter(r=>!["01","22"].includes(r.UPP_AIS_TP_CD));
    const q=process.env.Q; if(q) L=L.filter(r=>r.PAN_NM.includes(q));
    console.log(`공고일 ${s.PAN_ST_DT}~${s.PAN_ED_DT} · ${L.length}건`);
    for(const r of L) console.log(`${r.PAN_NT_ST_DT} ~${r.CLSG_DT} [${r.PAN_SS}] ${r.AIS_TP_CD_NM} · ${r.CNP_CD_NM}\n  ${r.PAN_NM}\n  ${r.DTL_URL}`);
  });'
