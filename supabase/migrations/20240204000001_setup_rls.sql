-- Functions
CREATE OR REPLACE FUNCTION get_session_id() 
RETURNS UUID AS $$
DECLARE
  session_id UUID;
BEGIN
  SELECT s.id INTO session_id
  FROM user_sessions s
  JOIN devices d ON s.device_id = d.id
  WHERE d.fingerprint = current_setting('app.device_fingerprint', true)
  AND s.expires_at > NOW()
  LIMIT 1;
  RETURN session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_admin_session()
RETURNS BOOLEAN AS $$
DECLARE
  session_id UUID;
BEGIN
  session_id := get_session_id();
  RETURN EXISTS (
    SELECT 1 FROM user_sessions
    WHERE id = session_id
    AND is_admin = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
  USING (id = get_session_id() OR is_admin_session());

DROP POLICY IF EXISTS reservation_access ON reservations;
CREATE POLICY reservation_access ON reservations
  FOR ALL
  USING (session_id = get_session_id() OR is_admin_session());

DROP POLICY IF EXISTS audit_access ON audit_logs;
CREATE POLICY audit_access ON audit_logs
  FOR ALL
  USING (is_admin_session());