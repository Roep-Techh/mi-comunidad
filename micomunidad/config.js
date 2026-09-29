/* ==========================================================================
   MiComunidad · config.js  →  PEGA AQUÍ TUS LLAVES (1 minuto)
   Supabase → Project Settings → API
     · Project URL  → SUPABASE_URL
     · anon public  → SUPABASE_ANON_KEY   (esta llave es pública, no es secreta)
   ========================================================================== */
window.MC = {
  SUPABASE_URL:    'https://TU-PROYECTO.supabase.co',
  SUPABASE_ANON_KEY: 'PEGA_AQUI_TU_ANON_KEY',
  PUEBLO_DEFECTO:  'p1'
};

/* No tocar */
window.MC.CONFIGURADO =
  !!window.MC.SUPABASE_URL &&
  window.MC.SUPABASE_URL.indexOf('TU-PROYECTO') === -1 &&
  !!window.MC.SUPABASE_ANON_KEY &&
  window.MC.SUPABASE_ANON_KEY.indexOf('PEGA_AQUI') === -1;
