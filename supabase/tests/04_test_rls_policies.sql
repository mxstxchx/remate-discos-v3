DO $$
DECLARE
  regular_fp TEXT := 'regular_user_fp';
  admin_fp TEXT := 'admin_user_fp';
  regular_session_id UUID;
  admin_session_id UUID;
BEGIN
  -- Setup test sessions
  INSERT INTO devices (fingerprint) VALUES
    (regular_fp),
    (admin_fp);

  INSERT INTO user_sessions (device_id, alias, is_admin)
  SELECT id, 'regular_user', false
  FROM devices WHERE fingerprint = regular_fp
  RETURNING id INTO regular_session_id;

  INSERT INTO user_sessions (device_id, alias, is_admin)
  SELECT id, 'admin_user', true
  FROM devices WHERE fingerprint = admin_fp
  RETURNING id INTO admin_session_id;

  -- Set session context
  PERFORM set_config('app.device_fingerprint', regular_fp, true);

  -- Test 1: Regular User Access
  ASSERT EXISTS(
    SELECT 1 FROM user_sessions
    WHERE device_id IN (SELECT id FROM devices WHERE fingerprint = regular_fp)
  ), 'Regular user cannot see own session';

  ASSERT NOT EXISTS(
    SELECT 1 FROM user_sessions
    WHERE device_id IN (SELECT id FROM devices WHERE fingerprint = admin_fp)
  ), 'Regular user can see other sessions';

  -- Test 2: Admin Access
  PERFORM set_config('app.device_fingerprint', admin_fp, true);

  ASSERT EXISTS(
    SELECT 1 FROM audit_logs
  ), 'Admin cannot access audit logs';

  -- Test 3: Reservation Access
  INSERT INTO reservations (release_id, session_id, status)
  VALUES (1, regular_session_id, 'reserved');

  PERFORM set_config('app.device_fingerprint', regular_fp, true);
  
  ASSERT EXISTS(
    SELECT 1 FROM reservations
    WHERE session_id = regular_session_id
  ), 'User cannot see own reservations';

  RAISE NOTICE 'All RLS policy tests passed';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Test failed: %', SQLERRM;
  RAISE;
END;
$$ LANGUAGE plpgsql;