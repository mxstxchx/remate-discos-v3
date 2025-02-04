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
DECLARE
    session_exists boolean;
    session_record record;
    user_is_admin boolean;
BEGIN
    -- Check if session exists and get its data
    SELECT EXISTS (
        SELECT 1 FROM public.sessions WHERE id = session_id
    ) INTO session_exists;

    IF NOT session_exists THEN
        RETURN false;
    END IF;

    -- Check if admin
    SELECT (role = 'admin') FROM auth.users 
    WHERE id = auth.uid()
    INTO user_is_admin;

    IF user_is_admin THEN
        RETURN true;
    END IF;

    -- Direct user+fingerprint comparison
    SELECT * INTO session_record
    FROM public.sessions
    WHERE id = session_id;
    
    RETURN 
        session_record.user_id = auth.uid() AND
        session_record.device_fingerprint = current_setting('app.device_fingerprint', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

-- Add session access policy
CREATE POLICY sessions_access ON public.sessions
  FOR ALL
  TO authenticated
  USING (auth.get_session_access(id));