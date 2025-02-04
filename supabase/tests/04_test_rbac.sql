BEGIN;
    SELECT plan(8);

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
        'SELECT role FROM auth.users LIMIT 1',
        ARRAY['basic'::user_role],
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
        SELECT auth.get_session_access(s.id)
        FROM public.sessions s
        WHERE s.user_id = auth.uid()
        AND s.device_fingerprint = current_setting('app.device_fingerprint', true)
        LIMIT 1
        $$,
        ARRAY[true],
        'User can access own fingerprinted session'
    );

    SELECT * FROM finish();
ROLLBACK;