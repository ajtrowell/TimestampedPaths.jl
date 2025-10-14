using Dates
using Test

using TimestampedPaths

@testset "Config placeholder parsing" begin
    mktempdir() do root
        config = Config(root_dir=root,
                        timestamp_template="yyyy-mm-dd_HHMMSS",
                        intermediate_template="run_##",
                        extension=".dat",
                        suffix="host",
                        start_index=1)
        @test config.subfolder_template === nothing
        @test config.index_width == 2
        @test config.intermediate_prefix == "run_"
        @test config.intermediate_suffix == ""
        @test config.extension == ".dat"
    end
end

@testset "Config mutability" begin
    mktempdir() do root
        now = DateTime(2024, 1, 1, 12, 0, 0)
        config = Config(root_dir=root,
                        timestamp_template="yyyy-mm-dd_HHMMSS",
                        intermediate_template="run_##",
                        extension=".dat",
                        now=now)

        set_intermediate_template!(config, "phase_##"; now=now)
        @test config.intermediate_template == "phase_##"
        @test config.index_width == 2
        @test config.intermediate_prefix == "phase_"
        @test endswith(current_collection_path(config), joinpath("2024-01-01", "phase_01"))

        set_subfolder_template!(config, "yyyymmdd"; now=now)
        @test config.subfolder_template == "yyyymmdd"
        @test endswith(current_collection_path(config), joinpath("20240101", "phase_01"))

        set_subfolder_template!(config, nothing; now=now)
        @test config.subfolder_template === nothing
        @test endswith(current_collection_path(config), joinpath("2024-01-01", "phase_01"))

        set_intermediate_template!(config, "special"; now=now)
        @test config.index_width === nothing
        @test config.placeholder_range === nothing
        @test endswith(current_collection_path(config), joinpath("2024-01-01", "special"))

        set_intermediate_template!(config, nothing; now=now)
        set_subfolder_template!(config, nothing; now=now)
        @test config.intermediate_template === nothing
        @test config.index_width === nothing
        @test !occursin("special", current_collection_path(config))
        @test current_collection_path(config) == joinpath(config.root_dir, "2024-01-01")

        @test_throws ArgumentError set_intermediate_template!(config, "phase_##"; index_width=3, now=now)
        @test_throws ArgumentError set_intermediate_template!(config, nothing; index_width=2, now=now)

        set_intermediate_template!(config, "batch_###"; index_width=3, now=now)
        @test endswith(current_collection_path(config), joinpath("2024-01-01", "batch_001"))
    end
end

@testset "Subfolder template override" begin
    mktempdir() do root
        now = DateTime(2024, 5, 25, 10, 30, 0)
        config = Config(root_dir=root,
                        timestamp_template="yyyy-mm-dd_HHMMSS",
                        subfolder_template="yyyymmdd",
                        intermediate_template="run_##",
                        extension="bin",
                        start_index=1,
                        now=now)

        path = current_collection_path(config)
        @test endswith(path, joinpath("20240525", "run_01"))
        @test !occursin("2024-05-25", path)

        ensured = ensure_collection_path!(config; now=now)
        @test ensured == path
        @test isdir(ensured)
    end
end

@testset "Path generation and directory lifecycle" begin
    mktempdir() do root
        now = DateTime(2024, 5, 25, 10, 30, 0)
        config = Config(root_dir=root,
                        timestamp_template="yyyy-mm-dd_HHMMSS",
                        intermediate_template="run_##",
                        extension="bin",
                        suffix=nothing,
                        start_index=1,
                        now=now)

        @test config.state.current == 1
        @test config.state.highest_seen == 0

        path = current_collection_path(config)
        @test endswith(path, joinpath("2024-05-25", "run_01"))

        ensured = ensure_collection_path!(config; now=now)
        @test ensured == path
        @test isdir(ensured)

        file_path = get_file_path(config; tag="primary", now=now)
        @test dirname(file_path) == path
        @test endswith(file_path, ".bin")
        @test occursin("2024-05-25_103000", basename(file_path))

        increment_index!(config)
        @test config.state.current == 2
        next_path = current_collection_path(config)
        @test endswith(next_path, "run_02")
    end
end

@testset "Path generator callable" begin
    mktempdir() do root
        now = DateTime(2024, 8, 15, 8, 0, 0)
        config = Config(root_dir=root,
                        timestamp_template="yyyy-mm-dd_HHMMSS",
                        intermediate_template="batch_##",
                        extension=".bin",
                        start_index=1,
                        now=now)

        generator = PathGenerator(config)

        first_path = generator(now=now)
        @test isdir(dirname(first_path))
        @test occursin("2024-08-15", first_path)

        second_path = generator(tag="processed", now=now + Minute(5))
        @test dirname(second_path) == dirname(first_path)
        @test occursin("processed", basename(second_path))
        @test config.state.current == 1  # generator does not advance index automatically

        next_dir = create_next_output_directory!(config; now=now + Minute(10))
        @test isdir(next_dir)
        third_path = generator(now=now + Minute(11))
        @test dirname(third_path) == next_dir
    end
end

@testset "Multi-system coordination" begin
    mktempdir() do root
        start_time = DateTime(2024, 6, 1, 9, 0, 0)
        primary = Config(root_dir=root,
                         timestamp_template="yyyy-mm-dd_HHMMSS",
                         intermediate_template="col_##",
                         extension=".dat",
                         start_index=1,
                         now=start_time)
        secondary = Config(root_dir=root,
                           timestamp_template="yyyy-mm-dd_HHMMSS",
                           intermediate_template="col_##",
                           extension=".dat",
                           start_index=1,
                           now=start_time)

        first_dir = create_next_output_directory!(primary; now=start_time)
        @test isdir(first_dir)

        sync_to_latest_index!(secondary; now=start_time)
        @test secondary.state.current == 1

        file_primary = get_file_path(primary; now=start_time + Minute(1))
        file_secondary = get_file_path(secondary; now=start_time + Minute(2))
        @test dirname(file_primary) == dirname(file_secondary)

        later = start_time + Minute(10)
        second_dir = create_next_output_directory!(primary; now=later)
        @test isdir(second_dir)
        @test endswith(second_dir, "col_02")

        # Secondary attempts the same creation and converges on the existing folder.
        second_dir_secondary = create_next_output_directory!(secondary; now=later)
        @test second_dir_secondary == second_dir
        @test secondary.state.current == 2
    end
end

@testset "Date rollover" begin
    mktempdir() do root
        late = DateTime(2024, 7, 31, 23, 55, 0)
        config = Config(root_dir=root,
                        timestamp_template="yyyy-mm-dd_HHMMSS",
                        intermediate_template="seq_##",
                        extension=".log",
                        start_index=1,
                        now=late)

        create_next_output_directory!(config; now=late)
        @test config.state.current == 1

        next_day = late + Day(1)
        refresh_index!(config; now=next_day, force=false)
        @test config.state.active_date == Date(next_day)
        @test config.state.current == 1
        @test config.state.highest_seen == 0

        rollover_path = ensure_collection_path!(config; now=next_day)
        @test occursin("2024-08-01", rollover_path)
    end
end
