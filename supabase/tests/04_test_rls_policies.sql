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
  SET session_replication_role = 'origin';
  
  RAISE NOTICE 'Initial replication role: %', current_setting('session_replication_role');
  RAISE NOTICE 'Initial RLS on user_sessions: %', (
    SELECT rowsecurity FROM pg_tables 
    WHERE schemaname = 'public' AND tablename = 'user_sessions'
  );

  SET session_replication_role = 'replica';
  
  -- Fix: Separate inserts for clearer ID handling
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

  RAISE NOTICE 'Post-setup replication role: %', current_setting('session_replication_role');
  RAISE NOTICE 'Post-setup RLS status: %', (
    SELECT rowsecurity FROM pg_tables 
    WHERE schemaname = 'public' AND tablename = 'user_sessions'
  );

  PERFORM set_config('request.device_fingerprint', 'regular_user_fp', true);
  
  SELECT get_session_claims() INTO claims;
  RAISE NOTICE 'Claims: %', claims;
  
  SELECT count(*) INTO debug_count FROM user_sessions;
  RAISE NOTICE 'Total visible sessions: %', debug_count;
  
  ASSERT debug_count = 1, 
    'RLS violation - user can see other sessions. Replication role: ' || 
    current_setting('session_replication_role');

  RAISE NOTICE 'Tests passed';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error role state: %', current_setting('session_replication_role');
  RAISE;
END;
$$ LANGUAGE plpgsql;