# Corner Club: combate dinámico — diseño técnico

## Objetivo

Transformar el combate actual de Corner Club en un prototipo donde la postura reacciona físicamente a los impactos, el daño queda visible y acumulado, cada boxeador deriva de un perfil corporal paramétrico y la stamina gobierna la capacidad ofensiva y defensiva real.

## Alcance aprobado

- Godot 4.7; no descargar ni depender de assets que simulen estos sistemas.
- Dos boxeadores simultáneos, con la cámara actual y el renderer Compatibility.
- Ragdoll activo parcial: pelvis, columna, pecho, cuello, cabeza, brazos y antebrazos. Las piernas conservan animación/cinemática para mantener el desplazamiento estable.
- Daño visual procedural y persistente durante el combate mediante un atlas de regiones de bajo coste.
- Variación paramétrica basada en el rig y malla comunes existentes, con límites anatómicos explícitos.
- Stamina como factor de animación, daño, drive físico, guardia, recuperación y toma de decisiones de IA.

## Arquitectura

### Perfil corporal

`BoxerBodyProfile` deriva `height_scale`, `arm_scale`, `leg_scale`, `torso_width`, `torso_depth`, `muscle_mass` y `head_scale` de altura, alcance y peso. Limita cada valor a rangos seguros. `Fighter` aplicará el perfil al `Skeleton3D`, la cápsula, los `BoneAttachment3D` de puños y las hitboxes, de modo que el alcance de juego coincida con el visual.

Las escalas locales se aplicarán de forma simétrica a pares de extremidades. La altura global estará separada de la longitud de segmentos. El perfil no modifica la topología ni genera mallas nuevas. El rig seguirá siendo el único `boxer_rigged.glb` compartido.

### Ragdoll activo parcial

`ActiveRagdollController` crea cuerpos físicos y joints sólo para el tren superior. Cada tick de física recibe la pose objetivo producida por `AnimationTree` y usa un controlador proporcional-derivativo para calcular torque hacia ella. El controlador expone `stiffness`, `damping` y `max_torque` por hueso.

`Fighter.receive_hit` calculará `HitData`: zona, posición mundial, dirección atacante→víctima, potencia, bloqueo y factor de stamina. El controlador selecciona el hueso más próximo a la zona, reparte impulso lineal y angular entre ese hueso, sus ancestros y el torso, y baja transitoriamente la rigidez. El bloqueo alto/corporal absorbe más impulso y conserva más rigidez. No se usarán clips de reacción como fuente de la desviación; los clips actuales sólo serán la pose objetivo que el drive intenta recuperar.

Para evitar inestabilidad, no se activan colisiones entre huesos del mismo boxeador, se limitan los impulsos, y se usa una transición suave de control cinemático a físico en knockdown. La primera versión excluye pies, manos y dedos del solver.

### Daño visual

`DamageAccumulator` mantiene por boxeador una matriz/atlas 256×256 con canales para hematoma, corte y swelling. Un impacto se proyecta a una región lógica (`head_left`, `head_right`, `head_center`, `body_left`, `body_right`) y estampa un círculo con radio e intensidad dependientes de `HitData`. Los datos persistirán hasta terminar el combate y podrán decaer lentamente sólo durante descanso.

Un `SubViewport` actualiza el atlas únicamente al recibir impactos. Un `ShaderMaterial` de piel toma la textura dinámica, combina color de hematoma, máscara de corte y normal/detail procedural. La hinchazón inicial será una deformación de vértices muy pequeña, protegida por máscara, para mantener compatibilidad; el shader expone el mismo canal para sustituirlo más adelante por blend shapes faciales preparadas desde arte.

### Fatiga táctica

`FatigueModel` separa energía inmediata de fatiga acumulada. Cada acción registra coste según golpe, velocidad, masa y cadena. La energía afecta `AnimationNodeTimeScale`, velocidad de movimiento, daño y máximo torque; la fatiga degrada recuperación, precisión de guardia, rigidez del drive y tiempo de reacción de IA. Una pausa entre golpes reduce fatiga más rápido que una cadena; bloquear y recibir golpes al cuerpo modifican la recuperación.

`Punches.damage` seguirá siendo determinista, pero recibirá los multiplicadores de fatiga y masa. Los valores de stamina del perfil se cargarán en el luchador activo, en lugar de quedar sólo en recursos de menú.

## Flujo de datos

`BoxerData` → `BoxerBodyProfile` y `FatigueModel` → configuración de rig/hitboxes y parámetros de combate.

Impacto de puño → `HitData` → salud/guardia/stamina, `ActiveRagdollController.apply_hit`, `DamageAccumulator.stamp` y HUD.

Cada `_physics_process` → `AnimationTree` produce pose objetivo → drive PD recibe pose + factores de fatiga → cuerpos físicos actualizan la desviación visible.

## Rendimiento y límites

- Máximo diez cuerpos físicos activos por boxeador; actualizar drives a física fija.
- Atlas 256×256 por boxeador y redibujado sólo ante impactos/decay programado; sin lecturas GPU→CPU.
- Sin sombras extra, sin decals por impacto, ni recomputar malla en CPU.
- Exponer contadores de cuerpos, stamps y tiempo de física en el panel debug actual.
- Si el frame time excede el presupuesto, reducir primero frecuencia de daño visual y torque máximo, nunca la detección de golpe.

## Pruebas y aceptación

- Un perfil alto/de brazos largos desplaza puños y alcance sin salir de límites establecidos.
- Un impacto lateral en cabeza produce impulso angular distinto de un impacto frontal; un bloqueo reduce ambos.
- Stamina baja reduce escala de acción, daño y torque; una cadena rápida acumula más fatiga que acciones espaciadas.
- Dos impactos en la misma región aumentan su acumulación; zonas diferentes no se pisan en el atlas lógico.
- La suite de combate existente continúa verde y la escena de prueba carga dos luchadores sin errores.

## No objetivos

- Ragdoll completo de piernas/pies en esta iteración.
- Generación de topología, ropa o caras completamente nuevas.
- Persistencia del daño entre peleas o modo carrera.
- Red multijugador/rollback.
