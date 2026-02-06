# DONEZY — AI_NAVIGATION.md
Authoritative Project Navigation & Anti-Repeat Control

LAST UPDATED: 2026-02-06
OWNER: AI (with explicit permission)

============================================================
PURPOSE
============================================================
This file is the single source of truth for:
• Current project phase
• What actions are DONE / SKIPPED / PENDING
• Fingerprints proving completed work
• Preventing repeated or regressive changes
• Enforcing file ownership boundaries

If this file disagrees with memory, chat history, or assumptions:
THIS FILE WINS.

============================================================
CURRENT PHASE
============================================================
PHASE 1 — STABILITY & ORIENTATION

Goal:
• Achieve flutter analyze = 0 issues
• Restore structural correctness
• Prove ownership boundaries
• Verify reorder + task flow correctness

No feature expansion is allowed in this phase.

============================================================
GLOBAL RULES (ENFORCED)
============================================================
• flutter analyze is the final authority
• App runs but analyze fails = FAILURE
• No ignores, suppressions, or TODO bypasses
• Each behavior has exactly ONE owning file
• Smallest safe edit always wins
• No repetition of completed actions

============================================================
FILE OWNERSHIP MAP
============================================================

UI LAYOUT (Widgets / Screens)
• Parent task list + reorder:
  - lib/screens/parent/parent_dashboard_page.dart

• Child task view:
  - lib/screens/child/child_dashboard_page.dart

• Task card layout:
  - lib/widgets/tasks/task_card.dart

STATE / ACTIONS
• Task reorder action:
  - lib/actions/tasks/reorder_tasks_action.dart

• Task mutation actions:
  - lib/actions/tasks/*.dart

PERSISTENCE / STORES
• Task in-memory state:
  - lib/services/task_store.dart

• Task orchestration + reorder logic:
  - lib/services/task_service.dart

============================================================
ACTION REGISTRY
============================================================

[A-001] Create AI_NAVIGATION.md
STATUS: DONE
FINGERPRINT:
- File exists at repo root
- Contains phase, ownership, registry, and fingerprints
DATE: 2026-02-06

[A-002] Analyzer Baseline Verification
STATUS: PENDING
REQUIRES:
- flutter pub get
- flutter analyze output captured
BLOCKER:
- Child dashboard structural integrity

[A-003] Child Dashboard Structural Repair
STATUS: PENDING
OWNER:
- lib/screens/child/child_dashboard_page.dart
GOAL:
- Restore valid widget tree
- Remove orphaned blocks / syntax corruption
NO UI CHANGES beyond safety

[A-004] Task Reorder Flow Verification
STATUS: PENDING
OWNER:
- lib/actions/tasks/reorder_tasks_action.dart
- lib/services/task_service.dart
GOAL:
- Confirm reorder indices correctness
- Confirm guard conditions prevent filtered reorder bugs

============================================================
ANTI-REPEAT FINGERPRINTS
============================================================

• Any change marked DONE here MUST NOT be re-suggested
• If fingerprint matches existing code → mark SKIPPED
• Repeating a DONE action = FAILURE

============================================================
CHANGE CONTROL
============================================================
Only this file may be updated autonomously by AI.

All other files require:
• Declared owner
• Justification
• Smallest safe patch
• Analyzer verification

============================================================
END OF FILE
============================================================
