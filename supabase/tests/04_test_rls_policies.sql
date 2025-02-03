DO $$
DECLARE
  regular_device_id UUID;
  admin_device_id UUID;
  regular_session_id UUID;
  admin_session_id UUID;
BEGIN
  -- Setup test devices with unique fingerprints
  INSERT INTO devices (id, fingerprint) VALUES
    (gen_random_uuid(), 'regular_user_fp') RETURNING id INTO regular_device_id;
  INSERT INTO devices (id, fingerprint) VALUES
    (gen_random_uuid(), 'admin_user_fp') RETURNING id INTO admin_device_id;

  -- Setup test sessions
  INSERT INTO user_sessions (id, device_id, alias, is_admin)
  VALUES (gen_random_uuid(), regular_device_id, 'regular_user', false)
  RETURNING id INTO regular_session_id;

  INSERT INTO user_sessions (id, device_id, alias, is_admin)
  VALUES (gen_random_uuid(), admin_device_id, 'admin_user', true)
  RETURNING id INTO admin_session_id;

  -- Set session context
  PERFORM set_config('app.device_fingerprint', 'regular_user_fp', true);

  -- Test 1: Regular User Access
  ASSERT EXISTS(
    SELECT 1 FROM user_sessions
    WHERE id = regular_session_id
  ), 'Regular user cannot see own session';

  ASSERT NOT EXISTS(
    SELECT 1 FROM user_sessions
    WHERE id = admin_session_id
  ), 'Regular user can see other sessions';

  -- Test 2: Admin Access
  PERFORM set_config('app.device_fingerprint', 'admin_user_fp', true);

  ASSERT EXISTS(
    SELECT 1 FROM audit_logs
  ), 'Admin cannot access audit logs';

  -- Test 3: Reservation Access
  INSERT INTO reservations (release_id, session_id, status)
  VALUES (1, regular_session_id, 'reserved');

  PERFORM set_config('app.device_fingerprint', 'regular_user_fp', true);
  
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