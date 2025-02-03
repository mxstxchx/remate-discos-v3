-- Add is_active flag to user_sessions
ALTER TABLE user_sessions
ADD COLUMN is_active boolean NOT NULL DEFAULT true;

-- Update get_session_claims to handle NULL is_active
CREATE OR REPLACE FUNCTION get_session_claims()
RETURNS jsonb AS $$
DECLARE
  device_fp text;
  claims jsonb;
  debug_info jsonb;
BEGIN
  RAISE NOTICE 'get_session_claims() start';
  
  -- Capture settings
  SELECT jsonb_build_object(
    'app_fp', current_setting('app.device_fingerprint', TRUE),
    'request_fp', current_setting('request.device_fingerprint', TRUE),
    'role', current_setting('role'),
    'session_role', current_setting('session_replication_role')
  ) INTO debug_info;
  
  RAISE NOTICE 'Settings: %', debug_info;
  
  -- Try both prefixes
  device_fp := COALESCE(
    current_setting('app.device_fingerprint', TRUE),
    current_setting('request.device_fingerprint', TRUE)
  );
  
  RAISE NOTICE 'Resolved fingerprint: %', device_fp;
  
  IF device_fp IS NULL THEN
    RAISE NOTICE 'No fingerprint found';
    RETURN NULL;
  END IF;

  -- Capture matching sessions for debugging
  WITH matching_sessions AS (
    SELECT 
      s.id,
      s.device_id,
      s.alias,
      s.is_admin,
      s.created_at,
      s.expires_at,
      s.is_active
    FROM user_sessions s
    JOIN devices d ON s.device_id = d.id
    WHERE d.fingerprint = device_fp
  )
  SELECT 
    jsonb_build_object(
      'session_id', s.id,
      'device_id', s.device_id,
      'alias', s.alias,
      'is_admin', COALESCE(s.is_admin, FALSE),
      'expires_at', s.expires_at,
      'is_active', COALESCE(s.is_active, FALSE)
    ) INTO claims
  FROM matching_sessions s
  WHERE s.expires_at > now()
    AND COALESCE(s.is_active, FALSE) = true
  ORDER BY s.created_at DESC
  LIMIT 1;

  RAISE NOTICE 'Found claims: %', claims;
  RETURN claims;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;