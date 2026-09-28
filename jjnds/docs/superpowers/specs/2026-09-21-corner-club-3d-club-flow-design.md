# Corner Club: flujo completo de Club 3D

## Objetivo

Unificar carrera, quick fight y entrenamiento en un club 3D navegable. Toda pelea debe abrir el combate actual `boxing/main.tscn`, con sus sistemas de física activa, daño visual, perfiles y fatiga; el flujo legado `scenes/arena/fight_3d.tscn` deja de ser destino de juego.

## Alcance

- `ClubHub3D` será el punto de entrada y contendrá estaciones interactivas para Carrera, Quick Fight y Entrenamiento.
- Cada estación usa geometría y paneles 3D diegéticos: tablón de contratos, pizarra de selección y zona de saco.
- Carrera transmite el perfil de carrera y rival a `GameManager`, y abre el combate actual.
- Quick Fight permite seleccionar jugador, rival, rounds y estilo de IA, y abre el mismo combate actual.
- Entrenamiento es un gimnasio 3D con saco suspendido, reacción física visual y objetivos de combinaciones.
- HUD de combate y entrenamiento puede seguir siendo `Control` superpuesto para legibilidad; no habrá una escena de menú 2D como flujo principal.

## Arquitectura

### Hub

`club_hub_3d.tscn` contiene cámara, iluminación, un modelo de ring, un área para el saco y tres `Area3D` de interacción. `club_hub_3d.gd` resuelve foco de estación por proximidad/raycast, muestra una tarjeta 3D asociada y ejecuta la acción mediante entradas existentes. La cámara se desplaza suavemente a la estación seleccionada, sin movimiento libre que pueda desorientar.

### Contexto de pelea

`GameManager` será la única fuente de contexto de una pelea. Expone modo (`career` o `quick`), `player_profile`, `enemy_profile`, rounds y estilo. `boxing/main.gd` consume esos perfiles cuando están presentes y mantiene sus actuales valores por defecto sólo si se entra directamente a la escena para pruebas.

Carrera reutiliza `CareerManager.get_next_opponent()` y persiste resultado al terminar. Quick Fight crea contexto no persistente. Ningún botón de carrera, cinemática o resultado apuntará a `fight_3d.tscn`.

### Entrenamiento

`heavy_bag_3d.tscn` crea al luchador actual usando `Fighter`, desactiva rival/round manager y añade `HeavyBag3D`. El saco es un `RigidBody3D` con límite de oscilación y una `Area3D` objetivo. Recibe los eventos de golpe reales del luchador, reproduce impulso proporcional a velocidad/fatiga y evalúa una cola de golpes con una ventana de tiempo. La primera rutina es `uppercut → jab → cross`; la UI muestra progreso, grado y tiempo restante como overlay.

### Contenido 3D

Se usarán primitivas de Godot y materiales procedurales para el gimnasio, paneles, ring y saco; no se depende de assets premade. Los textos de estación emplean `Label3D`/meshes para que formen parte del espacio. La referencia aporta composición: saco cercano, cámara posterior, área de entrenamiento luminosa y objetivo de combo.

## Datos y errores

- Si no existe carrera guardada, la estación abre creación de carrera 3D con perfil inicial por defecto.
- Si un perfil no carga, el hub conserva selección previa y presenta error 3D sin abrir combate.
- Si el saco no recibe impacto válido, no avanza la cadena ni consume recompensa.
- El retorno después de pelea/campamento usa el contexto de `GameManager` para volver al hub o carrera, nunca a una escena 2D.

## Pruebas de aceptación

- Carrera y Quick Fight cargan `boxing/main.tscn` y entregan ambos perfiles correctos.
- El combate directo continúa usando perfiles por defecto y la suite de combate queda verde.
- Un saco sólo contabiliza impactos reales y `uppercut → jab → cross` completa una vez en orden y dentro de la ventana.
- Un golpe fuera de orden reinicia la cadena.
- El hub carga sin referencias al destino legado `fight_3d.tscn` en rutas de juego.

## Fuera de alcance

- Movimiento libre por una ciudad o modo online.
- Rehacer modelos de boxeador/gimnasio desde un DCC.
- Sustituir el HUD de combate por HUD enteramente diegético en esta iteración.
