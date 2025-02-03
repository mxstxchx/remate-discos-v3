DO $$
DECLARE
  test_device_1 UUID;
  test_device_2 UUID;
  test_session_1 UUID;
  test_session_2 UUID;
  test_session_3 UUID;
BEGIN
  -- Test setup in separate transaction
  BEGIN;
  SET session_replication_role = 'replica';

  -- Create devices & sessions
  INSERT INTO devices (fingerprint, is_active)
  VALUES 
    ('test_device_1_fp', true),
    ('test_device_2_fp', true)
  RETURNING id INTO test_device_1;
  SELECT id INTO test_device_2 FROM devices OFFSET 1;

  INSERT INTO user_sessions (device_id, alias, is_admin, expires_at)
  VALUES
    (test_device_1, 'regular_user_1', false, NOW() + INTERVAL '1 day'),
    (test_device_1, 'regular_user_2', false, NOW() + INTERVAL '1 day'),
    (test_device_2, 'admin_user', true, NOW() + INTERVAL '1 day')
  RETURNING id INTO test_session_1;
  
  SELECT id INTO test_session_2 FROM user_sessions OFFSET 1;
  SELECT id INTO test_session_3 FROM user_sessions OFFSET 2;

  -- Enable RLS
  SET session_replication_role = 'origin';
  COMMIT;

  -- Core RLS Tests
  RAISE NOTICE 'Starting Core RLS Tests...';

  -- Test 1: Device Owner Access
  PERFORM set_config('request.device_fingerprint', 'test_device_1_fp', true);
  ASSERT EXISTS(
    SELECT 1 FROM user_sessions WHERE device_id = test_device_1
  ), 'Device owner cannot see own sessions';

  -- Test 2: Cross-Device Isolation
  ASSERT NOT EXISTS(
    SELECT 1 FROM user_sessions WHERE device_id = test_device_2
  ), 'Non-admin can see other device sessions';

  -- Test 3: Admin Access
  PERFORM set_config('request.device_fingerprint', 'test_device_2_fp', true);
  ASSERT EXISTS(
    SELECT 1 FROM user_sessions WHERE device_id = test_device_1
  ), 'Admin cannot see other sessions';

  -- Test 4: Session-Specific Access
  PERFORM set_config('request.device_fingerprint', 'test_device_1_fp', true);
  ASSERT EXISTS(
    SELECT 1 FROM reservations
    WHERE session_id = test_session_1
  ), 'Session owner cannot see reservations';

  -- Test 5: Policy Inheritance
  ASSERT NOT EXISTS(
    SELECT 1 FROM audit_logs
    WHERE session_id != test_session_1
  ), 'Session can see other audit logs';

  RAISE NOTICE 'Core RLS tests completed';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Test failed: % %', SQLERRM, SQLSTATE;
  RAISE;
END;
$$ LANGUAGE plpgsql;
