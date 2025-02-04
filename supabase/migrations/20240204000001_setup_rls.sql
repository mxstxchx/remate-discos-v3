ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS device_access ON devices;
CREATE POLICY device_access ON devices FOR ALL USING (
  fingerprint = current_setting('app.device_fingerprint', true)
);

DROP POLICY IF EXISTS session_access ON user_sessions;
CREATE POLICY session_access ON user_sessions FOR ALL USING (
  EXISTS (
    SELECT 1 FROM devices d
    WHERE d.fingerprint = current_setting('app.device_fingerprint', true)
    AND d.id = user_sessions.device_id
  )
);