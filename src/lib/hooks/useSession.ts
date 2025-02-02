import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface SessionState {
  alias: string | null
  sessionId: string | null
  language: 'es-ES' | 'en-UK'
  isAdmin: boolean
  deviceId: string | null
  expiresAt: Date | null
  status: 'idle' | 'loading' | 'error'
}

export const useSessionStore = create(
  persist<SessionState>(
    (set) => ({
      alias: null,
      sessionId: null,
      language: 'es-ES',
      isAdmin: false,
      deviceId: null,
      expiresAt: null,
      status: 'idle'
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
)