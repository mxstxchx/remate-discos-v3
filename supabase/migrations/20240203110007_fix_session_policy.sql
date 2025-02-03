-- Drop existing policies
DROP POLICY IF EXISTS session_select_policy ON user_sessions;
DROP POLICY IF EXISTS device_select_policy ON devices;
DROP POLICY IF EXISTS reservation_select_policy ON reservations;
DROP POLICY IF EXISTS audit_log_select_policy ON audit_logs;

-- Create more restrictive policies
CREATE POLICY session_select_policy ON user_sessions
  FOR SELECT USING (
    -- Regular users can only see their current active session
    id = (get_session_claims()->>'session_id')::uuid
    -- Admins can see all sessions
    OR (get_session_claims()->>'is_admin')::boolean = true
  );

CREATE POLICY device_select_policy ON devices
  FOR SELECT USING (
    -- Regular users can see their current device
    id = (get_session_claims()->>'device_id')::uuid
    -- Admins can see all devices
    OR (get_session_claims()->>'is_admin')::boolean = true
  );

CREATE POLICY reservation_select_policy ON reservations
  FOR SELECT USING (
    -- Users can only see reservations from their current session
    session_id = (get_session_claims()->>'session_id')::uuid
    -- Admins can see all reservations
    OR (get_session_claims()->>'is_admin')::boolean = true
  );

CREATE POLICY audit_log_select_policy ON audit_logs
  FOR SELECT USING (
    -- Users can only see audit logs from their current session
    session_id = (get_session_claims()->>'session_id')::uuid
    -- Admins can see all audit logs
    OR (get_session_claims()->>'is_admin')::boolean = true
  );