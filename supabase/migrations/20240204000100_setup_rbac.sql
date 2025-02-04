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
    current_fp text;
BEGIN
    -- Debug vars
    current_fp := current_setting('app.device_fingerprint', true);
    RAISE NOTICE 'Function called with: session_id=%, uid=%, fp=%', 
                 session_id, auth.uid(), current_fp;

    -- Check if session exists and get its data
    SELECT * INTO session_record
    FROM public.sessions
    WHERE id = session_id;

    IF session_record IS NULL THEN
        RAISE NOTICE 'Session not found';
        RETURN false;
    END IF;

    -- Check if admin
    SELECT (role = 'admin') FROM auth.users 
    WHERE id = auth.uid()
    INTO user_is_admin;

    IF user_is_admin THEN
        RAISE NOTICE 'Admin access granted';
        RETURN true;
    END IF;

    -- Debug session match
    RAISE NOTICE 'Checking match: session_uid=%, current_uid=%, session_fp=%, current_fp=%',
                 session_record.user_id, auth.uid(),
                 session_record.device_fingerprint, current_fp;

    -- Direct comparison
    RETURN 
        session_record.user_id = auth.uid() AND
        session_record.device_fingerprint = current_fp;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

-- Add session access policy
CREATE POLICY sessions_access ON public.sessions
  FOR ALL
  TO authenticated
  USING (auth.get_session_access(id));