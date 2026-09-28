# Storage Files Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate every eligible non-duplicate asset and source file from both supplied storage archives into the Godot project without changing existing files.

**Architecture:** A deterministic PowerShell extraction routine maps each archive's project root to the repository root and permits creation only when the destination does not exist. A manifest records copied, skipped, and excluded entries. Godot then regenerates its own import metadata and validates the project.

**Tech Stack:** PowerShell/.NET `System.IO.Compression`, Godot 4 headless validation, Git.

**Spec:** `docs/superpowers/specs/2026-09-27-storage-files-integration-design.md`

## Global Constraints

- Existing repository files always win; the integration must not overwrite them.
- Exclude `.godot/**`, all `.import` files, and archive-provided `git-lfs` and `godot` executables.
- Strip only archive project roots: `jjnds/` and `workspace/jjnds/`.
- Do not alter `project.godot`, autoloads, scenes, or menus.
- Do not enable `addons/godot_ai`.

## Review Focus

- A path that already exists must be skipped even if it has a newer archive timestamp.
- Both archive-root forms must map into the same repository root rather than a nested `jjnds` directory.
- A ZIP entry with traversal syntax must be rejected rather than written outside the repository.
- Godot-generated `.import` files must not be copied because their UIDs are local to the current project.
- A parse error in an optional newly imported script must be surfaced by the headless validation command.

---

### Task 1: Safe archive importer and manifest

**Files:**
- Create: `tools/integrate_storage_archives.ps1`
- Create: `docs/integrations/2026-09-27-storage-files-manifest.json`

**Interfaces:**
- Consumes: root-level `storage-files.zip` and `storage-files (1).zip`.
- Produces: JSON manifest with `copied`, `skipped_existing`, and `excluded` normalized paths.

- [ ] **Step 1: Add an importer that accepts the project root and the two archive paths**

Use `[System.IO.Compression.ZipFile]::OpenRead()`. Normalize `jjnds/` and `workspace/jjnds/` archive roots, reject empty/traversal paths, and create missing destination directories only beneath the supplied project root.

- [ ] **Step 2: Encode the copy policy**

Skip a destination that already exists. Exclude `.godot/`, path segments ending in `.import`, and exact root executables `git-lfs` and `godot`; copy every other file once, preserving its relative path.

- [ ] **Step 3: Write the manifest after extraction**

Serialize the three result lists as JSON to `docs/integrations/2026-09-27-storage-files-manifest.json`, so the outcome can be audited without re-reading the archives.

- [ ] **Step 4: Run the importer**

Run: `powershell -ExecutionPolicy Bypass -File tools/integrate_storage_archives.ps1`

Expected: the script completes successfully, reports zero overwrites, and writes the manifest.

- [ ] **Step 5: Verify the manifest and copied-file boundary**

Run: inspect the JSON counts and confirm no manifest `copied` entry previously existed before execution.

- [ ] **Step 6: Commit**

```bash
git add tools/integrate_storage_archives.ps1 docs/integrations/2026-09-27-storage-files-manifest.json
git commit -m "feat: integrate unique storage archive resources"
```

### Task 2: Project validation

**Files:**
- Modify: generated Godot local import state only (not committed)
- Test: headless Godot project load

**Interfaces:**
- Consumes: copied archive sources and the existing `project.godot`.
- Produces: a successful Godot project validation result or actionable diagnostics.

- [ ] **Step 1: Run headless Godot validation**

Run: `Godot.exe --headless --path . --editor --quit --log-file storage-integration-validation.log`

Expected: exit code 0 and no script parse errors attributable to imported files.

- [ ] **Step 2: Check validation diagnostics**

Inspect `storage-integration-validation.log` for parse failures. If an optional incoming script is invalid, keep the archive copy intact and report its path and diagnostic; do not rewrite existing project code.

- [ ] **Step 3: Record the validation result in the manifest**

Add the command exit code and relevant diagnostics to the manifest's `validation` object.

- [ ] **Step 4: Commit**

```bash
git add docs/integrations/2026-09-27-storage-files-manifest.json
git commit -m "test: validate integrated storage resources"
```
