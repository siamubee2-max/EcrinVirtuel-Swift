// Habille les captures App Store : fond or-sur-sombre + légendes bénéfice, cadre device.
// Rend chaque écran en 1320×2868 (classe 6.9") via Google Chrome headless.
// Usage: node tools/frame-screenshots.mjs
import { writeFileSync, mkdirSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const RAW = resolve(root, "docs/appstore/screenshots");
const OUT = resolve(root, "docs/appstore/screenshots-framed");
const TMP = resolve(root, ".build/frame-html");
mkdirSync(OUT, { recursive: true });
mkdirSync(TMP, { recursive: true });

const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

// Écran → légende (haut) + sous-ligne. Direction : or #D4AF37 sur fond sombre, titre Didot.
// 4e champ optionnel : nom du fichier source à utiliser (sinon = nom de l'écran).
// Slot 1 = vraie génération IA (01-essayage-result), pas la capture mock.
const SHOTS = [
  ["01-essayage",   "Essayez sur votre photo",   "Le bijou sur vous, en quelques secondes — par IA", "01-essayage-result"],
  ["02-garderobe",  "Toute votre garde-robe",    "Numérisez, composez, essayez"],
  ["03-catalogue",  "Un dressing infini",        "Des centaines de pièces à essayer"],
  ["04-communaute", "Progressez en style",       "Défis, badges et niveaux d’élégance"],
  ["05-profil",     "Votre écrin personnel",     "Vos essayages, vos crédits, votre style"],
  ["06-quicktryon", "Essayage rapide",           "Un look en un seul geste"],
];

const W = 1320, H = 2868;

function html(imgPath, title, sub) {
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
  * { margin:0; padding:0; box-sizing:border-box; }
  html,body { width:${W}px; height:${H}px; overflow:hidden; }
  body {
    background:
      radial-gradient(120% 60% at 50% 8%, rgba(212,175,55,0.16), transparent 60%),
      radial-gradient(90% 50% at 50% 100%, rgba(212,175,55,0.10), transparent 55%),
      linear-gradient(180deg, #0b0b10 0%, #14131b 55%, #0b0b10 100%);
    font-family: "Didot","Bodoni 72","Hoefler Text","Georgia",serif;
    color:#f4ead1; display:flex; flex-direction:column; align-items:center;
  }
  .cap { margin-top:150px; text-align:center; padding:0 90px; }
  .title { font-size:118px; line-height:1.06; font-weight:600; letter-spacing:-1px;
    color:#E9C76B; text-shadow:0 2px 30px rgba(212,175,55,0.25); }
  .sub { margin-top:34px; font-size:46px; line-height:1.3; font-weight:400;
    color:#cdbfa3; font-family:"Avenir Next","Helvetica Neue",sans-serif; }
  .frame { margin-top:96px; width:910px; border-radius:62px; padding:14px;
    background:linear-gradient(160deg, rgba(212,175,55,0.55), rgba(212,175,55,0.05));
    box-shadow:0 40px 120px rgba(0,0,0,0.6), 0 0 0 1px rgba(212,175,55,0.25); }
  .frame img { width:100%; display:block; border-radius:50px; }
  </style></head><body>
  <div class="cap"><div class="title">${title}</div><div class="sub">${sub}</div></div>
  <div class="frame"><img src="file://${imgPath}"></div>
  </body></html>`;
}

for (const [name, title, sub, imgOverride] of SHOTS) {
  const raw = resolve(RAW, `${imgOverride ?? name}.png`);
  if (!existsSync(raw)) { console.error("MISSING raw:", raw); continue; }
  const htmlPath = resolve(TMP, `${name}.html`);
  const outPath = resolve(OUT, `${name}-framed.png`);
  writeFileSync(htmlPath, html(raw, title, sub));
  execFileSync(CHROME, [
    "--headless=new", "--disable-gpu", "--hide-scrollbars",
    `--window-size=${W},${H}`, "--force-device-scale-factor=1",
    "--virtual-time-budget=1500",
    `--screenshot=${outPath}`, `file://${htmlPath}`,
  ], { stdio: "ignore" });
  console.log("framed:", outPath);
}
