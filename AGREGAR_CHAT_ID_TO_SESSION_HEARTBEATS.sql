-- Script SQL para agregar la columna chat_id a la tabla session_heartbeats
-- Este ID persistente identifica la conversación completa (no cambia con reloads)

-- PASO 1: Agregar columna chat_id (nullable inicialmente para compatibilidad)
ALTER TABLE public.session_heartbeats
ADD COLUMN IF NOT EXISTS chat_id TEXT;

-- PASO 2: Crear índice para mejorar performance en consultas por chat_id
CREATE INDEX IF NOT EXISTS idx_session_heartbeats_chat_id 
ON public.session_heartbeats(chat_id);

-- PASO 3: Agregar columna created_at si no existe (para comparar cuál heartbeat es más reciente)
ALTER TABLE public.session_heartbeats
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- PASO 4: Actualizar registros existentes: usar session_id como chat_id temporalmente
-- (Esto es solo para migración, los nuevos registros tendrán el chat_id correcto)
UPDATE public.session_heartbeats
SET chat_id = session_id
WHERE chat_id IS NULL;

-- PASO 5: Hacer chat_id NOT NULL después de la migración (opcional, comentado por seguridad)
-- ALTER TABLE public.session_heartbeats
-- ALTER COLUMN chat_id SET NOT NULL;

-- Verificación: Ver la estructura de la tabla
-- SELECT column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'session_heartbeats' 
-- ORDER BY ordinal_position;
