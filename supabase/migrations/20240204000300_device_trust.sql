-- Trust level type
CREATE TYPE device_trust_level AS ENUM ('new', 'known', 'primary');

-- Add trust levels
ALTER TABLE public.sessions
    ADD COLUMN trust_level device_trust_level NOT NULL DEFAULT 'new',
    ADD COLUMN last_verified TIMESTAMPTZ;

-- Trust level management function
CREATE OR REPLACE FUNCTION public.update_device_trust(
    p_session_id UUID,
    p_trust_level device_trust_level
) RETURNS void AS $$
BEGIN
    -- Verify access
    IF NOT auth.get_session_access(p_session_id) THEN
        RAISE EXCEPTION 'Access denied to session %', p_session_id;
    END IF;

    -- If setting to primary, clear other primary devices
    IF p_trust_level = 'primary' THEN
        UPDATE public.sessions
        SET trust_level = 'known'
        WHERE user_id = (
            SELECT user_id FROM public.sessions WHERE id = p_session_id
        )
        AND trust_level = 'primary';
    END IF;

    -- Update trust level
    UPDATE public.sessions
    SET 
        trust_level = p_trust_level,
        last_verified = CASE 
            WHEN p_trust_level IN ('known', 'primary') THEN now()
            ELSE last_verified
        END
    WHERE id = p_session_id;

    -- Record activity
    PERFORM public.record_session_activity(
        p_session_id,
        'login'::session_activity_type,
        jsonb_build_object('trust_level', p_trust_level)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;