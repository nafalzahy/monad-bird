// game-core.js - dipakai BROWSER dan SERVER (harus identik)
(function (root) {
  var W = 400, H = 600, BX = 80, BR = 14;

  // === TABEL KESULITAN (ubah angka di sini kalau mau disetel) ===
  // food: makanan sebelum boss muncul   hp: nyawa boss
  // fire: jeda tembakan boss (makin besar makin jarang)   vol: jumlah api sekali tembak
  // fb: kecepatan api   ps: kecepatan pilar   gap: lebar celah pilar   spd: kecepatan gerak boss
  var BOSS = [null,
    { name: "Elang",       food: 3, hp: 8,  fire: 90, vol: 1, fb: 3.0, ps: 1.9, gap: 235, spd: 0.8 },
    { name: "Naga Angin",  food: 4, hp: 12, fire: 78, vol: 1, fb: 3.3, ps: 2.1, gap: 222, spd: 0.95 },
    { name: "Phoenix",     food: 5, hp: 18, fire: 70, vol: 1, fb: 3.6, ps: 2.3, gap: 210, spd: 1.1 },
    { name: "Raja Langit", food: 6, hp: 26, fire: 62, vol: 2, fb: 3.9, ps: 2.6, gap: 200, spd: 1.25 }
  ];

  function rand(g) { // angka acak deterministik (seed sama = hasil sama)
    g.r = (g.r + 0x6D2B79F5) | 0;
    var t = Math.imul(g.r ^ (g.r >>> 15), 1 | g.r);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  function newGame(id, seed) {
    var b = BOSS[id];
    return { id: id, b: b, r: seed | 0, t: 0, y: 300, vy: 0, lives: 5, inv: 0, food: 0, score: 0,
      phase: "run", pipes: [], seeds: [], fires: [], boss: null, bhp: b.hp,
      nextPipe: 60, lastGap: 300, won: false, over: false };
  }

  function hit(g) {
    if (g.inv > 0) return;
    g.lives--; g.inv = 120;
    if (g.lives <= 0) g.over = true;
  }

  function step(g, flap) {
    if (g.over) return;
    var b = g.b, i;
    g.t++;

    // burung
    if (flap) g.vy = -5.8;
    g.vy = Math.min(7, g.vy + 0.33);
    g.y += g.vy;
    if (g.inv > 0) g.inv--;
    if (g.y < BR) { g.y = BR; g.vy = 0; }
    if (g.y > H - BR) { g.y = H - BR; g.vy = -6; hit(g); }

    // pilar + makanan
    if (g.phase === "run" && g.t >= g.nextPipe) {
      var gy = g.lastGap + (rand(g) - 0.5) * 110;
      gy = Math.max(200, Math.min(400, gy));
      g.lastGap = gy;
      g.pipes.push({ x: W + 30, gy: gy, food: true });
      g.nextPipe = g.t + Math.round(270 / b.ps);
    }
    for (i = g.pipes.length - 1; i >= 0; i--) {
      var p = g.pipes[i];
      p.x -= b.ps;
      if (p.x < -60) { g.pipes.splice(i, 1); continue; }
      if (BX + BR > p.x - 25 && BX - BR < p.x + 25 && Math.abs(g.y - p.gy) > b.gap / 2 - BR) hit(g);
      if (p.food && Math.abs(p.x - BX) < 34 && Math.abs(g.y - p.gy) < 40) {
        p.food = false; g.food++; g.score += 10;
      }
    }

    // boss muncul setelah cukup makanan
    if (g.phase === "run" && g.food >= b.food) {
      g.phase = "boss";
      g.boss = { x: W + 60, y: 300, dir: 1, cd: 90 };
    }

    if (g.phase === "boss") {
      var bo = g.boss;
      if (bo.x > W - 80) bo.x -= 2;
      else {
        bo.y += bo.dir * b.spd;
        if (bo.y > 460) bo.dir = -1;
        if (bo.y < 140) bo.dir = 1;
        if (--bo.cd <= 0) {
          bo.cd = b.fire;
          var offs = b.vol === 1 ? [0] : [0, rand(g) < 0.5 ? -100 : 100];
          for (i = 0; i < offs.length; i++)
            g.fires.push({ x: bo.x - 30, y: Math.max(20, Math.min(H - 20, g.y + offs[i])) });
        }
      }
      if (g.t % 12 === 0) g.seeds.push({ x: BX + 16, y: g.y }); // tembak otomatis
    }

    // biji kita
    for (i = g.seeds.length - 1; i >= 0; i--) {
      var s = g.seeds[i];
      s.x += 7;
      if (s.x > W + 20) { g.seeds.splice(i, 1); continue; }
      if (g.boss && s.x > g.boss.x - 30 && Math.abs(s.y - g.boss.y) < 70) {
        g.seeds.splice(i, 1); g.bhp--; g.score += 5;
        if (g.bhp <= 0) { g.won = true; g.over = true; g.score += 500 + g.lives * 100; return; }
      }
    }

    // api boss
    for (i = g.fires.length - 1; i >= 0; i--) {
      var f = g.fires[i];
      f.x -= b.fb;
      if (f.x < -20) { g.fires.splice(i, 1); continue; }
      if (Math.abs(f.x - BX) < BR + 8 && Math.abs(f.y - g.y) < BR + 8) { g.fires.splice(i, 1); hit(g); }
    }

    if (g.t >= 12000) g.over = true; // batas waktu
  }

  // dipakai server: putar ulang permainan dari daftar tap
  function simulate(id, seed, inputs) {
    var g = newGame(id, seed), set = {}, i;
    for (i = 0; i < inputs.length; i++) set[inputs[i]] = 1;
    while (!g.over) step(g, !!set[g.t]);
    return { won: g.won, score: g.score, ticks: g.t };
  }

  var api = { W: W, H: H, BX: BX, BR: BR, BOSS: BOSS, newGame: newGame, step: step, simulate: simulate };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.Core = api;
})(this);