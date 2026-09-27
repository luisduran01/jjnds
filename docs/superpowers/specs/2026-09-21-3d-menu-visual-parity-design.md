# Paridad visual de menús 2D dentro del Club 3D

## Objetivo

Trasladar la identidad visual y datos funcionales de los menús 2D actuales a paneles interactivos situados en el hub 3D, sin sustituirlos por un estilo nuevo.

## Diseño

Cada estación del `ClubHub3D` tendrá una superficie `MeshInstance3D` con un `SubViewport` que renderiza un `Control` reutilizando fondos, paleta azul oscura, bordes dorados, tarjetas, barras y tipografía de los menús existentes. El panel de Quick Fight muestra los perfiles, retratos, estadísticas, rounds, estilo AI y acción Fight. El de Carrera muestra récord, dinero, ranking, rival, contrato, historial y acceso a entrenamiento.

El foco de cámara selecciona una estación y envía entradas al `SubViewport`; los botones configuran `GameManager` y cargan `boxing/main.tscn`. Los datos siguen siendo los de `CareerManager`, `BoxerData` y los recursos existentes. No se duplican reglas de carrera en el panel.

## Aceptación

- Los paneles 3D conservan los recursos visuales 2D existentes.
- Quick Fight transmite perfiles, rounds y AI al combate actual.
- Carrera muestra datos reales del guardado y abre el combate actual con rival correcto.
- Ninguna ruta de juego abre `fight_3d.tscn`.
