DO $$
DECLARE
  test_session_id UUID;
  test_release_id BIGINT;
  reservation_id UUID;
BEGIN
  -- Setup test data
  INSERT INTO devices (fingerprint) VALUES ('test_fp_reserv')
  RETURNING id INTO STRICT test_session_id;
  
  INSERT INTO user_sessions (device_id, alias)
  VALUES (test_session_id, 'test_reserv_user');
  
  -- Test 1: Create Reservation
  INSERT INTO reservations (release_id, session_id, status)
  VALUES (1, test_session_id, 'reserved')
  RETURNING id INTO STRICT reservation_id;
  
  ASSERT EXISTS(
    SELECT 1 FROM reservations
    WHERE id = reservation_id
    AND expires_at IS NOT NULL
  ), 'Expiration not set';

  -- Test 2: Queue Position
  UPDATE reservations
  SET status = 'in_queue'
  WHERE id = reservation_id;
  
  ASSERT EXISTS(
    SELECT 1 FROM reservations
    WHERE id = reservation_id
    AND position_in_queue IS NOT NULL
  ), 'Queue position not assigned';

  -- Test 3: Status Transitions
  UPDATE reservations
  SET status = 'expired'
  WHERE id = reservation_id;
  
  ASSERT EXISTS(
    SELECT 1 FROM audit_logs
    WHERE details->>'reservation_id' = reservation_id::text
  ), 'Status change not logged';

  -- Test 4: Concurrent Reservations
  ASSERT NOT EXISTS(
    SELECT 1 FROM reservations
    WHERE session_id = test_session_id
    AND status = 'reserved'
    GROUP BY release_id
    HAVING COUNT(*) > 1
  ), 'Multiple active reservations found';

  RAISE NOTICE 'All reservation tests passed';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Test failed: %', SQLERRM;
  RAISE;
END;
$$ LANGUAGE plpgsql;