# Informe: Overlay de conectividad y TypeError en Flutter Web (botlode_player)

**Objetivo:** Documentar todo lo ocurrido alrededor del HUD de conectividad (sin señal / reconexión) en `botlode_player`, los cambios realizados y el **TypeError minificado** que sigue apareciendo en producción cuando se pierde el Wi‑Fi. Este informe está pensado para que otra IA pueda investigar en profundidad.

---

## 1. Contexto del proyecto

- **App:** `botlode_player` (Flutter Web), embebida en páginas HTML vía `<iframe>`.
- **Producción:** `https://botlode-player.vercel.app/`
- **Prueba local:** `prueba_jefe.html` (Live Server en `http://127.0.0.1:5500/`) carga el iframe apuntando a producción con `?botId=...&v=5.20`.
- **Ruta única:** `GoRouter` `/` → `UltraSimpleBot` (no `PlayerScreen` ni `FloatingBotWidget` en la ruta actual).
- **Stack visual:** `UltraSimpleBot` tiene un `Stack` con: panel de chat (`ChatPanelView` dentro de un `Container`), burbuja flotante y **`GlobalConnectivityOverlay`** como último hijo.
- **Detección de red:** `connectivityProvider` (`StreamProvider<bool>`) en `lib/core/network/connectivity_provider.dart`. Usa `html.window.navigator.onLine` y `window.onOnline` / `window.onOffline`.

---

## 2. Qué se pidió (resumen)

1. **Cartel de “sin conexión”** que se vea **en toda la pantalla**, no solo dentro del chat, y también con el chat cerrado (solo burbuja).
2. **No bloquear** la página: que sea tipo snackbar/appbar, no un modal que tape todo.
3. **Compartir espacio con el chat:** si el chat está abierto, el banner a la izquierda; si está cerrado, que ocupe todo el ancho (abajo).
4. **Mejor diseño** (estilo sci‑fi, sin azul, sin mencionar al bot), mensaje completo, soporte **reconexión** (“Conexión restablecida”).
5. **Propagar estado al HTML contenedor** vía `postMessage` para que el host pueda reaccionar.
6. Respetar **modo claro/oscuro** del bot.
7. **Versión** en `main.dart` (`DEPLOY_VERSION`) incrementada en cada deploy (v5.18 → v5.19 → v5.20…).

---

## 3. Qué se implementó

### 3.1 `GlobalConnectivityOverlay` (`lib/features/player/presentation/widgets/global_connectivity_overlay.dart`)

- **`GlobalConnectivityOverlay`:** `ConsumerWidget` que hace `ref.watch` de:
  - `botConfigProvider` → `isDarkMode`
  - `connectivityProvider` → `isOnline`
  - `chatOpenProvider` → `isChatOpen`
- Renderiza `_GlobalConnectivityBanner` dentro de `IgnorePointer(ignoring: true)`.
- **`_GlobalConnectivityBanner`:** `StatefulWidget` con `_showSuccess` para mostrar “Conexión restablecida” unos segundos al volver online.
- **Cuándo se muestra:** Solo si `!isOnline` (offline) o `_showSuccess` (reconexión reciente). Si no, `SizedBox.shrink()`.
- **Layout:** `AnimatedPositioned` abajo (`bottom: 12` visible, `-120` oculto), `left: 16`, `right: rightInset`.  
  `rightInset` depende de `isChatOpen` y layout desktop: si el chat está abierto, se reserva ancho a la derecha (`desktopChatWidth` 380 + padding) para que el banner no tape el chat.
- **Banner:** `ClipRRect` + `Container` con gradiente (rojo offline, verde reconexión), icono wifi/wifi_off en “chip” circular, texto en `Row` con `Flexible` + `Text` (maxLines: 2). **Sin `BackdropFilter`** (se quitó por posibles errores en HTML renderer).
- **Animación:** `flutter_animate`: `fadeIn` + `slideY(begin: 0.2, end: 0)` aplicado al `Container` del banner.

### 3.2 Montaje del overlay

- **`UltraSimpleBot`** (`lib/features/player/presentation/widgets/ultra_simple_bot.dart`): en el `Stack` del body, como último hijo:
  ```dart
  const GlobalConnectivityOverlay(),
  ```
- **`PlayerScreen`** también lo incluye, pero la ruta actual usa solo `UltraSimpleBot`.

### 3.3 Propagación al HTML y versión

- **`main.dart`:** Tras `CMD_READY`, se envía al parent:
  ```js
  { type: 'DEPLOY_INFO', source: 'botlode_player', version: DEPLOY_VERSION }
  ```
- **`FloatingBotWidget`** (no usado en la ruta activa): tiene `ref.listen(connectivityProvider, ...)` y envía `NETWORK_OFFLINE` / `NETWORK_ONLINE` y un payload `{ type: 'connectivity', ... }` al `window.parent`.
- **`prueba_jefe.html`:** Escucha `DEPLOY_INFO` y `CONNECTIVITY_STATE` y hace `console.log` de ambos.
- **Cache busting:** iframe con `&v=5.20` (o la versión desplegada) para evitar cache agresivo.

### 3.4 Otras piezas relacionadas

- **`connectivityProvider`:** `StreamProvider<bool>`, escucha `onOnline` / `onOffline`.
- **`StatusIndicator`:** Dentro del chat, muestra “DESCONECTADO” (rojo) cuando `!isOnline`; solo visible con chat abierto.
- **`ChatPanelView`:** El banner rojo interno (`_ConnectivityBanner`) se **eliminó**; solo queda el overlay global.
- **`SimpleChatTest`:** Input deshabilitado y hint “Sin conexión” cuando `!isOnline` (comportamiento previo, se mantiene).

---

## 4. El error: `TypeError` minificado al perder conexión

### 4.1 Cuándo ocurre

- Al **cortar el Wi‑Fi** (o simular offline) con la app en producción (Vercel) y `prueba_jefe.html` cargando el iframe.
- El **primer** `CONNECTIVITY_STATE` **sí llega** al HTML (ej. `[BotLode Player] CONNECTIVITY_STATE: false chatOpen= false`).
- Justo después aparece el **TypeError** y luego varias veces `Another exception was thrown: Instance of 'minified:n0<erased>'` (o similar).

### 4.2 Mensaje y stack (según logs)

```
TypeError: Instance of 'minified:e5': type 'minified:e5' is not a subtype of type 'minified:hk'
    at mi.bhw [as a] (https://botlode-player.vercel.app/main.dart.js:4555:23)
    at l2.v_ (https://botlode-player.vercel.app/main.dart.js:76669:5)
    at Ku.yo (https://botlode-player.vercel.app/main.dart.js:80799:8)
    at Ku.h2 (https://botlode-player.vercel.app/main.dart.js:80768:3)
    at Ku.h2 (https://botlode-player.vercel.app/main.dart.js:80815:3)
    at a0l.zu (https://botlode-player.vercel.app/main.dart.js:80511:17)
    at a0l.ev (https://botlode-player.vercel.app/main.dart.js:80407:24)
    at a0l.lo (https://botlode-player.vercel.app/main.dart.js:80657:31)
    at a0l.GI (https://botlode-player.vercel.app/main.dart.js:80602:10)
    at a0l.a8F (https://botlode-player.vercel.app/main.dart.js:80603:19)
```

(En v5.19 el error mencionaba `minified:e4` y `minified:hi`; en v5.20 pasó a `e5` y `hk`.)

### 4.3 Hipótesis probadas o descartadas

- **BackdropFilter:** Se **quitó** del overlay porque en Flutter Web con **HTML renderer** suele dar problemas de capas/casts. El error **persistió** tras quitarlo.
- **`ref.listen` de conectividad en el overlay:** Se llegó a añadir un `ref.listen` a `connectivityProvider.select(...)` para enviar `CONNECTIVITY_STATE` al parent. Se **eliminó** por si contribuía al crash. El `CONNECTIVITY_STATE` dejó de emitirse desde Flutter, pero el **TypeError siguió** (el usuario siguió viendo el error al cortar Wi‑Fi).
- **Orden de los widgets en el `Stack`:** El overlay está al final. No se ha cambiado ese orden de forma relevante.

### 4.4 Qué **sí** se confirma

- **Build correcta en producción:** `DEPLOY_INFO` con `v5.20` (o la versión desplegada) aparece en consola.
- **Detección de offline:** El `connectivityProvider` reacciona (el `CONNECTIVITY_STATE` llegó cuando el listener estaba activo).
- **Momento del crash:** Coincide con el cambio a offline (y por tanto con rebuilds que usan `connectivityProvider` y el overlay).

---

## 5. Cambios realizados (cronología breve)

1. **Overlay full-screen inicial** con gradiente, scanlines, chips “OFFLINE”/“LINK”/“SYNC”, `BackdropFilter`. Solo se mostraba dentro del chat en algunas rutas; se movió a nivel global (`UltraSimpleBot` / `PlayerScreen`).
2. **Rediseño a “snackbar/appbar”** abajo, sin bloquear, compartiendo espacio con el chat, sin azul ni mención al bot, con mensaje largo y “Conexión restablecida”.
3. **Eliminación de `BackdropFilter`** en el overlay para evitar crashes en HTML renderer.
4. **Eliminación del banner interno** de conectividad en `ChatPanelView`.
5. **`DEPLOY_INFO`** y **`CONNECTIVITY_STATE`** vía `postMessage` para debug y para que el host reaccione.
6. **Eliminación del `ref.listen` de conectividad** dentro de `GlobalConnectivityOverlay` (postMessage de `CONNECTIVITY_STATE` desde el overlay ya no se hace).
7. **Versiones** en `main.dart`: v5.18 → v5.19 → v5.20. En `prueba_jefe.html`, `&v=5.20` en el `src` del iframe.

---

## 6. Estado actual

- **`GlobalConnectivityOverlay`:**  
  - Sin `BackdropFilter`, sin `ref.listen` de conectividad.  
  - Usa solo `ref.watch` de `connectivityProvider`, `chatOpenProvider` y `botConfigProvider`.  
  - Banner con `flutter_animate` (`fadeIn` + `slideY`), `AnimatedPositioned`, layout responsivo.
- **Producción:** Se despliega a Vercel (`flutter build web` → `docs/` → deploy). En `prueba_jefe.html` se carga `https://botlode-player.vercel.app/?botId=...&v=5.20`.
- **Comportamiento observado:**  
  - Con **red OK:** el chat y la burbuja se ven normales.  
  - Al **cortar Wi‑Fi:** aparece el `TypeError` minificado y no se ve el HUD de conectividad; el chat sigue mostrando “DESCONECTADO” y deshabilitado como antes.

---

## 7. Archivos relevantes

| Archivo | Qué contiene |
|--------|----------------|
| `lib/features/player/presentation/widgets/global_connectivity_overlay.dart` | `GlobalConnectivityOverlay`, `_GlobalConnectivityBanner`. Toda la UI del HUD. |
| `lib/core/network/connectivity_provider.dart` | `StreamProvider<bool>` basado en `navigator.onLine` y `onOnline`/`onOffline`. |
| `lib/features/player/presentation/widgets/ultra_simple_bot.dart` | `Stack` con chat, burbuja y `GlobalConnectivityOverlay`. Ruta actual `/`. |
| `lib/features/player/presentation/views/player_screen.dart` | Incluye overlay; usado en otras rutas. |
| `lib/features/player/presentation/widgets/floating_bot_widget.dart` | `ref.listen(connectivityProvider)`, postMessage `NETWORK_OFFLINE`/`NETWORK_ONLINE`. No en la ruta activa. |
| `lib/features/player/presentation/views/chat_panel_view.dart` | Usa `connectivityProvider` y `StatusIndicator`. Banner interno de conectividad eliminado. |
| `lib/features/player/presentation/views/simple_chat_test.dart` | Chat real usado en `UltraSimpleBot` (según router); `isOnline` para input/hint. |
| `lib/main.dart` | `DEPLOY_VERSION`, `_setupIframeListeners`, `DEPLOY_INFO` vía postMessage. |
| `lib/core/router/app_router.dart` | Ruta `/` → `UltraSimpleBot`. |
| `prueba_jefe.html` (raíz del monorepo) | Iframe a producción, listeners para `DEPLOY_INFO` y `CONNECTIVITY_STATE`. |

---

## 8. Petición a la IA que investigue

1. **Origen del `TypeError` minificado**  
   - ¿Qué widget o capa de Flutter (o qué tipo concreto en el JS compilado) corresponde a `minified:e5` / `minified:hk` (o `e4`/`hi` en builds anteriores)?  
   - El stack apunta a `a0d.*` y `Ku.*` en `main.dart.js`. Si es posible, relacionar con `GlobalConnectivityOverlay`, `AnimatedPositioned`, `flutter_animate` o con el uso de `connectivityProvider` en el árbol.

2. **HTML vs CanvasKit**  
   - La app usa **HTML renderer** (según bootstrap: “Motor Flutter inicializado correctamente (HTML RENDERER)”).  
   - ¿Hay casos conocidos de `AnimatedPositioned`, `flutter_animate` o de `StreamProvider`/`AsyncValue` en este renderer que produzcan “type X is not a subtype of type Y” en release?

3. **`connectivityProvider` y rebuilds**  
   - Al pasar a offline, el `StreamProvider` emite `false` y todos los `ref.watch(connectivityProvider)` reconstruyen.  
   - ¿Puede ese flujo de rebuild (p. ej. overlay + chat + status) provocar que se dispare una animación o un layout en un estado inválido y acabe en ese cast error?

4. **Alternativas concretas**  
   - ¿Es más seguro usar **`AnimatedOpacity` + `AnimatedSlide`** (o `TweenAnimationBuilder`) en lugar de `flutter_animate` para el banner?  
   - ¿Conviene **no** usar `AnimatedPositioned` y usar solo `Positioned` + `AnimatedOpacity` para mostrar/ocultar?  
   - ¿Algún patrón conocido para “snackbar de conectividad” en Flutter Web que evite este tipo de errores en release?

5. **Logs y reproducción**  
   - Los `CONNECTIVITY_STATE` ya no se envían desde el overlay. Si hace falta más telemetría para acotar el fallo (p. ej. “overlay built”, “banner visible”), ¿dónde y cómo añadirla sin aumentar riesgo de crash?

---

## 9. Cómo reproducir

1. Abrir `prueba_jefe.html` con Live Server (o similar) apuntando al iframe de producción (con `&v=5.20` o la versión actual).
2. Abrir DevTools → Console.
3. Verificar `[BotLode Player] DEPLOY_INFO: ...` para confirmar build.
4. Cortar el Wi‑Fi (o en DevTools → Network → Offline).
5. En consola suele aparecer primero `CONNECTIVITY_STATE: false ...` (si el listener en overlay estuvo activo) y de inmediato el `TypeError` y los `Another exception was thrown`.

---

**Versión del informe:** 1.0  
**Última versión de la app referida:** `DEPLOY_VERSION` v5.20 (`Connectivity HUD + No BackdropFilter`).
