# Storage Files Integration Design

## Objective

Complement the existing Corner Club — Boxing Godot project with the two supplied
`storage-files` archives while preserving the current project as the source of
truth. No existing project file is replaced.

## Sources and destination

- `storage-files.zip` provides gameplay assets, optional gameplay scripts, and
  the optional `godot_ai` editor add-on.
- `storage-files (1).zip` provides a later set of reach-related combat tests
  and support scripts, plus a few animation preview textures.
- Both archives are flattened from their archive project root into this
  repository root; archive roots (`jjnds` and `workspace/jjnds`) are not
  created as nested project directories.

## Copy policy

1. An archive file is copied only when its normalized project-relative path
   does not already exist in this repository.
2. Existing files always win, regardless of archive order.
3. Godot-generated or machine-local artifacts are excluded: `.godot/**`,
   `.import` files, archive-provided `git-lfs` and `godot` executables.
4. The source archives and currently untracked user folders remain untouched.

## Integration boundaries

New assets retain their existing logical paths: `assets/`, `characters/`,
`scripts/musica/`, and `samurai/`. New optional gameplay scripts retain their
respective `scripts/`, `boxing/`, and `addons/godot_ai/` paths. Existing scenes,
autoloads, and menus are not modified to reference these additions
automatically; this prevents broken scene references or altered game flow.

`addons/godot_ai` is imported as source only. It is not enabled in
`project.godot`, so its external editor/MCP configuration is opt-in and cannot
affect the playable project.

## Validation

After extraction, validate that all copied entries conform to the policy and
launch Godot in headless project-check mode. A successful check must report no
parse failures caused by the added files. Godot may generate fresh import
metadata locally; those artifacts are not part of the integration.

## Success criteria

- Every eligible, non-duplicate archive entry is available at its normalized
  path in the repository.
- No pre-existing repository file is overwritten.
- No generated Godot cache/import file or executable is copied from an archive.
- The existing project continues to load successfully in Godot.
