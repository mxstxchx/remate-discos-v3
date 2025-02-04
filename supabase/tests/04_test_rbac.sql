BEGIN;
    SELECT plan(10);

    -- Setup test data
    INSERT INTO auth.users (id, email, role)
    VALUES 
        ('00000000-0000-0000-0000-000000000000'::uuid, 'test@example.com', 'basic'),
        ('00000000-0000-0000-0000-000000000001'::uuid, 'admin@example.com', 'admin');

    INSERT INTO public.sessions (id, user_id, device_fingerprint)
    VALUES 
        ('00000000-0000-0000-0000-000000000001'::uuid, 
         '00000000-0000-0000-0000-000000000000'::uuid,
         'test-fingerprint');

    -- Set test context
    SET app.device_fingerprint = 'test-fingerprint';
    SET request.jwt.claim.sub = '00000000-0000-0000-0000-000000000000';
    SET request.jwt.claims = '{"sub": "00000000-0000-0000-0000-000000000000"}';

    -- Type and column tests
    SELECT has_type('user_role', 'Role enum type exists');
    SELECT has_column('auth', 'users', 'role', 'Users table has role column');
    
    -- Function signature tests
    SELECT function_returns('auth', 'set_user_role', ARRAY['uuid', 'user_role'], 'void',
        'Role switching function exists with correct signature');
    SELECT function_returns('auth', 'get_session_access', ARRAY['uuid'], 'boolean',
        'Session access function exists with correct signature');
        
    -- Role tests
    SELECT results_eq(
        'SELECT role::text FROM auth.users WHERE id = ''00000000-0000-0000-0000-000000000000''::uuid',
        ARRAY['basic'],
        'New users default to basic role'
    );
    SELECT lives_ok(
        $$ SELECT auth.set_user_role('00000000-0000-0000-0000-000000000000'::uuid, 'admin'::user_role) $$,
        'Can switch user role'
    );
    
    -- Access tests - Basic user
    SELECT is(
        auth.get_session_access('00000000-0000-0000-0000-000000000000'::uuid),
        false,
        'Cannot access non-existent session'
    );
    
    SELECT results_eq(
        $$ 
        SELECT auth.get_session_access('00000000-0000-0000-0000-000000000001'::uuid)
        $$,
        ARRAY[true],
        'Can access own fingerprinted session'
    );

    -- Access tests - Admin user
    SET request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
    SET request.jwt.claims = '{"sub": "00000000-0000-0000-0000-000000000001"}';

    SELECT is(
        auth.get_session_access('00000000-0000-0000-0000-000000000001'::uuid),
        true,
        'Admin can access any existing session'
    );

    SELECT is(
        auth.get_session_access('00000000-0000-0000-0000-000000000000'::uuid),
        false,
        'Admin cannot access non-existent session'
    );

    SELECT * FROM finish();
ROLLBACK;