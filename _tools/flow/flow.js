// 신청 흐름도 그리기 (2026-11-10). 각 글의 _tools/flow/<슬러그>.html 이 FLOW 내용을 적고 이 파일을 불러온다.
// 왼쪽 파란 막대 = 신청자, 오른쪽 상자 = 기관. 화살표 in = 신청자→상자, out = 상자→신청자, v = 상자 사이 세로.
// 규칙(CLAUDE.md): 번호는 본문 단계 번호와 같게, 글자는 본문 그대로, 새 정보 금지, fact-checker 검토.
(function () {
  const F = window.FLOW, W = 900, H = F.height;
  const esc = s => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;");
  const T = (x, y, size, txt, o = {}) =>
    `<text x="${x}" y="${y}" font-size="${size}"${o.bold ? ` font-weight="${o.bold}"` : ""} fill="${o.fill || "#1b2430"}"${o.mid ? ' text-anchor="middle"' : ""}${o.end ? ' text-anchor="end"' : ""}>${esc(txt)}</text>`;
  const dot = (x, y, n, c) => `<circle cx="${x}" cy="${y}" r="20" fill="${c}"/>` + T(x, y + 9, 24, n, { bold: 800, fill: "#fff", mid: 1 });
  const BLUE = "#1a6fd1", ORANGE = "#c2410c";
  let s = `<defs><marker id="ah" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path d="M0,0 L10,5 L0,10 z" fill="${BLUE}"/></marker>`
    + `<marker id="ao" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path d="M0,0 L10,5 L0,10 z" fill="${ORANGE}"/></marker></defs>`
    + `<rect x="14" y="14" width="872" height="${H - 28}" rx="40" fill="#f6f9fd" stroke="#bcd3ef" stroke-width="3"/>`
    + T(56, 90, 30, F.label, { bold: 700, fill: BLUE }) + T(56, 148, 50, "신청 흐름 한눈에 보기", { bold: 800 })
    + `<image href="../../assets/brand/char/think.png" x="716" y="24" width="128" height="146"/>`;
  // 위 주황 상자: 먼저 할 일(번호 있는 단계 또는 한 줄)
  const n = F.note, nh = n.sub ? 128 : 84;
  s += `<rect x="56" y="180" width="788" height="${nh}" rx="18" fill="#fff6ef" stroke="#f3c7a8" stroke-width="2"/>`;
  if (n.steps) { let x = 96; for (const [k, t] of n.steps) { s += dot(x, 226, k, ORANGE) + T(x + 30, 236, 29, t, { bold: 800, fill: ORANGE }); x += 60 + t.length * 27; } }
  else s += T(84, 234, 29, n.main, { bold: 800, fill: ORANGE });
  if (n.sub) s += T(84, 284, 25, n.sub, { fill: "#8a5a3c" });
  // 신청자 막대
  const a = F.applicant, mid = (a.y0 + a.y1) / 2;
  s += `<rect x="56" y="${a.y0}" width="190" height="${a.y1 - a.y0}" rx="26" fill="${BLUE}"/>` + T(151, mid - 10, 44, "신청자", { bold: 800, fill: "#fff", mid: 1 });
  a.lines.forEach((t, i) => { s += T(151, mid + 36 + i * 34, 25, t, { fill: "#dbe9fb", mid: 1 }); });
  // 기관 상자
  const ST = { head: [26, 700, BLUE], title: [30, 800, "#1b2430"], text: [26, 0, "#4a5565"], em: [28, 800, BLUE] };
  for (const b of F.boxes) {
    s += `<rect x="480" y="${b.y}" width="364" height="${b.h}" rx="24" fill="#fff" stroke="${b.main ? BLUE : "#6b7684"}" stroke-width="3"/>`;
    const gap = 40, top = b.y + (b.h - gap * (b.lines.length - 1)) / 2 + 10;
    b.lines.forEach(([st, t], i) => { const [sz, bo, c] = ST[st]; s += T(662, top + i * gap, sz, t, { bold: bo || 0, fill: c, mid: 1 }); });
  }
  // 화살표
  for (const r of F.arrows) {
    const c = r.dash ? ORANGE : BLUE, m = r.dash ? "ao" : "ah", da = r.dash ? ' stroke-dasharray="14 10"' : "";
    if (r.type === "v") {
      s += `<path d="M662,${r.y0} L662,${r.y1 - 8}" stroke="${c}" stroke-width="6" marker-end="url(#${m})"${da}/>`;
      const my = (r.y0 + r.y1) / 2;
      if (r.n) s += dot(614, my, r.n, c);
      s += T(686, my + 10, 26, r.label, { bold: 700 });
    } else {
      s += r.type === "in" ? `<path d="M246,${r.y} L472,${r.y}" stroke="${c}" stroke-width="6" marker-end="url(#${m})"${da}/>`
                           : `<path d="M480,${r.y} L254,${r.y}" stroke="${c}" stroke-width="6" marker-end="url(#${m})"${da}/>`;
      const lx = r.n ? 320 : 270, ls = r.label.split("\n");  // 긴 라벨은 "\n"으로 두 줄(위로 쌓음)
      if (r.n) s += dot(290, r.y - 38 - (ls.length - 1) * 32, r.n, c);
      ls.forEach((t, i) => { s += T(lx, r.y - 27 - (ls.length - 1 - i) * 32, 28, t, { bold: 800, fill: r.dash ? ORANGE : "#1b2430" }); });
      (r.sub || []).forEach((t, i) => { s += T(270, r.y + 36 + i * 30, 22, t, { fill: "#8a5a3c" }); });
    }
  }
  // 메모: 문자열은 "※ ", [번호, 글]은 동그라미 번호(본문 단계)
  (F.notes || []).forEach((t, i) => { const y = F.notesY + i * 40;
    s += Array.isArray(t) ? dot(286, y - 8, t[0], BLUE) + T(314, y, 24, t[1], { bold: 700 }) : T(270, y, 24, "※ " + t, { fill: "#4a5565" }); });
  s += T(56, H - 30, 21, "개인이 정리한 그림", { fill: "#6b7684" }) + T(844, H - 30, 21, F.foot, { fill: "#6b7684", end: 1 });
  document.body.style.cssText = `margin:0;width:${W}px;height:${H}px;background:#fff`;
  document.body.innerHTML = `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg" style="font-family:Pretendard,'Malgun Gothic',sans-serif">${s}</svg>`;
})();
