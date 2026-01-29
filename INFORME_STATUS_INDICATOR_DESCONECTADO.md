# Informe: Rectángulo “DESCONECTADO / enchufe” al refrescar sin internet

**Objetivo:** Documentar el problema específico del rectángulo de estado (badge “DESCONECTADO” con icono de enchufe / alerta) que aparece dentro del chat cuando se recarga la página sin conexión, para que otra IA pueda investigarlo y proponer una solución robusta.

---

## 1. Contexto del problema

- **Comportamiento observado:**
  - Cuando el usuario **corta el Wi‑Fi** y luego **refresca la página** (`prueba_jefe.html`) mientras sigue sin conexión:
    - El chat se muestra dentro de un **container gris/oscuro** con bordes redondeados (la “tarjeta” del chat).
    - En la parte inferior izquierda de esa tarjeta aparece un **badge rectangular** con texto **“DESCONECTADO”** y un icono (tipo enchufe / alerta), con barra luminosa animada.
  - El usuario **no quiere** que este rectángulo aparezca en ese escenario. Prefiere que el estado de red lo comunique el **HUD/snackbar global**, no el chat interno.

- **Comportamiento deseado:**
  - Si la página se abre o se refresca **sin internet**, el chat:
    - Puede seguir mostrando el dimming y el input deshabilitado (no es el foco principal ahora).
    - **No debe mostrar** el rectángulo “DESCONECTADO” dentro del chat en ese primer render.
  - El rectángulo “DESCONECTADO” solo debería aparecer cuando:
    - La app **estaba online** con una sesión activa, y luego se corta la conexión.

- **Entorno:**
  - App Flutter Web (`botlode_player`) renderizada en un `<iframe>` dentro de `prueba_jefe.html`.
  - Renderizador: **HTML renderer**.
  - Motor de estado: **Riverpod**.

---

## 2. Componentes implicados

### 2.1 `StatusIndicator` (badge “DESCONECTADO”)

**Archivo:** `lib/features/player/presentation/widgets/status_indicator.dart`

- Widget `ConsumerWidget` que representa el **badge de estado** en la esquina inferior izquierda del chat.
- Props principales:
  - `isLoading` (bool)
  - `isOnline` (bool)
  - `mood` (String)
  - `isDarkMode` (bool)
  - `currentSessionId` (String?)
- Internamente además **lee providers**:
  - `chatOpenProvider` → para saber si el chat está abierto.
  - `activeSessionIdProvider` → id de la sesión de chat activa.
  - `chatControllerProvider` → para obtener `sessionId` si no se pasa `currentSessionId`.

Lógica relevante actual (simplificada, **v5.26+**):

- Si el chat está cerrado (`!isChatOpen`) → retorna `SizedBox.shrink()` (no se muestra nada).
- Si `!isOnline`:
  - Lee `hasEverBeenOnline = ref.watch(hasEverBeenOnlineProvider)`.
  - **Solo muestra “DESCONECTADO”** si `hasEverBeenOnline == true`.
  - Si **nunca** hubo conectividad en la sesión actual (`hasEverBeenOnline == false`), deja `text = ""` para que el widget se oculte (objetivo: no mostrar el cartel en un refresh offline “en frío”).
- Si `isOnline == true`, usa `mood`, `activeSessionId` y `currentSessionId` para decidir si muestra “EN LÍNEA” u otros estados.
- Al final:
  - Si `text.isEmpty` → retorna `SizedBox.shrink()` (no renderiza UI).
  - Si hay texto (por ejemplo “DESCONECTADO” o “EN LÍNEA”) → construye el rectángulo con:
    - Una barra vertical animada (`flutter_animate`) que parece un “reactor / enchufe”.
    - Texto con tipografía `Courier`.

### 2.2 `SimpleChatTest` (tarjeta del chat)

**Archivo:** `lib/features/player/presentation/views/simple_chat_test.dart`

Fragmento relevante:

```dart
// Colores base
const Color bgColor = Color(0xFF181818);
const Color borderColor = Colors.white24;
// ...

// Conectividad real desde provider
final isOnline = ref.watch(connectivityProvider).asData?.value ?? true;

return GestureDetector(
  onTap: () {},
  child: Container(
    width: double.infinity,
    height: double.infinity,
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: borderColor, width: 1.0),
      boxShadow: [ /* sombra */ ],
    ),
    child: Material(
      color: bgColor,
      child: Column(
        children: [
          // HEADER con avatar / título...
          Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: bgColor,
              // ...
            ),
            child: Stack(
              children: [
                // Avatar Rive...
                // ...
                // StatusIndicator dentro de un Positioned
                Positioned(
                  bottom: 12,
                  left: 24,
                  child: StatusIndicator(
                    isLoading: chatState.isLoading,
                    isOnline: isOnline,
                    mood: chatState.currentMood,
                    isDarkMode: isDarkMode,
                    currentSessionId: chatState.sessionId,
                  ),
                ),
              ],
            ),
          ),
          // BODY: mensajes, input, etc.
        ],
      ),
    ),
  ),
);
```

Este `Container` + `Material` es precisamente la **“tarjeta”** que el usuario ve como un rectángulo gris/oscuro con el badge encima.

### 2.3 `connectivityProvider`

**Archivo:** `lib/core/network/connectivity_provider.dart`

```dart
final connectivityProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();

  // Estado inicial
  controller.add(html.window.navigator.onLine ?? true);

  final onlineSub = html.window.onOnline.listen((_) {
    controller.add(true);
  });

  final offlineSub = html.window.onOffline.listen((_) {
    controller.add(false);
  });

  ref.onDispose(() {
    onlineSub.cancel();
    offlineSub.cancel();
    controller.close();
  });

  return controller.stream;
});
```

- Se apoya en `navigator.onLine` y en eventos `onOnline` / `onOffline` del navegador.
- **Importante:** al refrescar la página **sin internet**, `navigator.onLine` suele devolver `false`, por lo que el estado inicial `isOnline` llega como `false`.

### 2.4 `activeSessionIdProvider`

**Archivo:** `lib/features/player/presentation/views/simple_chat_test.dart` (y providers de chat)

En `SimpleChatTest.build()`:

```dart
final chatState = ref.watch(chatControllerProvider);
final activeSessionId = ref.watch(activeSessionIdProvider);
if (activeSessionId == null || activeSessionId.isEmpty) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final currentActiveSessionId = ref.read(activeSessionIdProvider);
    if (currentActiveSessionId == null || currentActiveSessionId.isEmpty) {
      ref.read(activeSessionIdProvider.notifier).state = chatState.sessionId;
      print("🟡 [SimpleChatTest] build() - activeSessionId inicializado a: ${chatState.sessionId}");
    }
  });
}
```

- Esto significa que **siempre** que se construye el chat (incluso sin internet), se inicializa un `activeSessionId` con el `sessionId` del chat actual.
- Por tanto, incluso en un **refresh sin internet**, la condición `hasActiveSession` en `StatusIndicator` se vuelve **true**.

---

## 3. Por qué sigue apareciendo el rectángulo al refrescar sin internet

### 3.1 Flujo actual al refrescar sin internet

1. Usuario corta Wi‑Fi.
2. Refresca `prueba_jefe.html` (iframe → `botlode_player`).
3. Al cargar Flutter:
   - `navigator.onLine` devuelve `false` → `connectivityProvider` emite `false`.
   - `SimpleChatTest` se construye, crea un nuevo `chatState` con `sessionId` generado.
   - Como `activeSessionId` está vacío, se inicializa con ese `sessionId`.
4. `StatusIndicator` se construye con:
   - `isOnline = false`.
   - `activeSessionId` **no vacío**.
5. Lógica de `StatusIndicator`:
   - `hasActiveSession = true`.
   - `!isOnline && hasActiveSession` ⇒ **muestra “DESCONECTADO”**.
6. Como el texto no está vacío, el widget no se oculta y se ve el rectángulo con el enchufe.

### 3.2 Intentos de mitigación aplicados hasta ahora

1. **Provider de transición (`connectivityTransitionProvider`) – DESCARTADO**
   - Primera versión: se intentó detectar explícitamente una transición `online → offline` y solo mostrar “DESCONECTADO” en ese caso.
   - Problema: la lógica se volvió compleja y frágil, y además seguía existiendo una sesión activa incluso en refresh offline (por la inicialización en `SimpleChatTest`), por lo que el cartel seguía apareciendo en algunos escenarios.

2. **Provider histórico `hasEverBeenOnlineProvider` – IMPLEMENTADO**
   - Versión más reciente: se introdujo `hasEverBeenOnlineProvider`, un `StateNotifierProvider<bool>` monotónico que:
     - Arranca en `false`.
     - Pasa a `true` la primera vez que `connectivityProvider` emite `true`.
   - `StatusIndicator` ahora solo muestra “DESCONECTADO” si:
     - `!isOnline` **y**
     - `hasEverBeenOnline == true`.
   - Objetivo: en un refresh offline “en frío”, `hasEverBeenOnline` debería permanecer `false` y el badge no debería pintarse.

3. **Estado actual del bug**
   - A pesar de `hasEverBeenOnline`, en algunas pruebas del usuario el rectángulo sigue apareciendo tras un refresh offline.
   - Hipótesis: puede haber una condición de carrera entre:
     - El primer valor que emite `connectivityProvider` (y cómo se inicializa `hasEverBeenOnline`),
     - La creación temprana de una sesión `activeSessionId`,
     - Y el orden en que se reconstruye `StatusIndicator`.

### 3.3 Causa raíz (para investigar)

La causa raíz de que el rectángulo aparezca en el refresh offline es:

> El sistema de sesiones (`activeSessionIdProvider`) **no distingue entre una sesión “histórica/activa previa” y una sesión recién creada en un entorno sin red**.

Desde el punto de vista del código:

- La condición `hasActiveSession` se cumple tanto:
  - En un escenario sano: la app estaba online, el usuario estaba chateando y luego se corta la red.
  - Como en un escenario de refresh sin red: se crea una sesión nueva pero **nunca** se llegó a estar online.

El `StatusIndicator` no tiene forma de saber si esa sesión activa corresponde a:

- Una sesión en la que **sí hubo conectividad antes**, o
- Una sesión creada en un entorno que **nunca tuvo conectividad**.

---

## 4. Requisitos funcionales para la IA investigadora

1. **No mostrar “DESCONECTADO” en refresh sin internet:**
   - Si la app **se inicia** con `isOnline == false` y **nunca estuvo online**, el `StatusIndicator` no debería renderizar el badge interno.
   - La señal de falta de conexión debería quedar a cargo del **HUD global** (snackbar/bottom-bar) fuera del chat.

2. **Sí mostrar “DESCONECTADO” cuando se corta la conexión durante una sesión:**
   - Si la app ya estuvo `isOnline == true` en algún momento y el usuario tiene un `activeSessionId` que corresponde a esa sesión, al pasar a `isOnline == false` el rectángulo debe mostrarse como ahora.

3. **No romper el resto de lógica de `activeSessionId`:**
   - El sistema de “solo un chat EN LÍNEA a la vez” y la sincronización con Supabase/heartbeat debe seguir funcionando.

---

## 5. Posibles líneas de investigación / soluciones (actualizadas con respuesta de IA)

1. **Flag “hasEverBeenOnline” (ya implementado, pero a revisar finamente):**
   - Ya existe `hasEverBeenOnlineProvider`, que marca en `true` cuando alguna vez hubo red.
   - Se debe revisar con lupa:
     - Cómo se lee el valor inicial de `connectivityProvider` (para evitar que un “falso positivo” de `navigator.onLine` marque el flag en `true` durante un refresh offline).
     - El orden en que `StatusIndicator` se construye vs. el momento en que `hasEverBeenOnline` cambia.
   - La otra IA sugiere mantener este enfoque, pero asegurando que:
     - En **cold start offline**, `hasEverBeenOnline` siga siendo `false` durante todo el primer frame.
     - Solo se marque en `true` tras una conexión real (idealmente después del primer heartbeat exitoso a Supabase, no solo por `navigator.onLine`).

2. **No inicializar `activeSessionId` cuando no hay conectividad:**
   - En `SimpleChatTest`, antes de inicializar `activeSessionId`, comprobar `isOnline`:
     ```dart
     if (isOnline && (activeSessionId == null || activeSessionId.isEmpty)) {
       // inicializar activeSessionId solo si hay red
     }
     ```
   - De esta forma, en un refresh sin internet **no** habría sesión activa y el `StatusIndicator` se ocultaría (si se mantiene la condición `hasActiveSession`).

3. **Distinguir “sesión persistida” de “sesión efímera offline”:**
   - Marcar en `chatState` o en la base local si la sesión fue creada con conectividad real (por ejemplo después de un primer heartbeat exitoso a Supabase, como sugiere la IA externa).
   - El `StatusIndicator` solo mostraría “DESCONECTADO” para sesiones que tengan un flag `wasOnlineOnce == true` y `hasEverBeenOnline == true`.

4. **Mover el rectángulo de “DESCONECTADO” al HUD global para estados iniciales:**
   - Dejar el badge interno solo para estados emocionales (“EN LÍNEA”, “FELIZ”, etc.).
   - El estado de red global (incluido “DESCONECTADO” inicial) se representaría siempre con el **snackbar global**.

---

## 6. Qué se espera de la IA investigadora

1. Analizar el flujo completo de:
   - Inicialización de `connectivityProvider` (HTML renderer + navigator.onLine).
   - Creación de `chatState` y `activeSessionId` en `SimpleChatTest`.
   - Renderizado de `StatusIndicator` con distintos valores de `isOnline` y `activeSessionId`.

2. Proponer una solución robusta que:
   - Diferencie claramente entre:
     - **Refresh sin internet** (nunca hubo conectividad).
     - **Desconexión posterior** en una sesión que sí estuvo online.
   - No rompa la lógica de sesiones ni el comportamiento de “EN LÍNEA”.

3. Sugerir cambios concretos de código (idealmente mínimos y localizados) en:
   - `connectivity_provider.dart`
   - `simple_chat_test.dart`
   - `status_indicator.dart`

para conseguir:

- Que **no aparezca** el rectángulo “DESCONECTADO / enchufe” al refrescar sin internet.
- Que **sí aparezca** cuando la red se cae tras haber estado online.

---

**Versión del informe:** 1.1  
**Versión de la app referida:** `DEPLOY_VERSION` v5.26 (`StatusIndicator usa hasEverBeenOnline (intento de ocultar cartel en refresh offline)`).

