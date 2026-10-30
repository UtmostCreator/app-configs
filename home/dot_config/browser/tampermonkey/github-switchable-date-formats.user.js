// ==UserScript==
// @name         GitHub: Switchable Date Formats
// @namespace    https://tampermonkey.net/
// @version      2026-06-05.3
// @description  Replaces GitHub's relative dates with a date format of your choice. A floating overlay toggles the feature on/off and an expandable panel lets you pick from several formats (persisted). Clicking a reformatted date toggles it between GitHub's standard rendering and your chosen format.
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
   * GitHub renders timestamps inside custom elements
   * (<relative-time>, <time-ago>, <local-time>, <time-until>) that carry a
   * machine-readable ISO value in their `datetime` attribute and a fully
   * formatted local string in their `title` attribute.
   *
   * IMPORTANT IMPLEMENTATION NOTE
   * -----------------------------
   * These are custom elements that re-render their OWN `textContent`
   * asynchronously and whenever their attributes change. You therefore cannot
   * reliably set `el.textContent` on them -- the component overwrites it back.
   *
   * To win this fight we never mutate the original element's text. Instead we:
   *   1. Insert a sibling <span> right after the original element (in place)
   *      and put our custom-formatted text there.
   *   2. Hide ONLY the original time element via CSS while the feature is ON.
   * Crucially we never hide or remove a wrapping <a> or any sibling content,
   * so links, icons and surrounding text remain fully intact. If the span
   * lands inside an <a>, CSS strips link styling and the global click handler
   * suppresses navigation. The new features (format picker, click-to-toggle,
   * settings panel) are layered on top.
   *
   * Behaviour:
   *  - A floating overlay button toggles the feature on/off.
   *  - An arrow expands a settings panel to pick a date format from presets.
   *  - On/off state, chosen format, and panel state persist across loads
   *    (GM storage, falling back to localStorage).
   *  - Clicking a reformatted date toggles that single date between GitHub's
   *    standard relative rendering and the user-selected format.
   */

  // ---------- Storage keys & defaults ----------
  const STORAGE_KEYS = {
    enabled: 'ghsd:enabled',
    formatId: 'ghsd:formatId',
    panelOpen: 'ghsd:panelOpen',
  };

  const DEFAULTS = {
    enabled: true,
    formatId: 'iso',
    panelOpen: false,
  };

  // ---------- DOM markers ----------
  const MODE_ATTR = 'data-ghsd-mode';        // on html element: "on" | "off"
  const HIDDEN_ATTR = 'data-ghsd-hidden';    // marks the time element we processed
  const HOST_ATTR = 'data-ghsd-host';        // the visually-hidden host (anchor or time el)
  const SPAN_ATTR = 'data-ghsd-span';        // our sibling span ("1")
  const OWNER_ATTR = 'data-ghsd-owner';      // links time element <-> its span
  const PERDATE_ATTR = 'data-ghsd-perdate';  // global click override: "standard"

  // ---------- Time elements GitHub uses ----------
  const TIME_TAGS = ['relative-time', 'time-ago', 'local-time', 'time-until'];
  const TIME_SELECTOR = TIME_TAGS.join(',');

  const HIDDEN_TIME_SELECTOR = TIME_TAGS
    .map((tag) => `${tag}[${HIDDEN_ATTR}="1"]`)
    .join(',');

  // ---------- Available date formats ----------
  // Each format is a pure function: (Date) -> string.
  const DATE_FORMATS = [
    {
      id: 'iso',
      label: 'ISO 8601 (2026-06-05)',
      format: (d) => isoDate(d),
    },
    {
      id: 'iso-time',
      label: 'ISO date + time (2026-06-05 14:30)',
      format: (d) => `${isoDate(d)} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`,
    },
    {
      id: 'us',
      label: 'US (06/05/2026)',
      format: (d) =>
        `${pad2(d.getMonth() + 1)}/${pad2(d.getDate())}/${d.getFullYear()}`,
    },
    {
      id: 'eu',
      label: 'European (05/06/2026)',
      format: (d) =>
        `${pad2(d.getDate())}/${pad2(d.getMonth() + 1)}/${d.getFullYear()}`,
    },
    {
      id: 'dotted',
      label: 'Dotted (05.06.2026)',
      format: (d) =>
        `${pad2(d.getDate())}.${pad2(d.getMonth() + 1)}.${d.getFullYear()}`,
    },
    {
      id: 'long',
      label: 'Long (June 5, 2026)',
      format: (d) =>
        d.toLocaleDateString(undefined, {
          year: 'numeric',
          month: 'long',
          day: 'numeric',
        }),
    },
    {
      id: 'long-time',
      label: 'Long + time (June 5, 2026, 2:30 PM)',
      format: (d) =>
        d.toLocaleString(undefined, {
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          hour: 'numeric',
          minute: '2-digit',
        }),
    },
    {
      id: 'weekday',
      label: 'Weekday (Fri, Jun 5, 2026)',
      format: (d) =>
        d.toLocaleDateString(undefined, {
          weekday: 'short',
          year: 'numeric',
          month: 'short',
          day: 'numeric',
        }),
    },
    {
      id: 'title',
      label: "GitHub's full title (hover) text",
      // Uses the element's own `title` string verbatim. Resolved separately
      // because it needs the element, not just a Date. See formatFor().
      format: null,
      usesTitle: true,
    },
  ];

  function pad2(n) {
    return String(n).padStart(2, '0');
  }

  function isoDate(d) {
    // Local-date ISO (not UTC) so the day matches what the user sees.
    return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
  }

  function getFormatById(id) {
    return DATE_FORMATS.find((f) => f.id === id) || DATE_FORMATS[0];
  }

  // ---------- Persistent state ----------
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
    formatId: readStored(STORAGE_KEYS.formatId, DEFAULTS.formatId),
    panelOpen: readStored(STORAGE_KEYS.panelOpen, DEFAULTS.panelOpen),
  };

  // Re-application bookkeeping. `stateToken` invalidates stale async passes
  // after toggles / SPA navigation.
  let stateToken = 0;
  let scheduled = false;

  function isEnabled() {
    return state.enabled;
  }

  function setModeAttribute() {
    const root = document.documentElement;
    if (root) root.setAttribute(MODE_ATTR, isEnabled() ? 'on' : 'off');
  }

  // ---------- Styles ----------
  const STYLE_ID = 'ghsd-style';

  const STYLE = `
    /* Hide ONLY GitHub's original <relative-time> element while ON. We never
       hide the wrapping anchor or sibling content, so links/icons/text stay. */
    html[${MODE_ATTR}="on"] [${HOST_ATTR}="1"] {
      display: none !important;
    }

    /* Show our custom span only when ON. It may sit inside an <a>, so we
       explicitly strip link styling to make it read as plain text. */
    html[${MODE_ATTR}="on"] [${SPAN_ATTR}="1"] {
      display: inline-block !important;
      max-width: 18rem !important;
      white-space: normal !important;
      overflow-wrap: break-word !important;
      word-break: normal !important;
      line-height: 1.35 !important;
      vertical-align: baseline !important;
      cursor: pointer !important;
      color: inherit !important;
      text-decoration: none !important;
    }
    html[${MODE_ATTR}="on"] [${SPAN_ATTR}="1"]:hover {
      text-decoration: underline dotted !important;
    }

    html[${MODE_ATTR}="off"] [${SPAN_ATTR}="1"] {
      display: none !important;
    }

    /* Global click toggle: while ON, clicking any date flips EVERY date to
       GitHub's standard rendering (reveal hosts, hide our spans). */
    html[${MODE_ATTR}="on"][${PERDATE_ATTR}="standard"] [${HOST_ATTR}="1"] {
      display: revert !important;
      cursor: pointer !important;
    }
    /* Same clickable affordance on the original GitHub date when shown. */
    html[${MODE_ATTR}="on"][${PERDATE_ATTR}="standard"] [${HOST_ATTR}="1"]:hover {
      text-decoration: underline dotted !important;
    }
    html[${MODE_ATTR}="on"][${PERDATE_ATTR}="standard"] [${SPAN_ATTR}="1"] {
      display: none !important;
    }

    #ghsd-overlay {
      position: fixed;
      bottom: 16px;
      right: 16px;
      z-index: 2147483647;
      font: 12px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: #e6edf3;
      background: #161b22;
      border: 1px solid #30363d;
      border-radius: 8px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
      user-select: none;
    }
    #ghsd-header {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 8px 10px;
    }
    #ghsd-toggle {
      cursor: pointer;
      border: none;
      border-radius: 6px;
      padding: 4px 10px;
      font-weight: 600;
      color: #fff;
    }
    #ghsd-toggle.on  { background: #238636; }
    #ghsd-toggle.off { background: #6e7681; }
    /* "Dates" label + arrow form one big clickable settings target. */
    #ghsd-settings {
      display: flex;
      align-items: center;
      gap: 6px;
      cursor: pointer;
      border: none;
      background: transparent;
      color: #e6edf3;
      font: inherit;
      padding: 4px 6px;
      border-radius: 6px;
    }
    #ghsd-settings:hover { background: #30363d; }
    #ghsd-settings-label { font-weight: 600; }
    #ghsd-expand {
      display: inline-block;
      font-size: 12px;
      transition: transform 0.15s ease;
      pointer-events: none;
    }
    #ghsd-expand.open { transform: rotate(180deg); }
    #ghsd-panel {
      padding: 0 10px 10px;
      border-top: 1px solid #30363d;
    }
    #ghsd-panel.hidden { display: none; }
    #ghsd-panel label {
      display: block;
      margin: 8px 0 4px;
      color: #8b949e;
    }
    #ghsd-format {
      width: 100%;
      background: #0d1117;
      color: #e6edf3;
      border: 1px solid #30363d;
      border-radius: 6px;
      padding: 4px 6px;
      cursor: pointer;
    }
  `;

  function injectStyle() {
    if (document.getElementById(STYLE_ID)) return;
    const style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = STYLE;
    (document.head || document.documentElement).appendChild(style);
  }

  // ---------- Date parsing & formatting ----------
  function parseDate(el) {
    const iso = el.getAttribute('datetime') || el.getAttribute('title');
    if (!iso) return null;
    const d = new Date(iso);
    return isNaN(d.getTime()) ? null : d;
  }

  function getTitleText(el) {
    const title = el.getAttribute('title');
    return title && title.trim() ? title.trim() : '';
  }

  // Returns the custom-formatted string for an element, or '' if not ready.
  function formatFor(el) {
    const fmt = getFormatById(state.formatId);

    if (fmt.usesTitle) {
      // Use GitHub's own full title text verbatim (closest to old behaviour).
      return getTitleText(el);
    }

    const d = parseDate(el);
    if (!d) return '';
    return fmt.format(d);
  }

  // ---------- Sibling-span management ----------
  function getOrCreateId(el) {
    let id = el.getAttribute(OWNER_ATTR);
    if (!id) {
      id =
        'ghsd-' +
        Math.random().toString(36).slice(2) +
        '-' +
        Date.now().toString(36);
      el.setAttribute(OWNER_ATTR, id);
    }
    return id;
  }

  // We insert our span directly after the time element, IN PLACE. We never
  // touch a wrapping <a> or any sibling content: only the original time
  // element is hidden, and our span sits right next to it. This keeps links,
  // icons and surrounding text fully intact. To prevent the span from looking
  // or behaving like a link (when it happens to live inside an <a>), CSS
  // neutralises link styling and the document click handler suppresses
  // navigation.
  function findExistingSpan(el, id) {
    const next = el.nextElementSibling;
    if (
      next &&
      next.getAttribute(SPAN_ATTR) === '1' &&
      next.getAttribute(OWNER_ATTR) === id
    ) {
      return next;
    }
    return null;
  }

  function createSpan(el, id) {
    const span = document.createElement('span');
    span.setAttribute(SPAN_ATTR, '1');
    span.setAttribute(OWNER_ATTR, id);
    el.insertAdjacentElement('afterend', span);
    return span;
  }

  // Wire (or refresh) a single time element. Safe to call repeatedly.
  function applyToTimeElement(el, token) {
    if (!isEnabled()) return;
    if (token !== stateToken) return;
    if (!el || el.nodeType !== 1) return;
    if (!el.matches || !el.matches(TIME_SELECTOR)) return;

    const text = formatFor(el);
    // Wait until GitHub has populated datetime/title.
    if (!text) return;

    const id = getOrCreateId(el);
    let span = findExistingSpan(el, id);
    if (!span) span = createSpan(el, id);

    if (span.textContent !== text) span.textContent = text;
    span.title = text;

    const datetime = el.getAttribute('datetime');
    if (datetime) span.setAttribute('datetime', datetime);

    el.setAttribute(HIDDEN_ATTR, '1');
    // Hide ONLY the original time element (never a wrapping anchor / siblings).
    el.setAttribute(HOST_ATTR, '1');
  }

  function applyWithin(root, token) {
    if (!isEnabled()) return;
    if (token !== stateToken) return;
    if (!root) return;

    if (root.nodeType === 1 && root.matches && root.matches(TIME_SELECTOR)) {
      applyToTimeElement(root, token);
    }
    if (root.querySelectorAll) {
      root
        .querySelectorAll(TIME_SELECTOR)
        .forEach((el) => applyToTimeElement(el, token));
    }
  }

  // Remove every trace: delete spans, unhide originals, clear markers.
  function restoreOriginalGitHubDates() {
    document.querySelectorAll(`[${SPAN_ATTR}="1"]`).forEach((span) => {
      span.remove();
    });

    document.querySelectorAll(`[${HOST_ATTR}="1"]`).forEach((el) => {
      el.removeAttribute(HOST_ATTR);
    });

    // Defensive cleanup for any marked time elements.
    document.querySelectorAll(TIME_SELECTOR).forEach((el) => {
      el.removeAttribute(HIDDEN_ATTR);
      el.removeAttribute(OWNER_ATTR);
    });
  }

  // Re-render spans after a format change (without rebuilding everything).
  function refreshCustomDates() {
    const token = stateToken;
    document.querySelectorAll(HIDDEN_TIME_SELECTOR).forEach((el) => {
      applyToTimeElement(el, token);
    });
  }

  // ---------- Click toggle (affects ALL dates) ----------
  // Clicking ANY reformatted date flips EVERY date on the page between the
  // custom format and GitHub's standard relative format. Repeated clicks flip
  // them back and forth indefinitely.
  //
  // We use ONE document-level capture listener instead of per-element ones.
  // This is essential: in "standard" mode our custom spans are hidden, so a
  // listener bound to the span could never receive the click that switches
  // back. The document listener catches clicks on EITHER our span OR the
  // original date host (the time element itself), and suppresses any link
  // navigation in the process.
  function isOurClickTarget(node) {
    while (node && node !== document.documentElement) {
      if (node.nodeType === 1) {
        if (node.getAttribute && node.getAttribute(SPAN_ATTR) === '1') {
          return true;
        }
        if (node.getAttribute && node.getAttribute(HOST_ATTR) === '1') {
          return true;
        }
        if (node.matches && node.matches(TIME_SELECTOR) &&
            node.hasAttribute(HIDDEN_ATTR)) {
          return true;
        }
      }
      node = node.parentNode;
    }
    return false;
  }

  function onDocumentClickCapture(event) {
    if (!isEnabled()) return;
    if (!isOurClickTarget(event.target)) return;

    // It's a date we manage: suppress navigation and toggle all dates.
    event.preventDefault();
    event.stopPropagation();
    if (typeof event.stopImmediatePropagation === 'function') {
      event.stopImmediatePropagation();
    }
    toggleAllDates();
  }

  function onDocumentSwallowCapture(event) {
    if (!isEnabled()) return;
    if (!isOurClickTarget(event.target)) return;
    // Block mousedown/auxclick navigation on managed dates.
    event.preventDefault();
    event.stopPropagation();
    if (typeof event.stopImmediatePropagation === 'function') {
      event.stopImmediatePropagation();
    }
  }

  let clickListenerInstalled = false;
  function installClickListener() {
    if (clickListenerInstalled) return;
    clickListenerInstalled = true;
    document.addEventListener('click', onDocumentClickCapture, true);
    document.addEventListener('mousedown', onDocumentSwallowCapture, true);
    document.addEventListener('auxclick', onDocumentSwallowCapture, true);
  }

  // Global flag: are we currently showing GitHub's standard dates instead of
  // our custom format (while the feature itself is still enabled)?
  let showingStandard = false;

  function toggleAllDates() {
    showingStandard = !showingStandard;
    applyShowingStandard();
  }

  // Reflect `showingStandard` onto the <html> element so a single CSS rule
  // swaps every date at once (no per-element looping needed).
  function applyShowingStandard() {
    const root = document.documentElement;
    if (!root) return;
    if (showingStandard) {
      root.setAttribute(PERDATE_ATTR, 'standard');
    } else {
      root.removeAttribute(PERDATE_ATTR);
    }
  }

  // ---------- Apply passes (GitHub renders async) ----------
  function runApplyPasses() {
    if (!isEnabled()) return;
    const token = stateToken;

    applyWithin(document, token);

    [100, 300, 700, 1200, 2500, 5000, 8000].forEach((delay) => {
      setTimeout(() => {
        if (!isEnabled()) return;
        if (token !== stateToken) return;
        applyWithin(document, token);
      }, delay);
    });
  }

  // ---------- Overlay UI ----------
  let ui = null;

  function buildOverlay() {
    if (!document.body) return;
    if (document.getElementById('ghsd-overlay')) return;

    const overlay = document.createElement('div');
    overlay.id = 'ghsd-overlay';
    overlay.innerHTML = `
      <div id="ghsd-header">
        <button id="ghsd-toggle" type="button"></button>
        <button id="ghsd-settings" type="button" title="Settings" aria-label="Settings">
          <span id="ghsd-settings-label">Dates</span>
          <span id="ghsd-expand">&#9660;</span>
        </button>
      </div>
      <div id="ghsd-panel">
        <label for="ghsd-format">Date format</label>
        <select id="ghsd-format"></select>
      </div>
    `;
    document.body.appendChild(overlay);

    ui = {
      overlay,
      toggle: overlay.querySelector('#ghsd-toggle'),
      settings: overlay.querySelector('#ghsd-settings'),
      expand: overlay.querySelector('#ghsd-expand'),
      panel: overlay.querySelector('#ghsd-panel'),
      select: overlay.querySelector('#ghsd-format'),
    };

    for (const fmt of DATE_FORMATS) {
      const opt = document.createElement('option');
      opt.value = fmt.id;
      opt.textContent = fmt.label;
      ui.select.appendChild(opt);
    }

    ui.toggle.addEventListener('click', toggleEnabled);
    ui.settings.addEventListener('click', togglePanel);
    ui.select.addEventListener('change', onFormatChange);

    renderOverlay();
  }

  function renderOverlay() {
    if (!ui) return;
    ui.toggle.textContent = state.enabled ? 'ON' : 'OFF';
    ui.toggle.classList.toggle('on', state.enabled);
    ui.toggle.classList.toggle('off', !state.enabled);
    ui.panel.classList.toggle('hidden', !state.panelOpen);
    ui.expand.classList.toggle('open', state.panelOpen);
    ui.select.value = state.formatId;
  }

  function toggleEnabled() {
    state.enabled = !state.enabled;
    writeStored(STORAGE_KEYS.enabled, state.enabled);
    stateToken += 1;
    setModeAttribute();
    renderOverlay();

    if (state.enabled) {
      applyShowingStandard();
      runApplyPasses();
    } else {
      restoreOriginalGitHubDates();
    }
  }

  function togglePanel() {
    state.panelOpen = !state.panelOpen;
    writeStored(STORAGE_KEYS.panelOpen, state.panelOpen);
    renderOverlay();
  }

  function onFormatChange(event) {
    state.formatId = event.target.value;
    writeStored(STORAGE_KEYS.formatId, state.formatId);
    refreshCustomDates();
  }

  // ---------- Mutation observer ----------
  function scheduleApply(root) {
    if (!isEnabled()) return;
    if (scheduled) return;
    const token = stateToken;
    scheduled = true;
    requestAnimationFrame(() => {
      scheduled = false;
      if (!isEnabled()) return;
      if (token !== stateToken) return;
      applyWithin(root || document, token);
    });
  }

  function startObserver() {
    const observer = new MutationObserver((mutations) => {
      buildOverlay();

      if (!isEnabled()) return;
      const token = stateToken;

      for (const mutation of mutations) {
        if (mutation.type === 'childList') {
          for (const node of mutation.addedNodes) {
            if (!node || node.nodeType !== 1) continue;
            if (
              node.matches?.(TIME_SELECTOR) ||
              node.querySelector?.(TIME_SELECTOR)
            ) {
              scheduleApply(node);
              return;
            }
          }
        }

        if (mutation.type === 'attributes') {
          const target = mutation.target;
          if (
            target &&
            target.nodeType === 1 &&
            target.matches?.(TIME_SELECTOR)
          ) {
            applyToTimeElement(target, token);
            return;
          }
        }
      }
    });

    observer.observe(document.documentElement, {
      subtree: true,
      childList: true,
      attributes: true,
      attributeFilter: ['title', 'datetime', 'class'],
    });
  }

  // ---------- SPA navigation hooks ----------
  function hookGitHubNavigation() {
    const originalPushState = history.pushState;
    const originalReplaceState = history.replaceState;

    function onNavigation() {
      stateToken += 1;
      setModeAttribute();
      applyShowingStandard();
      setTimeout(() => {
        buildOverlay();
        renderOverlay();
        if (isEnabled()) {
          applyShowingStandard();
          runApplyPasses();
        } else {
          restoreOriginalGitHubDates();
        }
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
    setModeAttribute();

    if (!document.documentElement || !document.body) {
      setTimeout(boot, 25);
      return;
    }

    buildOverlay();
    startObserver();
    hookGitHubNavigation();
    installClickListener();
    renderOverlay();
    applyShowingStandard();

    if (isEnabled()) {
      runApplyPasses();
    } else {
      restoreOriginalGitHubDates();
    }
  }

  boot();
})();
