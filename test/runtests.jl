using FileNamer
using Test

@testset "FileNamer.jl" begin
    @test greet("world") == "Hello, world!"
end
