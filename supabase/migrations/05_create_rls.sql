-- Enable RLS
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Drop default policies
DROP POLICY IF EXISTS "No RLS for test" ON user_sessions;
DROP POLICY IF EXISTS "No RLS for test" ON devices;
DROP POLICY IF EXISTS "No RLS for test" ON reservations;
DROP POLICY IF EXISTS "No RLS for test" ON audit_logs;

-- Context functions
CREATE OR REPLACE FUNCTION get_session_claims()
RETURNS jsonb AS $$
DECLARE
  device_fp text;
  claims jsonb;
BEGIN
  device_fp := current_setting('request.device_fingerprint', TRUE);
  
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

-- Session-based policies
CREATE POLICY session_select_policy ON user_sessions
  FOR SELECT USING (
    id = (get_session_claims()->>'session_id')::uuid
    OR (get_session_claims()->>'is_admin')::boolean = true
  );