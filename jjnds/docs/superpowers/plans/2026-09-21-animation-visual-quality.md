# Animation and Visual Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans task-by-task.

**Goal:** Improve combat motion contact and Forward+ presentation without changing combat rules.

**Architecture:** Add isolated IK/root-motion helpers around the current `Fighter`/`AnimationTree`; create reusable environment setup for ring and hub.

**Tech Stack:** Godot 4.7, GDScript, Skeleton3D, WorldEnvironment.

**Spec:** `docs/superpowers/specs/2026-09-21-animation-visual-quality-design.md`

## Global Constraints

- Preserve the existing combat suite.
- Keep `CharacterBody3D` as collision authority.
- Do not add imported animation assets.

### Task 1: Hybrid animation motion and constrained arm IK

**Files:** Modify `boxing/characters/fighter.gd`, create `boxing/characters/arm_ik.gd`, modify `boxing/tests/combat_test.gd`.

- [ ] Write a failing test that an unreachable target returns a clamped solution and does not move root.
- [ ] Run `Godot.exe --headless --path . --script boxing/tests/combat_test.gd`; verify failure.
- [ ] Implement `ArmIK.solve(shoulder, elbow_length, forearm_length, target) -> Dictionary` and apply it only during an active punch.
- [ ] Feed attack locomotion from animation cadence into desired velocity without replacing collision movement.
- [ ] Re-run the suite and commit.

### Task 2: Forward+ studio environment and PBR setup

**Files:** Create `boxing/arena/studio_environment.gd`, modify `boxing/main.gd`, `scripts/club/club_hub_3d.gd`, `boxing/tests/visual_test.gd`.

- [ ] Write a failing visual scene assertion for WorldEnvironment and three studio lights.
- [ ] Run visual test and verify failure.
- [ ] Configure AgX, SSAO, controlled exposure and overhead spot lights; add PBR roughness/normal-compatible materials while retaining dynamic damage shader.
- [ ] Re-run combat and visual suites and commit.
