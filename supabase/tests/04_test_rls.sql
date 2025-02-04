DO $$
DECLARE
  regular_device_id UUID;
  admin_device_id UUID;
  regular_session_id UUID;
  admin_session_id UUID;
  test_reservation_id UUID;
BEGIN
  -- Setup
  TRUNCATE devices, user_sessions, reservations, audit_logs CASCADE;
  
  -- Regular user setup
  INSERT INTO devices (fingerprint) 
  VALUES ('regular_fp')
  RETURNING id INTO regular_device_id;
  
  INSERT INTO user_sessions (device_id, alias, is_admin, expires_at)
  VALUES (regular_device_id, 'regular', FALSE, NOW() + INTERVAL '1 day')
  RETURNING id INTO regular_session_id;

  -- Admin user setup
  INSERT INTO devices (fingerprint) 
  VALUES ('admin_fp')
  RETURNING id INTO admin_device_id;
  
  INSERT INTO user_sessions (device_id, alias, is_admin, expires_at)
  VALUES (admin_device_id, 'admin', TRUE, NOW() + INTERVAL '1 day')
  RETURNING id INTO admin_session_id;

  -- Test data
  INSERT INTO reservations (release_id, session_id, status)
  VALUES (1, regular_session_id, 'reserved')
  RETURNING id INTO test_reservation_id;

  INSERT INTO audit_logs (session_id, action, details)
  VALUES (regular_session_id, 'create_reservation', jsonb_build_object('reservation_id', test_reservation_id));

  -- Regular user tests
  PERFORM set_config('request.device_fingerprint', 'regular_fp', TRUE);
  
  RAISE NOTICE 'Regular user test - device_fp: %', current_setting('request.device_fingerprint', TRUE);
  RAISE NOTICE 'Regular user test - session_id: %', get_session_id();
  RAISE NOTICE 'Regular user test - visible sessions: %', (SELECT COUNT(*) FROM user_sessions);

  ASSERT (SELECT COUNT(*) FROM user_sessions) = 1,
    'Regular user should only see their session';

  ASSERT (SELECT COUNT(*) FROM reservations) = 1,
    'Regular user should see their reservation';

  ASSERT (SELECT COUNT(*) FROM audit_logs) = 0,
    'Regular user should not see audit logs';

  -- Admin user tests
  PERFORM set_config('request.device_fingerprint', 'admin_fp', TRUE);
  
  RAISE NOTICE 'Admin user test - device_fp: %', current_setting('request.device_fingerprint', TRUE);
  RAISE NOTICE 'Admin user test - session_id: %', get_session_id();
  RAISE NOTICE 'Admin user test - visible sessions: %', (SELECT COUNT(*) FROM user_sessions);

  ASSERT (SELECT COUNT(*) FROM user_sessions) = 2,
    'Admin should see all sessions';

  ASSERT (SELECT COUNT(*) FROM reservations) = 1,
    'Admin should see all reservations';

  ASSERT (SELECT COUNT(*) FROM audit_logs) = 1,
    'Admin should see audit logs';

  -- Edge cases
  UPDATE user_sessions 
  SET expires_at = NOW() - INTERVAL '1 minute' 
  WHERE id = regular_session_id;

  PERFORM set_config('request.device_fingerprint', 'regular_fp', TRUE);
  
  ASSERT (SELECT COUNT(*) FROM user_sessions) = 0,
    'Expired session should not be visible';

  RAISE NOTICE 'All RLS tests passed';
END;
$$ LANGUAGE plpgsql;