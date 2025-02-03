-- Session Management Functions
CREATE OR REPLACE FUNCTION create_session(
  p_device_fingerprint TEXT,
  p_alias TEXT,
  p_language TEXT DEFAULT 'es-ES'
) RETURNS UUID AS $$
DECLARE
  v_device_id UUID;
  v_session_id UUID;
BEGIN
  -- Get or create device
  INSERT INTO devices (fingerprint)
  VALUES (p_device_fingerprint)
  ON CONFLICT (fingerprint) DO UPDATE
  SET last_seen = NOW()
  RETURNING id INTO v_device_id;

  -- Create new session
  INSERT INTO user_sessions (device_id, alias, language, expires_at)
  VALUES (
    v_device_id,
    p_alias,
    p_language,
    NOW() + INTERVAL '30 days'
  )
  RETURNING id INTO v_session_id;

  RETURN v_session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION validate_session(p_session_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM user_sessions s
    WHERE s.id = p_session_id
    AND s.expires_at > NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION refresh_session(p_session_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE user_sessions
  SET 
    last_active = NOW(),
    expires_at = NOW() + INTERVAL '30 days'
  WHERE id = p_session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;