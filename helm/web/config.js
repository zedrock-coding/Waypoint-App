// Public Supabase configuration shared by the static pages in helm/web/.
//
// These values are safe to ship: the publishable/anon key is designed to be
// public and is constrained by Row-Level Security. They live here - and in
// helm/lib/config/app_config.dart - so a key rotation is a two-file change
// instead of a scavenger hunt.
//
// A privileged (service-role) key must NEVER appear in this file, or anywhere
// in helm/web/.
window.HELM_PUBLIC_CONFIG = {
  supabaseUrl: 'https://eknzdxexfcfdmqvbyvxt.supabase.co',
  supabaseAnonKey: 'sb_publishable_fUoY96CXli7DwbZayu8pFQ_4yExvoJg',
};