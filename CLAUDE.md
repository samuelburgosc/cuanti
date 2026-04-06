# CUANTI — Documento maestro del proyecto

## 0. Propósito de este documento

Este documento existe para que cualquier IA de desarrollo, diseñador, futuro colaborador o yo mismo entienda con máxima claridad:

* qué es Cuanti
* para quién existe
* qué problema resuelve
* qué NO debe convertirse
* cómo debe priorizarse el producto
* qué decisiones de diseño, negocio y tecnología ya están tomadas
* qué principios no se deben romper

Este documento tiene prioridad sobre interpretaciones ambiguas.
Si algo no está explícitamente definido, siempre se debe elegir la opción que haga a Cuanti:

1. más simple
2. más útil
3. más rápida
4. más entendible para alguien no técnico
5. más enfocada en ganancia real y acción

---

## 1. Quién soy

Me llamo Samuel Burgos (Samu), emprendedor chileno. Vivo en Santiago, Chile. No sé programar profesionalmente; estoy construyendo Cuanti aprendiendo desde cero con ayuda de inteligencia artificial. Mi rol no es técnico: soy el fundador, dueño de la visión del producto, del problema a resolver, del criterio de negocio, del diseño esperado y de la experiencia final.

**Mi prioridad no es "hacer software" por hacer software.**
Mi prioridad es construir un producto real que microemprendedores latinoamericanos usen todos los días porque les ayuda a entender cuánto ganan y qué hacer con su negocio.

Email: samuburgos123@gmail.com

---

## 2. Qué es Cuanti

**Cuanti** es una aplicación SaaS de gestión para microemprendedores latinoamericanos que venden productos físicos: ropa, calzado, accesorios, electrónica y cualquier producto de comercio minorista con stock.

El nombre viene de:

* **cuantificar**
* **"¿cuánto gané?"**

Esa es la pregunta central del producto.

---

## 3. Qué problema resuelve

El microemprendedor latinoamericano vende, compra, repone y se mueve rápido, pero casi siempre gestiona su negocio:

* en la cabeza
* en un cuaderno
* en notas de WhatsApp
* en Excel mal armado
* o mezclando todo eso

El resultado es que:

* sabe cuánto vendió, pero no cuánto ganó
* no descuenta costos, comisiones ni gastos
* no sabe qué producto conviene más reponer
* no sabe qué producto deja más plata
* no sabe qué canal de venta es más rentable
* no detecta stock muerto
* no compra con criterio, compra por intuición
* siente que "trabaja mucho" pero no entiende dónde está la plata

**Cuanti existe para transformar esa intuición en claridad.**

No para mostrar más números, sino para ayudar a tomar mejores decisiones.

---

## 4. Qué hace Cuanti concretamente

Cuanti permite:

* registrar ventas en segundos desde el celular
* calcular automáticamente la ganancia real
* descontar stock por variante
* alertar antes del quiebre
* mostrar ganancia real por día, semana y mes
* identificar productos con mejor ROI
* comparar canales de venta
* detectar productos que rotan y productos que inmovilizan capital
* ayudar a decidir qué vender primero, qué reponer y qué priorizar

**Cuanti no solo registra. Interpreta.**

---

## 5. Qué NO es Cuanti

Cuanti no debe convertirse en:

* un ERP pesado
* un software contable formal
* una copia de Bsale
* un dashboard corporativo
* una herramienta pensada para gente experta en Excel o BI
* una app llena de funciones que nadie entiende
* una solución centrada en cumplimiento tributario antes que en operación real

Si una decisión acerca a Cuanti a eso, probablemente está mal.

---

## 6. Visión del producto

### Hoy
Herramienta personal para mi negocio de reventa streetwear en Santiago.

### Corto plazo
Escalar al negocio familiar de calzado y ropa deportiva con 2 locales físicos.

### Largo plazo
Ser el sistema de gestión número uno para microemprendedores de comercio minorista en Latinoamérica, empezando por Chile.

### Visión profunda
Que cualquier persona que venda productos físicos desde el celular pueda entender su negocio en segundos y tomar decisiones con seguridad, sin necesitar conocimientos técnicos.

---

## 7. Misión

Darles a los microemprendedores una forma simple de registrar sus ventas, entender su ganancia real y saber qué hacer para mejorar su negocio.

---

## 8. Propuesta de valor

### Versión principal
**No es cuánto vendes. Es cuánto ganas.**

### Versión extendida
Cuanti no solo te muestra datos. Te dice qué hacer con ellos.

### Promesa del producto
Registrar, entender, decidir.

---

## 9. Usuario objetivo

### Perfil principal
Microemprendedor latinoamericano que vende productos físicos y opera principalmente desde el celular.

### Características del usuario

* no es técnico
* no quiere aprender software complejo
* no tiene tiempo para configurar sistemas largos
* vende en ferias, tiendas pequeñas, redes sociales, WhatsApp, grupos de Facebook, marketplaces locales
* puede tener entre 10 y 200 productos activos
* puede manejar solo su negocio o con ayuda de 1–3 personas
* no tiene presupuesto para herramientas caras
* puede tener 70 años y nunca haber usado un sistema de gestión

### Regla de diseño
La app debe ser tan simple que un emprendedor de 70 años pueda usarla sin explicación larga.

---

## 10. Mi negocio actual: laboratorio real

Reventa de streetwear en Santiago, Chile.

### Canales actuales
* Sotos
* WhatsApp
* Facebook

### Compras
* Amazon Japón
* proveedores locales
* compras por lote

### Productos
* Zapatillas: Nike, Jordan, Adidas, New Balance
* Ropa: BAPE, Supreme
* Gorras: Palace
* Bolsos: BAPE

### Regla clave de negocio — Comisión Sotos
Sotos cobra comisión del 15% con tope de $10.000 CLP por ítem.

```javascript
comision = canal === 'Sotos' ? Math.min(precio * 0.15, 10000) : 0
```

### Ganancia por venta
```javascript
ganancia = (precio_unitario - costo_unitario) * cantidad - comision
```

### Contexto tributario actual
Las boletas las emite MercadoPago POS.
Por ahora Cuanti no necesita integración SII.

---

## 11. Posicionamiento competitivo

### Contra Excel
Excel obliga al usuario a saber fórmulas, mantener estructura y no romper celdas. Cuanti elimina esa fricción.

### Contra Power BI / Looker
Esas herramientas asumen que los datos ya existen y están ordenados. Cuanti captura y analiza en el mismo lugar.

### Contra Bsale
Bsale asume una pyme más formal, con más estructura, más presupuesto y foco más contable.
Cuanti está pensado para una sola persona que hace todo y necesita rapidez, simplicidad y precio accesible.

**Bsale planes:** Básico 1.5UF/mes (~$57k), Estándar 1.9UF/mes (~$72k), Full 2.9UF/mes (~$110k)

### Ventajas de Cuanti vs competencia
1. Inventario por variante/talla (nadie lo tiene)
2. ROI real por producto y canal
3. Capital inmovilizado en stock
4. Escáner multi-acción
5. Ganancia real por venta (descontando costos y comisiones)
6. Mobile-first real
7. Precio accesible
8. Diseñado para quien no es técnico

### Diferencia real
**Cuanti no muestra datos. Te orienta.**
No es un dashboard: es un copiloto.

---

## 12. North Star del producto

> Que el usuario abra la app y entienda en segundos cómo va su negocio y qué hacer.

Toda funcionalidad debe empujar hacia esa experiencia.

---

## 13. Core loop de Cuanti

1. El usuario registra una venta rápido
2. Cuanti calcula la ganancia real
3. Cuanti muestra un insight útil
4. El usuario entiende algo nuevo
5. El usuario toma una decisión mejor
6. El usuario vuelve a registrar y consultar

### Regla
Registrar una venta no es el final del flujo.
El final del flujo es que el usuario entienda algo accionable.

---

## 14. Momento wow

Cuanti debe generar momentos donde el usuario piense:

> "No sabía esto de mi negocio."

### Ejemplos de momento wow
* "Este producto vende menos, pero te deja más plata."
* "WhatsApp te da más ganancia que Sotos."
* "Tienes demasiada plata detenida en este stock."
* "Este producto deberías venderlo primero."
* "Estás vendiendo harto, pero ganando poco."

### Regla
Siempre que sea posible, Cuanti debe transformar un dato en una recomendación.

---

## 15. Principios de producto

1. **Ganancia antes que ventas** — La métrica central es ganancia real.
2. **Simplicidad extrema** — Menos pasos, menos campos, menos decisiones.
3. **Mobile-first real** — No adaptado a celular: pensado desde celular.
4. **Acción antes que visualización** — Lo importante no es ver el dato, sino saber qué hacer.
5. **Velocidad** — Si registrar una venta tarda demasiado, el producto falla.
6. **Cero jerga técnica para el usuario** — Hablar como habla un emprendedor, no como un analista.
7. **Construir solo lo que aumenta utilidad real** — No agregar funciones por "verse completo".

---

## 16. Principios UX/UI obligatorios

### Regla de los 3 taps
Registrar una venta debe idealmente ocurrir en 3 taps o lo más cerca posible.

### Un número principal por pantalla
* Dashboard → cuánto ganaste
* Stock → qué se está agotando / qué está muerto
* Análisis → qué te conviene hacer

### Lenguaje humano
Usar: "Ganaste", "Se te va a acabar", "Te conviene reponer", "Vende primero esto"
Evitar: KPI, margen bruto, eficiencia operativa, rotación avanzada, términos financieros complejos

### Jerarquía visual clara
1. ganancia → 2. alerta → 3. recomendación → 4. detalle

### Dedo primero
Botones, áreas táctiles y navegación pensadas para uso con una mano.

---

## 17. Pantalla post-venta ideal

Después de confirmar una venta, Cuanti debe mostrar:
1. confirmación clara
2. ganancia de esa venta
3. nuevo stock
4. una recomendación breve si aplica

**Ejemplo:**
* Venta registrada ✓
* Ganaste $12.500
* Te quedan 2 unidades
* Ojo: esta variante ya está bajo stock mínimo

---

## 18. Sistema de insights

### Insight 1 — producto rentable
Si un producto tiene alto margen y baja rotación:
> "Este producto te deja buena ganancia. Muéstralo más."

### Insight 2 — producto trampa
Si un producto vende harto pero deja poco margen:
> "Este producto se vende, pero te deja poca plata."

### Insight 3 — canal más conveniente
> "Te conviene priorizar este canal."

### Insight 4 — quiebre cercano
> "Se te va a acabar pronto."

### Insight 5 — stock inmovilizado
> "Tienes plata parada acá."

### Regla general
Todo insight debe ser: corto, directo, accionable, entendible sin explicación.

---

## 19. Roadmap por prioridad real

### Prioridad 1 — Valor núcleo *(lo que hace que el usuario vuelva)*
1. Insights post-venta — el "momento wow" después de cada venta
2. Dashboard con recomendaciones reales
3. Alertas de stock útiles y accionables
4. Onboarding simple — primeros 2 minutos con valor

### Prioridad 2 — Operación real *(lo que hace que sea usable en producción)*
5. Autenticación real — login, sesiones, roles
6. Clientes — historial por comprador, talla preferida, canal favorito
7. Descuentos — por cliente o por cantidad
8. POS básico con cierre de caja

### Prioridad 3 — Escalamiento *(cuando haya más de un local o usuario)*
9. Multi-local robusto
10. Transferencias entre locales
11. Exportes a Excel/PDF
12. Compras mejoradas

### Prioridad 4 — Expansión *(cuando Cuanti tenga usuarios pagando)*
13. E-commerce propio
14. MercadoLibre
15. Multi-tenant SaaS maduro
16. App nativa si realmente se necesita

### Regla
No hacer features grandes antes de consolidar el núcleo.

---

## 20. Modelo de negocio preliminar

### Etapa inicial
Producto gratis o muy accesible para capturar uso real y validar recurrencia.

### Posible estructura futura

**Plan gratuito:** límite de ventas o productos, operaciones básicas

**Plan pago:** uso ilimitado, insights avanzados, multi-local, exportes, más usuarios

### Regla
Cobrar cuando el usuario ya depende del producto, no antes.

---

## 21. Stack técnico actual

```
Frontend:  index.html (HTML + CSS + JavaScript puro, ~3500 líneas)
Backend:   Supabase (PostgreSQL)
Hosting:   Vercel (auto-deploy desde GitHub)
Repo:      github.com/samuelburgosc/cuanti
URL prod:  cuanti-two.vercel.app
```

### Credenciales Supabase
Las credenciales viven en el código (index.html) y en Vercel como variables de entorno.
No se documentan aquí por seguridad.

### Decisión actual
Se mantiene frontend en un solo archivo index.html por ahora para velocidad de iteración.

### Regla
No refactorizar a una arquitectura más compleja salvo necesidad real y consulta previa.

---

## 22. Base de datos Supabase

```sql
locales (id, nombre, direccion, activo, color)
usuarios (id, nombre, email, rol, local_id→locales, activo)
categorias (id, nombre, icono, activa)
marcas (id, nombre, origen, activa)
productos (id, nombre, categoria_id→categorias, marca_id→marcas, precio_base, tiene_tallas, imagen_url, activo)
variantes (id, sku[15 dígitos auto], producto_id→productos, talla_color, local_id→locales, stock_actual, stock_minimo, costo_ultima_compra, activa)
ventas (id, fecha_hora, usuario_id, local_id, canal, metodo_pago, tipo_envio, notas, estado, devolucion, fecha_devolucion, motivo_devolucion, repone_stock)
detalle_ventas (id, venta_id→ventas, variante_id→variantes, cantidad, precio_unitario, costo_unitario)
compras (id, fecha, origen, proveedor, referencia, total_pagado_clp, tipo_cambio, total_yenes, local_destino_id, usuario_id, costo_envio_clp, notas)
detalle_compras (id, compra_id→compras, variante_id→variantes, cantidad, costo_unitario)
gastos_generales (id, fecha, descripcion, categoria_gasto, monto, local_id, usuario_id, notas)
```

### Datos de prueba cargados
- 1 local: "Mi emprendimiento"
- 5 categorías: Zapatillas 👟, Ropa 👕, Accesorios 🎒, Gorras 🧢, Bolsos 👜
- 7 marcas: Nike, Jordan, Adidas, New Balance, BAPE, Supreme, Palace
- 8 productos con variantes reales

### Nota estratégica
La base actual es suficiente para MVP. No cambiar estructura sin motivo fuerte.

---

## 23. Pantallas existentes

1. Dashboard
2. Stock / Inventario
3. Escáner central (FAB amarillo, 6 acciones: vender/ingresar/devolver/ajustar/precio/transferir)
4. Nueva Venta (flujo 3 pasos)
5. Análisis (tabs: Hoy/Semana/Mes/Histórico/Stock)
6. SKUs y Etiquetas
7. Compras
8. Historial
9. Configuración

### Criterio de revisión permanente
> ¿Qué decisión ayuda a tomar esta pantalla?

---

## 24. Sistema de diseño

### Variables CSS
```css
--bg: #080808
--sf: #111
--sf2: #191919
--accent: #E8FF3B
--red: #FF4444
--blue: #4D9FFF
--orange: #FF8C42
--green: #3BFF8A
--purple: #B47FFF
--text: #F2F2F2
--muted: #666
--bd: #2a2a2a
```

### Regla
No cambiar identidad visual base sin consulta.

---

## 25. Lo que NO cambiar sin consultar

* sistema visual base (colores, tipografías, dark mode)
* estructura principal de base de datos Supabase
* lógica comisión Sotos
* flujo principal de nueva venta (3 pasos)
* orientación mobile-first
* foco en ganancia como métrica principal

---

## 26. Riesgos de producto a evitar

1. Volverse complejo
2. Parecer ERP
3. Medir demasiadas cosas irrelevantes
4. Construir funciones que el usuario no pidió ni necesita
5. Alejarse de "cuánto gané"
6. Priorizar diseño sobre utilidad
7. Agregar configuración excesiva al inicio
8. Meter boleta electrónica demasiado pronto
9. Construir para contador en vez de emprendedor
10. Usar lenguaje técnico con el usuario

---

## 27. Instrucciones para Claude Code

### Comunicación
* Responder SIEMPRE en español
* Explicar cambios en términos simples, no técnicos
* No usar jerga si no es necesaria
* Cuando algo cambie visualmente, explicar impacto práctico

### Workflow de desarrollo
Después de cada sesión de cambios aprobados:
```bash
git add .
git commit -m "descripción del cambio"
git push origin main
```
Vercel despliega automáticamente en ~30 segundos.

### Principios de código
* mantener index.html único por ahora
* usar datos reales desde Supabase
* no hardcodear datos de producción
* priorizar rendimiento mobile
* priorizar compatibilidad en Chrome móvil y Safari iOS
* no romper flujo de venta
* no romper lógica de Sotos
* no romper sistema visual

---

## 28. Prompt operativo para Claude Code

Claude, actúa como product engineer senior y socio de producto de Cuanti.

Tu trabajo no es solo programar. Tu trabajo es ayudar a construir el sistema más simple y útil para que microemprendedores latinoamericanos entiendan cuánto ganan y qué hacer con su negocio.

Antes de proponer cambios, evalúa siempre:
1. ¿esto hace a Cuanti más simple?
2. ¿esto entrega valor más rápido?
3. ¿esto ayuda a decidir?
4. ¿esto funciona bien en celular?
5. ¿esto lo entendería alguien no técnico?

Si la respuesta a varias de estas preguntas es no, no es el camino correcto.

Prioriza: ganancia real, velocidad de uso, claridad, insights accionables, experiencia mobile-first.

Evita: complejidad innecesaria, lenguaje técnico para el usuario, features tipo ERP, dashboards vacíos, trabajo que no se traduzca en valor real.

---

## 29. Objetivo final de Cuanti

Cuanti debe convertirse en la herramienta que un microemprendedor abra todos los días porque siente:

* "acá entiendo mi negocio"
* "acá sé cuánto gané"
* "acá sé qué hacer"

No buscamos que diga: "qué sistema más completo"

Buscamos que diga: **"por fin entiendo mi negocio"**
