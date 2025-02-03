CREATE OR REPLACE FUNCTION log_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO audit_logs (session_id, action, details)
    VALUES (
      NEW.session_id,
      'status_change',
      jsonb_build_object(
        'reservation_id', NEW.id,
        'old_status', OLD.status,
        'new_status', NEW.status
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER track_status_changes
  AFTER UPDATE OF status ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION log_status_change();