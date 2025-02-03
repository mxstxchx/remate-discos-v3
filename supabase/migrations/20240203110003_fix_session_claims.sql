CREATE OR REPLACE FUNCTION get_session_claims()
RETURNS jsonb AS $$
DECLARE
  device_fp text;
  claims jsonb;
BEGIN
  -- Try both prefixes
  BEGIN
    device_fp := COALESCE(
      current_setting('app.device_fingerprint', TRUE),
      current_setting('request.device_fingerprint', TRUE)
    );
  EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
  END;
  
  IF device_fp IS NULL THEN
    RETURN NULL;
  END IF;

  -- Log for debugging
  RAISE NOTICE 'Device fingerprint: %', device_fp;
  
  SELECT jsonb_build_object(
    'session_id', s.id,
    'device_id', d.id,
    'alias', s.alias,
    'is_admin', COALESCE(s.is_admin, FALSE)
  ) INTO claims
  FROM user_sessions s
  JOIN devices d ON s.device_id = d.id
  WHERE d.fingerprint = device_fp
    AND s.expires_at > now()
    AND s.is_active = TRUE
  ORDER BY s.created_at DESC
  LIMIT 1;

  -- Log matched session
  RAISE NOTICE 'Found claims: %', claims;
  
  RETURN claims;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
