using BinDeps
using BinDeps: MakeTargets

basedir = dirname(@__FILE__)
prefix = joinpath(basedir, "usr")

cmake_version = v"3.7.2"
base_url = "https://cmake.org/files/v$(cmake_version.major).$(cmake_version.minor)"
@static if is_windows()
    binary_name = "cmake.exe"
else
    binary_name = "cmake"
end

function install_binaries(file_base, file_ext, binary_dir)
    filename = "$(file_base).$(file_ext)"
    url = "$(base_url)/$(filename)"
    binary_path = joinpath(basedir, "downloads", file_base, binary_dir)

    @static if is_windows()
        install_tool = cp
    else
        install_tool = symlink
    end

    install_step = () -> begin
        for file in readdir(binary_path)
            install_tool(joinpath(binary_path, file), 
                         joinpath(prefix, "bin", file))
        end
    end

    (@build_steps begin
        FileRule(joinpath(prefix, "bin", binary_name), 
            (@build_steps begin
                FileDownloader(url, joinpath(basedir, "downloads", filename))
                FileUnpacker(joinpath(basedir, "downloads", filename),
                             joinpath(basedir, "downloads"), 
                             "")
                CreateDirectory(joinpath(prefix, "bin"))
                install_step
            end))
    end)
end

function install_from_source(file_base, file_ext)
    filename = "$(file_base).$(file_ext)"
    url = "$(base_url)/$(filename)"

    (@build_steps begin
        FileRule(joinpath(prefix, "bin", binary_name), 
            (@build_steps begin
                FileDownloader(url, joinpath(basedir, "downloads", filename))
                CreateDirectory(joinpath(basedir, "src"))
                FileUnpacker(joinpath(basedir, "downloads", filename),
                             joinpath(basedir, "src"), 
                             "")
                begin
                    ChangeDirectory(joinpath(basedir, "src", file_base))
                    `./configure --prefix=$(prefix)`
                    MakeTargets()
                    MakeTargets("install")
                end
            end))
    end)
end


process = @static if is_linux()
    arch = strip(readstring(`arch`))
    if arch == "x86_64"
        install_binaries(
            "cmake-$(cmake_version)-Linux-x86_64",
            "tar.gz",
            "bin")
    else
        install_from_source("cmake-$(cmake_version)", "tar.gz")
    end
elseif is_apple()
    install_binaries(
        "cmake-$(cmake_version)-Darwin-x86_64",
        "tar.gz",
        joinpath("CMake.app", "Contents", "bin"))
elseif is_windows()
    if sizeof(Int) == 8
        install_binaries(
            "cmake-$(cmake_version)-win64-x64",
            "zip",
            "bin")
    elseif sizeof(Int) == 4
        install_binaries(
            "cmake-$(cmake_version)-win32-x86",
            "zip",
            "bin")
    else
        error("Only 32- or 64-bit architectures are supported")
    end
else
    error("Sorry, I couldn't recognize your operating system.")
end

run(process)

open(joinpath(dirname(@__FILE__), "deps.jl"), "w") do f
    write(f, """
const cmake_executable = "$(escape_string(joinpath(prefix, "bin", binary_name)))"
""")

end
