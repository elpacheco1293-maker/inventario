# Nexocorp · Control de inventario por bodega

## 1. Supabase (base de datos)
1. Crea un proyecto en supabase.com.
2. SQL Editor → pega todo `supabase.sql` → Run.
3. Authentication → Users → Add user: tu correo y una contraseña fuerte (será tu acceso de administrador).
4. Authentication → Sign In / Providers → desactiva **Allow new users to sign up** (así nadie más puede crear cuentas).
5. Project Settings → API: copia **Project URL** y la clave **anon public**.

Las 42 bodegas (B300…B803) quedan creadas desde el SQL, tengan o no saldo en sistema. Si ya habías ejecutado una versión anterior, vuelve a ejecutar el archivo completo: es seguro repetirlo.

## 2. Configurar la web
Abre `index.html` y reemplaza `SB_URL` y `SB_KEY` (arriba del script) con esos dos valores. La clave anon es pública por diseño; la seguridad la dan las reglas del SQL. **Nunca uses la clave `service_role` aquí.**

## 3. GitHub
Crea un repositorio **privado**, sube `index.html`, `supabase.sql` y este README.
GitHub guarda el código, no los datos de inventario. Los datos viven en Supabase.

## 4. Vercel
Vercel → Add New Project → importa el repositorio → Deploy (sin build, es un sitio estático).
Ese link es el que compartes con las bodegas.

## Uso
- Bodegas sin saldo en sistema: aparecen igual, con su lista vacía. Pueden registrar sobrantes (código, descripción, físico) con el sistema en 0; el código autocompleta la descripción si existe en otra bodega.
- Administrador: en la pantalla de acceso escribe tu **correo** y contraseña.
- Bodegas: usuario = nombre de bodega (B301), contraseña = B301, o la que pongas en la columna `clave` del Excel.
- Dirección, nombre y logo de cada bodega: edita la tabla `bodegas` (columnas nombre, direccion, logo_url) en Supabase → Table Editor. Aparecen solos en la pantalla de la bodega.
- Respaldo: usa “Exportar CSV” del dashboard cada cierto tiempo.
