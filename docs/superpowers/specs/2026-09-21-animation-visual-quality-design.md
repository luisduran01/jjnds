# Calidad de movimiento y visuales: Corner Club

## Objetivo

Elevar fluidez, contacto y presentación gráfica sin sustituir el combate, perfiles, fatiga o PD-ragdoll existentes.

## Movimiento

El `AnimationTree` existente conservará locomoción y capa superior. Un controlador de movimiento híbrido derivará velocidad deseada de la cadencia de locomoción y de ventanas de ataque, manteniendo `CharacterBody3D` como autoridad de colisión. Un solver IK ligero de dos huesos corregirá brazo/antebrazo hacia un objetivo limitado a cara o torso y se mezclará con la pose actual. No se importarán animaciones falsas; el pipeline admite posteriormente clips MoCap/retargeted con el mismo rig.

El PD activo actual seguirá siendo la reacción de impacto. `PhysicalBone3D` queda reservado para K.O. de cuerpo completo tras preparar colisionadores por hueso; no se mezcla con el combate activo actual para evitar jitter.

## Visuales

Crear `WorldEnvironment` Forward+ para ring y club: tonemapping AgX, SSAO, niebla volumétrica opcional con presupuesto, luces cenitales y exposición controlada. Materiales de luchador, guantes, lona y saco usarán PBR con normal/roughness/AO disponibles. La piel conservará el mapa dinámico de daño y añadirá SSS sólo en materiales compatibles.

## Aceptación

- La suite de combate no pierde casos.
- IK se limita a alcance anatómico y no mueve root/cápsula.
- El desplazamiento no aumenta el deslizamiento de pies durante golpes.
- El entorno mantiene rendimiento con dos luchadores y luces de ring.
