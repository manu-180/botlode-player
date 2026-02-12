-- Calendario comercial por bot
-- Settings + disponibilidad semanal + reuniones reservadas

CREATE TABLE IF NOT EXISTS bot_calendar_settings (
  bot_id UUID PRIMARY KEY REFERENCES bots(id) ON DELETE CASCADE,
  is_enabled BOOLEAN NOT NULL DEFAULT false,
  meeting_duration_minutes INTEGER NOT NULL DEFAULT 30 CHECK (meeting_duration_minutes IN (15, 30, 45, 60, 90, 120)),
  timezone TEXT NOT NULL DEFAULT 'America/Argentina/Buenos_Aires',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS bot_calendar_availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bot_id UUID NOT NULL REFERENCES bots(id) ON DELETE CASCADE,
  weekday SMALLINT NOT NULL CHECK (weekday BETWEEN 0 AND 6),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  is_enabled BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  CHECK (start_time < end_time)
);

CREATE TABLE IF NOT EXISTS bot_meetings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bot_id UUID NOT NULL REFERENCES bots(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL,
  lead_phone TEXT,
  lead_name TEXT,
  scheduled_at TIMESTAMP WITH TIME ZONE NOT NULL,
  duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
  status TEXT NOT NULL DEFAULT 'booked' CHECK (status IN ('booked', 'cancelled')),
  source_message TEXT,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_calendar_availability_bot_weekday
  ON bot_calendar_availability(bot_id, weekday);

CREATE INDEX IF NOT EXISTS idx_meetings_bot_scheduled_at
  ON bot_meetings(bot_id, scheduled_at);

CREATE INDEX IF NOT EXISTS idx_meetings_session
  ON bot_meetings(session_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_meetings_booked_slot
  ON bot_meetings(bot_id, scheduled_at)
  WHERE status = 'booked';

-- RLS
ALTER TABLE bot_calendar_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE bot_calendar_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE bot_meetings ENABLE ROW LEVEL SECURITY;

-- Políticas permisivas para operación desde apps y edge functions
DROP POLICY IF EXISTS "Cualquiera puede ver calendar settings" ON bot_calendar_settings;
DROP POLICY IF EXISTS "Cualquiera puede insertar calendar settings" ON bot_calendar_settings;
DROP POLICY IF EXISTS "Cualquiera puede actualizar calendar settings" ON bot_calendar_settings;
CREATE POLICY "Cualquiera puede ver calendar settings" ON bot_calendar_settings
  FOR SELECT USING (true);
CREATE POLICY "Cualquiera puede insertar calendar settings" ON bot_calendar_settings
  FOR INSERT WITH CHECK (true);
CREATE POLICY "Cualquiera puede actualizar calendar settings" ON bot_calendar_settings
  FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Cualquiera puede ver calendar availability" ON bot_calendar_availability;
DROP POLICY IF EXISTS "Cualquiera puede insertar calendar availability" ON bot_calendar_availability;
DROP POLICY IF EXISTS "Cualquiera puede actualizar calendar availability" ON bot_calendar_availability;
DROP POLICY IF EXISTS "Cualquiera puede borrar calendar availability" ON bot_calendar_availability;
CREATE POLICY "Cualquiera puede ver calendar availability" ON bot_calendar_availability
  FOR SELECT USING (true);
CREATE POLICY "Cualquiera puede insertar calendar availability" ON bot_calendar_availability
  FOR INSERT WITH CHECK (true);
CREATE POLICY "Cualquiera puede actualizar calendar availability" ON bot_calendar_availability
  FOR UPDATE USING (true);
CREATE POLICY "Cualquiera puede borrar calendar availability" ON bot_calendar_availability
  FOR DELETE USING (true);

DROP POLICY IF EXISTS "Cualquiera puede ver meetings" ON bot_meetings;
DROP POLICY IF EXISTS "Service role puede insertar meetings" ON bot_meetings;
DROP POLICY IF EXISTS "Service role puede actualizar meetings" ON bot_meetings;
CREATE POLICY "Cualquiera puede ver meetings" ON bot_meetings
  FOR SELECT USING (true);
CREATE POLICY "Service role puede insertar meetings" ON bot_meetings
  FOR INSERT WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "Service role puede actualizar meetings" ON bot_meetings
  FOR UPDATE USING (auth.role() = 'service_role');
