DO $$ 
DECLARE
  test_fp TEXT := 'test_device_fp';
  test_alias TEXT := 'test_user';
  session_id UUID;
  is_valid BOOLEAN;
BEGIN
  -- Test 1: Session Creation
  session_id := create_session(test_fp, test_alias);
  ASSERT session_id IS NOT NULL, 'Session creation failed';
  
  -- Test 2: Device Creation
  ASSERT EXISTS(
    SELECT 1 FROM devices 
    WHERE fingerprint = test_fp
  ), 'Device not created';

  -- Test 3: Session Validation
  is_valid := validate_session(session_id);
  ASSERT is_valid, 'Session validation failed';

  -- Test 4: Session Refresh
  PERFORM refresh_session(session_id);
  ASSERT EXISTS(
    SELECT 1 FROM user_sessions
    WHERE id = session_id
    AND expires_at > NOW() + INTERVAL '29 days'
  ), 'Session refresh failed';

  -- Test 5: Language Validation
  ASSERT EXISTS(
    SELECT 1 FROM user_sessions
    WHERE id = session_id
    AND language IN ('es-ES', 'en-UK')
  ), 'Invalid language value';

  -- Test 6: Device Reuse
  session_id := create_session(test_fp, 'new_alias');
  ASSERT (
    SELECT COUNT(*) FROM devices
    WHERE fingerprint = test_fp
  ) = 1, 'Device duplication occurred';

  RAISE NOTICE 'All session management tests passed';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Test failed: %', SQLERRM;
  RAISE;
END;
$$ LANGUAGE plpgsql;