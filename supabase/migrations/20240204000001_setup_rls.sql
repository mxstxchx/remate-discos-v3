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

DROP POLICY IF EXISTS device_access ON devices;
CREATE POLICY device_access ON devices FOR ALL USING (
  fingerprint = current_setting('app.device_fingerprint', true)
);

DROP POLICY IF EXISTS session_access ON user_sessions;
CREATE POLICY session_access ON user_sessions FOR ALL USING (
  device_id IN (
    SELECT id FROM devices 
    WHERE fingerprint = current_setting('app.device_fingerprint', true)
  )
);
