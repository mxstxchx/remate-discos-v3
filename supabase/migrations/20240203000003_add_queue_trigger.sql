CREATE OR REPLACE FUNCTION manage_queue_position()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'in_queue' THEN
    SELECT COALESCE(MAX(position_in_queue), 0) + 1
    INTO NEW.position_in_queue
    FROM reservations
    WHERE release_id = NEW.release_id
    AND status = 'in_queue';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_queue_position
  BEFORE INSERT OR UPDATE ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION manage_queue_position();