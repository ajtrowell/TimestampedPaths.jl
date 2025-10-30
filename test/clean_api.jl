
# Tests for new api
@testset "New API"
    generator::NamerInterface = NamerInterface()
    generator.config.root_dir = "."
    generator.config.pre_tag = "pre_tag_"
    generator.config.post_tag = "post_tag_.dat"
    new_path = generator.generate_path("this_tag")
    println("new_path:   $(new_path)")
end