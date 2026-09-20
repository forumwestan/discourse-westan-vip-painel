const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { Preprocessor } = require('content-tag');
const { preprocess } = require('@glimmer/syntax');
const root = path.resolve(__dirname, '..');
function source(file) {
  const text = fs.readFileSync(path.join(root, file), 'utf8');
  new Preprocessor().process(text, { filename: file });
  preprocess(text.match(/<template>([\s\S]*)<\/template>/)[1]);
  return text;
}
function body(text) {
  return text.split('<template>')[0].replace(/^import .*;$/gm, '').replace(/@(?:tracked|action|service)\s*/g, '').replace('export default class', 'class') + '}';
}
const panel = source('assets/javascripts/discourse/components/westan-vip-painel/painel.gjs');
const banner = source('assets/javascripts/discourse/connectors/discovery-above/westan-premium-banner.gjs');
class Component { constructor(args) { this.args = args; } }
let submitted;
const Panel = new Function('Component', 'htmlSafe', 'ajax', 'popupAjaxError', 'window', 'CustomEvent', body(panel) + ';return WestanVipPainel;')(
  Component, value => value, async (_url, options) => { submitted = options.data; return {selection:{theme_id:'none'},decoration:{}}; }, error => { throw error; }, {dispatchEvent(){}}, class {}
);
const Banner = new Function('Component','getURL',body(banner) + ';return WestanPremiumBanner;')(Component, path => path);
(async () => {
  const ui = new Panel({model:{can_use:true,is_premium:false,user:{name:'Test'},selection:{nickname_color:'gold'},colors:[{value:'gold',name:'gold'},{value:'purpleglow',name:'purpleglow'}]}});
  assert.equal(ui.pageTitle,'Ajuste do VIP');
  assert.match(ui.nicknameStyle,/#ffca3a/);
  ui.updateColor({target:{value:'purpleglow'}});
  assert.match(ui.nicknameStyle,/#cfbaf0/);
  assert.match(ui.nicknameClass,/vip-color-purpleglow/);
  ui.updateColor({target:{value:'orangepowerfurl'}});
  assert.match(ui.nicknameClass,/vip-color-oragenpowerfurl/);
  ui.updateColor({target:{value:''}});
  assert.equal(ui.nicknameStyle,'');
  assert.equal(ui.nicknameClass,'premium-preview-nickname');
  ui.nicknameColor='obsolete'; ui.colorChanged=false; ui.args.model.is_premium=true;
  assert.equal(ui.colorRows[0].disabled,true);
  await ui.save({preventDefault(){}});
  assert.equal(Object.hasOwn(submitted,'nickname_color'),false);
  ui.updateColor({target:{value:'gold'}});
  await ui.save({preventDefault(){}});
  assert.equal(submitted.nickname_color,'gold');
  ui.savedSelection={custom_logo_url:'',custom_background_url:'https://example.org/bg.png'};
  assert.ok(ui.badgeRows.some(row=>row.id==='custom'));
  assert.doesNotMatch(panel.match(/<input id="premium-logo"[^>]*>/)[0],/required/);
  for(const getter of ['isBadges','isCustom','isAppearance']) assert.ok(panel.includes(`aria-pressed={{if this.${getter} "true" "false"}}`));
  const home = new Banner({outletArgs:{}});
  home.siteSettings={westan_vip_painel_enabled:true};
  home.currentUser={westan_vip_painel_premium:true};
  for(const url of ['/','/?page=1','/latest','/latest?order=activity']) {home.router={currentURL:url};assert.equal(home.visible,true,url);}
  for(const url of ['/top','/new','/c/music/5','/t/test/1','/vip-painel']) {home.router={currentURL:url};assert.equal(home.visible,false,url);}
  home.router={currentURL:'/'};
  home.currentUser=null; assert.equal(home.visible,false);
  home.currentUser={westan_vip_painel_premium:false}; assert.equal(home.visible,false);
  home.currentUser={westan_vip_painel_premium:true};home.args.outletArgs.category={id:5};assert.equal(home.visible,false);
  home.args.outletArgs={};home.siteSettings.westan_vip_painel_enabled=false;assert.equal(home.visible,false);
  console.log('PASS: original color preview, saved preferences, active tabs, Premium-only home banner; GJS compiled.');
})().catch(error=>{console.error(error);process.exitCode=1;});
