# Boxin SSJJ Combat 2.0 — diseño técnico

## Objetivo

Transformar la beta actual en un juego de boxeo 3D para PC donde el jugador controle un boxeador y no una secuencia de animaciones aisladas. El resultado debe conectar postura, distancia, orientación, transferencia de peso, stamina, defensa y situación táctica con cada acción. La implementación conservará los sistemas actuales que aporten valor y sustituirá progresivamente los que impidan alcanzar la calidad buscada.

## Alcance aprobado

- Implementar la hoja de ruta completa de Combat 2.0, excluyendo modo carrera y contenido cosmético que no mejore directamente la pelea.
- Priorizar exclusivamente PC y una pelea estable a 60 FPS en la escena de referencia.
- Permitir nuevos modelos, rigs, animaciones, audio, efectos y recursos técnicos con licencias compatibles con distribución.
- Reemplazar el boxeador y estilo visual actuales cuando el reemplazo produzca una mejora comprobable.
- Mantener compatibilidad con perfiles de boxeador, flujo de pelea y datos útiles mientras cada subsistema migra.
- Trabajar sobre el proyecto existente sin reescribir innecesariamente escenas, reglas o sistemas que ya cumplen su función.

## Estrategia

Se hará una reconstrucción modular e incremental. Cada fase debe dejar una pelea jugable, sin errores de runtime y con pruebas que cubran sus contratos. Las interfaces actuales podrán sobrevivir temporalmente como adaptadores; un sistema antiguo sólo se retirará después de que su reemplazo funcione en la escena laboratorio y en la pelea integrada.

La calidad de jab, cross, locomoción y retorno a guardia actúa como puerta de calidad para el resto del arsenal. No se ampliará contenido si esos fundamentos siguen rígidos o inconsistentes.

## Arquitectura

### Coordinación del luchador

`Fighter` se reducirá a un coordinador que expone la identidad y estado observable del boxeador. Delegará las responsabilidades de combate en componentes con interfaces explícitas. Los adaptadores preservarán las señales y propiedades consumidas por el HUD, la IA y `FightDirector` durante la migración.

### Estado de combate

`CombatStateMachine` gobernará `IDLE`, `MOVE`, `ATTACK`, `DEFEND`, `HURT`, `STUN`, `KNOCKDOWN`, `GET_UP` y `KO`, además de interrupciones, recuperación, buffer de input, fintas y cancelaciones. Toda transición tendrá una causa, una duración o condición de salida y reglas de prioridad. Un clip ausente nunca podrá bloquear el estado.

### Locomoción y ring

`FootworkController` resolverá movimiento 360°, pasos cortos, círculos, diagonales, pivotes, aceleración, desaceleración y orientación suave al rival. `RingAwareness` aportará distancia a cuerdas y esquinas, espacio de escape, presión y rutas para cortar el ring. La stamina, el daño y el espacio modificarán velocidad, estabilidad y capacidad de pivotar sin anular el control.

### Animación corporal

`CombatAnimationController` centralizará `AnimationTree`, locomotion blend space, capas superior e inferior, idle dinámico, respiración, transferencia de peso, fatiga y reacciones aditivas. Usará root motion sólo en acciones donde pueda reconciliarse de forma determinista con el movimiento de juego. Corrección limitada de pies, torso e IK reducirá deslizamiento sin deformar la trayectoria boxística de los puños.

### Ataque

`PunchController` definirá jab, cross, hooks, uppercuts, golpes al cuerpo y versiones rápidas o comprometidas. Elegirá variantes por dirección, distancia, postura y contexto: estáticas, avanzando, retrocediendo, laterales y counters. Cada golpe tendrá preparación, ventana activa, recuperación, coste, trayectoria, mano, zona preferida y compromiso. Las combinaciones se formarán mediante inputs y ventanas, no mediante secuencias largas pregrabadas.

### Defensa y counters

`DefenseController` incluirá guardia alta y corporal, slip, weave, duck, lean back, pasos defensivos, pivotes y parry configurable. La defensa será espacial y temporal: una guardia alta no protege automáticamente el cuerpo. Las ventanas de counter surgirán de un fallo, recuperación comprometida, defensa correctamente sincronizada o pérdida de balance, no de una bonificación permanente.

### Contacto

`ContactResolver` administrará hitboxes de puños y hurtboxes de cabeza y cuerpo activas sólo en ventanas válidas. Usará barridos entre poses físicas para evitar atravesar objetivos y garantizará un impacto máximo por ataque y víctima. Registrará posición, dirección, velocidad, trayectoria, zona, defensa y estado de ambos luchadores.

El resultado será `MISS`, `GRAZE`, `BLOCKED`, `PARTIAL`, `CLEAN`, `COUNTER` o `HEAVY_CLEAN`. La clasificación considerará recorrido disponible, alineación, velocidad, precisión, guardia y exposición. La distancia se expresará como `OUT_OF_RANGE`, `LONG`, `MID`, `POCKET` o `TOO_CLOSE` y modificará la efectividad de cada familia de golpes.

### Condición y daño

`ConditionModel` separará energía inmediata, fatiga acumulada, guardia, daño de cabeza, daño de cuerpo, stun y balance. Golpear al aire y lanzar golpes potentes consumirá energía. El daño corporal afectará recuperación; la fatiga reducirá velocidad, potencia, precisión, guardia, reacción y calidad de animación. El descanso entre rounds recuperará sólo cantidades limitadas y configurables.

### Reacciones y caídas

`ReactionController` combinará impulsos direccionales, active ragdoll parcial y animación contextual. Tipo, lado, potencia, zona y defensa determinarán la respuesta. Habrá pérdida de balance y stun antes de una caída, varias familias de knockdown, dirección coherente con el impacto, intento de levantarse y transición estable a KO o continuación. El solver físico no dependerá de colisiones internas inestables ni comprometerá la locomoción de las piernas.

### Inteligencia artificial

`BoxingBrain` consumirá distancia, stamina, daño, ring, puntuación, ritmo y hábitos observados. Implementará `OUTBOXER`, `PRESSURE_FIGHTER`, `COUNTER_PUNCHER`, `BRAWLER`, `DEFENSIVE_BOXER` y `BOXER_PUNCHER`. Cada estilo compartirá percepción y acciones, pero tendrá prioridades diferentes.

La IA reaccionará con latencia, información imperfecta y probabilidad de error dependiente de dificultad. Podrá adaptar guardia, protección corporal, ritmo, rutas de salida y agresividad sin leer directamente el input del jugador ni responder perfectamente a todo.

### Reglas y esquina

`FightDirector` seguirá coordinando rounds y resultado, pero separará conteo, puntuación, decisiones médicas y reglas configurables. El árbitro gestionará separación, knockdowns, KO, TKO y pausas. La esquina mostrará condición y consejos derivados de patrones reales, aplicará recuperación limitada y realizará una transición audiovisual limpia al round siguiente.

## Flujo de datos

1. Input del jugador o decisión de IA entra en `CombatStateMachine`.
2. Estado, stamina, distancia y espacio del ring validan la acción.
3. `PunchController` o `DefenseController` selecciona la variante contextual.
4. `CombatAnimationController` produce la pose y `FootworkController` resuelve desplazamiento y orientación.
5. Durante la ventana activa, `ContactResolver` barre la hitbox física.
6. El contacto se clasifica usando trayectoria, recorrido, guardia y exposición.
7. `ConditionModel` aplica costes y consecuencias localizadas.
8. `ReactionController` produce impulso, reacción, stun o knockdown.
9. Señales tipadas actualizan IA, audio, cámara, HUD, puntuación y esquina.
10. La máquina de estados entra en recuperación, encadena una acción válida o vuelve a guardia.

## Fases de entrega

### Fase 1 — Combat Foundation

Modularizar estado, locomoción 360°, orientación, footwork, idle y `AnimationTree`. La condición de salida es movimiento estable, sin cortes visibles ni regresiones del flujo de pelea.

### Fase 2 — Punch 2.0

Reconstruir jab y cross con transferencia de peso, rotación corporal, trayectorias, ventanas físicas, alcance y recuperaciones diferenciadas. Ambos deben sentirse fluidos y precisos a velocidad normal y lenta.

### Fase 3 — Arsenal

Añadir hooks, uppercuts, golpes al cuerpo, potencia y variantes contextuales. Cada familia debe distinguirse por rango, trayectoria, coste, riesgo y reacción.

### Fase 4 — Defense

Integrar guardias localizadas, slips, weave, duck, lean, parry, fintas, pivotes y counters. Ataque y defensa deben formar un sistema conectado por posición y timing.

### Fase 5 — Simulation

Integrar stamina, fatiga, daño localizado, balance, stun, reacciones y knockdowns. El desgaste debe cambiar visiblemente la conducta y capacidad del luchador.

### Fase 6 — Ring and AI

Completar cuerdas, esquinas, presión, escapes, clinch, seis estilos y adaptación. La IA debe tomar decisiones tácticas y cometer errores humanos.

### Fase 7 — Rules and Presentation

Completar árbitro, conteos, puntuación, esquina, HUD, cámara, audio y feedback audiovisual diferenciado por contacto.

### Fase 8 — PC Polish

Perfilar y optimizar física, animación, público y efectos; añadir LOD, pooling y opciones de accesibilidad pertinentes; ajustar balance y producir una build de PC verificable.

## Pruebas

Las reglas puras de rango, consumo, daño, contacto, puntuación, counters y selección táctica tendrán pruebas deterministas. Cada cambio funcional seguirá un ciclo de prueba fallida, implementación mínima y regresión completa.

Una escena laboratorio comprobará hitboxes reales, transiciones, bloqueo por zona, desplazamiento, ring, clinch, knockdowns y recuperación. Una prueba prolongada de pelea integrada buscará estados bloqueados, errores de runtime, acumulación de nodos y degradación de rendimiento.

La validación visual confirmará:

- pies sin deslizamiento evidente;
- transferencia corporal clara en jab y cross;
- regreso limpio a guardia;
- fallos naturales por distancia, trayectoria o evasión;
- diferencias perceptibles entre bloqueo, roce, impacto parcial, limpio, counter y heavy clean;
- cambios de postura y conducta por fatiga y daño;
- IA variada sin lectura instantánea de inputs;
- valor táctico real de cuerdas y esquinas;
- transiciones continuas entre locomoción, ataque, defensa, reacción y caída.

## Rendimiento

El objetivo es 60 FPS estables en PC en la escena de referencia. El profiler medirá por separado física, animación, público, shaders y efectos. Los presupuestos exactos se fijarán a partir de una captura base reproducible antes de optimizar. Se reducirán primero efectos secundarios, frecuencia de actualizaciones visuales o complejidad distante; nunca se degradará la detección de contacto para ocultar un problema de rendimiento.

## Tolerancia a fallos

- Un clip, sonido o efecto ausente usará un fallback seguro y emitirá un diagnóstico identificable.
- Una transición inválida volverá a un estado neutral controlado sin dejar al luchador atrapado.
- Los datos externos se validarán al cargar y usarán valores conservadores si faltan campos opcionales.
- Los impactos duplicados, referencias liberadas y señales fuera de fase se ignorarán de forma determinista y quedarán cubiertos por pruebas.
- Los recursos nuevos incluirán su procedencia y licencia antes de formar parte de una build distribuible.

## Fuera de alcance

- Modo carrera.
- Grandes plantillas de boxeadores antes de estabilizar el controlador.
- Colecciones de skins, rings o cosméticos.
- Multijugador en red.
- Paridad con export web.
- Sistemas de clinch ofensivo complejos más allá de detección, neutralización y separación reglamentaria.

## Criterio final

Combat 2.0 se considerará logrado cuando moverse, crear ángulos, defender y conectar golpes resulte satisfactorio sin depender del HUD; la distancia y el timing determinen los resultados; el desgaste cambie la pelea; la IA ofrezca estilos distinguibles; las reglas concluyan los combates consistentemente; y la build de PC mantenga el objetivo de rendimiento sin errores de runtime conocidos en las pruebas de aceptación.
