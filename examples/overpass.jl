using GeoExplorer, OverpassAPI, Extents
using OverpassAPI: OQL

# Launch map centered on Boulder, CO
app = explore(extent=Extents.Extent(X=(-105.30, -105.25), Y=(40.00, 40.03)))

# Add default Overpass controls (Roads, Buildings, Water, Parks, Amenities)
add_overpass_controls!(app)

# Or customize which features appear:
# add_overpass_controls!(app, features=[
#     OverpassFeature("Roads",     OQL.way["highway"],           :gray50,    :lines),
#     OverpassFeature("Buildings", OQL.way["building"],           :orange,    :poly),
#     OverpassFeature("Restaurants", OQL.node["amenity" => "restaurant"], :red, :scatter),
# ])
