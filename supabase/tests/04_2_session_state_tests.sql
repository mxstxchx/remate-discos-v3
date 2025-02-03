DO $$
DECLARE
  test_device UUID;
  active_session UUID;
  expired_session UUID;
BEGIN
  -- Setup
  BEGIN;
  SET session_replication_role = 'replica';

  INSERT INTO devices (fingerprint)
  VALUES ('state_test_fp')
  RETURNING id INTO test_device;

  INSERT INTO user_sessions (device_id, alias, expires_at)
  VALUES
    (test_device, 'active_user', NOW() + INTERVAL '1 day'),
    (test_device, 'expired_user', NOW() - INTERVAL '1 hour')
  RETURNING id INTO active_session;
  SELECT id INTO expired_session FROM user_sessions OFFSET 1;

  SET session_replication_role = 'origin';
  COMMIT;

  -- Test 1: Session Expiration
  PERFORM set_config('request.device_fingerprint', 'state_test_fp', true);
  ASSERT NOT EXISTS(
    SELECT 1 FROM user_sessions
    WHERE id = expired_session
    AND expires_at > NOW()
  ), 'Expired session still active';

  -- Test 2: Session Refresh
  SELECT refresh_session(active_session);
  ASSERT EXISTS(
    SELECT 1 FROM user_sessions
    WHERE id = active_session
    AND expires_at > NOW() + INTERVAL '29 days'
  ), 'Session refresh failed';

  -- Test 3: Cleanup Trigger
  UPDATE user_sessions
  SET expires_at = NOW() - INTERVAL '1 day'
  WHERE id = active_session;

  ASSERT NOT EXISTS(
    SELECT 1 FROM user_sessions
    WHERE id = active_session
  ), 'Expired session not cleaned up';

  -- Test 4: Expiration Audit
  ASSERT EXISTS(
    SELECT 1 FROM audit_logs
    WHERE session_id = active_session
    AND action = 'session_expired'
  ), 'Session expiration not audited';

  RAISE NOTICE 'Session state tests completed';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Test failed: % %', SQLERRM, SQLSTATE;
  RAISE;
END;
$$ LANGUAGE plpgsql;
