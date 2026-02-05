# Example: Adding layers to GeoExplorer
#
# This example demonstrates how to add, toggle, and zoom to layers.

using GeoExplorer, GLMakie

# Launch the explorer with default extent (Continental US)
app = explore()

# Create some sample data in Web Mercator coordinates
# (GeoExplorer's map uses Web Mercator projection)

# Helper to convert lon/lat to Web Mercator
function to_webmercator(lon, lat)
    x = lon * 20037508.34 / 180.0
    y = log(tan((90.0 + lat) * π / 360.0)) * 20037508.34 / π
    return (x, y)
end

# Some US cities (lon, lat)
cities = [
    ("New York", -74.006, 40.7128),
    ("Los Angeles", -118.2437, 34.0522),
    ("Chicago", -87.6298, 41.8781),
    ("Houston", -95.3698, 29.7604),
    ("Phoenix", -112.074, 33.4484),
]

# Convert to Web Mercator
city_coords = [to_webmercator(lon, lat) for (_, lon, lat) in cities]
xs = [c[1] for c in city_coords]
ys = [c[2] for c in city_coords]

# Plot cities and add as a layer
cities_plot = scatter!(app.map_axis, xs, ys; color=:red, markersize=15)
add_layer!(app, "US Cities", cities_plot)

# Add a line connecting the cities
line_plot = lines!(app.map_axis, xs, ys; color=:blue, linewidth=2)
add_layer!(app, "City Connections", line_plot)

# Now you can:
# - Click the layers button (☰) in the top right to see layers
# - Toggle visibility with the checkbox
# - Zoom to a layer with the zoom button (⌖)

# Programmatic layer control:
# toggle_layer!(app, "US Cities")           # Toggle visibility
# zoom_to_layer!(app, "US Cities")          # Zoom to layer extent
# remove_layer!(app, "City Connections")    # Remove a layer
