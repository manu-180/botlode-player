-- Añadir columnas explícitas de día y hora para reuniones (fácil de mostrar y filtrar)
ALTER TABLE bot_meetings
  ADD COLUMN IF NOT EXISTS scheduled_date DATE,
  ADD COLUMN IF NOT EXISTS scheduled_time TIME;

COMMENT ON COLUMN bot_meetings.scheduled_date IS 'Fecha local de la reunión (timezone del bot)';
COMMENT ON COLUMN bot_meetings.scheduled_time IS 'Hora local de inicio (timezone del bot)';
