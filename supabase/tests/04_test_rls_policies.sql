DO $$
DECLARE
  regular_device_id UUID;
  admin_device_id UUID;
  regular_session_id UUID;
  admin_session_id UUID;
  claims jsonb;
  debug_count integer;
  rls_info record;
BEGIN
  -- Clean initial state
  SET session_replication_role = 'origin';
  RAISE NOTICE 'Initial replication role: %', current_setting('session_replication_role');

  -- Setup test data
  SET session_replication_role = 'replica';
  
  INSERT INTO devices (fingerprint) VALUES 
    ('regular_user_fp'),
    ('admin_user_fp')
  RETURNING id INTO regular_device_id;
  SELECT id INTO admin_device_id FROM devices WHERE fingerprint = 'admin_user_fp' LIMIT 1;

  INSERT INTO user_sessions (device_id, alias, is_admin, expires_at)
  VALUES 
    (regular_device_id, 'regular_user', false, NOW() + INTERVAL '1 day'),
    (admin_device_id, 'admin_user', true, NOW() + INTERVAL '1 day')
  RETURNING id INTO regular_session_id;
  SELECT id INTO admin_session_id FROM user_sessions WHERE alias = 'admin_user' LIMIT 1;
  
  SET session_replication_role = 'origin';
  RAISE NOTICE 'Setup complete at role: %', current_setting('session_replication_role');

  -- RLS verification
  RAISE NOTICE 'RLS enabled on user_sessions: %', (
    SELECT rowsecurity FROM pg_tables 
    WHERE schemaname = 'public' AND tablename = 'user_sessions'
  );

  -- Test with regular user
  PERFORM set_config('request.device_fingerprint', 'regular_user_fp', true);
  SELECT get_session_claims() INTO claims;
  RAISE NOTICE 'Claims: %', claims;
  
  SELECT count(*) INTO debug_count FROM user_sessions;
  RAISE NOTICE 'Total visible sessions: %', debug_count;
  
  ASSERT debug_count = 1, 
    'RLS violation - user can see ' || debug_count || ' sessions. Role: ' || 
    current_setting('session_replication_role');

EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error at role: %', current_setting('session_replication_role');
  RAISE;
END;
$$ LANGUAGE plpgsql;