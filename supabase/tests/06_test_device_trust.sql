BEGIN;
    SELECT plan(7);

    -- Setup test data
    INSERT INTO auth.users (id, email, role)
    VALUES 
        ('00000000-0000-0000-0000-000000000000'::uuid, 'test@example.com', 'basic');

    INSERT INTO public.sessions (id, user_id, device_fingerprint)
    VALUES 
        ('00000000-0000-0000-0000-000000000001'::uuid, 
         '00000000-0000-0000-0000-000000000000'::uuid,
         'test-fingerprint'),
        ('00000000-0000-0000-0000-000000000002'::uuid,
         '00000000-0000-0000-0000-000000000000'::uuid,
         'another-device');

    SET app.device_fingerprint = 'test-fingerprint';
    SET request.jwt.claim.sub = '00000000-0000-0000-0000-000000000000';
    SET request.jwt.claims = '{"sub": "00000000-0000-0000-0000-000000000000"}';

    -- Schema tests
    SELECT has_type('device_trust_level', 'Trust level enum exists');
    SELECT has_column('public', 'sessions', 'trust_level', 'Trust level column exists');
    SELECT has_column('public', 'sessions', 'last_verified', 'Last verified column exists');

    -- Default trust level
    SELECT results_eq(
        'SELECT trust_level::text FROM sessions WHERE id = ''00000000-0000-0000-0000-000000000001''::uuid',
        ARRAY['new'],
        'New sessions start with new trust level'
    );

    -- Update trust level
    SELECT lives_ok(
        $$ SELECT public.update_device_trust(
            '00000000-0000-0000-0000-000000000001'::uuid,
            'known'::device_trust_level
        ) $$,
        'Can update trust level'
    );

    -- Primary device handling
    SELECT lives_ok(
        $$ SELECT public.update_device_trust(
            '00000000-0000-0000-0000-000000000001'::uuid,
            'primary'::device_trust_level
        ) $$,
        'Can set primary device'
    );

    -- Verify only one primary
    SELECT results_eq(
        'SELECT count(*) FROM sessions WHERE trust_level = ''primary''::device_trust_level',
        ARRAY[1::bigint],
        'Only one primary device allowed'
    );

    SELECT * FROM finish();
ROLLBACK;