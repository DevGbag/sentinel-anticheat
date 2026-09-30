// Maintainer tool: re-embeds branding/shield.png into html/branding.js and
// updates the expected hash in server/branding.lua.
// Run from the resource folder:  node tools/build-branding.js
const fs = require('fs');
const b64 = fs.readFileSync('branding/shield.png').toString('base64');
const js = `// Sentinel Anticheat branding. Generated — do not edit.
// This file is integrity-checked by the server (server/branding.lua);
// a modified copy is reported as an unofficial build.
(function () {
  var LOGO = 'data:image/png;base64,${b64}';
  var el = document.getElementById('brand');
  if (!el) return;
  el.innerHTML =
    '<img class="brand-mark" alt="" src="' + LOGO + '">' +
    '<div class="brand-text"><span class="brand-name">SENTINEL</span><span class="brand-sub">Anticheat</span></div>';
})();
`;
fs.writeFileSync('html/branding.js', js);
function joaat(s) {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = (h + s.charCodeAt(i)) >>> 0;
    h = (h + (h << 10)) >>> 0;
    h = (h ^ (h >>> 6)) >>> 0;
  }
  h = (h + (h << 3)) >>> 0;
  h = (h ^ (h >>> 11)) >>> 0;
  h = (h + (h << 15)) >>> 0;
  return h;
}
const norm = (f) => fs.readFileSync(f, 'latin1').replace(/\r/g, '');
const hash = joaat(norm('html/branding.js'));
const lua = fs.readFileSync('server/branding.lua', 'utf8').replace(/EXPECTED_BRANDING_HASH = d+/, 'EXPECTED_BRANDING_HASH = ' + hash);
fs.writeFileSync('server/branding.lua', lua);
console.log('branding.js regenerated, hash ' + hash + ' written to server/branding.lua');
