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
  INSERT INTO sessions (expires_at) VALUES (NOW() + interval '1 day');
  SELECT auth.get_session_access(id) FROM sessions WHERE expires_at > NOW();
$$, 'Access allowed for valid session');
SELECT results_eq($$
  INSERT INTO sessions (expires_at) VALUES (NOW() - interval '1 day') RETURNING auth.get_session_access(id);
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
SELECT plan(1);
SELECT results_eq($$
  WITH inserted AS (
    INSERT INTO sessions (id, trust_level) 
    VALUES ('00000000-0000-0000-0000-000000000001'::uuid, 'primary') 
    RETURNING id
  )
  INSERT INTO audit_logs (session_id, action) 
  SELECT id, 'login' FROM inserted
  RETURNING exists(
    SELECT 1 FROM sessions 
    WHERE id = '00000000-0000-0000-0000-000000000001'
    AND expires_at > NOW() + interval '29 days'
  );
$$, ARRAY[true], 'Primary device gets 30 day extension');
SELECT * FROM finish();
ROLLBACK;