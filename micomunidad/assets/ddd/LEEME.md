# 🌼 Imágenes de Día de Muertos

Pon aquí **tus** fotos e ilustraciones con estos nombres exactos. Si falta alguna,
**no se rompe nada**: la página se ve con el respaldo de colores que ya trae.

Esta carpeta vive dentro del sitio: `micomunidad/assets/ddd/`.

| Archivo | ¿Dónde se ve? | Tamaño sugerido | Formato |
|---|---|---|---|
| `logo.png` | Cuadrito 🤝 arriba a la izquierda (cubre el emoji) | **96 × 96 px** | PNG con fondo transparente |
| `papel-picado.png` | Franja pegada arriba del encabezado (se repite a los lados y se recorta en triángulos sola) | ancho **400 px** × alto **48 px** | PNG transparente |
| `banner.png` | Recuadro "Día de Muertos en tu comunidad", lo primero del inicio | **1200 × 500 px** | PNG o JPG |
| `fondo.png` | Marca de agua de toda la página, se ve al **10 %** de opacidad | **1200 × 1600 px** | PNG transparente |
| `favicon.png` | Ícono de la pestaña del navegador (sustituye el 🤝) | **64 × 64 px** | PNG |

## Consejos para que no se vea "IA"
- Usa fotos **reales de tu pueblo**: la ofrenda de la presidencia, el panteón, el pan
  de muerto del panadero, las catrinas de la escuela. Eso sí convence.
- Pasa las imágenes por [squoosh.app](https://squoosh.app) o tinypng.com para que
  pesen **menos de 150 KB** (si pesan más, el sitio va lento en el celular).
- Deja el **logo, el papel picado y el fondo con transparencia** (PNG), si no se verán
  cuadros blancos encima del color.

## ¿Cómo se cambian?
1. Guarda tu archivo con el nombre de la tabla, dentro de esta misma carpeta.
2. Sube los cambios a GitHub (o dime a mí y yo los subo): en 1 minuto se ve en la web.

## ¿Quitar el tema de Día de Muertos?
Abre `micomunidad/index.html`, busca `🌼 TEMA DÍA DE MUERTOS` en el CSS y borra desde
ahí hasta `FIN DEL TEMA DÍA DE MUERTOS`. Se quitan: el papel picado, el encabezado
morado, el recuadro del banner y la marca de agua.

**Ojo:** la paleta de colores de todo el sitio (morados y lila) está aplicada en el CSS
general, no dentro de ese bloque. Si quieres volver al diseño naranja de antes, pídemelo
y lo regreso en un minuto, o haz estos cambios de texto:

| De vuelta a | Busca → reemplaza |
|---|---|
| naranja | `#7C3AED` → `#C2410C` · `#6D28D9` → `#9A3412` · `#F3E8FF` → `#FFF1E7` |
| crema | `#FFF6EA` → `#FFFCF9` · `#FBF6FE` → `#FDFAF7` · `#FBF6FD` → `#FAF7F4` |
| beige | `#EEE0F2` → `#EDE6DF` · `#F4EBF9` → `#F3EEE9` · `#F6EFF8` → `#F5EFE9` |
| texto | `#7B6A86` → `#7C7169` · `#2A1B33` → `#221B16` |
| sombras | `rgba(42,27,51,` → `rgba(34,27,22,` |

## ¿Agregar otra imagen?
Cualquier hueco es de esta forma (ponlo donde lo necesites):

```html
<img class="slot" src="assets/ddd/NOMBRE.png" alt="" onerror="this.remove()">
```

Si el archivo no existe, la imagen **se borra sola** y queda lo que había debajo.
