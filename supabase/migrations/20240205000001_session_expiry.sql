-- Add expiry tracking columns
ALTER TABLE sessions
  ADD COLUMN expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '7 days',
  ADD COLUMN last_active TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Create audit logs schema
CREATE TYPE action_type AS ENUM ('login', 'logout', 'refresh', 'session_expired');

CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  action action_type NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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

DROP TRIGGER IF EXISTS session_activity_refresh ON audit_logs;
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

DROP TRIGGER IF EXISTS session_expiry_audit ON sessions;
CREATE TRIGGER session_expiry_audit
  AFTER UPDATE ON sessions
  FOR EACH ROW
  EXECUTE FUNCTION log_session_expiry();

-- Enhance session access
CREATE OR REPLACE FUNCTION auth.get_session_access(session_id UUID)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM sessions s
    WHERE s.id = session_id
    AND (
      device_id IN (SELECT id FROM devices WHERE fingerprint = current_setting('app.device_fingerprint', TRUE)::text)
      OR EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.role = 'admin')
    )
    AND s.expires_at > NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;