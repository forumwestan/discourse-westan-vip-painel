// Development only: NODE_PATH=<dev dependencies>/node_modules node scripts/preview.cjs <output directory>
const fs = require('node:fs');
const path = require('node:path');
const sass = require('sass');
const Handlebars = require('handlebars');
const { Preprocessor } = require('content-tag');
const { preprocess } = require('@glimmer/syntax');
const root = path.resolve(__dirname, '..');
const out = process.argv[2];
if (!out) throw new Error('Provide a preview output directory.');
const source = fs.readFileSync(path.join(root, 'assets/javascripts/discourse/components/westan-vip-painel/painel.gjs'), 'utf8');
for (const file of ['painel.gjs', 'admin-catalog.gjs']) {
  const src = fs.readFileSync(path.join(root, 'assets/javascripts/discourse/components/westan-vip-painel', file), 'utf8');
  new Preprocessor().process(src, { filename: file });
  preprocess(src.match(/<template>([\s\S]*)<\/template>/)[1]);
}
const template = source.match(/<template>([\s\S]*)<\/template>/)[1].replace(/=(\{\{[^}]+\}\})/g, '="$1"');
const component = source.split('<template>')[0].replace(/^import .*;$/gm, '').replace(/@(?:tracked|action)\s*/g, '').replace('export default class', 'class') + '}';
const css = ['painel', 'premium'].map(name => sass.compile(path.join(root, `assets/stylesheets/westan-vip-painel/${name}.scss`)).css).join('\n');
fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, 'premium.css'), css);
fs.writeFileSync(path.join(out, 'handlebars.js'), fs.readFileSync(require.resolve('handlebars/dist/handlebars.runtime.min.js')));
const previewJs = `
const params = new URLSearchParams(location.search);
const isPremium = params.get('member') !== 'redeemed';
document.documentElement.dataset.theme = params.get('theme') || 'light';
const svg = text => 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><rect width="96" height="96" rx="48" fill="#e0c9ef"/><text x="48" y="62" text-anchor="middle" fill="#8134ad" font-family="sans-serif" font-size="32">'+text+'</text></svg>');
const model = { can_use: true, is_premium: isPremium, user: { id:1, name:'Igor Freitas', username:'igorfreitas', avatar_url:svg('IF') },
 selection: { theme_id:'none', nickname_color:'purpleglow', verified_enabled:isPremium, custom_title:isPremium?'Westan é minha casa':'' },
 themes: [ {id:'gaga',name:'Gaga',badgeText:'GAGA'}, {id:'cowboy',name:'Cowboy Carter',badgeText:'BEY'}, {id:'sabrina',name:'Sabrina Carpenter',badgeText:'SC'}, {id:'brat',name:'Brat',badgeText:'brat'}, {id:'pop',name:'Pop culture',badgeText:'POP'}, {id:'westan',name:'Westan',badgeText:'westan'}, {id:'premium',name:'Premium',badgeText:'Premium'} ],
 colors: ['red','pink','esmerald','gold','orangepowerfurl','purpleglow','areia','rose','bluegray','hotcamp','blark'].map(value=>({value,name:value,from:null,to:null})) };
class Component { constructor(args) { this.args = args; } }
const htmlSafe = value => new Handlebars.SafeString(value);
const popupAjaxError = error => alert(error.message);
async function ajax(url, options) { model.selection = {...model.selection, ...options.data}; return { selection: model.selection, decoration: {} }; }
${component}
const hub = new WestanVipPainel({model});
if (isPremium && ['custom','appearance'].includes(params.get('section'))) hub.section = params.get('section');
const nativeIf = Handlebars.helpers.if;
Handlebars.registerHelper('if', function(condition, ...args) { const opt=args.at(-1); return opt.fn ? nativeIf.call(this,condition,opt) : condition?args[0]:args[1]; });
Handlebars.registerHelper('on', ()=>'');
Handlebars.registerHelper('dIcon', ()=>htmlSafe('<svg class="d-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="m5 12 4 4L19 6"/></svg>'));
const template = Handlebars.template(${Handlebars.precompile(template)});
function render() { document.querySelector('#preview').innerHTML=template(hub,{allowProtoPropertiesByDefault:true,allowProtoMethodsByDefault:true}).replace(/\\s(?:disabled|selected|required)=\"(?:false)?\"/g,''); }
render();
document.querySelector('#preview').addEventListener('click', event=> { const btn=event.target.closest('button'); if(!btn)return; if(btn.dataset.section){hub.selectSection({currentTarget:btn});render();} else if(btn.dataset.themeId){hub.selectTheme({currentTarget:btn});render();} });
const actions = {'premium-color':'updateColor','premium-verified':'updateVerified','premium-title':'updateTitle','premium-logo':'updateLogo','premium-background':'updateBackground'};
document.querySelector('#preview').addEventListener('input', event=> { const method=actions[event.target.id]; if(!method)return; const id=event.target.id; const start=event.target.selectionStart; const end=event.target.selectionEnd; hub[method](event); render(); const field=document.getElementById(id);field.focus();if(start!==null)field.setSelectionRange(start,end); });
document.querySelector('#preview').addEventListener('submit', async event=> { event.preventDefault();await hub.save(event);hub.feedback='Prévia atualizada. Nada foi enviado ao fórum.';render(); });
`;
fs.writeFileSync(path.join(out, 'preview.js'), previewJs);
fs.writeFileSync(path.join(out, 'index.html'), `<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Ajustes do Premium — prévia local</title><link rel="stylesheet" href="premium.css"><style>:root{--primary:#111;--secondary:#fff}html[data-theme=dark]{--primary:#f2eef7;--secondary:#151319}*{box-sizing:border-box}body{background:var(--secondary);color:var(--primary);margin:0;font:15px/1.5 system-ui,sans-serif}button,input,select{font:inherit}.demo-bar{display:flex;gap:16px;flex-wrap:wrap;padding:12px 24px;border-bottom:1px solid #8883;font-size:12px}.demo-bar a{color:inherit}.demo-bar span{opacity:.6}.d-icon{width:1em;height:1em}.westan-premium-badge-option[data-theme-id=gaga] .westan-premium-badge-art{background:linear-gradient(120deg,#24202b,#874766);color:white}.westan-premium-badge-option[data-theme-id=cowboy] .westan-premium-badge-art{background:linear-gradient(120deg,#1e3261,#9ea5b6);color:white}.westan-premium-badge-option[data-theme-id=brat] .westan-premium-badge-art{background:#b5dd39;color:#111}</style><body><nav class="demo-bar" aria-label="Controles da demonstração"><span>Prévia local · dados demonstrativos</span><a href="?member=paid">Premium</a><a href="?member=redeemed">VIP resgatado</a><a href="?theme=dark&section=appearance">Tema escuro</a><a href="?theme=light&section=appearance">Tema claro</a></nav><div id="preview"></div><script src="handlebars.js"></script><script src="preview.js"></script></body></html>`);
console.log('Compiled both GJS templates and both stylesheets. Interactive preview generated from the real component:', out);
