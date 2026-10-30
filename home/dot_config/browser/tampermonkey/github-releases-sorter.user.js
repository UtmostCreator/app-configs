// ==UserScript==
// @name         GitHub: Releases Sorter & Author Highlighter
// @namespace    https://tampermonkey.net/
// @version      2026-10-29.1
// @description  A draggable, toggleable overlay for GitHub release pages. Turn it on to re-order every release's "What's Changed" list by author or by PR id, colour-code each contributor (no hardcoded owners), and render your own entries in a bolder font. Designed as a non-conflicting overlay you can grab by its dotted handle and move anywhere; on/off state, sort mode and panel position persist.
// @author       UtmostCreator
// @match        https://github.com/*
// @match        https://*.github.com/*
// @grant        GM_getValue
// @grant        GM_setValue
// @run-at       document-start
// ==/UserScript==

(function () {
    'use strict';

    /**
   * Overview
   * --------
   * GitHub release pages render each release's "What's Changed" section as a
   * <ul> of <li> entries inside `.markdown-body`. Every entry typically ends
   * with:
   *     ... by <a class="user-mention" href="https://github.com/<login>">@login</a>
   *     in <a class="issue-link" href=".../pull/<id>">#<id></a>
   *
   * This script lets you, from a draggable floating overlay:
   *   - Toggle the feature on/off.
   *   - Re-order the entries in every such list, either grouped by author
   *     (alphabetical) or by PR id (numeric).
   *   - Colour-code each distinct contributor. Colours are derived from the
   *     login string (a stable hash) so NO owners are hardcoded -- every login
   *     discovered on the page gets its own consistent colour.
   *   - Render entries authored by the currently signed-in user ("you") in a
   *     bolder font. "You" is detected from GitHub's own DOM, so that too is
   *     not hardcoded.
   *
   * It is intentionally independent from any other userscript (the date
   * formatter): unique element ids, storage keys and data attributes, and a
   * default position on the LEFT so the two overlays don't overlap.
   *
   * Non-destructive: turning the feature OFF restores the original DOM order
   * and removes all styling we added.
   */

    // ---------- Storage keys & defaults (namespaced "ghrs:") ----------

    if (!window.location.pathname.endsWith('/releases')) {
        throw new Error('Script terminated: not on /releases page');
    }

    const STORAGE_KEYS = {
        enabled: 'ghrs:enabled',
        sortMode: 'ghrs:sortMode',
        panelOpen: 'ghrs:panelOpen',
        posX: 'ghrs:posX',
        posY: 'ghrs:posY',
    };

    const SORT_MODES = {
        USER: 'user',                 // grouped by author, A-Z
        USER_OWNER_FIRST: 'user-me',  // grouped by author, your own entries first
        PR_ASC: 'pr-asc',             // by PR id, ascending
        PR_DESC: 'pr-desc',           // by PR id, descending
    };

    const DEFAULTS = {
        enabled: false,
        sortMode: SORT_MODES.USER,
        panelOpen: true,
        posX: null, // null => use CSS default (left/top)
        posY: null,
    };

    // ---------- DOM markers ----------
    const PROCESSED_ATTR = 'data-ghrs-processed'; // marks a <ul> we reordered
    const ORDER_ATTR = 'data-ghrs-order';         // original index stored on <li>
    const COLORED_ATTR = 'data-ghrs-colored';     // marks a styled mention link
    const ME_ATTR = 'data-ghrs-me';               // marks "your" entries

    // ---------- Persistent storage ----------
    const hasGM =
          typeof GM_getValue === 'function' && typeof GM_setValue === 'function';

    function readStored(key, fallback) {
        try {
            if (hasGM) {
                const v = GM_getValue(key, undefined);
                return v === undefined ? fallback : v;
            }
            const raw = localStorage.getItem(key);
            return raw === null ? fallback : JSON.parse(raw);
        } catch (_) {
            return fallback;
        }
    }

    function writeStored(key, value) {
        try {
            if (hasGM) {
                GM_setValue(key, value);
            } else {
                localStorage.setItem(key, JSON.stringify(value));
            }
        } catch (_) {
            /* storage unavailable; ignore */
        }
    }

    const state = {
        enabled: readStored(STORAGE_KEYS.enabled, DEFAULTS.enabled),
        sortMode: readStored(STORAGE_KEYS.sortMode, DEFAULTS.sortMode),
        panelOpen: readStored(STORAGE_KEYS.panelOpen, DEFAULTS.panelOpen),
        posX: readStored(STORAGE_KEYS.posX, DEFAULTS.posX),
        posY: readStored(STORAGE_KEYS.posY, DEFAULTS.posY),
    };

    function isEnabled() {
        return state.enabled;
    }

    // ---------- "You" detection (not hardcoded) ----------
    // GitHub exposes the signed-in user in a few places. We try them in order.
    let cachedMe = undefined;
    function getCurrentUser() {
        if (cachedMe !== undefined) return cachedMe;
        let login = '';
        try {
            const meta = document.querySelector('meta[name="user-login"]');
            if (meta && meta.content) login = meta.content.trim();
            if (!login) {
                const a = document.querySelector(
                    'a[href^="/"] img.avatar-user[alt^="@"]'
                );
                if (a && a.alt) login = a.alt.replace(/^@/, '').trim();
            }
            if (!login) {
                const summaryImg = document.querySelector(
                    'summary .avatar-user[alt^="@"]'
                );
                if (summaryImg && summaryImg.alt) {
                    login = summaryImg.alt.replace(/^@/, '').trim();
                }
            }
        } catch (_) {
            /* ignore */
        }
        cachedMe = login.toLowerCase();
        return cachedMe;
    }

    // ---------- Colour derivation (unique per user, no repeats) ----------
    // Strategy: scan EVERY non-owner login on the page first, then deterministically
    // assign each one a colour drawn from evenly spread points on the HSL wheel so
    // that no two distinct users ever share (or sit too close to) the same colour.
    // The owner is intentionally excluded so GitHub's default colour is preserved.
    function hashString(str) {
        let h = 5381;
        for (let i = 0; i < str.length; i++) {
            h = (h * 33) ^ str.charCodeAt(i);
        }
        return h >>> 0;
    }

    // Registry mapping login -> assigned colour string. Rebuilt on each scan.
    let colorRegistry = new Map();

    function resetColorRegistry() {
        colorRegistry = new Map();
    }

    // Build a list of N visually distinct HSL colours. Hues are spread evenly
    // across the wheel; saturation/lightness alternate slightly so even users that
    // land on near-identical hues (only when N is large) remain distinguishable.
    function buildDistinctColors(n) {
        const colors = [];
        if (n <= 0) return colors;
        // Use the golden-angle for a good spread, but anchor to an even division so
        // small N sets are maximally separated and never collide.
        const step = 360 / n;
        for (let i = 0; i < n; i++) {
            const hue = Math.round((i * step) % 360);
            // Two saturation and two lightness tiers, cycled, to add separation
            // between consecutive entries beyond hue alone.
            const sat = 70 + (i % 2) * 12; // 70 or 82
            const light = 58 + (Math.floor(i / 2) % 2) * 10; // 58 or 68
            colors.push(`hsl(${hue} ${sat}% ${light}%)`);
        }
        return colors;
    }

    // Given the full set of non-owner logins, assign every one a unique colour.
    // Deterministic: logins are sorted (by stable hash, then name) before the
    // evenly-spread palette is dealt out, so the same page always looks the same.
    function assignColors(logins) {
        resetColorRegistry();
        const unique = Array.from(new Set(logins.filter(Boolean)));
        unique.sort((a, b) => {
            const ha = hashString(a);
            const hb = hashString(b);
            if (ha !== hb) return ha - hb;
            return a < b ? -1 : a > b ? 1 : 0;
        });
        const palette = buildDistinctColors(unique.length);
        unique.forEach((login, i) => {
            colorRegistry.set(login, palette[i]);
        });
    }

    // Look up a previously assigned colour. Returns null if the login has no
    // colour (e.g. the owner, who is deliberately left at GitHub's default).
    function colorForLogin(login) {
        return colorRegistry.get(login.toLowerCase()) || null;
    }

    // ---------- Release list parsing ----------
    // A "release list" is a <ul> inside a `.markdown-body` whose <li>s contain a
    // user-mention link. We reorder those <li>s.
    function findReleaseLists() {
        const lists = [];
        document
            .querySelectorAll('.markdown-body ul')
            .forEach((ul) => {
            if (ul.querySelector(':scope > li a.user-mention')) {
                lists.push(ul);
            }
        });
        return lists;
    }

    function getMention(li) {
        return li.querySelector('a.user-mention');
    }

    function getLogin(li) {
        const a = getMention(li);
        if (!a) return '';
        // Prefer the href (canonical), fall back to the @text.
        const href = a.getAttribute('href') || '';
        const m = href.match(/github\.com\/([^/?#]+)/i);
        if (m) return decodeURIComponent(m[1]).toLowerCase();
        return (a.textContent || '').replace(/^@/, '').trim().toLowerCase();
    }

    function getPrId(li) {
        // The "in #NNN" link is an issue-link to /pull/<id> or /issues/<id>.
        const links = li.querySelectorAll('a.issue-link, a[href*="/pull/"], a[href*="/issues/"]');
        let best = NaN;
        links.forEach((a) => {
            const href = a.getAttribute('href') || '';
            const m = href.match(/\/(?:pull|issues)\/(\d+)/);
            if (m) {
                const n = parseInt(m[1], 10);
                if (!isNaN(n)) best = isNaN(best) ? n : Math.max(best, n);
            }
            if (isNaN(best)) {
                const t = (a.textContent || '').match(/#(\d+)/);
                if (t) best = parseInt(t[1], 10);
            }
        });
        return best;
    }

    // ---------- Apply / reorder ----------
    function ensureOriginalOrder(ul) {
        const items = Array.from(ul.children).filter((c) => c.tagName === 'LI');
        items.forEach((li, idx) => {
            if (!li.hasAttribute(ORDER_ATTR)) {
                li.setAttribute(ORDER_ATTR, String(idx));
            }
        });
        return items;
    }

    function sortItems(items, mode) {
        const decorated = items.map((li) => ({
            li,
            login: getLogin(li),
            pr: getPrId(li),
            orig: parseInt(li.getAttribute(ORDER_ATTR) || '0', 10),
        }));

        if (mode === SORT_MODES.PR_ASC || mode === SORT_MODES.PR_DESC) {
            decorated.sort((a, b) => {
                const av = isNaN(a.pr) ? Infinity : a.pr;
                const bv = isNaN(b.pr) ? Infinity : b.pr;
                if (av !== bv) {
                    return mode === SORT_MODES.PR_ASC ? av - bv : bv - av;
                }
                return a.orig - b.orig;
            });
        } else {
            // By user: group by login alphabetically, keep original order within.
            // In "owner first" mode, your own login is hoisted to the top; the rest
            // stay grouped alphabetically.
            const ownerFirst = mode === SORT_MODES.USER_OWNER_FIRST;
            const me = ownerFirst ? getCurrentUser() : '';
            decorated.sort((a, b) => {
                if (ownerFirst && me) {
                    const aMe = a.login === me;
                    const bMe = b.login === me;
                    if (aMe !== bMe) return aMe ? -1 : 1;
                }
                if (a.login !== b.login) return a.login < b.login ? -1 : 1;
                return a.orig - b.orig;
            });
        }
        return decorated.map((d) => d.li);
    }

    function styleMentions(ul) {
        const me = getCurrentUser();
        ul.querySelectorAll('li a.user-mention').forEach((a) => {
            const href = a.getAttribute('href') || '';
            const m = href.match(/github\.com\/([^/?#]+)/i);
            const login = (m
                           ? decodeURIComponent(m[1])
                           : (a.textContent || '').replace(/^@/, '')
                          ).toLowerCase();
            if (!login) return;

            const li = a.closest('li');
            const isOwner = me && login === me;

            if (isOwner) {
                // Owner: leave GitHub's default colour untouched. Clear any colour we
                // may have applied previously, but still mark the row as "me".
                a.style.removeProperty('color');
                a.style.removeProperty('font-weight');
                a.removeAttribute(COLORED_ATTR);
                if (li) {
                    li.setAttribute(ME_ATTR, '1');
                    li.style.setProperty('font-weight', '700', 'important');
                }
                return;
            }

            const color = colorForLogin(login);
            if (color) {
                a.style.setProperty('color', color, 'important');
                a.style.setProperty('font-weight', '600', 'important');
                a.setAttribute(COLORED_ATTR, '1');
            }

            if (li) {
                li.removeAttribute(ME_ATTR);
                li.style.removeProperty('font-weight');
            }
        });
    }

    function applyToList(ul) {
        const items = ensureOriginalOrder(ul);
        if (items.length === 0) return;

        const sorted = sortItems(items, state.sortMode);
        let nextItem = ul.firstElementChild;
        for (const li of sorted) {
            if (li !== nextItem) ul.insertBefore(li, nextItem);
            nextItem = li.nextElementSibling;
        }

        styleMentions(ul);
        ul.setAttribute(PROCESSED_ATTR, '1');
    }

    // Walk every release list and collect all distinct non-owner logins so we can
    // assign each a unique colour before any styling happens.
    function scanAllLogins(lists) {
        const me = getCurrentUser();
        const logins = [];
        lists.forEach((ul) => {
            ul.querySelectorAll('li a.user-mention').forEach((a) => {
                const href = a.getAttribute('href') || '';
                const m = href.match(/github\.com\/([^/?#]+)/i);
                const login = (m
                               ? decodeURIComponent(m[1])
                               : (a.textContent || '').replace(/^@/, '')
                              ).toLowerCase();
                if (!login) return;
                if (me && login === me) return; // owner keeps GitHub's default colour
                logins.push(login);
            });
        });
        return logins;
    }

    function applyAll() {
        if (!isEnabled()) return;
        const lists = findReleaseLists();
        // Phase 1: scan every user across all lists and assign unique colours.
        assignColors(scanAllLogins(lists));
        // Phase 2: reorder + apply the assigned colours.
        lists.forEach((ul) => applyToList(ul));
    }

    function restoreList(ul) {
        const items = Array.from(ul.children).filter((c) => c.tagName === 'LI');
        items
            .slice()
            .sort((a, b) => {
            const ao = parseInt(a.getAttribute(ORDER_ATTR) || '0', 10);
            const bo = parseInt(b.getAttribute(ORDER_ATTR) || '0', 10);
            return ao - bo;
        })
            .forEach((li) => ul.appendChild(li));

        items.forEach((li) => {
            li.removeAttribute(ORDER_ATTR);
            li.removeAttribute(ME_ATTR);
            li.style.removeProperty('font-weight');
        });

        ul.querySelectorAll(`a[${COLORED_ATTR}="1"]`).forEach((a) => {
            a.style.removeProperty('color');
            a.style.removeProperty('font-weight');
            a.removeAttribute(COLORED_ATTR);
        });

        ul.removeAttribute(PROCESSED_ATTR);
    }

    function restoreAll() {
        document
            .querySelectorAll(`ul[${PROCESSED_ATTR}="1"]`)
            .forEach((ul) => restoreList(ul));
    }

    // Re-run after a sort-mode change: restore then re-apply for correctness.
    function reapplyAll() {
        restoreAll();
        if (isEnabled()) applyAll();
    }

    // ---------- Styles ----------
    const STYLE_ID = 'ghrs-style';
    const STYLE = `
    #ghrs-overlay {
      position: fixed;
      /* Reset the UA popover defaults (inset:0; margin:auto; width/height:auto)
         so our explicit top/left placement controls position instead of the
         popover being centered. */
      inset: auto;
      margin: 0;
      top: 16px;
      left: 16px;
      right: auto;
      bottom: auto;
      width: max-content;
      height: auto;
      max-width: none;
      max-height: none;
      overflow: visible;
      z-index: 2147483646;
      font: 12px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: #e6edf3;
      background: #161b22;
      border: 1px solid #30363d;
      border-radius: 8px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
      user-select: none;
      min-width: 190px;
    }
    /* Safety net: a [popover] element is display:none until shown. If for any
       reason showPopover() did not run, force it visible so the panel never
       disappears. (When it IS shown via the API this is a harmless no-op.) */
    #ghrs-overlay[popover] {
      display: block;
    }
    #ghrs-header {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 6px 8px;
    }
    /* Dotted drag handle: hold and move the panel. */
    #ghrs-handle {
      cursor: grab;
      padding: 4px 4px;
      border-radius: 6px;
      line-height: 0;
      color: #8b949e;
      flex: 0 0 auto;
    }
    #ghrs-handle:hover { background: #30363d; color: #e6edf3; }
    #ghrs-handle:active { cursor: grabbing; }
    #ghrs-overlay.dragging { opacity: 0.92; }
    #ghrs-overlay.dragging #ghrs-handle { cursor: grabbing; }
    #ghrs-title {
      font-weight: 600;
      flex: 1 1 auto;
      white-space: nowrap;
    }
    #ghrs-toggle {
      cursor: pointer;
      border: none;
      border-radius: 6px;
      padding: 3px 10px;
      font-weight: 600;
      color: #fff;
      flex: 0 0 auto;
    }
    #ghrs-toggle.on  { background: #238636; }
    #ghrs-toggle.off { background: #6e7681; }
    #ghrs-expand {
      cursor: pointer;
      border: none;
      background: transparent;
      color: #8b949e;
      font: inherit;
      padding: 2px 4px;
      border-radius: 6px;
      flex: 0 0 auto;
    }
    #ghrs-expand:hover { background: #30363d; color: #e6edf3; }
    #ghrs-expand .ghrs-arrow {
      display: inline-block;
      transition: transform 0.15s ease;
    }
    #ghrs-expand.open .ghrs-arrow { transform: rotate(180deg); }
    #ghrs-panel {
      padding: 0 8px 8px;
      border-top: 1px solid #30363d;
    }
    #ghrs-panel.hidden { display: none; }
    #ghrs-panel label {
      display: block;
      margin: 8px 0 4px;
      color: #8b949e;
    }
    #ghrs-sort {
      width: 100%;
      background: #0d1117;
      color: #e6edf3;
      border: 1px solid #30363d;
      border-radius: 6px;
      padding: 4px 6px;
      cursor: pointer;
    }
    #ghrs-hint {
      margin-top: 8px;
      color: #6e7681;
      font-size: 11px;
    }
  `;

    function injectStyle() {
        if (document.getElementById(STYLE_ID)) return;
        const style = document.createElement('style');
        style.id = STYLE_ID;
        style.textContent = STYLE;
        (document.head || document.documentElement).appendChild(style);
    }

    // Dotted 2x3 grip icon (like a drag handle).
    const HANDLE_SVG = `
    <svg width="12" height="16" viewBox="0 0 12 16" aria-hidden="true" focusable="false">
      <circle cx="3" cy="3"  r="1.5" fill="currentColor"/>
      <circle cx="9" cy="3"  r="1.5" fill="currentColor"/>
      <circle cx="3" cy="8"  r="1.5" fill="currentColor"/>
      <circle cx="9" cy="8"  r="1.5" fill="currentColor"/>
      <circle cx="3" cy="13" r="1.5" fill="currentColor"/>
      <circle cx="9" cy="13" r="1.5" fill="currentColor"/>
    </svg>`;

    // ---------- Overlay UI ----------
    let ui = null;

    function buildOverlay() {
        if (!document.body) return;
        if (document.getElementById('ghrs-overlay')) return;

        const overlay = document.createElement('div');
        overlay.id = 'ghrs-overlay';
        // Render in the browser's top layer when supported. A manual popover is
        // immune to any ancestor "containing block" (transform/filter/contain on
        // <body> or wrappers), so `position: fixed` stays truly viewport-relative
        // and the panel can be dragged anywhere -- even after a full page refresh.
        if ('popover' in HTMLElement.prototype) {
            overlay.setAttribute('popover', 'manual');
        }
        overlay.innerHTML = `
      <div id="ghrs-header">
        <span id="ghrs-handle" title="Drag to move" aria-label="Drag to move">${HANDLE_SVG}</span>
        <span id="ghrs-title">Releases</span>
        <button id="ghrs-toggle" type="button"></button>
        <button id="ghrs-expand" type="button" title="Settings" aria-label="Settings">
          <span class="ghrs-arrow">&#9660;</span>
        </button>
      </div>
      <div id="ghrs-panel">
        <label for="ghrs-sort">Order entries</label>
        <select id="ghrs-sort">
          <option value="${SORT_MODES.USER}">By username (A-Z)</option>
          <option value="${SORT_MODES.USER_OWNER_FIRST}">By username (owner first)</option>
          <option value="${SORT_MODES.PR_ASC}">By PR id (ascending)</option>
          <option value="${SORT_MODES.PR_DESC}">By PR id (descending)</option>
        </select>
        <div id="ghrs-hint">Each author is colour-coded; your own entries are bold.</div>
      </div>
    `;
      // Attach to <html>, not <body>: <body> is the element most likely to carry
      // a transform/contain that would trap a fixed-position child inside the
      // (very tall) page content. <html> escapes that.
      (document.documentElement || document.body).appendChild(overlay);

      // If the popover API is present, promote the element to the top layer.
      if (overlay.hasAttribute('popover') && typeof overlay.showPopover === 'function') {
          try { overlay.showPopover(); } catch (_) { /* already shown / unsupported */ }
      }

      ui = {
          overlay,
          handle: overlay.querySelector('#ghrs-handle'),
          toggle: overlay.querySelector('#ghrs-toggle'),
          expand: overlay.querySelector('#ghrs-expand'),
          panel: overlay.querySelector('#ghrs-panel'),
          select: overlay.querySelector('#ghrs-sort'),
      };

      ui.toggle.addEventListener('click', toggleEnabled);
      ui.expand.addEventListener('click', togglePanel);
      ui.select.addEventListener('change', onSortChange);
      installDragHandlers(overlay, ui.handle);

      applyStoredPosition();
      renderOverlay();
  }

    function renderOverlay() {
        if (!ui) return;
        ui.toggle.textContent = state.enabled ? 'ON' : 'OFF';
        ui.toggle.classList.toggle('on', state.enabled);
        ui.toggle.classList.toggle('off', !state.enabled);
        ui.panel.classList.toggle('hidden', !state.panelOpen);
        ui.expand.classList.toggle('open', state.panelOpen);
        ui.select.value = state.sortMode;
    }

    function toggleEnabled() {
        state.enabled = !state.enabled;
        writeStored(STORAGE_KEYS.enabled, state.enabled);
        renderOverlay();
        if (state.enabled) {
            cachedMe = undefined; // re-detect "you" (DOM may be ready now)
            applyAll();
        } else {
            restoreAll();
        }
    }

    function togglePanel() {
        state.panelOpen = !state.panelOpen;
        writeStored(STORAGE_KEYS.panelOpen, state.panelOpen);
        renderOverlay();
    }

    function onSortChange(event) {
        state.sortMode = event.target.value;
        writeStored(STORAGE_KEYS.sortMode, state.sortMode);
        if (isEnabled()) reapplyAll();
    }

    // ---------- Dragging (hold the dotted handle and move) ----------
    function applyStoredPosition() {
        if (!ui || state.posX === null || state.posY === null) return;
        const { x, y } = clampToViewport(state.posX, state.posY, ui.overlay);
        ui.overlay.style.left = x + 'px';
        ui.overlay.style.top = y + 'px';
        ui.overlay.style.right = 'auto';
        ui.overlay.style.bottom = 'auto';
    }

    function clampToViewport(x, y, el) {
        const w = el.offsetWidth || 200;
        const h = el.offsetHeight || 80;
        const maxX = Math.max(0, window.innerWidth - w);
        const maxY = Math.max(0, window.innerHeight - h);
        return {
            x: Math.min(Math.max(0, x), maxX),
            y: Math.min(Math.max(0, y), maxY),
        };
    }

    function installDragHandlers(overlay, handle) {
        let dragging = false;
        let startX = 0;
        let startY = 0;
        let originLeft = 0;
        let originTop = 0;

        function onPointerDown(e) {
            // Only primary button / touch.
            if (e.button !== undefined && e.button !== 0) return;
            dragging = true;
            overlay.classList.add('dragging');

            const rect = overlay.getBoundingClientRect();
            originLeft = rect.left;
            originTop = rect.top;
            startX = e.clientX;
            startY = e.clientY;

            // Switch to explicit left/top positioning while dragging.
            overlay.style.left = originLeft + 'px';
            overlay.style.top = originTop + 'px';
            overlay.style.right = 'auto';
            overlay.style.bottom = 'auto';

            if (handle.setPointerCapture && e.pointerId !== undefined) {
                try { handle.setPointerCapture(e.pointerId); } catch (_) {}
            }
            e.preventDefault();
        }

        function onPointerMove(e) {
            if (!dragging) return;
            const dx = e.clientX - startX;
            const dy = e.clientY - startY;
            const { x, y } = clampToViewport(originLeft + dx, originTop + dy, overlay);
            overlay.style.left = x + 'px';
            overlay.style.top = y + 'px';
        }

        function onPointerUp() {
            if (!dragging) return;
            dragging = false;
            overlay.classList.remove('dragging');
            const rect = overlay.getBoundingClientRect();
            state.posX = Math.round(rect.left);
            state.posY = Math.round(rect.top);
            writeStored(STORAGE_KEYS.posX, state.posX);
            writeStored(STORAGE_KEYS.posY, state.posY);
        }

        handle.addEventListener('pointerdown', onPointerDown);
        window.addEventListener('pointermove', onPointerMove);
        window.addEventListener('pointerup', onPointerUp);

        // Keep the overlay on-screen after viewport resizes.
        window.addEventListener('resize', () => {
            if (state.posX === null || state.posY === null) return;
            applyStoredPosition();
        });
    }

    // ---------- Mutation observer (GitHub renders async / SPA) ----------
    let scheduled = false;
    function scheduleApply() {
        if (scheduled) return;
        scheduled = true;
        requestAnimationFrame(() => {
            scheduled = false;
            buildOverlay();
            if (isEnabled()) applyAll();
        });
    }

    function startObserver() {
        const observer = new MutationObserver((mutations) => {
            buildOverlay();
            if (!isEnabled()) return;

            for (const mutation of mutations) {
                if (mutation.type !== 'childList') continue;
                for (const node of mutation.addedNodes) {
                    if (!node || node.nodeType !== 1) continue;
                    if (
                        node.matches?.('.markdown-body, .markdown-body ul') ||
                        node.querySelector?.('.markdown-body ul a.user-mention')
                    ) {
                        scheduleApply();
                        return;
                    }
                }
            }
        });

        observer.observe(document.documentElement, {
            subtree: true,
            childList: true,
        });
    }

    // ---------- SPA navigation hooks ----------
    function hookGitHubNavigation() {
        const originalPushState = history.pushState;
        const originalReplaceState = history.replaceState;

        function onNavigation() {
            cachedMe = undefined;
            resetColorRegistry();
            setTimeout(() => {
                buildOverlay();
                renderOverlay();
                if (isEnabled()) applyAll();
            }, 0);
        }

        history.pushState = function () {
            const result = originalPushState.apply(this, arguments);
            onNavigation();
            return result;
        };
        history.replaceState = function () {
            const result = originalReplaceState.apply(this, arguments);
            onNavigation();
            return result;
        };
        window.addEventListener('popstate', onNavigation, { passive: true });
    }

    // ---------- Boot ----------
    function boot() {
        injectStyle();

        if (!document.documentElement || !document.body) {
            setTimeout(boot, 25);
            return;
        }

        buildOverlay();
        startObserver();
        hookGitHubNavigation();
        renderOverlay();

        if (isEnabled()) {
            // Run a few delayed passes; GitHub hydrates markdown asynchronously.
            [0, 200, 600, 1200, 2500].forEach((delay) =>
                                              setTimeout(() => {
                if (isEnabled()) applyAll();
            }, delay)
                                             );
        }
    }

    boot();
})();
