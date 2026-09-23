'use client';

/** Something failed while loading a console view (details stay on the server; nothing sensitive is shown here). */
export default function ConsoleError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div className="panel" role="alert">
      <h1>This view could not load</h1>
      <p>The API may be unreachable or restarting. Your session is unchanged.</p>
      <button type="button" className="btn" onClick={() => reset()}>
        Try again
      </button>
    </div>
  );
}
