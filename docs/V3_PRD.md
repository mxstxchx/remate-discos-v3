# Remate Discos V3 - Product Requirements Document

## Overview
Web application for browsing and reserving vinyl records. Features session-based authentication, dual-language support, and a streamlined browsing experience.

## Core Requirements

### 1. Session Management

Entry Point (/session):
- Device/alias recognition system
- Modal states:
  * New user: Alias creation + language selection
  * Returning user: Continue as [alias] option
  * Admin: Redirect to /admin post-authentication
  * Regular user: Redirect to /browse post-authentication

Session Features:
- 30-day persistence (localStorage + cookies)
- Alias-based system with multi-device support
- Language preferences: es-ES (primary), en-UK (secondary)
- Cross-tab synchronization
- Real-time expiration handling
- Device fingerprinting for session linking

### 2. Browse Interface (/browse)

Layout:
- 75/25 split with filter sidebar
- Fixed header with language toggle
- Sticky session info (alias, cart)

Filter Components:
1. Primary Filters (Top Cards):
   - Artists (searchable modal)
   - Labels (searchable modal)
   - Styles (searchable modal)

2. Secondary Filters (Sidebar):
   - Price range (€)
   - Condition selection
   - Clear filters option

Grid View:
- Responsive layout (2-4 columns)
- Release preview cards:
  * Cover image with loading state
  * Title + Artists
  * Label + Catalog number
  * Price (€)
  * Condition badge
  * Reservation status

### 3. Release Management

Release Details:
- High-res images (primary + secondary)
- Complete metadata
  * Title and artist(s)
  * Label information
  * Release details (year, country)
  * Tracklist with durations
  * Media condition
  * Pricing in EUR
  * Style tags

Reservation System:
- 7-day hold period
- Status transitions:
  * Available -> In Cart
  * In Cart -> Reserved (requires admin confirmation)
  * Reserved -> Sold (admin only)
  * Reserved -> Expired (automatic after 7 days)
  * Reserved -> Cancelled (user or admin)
  * In Queue -> Reserved (automatic when spot opens)
- Queue management with position tracking
- WhatsApp integration for purchase completion

### 4. Admin Interface (/admin)

Dashboard:
- Active reservations overview
- Queue management
- Sales tracking
- User session monitoring
- Action audit logs

Features:
- Reservation management
  * Force expire
  * Mark as sold
  * Cancel reservations
  * Queue position adjustments
- Sales reports
- Inventory updates

## Technical Requirements

### 1. Authentication
- Alias-based with device recognition
- Session-based persistence
- Admin role management
- Route protection middleware
- Cross-tab session sync
- Expiration handling

### 2. Database Schema
```typescript
interface Release {
  id: number
  title: string
  artists: string[]
  labels: { name: string, catno: string }[]
  styles: string[]
  year?: string
  country?: string
  condition: string
  price: number
  images: {
    primary: string
    secondary?: string
  }
  tracklist?: {
    position: string
    title: string
    duration?: string
  }[]
}

interface Device {
  id: string
  fingerprint: string
  last_seen: Date
  is_active: boolean
}

interface Session {
  id: string
  alias: string
  device_id: string
  language: 'es-ES' | 'en-UK'
  is_admin: boolean
  created_at: Date
  last_active: Date
  expires_at: Date
}

interface Reservation {
  id: string
  release_id: number
  session_id: string
  status: ReservationStatus
  position_in_queue?: number
  reserved_at: Date
  expires_at?: Date
  audit_log_id: string
}

interface AuditLog {
  id: string
  session_id: string
  action: string
  details: Record<string, unknown>
  created_at: Date
}

type ReservationStatus = 
  | 'available'   // Initial state
  | 'in_cart'     // Added to cart
  | 'reserved'    // Active hold
  | 'in_queue'    // Waitlist
  | 'sold'        // Completed
  | 'expired'     // Past 7-day period
  | 'cancelled'   // User/admin cancelled
```

### 3. State Management
- Session store with persistence
- Cart state with expiration
- Filter state management
- Cross-tab synchronization
- Error boundaries
- Loading states

### 4. Performance
- Image optimization
- Query optimizations
- Component memoization
- Lazy loading
- Request debouncing
- Mobile responsiveness