-- Update session management triggers
CREATE OR REPLACE FUNCTION handle_session_expiration()
RETURNS trigger AS $$
BEGIN
  -- Only process active sessions
  IF OLD.is_active = TRUE AND 
    (NEW.is_active = FALSE OR NEW.expires_at < now()) THEN
    
    -- Insert audit log
    INSERT INTO audit_logs (session_id, action, details)
    VALUES (
      OLD.id,
      'session_expired',
      jsonb_build_object(
        'reason', CASE 
          WHEN NEW.is_active = FALSE THEN 'deactivated'
          ELSE 'expired'
        END,
        'expires_at', OLD.expires_at
      )
    );
    
    -- Update affected reservations
    UPDATE reservations
    SET status = 'expired',
        updated_at = now()
    WHERE session_id = OLD.id
      AND status NOT IN ('sold', 'expired', 'cancelled');
      
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
DROP TRIGGER IF EXISTS session_expiration_trigger ON user_sessions;
CREATE TRIGGER session_expiration_trigger
  AFTER UPDATE
  ON user_sessions
  FOR EACH ROW
  EXECUTE FUNCTION handle_session_expiration();