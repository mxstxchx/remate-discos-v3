DO $$
DECLARE
  regular_device_id UUID;
  admin_device_id UUID;
  regular_session_id UUID;
  admin_session_id UUID;
  claims jsonb;
  debug_info jsonb;
BEGIN
  RAISE NOTICE 'Test setup start';
  SET session_replication_role = 'replica';
  
  INSERT INTO devices (fingerprint) VALUES ('regular_user_fp')
  RETURNING id, fingerprint INTO regular_device_id, debug_info;
  RAISE NOTICE 'Regular device created: %', debug_info;
  
  INSERT INTO devices (fingerprint) VALUES ('admin_user_fp')
  RETURNING id, fingerprint INTO admin_device_id, debug_info;
  RAISE NOTICE 'Admin device created: %', debug_info;

  INSERT INTO user_sessions (device_id, alias, is_admin, expires_at)
  VALUES (regular_device_id, 'regular_user', false, NOW() + INTERVAL '1 day')
  RETURNING id, alias, is_admin INTO regular_session_id, debug_info;
  RAISE NOTICE 'Regular session created: %', debug_info;

  INSERT INTO user_sessions (device_id, alias, is_admin, expires_at)
  VALUES (admin_device_id, 'admin_user', true, NOW() + INTERVAL '1 day')
  RETURNING id, alias, is_admin INTO admin_session_id, debug_info;
  RAISE NOTICE 'Admin session created: %', debug_info;

  SET session_replication_role = 'origin';
  RAISE NOTICE 'Test setup complete';

  RAISE NOTICE 'Starting RLS tests...';
  
  -- Test basic session visibility
  PERFORM set_config('request.device_fingerprint', 'regular_user_fp', true);
  SELECT get_session_claims() INTO claims;
  RAISE NOTICE 'Regular user claims: %', claims;
  
  SELECT count(*) INTO debug_info FROM user_sessions;
  RAISE NOTICE 'Total sessions visible: %', debug_info;
  
  SELECT count(*) INTO debug_info FROM user_sessions WHERE id = regular_session_id;
  RAISE NOTICE 'Own sessions visible: %', debug_info;
  
  SELECT count(*) INTO debug_info FROM user_sessions WHERE id = admin_session_id;
  RAISE NOTICE 'Admin sessions visible: %', debug_info;

  ASSERT EXISTS(
    SELECT 1 FROM user_sessions WHERE id = regular_session_id
  ), 'Regular user cannot see own session';

  ASSERT NOT EXISTS(
    SELECT 1 FROM user_sessions WHERE id = admin_session_id
  ), 'Regular user can see other sessions';

  RAISE NOTICE 'Test complete';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Test failed at % with %', debug_info, SQLERRM;
  RAISE;
END;
$$ LANGUAGE plpgsql;