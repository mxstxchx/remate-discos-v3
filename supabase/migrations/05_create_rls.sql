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
    'device_id', d.id,
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
CREATE POLICY "Devices viewable by owner" ON devices
  FOR SELECT USING (
    id = (get_session_claims()->>'device_id')::uuid
    OR (get_session_claims()->>'is_admin')::boolean
  );

-- Session policies
CREATE POLICY "Sessions viewable by owner" ON user_sessions
  FOR SELECT USING (
    device_id = (get_session_claims()->>'device_id')::uuid
    OR (get_session_claims()->>'is_admin')::boolean
  );

-- Reservation policies
CREATE POLICY "Reservations viewable by owner" ON reservations
  FOR SELECT USING (
    session_id = (get_session_claims()->>'session_id')::uuid
    OR (get_session_claims()->>'is_admin')::boolean
  );

-- Audit log policies
CREATE POLICY "Audit logs admin only" ON audit_logs
  FOR SELECT USING (
    (get_session_claims()->>'is_admin')::boolean
  );