-- Enable RLS
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Utility functions for RLS
CREATE OR REPLACE FUNCTION get_session_claims()
RETURNS jsonb AS $$
DECLARE
  device_fp text;
  claims jsonb;
BEGIN
  device_fp := current_setting('app.device_fingerprint', TRUE);
  
  SELECT jsonb_build_object(
    'session_id', s.id,
    'alias', s.alias,
    'is_admin', s.is_admin
  ) INTO claims
  FROM user_sessions s
  JOIN devices d ON s.device_id = d.id
  WHERE d.fingerprint = device_fp
  AND s.expires_at > now()
  ORDER BY s.created_at DESC
  LIMIT 1;
  
  RETURN claims;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Device policies
CREATE POLICY "Devices viewable by fingerprint" ON devices
  FOR SELECT USING (
    fingerprint = current_setting('app.device_fingerprint', TRUE)
  );

CREATE POLICY "Devices updatable by fingerprint" ON devices
  FOR UPDATE USING (
    fingerprint = current_setting('app.device_fingerprint', TRUE)
  );

-- Session policies
CREATE POLICY "Sessions viewable by device" ON user_sessions
  FOR SELECT USING (
    device_id IN (
      SELECT id FROM devices
      WHERE fingerprint = current_setting('app.device_fingerprint', TRUE)
    )
  );

CREATE POLICY "Sessions deletable by device" ON user_sessions
  FOR DELETE USING (
    device_id IN (
      SELECT id FROM devices
      WHERE fingerprint = current_setting('app.device_fingerprint', TRUE)
    )
  );

-- Reservation policies
CREATE POLICY "Reservations viewable by session" ON reservations
  FOR SELECT USING (
    session_id::text = (get_session_claims()->>'session_id')::text
    OR (get_session_claims()->>'is_admin')::boolean = true
  );

CREATE POLICY "Reservations updatable by session" ON reservations
  FOR UPDATE USING (
    session_id::text = (get_session_claims()->>'session_id')::text
    OR (get_session_claims()->>'is_admin')::boolean = true
  );

CREATE POLICY "Reservations deletable by session" ON reservations
  FOR DELETE USING (
    session_id::text = (get_session_claims()->>'session_id')::text
    OR (get_session_claims()->>'is_admin')::boolean = true
  );

-- Audit log policies
CREATE POLICY "Audit logs viewable by admin" ON audit_logs
  FOR SELECT USING (
    (get_session_claims()->>'is_admin')::boolean = true
  );

CREATE POLICY "Audit logs viewable by session" ON audit_logs
  FOR SELECT USING (
    session_id::text = (get_session_claims()->>'session_id')::text
  );