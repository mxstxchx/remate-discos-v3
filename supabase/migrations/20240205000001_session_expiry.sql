-- Activity trigger
CREATE OR REPLACE FUNCTION refresh_session_expiry()
RETURNS trigger AS $$
BEGIN
  UPDATE sessions 
  SET last_active = NOW(),
      expires_at = NOW() + 
        CASE 
          WHEN trust_level = 'primary' THEN INTERVAL '30 days'
          ELSE INTERVAL '7 days'
        END
  WHERE id = NEW.session_id
  AND expires_at > NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER session_activity_refresh
  AFTER INSERT ON audit_logs
  FOR EACH ROW
  WHEN (NEW.action != 'session_expired')
  EXECUTE FUNCTION refresh_session_expiry();

-- Audit hook
CREATE OR REPLACE FUNCTION log_session_expiry()
RETURNS trigger AS $$
BEGIN
  IF OLD.expires_at > NOW() AND NEW.expires_at <= NOW() THEN
    INSERT INTO audit_logs (session_id, action)
    VALUES (NEW.id, 'session_expired');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER session_expiry_audit
  AFTER UPDATE ON sessions
  FOR EACH ROW
  EXECUTE FUNCTION log_session_expiry();

-- Fix session access
CREATE OR REPLACE FUNCTION auth.get_session_access(session_id UUID)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM sessions s
    JOIN devices d ON s.device_id = d.id
    WHERE s.id = session_id
    AND d.fingerprint = current_setting('app.device_fingerprint', TRUE)::text
    AND s.expires_at > NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;