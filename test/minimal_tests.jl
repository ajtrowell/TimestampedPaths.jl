import TimestampedPaths
const TP = TimestampedPaths

@testset "Minimal PathGenerator workflow" begin

    mktempdir() do temp_root
        cd(temp_root) do
            config = TP.Config(root_dir="./test_data", extension=".beve")
            path_generator = TP.PathGenerator(config)
            filename = path_generator(tag="file_stem")

            expected_root = joinpath(temp_root, "test_data")
            @test config.root_dir == expected_root

            open(filename, "w") do io
                write(io, "sample beve data")
            end

            @test isfile(filename)
            @test occursin("file_stem", basename(filename))
            @test startswith(filename, expected_root)
            @test isdir(dirname(filename))

            files_in_directory = readdir(dirname(filename))
            @test basename(filename) in files_in_directory

            rm(filename)
            @test !isfile(filename)

            rm(config.root_dir; recursive=true, force=true)
            @test !isdir(config.root_dir)
        end
    end
end
