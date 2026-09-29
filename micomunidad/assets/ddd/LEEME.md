# 🌼 Imágenes de Día de Muertos

Pon aquí **tus** fotos e ilustraciones con estos nombres exactos. Si falta alguna,
**no se rompe nada**: la página se ve con el respaldo de colores que ya trae.

| Archivo | ¿Dónde se ve? | Tamaño sugerido | Formato |
|---|---|---|---|
| `logo.png` | Cuadrito 🤝 arriba a la izquierda (sustituye el emoji) | **96 × 96 px** | PNG con fondo transparente |
| `papel-picado.png` | Franja de banderitas arriba del encabezado (se repite hacia los lados) | ancho **200 px** × alto **40 px** | PNG transparente |
| `banner.png` | Caja morada "Día de Muertos" al inicio del inicio | **1200 × 500 px** | PNG o JPG |
| `favicon.png` | Ícono de la pestaña del navegador | **64 × 64 px** | PNG |
| `fondo.png` | Marca de agua de fondo (se ve al 14% de opacidad) | **1200 × 1600 px** | PNG transparente |

## Consejos para que no se vea "IA"
- Usa fotos **reales de tu pueblo**: la ofrenda de la presidencia, el panteón, el pan
  de muerto del panadero, las catrinas de la escuela. Eso sí convence.
- Pasa las imágenes por [squoosh.app](https://squoosh.app) o tinypng.com para que
  pesen **menos de 150 KB** (si pesan más, el sitio va lento en el celular).
- Deja el **logo y el papel picado con fondo transparente** (PNG), si no se verán
  cuadros blancos encima del color.

## ¿Cómo se cambian?
1. Guarda tu archivo con el nombre de la tabla aquí arriba.
2. Corre `actualizar.bat` (está en la carpeta de arriba) para copiarlo al sitio.
3. Sube los cambios a GitHub y en 1 minuto se ve en la web.

## ¿Quitar el tema de Día de Muertos?
Abre `index.html`, busca `🌼 TEMA DÍA DE MUERTOS` en el CSS y borra desde ahí
hasta `--- FIN DEL TEMA DÍA DE MUERTOS ---`. Vuelve al diseño normal de un solo clic.

## ¿Agregar otra imagen?
Cualquier hueco es de esta forma (ponlo donde lo necesites):

```html
<img class="slot" src="assets/ddd/NOMBRE.png" alt="" onerror="this.remove()">
```

Si el archivo no existe, la imagen **se borra sola** y queda lo que había debajo.
