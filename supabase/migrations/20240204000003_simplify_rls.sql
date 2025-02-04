-- Clear all existing policies
DROP POLICY IF EXISTS session_access ON user_sessions;
DROP POLICY IF EXISTS device_access ON devices;
DROP POLICY IF EXISTS reservation_access ON reservations;
DROP POLICY IF EXISTS audit_access ON audit_logs;

-- Single basic policy for testing
CREATE POLICY session_access ON user_sessions FOR SELECT USING (
  id = get_session_id()
);