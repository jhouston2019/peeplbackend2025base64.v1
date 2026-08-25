// Batch Places Nearby Search from this script is forbidden.
// Venue names are resolved once at post creation in the app.
// Do not restore Nearby Search, Find Place, or type loops here.
console.error(
  'Aborted. fix_venue_names.js must not be run. It billed Google Places Nearby Search.',
);
process.exit(1);
