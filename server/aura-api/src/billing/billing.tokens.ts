/** Nest injection tokens for F12's external boundaries (tests override them with fakes). */
export const APPLE_JWS_VERIFIER = Symbol('APPLE_JWS_VERIFIER');
export const APP_STORE_API = Symbol('APP_STORE_API');
export const PLAY_API = Symbol('PLAY_API');
export const PUBSUB_VERIFIER = Symbol('PUBSUB_VERIFIER');
export { BILLING_CONFIG } from './billing.config';
