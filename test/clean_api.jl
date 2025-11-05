# Tests for new api
@testset "New API" begin
    @testset "basic path generation without collection folders" begin
        mktempdir() do tmp
            cfg = NamerConfig(
                root_dir = tmp,
                pre_tag = "pre_",
                post_tag = "_post.dat",
                collection_folder = nothing,
            )
            ni = NamerInterface(config = cfg)

            path = ni.generate_path("tag")
            dt = ni.state.recent_datetime
            date_folder = Dates.format(dt, ni.config.date_folder)
            file_prefix = Dates.format(dt, ni.config.file_timestamp)

            expected_path =
                joinpath(tmp, date_folder, file_prefix * "pre_" * "tag" * "_post.dat")
            @test path == expected_path
            @test isdir(dirname(path))

            open(path, "w") do io
                write(io, "ok")
            end
            @test isfile(path)
        end
    end

    @testset "cached timestamps reuse previous datetime" begin
        mktempdir() do tmp
            cfg = NamerConfig(root_dir = tmp, pre_tag = "_", post_tag = "")
            ni = NamerInterface(config = cfg)

            first_path = ni.generate_path("a")
            first_dt = ni.state.recent_datetime

            sleep(0.01)
            second_path = ni.generate_path("b")
            second_dt = ni.state.recent_datetime
            @test second_dt >= first_dt

            sleep(0.01)
            cached_path = ni.generate_path_with_cached_timestamp("c")
            cached_dt = ni.state.recent_datetime

            @test cached_dt == second_dt
            @test dirname(cached_path) == dirname(second_path)
            timestamp_prefix = Dates.format(second_dt, ni.config.file_timestamp)
            @test startswith(basename(cached_path), timestamp_prefix)
        end
    end

    @testset "collection folder indexing and rescans" begin
        mktempdir() do tmp
            cfg = NamerConfig(
                root_dir = tmp,
                pre_tag = "",
                post_tag = ".dat",
                collection_folder = "collection",
                width_of_collection_index = 3,
            )

            date_folder_path = TimestampedPaths.get_date_folder_path(cfg)
            mkpath(joinpath(date_folder_path, "collection_001"))
            mkpath(joinpath(date_folder_path, "collection_005"))

            ni = NamerInterface(config = cfg)
            @test ni.state.folder_index == 6

            path = ni.generate_path("sample")
            dt = ni.state.recent_datetime
            date_folder = Dates.format(dt, ni.config.date_folder)
            expected_dir = joinpath(tmp, date_folder, "collection_006")
            @test dirname(path) == expected_dir
            open(path, "w") do io
                write(io, "data")
            end
            @test isfile(path)

            ni.increment_collection_index()
            path_next = ni.generate_path("other")
            dt_next = ni.state.recent_datetime
            date_folder_next = Dates.format(dt_next, ni.config.date_folder)
            expected_dir_next = joinpath(tmp, date_folder_next, "collection_007")
            @test dirname(path_next) == expected_dir_next

            current_date_folder_path = TimestampedPaths.get_date_folder_path(cfg)
            mkpath(joinpath(current_date_folder_path, "collection_010"))
            ni.scan_and_set_next_collection_index()
            @test ni.state.folder_index == 11
        end
    end
end
