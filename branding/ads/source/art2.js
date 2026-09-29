// Thumbnail-style helpers (bright, glossy, big text), built on art.js.

// A front-facing donut: glossy frosting, sprinkles and a see-through hole.
// o: { x, y, R, frosting, dough, glow, rainbow, crown, sprinkles }
function frontDonut(o) {
  const { x, y, R } = o;
  const frost = o.frosting || "#ff8fc8";
  const dough = o.dough || "#e9a55b";
  const d = id("fd"), f = id("ff"), m = id("fm"), hi = id("fh"), inner = id("fi");
  let s = `<defs>
    <radialGradient id="${d}" cx="0.4" cy="0.35" r="0.7"><stop offset="0" stop-color="${shade(dough, 0.3)}"/><stop offset="0.7" stop-color="${dough}"/><stop offset="1" stop-color="${shade(dough, -0.45)}"/></radialGradient>
    <radialGradient id="${f}" cx="0.38" cy="0.3" r="0.8"><stop offset="0" stop-color="${shade(frost, 0.5)}"/><stop offset="0.5" stop-color="${frost}"/><stop offset="1" stop-color="${shade(frost, -0.35)}"/></radialGradient>
    <radialGradient id="${inner}" cx="0.5" cy="0.35" r="0.6"><stop offset="0.55" stop-color="${shade(dough, -0.5)}"/><stop offset="1" stop-color="${shade(dough, 0.1)}"/></radialGradient>
    <linearGradient id="${hi}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="0.85"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
    <mask id="${m}"><rect x="${x - R * 2}" y="${y - R * 2}" width="${R * 4}" height="${R * 4}" fill="#fff"/><circle cx="${x}" cy="${y}" r="${R * 0.27}" fill="#000"/></mask>
  </defs>`;
  if (o.glow) {
    s += `<circle cx="${x}" cy="${y}" r="${R * 1.0}" fill="none" stroke="${o.glow}" stroke-width="${R * 0.3}" opacity="0.8" filter="url(#blur20)"/>`;
    s += `<circle cx="${x}" cy="${y}" r="${R * 1.03}" fill="none" stroke="${shade(o.glow, 0.5)}" stroke-width="${R * 0.05}" opacity="0.8" filter="url(#blur8)"/>`;
  }
  s += `<g mask="url(#${m})">`;
  // thickness (bottom edge) then the dough
  s += `<circle cx="${x}" cy="${y + R * 0.05}" r="${R}" fill="${shade(dough, -0.5)}"/>`;
  s += `<circle cx="${x}" cy="${y}" r="${R}" fill="url(#${d})" stroke="#3a1a08" stroke-width="${R * 0.025}"/>`;
  s += `<circle cx="${x}" cy="${y}" r="${R * 0.4}" fill="url(#${inner})"/>`;
  // frosting ring with a wavy outer edge and a few drips
  const outer = [], innerPts = [];
  const N = 200;
  const drips = [0.9, 1.7, 2.35, 3.0, 4.1, 5.0, 5.8].map((a) => ({ a, len: R * (0.05 + rnd() * 0.07), w: 0.1 }));
  for (let i = 0; i <= N; i++) {
    const a = (i / N) * Math.PI * 2;
    let r = R * 0.86 + R * 0.025 * Math.sin(a * 9) + R * 0.015 * Math.sin(a * 23);
    for (const dr of drips) {
      const da = Math.atan2(Math.sin(a - dr.a), Math.cos(a - dr.a));
      r += dr.len * Math.exp(-(da * da) / (2 * dr.w * dr.w));
    }
    outer.push([x + Math.cos(a) * r, y + Math.sin(a) * r]);
    const ri = R * 0.4 + R * 0.02 * Math.sin(a * 7 + 1);
    innerPts.push([x + Math.cos(-a) * ri, y + Math.sin(-a) * ri]);
  }
  const path = (pts) => "M" + pts.map((p) => p[0].toFixed(1) + " " + p[1].toFixed(1)).join(" L") + " Z";
  s += `<path d="${path(outer)} ${path(innerPts)}" fill="${shade(frost, -0.45)}" transform="translate(0 ${R * 0.03})"/>`;
  s += `<path d="${path(outer)} ${path(innerPts)}" fill="url(#${f})" stroke="${shade(frost, -0.55)}" stroke-width="${R * 0.02}" stroke-linejoin="round"/>`;
  if (o.rainbow) {
    const rg = id("rbw");
    s += `<defs><linearGradient id="${rg}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff4d4d"/><stop offset="0.2" stop-color="#ffae3b"/><stop offset="0.4" stop-color="#fff04d"/><stop offset="0.6" stop-color="#4dff88"/><stop offset="0.8" stop-color="#4dc3ff"/><stop offset="1" stop-color="#c34dff"/></linearGradient></defs>`;
    s += `<path d="${path(outer)} ${path(innerPts)}" fill="url(#${rg})" opacity="0.8"/>`;
  }
  // sprinkles
  const cols = o.sprinkles || ["#ffffff", "#ffe14d", "#4dc3ff", "#7dff6a", "#ff4d6d", "#b36bff"];
  for (let i = 0; i < 46; i++) {
    const a = rnd() * Math.PI * 2;
    const r = R * (0.5 + rnd() * 0.3);
    const sx = x + Math.cos(a) * r, sy = y + Math.sin(a) * r;
    const len = R * 0.1, th = R * 0.035;
    s += `<rect x="${sx - len / 2}" y="${sy - th / 2}" width="${len}" height="${th}" rx="${th / 2}" fill="${cols[i % cols.length]}" stroke="${shade(cols[i % cols.length], -0.5)}" stroke-width="${R * 0.006}" transform="rotate(${rnd() * 180} ${sx} ${sy})"/>`;
  }
  // gloss
  s += `<path d="M${x - R * 0.72} ${y - R * 0.2} A ${R * 0.76} ${R * 0.76} 0 0 1 ${x - R * 0.1} ${y - R * 0.75}" stroke="url(#${hi})" stroke-width="${R * 0.09}" fill="none" stroke-linecap="round"/>`;
  s += `<circle cx="${x - R * 0.5}" cy="${y - R * 0.62}" r="${R * 0.04}" fill="#fff" opacity="0.9"/>`;
  s += `</g>`;
  if (o.crown) {
    const cy = y - R * 0.92, w = R * 0.42;
    s += `<g transform="rotate(-8 ${x} ${cy})"><path d="M${x - w} ${cy} L ${x - w * 1.08} ${cy - R * 0.4} L ${x - w * 0.5} ${cy - R * 0.18} L ${x} ${cy - R * 0.5} L ${x + w * 0.5} ${cy - R * 0.18} L ${x + w * 1.08} ${cy - R * 0.4} L ${x + w} ${cy} Z" fill="#ffd23a" stroke="#7a4a00" stroke-width="${R * 0.025}" stroke-linejoin="round"/>`;
    for (const [dx, c] of [[-0.55, "#ff2d55"], [0, "#2dc9ff"], [0.55, "#3dff7a"]]) s += `<circle cx="${x + dx * w}" cy="${cy - R * 0.08}" r="${R * 0.05}" fill="${c}" stroke="#7a4a00" stroke-width="${R * 0.012}"/>`;
    s += `</g>`;
  }
  return s;
}

// Per-letter rainbow title with a thick dark outline (thumbnail style).
function rainbowTitle(text, o) {
  const palette = o.palette || ["#ff3b3b", "#ff8a1f", "#ffd21f", "#5de83a", "#1fd0ff", "#3b6bff", "#b43bff", "#ff3bb4"];
  let defs = "<defs>";
  const ids = palette.map((c) => {
    const g = id("rt");
    defs += `<linearGradient id="${g}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${shade(c, 0.45)}"/><stop offset="0.55" stop-color="${c}"/><stop offset="1" stop-color="${shade(c, -0.25)}"/></linearGradient>`;
    return g;
  });
  defs += "</defs>";
  let k = 0;
  const spans = [...text].map((ch) => (ch === " " ? " " : `<tspan fill="url(#${ids[k++ % ids.length]})">${ch}</tspan>`)).join("");
  const sw = o.sw || o.size * 0.17;
  const tr = o.rotate ? `transform="rotate(${o.rotate} ${o.x} ${o.y})"` : "";
  const anchor = o.anchor || "start";
  return defs + `<g ${tr}>
    <text x="${o.x + o.size * 0.04}" y="${o.y + o.size * 0.08}" font-family="Luckiest Guy" font-size="${o.size}" text-anchor="${anchor}" fill="#1b0b2e" stroke="#1b0b2e" stroke-width="${sw}" stroke-linejoin="round">${text}</text>
    <text x="${o.x}" y="${o.y}" font-family="Luckiest Guy" font-size="${o.size}" text-anchor="${anchor}" stroke="#fff" stroke-width="${sw + o.size * 0.06}" stroke-linejoin="round" fill="#fff">${text}</text>
    <text x="${o.x}" y="${o.y}" font-family="Luckiest Guy" font-size="${o.size}" text-anchor="${anchor}" stroke="#1b0b2e" stroke-width="${sw}" stroke-linejoin="round" paint-order="stroke">${spans}</text>
  </g>`;
}

// Money-green text ($... /s)
function moneyText(text, o) {
  const g = id("mg");
  return `<defs><linearGradient id="${g}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#d8ff8a"/><stop offset="0.5" stop-color="#5dea3a"/><stop offset="1" stop-color="#1fa82a"/></linearGradient></defs>` +
    title(text, Object.assign({ fill: `url(#${g})`, stroke: "#0b3a12", anchor: "start" }, o));
}

// Big red curved arrow from (x1,y1) to (x2,y2), bending by `bend`.
function curvedArrow(x1, y1, x2, y2, bend, width) {
  const mx = (x1 + x2) / 2, my = (y1 + y2) / 2;
  const dx = x2 - x1, dy = y2 - y1, len = Math.hypot(dx, dy);
  const nx = -dy / len, ny = dx / len;
  const cx = mx + nx * bend, cy = my + ny * bend;
  // direction at the end
  const tx = x2 - cx, ty = y2 - cy, tl = Math.hypot(tx, ty);
  const ux = tx / tl, uy = ty / tl, px = -uy, py = ux;
  const head = width * 2.4;
  const bx = x2 - ux * head * 0.9, by = y2 - uy * head * 0.9;
  const tip = `M${x2 + ux * head * 0.25} ${y2 + uy * head * 0.25} L ${bx + px * head * 0.75} ${by + py * head * 0.75} L ${bx - px * head * 0.75} ${by - py * head * 0.75} Z`;
  const body = `M${x1} ${y1} Q ${cx} ${cy} ${bx} ${by}`;
  return `<g>
    <path d="${body}" stroke="#1b0b2e" stroke-width="${width + 22}" fill="none" stroke-linecap="round" opacity="0.35" transform="translate(6 10)"/>
    <path d="${tip}" fill="#1b0b2e" opacity="0.35" transform="translate(6 10)"/>
    <path d="${body}" stroke="#fff" stroke-width="${width + 22}" fill="none" stroke-linecap="round"/>
    <path d="${tip}" fill="#fff" stroke="#fff" stroke-width="22" stroke-linejoin="round"/>
    <path d="${body}" stroke="#ff2a2a" stroke-width="${width}" fill="none" stroke-linecap="round"/>
    <path d="${tip}" fill="#ff2a2a"/>
  </g>`;
}

function bangs(x, y, size, rot = 12) {
  return title("!!", { x, y, size, fill: "#ff2a2a", stroke: "#fff", sw: size * 0.2, rotate: rot, anchor: "middle" });
}

// An original sleeping security guard, lying face-down (side view, head on the left).
function sleepingGuard(x, y, k) {
  const skin = "#f2b98c", skinD = "#d68f62", shirt = "#27427e", shirtD = "#172b58", pants = "#2e2e38", boot = "#15151b";
  const ol = "#1b0b2e", w = 6 * k;
  const g1 = id("gs"), g2 = id("gp");
  let s = `<defs>
    <linearGradient id="${g1}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${shade(shirt, 0.25)}"/><stop offset="1" stop-color="${shirtD}"/></linearGradient>
    <linearGradient id="${g2}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${shade(pants, 0.25)}"/><stop offset="1" stop-color="${shade(pants, -0.3)}"/></linearGradient>
  </defs>`;
  s += `<g transform="translate(${x} ${y}) scale(${k})">`;
  s += `<ellipse cx="380" cy="215" rx="470" ry="42" fill="#000" opacity="0.25" filter="url(#blur8)"/>`;
  // legs + boots (to the right)
  s += `<path d="M430 105 C 560 95 700 110 790 140 L 790 200 C 700 205 560 200 430 200 Z" fill="url(#${g2})" stroke="${ol}" stroke-width="${w / k}"/>`;
  s += `<path d="M450 150 C 560 150 680 160 780 175" stroke="${shade(pants, -0.4)}" stroke-width="5" fill="none"/>`;
  s += `<path d="M775 118 C 830 110 870 120 880 150 L 880 205 L 770 205 Z" fill="${boot}" stroke="${ol}" stroke-width="${w / k}"/>`;
  s += `<rect x="770" y="196" width="118" height="16" rx="6" fill="#000"/>`;
  // big body (belly on the ground)
  s += `<path d="M150 150 C 150 40 300 20 450 60 C 520 80 540 140 520 200 L 170 205 C 150 195 148 175 150 150 Z" fill="url(#${g1})" stroke="${ol}" stroke-width="${w / k}"/>`;
  s += `<path d="M430 70 C 455 110 460 160 450 205" stroke="#111" stroke-width="22" fill="none"/>`; // belt
  s += `<rect x="440" y="120" width="30" height="34" rx="6" fill="#ffd23a" stroke="${ol}" stroke-width="4" transform="rotate(6 455 137)"/>`; // buckle
  s += `<path d="M300 55 l 22 18 l -6 30 l -16 8 l -16 -8 l -6 -30 Z" fill="#ffd23a" stroke="#7a4a00" stroke-width="5"/>`; // badge
  s += `<path d="M190 70 C 240 50 300 45 350 55" stroke="#fff" stroke-width="10" fill="none" opacity="0.25" stroke-linecap="round"/>`;
  // arm folded under the head
  s += `<path d="M190 120 C 120 130 60 160 30 190 L 40 212 C 90 200 160 190 220 185 Z" fill="${shirtD}" stroke="${ol}" stroke-width="${w / k}"/>`;
  s += `<ellipse cx="30" cy="198" rx="30" ry="18" fill="${skin}" stroke="${ol}" stroke-width="${w / k}"/>`;
  // head resting on the arm
  s += `<circle cx="95" cy="115" r="82" fill="${skin}" stroke="${ol}" stroke-width="${w / k}"/>`;
  s += `<path d="M40 60 C 70 20 150 20 175 80 C 160 70 130 62 100 62 C 75 62 55 68 40 60 Z" fill="#6b3f1f" stroke="${ol}" stroke-width="${w / k}"/>`; // hair
  s += `<ellipse cx="150" cy="118" rx="16" ry="22" fill="${skinD}" stroke="${ol}" stroke-width="5"/>`; // ear
  s += `<path d="M48 110 Q 62 122 78 110" stroke="${ol}" stroke-width="7" fill="none" stroke-linecap="round"/>`; // closed eye
  s += `<path d="M42 100 L 76 94" stroke="#6b3f1f" stroke-width="9" stroke-linecap="round"/>`; // brow
  s += `<ellipse cx="30" cy="135" rx="18" ry="15" fill="${skinD}" stroke="${ol}" stroke-width="5"/>`; // nose
  s += `<path d="M22 150 C 5 150 -12 160 -18 178 C 0 170 20 170 40 165 C 60 172 80 172 96 180 C 90 160 70 150 50 150 Z" fill="#6b3f1f" stroke="${ol}" stroke-width="5"/>`; // mustache
  s += `<circle cx="65" cy="135" r="12" fill="#ff9a9a" opacity="0.5"/>`;
  // cap that fell off
  s += `<g transform="rotate(-14 -40 205)"><path d="M-110 205 C -110 150 -40 130 20 160 L 25 205 Z" fill="${shirt}" stroke="${ol}" stroke-width="${w / k}"/><path d="M-130 205 C -100 196 20 196 45 205 C 20 216 -100 216 -130 205 Z" fill="${shirtD}" stroke="${ol}" stroke-width="5"/><path d="M-50 150 l 12 10 l -3 16 l -9 4 l -9 -4 l -3 -16 Z" fill="#ffd23a" stroke="#7a4a00" stroke-width="4"/></g>`;
  s += `</g>`;
  return s;
}

function sunburst(cx, cy, color, opacity) {
  return rays(cx, cy, 22, 2400, color, opacity, 0.11);
}
