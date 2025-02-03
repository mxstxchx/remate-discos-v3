DO $$
DECLARE
  test_device UUID;
  test_session UUID;
  null_device UUID;
BEGIN
  -- Setup
  BEGIN;
  SET session_replication_role = 'replica';

  -- NULL fingerprint test
  INSERT INTO devices (fingerprint)
  VALUES (NULL)
  RETURNING id INTO null_device;

  -- Regular test data
  INSERT INTO devices (fingerprint)
  VALUES ('edge_test_fp')
  RETURNING id INTO test_device;

  INSERT INTO user_sessions (device_id, alias, expires_at)
  VALUES (test_device, 'edge_user', NOW() + INTERVAL '1 day')
  RETURNING id INTO test_session;

  INSERT INTO test_releases (id, title, artists, labels, styles, condition, price, images)
  VALUES (1, 'Test', ARRAY['Artist'], '{}'::jsonb, ARRAY['Style'], 'NM', 10.00, '{}'::jsonb);

  SET session_replication_role = 'origin';
  COMMIT;

  -- Test 1: NULL Fingerprint Handling
  PERFORM set_config('request.device_fingerprint', NULL, true);
  ASSERT NOT EXISTS(
    SELECT 1 FROM user_sessions
    WHERE device_id = null_device
  ), 'NULL fingerprint allowed access';

  -- Test 2: Invalid Fingerprint
  PERFORM set_config('request.device_fingerprint', 'nonexistent_fp', true);
  ASSERT NOT EXISTS(
    SELECT 1 FROM user_sessions
  ), 'Invalid fingerprint allowed access';

  -- Test 3: Race Condition Check
  BEGIN;
    PERFORM set_config('request.device_fingerprint', 'edge_test_fp', true);
    INSERT INTO reservations (release_id, session_id, status)
    VALUES (1, test_session, 'reserved');
    
    -- Simulate concurrent update
    PERFORM pg_sleep(0.1);
    UPDATE reservations
    SET status = 'expired'
    WHERE session_id = test_session;
    
    ASSERT EXISTS(
      SELECT 1 FROM audit_logs
      WHERE action = 'status_change'
      GROUP BY session_id
      HAVING COUNT(*) = 1
    ), 'Multiple status changes recorded';
    
    COMMIT;
  END;

  -- Test 4: Transaction Isolation
  BEGIN;
    PERFORM set_config('request.device_fingerprint', 'edge_test_fp', true);
    UPDATE user_sessions
    SET expires_at = NOW() - INTERVAL '1 day'
    WHERE id = test_session;
    
    -- Should not see own session after expiry
    ASSERT NOT EXISTS(
      SELECT 1 FROM user_sessions
      WHERE id = test_session
    ), 'Session visible after expiry';
    
    -- Check audit log isolation
    ASSERT EXISTS(
      SELECT 1 FROM audit_logs
      WHERE session_id = test_session
      AND action = 'session_expired'
    ), 'Expiry not audited';
    
    ROLLBACK;
  END;

  RAISE NOTICE 'Edge case tests completed';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Test failed: % %', SQLERRM, SQLSTATE;
  RAISE;
END;
$$ LANGUAGE plpgsql;