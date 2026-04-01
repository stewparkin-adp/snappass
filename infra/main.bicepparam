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
// Branding
// ---------------------------------------------------------------------------

param theme        = 'flatly'
param brandTitle   = 'Assured Data Protection'
param brandTagline = 'Securely share sensitive information'

// Logo URLs — set to a publicly accessible image (CDN, Azure Blob, etc.)
// param lightLogo = 'https://example.com/adp-logo.png'
// param darkLogo  = 'https://example.com/adp-logo-dark.png'

// ---------------------------------------------------------------------------
// Optional overrides (uncomment to change defaults)
// ---------------------------------------------------------------------------

// param containerImage = 'pglombardo/pwpush:stable'
// param customDomain   = 'secrets.assured-dp.com'
// param minReplicas    = 1
// param maxReplicas    = 3
