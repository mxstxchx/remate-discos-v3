-- Activity type enum
CREATE TYPE session_activity_type AS ENUM (
    'login',
    'logout',
    'refresh',
    'expired'
);

-- Activity tracking table
CREATE TABLE public.session_activity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    activity_type session_activity_type NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadata JSONB
);

-- Index for quick lookups
CREATE INDEX idx_session_activity_session_id ON public.session_activity(session_id);
CREATE INDEX idx_session_activity_type ON public.session_activity(activity_type);

-- RLS setup
ALTER TABLE public.session_activity ENABLE ROW LEVEL SECURITY;

-- Inherit access from parent session
CREATE POLICY session_activity_access ON public.session_activity
    FOR ALL
    TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.sessions s
        WHERE s.id = session_id
        AND auth.get_session_access(s.id)
    ));

-- Activity recording function
CREATE OR REPLACE FUNCTION public.record_session_activity(
    p_session_id UUID,
    p_activity_type session_activity_type,
    p_metadata JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_activity_id UUID;
BEGIN
    IF NOT auth.get_session_access(p_session_id) THEN
        RAISE EXCEPTION 'Access denied to session %', p_session_id;
    END IF;

    INSERT INTO public.session_activity
        (session_id, activity_type, metadata)
    VALUES
        (p_session_id, p_activity_type, p_metadata)
    RETURNING id INTO v_activity_id;

    RETURN v_activity_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;