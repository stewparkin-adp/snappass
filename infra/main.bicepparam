using './main.bicep'

// ---------------------------------------------------------------------------
// Required — edit before deploying
// ---------------------------------------------------------------------------

param baseName = 'snappass'

// Loaded from the shell environment at deploy time (set by deploy.sh).
// Never hard-code secrets here.
param flaskSecretKey = readEnvironmentVariable('SNAPPASS_SECRET_KEY')

// ---------------------------------------------------------------------------
// Optional overrides (uncomment to change defaults)
// ---------------------------------------------------------------------------

// param containerImage = 'pinterest/snappass:latest'
// param redisSku       = 'Standard'
// param redisCapacity  = 1
// param minReplicas    = 1
// param maxReplicas    = 3
