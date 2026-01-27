-- ⚠️ ADVERTENCIA: Este script borra TODOS los chats de TODOS los bots
-- Ejecutar con precaución. No se puede deshacer.

-- 1. Borrar todos los mensajes del chat (chat_logs)
DELETE FROM chat_logs;

-- 2. Borrar todos los contactos extraídos (extracted_contacts)
DELETE FROM extracted_contacts;

-- 3. Borrar todos los heartbeats de sesiones (session_heartbeats)
DELETE FROM session_heartbeats;

-- 4. Borrar todos los registros de alertas de leads enviadas (lead_alerts_sent)
DELETE FROM lead_alerts_sent;

-- Verificar que se borraron (opcional, para confirmar)
-- SELECT 
--   (SELECT COUNT(*) FROM chat_logs) as chat_logs_count,
--   (SELECT COUNT(*) FROM extracted_contacts) as extracted_contacts_count,
--   (SELECT COUNT(*) FROM session_heartbeats) as session_heartbeats_count,
--   (SELECT COUNT(*) FROM lead_alerts_sent) as lead_alerts_sent_count;
