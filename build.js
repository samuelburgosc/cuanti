// build.js — Inyecta variables de entorno en index.html antes del deploy en Vercel
const fs = require('fs');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY;

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error('ERROR: Faltan variables de entorno SUPABASE_URL y/o SUPABASE_KEY');
  console.error('Configúralas en Vercel: Settings → Environment Variables');
  process.exit(1);
}

let html = fs.readFileSync('index.html', 'utf8');
html = html.replace('__SUPABASE_URL__', SUPABASE_URL);
html = html.replace('__SUPABASE_KEY__', SUPABASE_KEY);

if (!fs.existsSync('dist')) fs.mkdirSync('dist');
fs.writeFileSync('dist/index.html', html);

console.log('✓ Build completado — index.html generado en dist/');
