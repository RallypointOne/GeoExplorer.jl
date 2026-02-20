[![CI](https://github.com/RallypointOne/GeoExplorer.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/RallypointOne/GeoExplorer.jl/actions/workflows/CI.yml)
[![Docs Build](https://github.com/RallypointOne/GeoExplorer.jl/actions/workflows/Docs.yml/badge.svg)](https://github.com/RallypointOne/GeoExplorer.jl/actions/workflows/Docs.yml)
[![Stable Docs](https://img.shields.io/badge/docs-stable-blue)](https://RallypointOne.github.io/GeoExplorer.jl/stable/)
[![Dev Docs](https://img.shields.io/badge/docs-dev-blue)](https://RallypointOne.github.io/GeoExplorer.jl/dev/)

# GeoExplorer.jl

**Interactive geospatial exploration in Julia.**

GeoExplorer.jl provides an ArcGIS-like experience for exploring maps and geospatial data, built on [Tyler.jl](https://github.com/MakieOrg/Tyler.jl) and [GLMakie.jl](https://github.com/MakieOrg/Makie.jl).

```julia
using GeoExplorer, OSMGeocoder

explore(geocode(city="Boulder", state="CO"))
```

![Boulder, CO](https://github.com/user-attachments/assets/09b8862d-4ac8-42fd-9b0d-935527608424)

## Features

- Interactive map exploration with pan, zoom, and navigation controls
- Multiple tile providers (OpenStreetMap, Esri, CartoDB, and more)
- Plot any GeoInterface-compatible geometry
- Keyboard shortcuts for navigation

## Installation

```julia
using Pkg
Pkg.add("GeoExplorer")
```

## Quick Start

```julia
using GeoExplorer

# Launch the explorer
app = explore()

# Explore a specific region
app = explore(extent=Extents.Extent(X=(-0.2, 0.2), Y=(51.4, 51.6)))  # London

# Use satellite imagery
app = explore(provider=TileProviders.Esri(:WorldImagery))

# Explore a geometry
using GeoJSON
geom = GeoJSON.read("my_data.geojson")
app = explore(geom)
```

## Navigation

| Input | Action |
|-------|--------|
| Arrow Keys | Pan |
| +/- | Zoom in/out |
| Home | Reset view |
| Scroll | Zoom |
| Drag | Pan |

## Documentation

See the [full documentation](https://rallypointone.github.io/GeoExplorer.jl/) for detailed guides and API reference.
