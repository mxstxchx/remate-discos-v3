import { FC, useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { useSessionStore } from '@/stores/session';
import { SessionErrorBoundary } from './SessionErrorBoundary';

export const SessionProvider: FC = ({ children }) => {
  const [mounted, setMounted] = useState(false);
  const { sessionId, initialize } = useSessionStore();
  const router = useRouter();

  useEffect(() => {
    if (!mounted) {
      setMounted(true);
      initialize({});
    }

    if (!sessionId && router.pathname !== '/session') {
      router.replace('/session');
    }
  }, [mounted, sessionId]);

  if (!mounted) return null;

  return (
    <SessionErrorBoundary>
      {children}
    </SessionErrorBoundary>
  );
};
