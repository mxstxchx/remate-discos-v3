-- Enable RLS on all tables
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Simple session identification
CREATE FUNCTION get_session_id() 
RETURNS UUID AS $$
DECLARE
  device_fp TEXT;
  session_id UUID;
BEGIN
  device_fp := current_setting('request.device_fingerprint', TRUE);
  IF device_fp IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT s.id INTO session_id
  FROM user_sessions s
  JOIN devices d ON s.device_id = d.id
  WHERE d.fingerprint = device_fp
  AND s.expires_at > NOW()
  ORDER BY s.created_at DESC
  LIMIT 1;

  RETURN session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Policy for devices
CREATE POLICY device_access ON devices FOR ALL USING (
  EXISTS (
    SELECT 1 FROM user_sessions
    WHERE device_id = devices.id
    AND id = get_session_id()
  )
);

-- Policy for sessions
CREATE POLICY session_access ON user_sessions FOR ALL USING (
  id = get_session_id() OR
  EXISTS (
    SELECT 1 FROM user_sessions
    WHERE id = get_session_id()
    AND is_admin = true
  )
);

-- Policy for reservations
CREATE POLICY reservation_access ON reservations FOR ALL USING (
  session_id = get_session_id() OR
  EXISTS (
    SELECT 1 FROM user_sessions
    WHERE id = get_session_id()
    AND is_admin = true
  )
);

-- Policy for audit logs
CREATE POLICY audit_access ON audit_logs FOR ALL USING (
  EXISTS (
    SELECT 1 FROM user_sessions
    WHERE id = get_session_id()
    AND is_admin = true
  )
);