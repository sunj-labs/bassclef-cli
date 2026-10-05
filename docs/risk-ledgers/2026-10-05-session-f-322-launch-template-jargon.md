---
goal: Session F — cli#322 /launch template jargon driver
date: 2026-10-05
lenses:
  - michael-feathers
  - linus-torvalds
mode: light
---

# Pre-mortem light — cli#322 driver

Pattern 5x-proven in Session F. Risks compress to 3.

- **F1 — grep anchor collision.** Any skill body example may mention `scope-bounded` or `appetite:` in prose. Fold: driver pins exact file path (/launch SKILL.md); scope stays narrow.
- **F2 — bundle sync lifecycle.** Same as #306/#331/#332/#329: driver flips when v1.7.1+ bundle sync lands with the cured template. Expected design behavior.
- **L1 — adopter follows template, gets blocked by framework.** This IS the ticket. Driver captures the pain as evidence. Linus userspace-break class.

All 3 folded; no code change beyond the driver.
