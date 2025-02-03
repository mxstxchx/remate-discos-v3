DO $$
DECLARE
  regular_device_id UUID;
  admin_device_id UUID;
  regular_session_id UUID;
  admin_session_id UUID;
  claims jsonb;
BEGIN
  SET session_replication_role = 'replica';
  
  INSERT INTO devices (fingerprint) VALUES ('regular_user_fp')
  RETURNING id INTO regular_device_id;
  
  INSERT INTO devices (fingerprint) VALUES ('admin_user_fp')
  RETURNING id INTO admin_device_id;

  INSERT INTO user_sessions (device_id, alias, is_admin, expires_at)
  VALUES (regular_device_id, 'regular_user', false, NOW() + INTERVAL '1 day')
  RETURNING id INTO regular_session_id;

  INSERT INTO user_sessions (device_id, alias, is_admin, expires_at)
  VALUES (admin_device_id, 'admin_user', true, NOW() + INTERVAL '1 day')
  RETURNING id INTO admin_session_id;

  SET session_replication_role = 'origin';

  -- Test 1: Basic RLS with request.device_fingerprint
  PERFORM set_config('request.device_fingerprint', 'regular_user_fp', true);
  SELECT get_session_claims() INTO claims;
  RAISE NOTICE 'Regular claims (request): %', claims;

  ASSERT EXISTS(
    SELECT 1 FROM user_sessions WHERE id = regular_session_id
  ), 'Regular user cannot see own session (request prefix)';

  ASSERT NOT EXISTS(
    SELECT 1 FROM user_sessions WHERE id = admin_session_id
  ), 'Regular user can see admin session (request prefix)';

  -- Test 2: RLS with app.device_fingerprint
  PERFORM set_config('app.device_fingerprint', 'regular_user_fp', true);
  SELECT get_session_claims() INTO claims;
  RAISE NOTICE 'Regular claims (app): %', claims;

  ASSERT EXISTS(
    SELECT 1 FROM user_sessions WHERE id = regular_session_id
  ), 'Regular user cannot see own session (app prefix)';

  -- Test 3: Admin access and inheritance
  PERFORM set_config('app.device_fingerprint', 'admin_user_fp', true);
  SELECT get_session_claims() INTO claims;
  RAISE NOTICE 'Admin claims: %', claims;

  ASSERT EXISTS(
    SELECT 1 FROM user_sessions
  ), 'Admin cannot see all sessions';

  -- Test 4: Active session validation
  UPDATE user_sessions SET is_active = false WHERE id = regular_session_id;
  PERFORM set_config('app.device_fingerprint', 'regular_user_fp', true);
  
  ASSERT NOT EXISTS(
    SELECT 1 FROM user_sessions WHERE id = regular_session_id
  ), 'Inactive session still visible';

  -- Test 5: Reservation and audit access
  UPDATE user_sessions SET is_active = true WHERE id = regular_session_id;

  INSERT INTO reservations (release_id, session_id, status)
  VALUES (1, regular_session_id, 'reserved');

  INSERT INTO audit_logs (session_id, action, details)
  VALUES (regular_session_id, 'test_action', '{}'::jsonb);

  PERFORM set_config('app.device_fingerprint', 'regular_user_fp', true);

  ASSERT EXISTS(
    SELECT 1 FROM reservations WHERE session_id = regular_session_id
  ), 'User cannot see own reservations';

  ASSERT EXISTS(
    SELECT 1 FROM audit_logs WHERE session_id = regular_session_id
  ), 'User cannot see own audit logs';

  RAISE NOTICE 'All RLS policy tests passed';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Test failed: %', SQLERRM;
  RAISE;
END;
$$ LANGUAGE plpgsql;