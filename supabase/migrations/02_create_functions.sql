-- Session Management
CREATE OR REPLACE FUNCTION create_session(
  device_fingerprint text,
  alias text,
  language text DEFAULT 'es-CL'
) RETURNS UUID AS $$
DECLARE
  device_id UUID;
  session_id UUID;
BEGIN
  -- Get or create device
  INSERT INTO devices (fingerprint)
  VALUES (device_fingerprint)
  ON CONFLICT (fingerprint) DO UPDATE
  SET last_seen = NOW()
  RETURNING id INTO device_id;

  -- Create session
  INSERT INTO sessions (device_id, alias, language, expires_at)
  VALUES (device_id, alias, language, NOW() + INTERVAL '30 days')
  RETURNING id INTO session_id;

  RETURN session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cleanup Functions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS void AS $$
BEGIN
  UPDATE sessions
  SET expires_at = NOW()
  WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;