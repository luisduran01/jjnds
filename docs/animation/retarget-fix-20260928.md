# Corrección de retarget de golpes — 28 septiembre 2026

## Resultado y causa comprobada

El recurso guardado cross tenía 11 pistas de rotación. El FBX importado tiene 52, una pista de posición Hips y ninguna pista SCALE_3D. Los demás golpes tienen 51–52 rotaciones y solo posición Hips: no había traslaciones de brazos que estiraran los segmentos.

El boxer usa 17 huesos, con bases de reposo identidad. El humanoide Mixamo usa LowerArm/UpperLeg/LowerLeg; el boxer usa ForeArm/Thigh/Shin. El boxer tampoco tiene UpperChest, clavículas ni dedos. Copiar nombres y rotaciones locales pierde codos y transformaciones de padres ausentes. Cross guardado ni siquiera coincide con lo que produciría la versión actual del importador: había sido generado con otra versión que descartaba huesos no encontrados.

Los FBX idle y cross inspeccionados comparten el mismo esquema de reposo humanoide. La fórmula anterior target_local_rest.inverse() * source_local_rest * rotation no transforma correctamente entre estas jerarquías. En Godot 4 las rotaciones de pose ya incluyen el reposo. El buen aspecto de locomoción no garantiza que esa fórmula sea correcta; sus recursos existentes se conservaron íntegros.

## Cambios de producción

- boxing/tools/import_punch_animations.gd: sustituye la copia de pistas por horneado de la pose importada a 60 muestras/segundo. Usa nombres explícitos, Chest toma UpperChest, calcula motion = source_global_pose * inverse(source_global_rest), obtiene target_global = motion * target_global_rest y lo convierte a rotación local respecto al padre objetivo. Así incorpora las clavículas y el tramo extra de torso sin crear huesos ni offsets artificiales. El origen se añade al SceneTree antes de muestrear; fuera del árbol las poses globales no se actualizaban correctamente durante la prueba. Solo emite rotaciones, manteniendo posiciones y escalas del boxer. Hips conserva rotación, sin traslación. El uppercut fuente usa la izquierda: right_uppercut refleja toda la pose y permuta lados, left_uppercut conserva el original.
- boxing/characters/boxer_model.tscn: regenera las 11 acciones declaradas en CLIPS, cada una con 17 pistas válidas. Mantiene los estados existentes. UpperBody incluye Hips para que su rotación llegue al resultado, mientras los tracks locales de las piernas proceden de locomoción. La rotación de Hips también afecta globalmente a sus descendientes, de forma intencional; esto no es un sistema de fijación de pies al suelo.
- boxing/characters/fighter.gd: una condición en línea 399 permite calcular el blend de locomoción desde la velocidad también durante ATTACKING. No cambia las velocidades, distancias, hitboxes ni reglas de daño.

No se modificaron FBX, sus ajustes .import, importador de locomoción ni animation_factory.gd. Fighter consume la escena guardada y no utiliza animation_factory para generar estos golpes.

## Respaldo

backups/retarget-20260928/ contiene los tres archivos de producción tal como estaban antes del cambio, incluyendo modificaciones previas del usuario. .gdignore evita importar copias de scripts.

## Verificación reproducible

Ejecutable utilizado: C:/Users/Luis Duran/Desktop/Godot.exe, versión 4.7.2.stable.official.ed1daf0bf.

Comandos desde la raíz del proyecto:

```powershell
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --script boxing/tools/import_punch_animations.gd
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --script boxing/tests/retarget_test.gd
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --script boxing/tests/retarget_integration_test.gd
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --headless --path . --script boxing/tools/verify_locomotion_unchanged.gd
& 'C:/Users/Luis Duran/Desktop/Godot.exe' --path . --rendering-method gl_compatibility --script boxing/tools/render_retarget.gd
```

En Windows, para esperar al ejecutable gráfico usar Start-Process -Wait -WindowStyle Hidden.

retarget_test reproduce ambos AnimationPlayer directamente, sin AnimationTree, en 61 tiempos por golpe. Compara las direcciones globales de húmero y antebrazo con las del FBX; para right_uppercut usa la referencia reflejada. Verifica además que hombro–mano no supere 0,4801 m y Hips conserve la posición de reposo.

| Golpe | Error angular máximo después |
| --- | ---: |
| jab | 0,018° |
| cross | 0,00014° |
| left_hook | 0,125° |
| right_hook | 0,092° |
| left_uppercut | 0,151° |
| right_uppercut | 0,151° |

Antes del cambio las cinco referencias originales fallaban, con errores de 165–175°. La prueba de uppercut reflejado fallaba por 148° antes de habilitar la reflexión.

retarget_integration_test confirma que los tracks locales de ambas piernas no son sustituidos por el golpe en las cinco posiciones del BlendSpace, que la cadera del golpe sí llega al resultado, que un atacante con velocidad mantiene blend de locomoción y que al terminar vuelve a blend de acción 0. Antes fallaban la locomoción durante el golpe y el filtro de cadera.

verify_locomotion_unchanged compara contra el respaldo: boxing_idle, forward, backward, left y right tienen idéntica duración, loop, pistas, rutas, tiempos y valores de todas las claves.

render_retarget reproduce directamente los seis clips y genera boxing/tests/retarget_comparison.png: inicio, 50% y 95% de cada clip, junto al esqueleto del FBX. Se revisó la captura renderizada con Godot, no la ventana Advanced Import del editor. La equivalencia es de movimiento/orientación adaptada a las proporciones y cadena simplificada del boxer; no puede reproducir articulaciones que el modelo no tiene.

## Suite existente y límites

- bootstrap_test, condition_model_test, contracts_test, state_machine_test: 0 fallos.
- combat_test: tres fallos de contacto (right_hook, right_uppercut, body_jab). Al repetir con la biblioteca de animaciones del respaldo y filtro de cadera anterior daba cinco: los mismos tres más cross y body_cross. La corrección no se ha compensado alterando hitboxes/alcance.
- reach_test tiene un error de script por propiedad Fighter.reach inexistente, aunque imprime un contador 0; no se cuenta como aprobado.
- pose_test tiene un error de script por clave drive inexistente y no termina por sí solo; se detuvo únicamente ese proceso de prueba. No se cuenta como aprobado.
- El motor emite Failed to read the root certificate store incluso en las ejecuciones anteriores a la corrección. En el render también avisa que no puede crear la caché de shaders. No se observaron errores de GDScript en las pruebas nuevas de retarget/integración. No se certifica una sesión interactiva del panel Debugger.

Logs de evidencia: boxing/tools/audit_engine.log, retarget_before.log, retarget_after.log, retarget_integration_before.log, retarget_integration_after.log, baseline_combat.log y verify_*.log.

También se generó y revisó boxing/tests/retarget_moving_comparison.png mediante el mismo script con `-- --moving`: muestra los seis golpes mezclados con forward/left/right. Es una revisión de poses renderizadas, no una certificación de ausencia de deslizamiento de pies en una partida completa.

Referencia técnica contrastada: https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/retargeting_3d_skeletons.html (en Godot 4 Bone Pose incluye Bone Rest).
