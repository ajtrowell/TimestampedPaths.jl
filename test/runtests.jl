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
        config = Config(root_dir=root,
                        timestamp_template="yyyy-mm-dd_HHMMSS",
                        intermediate_template="run_##",
                        extension=".dat")

        set_intermediate_template!(config, "phase_##")
        @test config.intermediate_template == "phase_##"
        @test config.index_width == 2
        @test config.intermediate_prefix == "phase_"

        now = DateTime(2024, 1, 1, 12, 0, 0)
        set_subfolder_template!(config, "yyyymmdd")
        state = IndexState(config; now=now)
        @test endswith(current_collection_path(config, state), joinpath("20240101", "phase_01"))

        set_subfolder_template!(config, nothing)
        state = IndexState(config; now=now)
        @test endswith(current_collection_path(config, state), joinpath("2024-01-01", "phase_01"))

        set_intermediate_template!(config, "special")
        state = IndexState(config; now=now)
        @test config.index_width === nothing
        @test config.placeholder_range === nothing
        @test endswith(current_collection_path(config, state), joinpath("2024-01-01", "special"))

        set_intermediate_template!(config, nothing)
        set_subfolder_template!(config, nothing)
        state = IndexState(config; now=now)
        @test config.intermediate_template === nothing
        @test config.index_width === nothing
        @test !occursin("special", current_collection_path(config, state))
        @test current_collection_path(config, state) == joinpath(config.root_dir, "2024-01-01")

        @test_throws ArgumentError set_intermediate_template!(config, "phase_##"; index_width=3)
        @test_throws ArgumentError set_intermediate_template!(config, nothing; index_width=2)

        set_intermediate_template!(config, "batch_###"; index_width=3)
        state = IndexState(config; now=now)
        @test endswith(current_collection_path(config, state), joinpath("2024-01-01", "batch_001"))
    end
end

@testset "Subfolder template override" begin
    mktempdir() do root
        config = Config(root_dir=root,
                        timestamp_template="yyyy-mm-dd_HHMMSS",
                        subfolder_template="yyyymmdd",
                        intermediate_template="run_##",
                        extension="bin",
                        start_index=1)
        now = DateTime(2024, 5, 25, 10, 30, 0)
        state = IndexState(config; now=now)

        path = current_collection_path(config, state)
        @test endswith(path, joinpath("20240525", "run_01"))
        @test !occursin("2024-05-25", path)

        ensured = ensure_collection_path!(config, state; now=now)
        @test ensured == path
        @test isdir(ensured)
    end
end

@testset "Path generation and directory lifecycle" begin
    mktempdir() do root
        config = Config(root_dir=root,
                        timestamp_template="yyyy-mm-dd_HHMMSS",
                        intermediate_template="run_##",
                        extension="bin",
                        suffix=nothing,
                        start_index=1)
        now = DateTime(2024, 5, 25, 10, 30, 0)
        state = IndexState(config; now=now)

        @test state.current == 1
        @test state.highest_seen == 0

        path = current_collection_path(config, state)
        @test endswith(path, joinpath("2024-05-25", "run_01"))

        ensured = ensure_collection_path!(config, state; now=now)
        @test ensured == path
        @test isdir(ensured)

        file_path = get_file_path(config, state; tag="primary", now=now)
        @test dirname(file_path) == path
        @test endswith(file_path, ".bin")
        @test occursin("2024-05-25_103000", basename(file_path))

        increment_index!(state)
        @test state.current == 2
        next_path = current_collection_path(config, state)
        @test endswith(next_path, "run_02")
    end
end

@testset "Multi-system coordination" begin
    mktempdir() do root
        config = Config(root_dir=root,
                        timestamp_template="yyyy-mm-dd_HHMMSS",
                        intermediate_template="col_##",
                        extension=".dat",
                        start_index=1)
        start_time = DateTime(2024, 6, 1, 9, 0, 0)
        primary = IndexState(config; now=start_time)

        first_dir = create_next_output_directory!(config, primary; now=start_time)
        @test isdir(first_dir)

        secondary = IndexState(config; now=start_time)
        sync_to_latest_index!(secondary, config; now=start_time)
        @test secondary.current == 1

        file_primary = get_file_path(config, primary; now=start_time + Minute(1))
        file_secondary = get_file_path(config, secondary; now=start_time + Minute(2))
        @test dirname(file_primary) == dirname(file_secondary)

        later = start_time + Minute(10)
        second_dir = create_next_output_directory!(config, primary; now=later)
        @test isdir(second_dir)
        @test endswith(second_dir, "col_02")

        # Secondary attempts the same creation and converges on the existing folder.
        second_dir_secondary = create_next_output_directory!(config, secondary; now=later)
        @test second_dir_secondary == second_dir
        @test secondary.current == 2
    end
end

@testset "Date rollover" begin
    mktempdir() do root
        config = Config(root_dir=root,
                        timestamp_template="yyyy-mm-dd_HHMMSS",
                        intermediate_template="seq_##",
                        extension=".log",
                        start_index=1)
        late = DateTime(2024, 7, 31, 23, 55, 0)
        state = IndexState(config; now=late)

        create_next_output_directory!(config, state; now=late)
        @test state.current == 1

        next_day = late + Day(1)
        refresh_index!(state, config; now=next_day, force=false)
        @test state.active_date == Date(next_day)
        @test state.current == 1
        @test state.highest_seen == 0

        rollover_path = ensure_collection_path!(config, state; now=next_day)
        @test occursin("2024-08-01", rollover_path)
    end
end
