# Tampermonkey Userscripts

Scripts for the work-profile Tampermonkey extension, version `5.5.1`, ID
`dhdgffkkebhmkfjojejmpbldmpobfkfo`. The `userscripts` paths in
[../work-profile.extensions.json](../work-profile.extensions.json) are relative to
the browser configuration directory. This is an inventory, not an automatic
extension-settings importer.

| Script | File | Sites |
| --- | --- | --- |
| Jira comment buttons, priority rails, and Roman's assigned cards | [jira-highlight-comments.user.js](jira-highlight-comments.user.js) | Jira / Atlassian |
| GitHub release sorting and author highlighting | [github-releases-sorter.user.js](github-releases-sorter.user.js) | GitHub releases |
| GitHub switchable date formats | [github-switchable-date-formats.user.js](github-switchable-date-formats.user.js) | GitHub |

## Install

1. Install Tampermonkey in the browser's work profile. In Chromium, open
   `chrome://extensions/?id=dhdgffkkebhmkfjojejmpbldmpobfkfo` and enable
   **Allow User Scripts** (or **Developer mode** if required by the browser).
2. Deploy the files with `chezmoi apply ~/.config/browser`, or use the files in
   this repository directly.
3. Open **Tampermonkey > Dashboard > Utilities > Import from file** and import
   each of the three `.user.js` files. Deployed files are under
   `~/.config/browser/tampermonkey/`. Review and confirm each installation.
4. Ensure the three scripts are enabled in Tampermonkey, then reload Jira or
   GitHub. The Releases overlay starts OFF; turn it ON on a `/releases` page.
   The Dates overlay starts ON with ISO dates.

The scripts are preserved as supplied. Tampermonkey manages its own installed
copies; after updating these source files, import them again to update those
copies. GitHub overlay choices persist in Tampermonkey storage (with a
localStorage fallback), not in this manifest. Browser-profile databases and
extension-internal storage are intentionally not managed here.
