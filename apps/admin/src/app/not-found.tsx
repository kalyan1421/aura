import Link from 'next/link';

export default function NotFound() {
  return (
    <main id="main" className="auth">
      <div className="panel">
        <h1>Not found</h1>
        <p>That item does not exist, or it was closed and purged.</p>
        <p>
          <Link href="/now" prefetch={false}>
            Back to Now
          </Link>
        </p>
      </div>
    </main>
  );
}
