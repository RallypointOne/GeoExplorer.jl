using BenchmarkTools, JSON3, Dates
using GeoExplorer

#--------------------------------------------------------------------------------# Benchmark Suite
#--------------------------------------------------------------------------------
suite = BenchmarkGroup()

suite["coordinate_conversion"] = BenchmarkGroup()
suite["coordinate_conversion"]["wgs84_to_webmercator"] = @benchmarkable GeoExplorer.wgs84_to_webmercator(-105.27, 40.01)
suite["coordinate_conversion"]["webmercator_to_wgs84"] = @benchmarkable GeoExplorer.webmercator_to_wgs84(-11717528.0, 4865942.0)

#--------------------------------------------------------------------------------# Run Benchmarks
#--------------------------------------------------------------------------------
println("Running benchmarks...")
results = run(suite, verbose=true)

#--------------------------------------------------------------------------------# Collect Results
#--------------------------------------------------------------------------------
function collect_results(group::BenchmarkGroup, prefix="")
    entries = []
    for (key, val) in group
        name = isempty(prefix) ? string(key) : "$prefix/$key"
        if val isa BenchmarkGroup
            append!(entries, collect_results(val, name))
        else
            t = median(val)
            push!(entries, (;
                name,
                time_ns = t.time,
                memory_bytes = t.memory,
                allocs = t.allocs,
            ))
        end
    end
    return entries
end

benchmarks = collect_results(results)

output = (;
    julia_version = string(VERSION),
    cpu = Sys.cpu_info()[1].model,
    timestamp = Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ"),
    benchmarks,
)

outfile = joinpath(@__DIR__, "results.json")
open(outfile, "w") do io
    JSON3.pretty(io, output)
end

println("Results written to $outfile")
