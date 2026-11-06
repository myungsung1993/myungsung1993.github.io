#!/usr/bin/env bash
# 네이버 블로그 붙여넣기 묶음 만들기 (2026-11-07 사용자 확정 방식)
# 사용법: bash _tools/naver_pack.sh <출력 폴더> <슬러그> <폴더 이름> [<슬러그> <폴더 이름> ...]
#   예) bash _tools/naver_pack.sh "$HOME/OneDrive/바탕 화면/네이버예약_1118-1127" basic-pension-2026 11-18_기초연금
# 만드는 것: <출력 폴더>/<폴더 이름>/한번에복사.html (제목·태그 복사 버튼 + 사진·본문 한 번에 복사)
#           사진은 사이트에 올라간 인스타 카드(https://jiwongil.kr/assets/insta/<슬러그>/n.png)를 쓰므로 먼저 push해 둔다.
# 원고: _naver/<슬러그>/post.txt ([제목] [본문] [태그], 본문 속 [사진 n])
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$1"; shift
while [ $# -ge 2 ]; do
  s="$1"; name="$2"; shift 2
  src="$ROOT/_naver/$s/post.txt"; [ -s "$src" ] || { echo "원고 없음: $src" >&2; exit 1; }
  d="$OUT/$name"; mkdir -p "$d"
  title=$(awk '/^\[제목\]/{getline; print; exit}' "$src")
  tags=$(awk '/^\[태그\]/{getline; print; exit}' "$src")
  body=$(awk '/^\[본문\]/{f=1;next} /^\[태그\]/{f=0} f' "$src" | sed -E 's/&/\&amp;/g; s/</\&lt;/g; s#^\[사진 ([0-9]+)\]$#<p><img src="https://jiwongil.kr/assets/insta/'"$s"'/\1.png" width="540"></p>#; t; s#^$#<p>\&nbsp;</p>#; t; s#^(.*)$#<p>\1</p>#')
  # 점선 테두리는 복사 영역(#copy) 바깥 .frame에 둔다. 안에 두면 네이버 본문에 테두리가 같이 붙는다(11-07 확인).
  cat > "$d/한번에복사.html" <<EOF
<!doctype html><html lang="ko"><head><meta charset="utf-8"><title>$name</title>
<style>body{font-family:"Malgun Gothic",sans-serif;max-width:640px;margin:20px auto;padding:0 16px;line-height:1.7}
.guide{background:#fff4e0;border:1px solid #f0c36d;padding:10px 14px;border-radius:8px;font-size:14px}
.frame{border:2px dashed #1a6fd1;padding:12px;margin-top:12px}</style></head><body>
<div class="guide"><p><b>1. 제목</b> <button onclick="navigator.clipboard.writeText(document.getElementById('t').innerText);this.innerText='복사됨'">제목 복사</button><br><span id="t">$title</span></p><p><b>2. 태그</b> <button onclick="navigator.clipboard.writeText(document.getElementById('g').innerText.replace(/, /g,' '));this.innerText='복사됨'">태그 복사</button><br><span id="g">$tags</span></p><b>3. 본문</b> 파란 점선 상자 안을 클릭(전체 선택) → Ctrl+C → 네이버 본문에 Ctrl+V</div>
<div class="frame"><div id="copy" onclick="var r=document.createRange();r.selectNodeContents(this);var s=getSelection();s.removeAllRanges();s.addRange(r);">
$body
</div></div></body></html>
EOF
  echo "만듦: $d/한번에복사.html (사진 $(grep -c '<img' "$d/한번에복사.html")장)"
done
