DO $$
DECLARE
  test_device UUID;
  test_session UUID;
  test_release_1 BIGINT := 1;
  test_release_2 BIGINT := 2;
  reservation_1 UUID;
  reservation_2 UUID;
BEGIN
  -- Setup
  BEGIN;
  SET session_replication_role = 'replica';

  INSERT INTO devices (fingerprint)
  VALUES ('reservation_test_fp')
  RETURNING id INTO test_device;

  INSERT INTO user_sessions (device_id, alias, expires_at)
  VALUES (test_device, 'reservation_user', NOW() + INTERVAL '1 day')
  RETURNING id INTO test_session;

  INSERT INTO test_releases (id, title, artists, labels, styles, condition, price, images)
  VALUES
    (test_release_1, 'Test 1', ARRAY['Artist'], '{}'::jsonb, ARRAY['Style'], 'NM', 10.00, '{}'::jsonb),
    (test_release_2, 'Test 2', ARRAY['Artist'], '{}'::jsonb, ARRAY['Style'], 'VG+', 15.00, '{}'::jsonb);

  SET session_replication_role = 'origin';
  COMMIT;

  -- Test 1: Create Reservation
  INSERT INTO reservations (release_id, session_id, status)
  VALUES (test_release_1, test_session, 'reserved')
  RETURNING id INTO reservation_1;

  ASSERT EXISTS(
    SELECT 1 FROM reservations
    WHERE id = reservation_1
    AND expires_at IS NOT NULL
  ), 'Reservation expiry not set';

  -- Test 2: Queue Position
  INSERT INTO reservations (release_id, session_id, status)
  VALUES (test_release_1, test_session, 'in_queue')
  RETURNING id INTO reservation_2;

  ASSERT EXISTS(
    SELECT 1 FROM reservations
    WHERE id = reservation_2
    AND position_in_queue IS NOT NULL
  ), 'Queue position not assigned';

  -- Test 3: Status Transitions
  UPDATE reservations
  SET status = 'expired'
  WHERE id = reservation_1;

  ASSERT EXISTS(
    SELECT 1 FROM audit_logs
    WHERE session_id = test_session
    AND action = 'status_change'
  ), 'Status change not audited';

  -- Test 4: Queue Promotion
  UPDATE reservations
  SET status = 'reserved'
  WHERE id = reservation_2;

  ASSERT NOT EXISTS(
    SELECT 1 FROM reservations
    WHERE id = reservation_2
    AND position_in_queue IS NOT NULL
  ), 'Queue position not cleared';

  RAISE NOTICE 'Reservation tests completed';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Test failed: % %', SQLERRM, SQLSTATE;
  RAISE;
END;
$$ LANGUAGE plpgsql;
