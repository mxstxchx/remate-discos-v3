# Technical Insights V3

## Session Implementation

### Device Recognition
```typescript
// Device fingerprinting with fallback
const getDeviceId = async () => {
  try {
    const fp = await getFingerprintJS();
    return fp.get();
  } catch {
    return generateFallbackId();
  }
};

// Session initialization pattern
const initSession = async () => {
  const deviceId = await getDeviceId();
  const existingSession = await findSessionByDevice(deviceId);
  
  if (existingSession && !isExpired(existingSession)) {
    return resumeSession(existingSession);
  }
  
  return createNewSession(deviceId);
};
```

### Error Prevention
```typescript
// Status transition enforcement
const validateTransition = (current: Status, next: Status): boolean => {
  const allowed = {
    available: ['in_cart'],
    in_cart: ['reserved', 'available'],
    reserved: ['sold', 'expired', 'cancelled'],
    in_queue: ['reserved'],
    expired: ['available'],
    cancelled: ['available'],
  };
  
  return allowed[current]?.includes(next) ?? false;
};

// Session expiration handling
const handleExpiration = () => {
  const checkInterval = 1000 * 60; // 1 minute
  let timeoutId: NodeJS.Timeout;

  const check = () => {
    const { expiresAt } = useSessionStore.getState();
    if (isExpired(expiresAt)) {
      clearSession();
      return;
    }
    timeoutId = setTimeout(check, checkInterval);
  };

  return () => clearTimeout(timeoutId);
};
```

### Cross-Tab Sync
```typescript
// BroadcastChannel for session events
const channel = new BroadcastChannel('session-sync');

channel.onmessage = (event) => {
  switch (event.data.type) {
    case 'session:expired':
      handleExpiration();
      break;
    case 'cart:updated':
      syncCartState(event.data.payload);
      break;
  }
};

// Storage event fallback
window.addEventListener('storage', (e) => {
  if (e.key === 'remate-session') {
    validateAndSyncSession(JSON.parse(e.newValue));
  }
});
```

## Database Patterns

### JSONB Operations
```sql
-- Efficient label filtering with GIN index
CREATE INDEX idx_release_labels ON releases USING GIN (labels);

CREATE OR REPLACE FUNCTION filter_by_labels(p_labels text[])
RETURNS TABLE (release_id bigint) AS $$
BEGIN
  RETURN QUERY
    SELECT r.id
    FROM releases r,
         jsonb_array_elements(r.labels) l
    WHERE l->>'name' = ANY(p_labels);
END;
$$ LANGUAGE plpgsql;

-- Two-step query pattern
WITH matching_releases AS (
  SELECT release_id 
  FROM filter_by_labels($1)
)
SELECT r.*
FROM releases r
JOIN matching_releases m ON r.id = m.release_id
WHERE r.price BETWEEN $2 AND $3
  AND r.condition = ANY($4);
```

### RLS Utilities
```sql
-- Session validation function
CREATE OR REPLACE FUNCTION get_session_claims()
RETURNS jsonb AS $$
DECLARE
  device_fp text;
  claims jsonb;
BEGIN
  -- Get current device fingerprint
  device_fp := current_setting('app.device_fingerprint', TRUE);
  
  -- Get session data
  SELECT jsonb_build_object(
    'session_id', s.id,
    'alias', s.alias,
    'is_admin', s.is_admin
  ) INTO claims
  FROM sessions s
  JOIN devices d ON s.device_id = d.id
  WHERE d.fingerprint = device_fp
  AND s.expires_at > now()
  ORDER BY s.created_at DESC
  LIMIT 1;
  
  RETURN claims;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Row level security by session
CREATE POLICY "Reservations viewable by session"
  ON reservations FOR SELECT
  USING (
    session_id::text = 
      (get_session_claims()->>'session_id')::text
  );
```

## React Component Patterns

### Session Context
```typescript
// Persistent session provider
export const SessionProvider: FC = ({ children }) => {
  const [mounted, setMounted] = useState(false);
  const sessionStore = useSessionStore();

  useEffect(() => {
    if (!mounted) {
      setMounted(true);
      sessionStore.initialize();
    }

    return () => {
      sessionStore.cleanup();
    };
  }, []);

  if (!mounted) return null;

  return (
    <SessionContext.Provider value={sessionStore}>
      {children}
    </SessionContext.Provider>
  );
};

// Route protection HOC
export const withSession = (
  Component: ComponentType,
  requireAdmin = false
) => {
  return function WrappedComponent(props: any) {
    const { sessionId, isAdmin } = useSessionStore();
    const router = useRouter();

    useEffect(() => {
      if (!sessionId) {
        router.replace('/session');
        return;
      }

      if (requireAdmin && !isAdmin) {
        router.replace('/browse');
      }
    }, [sessionId, isAdmin]);

    if (!sessionId) return null;
    if (requireAdmin && !isAdmin) return null;

    return <Component {...props} />;
  };
};
```

### Error Boundaries
```typescript
class SessionErrorBoundary extends React.Component {
  state = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error) {
    const { clearSession, setError } = useSessionStore.getState();
    
    setError(error.message);
    clearSession();
    
    // Log to monitoring service
    captureError({
      type: 'session_error',
      error,
      context: { url: window.location.href }
    });
  }

  render() {
    if (this.state.hasError) {
      return <SessionErrorFallback />;
    }

    return this.props.children;
  }
}
```

## Performance Optimizations

### Query Optimizations
```sql
-- Composite indexes for common queries
CREATE INDEX idx_session_lookup 
  ON sessions (device_id, expires_at DESC);
  
CREATE INDEX idx_reservation_status 
  ON reservations (release_id, status, reserved_at DESC);

-- Materialized view for dashboard
CREATE MATERIALIZED VIEW admin_dashboard AS
  SELECT 
    COUNT(*) FILTER (WHERE status = 'reserved') as active_holds,
    COUNT(*) FILTER (WHERE status = 'in_queue') as in_queue,
    COUNT(*) FILTER (WHERE status = 'sold') as total_sold,
    AVG(EXTRACT(epoch FROM (expires_at - reserved_at))) as avg_hold_time
  FROM reservations
  WHERE created_at > NOW() - INTERVAL '30 days';

-- Refresh every hour
CREATE OR REPLACE FUNCTION refresh_dashboard()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY admin_dashboard;
END;
$$ LANGUAGE plpgsql;
```

### Component Optimizations
```typescript
// Memoized filter components
const FilterCard = memo(({ title, options, selected, onChange }) => {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
      </CardHeader>
      <CardContent>
        {options.map(option => (
          <FilterBadge
            key={option.value}
            selected={selected.includes(option.value)}
            onClick={() => onChange(option.value)}
          >
            {option.label}
          </FilterBadge>
        ))}
      </CardContent>
    </Card>
  );
}, isEqual);

// Virtualized grid
const ReleaseGrid = () => {
  return (
    <VirtualizedGrid
      items={releases}
      itemSize={320}
      overscan={5}
      renderItem={release => (
        <ReleaseCard
          key={release.id}
          {...release}
          onReserve={handleReserve}
        />
      )}
    />
  );
};
```