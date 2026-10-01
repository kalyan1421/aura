import { closeSharedWorkerConnections, redisOptionsFromUrl, sharedWorkerConnection } from '../../src/queues/redis';

describe('sharedWorkerConnection', () => {
  const url = 'redis://127.0.0.1:6391';
  afterEach(() => closeSharedWorkerConnections());

  it('is one client per URL (BullMQ workers share it instead of opening 2 connections each)', () => {
    const a = sharedWorkerConnection(url);
    expect(sharedWorkerConnection(url)).toBe(a);
    expect(sharedWorkerConnection('redis://127.0.0.1:6392')).not.toBe(a);
  });

  it('keeps what BullMQ requires: maxRetriesPerRequest null, and a TCP keepalive', () => {
    const c = sharedWorkerConnection(url);
    expect(c.options.maxRetriesPerRequest).toBeNull();
    expect(c.options.keepAlive).toBe(10_000);
    expect(redisOptionsFromUrl(url).maxRetriesPerRequest).toBeNull();
  });

  it('closing forgets the client, so the next call builds a fresh one', () => {
    const a = sharedWorkerConnection(url);
    closeSharedWorkerConnections();
    expect(sharedWorkerConnection(url)).not.toBe(a);
  });
});
