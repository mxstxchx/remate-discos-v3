-- Schema tests
BEGIN;
SELECT plan(3);
SELECT has_column('public', 'sessions', 'expires_at', 'sessions.expires_at exists');
SELECT has_column('public', 'sessions', 'last_active', 'sessions.last_active exists');
SELECT col_is_pk('public', 'sessions', 'id', 'sessions.id is primary key');
SELECT * FROM finish();
ROLLBACK;

-- Access function tests
BEGIN;
SELECT plan(2);
SELECT lives_ok($$
  WITH user_setup AS (
    INSERT INTO auth.users (id) VALUES ('00000000-0000-0000-0000-000000000001') RETURNING id
  ), device_setup AS (
    INSERT INTO devices (id, fingerprint) 
    VALUES ('00000000-0000-0000-0000-000000000001', current_setting('app.device_fingerprint'))
    RETURNING id
  )
  INSERT INTO sessions (user_id, device_id, alias, trust_level, expires_at)
  SELECT 
    user_setup.id,
    device_setup.id,
    'test_user',
    'primary',
    NOW() + interval '1 day'
  FROM user_setup, device_setup;
  
  SELECT auth.get_session_access(id) FROM sessions WHERE expires_at > NOW();
$$, 'Access allowed for valid session');

SELECT results_eq($$
  WITH user_setup AS (
    INSERT INTO auth.users (id) VALUES ('00000000-0000-0000-0000-000000000002') RETURNING id
  ), device_setup AS (
    INSERT INTO devices (id, fingerprint)
    VALUES ('00000000-0000-0000-0000-000000000002', current_setting('app.device_fingerprint'))
    RETURNING id
  )
  INSERT INTO sessions (user_id, device_id, alias, trust_level, expires_at)
  SELECT 
    user_setup.id,
    device_setup.id,
    'test_user',
    'primary',
    NOW() - interval '1 day'
  FROM user_setup, device_setup
  RETURNING auth.get_session_access(id);
$$, ARRAY[false], 'Access denied for expired session');
SELECT * FROM finish();
ROLLBACK;

-- Rest of tests unchanged