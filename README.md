# 🤝 MiComunidad

> **Tu comunidad y sus alrededores.** Avisos, ventas y vida del pueblo.
> Hosting gratis (Cloudflare) · base de datos gratis (Supabase) · costo total **$0**.

---

## Qué hay en este repo

| Ruta | Qué es |
|---|---|
| `micomunidad/index.html` | **La app — el sitio que ve la gente.** Todo en un archivo, se conecta a Supabase. |
| `micomunidad/config.js` | Aquí pegas tus **2 llaves** de Supabase (2 líneas). |
| `micomunidad/_headers` | Seguridad y caché para Cloudflare Pages (ya configurado). |
| `micomunidad/supabase/schema.sql` | Toda la base de datos: tablas, permisos (RLS) y funciones. |
| `micomunidad/assets/ddd/LEEME.md` | Guía de imágenes de Día de Muertos. |
| `README.md` | Este archivo. |

> ⚠️ **El prototipo de demostración no está en este repo** porque el repo es público.
> `mipueblo-prototipo.html` (tema Día de Muertos, datos de mentira) vive **solo en tu PC**
> y es con lo que visitas a los negocios. Esta app es la de datos reales.

---

## 1. Subir cambios — los 3 comandos de siempre

```bash
git add -A
git commit -m "lo que cambió"
git push
```

Cloudflare Pages vuelve a publicar solo en ~30 segundos. Si me dices *"súbelo"*, yo los ejecuto.

---

## 2. Primera publicación en Cloudflare Pages

1. [dash.cloudflare.com](https://dash.cloudflare.com) → **Workers & Pages** → **Create** → pestaña **Pages** → **Connect to Git**
2. Elige el repo `mi-comunidad` (autoriza GitHub si te lo pide)
3. Configura:
   - *Framework preset* = **None**
   - *Build command* = **vacío**
   - ***Output directory* = `micomunidad`** ← importante, no lo dejes en blanco
4. **Save and Deploy** → en ~30 s queda vivo en `https://mi-comunidad.pages.dev`
5. **Custom domains** → escribe tu dominio; como tus DNS ya están en Cloudflare, el registro
   y el certificado SSL se crean solos (1–5 minutos).

---

## 3. La base de datos (Supabase, gratis)

1. [supabase.com](https://supabase.com) → **New project** (región cercana: *South US* / *East US*)
2. **SQL Editor** → *New query* → abre `micomunidad/supabase/schema.sql`, copia **todo** y pega → **Run**
3. **Authentication → Sign In / Providers** → activa **Anonymous sign-ins**
   (es el login de vendedores con PIN; es gratis y **no manda SMS**)
4. **Authentication → Users** → **Add user**: tu correo y una contraseña, marca *Auto Confirm User*
   → ese eres **tú como administrador**
5. SQL Editor → copia el bloque **CREAR TU USUARIO ADMIN** (última parte del schema),
   descoméntalo, pon **tu correo** y dale **Run**
6. Storage ya quedó listo (el SQL crea el bucket `fotos`); revisa en **Storage → Settings**
   que el límite de subida sea **1 MB**

---

## 4. Conectar la app a tus datos

Abre **`micomunidad/config.js`** y cambia solo 2 líneas:

```js
SUPABASE_URL:      'https://XXXXXXXX.supabase.co',  // Project Settings → API → Project URL
SUPABASE_ANON_KEY: 'eyJhbGciOi...',                 // Project Settings → API → anon public
```

Sube los cambios. Al entrar a tu dominio ya **no** aparece la pantalla de "configúrame".

---

## 5. Reglas de negocio que ya están escritas en la base de datos

**Avisos — cualquiera, sin cuenta**
- Pide nombre (persona o comité) y celular; el celular **nunca se muestra público**.
- **1 día sin destacar** → se publica al instante y cae en tu cola para revisar spam.
- **5 días o más** (o ⭐ destacado) → espera tu verificación (promesa: 20 minutos).
- Máximo **3 avisos por celular en 24 horas** (límite en la función `enviar_aviso`).
- Si detecta palabras de venta, la app ofrece crear perfil de vendedor.

**Vendedores**
- Registro: nombre + negocio + celular + **PIN de 6 dígitos** → queda `pendiente` hasta que lo apruebes.
- **5 intentos fallidos = 15 minutos de bloqueo** (lo hace la base de datos, no el navegador).
- PIN **cifrado con bcrypt**; esa columna ni siquiera sale por la API.
- Solo un vendedor `aprobado` publica y todo entra como `pendiente`.

**Administrador**
- Entra con correo y contraseña de Supabase.
- **Nadie se auto-aprueba ni se auto-destaca**: lo protege `proteger_fila()` en el SQL.
- Secciones: 📞 avisos por verificar (cronómetro, rojo >20 min), ⏳ publicaciones,
  🧑‍💼 vendedores, 🤝 patrocinadores.

**Fotos** — se comprimen en el celular a WebP de 1280 px ≈ 60 KB antes de subir.

**Multi-comunidad** — todo lleva `pueblo_id`; para agregar un pueblo:
`insert into pueblos (id, nombre, icono) values ('p4','Mi Pueblo','🏘️');`

---

## 6. Costos

| Concepto | Costo |
|---|---|
| Cloudflare Pages (hosting + SSL) | $0 |
| Supabase Free (500 MB base + 1 GB de fotos) | $0 |
| GitHub | $0 |
| **Total** | **$0** |

---

## 7. Pendientes

- [ ] **Pagos automáticos** de los planes (⭐ $10/semana · 📍 $100/mes · 👑 $400/mes):
      proveedor (MercadoPago / Stripe / Conekta) + webhook en `/functions` + columna `vence`.
- [ ] Aviso al autor cuando se aprueba su aviso (correo o WhatsApp).
- [ ] Caducidad automática de avisos con `pg_cron` (hoy se calcula al mostrar).
- [ ] Copia de respaldo diaria (Supabase → Database → Backups).
