#!/usr/bin/env bash
# 인스타 카드뉴스 이미지로 릴스용 세로 영상(1080x1920) 만들기 — 배경음악 없음
#
# 사용법
#   bash _tools/insta_reel.sh <슬러그> [출력 파일] [카드당 초]
#   예) bash _tools/insta_reel.sh youth-housing-support-2026            # assets/insta/<슬러그>/reel.mp4
#       bash _tools/insta_reel.sh youth-housing-support-2026 /tmp/a.mp4 5
#
# - 카드(1080x1350)를 세로 화면 위쪽에 두고 남는 칸은 카드 모서리 색으로 채운다.
#   릴스 화면 아래쪽은 캡션·버튼이 덮으므로 카드를 위로 올려 둔다(위 170px, 아래 400px).
# - 카드 사이는 0.4초 겹쳐 넘긴다. 카드당 기본 4.5초(글씨가 많아 3초는 읽기 어려움).
# - 숫자는 카드 이미지 그대로다. 영상만 새로 만드는 것이라 카드 팩트체크를 다시 할 필요는 없다.

set -euo pipefail

slug="${1:?슬러그를 넣어 주세요 (예: youth-housing-support-2026)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
dir="$ROOT/assets/insta/$slug"
out="${2:-$dir/reel.mp4}"
per="${3:-4.5}"
fade=0.4
top=170

command -v ffmpeg >/dev/null || { echo "ffmpeg가 없습니다 (winget install Gyan.FFmpeg)" >&2; exit 1; }
imgs=( $(ls "$dir" | grep -E '^[0-9]+\.png$' | sort -n) )
[ "${#imgs[@]}" -ge 2 ] || { echo "카드 이미지가 2장 이상 있어야 합니다: $dir" >&2; exit 1; }

# 카드 왼쪽 위 모서리 색 (배경 채우기용)
corner() {
  ffmpeg -v error -i "$1" -vf "crop=1:1:5:5,format=rgb24" -f rawvideo - | od -An -tx1 | tr -d ' \n'
}

inputs=(); filters=""; n=${#imgs[@]}
for i in "${!imgs[@]}"; do
  f="$dir/${imgs[$i]}"
  inputs+=( -loop 1 -t "$per" -i "$f" )
  c="$(corner "$f")"
  filters+="[$i:v]scale=1080:1350,pad=1080:1920:0:$top:0x$c,setsar=1,fps=30,format=yuv420p[v$i];"
done

# 카드를 차례로 겹쳐 넘기기(xfade)
prev="v0"; offset=0
for (( i=1; i<n; i++ )); do
  offset=$(awk "BEGIN{print $offset + $per - $fade}")
  filters+="[$prev][v$i]xfade=transition=fade:duration=$fade:offset=$offset[x$i];"
  prev="x$i"
done
filters="${filters%;}"

ffmpeg -v error -y "${inputs[@]}" -filter_complex "$filters" -map "[$prev]" \
  -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p -r 30 -movflags +faststart "$out"

dur=$(awk "BEGIN{print $n * $per - ($n - 1) * $fade}")
echo "만듦: $out (${n}장, 약 ${dur}초, $(du -h "$out" | cut -f1))"
