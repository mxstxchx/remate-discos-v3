-- Update session claims function to handle NULL fingerprints
CREATE OR REPLACE FUNCTION get_session_claims()
RETURNS jsonb AS $$
DECLARE
  device_fp text;
  claims jsonb;
BEGIN
  -- Get current device fingerprint from request setting
  BEGIN
    device_fp := current_setting('app.device_fingerprint', TRUE);
  EXCEPTION WHEN undefined_object THEN
    device_fp := current_setting('request.device_fingerprint', TRUE);
  END;
  
  -- Return NULL claims if no fingerprint
  IF device_fp IS NULL THEN
    RETURN NULL;
  END IF;
  
  -- Get session data with explicit NULL handling
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
    AND s.is_active = true
  ORDER BY s.created_at DESC
  LIMIT 1;
  
  RETURN claims;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check admin status
CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN COALESCE((get_session_claims()->>'is_admin')::boolean, FALSE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;