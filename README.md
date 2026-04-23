# Ejercicio1 – Pokédex en SwiftUI

Aplicación iOS en SwiftUI que muestra una Pokédex consumiendo la API pública de [PokeAPI](https://pokeapi.co/).  
Incluye listado paginado de Pokémon y una vista de detalle con información ampliada.

## Características

### Listado principal

- Lista de Pokémon obtenidos desde `https://pokeapi.co/api/v2/pokemon`.
- Paginación por páginas:
  - Cada página muestra 50 Pokémon.
  - Botones **Anterior** y **Siguiente** para navegar entre páginas.
  - Se deshabilitan los botones cuando no hay más páginas.
- Manejo de carga y errores:
  - Indicador de carga (`ProgressView`) mientras se obtienen los datos.
  - Si falla la primera carga, muestra mensaje de error y botón **Reintentar**.
  - Si falla al cambiar de página, aparece un error al final de la lista con botón **Reintentar** que vuelve a cargar la página actual.
- Cada fila del listado:
  - Muestra sprite, nombre y número de Pokédex.
  - Estilo tipo **tarjeta**:
    - Fondo sutil acorde al sistema (`Color(.systemBackground)`).
    - Bordes redondeados.
    - Sombra suave para destacar sobre el fondo.

### Vista de detalle

Al pulsar sobre un Pokémon del listado se navega a su pantalla de detalle, que muestra:

- **Nombre** (capitalizado).
- **ID** del Pokémon.
- **Sprite** principal (`sprites.front_default`).
- **Tipos** con chips coloreados:
  - `fire` → rojo  
  - `water` → azul  
  - `grass` / `bug` → verde  
  - `electric` → amarillo  
  - `poison` / `ghost` → morado  
  - `psychic` / `fairy` → rosa  
  - `rock` / `ground` → marrón  
  - `ice` → cian  
  - `fighting` → naranja  
  - `dragon` → índigo  
  - `steel` → gris  
  - `normal` → gris claro  
  - Otros tipos → azul suave por defecto
- **Altura** en metros (conversión desde decímetros).
- **Peso** en kilogramos (conversión desde hectogramos).
- Manejo de carga y errores:
  - `ProgressView` mientras se carga el detalle.
  - Mensaje de error y botón **Reintentar** si la petición falla.

La lógica del color por tipo está encapsulada en una función auxiliar:

```swift
private func color(forType type: String) -> Color { ... }
```

## Arquitectura

- **SwiftUI** con `NavigationStack` para gestionar la navegación.
- Patrón **MVVM** ligero:
  - `PokemonListViewModel`:
    - Se encarga de la carga paginada de la lista de Pokémon.
    - Expone estado con `@Published`:
      - `pokemon`, `isLoading`, `errorMessage`, `currentPage`, etc.
  - `PokemonDetailViewModel`:
    - Descarga el detalle de un Pokémon concreto (por `pokemon.url`).
    - Maneja estados de carga y error para la pantalla de detalle.
- Modelos de red decodificables con `Decodable`:
  - `PokemonListResponse`, `PokemonListItem`, `PokemonDetail` y tipos anidados.

## Requisitos

- Xcode 15 o superior (recomendado).
- iOS 17 o superior (puedes ajustarlo en el `Deployment Target` si lo necesitas).
- Conexión a Internet para consumir PokeAPI.

## Estructura principal de ficheros

- `Ejercicio1App.swift`: Punto de entrada de la app (estructura `@main`).
- `ContentView.swift`:
  - Modelos (`PokemonListResponse`, `PokemonListItem`, `PokemonDetail`).
  - ViewModels (`PokemonListViewModel`, `PokemonDetailViewModel`).
  - Vistas (`ContentView`, `PokemonDetailView`, `PokemonRowView`).
  - Función auxiliar `color(forType:)`.

## Cómo ejecutar el proyecto

1. Clona el repositorio o descarga el proyecto.

   ```bash
   git clone <URL-del-repo>
   cd Ejercicio1
   ```

2. Abre el proyecto en Xcode:

   - Doble clic en `Ejercicio1.xcodeproj`, o
   - Desde terminal:

     ```bash
     open Ejercicio1.xcodeproj
     ```

3. Selecciona un simulador (por ejemplo, *iPhone 15*) o tu dispositivo físico.
4. Pulsa **Run** (⌘ + R).

La aplicación debería arrancar mostrando el listado de Pokémon, con paginación al final y permitiendo abrir el detalle de cada uno.

## Posibles mejoras futuras

- Búsqueda por nombre o número de Pokédex.
- Filtros por tipo de Pokémon.
- Persistencia en caché de resultados para uso offline.
- Animaciones extra en las tarjetas y transición hacia la vista detalle.
- Soporte para modo horizontal y iPad con layout adaptativo.
