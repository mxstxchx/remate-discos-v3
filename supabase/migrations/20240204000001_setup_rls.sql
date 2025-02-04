-- Enable RLS
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Force RLS
ALTER TABLE devices FORCE ROW LEVEL SECURITY;
ALTER TABLE user_sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE reservations FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_logs FORCE ROW LEVEL SECURITY;

-- Core policies
DROP POLICY IF EXISTS device_access ON devices;
CREATE POLICY device_access ON devices
  FOR ALL
  USING (fingerprint = current_setting('app.device_fingerprint', true));

DROP POLICY IF EXISTS session_access ON user_sessions;
CREATE POLICY session_access ON user_sessions
  FOR ALL
  USING (
    device_id IN (
      SELECT id FROM devices 
      WHERE fingerprint = current_setting('app.device_fingerprint', true)
    )
    OR (
      is_admin = true AND 
      EXISTS (
        SELECT 1 FROM user_sessions s 
        JOIN devices d ON s.device_id = d.id
        WHERE d.fingerprint = current_setting('app.device_fingerprint', true)
        AND s.is_admin = true
      )
    )
  );

DROP POLICY IF EXISTS reservation_access ON reservations;
CREATE POLICY reservation_access ON reservations
  FOR ALL
  USING (
    session_id IN (
      SELECT id FROM user_sessions
      WHERE device_id IN (
        SELECT id FROM devices
        WHERE fingerprint = current_setting('app.device_fingerprint', true)
      )
    )
  );

DROP POLICY IF EXISTS audit_access ON audit_logs;
CREATE POLICY audit_access ON audit_logs
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_sessions s
      JOIN devices d ON s.device_id = d.id
      WHERE d.fingerprint = current_setting('app.device_fingerprint', true)
      AND s.is_admin = true
    )
  );