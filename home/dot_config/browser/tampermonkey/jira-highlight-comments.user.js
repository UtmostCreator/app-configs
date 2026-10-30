// ==UserScript==
// @name         Jira: Highlight “Show more replies/comments” buttons
// @namespace    https://tampermonkey.net/
// @version      2026-02-10
// @description  Styles Jira activity “Show more replies” and “Show more comments” controls (lazy-loaded) with MutationObserver.
// @author       You
// @match        https://*.atlassian.net/*
// @match        https://jira.*/*
// @grant        none
// ==/UserScript==

(function () {
  'use strict';

  /**
   * Targets:
   * - Within containers whose data-testid matches /^comment-base-item-\d+$/ (e.g. comment-base-item-34768)
   * - Buttons/spans for:
   *   - “Show more replies”
   *   - “Show more comments”
   *
   * Approach:
   * - Inject CSS for resilient targeting via data-testid where possible.
   * - Also apply inline styles as a fallback (when classnames change).
   * - Run MutationObserver to handle Jira’s async rendering / React re-renders.
   */

  // ---------- Config ----------
  const BG = 'forestgreen';
  const FG = 'white';

  // Regex for comment containers: data-testid="comment-base-item-34768"
  const COMMENT_BASE_TESTID_RE = /^comment-base-item-\d+$/;

  // “Do once” marker to avoid re-styling the same nodes endlessly.
  const MARK_ATTR = 'data-tm-greenified';
  const CARD_SELECTOR = 'div[data-testid="platform-board-kit.ui.card.card"]';
  const ASSIGNEE_NAME = 'Roman Zakhriapa';

  // ---------- CSS injection (preferred: stable selectors) ----------
  const css = `
    /* Show more replies button (data-testid given in example) */
    button[data-testid="issue-view-activity-comment.comment-show-more-replies.show-more-button"] {
      background: ${BG} !important;
      color: ${FG} !important;
    }
    button[data-testid="issue-view-activity-comment.comment-show-more-replies.show-more-button"] * {
      color: ${FG} !important;
      fill: ${FG} !important;
    }

    /* Show more comments button (data-testid given in example) */
    button[data-testid="issue.activity.common.component.load-more-button.loading-button"] {
      background: ${BG} !important;
      color: ${FG} !important;
    }
    button[data-testid="issue.activity.common.component.load-more-button.loading-button"] * {
      color: ${FG} !important;
      fill: ${FG} !important;
    }

    /* Jira board cards: use the priority icon's stable alt text rather than volatile classes. */
    div[data-testid="platform-board-kit.ui.card.card"] [style*="--card-background-color"] {
      box-sizing: border-box;
      border: 1px solid transparent;
      border-left-width: 8px;
    }

    div[data-testid="platform-board-kit.ui.card.card"]:has(img[alt="Highest priority"]) [style*="--card-background-color"] {
      --card-background-color: #ffebe6 !important;
      border-color: #ae2e24 !important;
      box-shadow: inset 0 0 0 1px #f15b50;
    }

    div[data-testid="platform-board-kit.ui.card.card"]:has(img[alt="High priority"]) [style*="--card-background-color"] {
      --card-background-color: #ffdfb7 !important;
      border-color: #b65c02 !important;
      box-shadow: inset 0 0 0 1px #f18d13;
    }

    div[data-testid="platform-board-kit.ui.card.card"]:has(img[alt="Low priority"]) [style*="--card-background-color"] {
      --card-background-color: #e9f2ff !important;
      border-color: #0c66e4 !important;
    }

    div[data-testid="platform-board-kit.ui.card.card"]:has(img[alt="Lowest priority"]) [style*="--card-background-color"] {
      --card-background-color: #f1f2f4 !important;
      border-color: #758195 !important;
    }

    /* Mark cards assigned to Roman without replacing their priority rail. */
    div[data-testid="platform-board-kit.ui.card.card"].tm-assigned-to-roman [style*="--card-background-color"] {
      border-right: 5px solid #22a06b !important;
    }
  `.trim();

  function injectStyle(text) {
    const style = document.createElement('style');
    style.type = 'text/css';
    style.appendChild(document.createTextNode(text));
    document.documentElement.appendChild(style);
  }

  injectStyle(css);

  // ---------- Helpers ----------
  function isJiraLikePage() {
    // Defensive guard to avoid affecting non-Jira pages even if @match is broad.
    // Atlassian Cloud pages typically include “atlassian” in meta/app markers.
    const host = location.hostname.toLowerCase();
    if (host.includes('atlassian.net')) return true;
    if (host.startsWith('jira.')) return true;

    // Heuristic fallback: Jira issue view commonly has these testids somewhere.
    return Boolean(
      document.querySelector('[data-testid*="issue-view"], [data-testid*="issue.activity"]')
    );
  }

  function styleButton(btn) {
    if (!btn || btn.nodeType !== 1) return;
    if (btn.getAttribute(MARK_ATTR) === '1') return;

    btn.style.background = BG;
    btn.style.color = FG;

    // Ensure nested text/icons inherit
    const descendants = btn.querySelectorAll('*');
    for (const el of descendants) {
      el.style.color = FG;
      // Some Jira icons are SVG using currentColor; setting fill helps in some cases.
      if (el.tagName === 'SVG' || el.tagName === 'PATH') {
        el.style.fill = FG;
      }
    }

    btn.setAttribute(MARK_ATTR, '1');
  }

  function findCommentBaseContainers(root) {
    const containers = [];

    // root might itself be a container
    if (root && root.nodeType === 1) {
      const dt = root.getAttribute && root.getAttribute('data-testid');
      if (dt && COMMENT_BASE_TESTID_RE.test(dt)) containers.push(root);
    }

    // plus any descendants
    if (root && root.querySelectorAll) {
      root.querySelectorAll('[data-testid]').forEach((el) => {
        const dt = el.getAttribute('data-testid');
        if (dt && COMMENT_BASE_TESTID_RE.test(dt)) containers.push(el);
      });
    }

    return containers;
  }

  function markAssignedCards(root) {
    if (!root || !root.querySelectorAll) return;

    const cards = [];
    if (root.nodeType === 1 && root.matches(CARD_SELECTOR)) cards.push(root);
    root.querySelectorAll(CARD_SELECTOR).forEach((card) => cards.push(card));

    for (const card of cards) {
      const hasAssigneeLabel = card.querySelector(
        `img[alt="Assignee: ${ASSIGNEE_NAME}"], [aria-label="Assignee: ${ASSIGNEE_NAME}"]`
      );
      const hasAssigneeText = (card.textContent || '').includes(`Assignee: ${ASSIGNEE_NAME}`);
      card.classList.toggle('tm-assigned-to-roman', Boolean(hasAssigneeLabel || hasAssigneeText));
    }
  }

  function applyWithin(root) {
    if (!root || !root.querySelectorAll) return;

    // Primary: target by stable data-testid (best for Jira)
    root
      .querySelectorAll(
        'button[data-testid="issue-view-activity-comment.comment-show-more-replies.show-more-button"],' +
        'button[data-testid="issue.activity.common.component.load-more-button.loading-button"]'
      )
      .forEach(styleButton);

    // Fallback: sometimes data-testid changes; match by visible label text
    // Restrict fallback to comment-base-item containers to avoid false positives.
    const candidates = root.querySelectorAll('button, [role="button"]');
    for (const el of candidates) {
      if (el.getAttribute(MARK_ATTR) === '1') continue;

      const text = (el.innerText || '').trim().toLowerCase();
      if (text === 'show more replies' || text === 'show more comments') {
        styleButton(el);
      }
    }
  }

  function applyAll() {
    markAssignedCards(document);

    // Apply globally where buttons exist
    applyWithin(document);

    // Apply within each comment-base-item-* container specifically (your requirement)
    const containers = findCommentBaseContainers(document);
    for (const c of containers) applyWithin(c);
  }

  // ---------- Mutation observer for async Jira rendering ----------
  let scheduled = false;
  function scheduleApply() {
    if (scheduled) return;
    scheduled = true;
    // Coalesce rapid DOM mutations (React)
    requestAnimationFrame(() => {
      scheduled = false;
      applyAll();
    });
  }

  function startObserver() {
    const obs = new MutationObserver((mutations) => {
      for (const m of mutations) {
        if (m.type !== 'childList' && m.type !== 'attributes') continue;

        // If nodes added, only scan those subtrees for speed.
        if (m.addedNodes && m.addedNodes.length) {
          for (const n of m.addedNodes) {
            if (n && n.nodeType === 1) {
              // If this subtree includes a comment-base-item container or target buttons, rescan.
              const dt = n.getAttribute && n.getAttribute('data-testid');
              if ((dt && COMMENT_BASE_TESTID_RE.test(dt)) ||
                  (n.matches && n.matches(CARD_SELECTOR)) ||
                  (n.querySelector && (
                    n.querySelector(CARD_SELECTOR) ||
                    n.querySelector('button[data-testid="issue-view-activity-comment.comment-show-more-replies.show-more-button"]') ||
                    n.querySelector('button[data-testid="issue.activity.common.component.load-more-button.loading-button"]')
                  ))) {
                scheduleApply();
                return;
              }
            }
          }
        }

        // Attribute changes can reflect re-rendered testids/classes.
        if (m.type === 'attributes') {
          const t = m.target;
          if (t && t.nodeType === 1) {
            const dt = t.getAttribute && t.getAttribute('data-testid');
            if (dt && (COMMENT_BASE_TESTID_RE.test(dt) || dt.includes('issue-view') || dt.includes('issue.activity'))) {
              scheduleApply();
              return;
            }
          }
        }
      }
    });

    obs.observe(document.documentElement, {
      subtree: true,
      childList: true,
      attributes: true,
      attributeFilter: ['data-testid', 'class', 'aria-label', 'alt']
    });

    // Initial runs: Jira can take time; run a few delayed passes.
    applyAll();
    setTimeout(applyAll, 500);
    setTimeout(applyAll, 2000);
    setTimeout(applyAll, 6000);
  }

  // ---------- Boot ----------
  function boot() {
    if (!isJiraLikePage()) return;

    // Wait for body to exist
    if (!document.body) {
      setTimeout(boot, 50);
      return;
    }

    startObserver();
  }

  boot();

})();
