# Inventario Universal 1.0

Sistema de control de inventario multiempresa y multialmacén, diseñado con altos estándares de fiabilidad transaccional, trazabilidad inmutable y seguridad a nivel de base de datos.

Desarrollado con **Next.js 16 (App Router + React 19)** y **PostgreSQL 17** mediante **Supabase Local**.

---

## 🚀 Características Principales

- **Aislamiento Multiempresa Estricto (Multi-Tenant):**  
  Todas las tablas operativas utilizan claves compuestas con `business_id` y políticas **Row Level Security (RLS)** para garantizar cero fuga de datos entre empresas.
- **Valuación por Costo Promedio Ponderado (CPP):**  
  Recálculo automático y matemáticamente exacto de existencias y costos en cada entrada de almacén, preservando el costo vigente en salidas.
- **Trazabilidad y Kárdex Inmutable:**  
  Bitácora histórica detallada con sellado en tiempo, usuario responsable, stock previo (`stock_before`), stock resultante (`stock_after`) y costo unitario aplicado (`applied_unit_cost`).
- **Seguridad Procedimental:**  
  Funciones operativas blindadas con `SECURITY DEFINER`, `search_path = ''` y permisos restringidos exclusivamente a usuarios autenticados.
- **Triggers de Salvaguarda:**  
  Protección contra el borrado físico de movimientos confirmados y control estricto de transiciones de estado (`draft -> posted / cancelled`).
- **Onboarding Atómico:**  
  Inicialización segura de nuevas empresas asignando automáticamente al usuario como propietario (`owner`) y creando su almacén principal por defecto.

---

## 🛠️ Stack Tecnológico

- **Frontend:** Next.js 16.3 (Turbopack, App Router, React 19).
- **Estilos:** Tailwind CSS v4.
- **Backend & Base de Datos:** PostgreSQL 17 vía Supabase CLI (Auth GoTrue, PostgREST, Studio).
- **Librería de Acceso:** `@supabase/ssr` con Server Actions y gestión segura de cookies.
- **Lenguajes:** TypeScript 5, SQL (PL/pgSQL).

---

## 📋 Requisitos Previos

Antes de comenzar, asegúrate de tener instalado en tu sistema:
1. **Node.js** (versión 18 o superior) y **npm**.
2. **Motor de Contenedores:** **Docker** o **Docker Desktop** (necesario para ejecutar Supabase Local).

---

## ⚡ Puesta en Marcha Rápida (Setup Multiplataforma)

El proyecto incluye scripts automatizados de aprovisionamiento para cualquier sistema operativo:

### En Linux (Ubuntu, Debian, Fedora, Arch, Manjaro) o macOS:
```bash
# Dar permisos de ejecución y correr el script
bash scripts/setup.sh

# O mediante npm:
npm run setup
```

### En Windows 10 / 11 (PowerShell):
Abre PowerShell en la carpeta del proyecto y ejecuta:
```powershell
npm run setup:win
```
*(El script comprobará Node.js, Docker Desktop, creará `.env.local` e instalará las dependencias).*

---

## 💻 Desarrollo Local

Una vez completado el setup:

1. **Iniciar los servicios de Supabase Local (PostgreSQL, Auth, Studio):**
   ```bash
   npm run db:start
   ```
   - **Studio Local (Panel Web):** [http://127.0.0.1:54323](http://127.0.0.1:54323)
   - **API REST (PostgREST):** [http://127.0.0.1:54321](http://127.0.0.1:54321)
   - **PostgreSQL Directo:** `postgresql://postgres:postgres@127.0.0.1:54322/postgres`

2. **Aplicar la migración canónica consolidada:**
   ```bash
   npm run db:reset
   ```

3. **Iniciar el servidor de desarrollo de Next.js:**
   ```bash
   npm run dev
   ```
   Abre [http://localhost:3000](http://localhost:3000) en tu navegador.

---

## 📊 Modelo de Datos (Esquema Canónico)

El sistema opera sobre 7 tablas del núcleo:

```mermaid
erDiagram
    businesses ||--o{ business_members : "tiene"
    businesses ||--o{ warehouses : "posee"
    businesses ||--o{ products : "cataloga"
    businesses ||--o{ inventory_balances : "totaliza"
    businesses ||--o{ inventory_movements : "registra"
    
    inventory_movements ||--o{ inventory_movement_lines : "contiene"
    warehouses ||--o{ inventory_balances : "almacena"
    products ||--o{ inventory_balances : "valorado en"
    products ||--o{ inventory_movement_lines : "afectado por"
```

1. **`businesses`**: Empresas aisladas dentro de la plataforma.
2. **`business_members`**: Vínculo usuario-empresa con roles (`owner`, `admin`, `operator`, `viewer`).
3. **`warehouses`**: Almacenes pertenecientes a una empresa.
4. **`products`**: Catálogo de productos con SKU único por empresa.
5. **`inventory_balances`**: Existencias y Costo Promedio Ponderado en tiempo real.
6. **`inventory_movements`**: Encabezados de movimientos (tipo, estado, referencia, motivo).
7. **`inventory_movement_lines`**: Detalle por producto con trazabilidad (`stock_before`, `stock_after`, `applied_unit_cost`).

---

## 🧪 Pruebas Funcionales

Para ejecutar la suite automatizada de pruebas funcionales (onboarding, RLS, cálculo de CPP, salidas y ajustes físicos):
```bash
npx supabase db query --file supabase/tests/inventory_functional_suite.sql
```

---

## 📝 Scripts Disponibles en `package.json`

| Comando | Descripción |
| :--- | :--- |
| `npm run dev` | Inicia el servidor de desarrollo web en `localhost:3000`. |
| `npm run build` | Compila la aplicación Next.js con Turbopack y TypeScript. |
| `npm run setup` | Ejecuta el aprovisionamiento para Linux y macOS. |
| `npm run setup:win` | Ejecuta el aprovisionamiento en Windows PowerShell. |
| `npm run db:start` | Levanta la infraestructura de Supabase Local en Docker. |
| `npm run db:stop` | Detiene los contenedores locales de Supabase. |
| `npm run db:reset` | Aplica la migración SQL consolidada limpia. |

---

## 📄 Licencia

Este proyecto es privado y confidencial. Desarrollado para gestión y control empresarial de inventarios.
