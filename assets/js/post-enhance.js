// 세부 글 화면 다듬기 (2026-11-10). 글 원고는 그대로 두고 보이는 모양만 바꾼다. 스크립트가 안 돌면 예전 모양 그대로.
(function () {
  var c = document.querySelector(".post-content"); if (!c) return;
  // 1. 목차 접기
  var toc = c.querySelector(".toc-box .toc-title");
  if (toc) { toc.parentNode.classList.add("toc-js"); toc.setAttribute("role", "button"); toc.tabIndex = 0;
    var t = function () { toc.parentNode.classList.toggle("is-open"); };
    toc.addEventListener("click", t); toc.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); t(); } }); }
  // 9. 핵심 요약 상자에 말하는 모습
  c.querySelectorAll("blockquote").forEach(function (b) { if (b.querySelector(".summary-char") || !/^\s*💡?\s*핵심 요약/.test(b.textContent)) return;
    var im = document.createElement("img"); im.className = "summary-char"; im.alt = ""; im.src = (window.CHAR_BASE || "/assets/brand/char/") + "talk.png"; b.classList.add("has-char"); b.prepend(im); });
  // 2. 출처 표시 방법 상자
  c.querySelectorAll("blockquote").forEach(function (b) { if (/^\s*출처 표시 방법/.test(b.textContent)) b.classList.add("src-howto"); });
  // 3. 요약 카드를 핵심 요약 아래로
  var card = c.querySelector("img.summary-card"), cardP = card && card.closest("p");
  if (cardP) { var n = cardP.nextElementSibling; if (n && n.tagName === "BLOCKQUOTE") n.after(cardP); }
  // 4. 신청 단계: "어떻게 신청" 소제목 바로 뒤 첫 번호 목록
  c.querySelectorAll("h2").forEach(function (h) { if (!/어떻게 신청/.test(h.textContent)) return;
    for (var e = h.nextElementSibling; e && e.tagName !== "H2"; e = e.nextElementSibling) if (e.tagName === "OL") { e.classList.add("steps"); break; } });
  // 5. 표 머리 줄이 "항목 | 내용"이면 숨김
  c.querySelectorAll("table").forEach(function (tb) { var th = tb.querySelectorAll("thead th");
    if (th.length === 2 && th[0].textContent.trim() === "항목" && th[1].textContent.trim() === "내용") tb.classList.add("no-head"); });
  // 5. (출처①) 표시: 단독 줄은 오른쪽 작은 글씨, 문장 안은 작은 회색
  var re = /\(출처[①-⑳]+(?:, ?출처[①-⑳]+)*\)/;
  c.querySelectorAll("p").forEach(function (p) { if (/^\s*\(출처[①-⑳]+(?:, ?출처[①-⑳]+)*\)\s*$/.test(p.textContent)) p.classList.add("src-line"); });
  var w = document.createTreeWalker(c, NodeFilter.SHOW_TEXT), list = [];
  while (w.nextNode()) if (re.test(w.currentNode.nodeValue) && !w.currentNode.parentNode.closest(".src-line")) list.push(w.currentNode);
  list.forEach(function (tn) { var f = document.createDocumentFragment();
    tn.nodeValue.split(/(\(출처[①-⑳]+(?:, ?출처[①-⑳]+)*\))/).forEach(function (s) { if (!s) return;
      if (re.test(s)) { var sp = document.createElement("span"); sp.className = "src"; sp.textContent = s; f.appendChild(sp); } else f.appendChild(document.createTextNode(s)); });
    tn.parentNode.replaceChild(f, tn); });
})();
