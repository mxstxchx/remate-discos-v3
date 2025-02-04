BEGIN;
    SELECT plan(8);

    -- Setup test data
    INSERT INTO auth.users (id, email, role)
    VALUES ('00000000-0000-0000-0000-000000000000'::uuid, 'test@example.com', 'basic');

    INSERT INTO public.sessions (id, user_id, device_fingerprint)
    VALUES ('00000000-0000-0000-0000-000000000001'::uuid, 
            '00000000-0000-0000-0000-000000000000'::uuid,
            'test-fingerprint');

    -- Set test context
    SET app.device_fingerprint = 'test-fingerprint';
    SET request.jwt.claim.sub = '00000000-0000-0000-0000-000000000000';
    SET request.jwt.claims = '{"sub": "00000000-0000-0000-0000-000000000000"}';

    -- Test role creation
    SELECT has_type('user_role', 'Role enum type exists');
    SELECT has_column('auth', 'users', 'role', 'Users table has role column');
    
    -- Test role switching
    SELECT function_returns('auth', 'set_user_role', ARRAY['uuid', 'user_role'], 'void',
        'Role switching function exists with correct signature');
        
    -- Test access function
    SELECT function_returns('auth', 'get_session_access', ARRAY['uuid'], 'boolean',
        'Session access function exists with correct signature');
        
    -- Test initial data
    SELECT results_eq(
        'SELECT role::text FROM auth.users WHERE id = ''00000000-0000-0000-0000-000000000000''::uuid',
        ARRAY['basic'],
        'New users default to basic role'
    );
    
    -- Role switch test
    SELECT lives_ok(
        $$ SELECT auth.set_user_role('00000000-0000-0000-0000-000000000000'::uuid, 'admin'::user_role) $$,
        'Can switch user role'
    );
    
    -- Access checks
    SELECT is(
        auth.get_session_access('00000000-0000-0000-0000-000000000000'::uuid),
        false,
        'Basic user cannot access unknown session'
    );
    
    SELECT results_eq(
        $$ 
        SELECT auth.get_session_access('00000000-0000-0000-0000-000000000001'::uuid)
        $$,
        ARRAY[true],
        'User can access own fingerprinted session'
    );

    SELECT * FROM finish();
ROLLBACK;