-- Update policies to use claims exclusively
DROP POLICY IF EXISTS session_select_policy ON user_sessions;
DROP POLICY IF EXISTS device_select_policy ON devices;

-- Update claims handling
CREATE OR REPLACE FUNCTION get_session_claims()
RETURNS jsonb AS $$
DECLARE
  device_fp text;
  claims jsonb;
  debug_info jsonb;
BEGIN
  RAISE NOTICE 'get_session_claims() start';
  
  -- Try both prefixes
  device_fp := COALESCE(
    current_setting('app.device_fingerprint', TRUE),
    current_setting('request.device_fingerprint', TRUE)
  );
  
  IF device_fp IS NULL THEN
    RETURN NULL;
  END IF;

  -- Get matching session
  WITH matching_session AS (
    SELECT 
      s.id,
      s.device_id,
      s.alias,
      s.is_admin,
      s.expires_at,
      s.is_active
    FROM user_sessions s
    JOIN devices d ON s.device_id = d.id
    WHERE d.fingerprint = device_fp
      AND s.expires_at > now()
      AND s.is_active = true
    ORDER BY s.created_at DESC
    LIMIT 1
  )
  SELECT 
    jsonb_build_object(
      'session_id', s.id,
      'device_id', s.device_id,
      'alias', s.alias,
      'is_admin', COALESCE(s.is_admin, false),
      'expires_at', s.expires_at,
      'is_active', s.is_active
    ) INTO claims
  FROM matching_session s;

  RAISE NOTICE 'Claims for fingerprint %: %', device_fp, claims;
  RETURN claims;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create improved policies using claims
CREATE POLICY session_select_policy ON user_sessions
  FOR SELECT USING (
    id = (get_session_claims()->>'session_id')::uuid
    OR device_id = (get_session_claims()->>'device_id')::uuid
    OR (get_session_claims()->>'is_admin')::boolean = true
  );

CREATE POLICY device_select_policy ON devices
  FOR SELECT USING (
    id = (get_session_claims()->>'device_id')::uuid
    OR (get_session_claims()->>'is_admin')::boolean = true
  );

-- Update other policies to use claims for admin check
CREATE OR REPLACE POLICY reservation_select_policy ON reservations
  FOR SELECT USING (
    session_id = (get_session_claims()->>'session_id')::uuid
    OR (get_session_claims()->>'is_admin')::boolean = true
  );

CREATE OR REPLACE POLICY audit_log_select_policy ON audit_logs
  FOR SELECT USING (
    session_id = (get_session_claims()->>'session_id')::uuid
    OR (get_session_claims()->>'is_admin')::boolean = true
  );