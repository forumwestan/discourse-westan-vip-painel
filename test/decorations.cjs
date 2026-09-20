// Run with NODE_PATH pointing at a local jsdom installation.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { JSDOM } = require('jsdom');
const source = fs.readFileSync(require('node:path').join(__dirname, '../assets/javascripts/discourse/api-initializers/westan-vip-painel.js'), 'utf8').replace(/^import .*;$/gm, '').split('export default apiInitializer')[0];
const dom = new JSDOM('<main></main>', { url: 'https://example.org/u/Blair/summary' });
const context = vm.createContext({ document: dom.window.document, window: dom.window });
vm.runInContext(source, context);
const doc = dom.window.document;
const data = { id: 12, username: 'Blair', name: 'Blair', verified: true, nickname_style: { from: '#D97706', to: '#FDE68A' }, custom_title: 'Premium', badge_enabled: true, theme: { id: 'custom', name: 'Meu badge', logoUrl: 'https://example.org/logo.png' } };
doc.body.innerHTML = '<article class="topic-post"><div class="topic-meta-data"><div class="names"><span class="username"><i class="westan-vip-verified"></i><a>Blair</a><i class="westan-vip-verified"></i></span></div></div><div class="post-infos"></div></article>';
const post = doc.querySelector('article');
for (let i = 0; i < 10; i++) { context.decoratePost(post, data); }
assert.equal(post.querySelectorAll('.westan-vip-verified').length, 1);
assert(post.querySelector('a').nextElementSibling.matches('.westan-vip-verified'));
assert(post.querySelector('a').classList.contains('westan-vip-nickname'));
assert.equal(post.querySelectorAll('.westan-vip-post-badge').length, 1);
post.querySelector('.westan-vip-verified').click();
assert.equal(doc.querySelector('.westan-premium-tooltip').parentElement, doc.body);
assert.equal(doc.querySelector('.westan-premium-tooltip').textContent, 'Membro Premium Verificado');
context.decoratePost(post, { ...data, verified: false, theme: null, badge_enabled: false, custom_title: '', nickname_style: null });
assert.equal(post.querySelectorAll('.westan-vip-verified,.westan-vip-post-badge,.westan-vip-user-title,.westan-vip-nickname').length, 0);
doc.body.innerHTML = '<div class="user-card"><div class="names"><span class="username"><a href="/u/Blair">Blair</a></span></div></div>';
const card = doc.querySelector('.user-card');
for (let i = 0; i < 5; i++) { context.decorateUserCard(card, data); }
assert.equal(card.querySelectorAll('.westan-vip-verified').length, 1);
assert(card.querySelector('a').nextElementSibling.matches('.westan-vip-verified'));
context.decorateUserCard(card, { ...data, verified: false, custom_title: '' });
assert.equal(card.querySelectorAll('.westan-vip-verified').length, 0);
doc.body.innerHTML = '<main><div class="user-main"><div class="user-profile-names"><h1 class="full-name">Blair</h1></div></div></main>';
for (let i = 0; i < 5; i++) { context.decorateProfile(data); }
assert.equal(doc.querySelectorAll('.westan-vip-verified').length, 1);
assert.equal(doc.querySelectorAll('.westan-premium-name-label').length, 1);
assert(doc.querySelector('.westan-premium-name-label').nextElementSibling.matches('.westan-vip-verified'));
context.decorateProfile({ ...data, verified: false, nickname_style: null, custom_title: '' });
assert.equal(doc.querySelectorAll('.westan-vip-verified,.westan-vip-user-title,.westan-vip-nickname').length, 0);
console.log('Decoration regressions passed: one seal after name, color, badge, profile, user card, revocation and tooltip outside clipping containers.');
