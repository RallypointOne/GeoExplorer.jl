#-----------------------------------------------------------------------------# GeoExplorerApp
"""
    GeoExplorerApp

Main application struct for GeoExplorer. Contains the figure, map axis, and all UI components.

# Fields
- `figure::Figure` - The main GLMakie figure
- `map_axis::Axis` - The Tyler map axis
- `map::Tyler.Map` - The Tyler map object
- `zoom_level::Observable{Int}` - Current zoom level
- `provider` - Current tile provider
- `extent` - Original extent (for reset_view!)
- `cursor_pos` - Observable cursor position (lon, lat)
"""
mutable struct GeoExplorerApp
    figure::Figure
    map_axis::Union{Axis, GeoAxis}
    map::Tyler.Map
    zoom_level::Observable{Int}
    provider
    extent::Extents.Extent
    cursor_pos::Observable{Tuple{Float64, Float64}}
end

#-----------------------------------------------------------------------------# Coordinate conversion helpers
const WEB_MERCATOR_MAX = 20037508.34

"""Convert WGS84 (lon, lat) to Web Mercator (x, y)."""
function wgs84_to_webmercator(lon, lat)
    x = lon * WEB_MERCATOR_MAX / 180.0
    y = log(tan((90.0 + lat) * π / 360.0)) * WEB_MERCATOR_MAX / π
    return (x, y)
end

"""Convert Web Mercator (x, y) to WGS84 (lon, lat)."""
function webmercator_to_wgs84(x, y)
    lon = x * 180.0 / WEB_MERCATOR_MAX
    lat = atan(sinh(y * π / WEB_MERCATOR_MAX)) * 180.0 / π
    return (lon, lat)
end

#-----------------------------------------------------------------------------# explore
"""
    explore(; extent=Extents.Extent(X=(-125.0, -65.0), Y=(24.0, 50.0)), provider=TileProviders.OpenStreetMap())

Launch the GeoExplorer application.

# Keyword Arguments
- `extent`: Initial map extent (default: Continental US)
- `provider`: Tile provider for basemap (default: OpenStreetMap)

# Returns
- `GeoExplorerApp`: The application instance

# Example
```julia
app = explore()  # Opens map of Continental US with OpenStreetMap tiles
app = explore(provider=TileProviders.Esri(:WorldImagery))  # Satellite imagery
app = explore(extent=Extents.Extent(X=(-0.1, 0.1), Y=(51.4, 51.6)))  # London
```
"""
function explore(;
        extent = Extents.Extent(X=(-125.0, -65.0), Y=(24.0, 50.0)),  # Continental US
        provider = TileProviders.OpenStreetMap(),
        figure = Figure(size=(1200, 800))
    )
    map_axis = Axis(figure[1,1], panbutton=Mouse.left)
    map = Tyler.Map(extent; provider=provider, figure, axis=map_axis, scale=0.5)
    hidedecorations!(map_axis)
    deregister_interaction!(map_axis, :rectanglezoom)

    app = GeoExplorerApp(figure, map_axis, map, Observable(1), provider, extent, Observable((0.0, 0.0)))

    # Status display in top left corner
    status_layout = figure[1, 1] = GridLayout(tellwidth=false, tellheight=false, halign=:left, valign=:top, alignmode=Outside(8))
    Box(status_layout[1:2, 1], color=(:white, 0.9), strokecolor=:gray60, strokewidth=1)
    cursor_pos_str(x) = Printf.@sprintf("(%.4f°, %.4f°)", x[1], x[2])
    Label(status_layout[1, 1], @lift(cursor_pos_str($(app.cursor_pos))), fontsize=12, color=:gray30, halign=:left, padding=(6, 6, 4, 0))
    Label(status_layout[2, 1], @lift("Zoom: $($(app.map.zoom))"), fontsize=12, color=:gray30, halign=:left, padding=(6, 6, 0, 4))
    rowgap!(status_layout, 0)
    add_map_nav!(app)
    setup_mouse_cursor!(app)
    setup_keyboard_shortcuts!(app)
    display(figure)

    return app
end

#-----------------------------------------------------------------------------# explore(geometry)
"""
    explore(geometry; padding=0.1, kw...)

Launch the GeoExplorer application with a geometry automatically plotted.

# Arguments
- `geometry`: Any GeoInterface-compatible geometry (Point, LineString, Polygon, etc.)

# Keyword Arguments
- `padding`: Fractional padding around the geometry extent (default: 0.1 = 10%)
- `kw...`: Additional keyword arguments passed to `explore(; kw...)`

# Example
```julia
using GeoJSON
geom = GeoJSON.read("path/to/file.geojson")
app = explore(geom)
```
"""
function explore(geometry; padding=0.1, kw...)
    ext = GI.extent(geometry)
    # Add padding to extent
    xpad = (ext.X[2] - ext.X[1]) * padding
    ypad = (ext.Y[2] - ext.Y[1]) * padding
    # Handle point geometries (zero extent)
    xpad = xpad == 0 ? 0.01 : xpad
    ypad = ypad == 0 ? 0.01 : ypad
    padded_extent = Extents.Extent(
        X = (ext.X[1] - xpad, ext.X[2] + xpad),
        Y = (ext.Y[1] - ypad, ext.Y[2] + ypad)
    )

    app = explore(; extent=padded_extent, kw...)
    plot_geometry!(app, geometry)
    return app
end

#-----------------------------------------------------------------------------# plot_geometry!
"""
    plot_geometry!(app::GeoExplorerApp, geometry; kw...)

Plot a GeoInterface-compatible geometry on the map.
Dispatches to specific plot methods based on geometry type.
"""
function plot_geometry!(app::GeoExplorerApp, geometry; kw...)
    trait = GI.trait(geometry)
    plot_geometry!(app, trait, geometry; kw...)
end

# Point
function plot_geometry!(app::GeoExplorerApp, ::GI.PointTrait, geom; color=:red, markersize=10, kw...)
    x, y = wgs84_to_webmercator(GI.x(geom), GI.y(geom))
    scatter!(app.map_axis, [x], [y]; color, markersize, kw...)
end

# MultiPoint
function plot_geometry!(app::GeoExplorerApp, ::GI.MultiPointTrait, geom; color=:red, markersize=10, kw...)
    coords = [wgs84_to_webmercator(GI.x(p), GI.y(p)) for p in GI.getpoint(geom)]
    xs = [c[1] for c in coords]
    ys = [c[2] for c in coords]
    scatter!(app.map_axis, xs, ys; color, markersize, kw...)
end

# LineString
function plot_geometry!(app::GeoExplorerApp, ::GI.LineStringTrait, geom; color=:blue, linewidth=2, kw...)
    coords = [wgs84_to_webmercator(GI.x(p), GI.y(p)) for p in GI.getpoint(geom)]
    xs = [c[1] for c in coords]
    ys = [c[2] for c in coords]
    lines!(app.map_axis, xs, ys; color, linewidth, kw...)
end

# MultiLineString
function plot_geometry!(app::GeoExplorerApp, ::GI.MultiLineStringTrait, geom; kw...)
    for line in GI.getgeom(geom)
        plot_geometry!(app, GI.LineStringTrait(), line; kw...)
    end
end

# Polygon
function plot_geometry!(app::GeoExplorerApp, ::GI.PolygonTrait, geom; color=(:blue, 0.3), strokecolor=:blue, strokewidth=2, kw...)
    # Get exterior ring
    exterior = GI.getexterior(geom)
    coords = [wgs84_to_webmercator(GI.x(p), GI.y(p)) for p in GI.getpoint(exterior)]
    poly!(app.map_axis, coords; color, strokecolor, strokewidth, kw...)
end

# MultiPolygon
function plot_geometry!(app::GeoExplorerApp, ::GI.MultiPolygonTrait, geom; kw...)
    for polygon in GI.getgeom(geom)
        plot_geometry!(app, GI.PolygonTrait(), polygon; kw...)
    end
end

# GeometryCollection
function plot_geometry!(app::GeoExplorerApp, ::GI.GeometryCollectionTrait, geom; kw...)
    for g in GI.getgeom(geom)
        plot_geometry!(app, g; kw...)
    end
end

# Feature (unwrap to geometry)
function plot_geometry!(app::GeoExplorerApp, ::GI.FeatureTrait, feature; kw...)
    plot_geometry!(app, GI.geometry(feature); kw...)
end

# FeatureCollection
function plot_geometry!(app::GeoExplorerApp, ::GI.FeatureCollectionTrait, fc; kw...)
    for feature in GI.getfeature(fc)
        plot_geometry!(app, feature; kw...)
    end
end

#-----------------------------------------------------------------------------# setup_mouse_cursor!
"""
    setup_mouse_cursor!(app::GeoExplorerApp)

Set up mouse cursor position tracking, converting Web Mercator to lat/lon.
"""
function setup_mouse_cursor!(app::GeoExplorerApp)
    on(events(app.map_axis.scene).mouseposition) do pos
        # Convert screen position to data coordinates (Web Mercator)
        data_pos = mouseposition(app.map_axis.scene)
        if !isnothing(data_pos)
            x, y = data_pos
            lon, lat = webmercator_to_wgs84(x, y)
            # Clamp latitude to valid range
            lat = clamp(lat, -85.0, 85.0)
            app.cursor_pos[] = (lon, lat)
        end
    end
end

#-----------------------------------------------------------------------------# setup_keyboard_shortcuts!
"""
    setup_keyboard_shortcuts!(app::GeoExplorerApp)

Set up keyboard shortcuts for navigation.
"""
function setup_keyboard_shortcuts!(app::GeoExplorerApp)
    on(events(app.figure.scene).keyboardbutton) do event
        if event.action == Keyboard.press || event.action == Keyboard.repeat
            handle_keyboard!(app, event.key)
        end
    end
end

#-----------------------------------------------------------------------------# handle_keyboard!
"""
    handle_keyboard!(app::GeoExplorerApp, key)

Handle keyboard input for the GeoExplorer application.
"""
function handle_keyboard!(app::GeoExplorerApp, key)
    ax = app.map_axis
    limits = ax.finallimits[]
    center = limits.origin .+ limits.widths ./ 2
    pan_amount = limits.widths .* 0.1

    if key == Keyboard.up
        # Pan up
        new_center = center .+ (0, pan_amount[2])
        set_center!(app, new_center)
    elseif key == Keyboard.down
        # Pan down
        new_center = center .- (0, pan_amount[2])
        set_center!(app, new_center)
    elseif key == Keyboard.left
        # Pan left
        new_center = center .- (pan_amount[1], 0)
        set_center!(app, new_center)
    elseif key == Keyboard.right
        # Pan right
        new_center = center .+ (pan_amount[1], 0)
        set_center!(app, new_center)
    elseif key == Keyboard.equal || key == Keyboard.kp_add
        # Zoom in
        zoom!(app, 0.8)
    elseif key == Keyboard.minus || key == Keyboard.kp_subtract
        # Zoom out
        zoom!(app, 1.25)
    elseif key == Keyboard.home
        # Reset to world view
        reset_view!(app)
    end
end

#-----------------------------------------------------------------------------# Navigation functions
"""
    set_center!(app::GeoExplorerApp, center)

Set the map center to the given coordinates (in Web Mercator).
"""
function set_center!(app::GeoExplorerApp, center)
    ax = app.map_axis
    limits = ax.finallimits[]
    half_width = limits.widths ./ 2
    new_origin = center .- half_width
    ax.finallimits[] = Rect2f(new_origin, limits.widths)
end

"""
    zoom!(app::GeoExplorerApp, factor)

Zoom the map by the given factor (< 1 zooms in, > 1 zooms out).
"""
function zoom!(app::GeoExplorerApp, factor)
    ax = app.map_axis
    limits = ax.finallimits[]
    center = limits.origin .+ limits.widths ./ 2
    new_widths = limits.widths .* factor
    new_origin = center .- new_widths ./ 2
    ax.finallimits[] = Rect2f(new_origin, new_widths)
end

"""
    reset_view!(app::GeoExplorerApp)

Reset the map view to the original extent.
"""
function reset_view!(app::GeoExplorerApp)
    ext = app.extent
    xmin, ymin = wgs84_to_webmercator(ext.X[1], ext.Y[1])
    xmax, ymax = wgs84_to_webmercator(ext.X[2], ext.Y[2])
    app.map_axis.finallimits[] = Rect2f(xmin, ymin, xmax - xmin, ymax - ymin)
end

"""
    goto!(app::GeoExplorerApp, lon, lat; zoom=10)

Navigate to a specific longitude/latitude location with optional zoom level.
"""
function goto!(app::GeoExplorerApp, lon, lat; zoom=10)
    # Convert lon/lat to Web Mercator
    x, y = wgs84_to_webmercator(lon, lat)

    # Calculate extent based on zoom level
    # Approximate meters per pixel at equator for given zoom
    meters_per_pixel = 40075016.686 / (256 * 2^zoom)
    half_extent = meters_per_pixel * 600  # ~1200 pixels wide

    app.map_axis.finallimits[] = Rect2f(x - half_extent, y - half_extent, 2*half_extent, 2*half_extent)
end


#-----------------------------------------------------------------------------# add_map_nav!
"""
    add_map_nav!(app::GeoExplorerApp; kw...)

Add navigation buttons (zoom in, zoom out, home, help) to the map.

# Keyword Arguments
- `buttonsize`: Size of each button (default: 30)
- `fontsize`: Font size for button labels (default: 18)
- `halign`: Horizontal alignment (default: :right)
- `valign`: Vertical alignment (default: :bottom)

# Returns
- `NamedTuple` with `layout`, `zoom_in`, `zoom_out`, `home`, `help` buttons
"""
function add_map_nav!(app::GeoExplorerApp;
    buttonsize = 30,
    fontsize = 18,
    halign = :right,
    valign = :bottom
)
    figure = app.figure
    map_axis = app.map_axis
    extent = app.extent

    # Create layout overlay on map
    layout = figure[1, 1] = GridLayout(tellwidth=false, tellheight=false, halign=halign, valign=valign, alignmode=Outside(10))

    # Create buttons
    btn_style = (; fontsize=fontsize, width=buttonsize, height=buttonsize, strokewidth=1, strokecolor=:gray60)

    # Zoom buttons grouped together (tighter spacing)
    zoom_layout = layout[1, 1] = GridLayout()
    zoom_in = Button(zoom_layout[1, 1]; label="+", btn_style...)
    zoom_out = Button(zoom_layout[2, 1]; label="−", btn_style...)
    rowgap!(zoom_layout, 0)

    # Other buttons
    home = Button(layout[2, 1]; label="⌂", btn_style...)
    help = Button(layout[3, 1]; label="?", btn_style...)

    rowgap!(layout, 8)

    # Create help box (initially hidden)
    help_visible = Observable(false)
    help_layout = figure[1, 1] = GridLayout(tellwidth=false, tellheight=false, halign=:right, valign=:bottom)
    help_box = Box(help_layout[1, 1], color=(:white, 0.95), strokecolor=:gray70, strokewidth=1, alignmode=Outside(50), visible=false)
    help_content = GridLayout(help_layout[1, 1], alignmode=Outside(58))
    mono = "TeX Gyre Cursor"  # Monospace font bundled with Makie
    help_labels = [
        Label(help_content[1, 1], "Keyboard Shortcuts", fontsize=12, font=:bold, halign=:left, visible=false),
        Label(help_content[2, 1], "Arrow Keys    Pan", fontsize=10, font=mono, halign=:left, color=:gray30, visible=false),
        Label(help_content[3, 1], "+/-           Zoom", fontsize=10, font=mono, halign=:left, color=:gray30, visible=false),
        Label(help_content[4, 1], "Home          Reset", fontsize=10, font=mono, halign=:left, color=:gray30, visible=false),
        Label(help_content[5, 1], "Scroll        Zoom", fontsize=10, font=mono, halign=:left, color=:gray30, visible=false),
        Label(help_content[6, 1], "Drag          Pan", fontsize=10, font=mono, halign=:left, color=:gray30, visible=false),
    ]
    rowgap!(help_content, 2)

    # Connect visibility to help_visible observable
    on(help_visible) do vis
        help_box.visible[] = vis
        for label in help_labels
            label.visible[] = vis
        end
    end

    # Wire up button handlers
    on(zoom_in.clicks) do _
        limits = map_axis.finallimits[]
        center = limits.origin .+ limits.widths ./ 2
        new_widths = limits.widths .* 0.8
        new_origin = center .- new_widths ./ 2
        map_axis.finallimits[] = Rect2f(new_origin, new_widths)
    end

    on(zoom_out.clicks) do _
        limits = map_axis.finallimits[]
        center = limits.origin .+ limits.widths ./ 2
        new_widths = limits.widths .* 1.25
        new_origin = center .- new_widths ./ 2
        map_axis.finallimits[] = Rect2f(new_origin, new_widths)
    end

    on(home.clicks) do _
        xmin, ymin = wgs84_to_webmercator(extent.X[1], extent.Y[1])
        xmax, ymax = wgs84_to_webmercator(extent.X[2], extent.Y[2])
        map_axis.finallimits[] = Rect2f(xmin, ymin, xmax - xmin, ymax - ymin)
    end

    on(help.clicks) do _
        help_visible[] = !help_visible[]
    end

    return (; layout, zoom_in, zoom_out, home, help)
end

#-----------------------------------------------------------------------------# Tile provider helpers
"""
    set_provider!(app::GeoExplorerApp, provider)

Change the basemap tile provider.

Note: This currently requires restarting the application as Tyler
doesn't support dynamic provider changes.
"""
function set_provider!(app::GeoExplorerApp, provider)
    @warn "Changing tile provider requires restarting the application. Use explore(provider=...) instead."
end

"""
    available_providers()

List available tile providers.

# Example
```julia
providers = available_providers()
app = explore(provider=providers[2].second)  # Use Esri WorldImagery
```
"""
function available_providers()
    return [
        "OpenStreetMap" => TileProviders.OpenStreetMap(),
        "Esri WorldImagery" => TileProviders.Esri(:WorldImagery),
        "Esri WorldTopoMap" => TileProviders.Esri(:WorldTopoMap),
        "Esri WorldStreetMap" => TileProviders.Esri(:WorldStreetMap),
        "CartoDB Positron" => TileProviders.CartoDB(:Positron),
        "CartoDB DarkMatter" => TileProviders.CartoDB(:DarkMatter),
    ]
end
