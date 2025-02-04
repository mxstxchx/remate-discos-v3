-- Debug functions for RLS
CREATE OR REPLACE FUNCTION debug_session_policy(target_id UUID)
RETURNS TABLE (check_name text, result boolean) AS $$
BEGIN
    RETURN QUERY
    SELECT 'session_id match' as check_name,
           target_id = get_session_id() as result
    UNION ALL
    SELECT 'is_admin check',
           is_admin_session() as result;
END;
$$ LANGUAGE plpgsql;

-- Update test file to use debug info
DROP POLICY IF EXISTS session_access ON user_sessions;
CREATE POLICY session_access ON user_sessions FOR ALL USING (
    (SELECT id = get_session_id() FROM user_sessions WHERE id = user_sessions.id)
    OR 
    is_admin_session()
);