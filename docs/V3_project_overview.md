# Remate Discos V3 - Technical Architecture

## Core Architecture

### Tech Stack
- Next.js 14 (App Router)
- Supabase (PostgreSQL + RLS)
- TypeScript
- Zustand + persist middleware
- shadcn/ui
- Tailwind CSS

### Directory Structure
```
/src
  /app
    /session     # Entry point
    /browse      # Main interface
    /admin      # Admin dashboard
  /components
    /session    # Session management
    /browse     # Browsing interface
    /admin      # Admin components
    /ui         # shadcn/ui components
  /lib
    /supabase   # Database client
    /session    # Session utilities
    /utils      # Shared utilities
  /stores       # State management
  /types        # TypeScript types
/docs           # Development documentation                   
   /V3_PRD.md                  # Requirements
   /V3_project_overview.md     # Architecture
   /V3_technical_insights.md   # Implementation details
```

### Database Schema

#### Tables
```sql
-- Devices
CREATE TABLE devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fingerprint TEXT NOT NULL UNIQUE,
  last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT TRUE
);

-- Sessions
CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID REFERENCES devices(id),
  alias TEXT NOT NULL,
  language TEXT DEFAULT 'es-CL',
  is_admin BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE
);

-- Reservations
CREATE TABLE reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  release_id BIGINT REFERENCES releases(id),
  session_id UUID REFERENCES sessions(id),
  status reservation_status NOT NULL,
  position_in_queue INTEGER,
  reserved_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE,
  audit_log_id UUID REFERENCES audit_logs(id)
);

-- Audit Logs
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES sessions(id),
  action TEXT NOT NULL,
  details JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### Functions
```sql
-- Session Management
create_session(device_fingerprint text, alias text, language text)
validate_session(session_id uuid)
refresh_session(session_id uuid)
cleanup_expired_sessions()

-- Reservation Management
create_reservation(release_id bigint, session_id uuid)
update_reservation_status(reservation_id uuid, new_status reservation_status)
manage_queue_position(release_id bigint)
cleanup_expired_reservations()

-- Admin Functions
admin_force_expire(reservation_id uuid, admin_session_id uuid)
admin_mark_sold(reservation_id uuid, admin_session_id uuid)
```

### API Routes

#### Session Management
- POST /api/session/create
- POST /api/session/validate
- POST /api/session/refresh

#### Browse Interface
- GET /api/releases
- GET /api/releases/[id]
- POST /api/releases/[id]/reserve

#### Admin Actions
- POST /api/admin/reservations/expire
- POST /api/admin/reservations/sold
- GET /api/admin/audit-logs

### State Management

#### Session Store
```typescript
interface SessionState {
  alias: string | null;
  sessionId: string | null;
  language: 'es-ES' | 'en-UK';
  isAdmin: boolean;
  deviceId: string;
  expiresAt: Date | null;
  status: 'idle' | 'loading' | 'error';
}

const useSessionStore = create(
  persist<SessionState>(
    (set) => ({
      // Initial state
      alias: null,
      sessionId: null,
      language: 'es-ES',
      isAdmin: false,
      deviceId: null,
      expiresAt: null,
      status: 'idle',

      // Actions
      initializeSession: (session) => set({...}),
      refreshSession: () => {...},
      clearSession: () => set(initialState),
    }),
    {
      name: 'session-store',
      partialize: (state) => ({
        alias: state.alias,
        sessionId: state.sessionId,
        language: state.language,
        deviceId: state.deviceId
      })
    }
  )
);
```

#### Cart Store
```typescript
interface CartState {
  items: CartItem[];
  status: 'idle' | 'loading';
  error: string | null;
}

const useCartStore = create<CartState>((set) => ({
  items: [],
  status: 'idle',
  error: null,

  addItem: async (item) => {...},
  removeItem: (id) => {...},
  clearCart: () => set({ items: [] })
}));
```

### Security Implementation

#### RLS Policies
```sql
-- Device Access
CREATE POLICY "Devices are only accessible by matching fingerprint"
  ON devices FOR ALL USING (
    fingerprint = current_setting('app.device_fingerprint')::text
  );

-- Session Access
CREATE POLICY "Sessions are accessible by device"
  ON sessions FOR ALL USING (
    device_id IN (
      SELECT id FROM devices 
      WHERE fingerprint = current_setting('app.device_fingerprint')::text
    )
  );

-- Admin Access
CREATE POLICY "Admin actions require admin session"
  ON audit_logs FOR ALL USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE id = audit_logs.session_id
      AND is_admin = true
    )
  );
```

### Performance Optimizations

#### Image Handling
```typescript
interface ImageConfig {
  primary: {
    quality: 90,
    sizes: [400, 800, 1200]
  },
  secondary: {
    quality: 80,
    sizes: [400, 800]
  }
}
```

#### Query Optimizations
```sql
CREATE INDEX idx_sessions_device_alias ON sessions(device_id, alias);
CREATE INDEX idx_reservations_status ON reservations(status, expires_at);
CREATE INDEX idx_audit_logs_session ON audit_logs(session_id, created_at);
```