BEGIN;
    SELECT plan(8);

    -- Setup test data
    INSERT INTO auth.users (id, email, role)
    VALUES 
        ('00000000-0000-0000-0000-000000000000'::uuid, 'test@example.com', 'basic');

    INSERT INTO public.sessions (id, user_id, device_fingerprint)
    VALUES 
        ('00000000-0000-0000-0000-000000000001'::uuid, 
         '00000000-0000-0000-0000-000000000000'::uuid,
         'test-fingerprint');

    SET app.device_fingerprint = 'test-fingerprint';
    SET request.jwt.claim.sub = '00000000-0000-0000-0000-000000000000';
    SET request.jwt.claims = '{"sub": "00000000-0000-0000-0000-000000000000"}';

    -- Schema tests
    SELECT has_type('session_activity_type', 'Activity type enum exists');
    SELECT has_table('public', 'session_activity', 'Activity table exists');
    SELECT has_column('public', 'session_activity', 'metadata', 'Metadata column exists');

    -- Function test
    SELECT function_returns('public', 'record_session_activity', ARRAY['uuid', 'session_activity_type', 'jsonb'], 'uuid',
        'Activity recording function exists');

    -- Activity recording
    SELECT isnt_empty(
        $$ SELECT public.record_session_activity(
            '00000000-0000-0000-0000-000000000001'::uuid,
            'login'::session_activity_type,
            '{"ip": "127.0.0.1"}'::jsonb
        ) $$,
        'Can record activity'
    );

    -- Activity retrieval
    SELECT results_eq(
        'SELECT count(*) FROM session_activity',
        ARRAY[1::bigint],
        'Activity was recorded'
    );

    -- Wrong session access
    SELECT throws_ok(
        $$ SELECT public.record_session_activity(
            '00000000-0000-0000-0000-000000000002'::uuid,
            'login'::session_activity_type
        ) $$,
        'Access denied to session 00000000-0000-0000-0000-000000000002',
        'Cannot record activity for inaccessible session'
    );

    -- Policy test
    SELECT results_eq(
        'SELECT count(*) FROM session_activity',
        ARRAY[1::bigint],
        'Can only see activity for accessible sessions'
    );

    SELECT * FROM finish();
ROLLBACK;