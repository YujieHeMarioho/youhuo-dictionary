'use strict';
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = { innerHTML: '' };
const messages = [];
let allowImport = false;
const document = {
  body: { classList: { toggle() {} }, append() {} },
  querySelector(selector) { return selector === '#app' ? root : null; },
  querySelectorAll() { return []; },
  getElementById() { return null; },
  createElement() { return { remove() {} }; }
};
const context = vm.createContext({
  document,
  window: { webkit: { messageHandlers: { native: { postMessage(message) { messages.push(message); } } } } },
  crypto: require('node:crypto').webcrypto,
  setTimeout() {},
  confirm() { return allowImport; }
});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../src/app.js'), 'utf8'), context);
const run = code => vm.runInContext(code, context);
const receive = (event, payload) => context.window.receiveNative(event, payload);
assert.equal(run('validState(state)'), true);
run("lookup('old'); lookup('hello')");
const lookupId = messages.filter(m => m.action === 'lookup').at(-1).id;
receive('lookup', { id: 'stale', query: 'old', entries: [{ word: 'wrong', translation: 'wrong' }] });
assert.equal(run('busy'), true);
assert.equal(run('entries.length'), 0);
receive('lookup', { id: lookupId, query: 'hello', entries: [{ word: 'hello', translation: '你好\\n您好', definition: 'greeting\\nwelcome' }] });
assert.equal(run('busy'), false);
assert.equal(run('entries[0].translation'), '你好\n您好');
assert.equal(run('entries[0].definition'), 'greeting\nwelcome');
assert.ok(root.innerHTML.includes('你好\n您好'));
run("lookup('<img src=x onerror=alert(1)>')");
assert.ok(root.innerHTML.includes('&lt;img'));
assert.ok(!root.innerHTML.includes('<img src=x'));
receive('error', { id: messages.filter(m => m.action === 'lookup').at(-1).id, message: '词库不可用' });
assert.equal(run('busy'), false);
run("translationId='translation-1'; translated='等待翻译'; aiId='ai-1'; aiResult='等待 AI'");
receive('translation', { id: 'stale', text: 'incorrect' });
assert.equal(run('translated'), '等待翻译');
receive('error', { id: 'translation-1', message: '语言包未下载' });
assert.equal(run('translated'), '语言包未下载');
receive('ai', { id: 'stale', text: 'incorrect' });
assert.equal(run('aiResult'), '等待 AI');
receive('error', { id: 'ai-1', message: 'AI 未配置' });
assert.equal(run('aiResult'), 'AI 未配置');
assert.equal(run(`validState({...state,words:[{id:'bad" onclick="x',word:'x',translation:'x',folder:'默认单词本'}]})`), false);
assert.equal(run(`validState({...state,documents:[{id:'<script>',name:'x',text:'x'}]})`), false);
assert.equal(run(`validState({...state,history:[{id:'valid',type:'unknown',text:'x',at:new Date().toISOString()}]})`), false);
assert.equal(run(`validState({...state,history:[{id:'valid',type:'lookup',text:'x',at:'not-a-date'}]})`), false);
assert.equal(run(`validState({...state,settings:{dark:'false'}})`), false);
const backup = JSON.parse(run(`JSON.stringify({...state,words:[{id:'safe-id',word:'test',translation:'测试',folder:'默认单词本'}]})`));
assert.equal(run(`validState(${JSON.stringify(backup)})`), true);
receive('importData', { state: backup });
assert.equal(run('state.words.length'), 0, 'Declining replacement must retain original data');
allowImport = true;
receive('importData', { state: backup });
assert.equal(run('state.words.length'), 1);
assert.equal(run('state.words[0].note'), '', 'Missing optional note normalizes on import');
console.log('PASS: stale replies, corpus newlines, HTML escaping, backup validation and confirmation, optional notes, async failure recovery');
