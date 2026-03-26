# Informe: Avatar Rive – Strike / HandTarget y brazo al mouse

Documento de todo lo implementado hasta ahora para que el brazo del avatar (catbotlode) siga la posicion del mouse al hacer hover, y del estado actual (Flutter envia datos pero el brazo no se mueve en pantalla).

---

## 1. Objetivo

- **Burbuja (header):** Solo cabeza - archivo cabezabot.riv. Sin inputs de strike ni hand target.
- **Chat (cuerpo completo):** Archivo catbotlode.riv. Al hacer hover sobre el avatar, el brazo debe seguir o apuntar hacia la posicion del mouse (manotazo / HandTarget), sin quedar rigido.

---

## 2. Flutter – Cambios realizados

**Archivo:** lib/features/player/presentation/widgets/rive_avatar.dart

### 2.1 Carga de .riv

- **Burbuja:** isBubble == true - riveHeadFileLoaderProvider - cabezabot.riv.
- **Chat:** isBubble == false - riveFileLoaderProvider - catbotlode.riv.

### 2.2 Inputs usados (solo en avatar de chat)

- StrikeTargetX (Number 0-100): posicion X del objetivo del brazo.
- StrikeTargetY (Number 0-100): posicion Y del objetivo del brazo.
- Strike (Trigger): disparo periodico de strike (cooldown + distancia minima).
- StrikeUseRightHand (Bool): mano derecha/izquierda segun posicion X.

La logica de strike/HandTarget y el envio de estos inputs se ejecutan **solo cuando !widget.isBubble** (avatar del chat), para no afectar la burbuja.

### 2.3 Envio de valores

- Con **hover** sobre el avatar del chat: cada frame se envian StrikeTargetX y StrikeTargetY con los mismos valores suavizados que la cabeza (_currentX, _currentY).
- Sin hover: se envian 50, 50 (centro/reposo).

### 2.4 Logs de depuracion

- _debugHandTarget = true: logs de hover ENTRO/SALIO, valores enviados y estado periodico (hovered, strikeInputs, look).
- En init solo se hace log de StrikeTargetX/Y encontrados para el avatar de chat (no para la burbuja).

### 2.5 Estado segun logs

Los logs confirman: StrikeTargetX y StrikeTargetY encontrados en el .riv del chat; hover ENTRO y hover activo con valores (X, Y) correctos; strikeInputs=true y hovered=true mientras el mouse esta sobre el avatar; hover SALIO y envio de 50, 50 al salir.

Conclusion: **Flutter esta enviando bien los datos al State Machine de Rive.** El problema no esta en la app.

---

## 3. Rive – Lo configurado

### 3.1 Inputs en la State Machine (catbotlode.riv)

Strike (Trigger), StrikeTargetX (Number, default 50), StrikeTargetY (Number, default 50), StrikeUseRightHand (Boolean).

### 3.2 HandTarget

Grupo HandTarget creado, colocado en la punta de la mano, asignado como Target del constraint IK del brazo.

### 3.3 Huesos del brazo derecho

Root Bone dentro de [hand-right], Bone 3 como hijo. Cadena: Root Bone - ultimo hueso (ej. Bone 3).

### 3.4 IK Constraint

Aplicado al ultimo hueso. Target: HandTarget. Bone Count: 3. Strength: 100%.

### 3.5 Timelines para Blends

StrikeTargetX_L, StrikeTargetX_R, StrikeTargetY_T, StrikeTargetY_B: keyframes de Position X/Y de HandTarget (izquierda, derecha, arriba, abajo).

### 3.6 State Machine – Capas HandTarget X e Y

HandTarget X: Entry - Blend 1D, Input = StrikeTargetX, Timelines StrikeTargetX_L (0), StrikeTargetX_R (100). HandTarget Y: Entry - Blend 1D, Input = StrikeTargetY, Timelines StrikeTargetY_T (0), StrikeTargetY_B (100).

### 3.7 Jerarquia

HandTarget al mismo nivel que [hand-right], [Body]. Root Bone dentro de [hand-right], Bone 3 como hijo.

---

## 4. Problema actual

Flutter envia StrikeTargetX/Y cada frame con hover; los logs lo confirman. Rive: el brazo no se mueve en pantalla al hacer hover. El fallo esta en Rive: (1) Blends no mueven HandTarget, (2) HandTarget no mueve el IK, (3) Malla del brazo no sigue los huesos (skinning), (4) Orden o prioridad de capas.

---

## 5. Checklist de revision en Rive

- En HandTarget X e Y el Blend tiene Input exactamente StrikeTargetX y StrikeTargetY.
- Las cuatro timelines tienen keyframes en HandTarget - Position X o Y.
- Las dos capas HandTarget X e Y estan activas.
- El IK esta en el ultimo hueso; Target = HandTarget; Bone Count correcto.
- La malla del brazo esta deformada por Root Bone y Bone 3 (skinning).

---

## 6. Archivos tocados

rive_avatar.dart: Inputs Strike/StrikeTargetX/Y/StrikeUseRightHand, envio cada frame cuando hover + !isBubble, logs HandTarget, enableBodyGestures. loader_provider.dart: sin cambios. Rive catbotlode.riv: Inputs, HandTarget, IK, 4 timelines, 2 Blends HandTarget X/Y, jerarquia Root Bone dentro de [hand-right].

---

## 7. Proximos pasos sugeridos

1. En Rive: mover manualmente StrikeTargetX y StrikeTargetY (0-100) en el panel Inputs y comprobar si HandTarget se mueve en el Stage.
2. Comprobar skinning del brazo a los huesos.
3. Probar con un solo Blend (solo X o solo Y) para aislar el problema.

---

Informe generado a partir del trabajo realizado en el avatar Rive (Strike / HandTarget) y estado actual de Flutter + Rive.

---

## ACTUALIZACION: Movimiento conseguido + correccion de posicion de reposo

### Cambio en Rive que funciono
- Se quito el IK de Bone 3 y se puso **en [hand-right] (la mano) directamente** con **Bone Count: 1**.
- El brazo ahora si se mueve (rigido, sin codo doblado; para codo doblado haria falta deform binding del mesh a los huesos).

### Problema actual: posicion por defecto (50/50) incorrecta
Con el Blend 1D, el valor 50 es la interpolacion entre el keyframe 0 y el 100. Si esos extremos no son simetricos respecto a la posicion natural del brazo, en 50/50 la mano arranca doblada.

### Solucion (solo en Rive, no en Flutter)
1. En modo Design, seleccionar HandTarget y anotar su X e Y de reposo (posicion natural del brazo).
2. En cada timeline, poner los keyframes simetricos alrededor de ese reposo:
   - StrikeTargetX_L (valor 0): HandTarget X = X_rest - N (ej. si X_rest=200, usar -100).
   - StrikeTargetX_R (valor 100): HandTarget X = X_rest + N (ej. 500).
   - Asi en 50 el promedio = X_rest. Igual para StrikeTargetY_T y StrikeTargetY_B con Y_rest +/- rango.

**Flutter no requiere cambios:** ya envia 50/50 en reposo y 0-100 con hover; la correccion es solo en los keyframes del .riv.
