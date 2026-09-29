// Shared drawing helpers for the Steal a Donut ads. Every helper returns an SVG string.
let uid = 0;
const id = (p) => `${p}${++uid}`;

// Seeded random so every render is identical
let seed = 7;
function rnd() {
  seed = (seed * 16807) % 2147483647;
  return (seed - 1) / 2147483646;
}

function shade(hex, amt) {
  const n = parseInt(hex.slice(1), 16);
  let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  const t = amt < 0 ? 0 : 255, p = Math.abs(amt);
  r = Math.round((t - r) * p + r); g = Math.round((t - g) * p + g); b = Math.round((t - b) * p + b);
  return `#${((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)}`;
}

// Wavy frosting outline around an ellipse; drips hang down on the front half.
function frostingPath(cx, cy, rx, ry, drips) {
  const pts = [];
  const N = 180;
  for (let i = 0; i <= N; i++) {
    const a = (i / N) * Math.PI * 2;
    let x = cx + Math.cos(a) * rx;
    let y = cy + Math.sin(a) * ry;
    const front = Math.max(0, Math.sin(a)); // 0 at the back, 1 at the front
    let drip = 0;
    for (const d of drips) {
      const da = Math.atan2(Math.sin(a - d.a), Math.cos(a - d.a));
      drip += d.len * Math.exp(-(da * da) / (2 * d.w * d.w));
    }
    y += drip * front;
    x += Math.sin(a * 9) * rx * 0.012;
    pts.push([x, y]);
  }
  return "M" + pts.map((p) => p[0].toFixed(1) + " " + p[1].toFixed(1)).join(" L") + " Z";
}

// A brainrot donut character.
// o: { x, y, r, dough, frosting, sprinkles:[colors], eyes:'sneaky'|'happy'|'shock'|'cool',
//      legs, arms, crown, glow, halo, mouth:'smile'|'o'|'grin', tilt }
function donut(o) {
  const { x, y, r } = o;
  const dough = o.dough || "#e7a15a";
  const frost = o.frosting || "#ff6fb5";
  const g1 = id("dough"), g2 = id("frost"), g3 = id("hi"), clip = id("clip");
  let s = `<g transform="rotate(${o.tilt || 0} ${x} ${y})">`;
  s += `<defs>
    <radialGradient id="${g1}" cx="35%" cy="30%" r="80%"><stop offset="0" stop-color="${shade(dough, 0.35)}"/><stop offset="0.6" stop-color="${dough}"/><stop offset="1" stop-color="${shade(dough, -0.35)}"/></radialGradient>
    <radialGradient id="${g2}" cx="35%" cy="25%" r="85%"><stop offset="0" stop-color="${shade(frost, 0.45)}"/><stop offset="0.55" stop-color="${frost}"/><stop offset="1" stop-color="${shade(frost, -0.3)}"/></radialGradient>
    <radialGradient id="${g3}" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#fff" stop-opacity="0.9"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
  </defs>`;
  if (o.glow) {
    s += `<circle cx="${x}" cy="${y}" r="${r * 1.9}" fill="${o.glow}" opacity="0.35" filter="url(#blur40)"/>`;
  }
  // legs
  if (o.legs) {
    for (const side of [-1, 1]) {
      const lx = x + side * r * 0.38, ly = y + r * 0.45;
      const fx = lx + side * r * 0.08 + (o.run ? side * r * 0.25 : 0), fy = y + r * 1.12;
      s += `<path d="M${lx} ${ly} Q ${lx + side * r * 0.1} ${(ly + fy) / 2} ${fx} ${fy}" stroke="#3b2414" stroke-width="${r * 0.1}" fill="none" stroke-linecap="round"/>`;
      s += `<ellipse cx="${fx + side * r * 0.06}" cy="${fy + r * 0.03}" rx="${r * 0.16}" ry="${r * 0.08}" fill="${o.shoes || "#e8313a"}" stroke="#2a1208" stroke-width="${r * 0.025}"/>`;
    }
  }
  // arms
  if (o.arms) {
    for (const side of [-1, 1]) {
      const ax = x + side * r * 0.95, ay = y + r * 0.05;
      const hx = ax + side * r * 0.35, hy = ay + (o.armsUp ? -r * 0.55 : r * 0.2);
      s += `<path d="M${ax} ${ay} Q ${ax + side * r * 0.25} ${ay} ${hx} ${hy}" stroke="#3b2414" stroke-width="${r * 0.08}" fill="none" stroke-linecap="round"/>`;
      s += `<circle cx="${hx}" cy="${hy}" r="${r * 0.1}" fill="#fff" stroke="#2a1208" stroke-width="${r * 0.025}"/>`;
    }
  }
  // body: bottom (thickness) then top
  s += `<ellipse cx="${x}" cy="${y + r * 0.2}" rx="${r}" ry="${r * 0.62}" fill="${shade(dough, -0.3)}" stroke="#2a1208" stroke-width="${r * 0.035}"/>`;
  s += `<ellipse cx="${x}" cy="${y}" rx="${r}" ry="${r * 0.6}" fill="url(#${g1})" stroke="#2a1208" stroke-width="${r * 0.035}"/>`;
  // frosting with drips
  const drips = [];
  for (let i = 0; i < 7; i++) drips.push({ a: 0.35 + i * 0.4 + rnd() * 0.15, len: r * (0.08 + rnd() * 0.16), w: 0.08 + rnd() * 0.05 });
  s += `<path d="${frostingPath(x, y - r * 0.03, r * 0.9, r * 0.52, drips)}" fill="url(#${g2})" stroke="${shade(frost, -0.55)}" stroke-width="${r * 0.03}" stroke-linejoin="round"/>`;
  if (o.rainbow) {
    const rg = id("rb");
    s += `<defs><linearGradient id="${rg}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff3b3b"/><stop offset="0.2" stop-color="#ffb13b"/><stop offset="0.4" stop-color="#fff23b"/><stop offset="0.6" stop-color="#3bff7a"/><stop offset="0.8" stop-color="#3bb8ff"/><stop offset="1" stop-color="#b43bff"/></linearGradient></defs>`;
    s += `<path d="${frostingPath(x, y - r * 0.03, r * 0.9, r * 0.52, drips)}" fill="url(#${rg})" opacity="${o.rainbowOpacity || 0.55}"/>`;
  }
  // hole
  s += `<ellipse cx="${x}" cy="${y - r * 0.07}" rx="${r * 0.27}" ry="${r * 0.14}" fill="${shade(dough, -0.55)}" stroke="#2a1208" stroke-width="${r * 0.03}"/>`;
  s += `<ellipse cx="${x}" cy="${y - r * 0.04}" rx="${r * 0.2}" ry="${r * 0.08}" fill="${o.holeColor || "#1a0b05"}" opacity="0.8"/>`;
  // sprinkles
  const cols = o.sprinkles || ["#fff", "#ffe14d", "#4dd2ff", "#7dff6a"];
  for (let i = 0; i < 26; i++) {
    const a = rnd() * Math.PI * 2;
    const d = 0.45 + rnd() * 0.45;
    const sx = x + Math.cos(a) * r * 0.85 * d;
    const sy = y - r * 0.05 + Math.sin(a) * r * 0.48 * d;
    if (Math.abs(sx - x) < r * 0.32 && Math.abs(sy - (y - r * 0.07)) < r * 0.18) continue;
    if (sy > y + r * 0.1 && Math.abs(sx - x) < r * 0.5) continue; // keep the face clear
    s += `<rect x="${sx - r * 0.045}" y="${sy - r * 0.013}" width="${r * 0.09}" height="${r * 0.026}" rx="${r * 0.013}" fill="${cols[i % cols.length]}" transform="rotate(${rnd() * 180} ${sx} ${sy})"/>`;
  }
  // highlight
  s += `<ellipse cx="${x - r * 0.45}" cy="${y - r * 0.28}" rx="${r * 0.26}" ry="${r * 0.1}" fill="url(#${g3})" transform="rotate(-18 ${x - r * 0.45} ${y - r * 0.28})"/>`;
  // face on the front of the frosting
  const ey = y + r * 0.2, ex = r * 0.24, er = r * 0.13;
  const eyes = o.eyes || "happy";
  if (eyes === "cool") {
    s += `<path d="M${x - ex - er * 1.4} ${ey - er * 0.7} H ${x + ex + er * 1.4} L ${x + ex + er * 1.1} ${ey + er * 0.9} Q ${x + ex} ${ey + er * 1.3} ${x + ex - er * 1.1} ${ey + er * 0.7} L ${x + er * 0.3} ${ey - er * 0.2} H ${x - er * 0.3} L ${x - ex + er * 1.1} ${ey + er * 0.7} Q ${x - ex} ${ey + er * 1.3} ${x - ex - er * 1.1} ${ey + er * 0.9} Z" fill="#111" stroke="#000" stroke-width="${r * 0.02}"/>`;
    s += `<path d="M${x - ex - er * 0.7} ${ey - er * 0.3} l ${er * 0.6} ${-er * 0.2}" stroke="#fff" stroke-width="${r * 0.025}" stroke-linecap="round" opacity="0.8"/>`;
    s += `<path d="M${x + ex - er * 0.2} ${ey - er * 0.3} l ${er * 0.6} ${-er * 0.2}" stroke="#fff" stroke-width="${r * 0.025}" stroke-linecap="round" opacity="0.8"/>`;
  } else {
    for (const side of [-1, 1]) {
      const cx = x + side * ex;
      const h = eyes === "shock" ? er * 1.25 : er;
      s += `<ellipse cx="${cx}" cy="${ey}" rx="${er}" ry="${h}" fill="#fff" stroke="#1a0b05" stroke-width="${r * 0.025}"/>`;
      let px = cx, py = ey;
      if (eyes === "sneaky") px += er * 0.45;
      if (eyes === "happy") py += er * 0.15;
      const pr = eyes === "shock" ? er * 0.35 : er * 0.5;
      s += `<circle cx="${px}" cy="${py}" r="${pr}" fill="#1a0b05"/><circle cx="${px - pr * 0.35}" cy="${py - pr * 0.35}" r="${pr * 0.35}" fill="#fff"/>`;
      if (eyes === "sneaky") s += `<path d="M${cx - er * 1.1} ${ey - er * 0.35} Q ${cx} ${ey - er * 0.75} ${cx + er * 1.1} ${ey - er * 0.35}" fill="${frost}" stroke="#1a0b05" stroke-width="${r * 0.02}"/>`;
    }
  }
  const my = y + r * 0.42;
  const mouth = o.mouth || "smile";
  if (mouth === "o") s += `<ellipse cx="${x}" cy="${my}" rx="${r * 0.07}" ry="${r * 0.09}" fill="#3a0d0d" stroke="#1a0b05" stroke-width="${r * 0.02}"/>`;
  else if (mouth === "grin") s += `<path d="M${x - r * 0.18} ${my - r * 0.04} Q ${x} ${my + r * 0.16} ${x + r * 0.18} ${my - r * 0.04} Z" fill="#3a0d0d" stroke="#1a0b05" stroke-width="${r * 0.02}"/><path d="M${x - r * 0.14} ${my - r * 0.02} H ${x + r * 0.14}" stroke="#fff" stroke-width="${r * 0.035}"/>`;
  else s += `<path d="M${x - r * 0.13} ${my - r * 0.02} Q ${x} ${my + r * 0.1} ${x + r * 0.13} ${my - r * 0.02}" stroke="#1a0b05" stroke-width="${r * 0.035}" fill="none" stroke-linecap="round"/>`;
  // crown
  if (o.crown) {
    const cy = y - r * 0.58, w = r * 0.55;
    s += `<path d="M${x - w} ${cy} L ${x - w * 1.05} ${cy - r * 0.45} L ${x - w * 0.5} ${cy - r * 0.2} L ${x} ${cy - r * 0.55} L ${x + w * 0.5} ${cy - r * 0.2} L ${x + w * 1.05} ${cy - r * 0.45} L ${x + w} ${cy} Z" fill="#ffd23a" stroke="#7a4a00" stroke-width="${r * 0.03}" stroke-linejoin="round"/>`;
    for (const [dx, c] of [[-0.55, "#ff2d55"], [0, "#2dc9ff"], [0.55, "#3dff7a"]]) s += `<circle cx="${x + dx * w}" cy="${cy - r * 0.1}" r="${r * 0.06}" fill="${c}" stroke="#7a4a00" stroke-width="${r * 0.015}"/>`;
  }
  if (o.halo) {
    s += `<ellipse cx="${x}" cy="${y - r * (o.crown ? 1.35 : 0.95)}" rx="${r * 0.55}" ry="${r * 0.13}" fill="none" stroke="${o.halo}" stroke-width="${r * 0.07}" filter="url(#glow8)"/>`;
  }
  s += `</g>`;
  return s;
}

// A blocky avatar (generic, Roblox-style proportions). o: { x, y (feet), s (scale), pose, colors, face }
function avatar(o) {
  const s = o.s || 1;
  const c = Object.assign({ head: "#ffd23a", torso: "#2f7bff", arms: "#ffd23a", legs: "#38c95a", outline: "#15121f" }, o.colors || {});
  const w = 3 * s; // outline width
  const part = (x, y, wd, h, fill, rot, px, py) =>
    `<rect x="${x}" y="${y}" width="${wd}" height="${h}" rx="${6 * s}" fill="${fill}" stroke="${c.outline}" stroke-width="${w}" ${rot ? `transform="rotate(${rot} ${px} ${py})"` : ""}/>`;
  const p = o.pose || {};
  let g = `<g transform="translate(${o.x} ${o.y}) ${o.flip ? "scale(-1 1)" : ""}">`;
  const legH = 70 * s, legW = 30 * s, torsoH = 72 * s, torsoW = 66 * s, armW = 28 * s, armH = 70 * s, head = 54 * s;
  const hipY = -legH, shY = hipY - torsoH;
  // back arm, back leg
  g += part(-legW, hipY, legW, legH, shade(c.legs, -0.25), p.legBack || 0, -legW / 2, hipY);
  g += part(-torsoW / 2 - armW + 2 * s, shY, armW, armH, shade(c.arms, -0.2), p.armBack || 0, -torsoW / 2 - armW / 2, shY + 6 * s);
  // torso
  g += part(-torsoW / 2, shY, torsoW, torsoH, c.torso, p.lean || 0, 0, hipY);
  // front leg
  g += part(0, hipY, legW, legH, c.legs, p.legFront || 0, legW / 2, hipY);
  // head
  const hx = -head / 2 + (p.headX || 0) * s, hy = shY - head - 4 * s;
  g += `<g ${p.lean ? `transform="rotate(${p.lean} 0 ${hipY})"` : ""}>`;
  g += `<rect x="${hx}" y="${hy}" width="${head}" height="${head}" rx="${12 * s}" fill="${c.head}" stroke="${c.outline}" stroke-width="${w}"/>`;
  const fx = hx + head / 2, fy = hy + head / 2;
  const face = o.face || "smile";
  if (face === "sneaky") {
    g += `<rect x="${fx - 17 * s}" y="${fy - 8 * s}" width="${9 * s}" height="${6 * s}" rx="${2 * s}" fill="${c.outline}"/><rect x="${fx + 8 * s}" y="${fy - 8 * s}" width="${9 * s}" height="${6 * s}" rx="${2 * s}" fill="${c.outline}"/>`;
    g += `<path d="M${fx - 12 * s} ${fy + 8 * s} q ${12 * s} ${9 * s} ${22 * s} ${-4 * s}" stroke="${c.outline}" stroke-width="${3.5 * s}" fill="none" stroke-linecap="round"/>`;
  } else if (face === "evil") {
    g += `<path d="M${fx - 18 * s} ${fy - 12 * s} l ${11 * s} ${6 * s} M${fx + 18 * s} ${fy - 12 * s} l ${-11 * s} ${6 * s}" stroke="${c.outline}" stroke-width="${3.5 * s}" stroke-linecap="round"/>`;
    g += `<circle cx="${fx - 10 * s}" cy="${fy - 1 * s}" r="${4 * s}" fill="${c.outline}"/><circle cx="${fx + 10 * s}" cy="${fy - 1 * s}" r="${4 * s}" fill="${c.outline}"/>`;
    g += `<path d="M${fx - 13 * s} ${fy + 9 * s} q ${13 * s} ${12 * s} ${26 * s} 0 z" fill="${c.outline}"/>`;
  } else if (face === "angry") {
    g += `<path d="M${fx - 18 * s} ${fy - 14 * s} l ${12 * s} ${7 * s} M${fx + 18 * s} ${fy - 14 * s} l ${-12 * s} ${7 * s}" stroke="${c.outline}" stroke-width="${4 * s}" stroke-linecap="round"/>`;
    g += `<circle cx="${fx - 10 * s}" cy="${fy - 1 * s}" r="${4.5 * s}" fill="${c.outline}"/><circle cx="${fx + 10 * s}" cy="${fy - 1 * s}" r="${4.5 * s}" fill="${c.outline}"/>`;
    g += `<ellipse cx="${fx}" cy="${fy + 13 * s}" rx="${9 * s}" ry="${6 * s}" fill="${c.outline}"/>`;
  } else {
    g += `<circle cx="${fx - 10 * s}" cy="${fy - 4 * s}" r="${4 * s}" fill="${c.outline}"/><circle cx="${fx + 10 * s}" cy="${fy - 4 * s}" r="${4 * s}" fill="${c.outline}"/>`;
    g += `<path d="M${fx - 12 * s} ${fy + 7 * s} q ${12 * s} ${10 * s} ${24 * s} 0" stroke="${c.outline}" stroke-width="${3.5 * s}" fill="none" stroke-linecap="round"/>`;
  }
  g += `</g>`;
  // front arm
  g += part(torsoW / 2 - 2 * s, shY, armW, armH, c.arms, p.armFront || 0, torsoW / 2 + armW / 2, shY + 6 * s);
  g += `</g>`;
  return g;
}

function sparkle(x, y, size, color, opacity = 1) {
  const s = size;
  return `<path d="M${x} ${y - s} C ${x + s * 0.12} ${y - s * 0.12} ${x + s * 0.12} ${y - s * 0.12} ${x + s} ${y} C ${x + s * 0.12} ${y + s * 0.12} ${x + s * 0.12} ${y + s * 0.12} ${x} ${y + s} C ${x - s * 0.12} ${y + s * 0.12} ${x - s * 0.12} ${y + s * 0.12} ${x - s} ${y} C ${x - s * 0.12} ${y - s * 0.12} ${x - s * 0.12} ${y - s * 0.12} ${x} ${y - s} Z" fill="${color}" opacity="${opacity}"/>`;
}

function rays(cx, cy, n, len, color, opacity, width = 0.12) {
  let s = `<g opacity="${opacity}">`;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    const a1 = a - width / 2, a2 = a + width / 2;
    s += `<path d="M${cx} ${cy} L ${cx + Math.cos(a1) * len} ${cy + Math.sin(a1) * len} L ${cx + Math.cos(a2) * len} ${cy + Math.sin(a2) * len} Z" fill="${color}"/>`;
  }
  return s + `</g>`;
}

// Outlined game-style text. o: { x, y, size, fill (color or gradient url), stroke, sw, anchor, rotate, font, shadow }
function title(text, o) {
  const font = o.font || "Luckiest Guy";
  const anchor = o.anchor || "middle";
  const sw = o.sw || o.size * 0.16;
  const tr = o.rotate ? `transform="rotate(${o.rotate} ${o.x} ${o.y})"` : "";
  const ls = o.spacing != null ? `letter-spacing="${o.spacing}"` : "";
  let s = `<g ${tr}>`;
  if (o.shadow !== false) s += `<text x="${o.x + o.size * 0.05}" y="${o.y + o.size * 0.09}" font-family="${font}" font-size="${o.size}" text-anchor="${anchor}" ${ls} fill="#000" opacity="0.45" stroke="#000" stroke-width="${sw}" stroke-linejoin="round" paint-order="stroke">${text}</text>`;
  s += `<text x="${o.x}" y="${o.y}" font-family="${font}" font-size="${o.size}" text-anchor="${anchor}" ${ls} fill="${o.fill || "#fff"}" stroke="${o.stroke || "#1b0b2e"}" stroke-width="${sw}" stroke-linejoin="round" paint-order="stroke">${text}</text>`;
  return s + `</g>`;
}

// "STEAL A DONUT" lockup with a little donut. (x, y) = top-left.
function logo(x, y, scale = 1) {
  const s = scale;
  let g = `<g transform="translate(${x} ${y}) scale(${s})">`;
  g += `<defs><linearGradient id="logoGrad" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff36b"/><stop offset="1" stop-color="#ffb21e"/></linearGradient>
  <linearGradient id="logoPink" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffb3dc"/><stop offset="1" stop-color="#ff4fa3"/></linearGradient></defs>`;
  g += title("STEAL A", { x: 0, y: 70, size: 74, fill: "url(#logoGrad)", anchor: "start", sw: 14 });
  g += title("DONUT", { x: 0, y: 150, size: 92, fill: "url(#logoPink)", anchor: "start", sw: 16 });
  g += donut({ x: 330, y: 118, r: 38, frosting: "#ff5fae", eyes: "happy", mouth: "grin" });
  g += `</g>`;
  return g;
}

// Common <defs>: blur and glow filters.
const commonDefs = `<defs>
  <filter id="blur40" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="40"/></filter>
  <filter id="blur20" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="20"/></filter>
  <filter id="blur8" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="8"/></filter>
  <filter id="glow8" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
</defs>`;

function page(svgInner) {
  document.body.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">${commonDefs}${svgInner}</svg>`;
}
