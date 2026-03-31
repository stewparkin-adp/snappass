using './main.bicep'

// ---------------------------------------------------------------------------
// Required — edit before deploying
// ---------------------------------------------------------------------------

param baseName = 'pwpush'

// Loaded from the shell environment at deploy time.
// Never hard-code secrets here.
param secretKeyBase   = readEnvironmentVariable('PWP_SECRET_KEY_BASE')
param pwpushMasterKey = readEnvironmentVariable('PWP_MASTER_KEY')

// ---------------------------------------------------------------------------
// Optional overrides (uncomment to change defaults)
// ---------------------------------------------------------------------------

// param containerImage = 'psilocybin/pwpush:latest'
// param customDomain   = 'secrets.assured-dp.com'
// param minReplicas    = 1
// param maxReplicas    = 3
