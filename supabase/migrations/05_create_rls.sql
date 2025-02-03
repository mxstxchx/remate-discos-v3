-- Enable RLS
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Session context handling
CREATE OR REPLACE FUNCTION get_device_fingerprint()
RETURNS TEXT AS $$
BEGIN
  RETURN COALESCE(
    current_setting('app.device_fingerprint', TRUE),
    current_setting('request.device_fingerprint', TRUE)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_session_claims()
RETURNS jsonb AS $$
DECLARE
  claims jsonb;
BEGIN
  SELECT jsonb_build_object(
    'session_id', s.id,
    'device_id', d.id,
    'alias', s.alias,
    'is_admin', s.is_admin
  ) INTO claims
  FROM user_sessions s
  JOIN devices d ON s.device_id = d.id
  WHERE d.fingerprint = get_device_fingerprint()
  AND s.expires_at > now()
  ORDER BY s.created_at DESC
  LIMIT 1;
  
  RETURN claims;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Basic RLS policy
CREATE POLICY "No RLS for test" ON user_sessions FOR SELECT USING (true);
CREATE POLICY "No RLS for test" ON devices FOR SELECT USING (true);
CREATE POLICY "No RLS for test" ON reservations FOR SELECT USING (true);
CREATE POLICY "No RLS for test" ON audit_logs FOR SELECT USING (true);