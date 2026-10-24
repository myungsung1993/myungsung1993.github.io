// threads_upload.sh comments 보조: 답글 목록 JSON(표준 입력)을 읽어 남의 댓글만 한 줄씩 보여 준다.
// 환경변수: PID(게시물 ID), ME(내 계정 이름), DONE(답글 기록 폴더 — <댓글ID>.posted 가 있으면 답글 단 것)
const fs = require("fs");
let d = "";
process.stdin.on("data", c => (d += c)).on("end", () => {
  const j = JSON.parse(d);
  if (j.error) { console.error("API 오류:", j.error.message); return; }
  for (const c of j.data || []) {
    if (c.username === process.env.ME) continue;
    const mark = fs.existsSync(`${process.env.DONE}/${c.id}.posted`) ? " " : "*";
    console.log(`${mark} 댓글 ${c.id} (게시물 ${process.env.PID}, @${c.username}, ${c.timestamp})`);
    console.log(`    ${String(c.text || "").replace(/\n/g, " ")}`);
  }
});
