import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface SessionState {
  sessionId: string | null;
  alias: string | null;
  language: 'es-ES' | 'en-UK';
  isAdmin: boolean;
  expiresAt: Date | null;
}

interface SessionActions {
  initialize: (session: Partial<SessionState>) => void;
  clear: () => void;
  setLanguage: (language: 'es-ES' | 'en-UK') => void;
}

const initialState: SessionState = {
  sessionId: null,
  alias: null,
  language: 'es-ES',
  isAdmin: false,
  expiresAt: null,
};

export const useSessionStore = create(
  persist<SessionState & SessionActions>(
    (set) => ({
      ...initialState,

      initialize: (session) => {
        set({ ...session });
        localStorage.setItem('session-update', Date.now().toString());
      },

      clear: () => {
        set(initialState);
        localStorage.setItem('session-update', Date.now().toString());
      },

      setLanguage: (language) => {
        set({ language });
        localStorage.setItem('session-update', Date.now().toString());
      },
    }),
    {
      name: 'session-store',
      partialize: (state) => ({
        sessionId: state.sessionId,
        alias: state.alias,
        language: state.language,
        isAdmin: state.isAdmin,
        expiresAt: state.expiresAt,
      }),
    }
  )
);

// Simple cross-tab sync
if (typeof window !== 'undefined') {
  window.addEventListener('storage', (e) => {
    if (e.key === 'session-update') {
      const storedSession = localStorage.getItem('session-store');
      if (storedSession) {
        try {
          const session = JSON.parse(storedSession);
          const state = session.state;
          useSessionStore.setState({
            sessionId: state.sessionId,
            alias: state.alias,
            language: state.language,
            isAdmin: state.isAdmin,
            expiresAt: state.expiresAt ? new Date(state.expiresAt) : null,
          });
        } catch (error) {
          console.error('[APP] Session sync error:', error);
        }
      }
    }
  });
}
