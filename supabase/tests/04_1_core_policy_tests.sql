-- Core RLS Policy Tests

BEGIN;

-- Create test data
INSERT INTO devices (id, fingerprint)
VALUES 
  ('97d07a61-f449-49db-b01e-80469b0fadac', 'device_1'),
  ('a8b4c2e0-d6f8-4g9h-i0j1-k2l3m4n5o6p7', 'device_2');

INSERT INTO user_sessions (id, device_id, alias, is_admin)
VALUES
  ('c8543c6a-6487-4c36-96cc-7a428cadb024', '97d07a61-f449-49db-b01e-80469b0fadac', 'regular_user', false),
  ('d9654d7b-7598-5d47-07dd-8b539dbdc135', 'a8b4c2e0-d6f8-4g9h-i0j1-k2l3m4n5o6p7', 'admin_user', true);

-- Test regular user context
SET app.device_fingerprint = 'device_1';

-- Should see own session only
SELECT COUNT(*) = 1 as test_passed
FROM user_sessions
WHERE alias = 'regular_user';

-- Should not see admin session
SELECT COUNT(*) = 0 as test_passed
FROM user_sessions
WHERE alias = 'admin_user';

-- Test admin context
SET app.device_fingerprint = 'device_2';

-- Should see all sessions
SELECT COUNT(*) = 2 as test_passed
FROM user_sessions;

ROLLBACK;
