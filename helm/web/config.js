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
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVrbnpkeGV4ZmNmZG1xdmJ5dnh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ5MTI3MTMsImV4cCI6MjEwMDQ4ODcxM30.ljz85USIZCfqhJmViTTg24dgOx5wzuzck9ykgEA8_IQ',
};