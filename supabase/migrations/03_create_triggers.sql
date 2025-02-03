-- Auto-update last_active on session access
CREATE OR REPLACE FUNCTION update_session_last_active()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_active = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER session_last_active
  BEFORE UPDATE ON user_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_session_last_active();

-- Auto-expire reservations
CREATE OR REPLACE FUNCTION expire_reservations()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'reserved' THEN
    NEW.expires_at = NOW() + INTERVAL '7 days';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_reservation_expiry
  BEFORE INSERT OR UPDATE ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION expire_reservations();