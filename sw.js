/* ═══════════════════════════════════════════════════════════════
   Service Worker for Coach4U PWA
   Caching strategy: Static assets (cache-first), Pages (network-first), API (network-first)
   ═══════════════════════════════════════════════════════════════ */

const CACHE_VERSION = 'coach4u-v0.5.244';
const STATIC_CACHE = CACHE_VERSION + '-static';
const PAGES_CACHE = CACHE_VERSION + '-pages';
const API_CACHE = CACHE_VERSION + '-api';

// Relative paths — resolved against the SW's location at install time.
// Works on GitHub Pages (/yourbusinesscoach/) and any local subpath.
const STATIC_ASSETS = [
  './',
  './index.html',
  './offline.html',
  './manifest.json',
  './favicon.svg',
  './css/style.css',
  './js/active-session.js',
  './js/active-meeting.js',
  './js/active-org.js',
  './js/mobile-keyboard.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => {
      return cache.addAll(STATIC_ASSETS).catch(() => {
        console.log('Some static assets could not be cached');
      });
    }).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (!cacheName.startsWith(CACHE_VERSION)) {
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  if (url.origin !== self.location.origin) return;
  if (request.method !== 'GET') return;

  // HTML pages: network-first with fallback to cache, then offline.html
  if (request.headers.get('accept')?.includes('text/html')) {
    event.respondWith(
      fetch(request)
        .then((response) => {
          if (response.ok) {
            const clone = response.clone();
            caches.open(PAGES_CACHE).then((cache) => cache.put(request, clone));
          }
          return response;
        })
        .catch(() => caches.match(request).then((cached) => cached || caches.match('./offline.html')))
    );
    return;
  }

  // Static assets (JS, CSS, images): cache-first, fallback to network
  event.respondWith(
    caches.match(request).then((cached) => {
      return cached || fetch(request).then((response) => {
        if (response.ok) {
          const clone = response.clone();
          caches.open(STATIC_CACHE).then((cache) => cache.put(request, clone));
        }
        return response;
      }).catch(() => {
        if (request.destination === 'image') {
          return new Response(
            '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">'
            + '<rect fill="#f0f0f0" width="100" height="100"/></svg>',
            { headers: { 'Content-Type': 'image/svg+xml' } }
          );
        }
        return new Response('Resource unavailable offline', { status: 503 });
      });
    })
  );
});
