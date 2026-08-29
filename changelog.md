# Changelog — norml-wordpress-copilot-advanced (repository)

This file tracks **repository-level** changes — README, packaging, license,
distribution. The **skill's own** version history is the source of truth for
skill behavior: see
[`.claude/skills/norml-wp-developer/changelog.md`](.claude/skills/norml-wp-developer/changelog.md)
(currently **v1.2.1**).

## Aug 29, 2026

- Renamed the public GitHub repository from `norml-wp-developer` to
  `norml-wordpress-copilot-advanced` so its source identity matches the product
  name.
- Updated all repository install commands and generated one-pager metadata. The
  installed `norml-wp-developer` slug remains stable for backward compatibility.

## Aug 28, 2026

- Updated public naming to **Norml WordPress Copilot Advanced** while preserving
  the stable `norml-wp-developer` package slug.
- Added the generated capability/architecture project contract and working
  macOS/Linux + Windows read-only scanners.
- Made GitHub, production SSH, remote WP-CLI, and the first architecture scan
  mandatory onboarding gates. Updated install, onboarding, and public docs for the
  CLI-only product boundary.
- Added exact installed-package path/role documentation to the deep guide and
  generated one-pager, explicitly separated from the theme-local project output.

## Jun 22, 2026

- README + repo changelog updated to reflect skill **v1.1.0** — a
  reference-layer depth expansion (new `development-guides/conventions/` and
  `development-guides/ci-cd/` folders + `development-guides/qa-gates.md`). Setup, develop,
  and deploy behavior are unchanged; the new references are additive. See
  the [skill changelog](.claude/skills/norml-wp-developer/changelog.md)
  for the full breakdown.
- Swapped the human-facing docs to the one-pager approach: removed
  `human.md`; added `readme.md` + `readme.data.json` +
  `readme.html` (visual one-pager) and a new `install.html` (visual,
  prompt-first install page — copy-pastable Claude Code prompts with
  copy buttons). README doc links updated to point at them.

## Jun 13, 2026

- Extracted into a standalone public repository, split out of the internal
  `norml-shared-skills` bundle (which previously held this skill alongside
  `norml-wp-manager`).
- Added MIT `LICENSE` (© Norml Studio), public-facing `README.md`, `.gitignore`.
- Skill content unchanged at v1.0.0 — relocation only.
