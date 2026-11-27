#!/usr/bin/env bash
# 네이버 블로그 붙여넣기 묶음 만들기 (2026-11-07 사용자 확정 방식)
# 사용법: bash _tools/naver_pack.sh <출력 폴더> <슬러그> <폴더 이름> [<슬러그> <폴더 이름> ...]
#   예) bash _tools/naver_pack.sh "$HOME/Desktop/네이버예약_1118-1127" basic-pension-2026 11-18_기초연금
# 만드는 것: <출력 폴더>/<폴더 이름>/한번에복사.html (제목·태그 복사 버튼 + 사진·본문 한 번에 복사)
#           사진은 사이트에 올라간 인스타 카드(https://jiwongil.kr/assets/insta/<슬러그>/n.png)를 쓰므로 먼저 push해 둔다.
#           인스타 카드가 없는 글은 요약 카드가 대표사진(비상용). 11-26부터는 카드가 없으면 insta.html로 네이버용 카드 6장을 먼저 만든다(사용자: 2장은 허전).
# 원고: _naver/<슬러그>/post.txt ([제목] [본문] [태그], 본문 속 [사진 n], 신청 흐름도는 [흐름도 사이트슬러그] 한 줄 — 2026-11-10~)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$1"; shift
while [ $# -ge 2 ]; do
  s="$1"; name="$2"; shift 2
  src="$ROOT/_naver/$s/post.txt"; [ -s "$src" ] || { echo "원고 없음: $src" >&2; exit 1; }
  d="$OUT/$name"; mkdir -p "$d"
  # 붙여넣은 사진은 jiwongil.kr 링크 사진이라 네이버 대표 사진이 될 수 없다(11-16 확인: 목록·검색 썸네일 빈칸). 첫 장은 파일로 올린다.
  # 인스타 카드가 없는 글은 요약 카드(1200×630)를 대표사진으로 쓴다(11-21 사용자 확정: 요약 카드 + 흐름도). 이런 글 원고는 [사진 1]과 [흐름도 …]만 쓴다.
  if [ -f "$ROOT/assets/insta/$s/1.png" ]; then cp "$ROOT/assets/insta/$s/1.png" "$d/대표사진.png"
  else cp "$ROOT/assets/images/cards/$s.png" "$d/대표사진.png"
    grep -qE '^\[사진 ([2-9]|[0-9]{2,})\]$' "$src" && { echo "인스타 카드 없는 글에 [사진 2~] 있음: $src" >&2; exit 1; }
  fi
  title=$(awk '/^\[제목\]/{getline; print; exit}' "$src")
  tags=$(awk '/^\[태그\]/{getline; print; exit}' "$src")
  cat=$(awk '/^\[카테고리\]/{getline; print; exit}' "$src")
  catline=""; [ -n "$cat" ] && catline="<p><b>0. 카테고리</b> <b style=\"color:#c2410c\">$cat</b> (발행 설정에서 선택)</p>"
  # 카테고리 색(11-27): 정부정책뉴스 노랑, 상황별 지원 모음 초록, 나머지 파랑. ?v= 는 다시 캡처한 카드가 브라우저 캐시로 옛 그림이 붙는 것 방지
  hc="#1a6fd1"; case "$cat" in 정부정책뉴스) hc="#b7860b";; "상황별 지원 모음") hc="#2e8b57";; esac; v=$(date +%s)
  body=$(awk '/^\[본문\]/{f=1;next} /^\[(카테고리|태그)\]/{f=0} f' "$src" | sed -E 's/&/\&amp;/g; s/</\&lt;/g; s#^\[사진 1\]$#<p><b style="color:rgb(194,65,12)">▶ 여기를 누르고 사진 버튼으로 대표사진.png 올리기 (올린 뒤 이 줄은 지우기)</b></p>#; t; s#^\[사진 ([0-9]+)\]$#<p><img src="https://jiwongil.kr/assets/insta/'"$s"'/\1.png?v='"$v"'" width="540"></p>#; t; s#^\[흐름도 ([a-z0-9-]+)\]$#<p><img src="https://jiwongil.kr/assets/images/flow/\1.png?v='"$v"'" width="540"></p>#; t; s#^$#<p>\&nbsp;</p>#; t; s|^■ (.*)$|<p><span style="font-size:19px"><b style="color:'"$hc"'">■ \1</b></span></p>|; t; s#(https://[^ ]+)#<a href="\1">\1</a>#g; s#^(.*)$#<p>\1</p>#; s#^(<p>👉 .*</p>)$#\1<p><a href="https://jiwongil.kr"><img src="https://jiwongil.kr/assets/brand/naver-footer.png" width="540"></a></p>#')
  # 서식(11-14): "■ 소제목" 줄은 크고 굵은 파란 글씨, 사이트 링크(👉) 줄 아래에 공통 배너(_tools/naver_banner.html → assets/brand/naver-footer.png, 누르면 사이트)
  # 주소를 <a>로 감싼다: HTML로 붙여넣으면 네이버가 글자 주소를 자동으로 링크로 바꾸지 않는다(11-09 확인).
  # 점선 테두리는 복사 영역(#copy) 바깥 .frame에 둔다. 안에 두면 네이버 본문에 테두리가 같이 붙는다(11-07 확인).
  cat > "$d/한번에복사.html" <<EOF
<!doctype html><html lang="ko"><head><meta charset="utf-8"><title>$name</title>
<style>body{font-family:"Malgun Gothic",sans-serif;max-width:640px;margin:20px auto;padding:0 16px;line-height:1.7}
.guide{background:#fff4e0;border:1px solid #f0c36d;padding:10px 14px;border-radius:8px;font-size:14px}
.frame{border:2px dashed #1a6fd1;padding:12px;margin-top:12px}</style></head><body>
<div class="guide">$catline<p><b>1. 제목</b> <button onclick="navigator.clipboard.writeText(document.getElementById('t').innerText);this.innerText='복사됨'">제목 복사</button><br><span id="t">$title</span></p><p><b>2. 태그</b> <button onclick="navigator.clipboard.writeText(document.getElementById('g').innerText.replace(/, /g,' '));this.innerText='복사됨'">태그 복사</button><br><span id="g">$tags</span></p><b>3. 본문</b> 파란 점선 상자 안을 클릭(전체 선택) → Ctrl+C → 네이버 본문에 Ctrl+V<p><b style="color:#c2410c">4. 대표 사진</b> 붙여넣은 본문 맨 위 주황색 줄을 누르고 사진 버튼 → 이 폴더의 <b>대표사진.png</b> 올리기 → 주황색 줄 지우기. 올린 사진에 <b>대표</b> 표시가 없으면 사진을 눌러 대표 지정</p></div>
<div class="frame"><div id="copy" onclick="var r=document.createRange();r.selectNodeContents(this);var s=getSelection();s.removeAllRanges();s.addRange(r);">
$body
</div></div></body></html>
EOF
  echo "만듦: $d/한번에복사.html (사진 $(grep -c '<img' "$d/한번에복사.html")장)"
done
