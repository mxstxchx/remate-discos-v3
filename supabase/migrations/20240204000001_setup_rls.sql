-- Core RLS setup
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

ALTER TABLE devices FORCE ROW LEVEL SECURITY;
ALTER TABLE user_sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE reservations FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_logs FORCE ROW LEVEL SECURITY;

-- Single owner/admin policy per table
CREATE POLICY session_access ON user_sessions FOR ALL USING (
  EXISTS (
    SELECT 1 FROM devices d
    WHERE d.fingerprint = current_setting('app.device_fingerprint', true)
    AND (d.id = user_sessions.device_id OR user_sessions.is_admin = true)
  )
);

CREATE POLICY device_access ON devices FOR ALL USING (
  fingerprint = current_setting('app.device_fingerprint', true)
);

CREATE POLICY reservation_access ON reservations FOR ALL USING (
  EXISTS (
    SELECT 1 FROM user_sessions s
    JOIN devices d ON s.device_id = d.id
    WHERE d.fingerprint = current_setting('app.device_fingerprint', true)
    AND (s.id = reservations.session_id OR s.is_admin = true)
  )
);

CREATE POLICY audit_access ON audit_logs FOR ALL USING (
  EXISTS (
    SELECT 1 FROM user_sessions s
    JOIN devices d ON s.device_id = d.id
    WHERE d.fingerprint = current_setting('app.device_fingerprint', true)
    AND s.is_admin = true
  )
);