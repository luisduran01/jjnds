# Brazos abiertos al volver a locomoción — 28 septiembre 2026

La captura del usuario se reprodujo en boxing/main.tscn con los dos boxeadores en idle y el AnimationTree activo. El arreglo anterior solo había corregido golpes: boxing_idle y las cuatro direcciones seguían usando rotaciones locales incompatibles y carecían de pistas válidas para ForeArm. Al volver UpperBody a cero, reaparecían brazos abiertos y codos sin flexionar.

Cambios de producción:
- import_locomotion_animations.gd: sustituye únicamente los tracks de torso/cuello/cabeza/brazos por la conversión global ya validada; mantiene la transferencia existente de la parte inferior. Añade el FBX al SceneTree para que el muestreo actualice poses globales.
- import_punch_animations.gd: retarget_action pasa a static para reutilizarlo sin crear otro SceneTree ni ejecutar su importación.
- boxer_model.tscn: cinco clips de locomoción regenerados con torso y brazos corregidos.

Respaldo: backups/locomotion-arms-20260928/. No se cambiaron fighter.gd, las hitboxes, alcance, daño ni los FBX en esta corrección.

Pruebas:
- locomotion_arms_test: compara 60 poses por cada uno de los cinco clips con los FBX reproducidos por AnimationPlayer. Antes: cinco fallos, errores máximos 81,25° / 93,55° / 90,60° / 146,78° / 128,49°. Después: cero fallos, error máximo 0,037°.
- locomotion_preservation_test: pistas anteriores de cadera/piernas y todos los clips ajenos a la locomoción idénticos al respaldo, cero fallos.
- retarget_test, retarget_integration_test, glancing_contact_test, bootstrap_test, condition_model_test, contracts_test, state_machine_test: cero fallos.
- combat_test: COMBAT + FLOW TEST FAILURES: 0.
- Captura renderizada de la escena real: boxing/tests/guard_runtime_before.png reproduce los brazos extendidos; guard_runtime_after.png confirma codos flexionados y manos en guardia con el AnimationTree activo. Generador reproducible: boxing/tools/capture_guard_runtime.tscn; argumento de usuario --before selecciona el nombre de la imagen anterior, no restaura recursos.

Los informes anteriores describen el estado de aquella intervención; la afirmación de que todos los tracks de locomoción quedaron idénticos ya no aplica a torso/brazos, que se corrigen aquí. La comprobación actual de preservación es locomotion_preservation_test.gd. El script diagnóstico antiguo verify_locomotion_unchanged.gd compara contra el respaldo original y detectará estas modificaciones intencionales.

Persisten los avisos ambientales de certificados y caché de shaders descritos previamente. No se observaron nuevos errores GDScript en las pruebas ejecutadas. reach_test y pose_test obsoletos no forman parte de los resultados aprobados.

Para ver los cambios en una partida ya iniciada, detenerla y ejecutarla de nuevo: la instancia en memoria no sustituye por sí sola la biblioteca de animaciones guardada.
