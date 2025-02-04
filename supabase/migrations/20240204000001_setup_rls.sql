-- Enable and force RLS
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

ALTER TABLE devices FORCE ROW LEVEL SECURITY;
ALTER TABLE user_sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE reservations FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_logs FORCE ROW LEVEL SECURITY;

-- Helper function
CREATE OR REPLACE FUNCTION is_admin_device()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_sessions s
    JOIN devices d ON s.device_id = d.id
    WHERE d.fingerprint = current_setting('app.device_fingerprint', true)
    AND s.is_admin = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Core policies
DROP POLICY IF EXISTS session_access ON user_sessions;
CREATE POLICY session_access ON user_sessions FOR ALL
USING (
  CASE WHEN is_admin_device() THEN true
  ELSE (
    SELECT d.id = user_sessions.device_id 
    FROM devices d 
    WHERE d.fingerprint = current_setting('app.device_fingerprint', true)
  )
  END
);

DROP POLICY IF EXISTS device_access ON devices;
CREATE POLICY device_access ON devices FOR ALL
USING (
  fingerprint = current_setting('app.device_fingerprint', true) OR
  is_admin_device()
);

DROP POLICY IF EXISTS reservation_access ON reservations;
CREATE POLICY reservation_access ON reservations FOR ALL
USING (
  CASE WHEN is_admin_device() THEN true
  ELSE (
    SELECT s.id = reservations.session_id
    FROM user_sessions s
    JOIN devices d ON s.device_id = d.id
    WHERE d.fingerprint = current_setting('app.device_fingerprint', true)
  )
  END
);

DROP POLICY IF EXISTS audit_access ON audit_logs;
CREATE POLICY audit_access ON audit_logs FOR ALL
USING (is_admin_device());