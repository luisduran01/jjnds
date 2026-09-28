# Boxin SSJJ Combat 2.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the complete Combat 2.0 roadmap as a modular, testable PC boxing system while preserving a playable fight after every task.

**Architecture:** Reduce `Fighter` to a compatibility coordinator around focused state, movement, attack, defense, contact, condition, reaction and ring modules. Migrate behavior incrementally behind existing signals and properties, then replace AI, rules and presentation consumers with typed combat snapshots and events.

**Tech Stack:** Godot 4.7, GDScript, CharacterBody3D, AnimationTree/AnimationPlayer, PhysicsDirectSpaceState3D, Skeleton3D, procedural animation, active ragdoll, Godot headless test scripts.

**Spec:** `docs/superpowers/specs/2026-09-27-boxin-ssjj-combat-2-0-design.md`

## Global Constraints

- Target Godot 4.7 and PC only; do not preserve web-export parity.
- Keep the GL Compatibility renderer unless a measured PC feature requires a documented renderer migration.
- Target a stable 60 FPS in the reference fight scene.
- Preserve existing local changes and do not restore or delete unrelated files.
- Keep boxer data, round flow and public `Fighter` signals/properties compatible until their consumers migrate.
- New external assets must include source, author, license and redistribution terms in `assets/ATTRIBUTION.md`.
- Prefer the current shared rig and procedural/full-body animation reconstruction first; replace the rig only after a side-by-side quality and performance gate proves the replacement superior.
- Do not add career mode, network multiplayer, cosmetic collections, ring collections or complex offensive clinch systems.
- Every behavioral change uses red-green-refactor; every task ends with the targeted test and the complete combat suite passing.

### Verification commands

Use this exact PowerShell command wherever a task says to run the complete combat suite:

```powershell
$tests = @(
  'boxing/tests/contracts_test.gd',
  'boxing/tests/state_machine_test.gd',
  'boxing/tests/condition_model_test.gd',
  'boxing/tests/footwork_test.gd',
  'boxing/tests/animation_controller_test.gd',
  'boxing/tests/action_controller_test.gd',
  'boxing/tests/contact_resolver_test.gd',
  'boxing/tests/boxing_brain_test.gd',
  'boxing/tests/fight_rules_test.gd',
  'boxing/tests/presentation_test.gd',
  'boxing/tests/combat_test.gd'
)
foreach ($test in $tests) {
  & 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --script $test
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Before a test exists, omit only that future path. Never omit an existing test. Use this exact import check where requested:

```powershell
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --editor --quit --log-file 'combat_2_import.log'
```

## Review Focus

- Missing animation or audio resource must fall back to a neutral state without trapping either fighter; covered in Task 5.
- Zero/negative delta and overlapping fighters must not generate NaN velocity, damage or impulses; covered in Tasks 3 and 4.
- A fighter freed during a hit, round transition or AI decision must not leave a stale reference or crash; covered in Tasks 7, 8 and 9.
- Repeated input at state boundaries must produce at most one buffered action and one hit per attack/victim; covered in Tasks 2, 6 and 7.
- Long fights must not grow hit registries, event queues, textures or transient effects without a bound; covered in Tasks 7 and 11.

---

### Task 1: Establish the Combat 2.0 test harness and typed contracts

**Files:**
- Create: `boxing/combat/combat_types.gd`
- Create: `boxing/tests/test_support.gd`
- Create: `boxing/tests/contracts_test.gd`
- Modify: `boxing/tests/combat_test.gd:1-12`

**Interfaces:**
- Produces: `CombatTypes.RangeBand`, `ContactResult`, `ActionKind`, `HitData`, `CombatSnapshot`, and `TestSupport.check_finite_vector(value: Vector3) -> bool`.
- Consumers: all later tasks use these enum values and dictionary constructors instead of ad-hoc strings.

- [ ] **Step 1: Write the failing contracts test**

Create assertions that `HitData.create(...)` preserves attacker/victim IDs, attack ID, punch, zone, contact position, velocity, accuracy and defense; that `CombatSnapshot.create(...)` supplies finite conservative defaults; and that each enum exposes the exact names specified above.

- [ ] **Step 2: Run the contracts test and confirm RED**

Run: `C:/Users/Luis Duran/Desktop/Godot.exe --headless --path . --script boxing/tests/contracts_test.gd`

Expected: exit 1 because `combat_types.gd` does not exist.

- [ ] **Step 3: Implement the typed contracts and shared finite-value assertion**

Use typed static constructors returning dictionaries with explicit keys so existing GDScript consumers can migrate without requiring custom Resource serialization.

- [ ] **Step 4: Run targeted and baseline tests**

Run the contracts command, then `C:/Users/Luis Duran/Desktop/Godot.exe --headless --path . --script boxing/tests/combat_test.gd`.

Expected: both exit 0 and print zero failures.

- [ ] **Step 5: Commit**

```bash
git add boxing/combat/combat_types.gd boxing/tests/test_support.gd boxing/tests/contracts_test.gd boxing/tests/combat_test.gd
git commit -m "test: establish Combat 2.0 contracts"
```

### Task 2: Extract the combat state machine and input buffer

**Files:**
- Create: `boxing/combat/combat_state_machine.gd`
- Create: `boxing/tests/state_machine_test.gd`
- Modify: `boxing/characters/fighter.gd:9-50,184-244,249-286`

**Interfaces:**
- Consumes: `CombatTypes.ActionKind`.
- Produces: `CombatStateMachine.request(next: int, duration: float, reason: StringName = &"") -> bool`, `tick(delta: float) -> void`, `buffer(action: Dictionary, lifetime: float = 0.16) -> bool`, `take_buffered() -> Dictionary`, `interrupt(reason: StringName) -> void`, and signals `transitioned(previous, next, reason)` and `buffer_expired(action)`.
- Compatibility: `Fighter.state`, `state_time`, `buffered`, `buffer_life`, `set_state`, `can_act`, `attack`, `dodge` and `feint` remain callable and delegate to the module.

- [ ] **Step 1: Write failing state-machine tests**

Cover legal neutral→attack→recovery→neutral transitions, hurt interrupting attack, KO rejecting all actions, an early buffered action becoming available once, buffer expiry, repeated input replacing neither the first accepted action nor creating duplicates, and unknown animation reasons returning safely to neutral.

- [ ] **Step 2: Run the test and confirm RED**

Run: `C:/Users/Luis Duran/Desktop/Godot.exe --headless --path . --script boxing/tests/state_machine_test.gd`

Expected: exit 1 because `CombatStateMachine` is missing.

- [ ] **Step 3: Implement the state machine and migrate Fighter delegation**

Keep transition priorities in one table: `KO > KNOCKDOWN > STUN > HURT > DEFEND/ATTACK > MOVE > IDLE`. Clamp negative duration and delta to zero. Store one buffered action only.

- [ ] **Step 4: Run state, contracts and full combat tests**

Expected: all commands exit 0; existing flow tests still observe the legacy `Fighter` state properties.

- [ ] **Step 5: Commit**

```bash
git add boxing/combat/combat_state_machine.gd boxing/tests/state_machine_test.gd boxing/characters/fighter.gd
git commit -m "refactor: extract combat state machine"
```

### Task 3: Consolidate condition, fatigue and localized damage

**Files:**
- Create: `boxing/combat/condition_model.gd`
- Create: `boxing/tests/condition_model_test.gd`
- Modify: `boxing/combat/fatigue_model.gd`
- Modify: `boxing/combat/injury_system.gd`
- Modify: `boxing/characters/fighter.gd:24-30,100-102,249-328,410-469`

**Interfaces:**
- Consumes: a `HitData` dictionary.
- Produces: `ConditionModel.configure(stats: Dictionary)`, `can_spend(cost: float) -> bool`, `spend(cost: float, intensity: float, connected: bool) -> void`, `tick(delta: float, activity: int) -> void`, `apply_hit(hit: Dictionary, result: int, damage: float) -> Dictionary`, `rest(seconds: float, treatment: StringName = &"") -> Dictionary`, and `snapshot() -> Dictionary`.
- Compatibility: `Fighter.health`, `stamina`, `guard`, `head_damage`, `body_damage`, `stun` and `knockdown_meter` mirror the model until UI migration.

- [ ] **Step 1: Write failing condition tests**

Assert literal outcomes for: whiff stamina cost, connected punch cost, rapid-chain fatigue, passive recovery, body damage reducing recovery, head damage increasing stun, localized guard depletion, bounded rest recovery and all outputs remaining finite when delta is zero or negative.

- [ ] **Step 2: Run the condition test and confirm RED**

Run: `C:/Users/Luis Duran/Desktop/Godot.exe --headless --path . --script boxing/tests/condition_model_test.gd`

Expected: exit 1 because `ConditionModel` is missing.

- [ ] **Step 3: Implement ConditionModel and delegate legacy models**

Make `ConditionModel` authoritative; retain `TacticalFatigue` and `InjurySystem` as focused helpers for fatigue curves and persistent injury/treatment.

- [ ] **Step 4: Run targeted and complete combat tests**

Expected: exit 0 with no NaN/INF values and no regression in knockdown or round recovery.

- [ ] **Step 5: Commit**

```bash
git add boxing/combat/condition_model.gd boxing/combat/fatigue_model.gd boxing/combat/injury_system.gd boxing/characters/fighter.gd boxing/tests/condition_model_test.gd
git commit -m "feat: unify fighter condition simulation"
```

### Task 4: Implement five-band distance and ring-aware footwork

**Files:**
- Create: `boxing/combat/footwork_controller.gd`
- Create: `boxing/combat/ring_awareness.gd`
- Create: `boxing/tests/footwork_test.gd`
- Modify: `boxing/combat/distance_system.gd`
- Modify: `boxing/characters/fighter.gd:37,52-55,249-333`
- Modify: `boxing/arena/ring.gd:53-108`

**Interfaces:**
- Consumes: input vector, fighter/opponent transforms, condition snapshot and `RingAwareness.sample(position: Vector3) -> Dictionary`.
- Produces: `DistanceSystem.classify(distance: float) -> CombatTypes.RangeBand`, `FootworkController.solve(delta: float, input: Vector2, self_transform: Transform3D, opponent_position: Vector3, condition: Dictionary, ring: Dictionary) -> Dictionary`, and `RingAwareness.escape_vector(position: Vector3) -> Vector3`.
- Solver result keys: `velocity`, `facing_basis`, `locomotion_blend`, `pivot`, `near_ropes`, `near_corner`.

- [ ] **Step 1: Write failing footwork tests**

Assert exact classification boundaries for OUT_OF_RANGE/LONG/MID/POCKET/TOO_CLOSE; acceleration and deceleration rather than instantaneous speed; lateral circling; smooth facing; pivot direction; speed loss under fatigue; inward escape vectors at each rope/corner; and finite zero velocity for overlapping fighters or non-positive delta.

- [ ] **Step 2: Run the footwork test and confirm RED**

Run: `C:/Users/Luis Duran/Desktop/Godot.exe --headless --path . --script boxing/tests/footwork_test.gd`

Expected: exit 1 because the new controllers are missing.

- [ ] **Step 3: Implement range, ring sampling and footwork solver**

Use world-space target direction and tangent vectors, then convert input relative to the target. Reconcile velocity through `move_and_slide`; never teleport to enforce ring boundaries.

- [ ] **Step 4: Run footwork and complete combat tests**

Expected: all exit 0; the existing fight remains playable and fighters cannot cross rope collision.

- [ ] **Step 5: Commit**

```bash
git add boxing/combat/footwork_controller.gd boxing/combat/ring_awareness.gd boxing/combat/distance_system.gd boxing/characters/fighter.gd boxing/arena/ring.gd boxing/tests/footwork_test.gd
git commit -m "feat: add ring-aware 360 footwork"
```

### Task 5: Build the layered animation controller and full-body punch definitions

**Files:**
- Create: `boxing/characters/combat_animation_controller.gd`
- Create: `boxing/combat/punch_definition.gd`
- Create: `boxing/tests/animation_controller_test.gd`
- Modify: `boxing/characters/animation_factory.gd`
- Modify: `boxing/combat/punches.gd`
- Modify: `boxing/characters/fighter.gd:51-69,77-183,334-351`
- Modify: `boxing/characters/boxer_model.tscn`

**Interfaces:**
- Consumes: state, locomotion blend, condition snapshot, selected `PunchDefinition`, reaction offset and current Skeleton3D.
- Produces: `CombatAnimationController.configure(model: Node3D) -> void`, `play_action(name: StringName, speed: float = 1.0) -> bool`, `set_locomotion(blend: Vector2)`, `set_condition(condition: Dictionary)`, `apply_reaction(offsets: Dictionary)`, `has_action(name: StringName) -> bool`; `PunchDefinition.from_dictionary(name, data) -> PunchDefinition` with preparation, active, recovery, hand, trajectory, preferred range, zone, commitment and movement tags.

- [ ] **Step 1: Write failing animation tests**

Test that every punch definition has ordered non-negative phases; jab recovers faster and costs less than cross; locomotion and upper-body action can coexist; fatigue lowers action speed within a safe floor; missing clips return `false`, emit one diagnostic and return to neutral; and all existing boxer resources can configure the controller.

- [ ] **Step 2: Run the animation test and confirm RED**

Run: `C:/Users/Luis Duran/Desktop/Godot.exe --headless --path . --script boxing/tests/animation_controller_test.gd`

Expected: exit 1 because the controller and resource type are missing.

- [ ] **Step 3: Implement layered controller and rebuild procedural clips**

Create lower-body locomotion, upper-body action and additive breathing/reaction layers. Re-author jab and cross first with shoulder protection, hip/torso rotation, weight shift and distinct recovery; preserve safe procedural fallbacks for the other actions until Task 6.

- [ ] **Step 4: Run targeted, import and complete combat tests**

Run the animation test, then launch `Godot.exe --headless --path . --editor --quit`, then run `combat_test.gd`.

Expected: all exit 0 with no missing-resource or invalid-track errors.

- [ ] **Step 5: Commit**

```bash
git add boxing/characters/combat_animation_controller.gd boxing/combat/punch_definition.gd boxing/characters/animation_factory.gd boxing/combat/punches.gd boxing/characters/fighter.gd boxing/characters/boxer_model.tscn boxing/tests/animation_controller_test.gd
git commit -m "feat: add layered combat animation"
```

### Task 6: Complete contextual punches, defense, feints and counters

**Files:**
- Create: `boxing/combat/punch_controller.gd`
- Create: `boxing/combat/defense_controller.gd`
- Create: `boxing/tests/action_controller_test.gd`
- Modify: `boxing/combat/punches.gd`
- Modify: `boxing/characters/animation_factory.gd`
- Modify: `boxing/characters/fighter.gd:197-244,352-369`
- Modify: `boxing/managers/input_setup.gd`
- Modify: `project.godot:80-204`

**Interfaces:**
- Consumes: combat snapshot, input action, punch catalog, condition model and state machine.
- Produces: `PunchController.request(name: StringName, snapshot: Dictionary) -> Dictionary`, `variant_for(name, snapshot) -> StringName`, `DefenseController.request(action: StringName, snapshot: Dictionary) -> Dictionary`, `evaluate(incoming_hit: Dictionary, snapshot: Dictionary) -> Dictionary`, and `counter_window() -> Dictionary`.
- Action result keys: `accepted`, `variant`, `cost`, `state`, `duration`, `tags`, `counter_window`.

- [ ] **Step 1: Write failing action-controller tests**

Cover static/stepping/retreating/lateral jab, advancing/body/counter cross, head/body hooks, left/right uppercuts, weak/committed variants, range rejection, stamina rejection, whiff recovery, localized high/low block, slip/weave/duck/lean/pivot/parry timing, early feint cancellation, committed cross refusing late cancellation and one buffered combo action.

- [ ] **Step 2: Run the action test and confirm RED**

Run: `C:/Users/Luis Duran/Desktop/Godot.exe --headless --path . --script boxing/tests/action_controller_test.gd`

Expected: exit 1 because both controllers are missing.

- [ ] **Step 3: Implement contextual action selection and complete procedural actions**

Keep selection deterministic for a supplied snapshot. Counters require an explicit exposure window created by defense, whiff or recovery. Add only the input actions needed by these approved mechanics.

- [ ] **Step 4: Run action, animation and complete combat tests**

Expected: all exit 0; every registered attack has a definition, animation/fallback and reachable input or AI action.

- [ ] **Step 5: Commit**

```bash
git add boxing/combat/punch_controller.gd boxing/combat/defense_controller.gd boxing/combat/punches.gd boxing/characters/animation_factory.gd boxing/characters/fighter.gd boxing/managers/input_setup.gd project.godot boxing/tests/action_controller_test.gd
git commit -m "feat: complete contextual boxing actions"
```

### Task 7: Resolve physical contact, reactions and bounded hit history

**Files:**
- Create: `boxing/combat/contact_resolver.gd`
- Create: `boxing/combat/reaction_controller.gd`
- Create: `boxing/tests/contact_resolver_test.gd`
- Modify: `boxing/characters/active_ragdoll.gd`
- Modify: `boxing/combat/damage_accumulator.gd`
- Modify: `boxing/characters/fighter.gd:158-183,370-465`

**Interfaces:**
- Consumes: `HitData`, punch definition, defender snapshot and swept-shape samples.
- Produces: `ContactResolver.classify(hit: Dictionary, attack: Resource, defender: Dictionary) -> int`, `damage_multiplier(result: int) -> float`, `accept_once(attacker_id: int, victim_id: int, attack_id: int) -> bool`, `finish_attack(attacker_id, attack_id)`, and `ReactionController.apply(hit, result, condition) -> Dictionary`.
- Reaction keys: `bone_offsets`, `linear_impulse`, `angular_impulse`, `stun`, `balance_loss`, `knockdown_family`.

- [ ] **Step 1: Write failing contact tests**

Use literal fixtures for MISS, GRAZE, BLOCKED, PARTIAL, CLEAN, COUNTER and HEAVY_CLEAN; verify range/trajectory effects, sweep tunneling protection, one hit per attack/victim, stale victim rejection, finite impulses for zero velocity/overlap, directional head/body reactions, guard absorption, knockdown family selection and bounded history after 10,000 attacks.

- [ ] **Step 2: Run the contact test and confirm RED**

Run: `C:/Users/Luis Duran/Desktop/Godot.exe --headless --path . --script boxing/tests/contact_resolver_test.gd`

Expected: exit 1 because the resolver is missing.

- [ ] **Step 3: Implement contact classification and migrate Fighter hit processing**

Key duplicate history by active attack and erase it at recovery; do not retain an unbounded global dictionary. Apply condition, visual damage and reaction only after resolver acceptance.

- [ ] **Step 4: Run contact, action and complete combat tests**

Expected: all exit 0; physical punches still connect at valid range and never damage twice from one attack.

- [ ] **Step 5: Commit**

```bash
git add boxing/combat/contact_resolver.gd boxing/combat/reaction_controller.gd boxing/characters/active_ragdoll.gd boxing/combat/damage_accumulator.gd boxing/characters/fighter.gd boxing/tests/contact_resolver_test.gd
git commit -m "feat: classify contacts and drive reactions"
```

### Task 8: Add tactical ring pressure and six adaptive AI styles

**Files:**
- Create: `boxing/ai/boxing_perception.gd`
- Create: `boxing/ai/style_profile.gd`
- Create: `boxing/tests/boxing_brain_test.gd`
- Modify: `boxing/ai/boxing_brain.gd`
- Modify: `boxing/combat/momentum_system.gd`
- Modify: `boxing/main.gd:13-70`

**Interfaces:**
- Consumes: immutable self/opponent combat snapshots, ring sample, score, observed events and seeded `RandomNumberGenerator`.
- Produces: `BoxingPerception.observe(...) -> Dictionary`, `StyleProfile.for_name(name: StringName) -> Dictionary`, `BoxingBrain.choose_action(perception: Dictionary) -> Dictionary`, `record_event(event: Dictionary)`, and six profiles `OUTBOXER`, `PRESSURE_FIGHTER`, `COUNTER_PUNCHER`, `BRAWLER`, `DEFENSIVE_BOXER`, `BOXER_PUNCHER`.

- [ ] **Step 1: Write failing AI tests**

For fixed seeds, assert each style's distinguishing priorities; pressure fighters cut off a corner instead of following; outboxers seek long range; counter punchers wait for exposure; body punishment increases body defense; repeated player exits alter ring-cut direction; losing late increases safe aggression; reaction latency prevents same-tick input reading; error probability produces at least one non-optimal response in a fixed sample; and freed targets produce IDLE safely.

- [ ] **Step 2: Run the AI test and confirm RED**

Run: `C:/Users/Luis Duran/Desktop/Godot.exe --headless --path . --script boxing/tests/boxing_brain_test.gd`

Expected: exit 1 because perception and six profiles are missing.

- [ ] **Step 3: Implement perception, style profiles and adaptive decision scoring**

Score legal actions from snapshot data; introduce difficulty-scaled observation delay and bounded noise before selection. Never query the player's live input state.

- [ ] **Step 4: Run AI and complete combat tests**

Expected: all exit 0; the endurance scene can assign a brain to both fighters without state cancellation regressions.

- [ ] **Step 5: Commit**

```bash
git add boxing/ai/boxing_perception.gd boxing/ai/style_profile.gd boxing/ai/boxing_brain.gd boxing/combat/momentum_system.gd boxing/main.gd boxing/tests/boxing_brain_test.gd
git commit -m "feat: add adaptive boxing AI styles"
```

### Task 9: Separate rules, referee, scoring and corner recovery

**Files:**
- Create: `boxing/rules/fight_rules.gd`
- Create: `boxing/rules/score_engine.gd`
- Create: `boxing/rules/referee_controller.gd`
- Create: `boxing/tests/fight_rules_test.gd`
- Modify: `boxing/managers/fight_director.gd`
- Modify: `boxing/arena/ring.gd:155-181`
- Modify: `boxing/ui/corner_panel.gd`

**Interfaces:**
- Consumes: round events, condition snapshots, configured round/knockdown rules and corner treatment.
- Produces: `ScoreEngine.score_round(events: Array) -> Dictionary`, `FightRules.evaluate(event, state) -> Dictionary`, `RefereeController.update(delta, fighters, rules_state) -> Dictionary`, and `CornerPanel.build_report(fighter, opponent, events) -> Dictionary`.
- Rules result keys: `phase`, `count`, `separate`, `winner_id`, `method`, `reason`.

- [ ] **Step 1: Write failing rules tests**

Cover 10-9/10-8 scoring, configurable three-knockdown rule, count pause, legal get-up, count-ten KO, medical TKO, round decision, draw, clinch separation/cooldown, freed fighter during transition, limited rest recovery, treatment limits and advice derived from recorded patterns.

- [ ] **Step 2: Run the rules test and confirm RED**

Run: `C:/Users/Luis Duran/Desktop/Godot.exe --headless --path . --script boxing/tests/fight_rules_test.gd`

Expected: exit 1 because rules modules are missing.

- [ ] **Step 3: Implement rules modules and reduce FightDirector to orchestration**

Use fighter instance IDs in stored events and resolve live nodes only at the presentation boundary. Keep phase transitions deterministic and idempotent.

- [ ] **Step 4: Run rules and complete flow tests**

Expected: all exit 0 with existing HUD/result consumers still receiving compatible phase and result signals.

- [ ] **Step 5: Commit**

```bash
git add boxing/rules/fight_rules.gd boxing/rules/score_engine.gd boxing/rules/referee_controller.gd boxing/managers/fight_director.gd boxing/arena/ring.gd boxing/ui/corner_panel.gd boxing/tests/fight_rules_test.gd
git commit -m "feat: modularize boxing rules and referee"
```

### Task 10: Upgrade combat feedback, HUD and PC-only presentation

**Files:**
- Create: `boxing/presentation/combat_feedback.gd`
- Create: `boxing/tests/presentation_test.gd`
- Modify: `boxing/managers/sound.gd`
- Modify: `boxing/arena/fight_camera.gd`
- Modify: `boxing/ui/hud.gd`
- Modify: `boxing/ui/corner_panel.gd`
- Modify: `boxing/arena/studio_environment.gd`
- Modify: `boxing/arena/ring.gd`
- Modify: `project.godot`
- Create: `assets/ATTRIBUTION.md`

**Interfaces:**
- Consumes: typed combat events and condition/rules snapshots.
- Produces: `CombatFeedback.present(event: Dictionary) -> void`, with result-specific audio layer, camera impulse, impact effect, crowd response and optional HUD callout; `set_reduced_motion(enabled: bool)` and `set_camera_shake(scale: float)`.

- [ ] **Step 1: Write failing presentation tests**

Assert that all seven contact results map to distinct feedback profiles; heavy clean exceeds clean but respects shake/volume caps; blocked uses guard feedback; missing audio/effect falls back once without error; reduced motion disables hit-stop and lowers shake; HUD reads condition snapshots rather than mutable internals; and mobile controls are absent in PC configuration.

- [ ] **Step 2: Run the presentation test and confirm RED**

Run: `C:/Users/Luis Duran/Desktop/Godot.exe --headless --path . --script boxing/tests/presentation_test.gd`

Expected: exit 1 because `CombatFeedback` is missing.

- [ ] **Step 3: Implement feedback profiles and PC presentation settings**

Pool repeated effects, cap simultaneous voices/particles and preserve accessibility settings. Add asset attribution entries before committing any third-party file.

- [ ] **Step 4: Run presentation, import and complete combat tests**

Expected: all exit 0 with no missing resources; project settings no longer expose mobile-only combat UI.

- [ ] **Step 5: Commit**

```bash
git add boxing/presentation/combat_feedback.gd boxing/managers/sound.gd boxing/arena/fight_camera.gd boxing/ui/hud.gd boxing/ui/corner_panel.gd boxing/arena/studio_environment.gd boxing/arena/ring.gd project.godot assets/ATTRIBUTION.md boxing/tests/presentation_test.gd
git commit -m "feat: upgrade PC combat presentation"
```

### Task 11: Add integrated acceptance, endurance and performance gates

**Files:**
- Create: `boxing/tests/combat_2_acceptance.gd`
- Create: `boxing/tests/combat_2_acceptance.tscn`
- Create: `boxing/tests/performance_budget.gd`
- Modify: `boxing/tests/endurance.gd`
- Modify: `boxing/tests/endurance.tscn`
- Modify: `boxing/tests/combat_test.gd`
- Modify: `boxing/tests/visual_test.gd`
- Modify: `export_presets.cfg`

**Interfaces:**
- Consumes: all modules and public coordinator interfaces from Tasks 1–10.
- Produces: machine-readable `boxing/tests/combat_2_report.json` containing test failures, runtime errors, average FPS, p95 frame time, node-count delta, effect-pool high-water marks and action/contact coverage.

- [ ] **Step 1: Write the failing integrated acceptance assertions**

Script deterministic scenarios for locomotion and pivot, jab/cross at slow motion, every punch family and range, every defense and counter window, all contact results, fatigue/condition changes, rope/corner escape, clinch break, each AI style, knockdown/get-up/KO/TKO/decision and a 20-minute accelerated endurance fight. Assert zero stuck states, zero runtime errors, bounded nodes/hit history/effects and report schema completeness.

- [ ] **Step 2: Run acceptance and confirm RED**

Run: `C:/Users/Luis Duran/Desktop/Godot.exe --headless --path . --script boxing/tests/combat_2_acceptance.gd`

Expected: exit 1 until every required scenario and report field is implemented.

- [ ] **Step 3: Implement the acceptance scene, performance sampler and PC export preset**

Measure a reproducible release-mode reference scene after a warm-up. Record 60 FPS as the pass target; report the actual p95 frame time and any hardware caveat instead of hiding misses.

- [ ] **Step 4: Run the complete verification matrix**

Run the complete combat suite command above, then:

```powershell
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --script boxing/tests/combat_2_acceptance.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . boxing/tests/endurance.tscn
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --editor --quit --log-file 'combat_2_import.log'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --export-release 'Windows Desktop' 'build/BoxinSSJJ.exe'
```

Expected: every command exits 0, report shows zero failures/errors/leaks, average FPS is at least 60 in the reference run, and the PC executable is produced.

- [ ] **Step 5: Perform visual acceptance in the running project**

Inspect at normal speed and 0.25×: foot planting, facing, jab/cross weight transfer, guard return, miss/blocked/partial/clean/counter/heavy-clean readability, fatigue posture, rope/corner behavior and knockdown recovery. Record any failure as a new test before fixing it.

- [ ] **Step 6: Commit**

```bash
git add boxing/tests/combat_2_acceptance.gd boxing/tests/combat_2_acceptance.tscn boxing/tests/performance_budget.gd boxing/tests/endurance.gd boxing/tests/endurance.tscn boxing/tests/combat_test.gd boxing/tests/visual_test.gd export_presets.cfg
git commit -m "test: gate Combat 2.0 release quality"
```

### Task 12: Remove compatibility shims and document asset decisions

**Files:**
- Modify: `boxing/characters/fighter.gd`
- Modify: `boxing/ai/boxing_brain.gd`
- Modify: `boxing/managers/fight_director.gd`
- Modify: `boxing/ui/hud.gd`
- Modify: `boxing/main.gd`
- Modify: `assets/ATTRIBUTION.md`
- Create: `docs/combat-2-architecture.md`
- Test: all `boxing/tests/*_test.gd` and `boxing/tests/combat_2_acceptance.gd`

**Interfaces:**
- Consumes: the stabilized module APIs from Tasks 1–11.
- Produces: final coordinator wiring with no duplicate state authority and an architecture/asset record for future maintainers.

- [ ] **Step 1: Add regression assertions for single ownership**

Extend acceptance tests so condition, state and contact values originate from their modules and legacy mirrors cannot diverge after attack, hit, rest, knockdown or round transition.

- [ ] **Step 2: Run acceptance and confirm RED against at least one remaining mirror**

Expected: exit 1 identifying a duplicated source of truth.

- [ ] **Step 3: Remove obsolete compatibility fields and migrate remaining consumers**

Keep only intentional read-only compatibility accessors. Document module ownership, event flow, extension points, performance budgets and the keep/replace decision for the original rig with measured evidence.

- [ ] **Step 4: Run fresh full verification and inspect Git diff**

Expected: all tests, import, endurance, acceptance and PC export exit 0; `git diff --check` reports no whitespace errors; unrelated user changes are absent from staged files.

- [ ] **Step 5: Commit**

```bash
git add boxing/characters/fighter.gd boxing/ai/boxing_brain.gd boxing/managers/fight_director.gd boxing/ui/hud.gd boxing/main.gd assets/ATTRIBUTION.md docs/combat-2-architecture.md boxing/tests
git commit -m "refactor: finalize Combat 2.0 architecture"
```
