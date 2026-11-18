// Service worker: permite instalar o app e abrir mais rápido.
// Dados (clientes, OS, preços) sempre vêm do Supabase, nunca do cache.
const VERSAO = 'mpf-v3';
const BASE = ['./', 'index.html', 'manifest.json', 'logo.png', 'icon-192.png', 'icon-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(VERSAO).then(c => c.addAll(BASE)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== VERSAO).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const req = e.request, url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== location.origin) return;   // Supabase e CDNs: direto da rede
  if (req.mode === 'navigate' || url.pathname.endsWith('.html') || url.pathname === '/') {
    // página: sempre tenta a versão nova; sem internet, usa a última salva
    e.respondWith(fetch(req).then(r => { const c = r.clone(); caches.open(VERSAO).then(x => x.put(req, c)); return r; })
      .catch(() => caches.match(req).then(r => r || caches.match('index.html'))));
    return;
  }
  // arquivos fixos (moto 3D, logo, ícones): usa o salvo e atualiza em segundo plano
  e.respondWith(caches.match(req).then(hit => {
    const rede = fetch(req).then(r => { if (r.ok) { const c = r.clone(); caches.open(VERSAO).then(x => x.put(req, c)); } return r; });
    return hit || rede;
  }));
});
