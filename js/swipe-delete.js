/* Swipe-to-delete helper (v0.5.222).
   Opt-in via the .swipeable class on a row container. Touch-only — desktop
   keeps the existing affordances (click X button, click checkbox, etc.).

   Usage:
     <div class="todo-row swipeable" data-id="..."> ... </div>
   The row needs a child element with class .swipe-delete that the helper
   will attach the actual delete click handler to — OR the row already has
   a regular delete button (e.g. .todo-del) that the helper will trigger
   when the swipe completes fully.

   How it works:
     - touchstart: record the start x + y
     - touchmove: if the gesture is mostly horizontal AND going left, translate
       the row's content. Reveal a red "Delete" backdrop behind it.
     - touchend: if dragged past 50% of row width, trigger the delete handler;
       otherwise snap back to 0.
     - tap (no significant drag): do nothing — let the regular click handler fire.
*/
(function () {
  'use strict';
  const ATTACHED = Symbol('swipeAttached');
  const SWIPE_THRESHOLD = 80;          // px to snap to "open" state
  const COMMIT_THRESHOLD = 0.5;        // fraction of row width to auto-delete
  const HORIZONTAL_LOCK = 12;          // px before we commit to a horizontal gesture
  const STYLE_ID = 'swipeDeleteStyle';

  function injectStyle() {
    if (document.getElementById(STYLE_ID)) return;
    const s = document.createElement('style');
    s.id = STYLE_ID;
    s.textContent = `
      .swipeable {
        position: relative;
        overflow: hidden;
        touch-action: pan-y;
      }
      .swipeable > .swipe-content {
        position: relative;
        background: white;
        transition: transform .18s ease;
        will-change: transform;
        z-index: 1;
      }
      .swipeable > .swipe-backdrop {
        position: absolute;
        top: 0; bottom: 0; right: 0;
        width: 100%;
        background: linear-gradient(90deg, transparent 0%, #fee2e2 30%, #ef4444 100%);
        display: flex; align-items: center; justify-content: flex-end;
        padding-right: 20px;
        font-family: inherit; font-size: 0.85rem; font-weight: 800;
        color: white; letter-spacing: 0.5px;
        pointer-events: none;
        z-index: 0;
      }
      .swipeable.swiping > .swipe-content { transition: none; }
    `;
    document.head.appendChild(s);
  }

  function wrapContent(row) {
    if (row[ATTACHED]) return;
    row[ATTACHED] = true;
    // Move all children into a .swipe-content wrapper, and prepend a .swipe-backdrop.
    const content = document.createElement('div');
    content.className = 'swipe-content';
    while (row.firstChild) content.appendChild(row.firstChild);
    const backdrop = document.createElement('div');
    backdrop.className = 'swipe-backdrop';
    backdrop.textContent = 'Delete';
    row.appendChild(backdrop);
    row.appendChild(content);
    attachHandlers(row, content);
  }

  function attachHandlers(row, content) {
    let startX = 0, startY = 0, currentDX = 0, swiping = false, decided = false, horizontal = false;
    let rowWidth = 0;

    function reset(snap) {
      swiping = false; decided = false; horizontal = false;
      row.classList.remove('swiping');
      content.style.transform = snap ? '' : 'translateX(0)';
    }

    function findDeleteHandler() {
      const explicit = row.querySelector('.swipe-delete');
      if (explicit) return () => explicit.click();
      const todoDel = row.querySelector('.todo-del');
      if (todoDel) return () => todoDel.click();
      return null;
    }

    row.addEventListener('touchstart', (e) => {
      if (e.touches.length !== 1) return;
      const t = e.touches[0];
      startX = t.clientX; startY = t.clientY; currentDX = 0;
      swiping = true; decided = false; horizontal = false;
      rowWidth = row.offsetWidth || 320;
      row.classList.add('swiping');
    }, { passive: true });

    row.addEventListener('touchmove', (e) => {
      if (!swiping) return;
      const t = e.touches[0];
      const dx = t.clientX - startX;
      const dy = t.clientY - startY;
      if (!decided) {
        if (Math.abs(dx) < HORIZONTAL_LOCK && Math.abs(dy) < HORIZONTAL_LOCK) return;
        horizontal = Math.abs(dx) > Math.abs(dy);
        decided = true;
        if (!horizontal) { reset(true); return; }
      }
      if (!horizontal) return;
      // Only allow left swipes (negative dx); clamp positive.
      currentDX = Math.min(0, dx);
      content.style.transform = 'translateX(' + currentDX + 'px)';
    }, { passive: true });

    row.addEventListener('touchend', () => {
      if (!swiping) return;
      const shouldCommit = horizontal && Math.abs(currentDX) > rowWidth * COMMIT_THRESHOLD;
      if (shouldCommit) {
        // Animate out then trigger delete
        content.style.transform = 'translateX(-100%)';
        const handler = findDeleteHandler();
        setTimeout(() => {
          if (handler) handler();
          reset(true);
        }, 180);
      } else if (horizontal && Math.abs(currentDX) > SWIPE_THRESHOLD) {
        // Snap to open state (-SWIPE_THRESHOLD); tap anywhere snaps back
        content.style.transform = 'translateX(-' + SWIPE_THRESHOLD + 'px)';
        row.classList.remove('swiping');
        const close = () => {
          content.style.transform = 'translateX(0)';
          document.removeEventListener('touchstart', close, true);
        };
        setTimeout(() => document.addEventListener('touchstart', close, true), 0);
      } else {
        reset();
      }
    }, { passive: true });

    row.addEventListener('touchcancel', () => reset(), { passive: true });
  }

  function scan(root) {
    (root || document).querySelectorAll('.swipeable').forEach(wrapContent);
  }

  // Auto-attach to anything matching .swipeable on load + on later DOM updates.
  function init() {
    injectStyle();
    scan(document);
    const observer = new MutationObserver((mutations) => {
      for (const m of mutations) {
        m.addedNodes.forEach(n => {
          if (n.nodeType !== 1) return;
          if (n.classList && n.classList.contains('swipeable')) wrapContent(n);
          if (n.querySelectorAll) n.querySelectorAll('.swipeable').forEach(wrapContent);
        });
      }
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  window.swipeDelete = { scan };
})();
