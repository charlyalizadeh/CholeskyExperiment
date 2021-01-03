testdirectory = dirname(@__FILE__)
cd(testdirectory)
files = readdir()
for file in files
    if file!="runtest.jl"
        include(joinpath(testdirectory, file))
    end
end
