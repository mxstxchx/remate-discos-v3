-- Schema tests
BEGIN;
SELECT plan(3);
SELECT has_column('public', 'sessions', 'expires_at', 'sessions.expires_at exists');
SELECT has_column('public', 'sessions', 'last_active', 'sessions.last_active exists');
SELECT col_is_pk('public', 'sessions', 'id', 'sessions.id is primary key');
SELECT * FROM finish();
ROLLBACK;

-- Set up test environment
BEGIN;
SELECT set_config('app.device_fingerprint', 'test-device', false);

-- Access function tests
SELECT plan(2);

INSERT INTO auth.users (id) VALUES ('00000000-0000-0000-0000-000000000001');
INSERT INTO devices (id, fingerprint) VALUES ('00000000-0000-0000-0000-000000000001', 'test-device');

SELECT lives_ok($$
  INSERT INTO sessions 
    (user_id, device_id, alias, trust_level, expires_at)
  VALUES 
    ('00000000-0000-0000-0000-000000000001', 
     '00000000-0000-0000-0000-000000000001',
     'test_user',
     'primary',
     NOW() + interval '1 day');
  SELECT auth.get_session_access(id) FROM sessions WHERE expires_at > NOW();
$$, 'Access allowed for valid session');

SELECT results_eq($$
  INSERT INTO sessions 
    (user_id, device_id, alias, trust_level, expires_at)
  VALUES 
    ('00000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-000000000001',
     'test_user',
     'primary',
     NOW() - interval '1 day')
  RETURNING auth.get_session_access(id);
$$, ARRAY[false], 'Access denied for expired session');
SELECT * FROM finish();
ROLLBACK;

-- Trigger tests
BEGIN;
SELECT plan(2);
SELECT trigger_is('public', 'sessions', 'session_expiry_audit', 'Expiry audit trigger exists');
SELECT trigger_is('public', 'audit_logs', 'session_activity_refresh', 'Activity refresh trigger exists');
SELECT * FROM finish();
ROLLBACK;

-- Activity refresh tests
BEGIN;
SELECT set_config('app.device_fingerprint', 'test-device', false);
SELECT plan(1);

INSERT INTO auth.users (id) VALUES ('00000000-0000-0000-0000-000000000001');
INSERT INTO devices (id, fingerprint) VALUES ('00000000-0000-0000-0000-000000000001', 'test-device');

SELECT results_eq($$
  WITH session_setup AS (
    INSERT INTO sessions 
      (id, user_id, device_id, alias, trust_level)
    VALUES 
      ('00000000-0000-0000-0000-000000000001',
       '00000000-0000-0000-0000-000000000001',
       '00000000-0000-0000-0000-000000000001',
       'test_user',
       'primary')
    RETURNING id
  )
  INSERT INTO audit_logs (session_id, action)
  SELECT id, 'login' FROM session_setup
  RETURNING exists(
    SELECT 1 FROM sessions 
    WHERE id = '00000000-0000-0000-0000-000000000001'
    AND expires_at > NOW() + interval '29 days'
  );
$$, ARRAY[true], 'Primary device gets 30 day extension');
SELECT * FROM finish();
ROLLBACK;