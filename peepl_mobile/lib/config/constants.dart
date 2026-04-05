// ignore: constant_identifier_names — public API base URL, matches backend env naming
const String API_BASE_URL = 'https://peepl2025v1-production.up.railway.app';

// Stripe publishable key — non-secret, safe to ship in client code.
// Replace with your live key from https://dashboard.stripe.com/apikeys
// Use pk_test_... for development, pk_live_... for production.
// NEVER put the secret key (sk_...) here or anywhere in Flutter code.
const String kStripePublishableKey = 'pk_test_YOUR_PUBLISHABLE_KEY_HERE';
