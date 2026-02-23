module GeoExplorerOverpassAPIExt

using GeoExplorer
using OverpassAPI
using OverpassAPI: OQL
import GeoExplorer: add_overpass_controls!, wgs84_to_webmercator, webmercator_to_wgs84
using GLMakie, Extents

const DEFAULT_FEATURES = [
    OverpassFeature("Roads",     OQL.way["highway"],            :gray50,    :lines),
    OverpassFeature("Buildings", OQL.way["building"],            :orange,    :poly),
    OverpassFeature("Water",     OQL.way["natural" => "water"],  :dodgerblue, :poly),
    OverpassFeature("Parks",     OQL.way["leisure" => "park"],   :green,     :poly),
    OverpassFeature("Amenities", OQL.node["amenity"],            :red,       :scatter),
]

#-----------------------------------------------------------------------------# Helpers

"""Get the visible extent as a WGS84 Extents.Extent."""
function visible_extent(app::GeoExplorerApp)
    limits = app.map_axis.finallimits[]
    xmin, ymin = limits.origin
    xmax = xmin + limits.widths[1]
    ymax = ymin + limits.widths[2]
    lon_min, lat_min = webmercator_to_wgs84(xmin, ymin)
    lon_max, lat_max = webmercator_to_wgs84(xmax, ymax)
    return Extents.Extent(X=(lon_min, lon_max), Y=(lat_min, lat_max))
end

"""Fetch and plot a single OverpassFeature, returning the plot objects."""
function fetch_and_plot!(app::GeoExplorerApp, feature::OverpassFeature, bbox::Extents.Extent)
    resp = OverpassAPI.query(feature.query; bbox, out=:geom)
    plots = []

    if feature.plot_type == :scatter
        # Plot nodes as scatter points
        ns = OverpassAPI.nodes(resp)
        isempty(ns) && return plots
        coords = [wgs84_to_webmercator(n.lon, n.lat) for n in ns]
        xs = [c[1] for c in coords]
        ys = [c[2] for c in coords]
        p = scatter!(app.map_axis, xs, ys; color=feature.color, markersize=6)
        push!(plots, p)

    elseif feature.plot_type == :lines
        ws = OverpassAPI.ways(resp)
        for w in ws
            isempty(w.geometry) && continue
            coords = [wgs84_to_webmercator(ll.lon, ll.lat) for ll in w.geometry]
            xs = [c[1] for c in coords]
            ys = [c[2] for c in coords]
            p = lines!(app.map_axis, xs, ys; color=feature.color, linewidth=1)
            push!(plots, p)
        end

    elseif feature.plot_type == :poly
        ws = OverpassAPI.ways(resp)
        for w in ws
            isempty(w.geometry) && continue
            coords = [wgs84_to_webmercator(ll.lon, ll.lat) for ll in w.geometry]
            p = poly!(app.map_axis, coords; color=(feature.color, 0.3), strokecolor=feature.color, strokewidth=1)
            push!(plots, p)
        end
    end

    return plots
end

#-----------------------------------------------------------------------------# add_overpass_controls!

function add_overpass_controls!(app::GeoExplorerApp; features=DEFAULT_FEATURES)
    figure = app.figure

    # State tracking per feature
    feature_plots = Dict{String, Vector{Any}}()   # name => plot objects
    feature_active = Dict{String, Observable{Bool}}()

    for f in features
        feature_plots[f.name] = []
        feature_active[f.name] = Observable(false)
    end

    # UI: Bottom-left panel
    panel = figure[1, 1] = GridLayout(tellwidth=false, tellheight=false, halign=:left, valign=:bottom, alignmode=Outside(10))
    bg = Box(panel[1:length(features)+1, 1], color=(:white, 0.9), strokecolor=:gray60, strokewidth=1)

    btn_style = (; fontsize=11, height=24, strokewidth=1, strokecolor=:gray60)

    buttons = Dict{String, Button}()
    for (i, f) in enumerate(features)
        btn = Button(panel[i, 1]; label=f.name, buttoncolor=:white, btn_style...)
        buttons[f.name] = btn
        translate!(btn.blockscene, Vec3f(0, 0, 9000))
    end

    refresh_btn = Button(panel[length(features)+1, 1]; label="Refresh", buttoncolor=:lightyellow, btn_style...)
    translate!(refresh_btn.blockscene, Vec3f(0, 0, 9000))
    translate!(bg.blockscene, Vec3f(0, 0, 9000))

    rowgap!(panel, 2)

    # Toggle behavior for each feature button
    for f in features
        on(buttons[f.name].clicks) do _
            is_active = feature_active[f.name][]

            if is_active
                # Hide: remove plots
                for p in feature_plots[f.name]
                    try delete!(app.map_axis, p) catch end
                end
                empty!(feature_plots[f.name])
                feature_active[f.name][] = false
                buttons[f.name].buttoncolor[] = :white
            else
                # Fetch and show
                buttons[f.name].buttoncolor[] = :lightgray
                bbox = visible_extent(app)
                try
                    new_plots = fetch_and_plot!(app, f, bbox)
                    feature_plots[f.name] = new_plots
                    feature_active[f.name][] = true
                    buttons[f.name].buttoncolor[] = (f.color, 0.3)
                catch e
                    @warn "Overpass query failed for $(f.name)" exception=e
                    buttons[f.name].buttoncolor[] = :white
                end
            end
        end
    end

    # Refresh: re-fetch all active features for current extent
    on(refresh_btn.clicks) do _
        bbox = visible_extent(app)
        for f in features
            if feature_active[f.name][]
                # Remove old plots
                for p in feature_plots[f.name]
                    try delete!(app.map_axis, p) catch end
                end
                empty!(feature_plots[f.name])
                # Fetch new
                try
                    new_plots = fetch_and_plot!(app, f, bbox)
                    feature_plots[f.name] = new_plots
                catch e
                    @warn "Overpass refresh failed for $(f.name)" exception=e
                    feature_active[f.name][] = false
                    buttons[f.name].buttoncolor[] = :white
                end
            end
        end
    end

    return (; panel, buttons, refresh=refresh_btn, feature_active)
end

end # module
