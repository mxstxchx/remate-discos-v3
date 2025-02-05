-- Add expiry tracking columns
ALTER TABLE sessions
  ADD COLUMN expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '7 days',
  ADD COLUMN last_active TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Add session expired action type
ALTER TYPE action_type ADD VALUE IF NOT EXISTS 'session_expired';

-- Enhance session access check
CREATE OR REPLACE FUNCTION auth.get_session_access(session_id UUID)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM sessions s
    WHERE s.id = session_id
    AND (
      -- Existing fingerprint check
      device_id IN (SELECT id FROM devices WHERE fingerprint = current_setting('app.device_fingerprint', TRUE)::text)
      OR 
      -- Admin override
      EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid() AND u.role = 'admin')
    )
    -- Add expiry check
    AND s.expires_at > NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
