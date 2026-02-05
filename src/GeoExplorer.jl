module GeoExplorer

using Reexport

using GeoMakie, Tyler, GLMakie, GeoJSON, Shapefile, Extents, Proj, Colors, OrderedCollections, Printf

import GeoInterface as GI
import Tyler.TileProviders

#-----------------------------------------------------------------------------# Exports
export
    # App
    GeoExplorerApp,
    explore,
    plot_geometry!,

    # UI
    add_map_nav!,

    # Navigation
    goto!,
    zoom!,
    reset_view!,
    set_center!,

    # Providers
    set_provider!,
    available_providers

#-----------------------------------------------------------------------------# Includes
include("app.jl")

end # module
