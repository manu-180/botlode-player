-- Permite que el player embebido (cliente anónimo) lea la config del bot (tema, notificaciones, etc.).
-- Sin esta política, auth.uid() es null y "bots_select_own" (user_id = auth.uid()) no devuelve filas,
-- por eso el player siempre usaba valores por defecto (tema dark, notificaciones activas).
--
-- Ejecutar en el mismo proyecto Supabase que usa botslode (tabla public.bots).
-- En Dashboard: SQL Editor > New query > pegar y Run.

-- Política adicional: anon puede hacer SELECT en bots (solo lectura).
-- INSERT/UPDATE/DELETE siguen restringidos por bots_insert_own, bots_update_own, bots_delete_own.
CREATE POLICY "bots_select_anon_player" ON public.bots
  FOR SELECT
  TO anon
  USING (true);
