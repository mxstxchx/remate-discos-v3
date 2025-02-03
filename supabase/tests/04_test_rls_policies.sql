DO $$
DECLARE
  regular_device_id UUID;
  admin_device_id UUID;
  regular_session_id UUID;
  admin_session_id UUID;
  claims jsonb;
BEGIN
  -- Setup test devices
  INSERT INTO devices (fingerprint) VALUES ('regular_user_fp')
  RETURNING id INTO regular_device_id;
  
  INSERT INTO devices (fingerprint) VALUES ('admin_user_fp')
  RETURNING id INTO admin_device_id;

  -- Setup test sessions with expiration
  INSERT INTO user_sessions (device_id, alias, is_admin, expires_at)
  VALUES (regular_device_id, 'regular_user', false, NOW() + INTERVAL '1 day')
  RETURNING id INTO regular_session_id;

  INSERT INTO user_sessions (device_id, alias, is_admin, expires_at)
  VALUES (admin_device_id, 'admin_user', true, NOW() + INTERVAL '1 day')
  RETURNING id INTO admin_session_id;

  -- Debug claim generation
  PERFORM set_config('request.device_fingerprint', 'regular_user_fp', true);
  SELECT get_session_claims() INTO claims;
  RAISE NOTICE 'Regular claims: %', claims;
  RAISE NOTICE 'Regular session id: %', regular_session_id;

  -- Test 1: Regular User Access
  ASSERT EXISTS(
    SELECT 1 FROM user_sessions WHERE id = regular_session_id
  ), 'Regular user cannot see own session';

  ASSERT NOT EXISTS(
    SELECT 1 FROM user_sessions WHERE id = admin_session_id
  ), 'Regular user can see other sessions';

  -- Debug admin claims
  PERFORM set_config('request.device_fingerprint', 'admin_user_fp', true);
  SELECT get_session_claims() INTO claims;
  RAISE NOTICE 'Admin claims: %', claims;
  RAISE NOTICE 'Admin session id: %', admin_session_id;

  ASSERT EXISTS(
    SELECT 1 FROM audit_logs
  ), 'Admin cannot access audit logs';

  RAISE NOTICE 'All RLS policy tests passed';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Test failed: %', SQLERRM;
  RAISE;
END;
$$ LANGUAGE plpgsql;