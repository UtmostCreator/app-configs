# Archived migration records

Historical, completed-migration artifacts. Kept for audit trail only; nothing
here is read by a live check. The dotfiles migration completed 2026-06-02.

| File | What it was |
|------|-------------|
| `migration-audit-2026-05-24.md` | Dated migration audit snapshot. |
| `pr-body-2026-05-24.md` | Body of the migration pull request. |
| `file-audit-plan.md` | The `docs/` -> `repo-docs/` move plan (completed). |
| `docs-move-manifest.json` | One-off move manifest snapshot. |
| `docs-move-manifest.py` | One-off helper that generated the move manifest. |
| `migration-package-ownership.draft.md` | Regenerable draft from `ops/generate-package-matrix.sh`. |
| `migration-source-of-truth.draft.md` | Regenerable draft from `ops/check-source-of-truth.sh`. |

Active, load-bearing migration docs remain in `repo-docs/`:
`migration-source-of-truth.md`, `migration-package-ownership.md`,
`migration-decisions.md`, `migration-implementation-plan.md`,
`migration-followups.md` (referenced by `ops/doctor.sh`,
`ops/validate-config.sh`, the README, and `architecture/tool-ownership.md`).
