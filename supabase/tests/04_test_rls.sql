DO $$
DECLARE
  regular_device_id UUID;
  admin_device_id UUID;
  regular_session_id UUID;
  admin_session_id UUID;
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
  PERFORM set_config('app.device_fingerprint', 'regular_fp', true);
  ASSERT (SELECT COUNT(*) FROM user_sessions) = 1,
    'Regular user should only see their session';

  -- Admin user tests
  PERFORM set_config('app.device_fingerprint', 'admin_fp', true);
  ASSERT (SELECT COUNT(*) FROM user_sessions) = 2,
    'Admin should see all sessions';

END;
$$ LANGUAGE plpgsql;