DO $$
DECLARE
  regular_device_id UUID;
  admin_device_id UUID;
  regular_session_id UUID;
  admin_session_id UUID;
  r RECORD;
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

  -- Regular user tests
  PERFORM set_config('request.device_fingerprint', 'regular_fp', TRUE);
  
  RAISE NOTICE 'Current device_fp: %, session_id: %', 
    current_setting('request.device_fingerprint', TRUE),
    get_session_id();

  FOR r IN SELECT * FROM debug_session_policy(regular_session_id) LOOP
    RAISE NOTICE '% = %', r.check_name, r.result;
  END LOOP;

  RAISE NOTICE 'Visible sessions: %', (
    SELECT string_agg(alias, ', ') FROM user_sessions
  );

  ASSERT (SELECT COUNT(*) FROM user_sessions) = 1,
    'Regular user should only see their session';

END;
$$ LANGUAGE plpgsql;