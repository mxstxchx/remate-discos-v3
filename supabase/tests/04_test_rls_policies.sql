DO $$
DECLARE
  regular_device_id UUID;
  admin_device_id UUID;
  regular_session_id UUID;
  admin_session_id UUID;
  claims jsonb;
  debug_count integer;
  rls_info record;
  policy_info record;
BEGIN
  -- Verify replication role
  IF current_setting('session_replication_role') != 'origin' THEN
    RAISE EXCEPTION 'Test must run with replication role origin';
  END IF;

  -- Check RLS configuration
  RAISE NOTICE 'Checking RLS configuration...';
  FOR rls_info IN 
    SELECT tablename, rowsecurity 
    FROM pg_tables 
    WHERE schemaname = 'public'
    AND tablename IN ('devices', 'user_sessions', 'reservations', 'audit_logs')
  LOOP
    IF NOT rls_info.rowsecurity THEN
      RAISE EXCEPTION 'RLS not enabled on %', rls_info.tablename;
    END IF;
    RAISE NOTICE 'Table: %, RLS Enabled: %', rls_info.tablename, rls_info.rowsecurity;
  END LOOP;

  -- Check Policies
  RAISE NOTICE 'Checking active policies...';
  FOR policy_info IN
    SELECT schemaname, tablename, policyname, cmd, qual
    FROM pg_policies 
    WHERE schemaname = 'public'
    ORDER BY tablename, policyname
  LOOP
    RAISE NOTICE 'Policy: % on % (%) - %', 
      policy_info.policyname, 
      policy_info.tablename,
      policy_info.cmd,
      policy_info.qual;
  END LOOP;

  -- Test setup
  RAISE NOTICE 'Test setup start';
  SET session_replication_role = 'replica';
  
  INSERT INTO devices (fingerprint) VALUES ('regular_user_fp')
  RETURNING id INTO regular_device_id;
  RAISE NOTICE 'Regular device created (id: %)', regular_device_id;
  
  INSERT INTO devices (fingerprint) VALUES ('admin_user_fp')
  RETURNING id INTO admin_device_id;
  RAISE NOTICE 'Admin device created (id: %)', admin_device_id;

  INSERT INTO user_sessions (device_id, alias, is_admin, expires_at)
  VALUES (regular_device_id, 'regular_user', false, NOW() + INTERVAL '1 day')
  RETURNING id INTO regular_session_id;
  RAISE NOTICE 'Regular session created (id: %)', regular_session_id;

  INSERT INTO user_sessions (device_id, alias, is_admin, expires_at)
  VALUES (admin_device_id, 'admin_user', true, NOW() + INTERVAL '1 day')
  RETURNING id INTO admin_session_id;
  RAISE NOTICE 'Admin session created (id: %)', admin_session_id;

  SET session_replication_role = 'origin';
  RAISE NOTICE 'Test setup complete';
  RAISE NOTICE 'Replication role after setup: %', current_setting('session_replication_role');

  -- Test basic session visibility
  PERFORM set_config('request.device_fingerprint', 'regular_user_fp', true);
  SELECT get_session_claims() INTO claims;
  RAISE NOTICE 'Regular user claims: %', claims;
  
  SELECT count(*) INTO debug_count FROM user_sessions;
  RAISE NOTICE 'Total sessions visible: %', debug_count;
  
  SELECT count(*) INTO debug_count FROM user_sessions WHERE id = regular_session_id;
  RAISE NOTICE 'Own sessions visible: %', debug_count;
  
  SELECT count(*) INTO debug_count FROM user_sessions WHERE id = admin_session_id;
  RAISE NOTICE 'Admin sessions visible: %', debug_count;
  
  -- Test SQL being executed
  RAISE NOTICE 'Testing query: %', format(
    'SELECT * FROM user_sessions WHERE id = %L'
    'OR (get_session_claims()->>''is_admin'')::boolean = true',
    regular_session_id
  );

  -- Visibility assertions
  ASSERT EXISTS(
    SELECT 1 FROM user_sessions WHERE id = regular_session_id
  ), 'Regular user cannot see own session';

  ASSERT NOT EXISTS(
    SELECT 1 FROM user_sessions WHERE id = admin_session_id
  ), 'Regular user can see other sessions';

  RAISE NOTICE 'Test complete';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Test failed at % with %', SQLERRM;
  RAISE;
END;
$$ LANGUAGE plpgsql;