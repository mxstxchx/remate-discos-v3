-- Core tables
CREATE TABLE IF NOT EXISTS devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fingerprint TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID REFERENCES devices(id),
  alias TEXT NOT NULL,
  language TEXT DEFAULT 'es-ES',
  is_admin BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Basic RLS
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS session_access ON user_sessions;
CREATE POLICY session_access ON user_sessions FOR ALL USING (
  EXISTS (
    SELECT 1 FROM devices d
    WHERE d.fingerprint = current_setting('app.device_fingerprint', true)
    AND (
      d.id = user_sessions.device_id
      OR EXISTS (SELECT 1 FROM user_sessions s WHERE s.device_id = d.id AND s.is_admin = true)
    )
  )
);