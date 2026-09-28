# Corrección de los tres fallos de contacto — 28 septiembre 2026

Los fallos de right_hook, right_uppercut y body_jab eran de daño, no de detección: los tres registraban hit_landed, pero la vida del defensor aumentaba. El diagnóstico registró respectivamente daños de -3,3514, -1,6621 y -0,6014.

En fighter.gd, receive_hit interpolaba el factor de roce entre 0,35 y 0,85 con (accuracy - 0,6) / 0,12. La precisión de un contacto real puede ser inferior a 0,6; lerpf extrapolaba por debajo de cero y producía daño negativo. Se limita únicamente el peso de interpolación a [0,1]. Los roces débiles mantienen daño reducido positivo; la detección física, retarget, hitboxes, alcance, duración y locomoción permanecen sin cambios en esta corrección.

Respaldo previo: backups/contact-20260928/fighter.gd y combat_test.gd. No se modificó combat_test.gd.

Prueba nueva: boxing/tests/glancing_contact_test.gd. Ejecuta receive_hit real para los tres golpes con ocho valores de precisión (24 casos) y comprueba además que repetir el ID de impacto no dañe dos veces. Antes fallaban nueve casos con curación; después, cero.

Validación posterior:

- combat_test: COMBAT + FLOW TEST FAILURES: 0 (los tres fallos resueltos sin cambiar la prueba).
- glancing_contact_test: 0 fallos.
- retarget_test y retarget_integration_test: 0 fallos.
- bootstrap_test, condition_model_test, contracts_test y state_machine_test: 0 fallos.

Logs: boxing/tools/diagnose_contacts_damage.log, glancing_contact_before.log, glancing_contact_after.log, contact_combat_after.log y contact_verify_*.log.

Persiste el aviso ambiental del motor Failed to read the root certificate store, presente antes del cambio. Las dos pruebas antiguas reach_test/pose_test con propiedades inexistentes descritas en retarget-fix-20260928.md no se modificaron ni se cuentan como aprobadas en este trabajo.

Reproducción: ejecutar Godot --headless --path . --script boxing/tests/glancing_contact_test.gd y repetir con boxing/tests/combat_test.gd.
