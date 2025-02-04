-- Basic role definitions
CREATE TYPE user_role AS ENUM ('basic', 'admin');

-- Add role column to auth.users
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS role user_role NOT NULL DEFAULT 'basic';

-- Create role-switching function
CREATE OR REPLACE FUNCTION auth.set_user_role(
    user_id UUID,
    new_role user_role
) RETURNS void AS $$
BEGIN
    UPDATE auth.users 
    SET role = new_role 
    WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Basic RLS policy function
CREATE OR REPLACE FUNCTION auth.get_session_access(session_id UUID)
RETURNS boolean AS $$
BEGIN
    -- Admin sees everything
    IF (SELECT role FROM auth.users WHERE id = auth.uid()) = 'admin' THEN
        RETURN true;
    END IF;
    
    -- Users see only their fingerprinted sessions
    RETURN EXISTS (
        SELECT 1
        FROM public.sessions s
        WHERE s.id = session_id
        AND s.user_id = auth.uid()
        AND s.device_fingerprint = current_setting('app.device_fingerprint', true)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;