import React from 'react';
import { useSessionStore } from '@/stores/session';

interface ErrorBoundaryProps {
  children: React.ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
}

export class SessionErrorBoundary extends React.Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error) {
    const { clear } = useSessionStore.getState();
    clear();
    console.error('[APP] Session error:', error.message);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="p-4 text-center">
          <h2 className="text-lg font-semibold mb-2">Session Error</h2>
          <p className="text-gray-600 mb-4">Please refresh the page to continue.</p>
          <button
            onClick={() => window.location.reload()}
            className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
          >
            Refresh
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
