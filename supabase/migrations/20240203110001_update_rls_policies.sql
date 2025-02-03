-- Drop existing policies
DROP POLICY IF EXISTS session_select_policy ON user_sessions;
DROP POLICY IF EXISTS session_insert_policy ON user_sessions;
DROP POLICY IF EXISTS device_select_policy ON devices;
DROP POLICY IF EXISTS device_insert_policy ON devices;
DROP POLICY IF EXISTS reservation_select_policy ON reservations;
DROP POLICY IF EXISTS reservation_insert_policy ON reservations;
DROP POLICY IF EXISTS audit_log_select_policy ON audit_logs;
DROP POLICY IF EXISTS audit_log_insert_policy ON audit_logs;

-- Device policies
CREATE POLICY device_select_policy ON devices
  FOR SELECT USING (
    id = (get_session_claims()->>'device_id')::uuid
    OR is_admin()
  );

CREATE POLICY device_insert_policy ON devices
  FOR INSERT WITH CHECK (TRUE);

-- Session policies
CREATE POLICY session_select_policy ON user_sessions
  FOR SELECT USING (
    id = (get_session_claims()->>'session_id')::uuid
    OR device_id = (get_session_claims()->>'device_id')::uuid
    OR is_admin()
  );

CREATE POLICY session_insert_policy ON user_sessions
  FOR INSERT WITH CHECK (TRUE);

-- Reservation policies
CREATE POLICY reservation_select_policy ON reservations
  FOR SELECT USING (
    session_id = (get_session_claims()->>'session_id')::uuid
    OR is_admin()
  );

CREATE POLICY reservation_insert_policy ON reservations
  FOR INSERT WITH CHECK (
    session_id = (get_session_claims()->>'session_id')::uuid
  );

-- Audit log policies
CREATE POLICY audit_log_select_policy ON audit_logs
  FOR SELECT USING (
    session_id = (get_session_claims()->>'session_id')::uuid
    OR is_admin()
  );

CREATE POLICY audit_log_insert_policy ON audit_logs
  FOR INSERT WITH CHECK (
    session_id = (get_session_claims()->>'session_id')::uuid
    OR session_id IN (
      SELECT id FROM user_sessions
      WHERE device_id = (get_session_claims()->>'device_id')::uuid
    )
  );